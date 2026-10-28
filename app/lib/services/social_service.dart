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
  final String? avatar;
  final String thread;
  const Friend({
    required this.fid,
    required this.status,
    required this.incoming,
    required this.userId,
    required this.name,
    this.username,
    this.avatar,
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
  final String? avatar;
  const IncomingCall(this.thread, this.callId, this.callerName, this.video, [this.avatar]);
}

class PollResult {
  final List<ChatMessage> messages;
  final int peerDelivered; // highest message id the other side has received
  final int peerSeen; // highest message id the other side has seen
  final List<String> typing; // names typing right now
  final MeetPoint? meet;
  const PollResult(this.messages, this.peerDelivered, this.peerSeen, this.typing, this.meet);
}

class MeetPoint {
  final double lat;
  final double lng;
  final String label;
  final String by;
  final DateTime at;
  const MeetPoint(this.lat, this.lng, this.label, this.by, this.at);
  static MeetPoint? fromJson(dynamic j) {
    if (j is! Map) return null;
    final lat = double.tryParse('${j['lat']}');
    final lng = double.tryParse('${j['lng']}');
    if (lat == null || lng == null) return null;
    return MeetPoint(lat, lng, '${j['label'] ?? ''}', '${j['by'] ?? ''}',
        DateTime.fromMillisecondsSinceEpoch((int.tryParse('${j['ts']}') ?? 0) * 1000));
  }
}

class GroupMember {
  final int id;
  final String name;
  final String? username;
  final String? avatar;
  const GroupMember(this.id, this.name, this.username, this.avatar);
  factory GroupMember.fromJson(Map j) => GroupMember(
      int.tryParse('${j['id']}') ?? 0,
      '${j['name'] ?? ''}',
      j['username']?.toString(),
      (j['avatar'] ?? '').toString().isEmpty ? null : j['avatar'].toString());
}

class ChatGroup {
  final int id;
  final String name;
  final int owner;
  final String thread;
  final List<GroupMember> members;
  const ChatGroup(this.id, this.name, this.owner, this.thread, this.members);
  factory ChatGroup.fromJson(Map j) => ChatGroup(
        int.tryParse('${j['id']}') ?? 0,
        '${j['name'] ?? ''}',
        int.tryParse('${j['owner']}') ?? 0,
        '${j['thread']}',
        (j['members'] is List ? j['members'] as List : const [])
            .whereType<Map>()
            .map(GroupMember.fromJson)
            .toList(),
      );
}

class MemberLocation {
  final GroupMember user;
  final bool me;
  final bool sharing;
  final double? lat;
  final double? lng;
  final double? acc;
  final DateTime? at;
  const MemberLocation(this.user, this.me, this.sharing, this.lat, this.lng, this.acc, this.at);
}

class SosAlert {
  final String thread;
  final String from;
  final double? lat;
  final double? lng;
  final String? audio;
  final DateTime at;
  const SosAlert(this.thread, this.from, this.lat, this.lng, this.audio, this.at);
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
  List<ChatGroup> groups = [];
  /// Share my live location with my groups (account users).
  bool shareGroupLocation = false;
  DateTime _lastLocPush = DateTime.fromMillisecondsSinceEpoch(0);
  /// Fires when an SOS alert arrives from the partner / a group / a friend.
  final StreamController<SosAlert> sosAlerts = StreamController.broadcast();
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
  /// True while a call screen is open — new incoming calls get "busy".
  bool inCall = false;

  /// Photo of whoever is on the other side of [thread] (friends only).
  String? avatarFor(String thread) {
    for (final f in friends) {
      if (f.thread == thread) return f.avatar;
    }
    return null;
  }
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
    shareGroupLocation = p.getBool('share_group_loc') ?? false;
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
    sosAlerts.close();
    super.dispose();
  }

  void _onAccountChanged() {
    final active = account.loggedIn || pair.paired;
    if (active) {
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 4), (_) {
          refreshInbox();
          _maybePushLocation();
        });
        refreshFriends();
        refreshGroups();
        refreshInbox();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
    if (!account.loggedIn && (friends.isNotEmpty || groups.isNotEmpty)) {
      friends = [];
      groups = [];
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
        return SocialResult(false, {}, 'Server HTTP ${r.statusCode} (is plugin v1.7 installed?)');
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
              avatar: (u['avatar'] ?? '').toString().isEmpty ? null : u['avatar'].toString(),
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

  Future<PollResult?> poll(String thread, int afterId, {int seen = 0}) async {
    final r = await _post(
        'chat/poll', {'thread': thread, 'after': afterId, 'seen': seen, ..._auth(thread)});
    if (!r.ok) return null;
    final list = r.data['messages'];
    final msgs = list is List
        ? list.whereType<Map>().map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList()
        : <ChatMessage>[];
    final ty = r.data['typing'];
    return PollResult(
      msgs,
      int.tryParse('${r.data['peer_delivered'] ?? 0}') ?? 0,
      int.tryParse('${r.data['peer_seen'] ?? 0}') ?? 0,
      ty is List ? ty.map((e) => '$e').toList() : const [],
      MeetPoint.fromJson(r.data['meet']),
    );
  }

  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  /// Tell the other side I'm typing (throttled to one call per 3 s).
  void typing(String thread) {
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 3)) return;
    _lastTyping = now;
    _post('chat/typing', {'thread': thread, 'typing': true, ..._auth(thread)},
        timeout: const Duration(seconds: 8));
  }

  Future<SocialResult> sendVoice(String thread, Uint8List audio, int seconds) => _post(
      'chat/send',
      {'thread': thread, 'type': 'voice', 'audio': base64Encode(audio), 'duration': seconds, ..._auth(thread)},
      timeout: const Duration(seconds: 60));

  // ---------------- groups ----------------

  Future<void> refreshGroups() async {
    if (!account.loggedIn) return;
    final r = await _post('groups/list', {'token': account.token});
    if (!r.ok) return;
    final l = r.data['groups'];
    groups = l is List ? l.whereType<Map>().map(ChatGroup.fromJson).toList() : [];
    notifyListeners();
  }

  Future<SocialResult> createGroup(String name, List<int> memberIds) async {
    final r = await _post('groups/create', {'token': account.token, 'name': name, 'members': memberIds});
    if (r.ok) await refreshGroups();
    return r;
  }

  Future<SocialResult> addToGroup(int groupId, List<int> memberIds) async {
    final r = await _post('groups/add', {'token': account.token, 'group_id': groupId, 'members': memberIds});
    if (r.ok) await refreshGroups();
    return r;
  }

  Future<SocialResult> leaveGroup(int groupId) async {
    final r = await _post('groups/leave', {'token': account.token, 'group_id': groupId});
    if (r.ok) await refreshGroups();
    return r;
  }

  ChatGroup? groupFor(String thread) {
    for (final g in groups) {
      if (g.thread == thread) return g;
    }
    return null;
  }

  /// Members' live locations + the group's meeting point.
  Future<(List<MemberLocation>, MeetPoint?)?> groupLocations(int groupId) async {
    final r = await _post('groups/locations', {'token': account.token, 'group_id': groupId},
        timeout: const Duration(seconds: 12));
    if (!r.ok) return null;
    final l = r.data['members'];
    final list = l is List
        ? l.whereType<Map>().map((m) {
            final at = int.tryParse('${m['loc_at']}') ?? 0;
            return MemberLocation(
              GroupMember.fromJson(m),
              m['me'] == true,
              m['sharing'] == true,
              double.tryParse('${m['lat']}'),
              double.tryParse('${m['lng']}'),
              double.tryParse('${m['acc']}'),
              at > 0 ? DateTime.fromMillisecondsSinceEpoch(at * 1000) : null,
            );
          }).toList()
        : <MemberLocation>[];
    return (list, MeetPoint.fromJson(r.data['meet']));
  }

  Future<void> setShareGroupLocation(bool v) async {
    shareGroupLocation = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('share_group_loc', v);
    _lastLocPush = DateTime.fromMillisecondsSinceEpoch(0);
    if (v) {
      await pair.app.refreshLocation();
      await pushLocationNow();
    } else if (account.loggedIn) {
      await _post('loc/update', {'token': account.token, 'share': false});
    }
  }

  Future<void> pushLocationNow() async {
    if (!account.loggedIn || !shareGroupLocation) return;
    _lastLocPush = DateTime.now();
    final pos = pair.app.position;
    await _post('loc/update', {
      'token': account.token,
      'share': true,
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
      if (pos != null) 'acc': pos.accuracy,
    });
  }

  void _maybePushLocation() {
    if (!shareGroupLocation || !account.loggedIn || groups.isEmpty) return;
    if (DateTime.now().difference(_lastLocPush) < const Duration(seconds: 20)) return;
    _lastLocPush = DateTime.now();
    pair.app.refreshLocation(request: false).then((_) => pushLocationNow()).catchError((_) {});
  }

  // ---------------- meeting point ----------------

  Future<SocialResult> setMeet(String thread, double lat, double lng, String label) =>
      _post('meet/set', {'thread': thread, 'lat': lat, 'lng': lng, 'label': label, ..._auth(thread)});

  Future<SocialResult> clearMeet(String thread) =>
      _post('meet/set', {'thread': thread, 'clear': true, ..._auth(thread)});

  Future<MeetPoint?> getMeet(String thread) async {
    final r = await _post('meet/get', {'thread': thread, ..._auth(thread)},
        timeout: const Duration(seconds: 10));
    return r.ok ? MeetPoint.fromJson(r.data['meet']) : null;
  }

  // ---------------- SOS ----------------

  /// Everyone an SOS goes to: the paired partner and all my groups;
  /// with no partner/groups (or [includeFriends]) also every friend.
  List<String> sosThreads({bool includeFriends = false}) {
    final out = <String>[
      if (pair.paired) 'pair:${pair.code}',
      if (account.loggedIn) ...groups.map((g) => g.thread),
    ];
    if (includeFriends || out.isEmpty) {
      out.addAll(friends.where((f) => f.accepted).map((f) => f.thread));
    }
    return out.toSet().toList();
  }

  Future<SocialResult> sendSos(List<String> threads,
      {double? lat, double? lng, double? acc, Uint8List? audio}) {
    return _post(
        'sos/send',
        {
          'threads': threads,
          if (account.loggedIn) 'token': account.token,
          if (pair.paired) 'ptoken': pair.token,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (acc != null) 'acc': acc,
          if (audio != null) 'audio': base64Encode(audio),
        },
        timeout: const Duration(seconds: 60));
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

  Future<SocialResult> callEnd(String thread, String callId,
          {bool declined = false, bool busy = false}) =>
      _post('call/end', {
        'thread': thread,
        'call_id': callId,
        'status': busy ? 'busy' : (declined ? 'declined' : 'ended'),
        ..._auth(thread),
      });

  void markCallHandled(String callId) => _announcedCalls.add(callId);

  // ---------------- unread + incoming calls ----------------

  int unreadFor(String thread) {
    final latest = _latestId[thread] ?? 0;
    final seen = _seenId[thread] ?? 0;
    return latest > seen ? 1 : 0;
  }

  int get totalUnread =>
      friends.where((f) => f.accepted).fold(0, (s, f) => s + unreadFor(f.thread)) +
      groups.fold(0, (s, g) => s + unreadFor(g.thread)) +
      (pair.paired ? unreadFor('pair:${pair.code}') : 0);

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
    // Calls ringing for me (v1.6+: freshness decided by the server clock).
    final ringing = r.data['ringing'];
    final serverRings = ringing is List;
    if (ringing is List) {
      for (final raw in ringing.whereType<Map>()) {
        final c = Map<String, dynamic>.from(raw);
        final callId = '${c['call_id'] ?? ''}';
        if (callId.isEmpty || !_announcedCalls.add(callId)) continue;
        final video = c['video'] == true;
        final av = '${c['caller_avatar'] ?? ''}';
        final name = '${c['caller_name'] ?? ''}';
        incomingCalls.add(IncomingCall('${c['thread']}', callId, name, video, av.isEmpty ? null : av));
        NotificationsService.instance.showCall(
            video ? '📹 Incoming video call' : '📞 Incoming voice call', '$name is calling you');
      }
    }
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
        if (isNew && !m.mine && m.type == 'sos') {
          final b = m.body is Map ? Map<String, dynamic>.from(m.body as Map) : <String, dynamic>{};
          if (DateTime.now().difference(m.at).abs() < const Duration(minutes: 30)) {
            sosAlerts.add(SosAlert('$thread', m.name, double.tryParse('${b['lat']}'),
                double.tryParse('${b['lng']}'), b['audio']?.toString(), m.at));
            NotificationsService.instance.showSos('🚨 SOS — ${m.name} needs help', 'Tap to see their location');
          }
          return;
        }
        if (isNew && !m.mine && m.type == 'system') return;
        if (isNew && !m.mine && (activeThread != thread || m.type == 'call')) {
          if (m.type == 'call') {
            if (serverRings) return; // handled above
            if (DateTime.now().difference(m.at).abs() > const Duration(minutes: 1)) return;
            final b = m.body is Map ? Map<String, dynamic>.from(m.body as Map) : <String, dynamic>{};
            final video = b['video'] == true;
            final callId = '${b['call_id'] ?? ''}';
            if (callId.isNotEmpty && _announcedCalls.add(callId)) {
              incomingCalls.add(IncomingCall('$thread', callId, m.name, video));
            }
            NotificationsService.instance.showCall(
                video ? '📹 Incoming video call' : '📞 Incoming voice call',
                '${m.name} is calling you');
          } else {
            NotificationsService.instance.showAnnouncement(
                '💬 ${m.name}',
                m.type == 'text'
                    ? '${m.body}'
                    : const {
                          'image': '📷 Photo',
                          'location': '📍 Location',
                          'voice': '🎤 Voice message',
                          'meet': '📌 New meeting point',
                        }[m.type] ??
                        '📞 Call');
          }
        }
      });
    }
    if (latest is Map &&
        latest.keys.any((k) => '$k'.startsWith('grp:') && groupFor('$k') == null)) {
      refreshGroups();
    }
    if (pendingRequests > prevPending && prevPending >= 0 && _timer != null) {
      refreshFriends();
    }
    notifyListeners();
  }
}
