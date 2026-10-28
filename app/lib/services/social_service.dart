import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'account_service.dart';
import 'notifications_service.dart';
import 'pair_service.dart' show kDefaultPairApiBase;
import 'pair_state.dart';

class Friend {
  final int fid;
  final String status; // pending | accepted
  final bool incoming; // a request waiting for MY answer
  final int userId;
  final String name;
  final String? username;
  final String thread;
  const Friend({
    required this.fid,
    required this.status,
    required this.incoming,
    required this.userId,
    required this.name,
    this.username,
    required this.thread,
  });
  bool get accepted => status == 'accepted';
}

class ChatMessage {
  final int id;
  final String type; // text | image | location | call
  final dynamic body; // String, or Map for location/call
  final String name;
  final bool mine;
  final DateTime at;
  const ChatMessage(this.id, this.type, this.body, this.name, this.mine, this.at);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        int.tryParse('${j['id']}') ?? 0,
        '${j['type'] ?? 'text'}',
        j['body'],
        '${j['name'] ?? ''}',
        j['mine'] == true,
        DateTime.fromMillisecondsSinceEpoch((int.tryParse('${j['ts']}') ?? 0) * 1000),
      );
}

class IncomingCall {
  final String thread;
  final String callId;
  final String callerName;
  final bool video;
  const IncomingCall(this.thread, this.callId, this.callerName, this.video);
}

class SocialResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String? error;
  const SocialResult(this.ok, this.data, [this.error]);
}

/// Friends (add by email or @username), live chat (text, photo, location),
/// and voice/video calls via a Jitsi room link. Works over plain HTTPS
/// polling against the Umrah Trip website — no extra services required.
class SocialService extends ChangeNotifier {
  final AccountService account;
  final PairState pair;
  SocialService(this.account, this.pair);

  List<Friend> friends = [];
  int pendingRequests = 0;
  final Map<String, int> _latestId = {}; // thread → latest message id on server
  final Map<String, int> _seenId = {}; // thread → last id the user has seen
  String callServer = 'https://meet.jit.si';
  /// STUN/TURN servers for in-app calls (from the website admin settings).
  List<Map<String, dynamic>> iceServers = [
    {'urls': ['stun:stun.l.google.com:19302']}
  ];

  /// Fires when someone starts calling us (thread, call_id, caller, video).
  final StreamController<IncomingCall> incomingCalls = StreamController.broadcast();
  final Set<String> _announcedCalls = {};
  String? activeThread; // the chat currently open (no alerts for it)
  Timer? _timer;

  String get _base =>
      pair.api.baseUrl.isEmpty ? kDefaultPairApiBase : pair.api.baseUrl;
  Uri _ep(String path) => Uri.parse('$_base/wp-json/umrah-pair/v1/$path');

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('chat_seen');
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map).forEach((k, v) => _seenId['$k'] = int.tryParse('$v') ?? 0);
      } catch (_) {}
    }
    account.addListener(_onAccountChanged);
    pair.addListener(_onAccountChanged);
    _loadCallServer();
    _onAccountChanged();
  }

  @override
  void dispose() {
    _timer?.cancel();
    account.removeListener(_onAccountChanged);
    pair.removeListener(_onAccountChanged);
    incomingCalls.close();
    super.dispose();
  }

  void _onAccountChanged() {
    final active = account.loggedIn || pair.paired;
    if (active) {
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 8), (_) => refreshInbox());
        refreshFriends();
        refreshInbox();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
    if (!account.loggedIn && friends.isNotEmpty) {
      friends = [];
      pendingRequests = 0;
      notifyListeners();
    }
  }

  Future<void> _loadCallServer() async {
    try {
      final r = await http.get(_ep('config')).timeout(const Duration(seconds: 12));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final cs = '${j['call_server'] ?? ''}';
      if (cs.startsWith('http')) callServer = cs.replaceAll(RegExp(r'/+$'), '');
      final ice = j['ice_servers'];
      if (ice is List && ice.isNotEmpty) {
        iceServers = ice.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
  }

  Future<SocialResult> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      final r = await http
          .post(_ep(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      Map<String, dynamic> j;
      try {
        j = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {
        return SocialResult(false, {}, 'Server HTTP ${r.statusCode} (is plugin v1.4 installed?)');
      }
      if (r.statusCode == 200 && j['ok'] == true) return SocialResult(true, j);
      return SocialResult(false, j, '${j['error'] ?? j['message'] ?? 'HTTP ${r.statusCode}'}');
    } catch (e) {
      return SocialResult(false, {}, 'Internet or server problem: $e');
    }
  }

  // ---------------- friends ----------------

  Future<void> refreshFriends() async {
    if (!account.loggedIn) return;
    final r = await _post('friends/list', {'token': account.token});
    if (!r.ok) return;
    final list = r.data['friends'];
    friends = list is List
        ? list.whereType<Map>().map((m) {
            final u = Map<String, dynamic>.from(m['user'] as Map);
            return Friend(
              fid: int.tryParse('${m['fid']}') ?? 0,
              status: '${m['status']}',
              incoming: m['incoming'] == true,
              userId: int.tryParse('${u['id']}') ?? 0,
              name: '${u['name'] ?? ''}',
              username: u['username']?.toString(),
              thread: '${m['thread']}',
            );
          }).toList()
        : [];
    notifyListeners();
  }

  Future<SocialResult> addFriend(String query) async {
    final r = await _post('friends/add', {'token': account.token, 'query': query.trim()});
    if (r.ok) await refreshFriends();
    return r;
  }

  Future<SocialResult> respond(Friend f, bool accept) async {
    final r = await _post('friends/respond', {'token': account.token, 'fid': f.fid, 'accept': accept});
    if (r.ok) await refreshFriends();
    await refreshInbox();
    return r;
  }

  Future<SocialResult> removeFriend(Friend f) async {
    final r = await _post('friends/remove', {'token': account.token, 'fid': f.fid});
    if (r.ok) await refreshFriends();
    return r;
  }

  // ---------------- chat ----------------

  Map<String, dynamic> _auth(String thread) => thread.startsWith('pair:')
      ? {'ptoken': pair.token}
      : {'token': account.token};

  Future<List<ChatMessage>?> poll(String thread, int afterId) async {
    final r = await _post('chat/poll', {'thread': thread, 'after': afterId, ..._auth(thread)});
    if (!r.ok) return null;
    final list = r.data['messages'];
    return list is List
        ? list.whereType<Map>().map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList()
        : <ChatMessage>[];
  }

  Future<SocialResult> sendText(String thread, String text) =>
      _post('chat/send', {'thread': thread, 'type': 'text', 'body': text, ..._auth(thread)});

  Future<SocialResult> sendImage(String thread, Uint8List jpeg) => _post(
      'chat/send', {'thread': thread, 'type': 'image', 'image': base64Encode(jpeg), ..._auth(thread)},
      timeout: const Duration(seconds: 60));

  Future<SocialResult> sendLocation(String thread, double lat, double lng) => _post('chat/send', {
        'thread': thread,
        'type': 'location',
        'body': {'lat': lat, 'lng': lng},
        ..._auth(thread),
      });

  /// Creates a private Jitsi room, posts the call invite into the chat and
  /// returns the room URL to open.
  Future<String?> startCall(String thread, {required bool video}) async {
    final rnd = Random.secure();
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final room = 'UmrahTrip-${List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join()}';
    final url = '$callServer/$room#config.prejoinPageEnabled=false'
        '&config.startWithVideoMuted=${!video}&config.startWithAudioMuted=false';
    final r = await _post('chat/send', {
      'thread': thread,
      'type': 'call',
      'body': {'url': url, 'video': video},
      ..._auth(thread),
    });
    return r.ok ? url : null;
  }

  // ---------------- in-app calls (WebRTC signaling) ----------------

  Future<SocialResult> callStart(String thread, Map<String, dynamic> offer, bool video) =>
      _post('call/start', {'thread': thread, 'offer': offer, 'video': video, ..._auth(thread)});

  Future<Map<String, dynamic>?> callGet(String thread, String callId) async {
    final r = await _post('call/get', {'thread': thread, 'call_id': callId, ..._auth(thread)},
        timeout: const Duration(seconds: 10));
    final c = r.data['call'];
    return r.ok && c is Map ? Map<String, dynamic>.from(c) : null;
  }

  Future<SocialResult> callAnswer(String thread, String callId, Map<String, dynamic> answer) =>
      _post('call/answer', {'thread': thread, 'call_id': callId, 'answer': answer, ..._auth(thread)});

  Future<SocialResult> callEnd(String thread, String callId, {bool declined = false}) => _post(
      'call/end',
      {'thread': thread, 'call_id': callId, 'status': declined ? 'declined' : 'ended', ..._auth(thread)});

  void markCallHandled(String callId) => _announcedCalls.add(callId);

  // ---------------- unread + incoming calls ----------------

  int unreadFor(String thread) {
    final latest = _latestId[thread] ?? 0;
    final seen = _seenId[thread] ?? 0;
    return latest > seen ? 1 : 0;
  }

  int get totalUnread =>
      friends.where((f) => f.accepted).fold(0, (s, f) => s + unreadFor(f.thread));

  Future<void> markSeen(String thread, int id) async {
    if ((_seenId[thread] ?? 0) >= id) return;
    _seenId[thread] = id;
    if ((_latestId[thread] ?? 0) < id) _latestId[thread] = id;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setString('chat_seen', jsonEncode(_seenId));
  }

  Future<void> refreshInbox() async {
    if (!account.loggedIn && !pair.paired) return;
    final r = await _post('chat/inbox', {
      if (account.loggedIn) 'token': account.token,
      if (pair.paired) 'pair_thread': 'pair:${pair.code}',
      if (pair.paired) 'ptoken': pair.token,
    });
    if (!r.ok) return;
    final prevPending = pendingRequests;
    pendingRequests = int.tryParse('${r.data['pending_requests']}') ?? 0;
    final latest = r.data['latest'];
    if (latest is Map) {
      latest.forEach((thread, raw) {
        if (raw is! Map) return;
        final m = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
        final before = _latestId['$thread'] ?? 0;
        _latestId['$thread'] = m.id;
        final isNew = m.id > before && (before != 0 || m.type == 'call');
        if (isNew && !m.mine && (activeThread != thread || m.type == 'call')) {
          if (m.type == 'call' &&
              DateTime.now().difference(m.at) < const Duration(minutes: 1)) {
            final b = m.body is Map ? Map<String, dynamic>.from(m.body as Map) : <String, dynamic>{};
            final video = b['video'] == true;
            final callId = '${b['call_id'] ?? ''}';
            if (callId.isNotEmpty && _announcedCalls.add(callId)) {
              incomingCalls.add(IncomingCall('$thread', callId, m.name, video));
            }
            NotificationsService.instance.showAnnouncement(
                video ? '📹 Incoming video call' : '📞 Incoming voice call',
                '${m.name} is calling you');
          } else {
            NotificationsService.instance.showAnnouncement(
                '💬 ${m.name}',
                m.type == 'text'
                    ? '${m.body}'
                    : m.type == 'image'
                        ? '📷 Photo'
                        : m.type == 'location'
                            ? '📍 Location'
                            : '📞 Call');
          }
        }
      });
    }
    if (pendingRequests > prevPending && prevPending >= 0 && _timer != null) {
      refreshFriends();
    }
    notifyListeners();
  }
}
