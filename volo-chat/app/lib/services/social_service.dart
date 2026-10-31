import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import 'account_service.dart';
import 'device_state.dart';
import 'notifications_service.dart';

class ChatMessage {
  final int id;
  final String type; // text | reply | image | location | voice | call | sos | meet | system | deleted
  final dynamic body;
  final String name;
  final String sender;
  final bool mine;
  final DateTime at;
  const ChatMessage(this.id, this.type, this.body, this.name, this.mine, this.at, [this.sender = '']);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        int.tryParse('${j['id']}') ?? 0,
        '${j['type'] ?? 'text'}',
        j['body'],
        '${j['name'] ?? ''}',
        j['mine'] == true,
        DateTime.fromMillisecondsSinceEpoch((int.tryParse('${j['ts']}') ?? 0) * 1000),
        '${j['sender'] ?? ''}',
      );

  ChatMessage asDeleted() => ChatMessage(id, 'deleted', '', name, mine, at, sender);

  /// One-line preview for the chat list / notifications.
  String get preview {
    switch (type) {
      case 'text':
        return '$body';
      case 'reply':
        return body is Map ? '${(body as Map)['text']}' : '$body';
      case 'image':
        final c = body is Map ? '${(body as Map)['caption'] ?? ''}' : '';
        return c.isNotEmpty ? '📷 $c' : '📷 Photo';
      case 'voice':
        return '🎤 Voice message';
      case 'location':
        return '📍 Location';
      case 'call':
        return (body is Map && (body as Map)['video'] == true) ? '📹 Video call' : '📞 Voice call';
      case 'sos':
        return '🚨 SOS alert';
      case 'meet':
        return '📌 Meeting point';
      case 'system':
        return body is Map ? '${(body as Map)['text']}' : '';
      case 'deleted':
        return '🚫 This message was deleted';
      default:
        return 'Message';
    }
  }
}

class Contact {
  final int cid;
  final String thread;
  final VoloUser user;
  const Contact(this.cid, this.thread, this.user);
  factory Contact.fromJson(Map j) =>
      Contact(int.tryParse('${j['cid']}') ?? 0, '${j['thread']}', VoloUser.fromJson(j['user'] as Map));
}

class ChatGroup {
  final int id;
  final String name;
  final int owner;
  final String thread;
  final List<VoloUser> members;
  const ChatGroup(this.id, this.name, this.owner, this.thread, this.members);
  factory ChatGroup.fromJson(Map j) => ChatGroup(
        int.tryParse('${j['id']}') ?? 0,
        '${j['name'] ?? ''}',
        int.tryParse('${j['owner']}') ?? 0,
        '${j['thread']}',
        (j['members'] is List ? j['members'] as List : const []).whereType<Map>().map(VoloUser.fromJson).toList(),
      );
}

/// Kept for the shared group/map widgets.
typedef GroupMember = VoloUser;

class PollResult {
  final List<ChatMessage> messages;
  final List<int> deleted;
  final int peerDelivered;
  final int peerSeen;
  final List<String> typing;
  final MeetPoint? meet;
  final bool? peerOnline;
  final DateTime? peerLastSeen;
  const PollResult(this.messages, this.deleted, this.peerDelivered, this.peerSeen, this.typing, this.meet,
      this.peerOnline, this.peerLastSeen);
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

class MemberLocation {
  final VoloUser user;
  final bool me;
  final bool sharing;
  final double? lat;
  final double? lng;
  final double? acc;
  final DateTime? at;
  const MemberLocation(this.user, this.me, this.sharing, this.lat, this.lng, this.acc, this.at);
}

class IncomingCall {
  final String thread;
  final String callId;
  final String callerName;
  final bool video;
  final String? avatar;
  const IncomingCall(this.thread, this.callId, this.callerName, this.video, [this.avatar]);
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

class CallRecord {
  final String callId;
  final String thread;
  final bool video;
  final bool outgoing;
  final String peer;
  final String? avatar;
  final String status;
  final DateTime at;
  final int duration;
  const CallRecord(this.callId, this.thread, this.video, this.outgoing, this.peer, this.avatar, this.status, this.at,
      this.duration);
  bool get answered => status == 'answered';
  bool get missedByMe => !outgoing && !answered && status != 'ringing';
  factory CallRecord.fromJson(Map j) => CallRecord(
        '${j['call_id']}',
        '${j['thread']}',
        j['video'] == true,
        j['outgoing'] == true,
        '${j['peer'] ?? ''}',
        (j['avatar'] ?? '').toString().isEmpty ? null : '${j['avatar']}',
        '${j['status'] ?? ''}',
        DateTime.fromMillisecondsSinceEpoch((int.tryParse('${j['ts']}') ?? 0) * 1000),
        int.tryParse('${j['duration']}') ?? 0,
      );
}

class StatusItem {
  final int id;
  final String type; // text | image
  final String body; // text or image URL
  final String bg;
  final String caption;
  final DateTime at;
  final bool viewed;
  final int views;
  const StatusItem(this.id, this.type, this.body, this.bg, this.caption, this.at, this.viewed, this.views);
  factory StatusItem.fromJson(Map j) => StatusItem(
        int.tryParse('${j['id']}') ?? 0,
        '${j['type']}',
        '${j['body'] ?? ''}',
        '${j['bg'] ?? '#6C4CF1'}',
        '${j['caption'] ?? ''}',
        DateTime.fromMillisecondsSinceEpoch((int.tryParse('${j['ts']}') ?? 0) * 1000),
        j['viewed'] == true,
        int.tryParse('${j['views'] ?? 0}') ?? 0,
      );
}

class StatusGroup {
  final VoloUser user;
  final List<StatusItem> items;
  const StatusGroup(this.user, this.items);
  bool get allViewed => items.every((i) => i.viewed);
}

typedef SocialResult = ApiResult;

/// Contacts, chats, calls, groups, Status, location sharing and SOS.
/// Plain HTTPS polling against the Volo Chat server.
class SocialService extends ChangeNotifier {
  final AccountService account;
  final DeviceState device;
  SocialService(this.account, this.device);

  List<Contact> contacts = [];
  List<ChatGroup> groups = [];
  final Map<String, ChatMessage> latest = {}; // thread → newest message
  final Map<String, int> unread = {};
  List<CallRecord> callHistory = [];
  String? callHistoryError;
  int missedCallsUnseen = 0;
  List<StatusItem> myStatus = [];
  List<StatusGroup> statusFeed = [];
  List<Map<String, dynamic>> iceServers = [
    {'urls': ['stun:stun.l.google.com:19302']}
  ];
  bool shareGroupLocation = false;

  final StreamController<IncomingCall> incomingCalls = StreamController.broadcast();
  final StreamController<SosAlert> sosAlerts = StreamController.broadcast();
  final Set<String> _announcedCalls = {};
  final Set<int> _announcedSos = {};
  String? activeThread;
  bool inCall = false;
  bool appInForeground = true;
  Timer? _timer;
  DateTime _callsSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLocPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _seeded = false;
  int _lastCallMsgId = 0;

  Map<String, dynamic> get _t => {'token': account.token};

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _callsSeenAt = DateTime.fromMillisecondsSinceEpoch(p.getInt('volo_calls_seen_at') ?? 0);
    shareGroupLocation = p.getBool('volo_share_loc') ?? false;
    account.addListener(_onAccount);
    _loadConfig();
    _onAccount();
  }

  void _onAccount() {
    if (account.loggedIn && !account.needsProfile) {
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 4), (_) {
          refreshInbox();
          _maybePushLocation();
        });
        refreshAll();
      }
    } else {
      _timer?.cancel();
      _timer = null;
      if (contacts.isNotEmpty || groups.isNotEmpty || latest.isNotEmpty) {
        contacts = [];
        groups = [];
        latest.clear();
        unread.clear();
        callHistory = [];
        statusFeed = [];
        myStatus = [];
        _seeded = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshContacts(), refreshGroups()]);
    await refreshInbox();
    refreshStatus();
    refreshCallHistory();
  }

  Future<void> _loadConfig() async {
    final c = await Api.config();
    final ice = c?['ice_servers'];
    if (ice is List && ice.isNotEmpty) {
      iceServers = ice.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    account.removeListener(_onAccount);
    incomingCalls.close();
    sosAlerts.close();
    super.dispose();
  }

  Future<ApiResult> _post(String path, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 20)}) =>
      Api.post(path, {..._t, ...body}, timeout: timeout);

  // ---------------- contacts ----------------

  Future<void> refreshContacts() async {
    if (!account.loggedIn) return;
    final r = await _post('contacts/list', {});
    if (!r.ok) return;
    final l = r.data['contacts'];
    contacts = l is List ? l.whereType<Map>().map(Contact.fromJson).toList() : [];
    notifyListeners();
  }

  Future<ApiResult> addContact(String query) async {
    final r = await _post('contacts/add', {'query': query.trim()});
    if (r.ok) await refreshContacts();
    return r;
  }

  Future<ApiResult> removeContact(Contact c) async {
    final r = await _post('contacts/remove', {'cid': c.cid});
    if (r.ok) await refreshContacts();
    return r;
  }

  Contact? contactFor(String thread) {
    for (final c in contacts) {
      if (c.thread == thread) return c;
    }
    return null;
  }

  String? avatarFor(String thread) => contactFor(thread)?.user.avatar;

  String titleFor(String thread) =>
      contactFor(thread)?.user.displayName ?? groupFor(thread)?.name ?? 'Chat';

  // ---------------- chat ----------------

  Future<PollResult?> poll(String thread, int afterId, {int seen = 0}) async {
    final r = await _post('chat/poll', {'thread': thread, 'after': afterId, 'seen': seen});
    if (!r.ok) return null;
    final l = r.data['messages'];
    final msgs = l is List
        ? l.whereType<Map>().map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList()
        : <ChatMessage>[];
    final del = r.data['deleted'];
    final ty = r.data['typing'];
    final peer = r.data['peer'];
    bool? online;
    DateTime? ls;
    if (peer is Map) {
      online = peer['online'] == true;
      final t = int.tryParse('${peer['last_seen'] ?? 0}') ?? 0;
      if (t > 0) ls = DateTime.fromMillisecondsSinceEpoch(t * 1000);
    }
    if (msgs.isNotEmpty) {
      latest[thread] = msgs.last;
      unread[thread] = 0;
      notifyListeners();
    }
    return PollResult(
      msgs,
      del is List ? del.map((e) => int.tryParse('$e') ?? 0).toList() : const [],
      int.tryParse('${r.data['peer_delivered'] ?? 0}') ?? 0,
      int.tryParse('${r.data['peer_seen'] ?? 0}') ?? 0,
      ty is List ? ty.map((e) => '$e').toList() : const [],
      MeetPoint.fromJson(r.data['meet']),
      online,
      ls,
    );
  }

  Future<ApiResult> sendText(String thread, String text, {int? replyTo}) =>
      _post('chat/send', {'thread': thread, 'type': 'text', 'body': text, if (replyTo != null) 'reply_to': replyTo});

  Future<ApiResult> sendImage(String thread, Uint8List jpeg, {String caption = ''}) => _post(
      'chat/send', {'thread': thread, 'type': 'image', 'image': base64Encode(jpeg), 'caption': caption},
      timeout: const Duration(seconds: 60));

  Future<ApiResult> sendLocation(String thread, double lat, double lng) =>
      _post('chat/send', {'thread': thread, 'type': 'location', 'body': {'lat': lat, 'lng': lng}});

  Future<ApiResult> sendVoice(String thread, Uint8List audio, int seconds) => _post(
      'chat/send', {'thread': thread, 'type': 'voice', 'audio': base64Encode(audio), 'duration': seconds},
      timeout: const Duration(seconds: 60));

  Future<ApiResult> deleteMessage(String thread, int id) => _post('chat/delete', {'thread': thread, 'id': id});

  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
  void typing(String thread) {
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 3)) return;
    _lastTyping = now;
    _post('chat/typing', {'thread': thread, 'typing': true}, timeout: const Duration(seconds: 8));
  }

  int unreadFor(String thread) => unread[thread] ?? 0;
  int get totalUnread => unread.values.fold<int>(0, (a, b) => a + b);

  /// Kept for the shared chat screen (server tracks "seen" through polling).
  Future<void> markSeen(String thread, int id) async {
    if ((unread[thread] ?? 0) > 0) {
      unread[thread] = 0;
      notifyListeners();
    }
  }

  // ---------------- inbox / incoming calls / alerts ----------------

  Future<void> refreshInbox() async {
    if (!account.loggedIn) return;
    if (appInForeground) {
      SharedPreferences.getInstance().then((p) => p.setInt('volo_fg_at', DateTime.now().millisecondsSinceEpoch));
    }
    final r = await _post('chat/inbox', {});
    if (!r.ok) return;
    final ring = r.data['ringing'];
    if (ring is List) {
      for (final c in ring.whereType<Map>()) {
        final id = '${c['call_id']}';
        if (id.isEmpty || !_announcedCalls.add(id)) continue;
        final video = c['video'] == true;
        final av = '${c['caller_avatar'] ?? ''}';
        incomingCalls.add(IncomingCall('${c['thread']}', id, '${c['caller_name']}', video, av.isEmpty ? null : av));
        if (!appInForeground) {
          NotificationsService.instance.showCall(
              video ? '📹 ${c['caller_name']}' : '📞 ${c['caller_name']}', video ? 'Incoming video call' : 'Incoming voice call');
        }
      }
    }
    final l = r.data['latest'];
    final u = r.data['unread'];
    var newCall = false;
    if (l is Map) {
      l.forEach((th, raw) {
        if (raw is! Map) return;
        final m = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
        final before = latest['$th']?.id ?? 0;
        latest['$th'] = m;
        if (m.type == 'call' && m.id > _lastCallMsgId) {
          _lastCallMsgId = m.id;
          newCall = true;
        }
        final fresh = _seeded && m.id > before && !m.mine;
        if (m.type == 'sos' && !m.mine && _announcedSos.add(m.id) &&
            DateTime.now().difference(m.at).abs() < const Duration(minutes: 30)) {
          final b = m.body is Map ? m.body as Map : const {};
          sosAlerts.add(SosAlert('$th', m.name, double.tryParse('${b['lat']}'), double.tryParse('${b['lng']}'),
              b['audio']?.toString(), m.at));
          NotificationsService.instance.showSos('🚨 SOS — ${m.name} needs help', 'Tap to see their location');
          return;
        }
        if (fresh && activeThread != th && !const {'call', 'system'}.contains(m.type)) {
          final g = groupFor('$th');
          NotificationsService.instance.showMessage('$th', g != null ? '${m.name} @ ${g.name}' : m.name, m.preview);
        }
      });
    }
    if (u is Map) {
      unread.clear();
      u.forEach((k, v) => unread['$k'] = '$k' == activeThread ? 0 : (int.tryParse('$v') ?? 0));
    }
    if (l is Map && l.keys.any((k) => '$k'.startsWith('grp:') && groupFor('$k') == null)) refreshGroups();
    if (l is Map && l.keys.any((k) => '$k'.startsWith('dm:') && contactFor('$k') == null)) refreshContacts();
    if (newCall && _seeded) refreshCallHistory();
    _seeded = true;
    notifyListeners();
  }

  // ---------------- calls ----------------

  Future<ApiResult> callStart(String thread, Map<String, dynamic> offer, bool video) =>
      _post('call/start', {'thread': thread, 'offer': offer, 'video': video});

  Future<Map<String, dynamic>?> callGet(String thread, String callId) async {
    final r = await _post('call/get', {'thread': thread, 'call_id': callId}, timeout: const Duration(seconds: 10));
    final c = r.data['call'];
    return r.ok && c is Map ? Map<String, dynamic>.from(c) : null;
  }

  Future<ApiResult> callAnswer(String thread, String callId, Map<String, dynamic> answer) =>
      _post('call/answer', {'thread': thread, 'call_id': callId, 'answer': answer});

  Future<ApiResult> callEnd(String thread, String callId, {bool declined = false, bool busy = false}) => _post(
      'call/end', {'thread': thread, 'call_id': callId, 'status': busy ? 'busy' : (declined ? 'declined' : 'ended')});

  void markCallHandled(String callId) => _announcedCalls.add(callId);

  Future<void> refreshCallHistory() async {
    if (!account.loggedIn) return;
    final r = await _post('call/history', {});
    if (r.ok) {
      final l = r.data['calls'];
      callHistory = l is List ? l.whereType<Map>().map(CallRecord.fromJson).toList() : [];
      callHistoryError = null;
      missedCallsUnseen = callHistory.where((c) => c.missedByMe && c.at.isAfter(_callsSeenAt)).length;
    } else {
      callHistoryError = r.error;
    }
    notifyListeners();
  }

  Future<void> markCallsSeen() async {
    _callsSeenAt = DateTime.now();
    missedCallsUnseen = 0;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('volo_calls_seen_at', _callsSeenAt.millisecondsSinceEpoch);
  }

  // ---------------- groups ----------------

  Future<void> refreshGroups() async {
    if (!account.loggedIn) return;
    final r = await _post('groups/list', {});
    if (!r.ok) return;
    final l = r.data['groups'];
    groups = l is List ? l.whereType<Map>().map(ChatGroup.fromJson).toList() : [];
    notifyListeners();
  }

  Future<ApiResult> createGroup(String name, List<int> ids) async {
    final r = await _post('groups/create', {'name': name, 'members': ids});
    if (r.ok) await refreshGroups();
    return r;
  }

  Future<ApiResult> addToGroup(int gid, List<int> ids) async {
    final r = await _post('groups/add', {'group_id': gid, 'members': ids});
    if (r.ok) await refreshGroups();
    return r;
  }

  Future<ApiResult> leaveGroup(int gid) async {
    final r = await _post('groups/leave', {'group_id': gid});
    if (r.ok) {
      latest.remove('grp:$gid');
      await refreshGroups();
    }
    return r;
  }

  ChatGroup? groupFor(String thread) {
    for (final g in groups) {
      if (g.thread == thread) return g;
    }
    return null;
  }

  Future<(List<MemberLocation>, MeetPoint?)?> groupLocations(int gid) async {
    final r = await _post('groups/locations', {'group_id': gid}, timeout: const Duration(seconds: 12));
    if (!r.ok) return null;
    final l = r.data['members'];
    final list = l is List
        ? l.whereType<Map>().map((m) {
            final at = int.tryParse('${m['loc_at']}') ?? 0;
            return MemberLocation(VoloUser.fromJson(m), m['me'] == true, m['sharing'] == true,
                double.tryParse('${m['lat']}'), double.tryParse('${m['lng']}'), double.tryParse('${m['acc']}'),
                at > 0 ? DateTime.fromMillisecondsSinceEpoch(at * 1000) : null);
          }).toList()
        : <MemberLocation>[];
    return (list, MeetPoint.fromJson(r.data['meet']));
  }

  // ---------------- live location ----------------

  Future<void> setShareGroupLocation(bool v) async {
    shareGroupLocation = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('volo_share_loc', v);
    if (v) {
      await device.refreshLocation();
      await pushLocationNow();
    } else {
      await _post('loc/update', {'share': false});
    }
  }

  Future<void> pushLocationNow() async {
    if (!account.loggedIn || !shareGroupLocation) return;
    _lastLocPush = DateTime.now();
    final pos = device.position;
    await _post('loc/update', {
      'share': true,
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
      if (pos != null) 'acc': pos.accuracy,
    });
  }

  void _maybePushLocation() {
    if (!shareGroupLocation || groups.isEmpty) return;
    if (DateTime.now().difference(_lastLocPush) < const Duration(seconds: 20)) return;
    _lastLocPush = DateTime.now();
    device.refreshLocation(request: false).then((_) => pushLocationNow()).catchError((_) {});
  }

  // ---------------- meeting point ----------------

  Future<ApiResult> setMeet(String thread, double lat, double lng, String label) =>
      _post('meet/set', {'thread': thread, 'lat': lat, 'lng': lng, 'label': label});

  Future<ApiResult> clearMeet(String thread) => _post('meet/set', {'thread': thread, 'clear': true});

  Future<MeetPoint?> getMeet(String thread) async {
    final r = await _post('meet/get', {'thread': thread}, timeout: const Duration(seconds: 10));
    return r.ok ? MeetPoint.fromJson(r.data['meet']) : null;
  }

  // ---------------- SOS ----------------

  /// Groups get every SOS; with no groups (or [includeContacts]) every contact too.
  List<String> sosThreads({bool includeContacts = false}) {
    final out = <String>[...groups.map((g) => g.thread)];
    if (includeContacts || out.isEmpty) out.addAll(contacts.map((c) => c.thread));
    return out.toSet().toList();
  }

  Future<ApiResult> sendSos(List<String> threads, {double? lat, double? lng, double? acc, Uint8List? audio}) => _post(
      'sos/send',
      {
        'threads': threads,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (acc != null) 'acc': acc,
        if (audio != null) 'audio': base64Encode(audio),
      },
      timeout: const Duration(seconds: 60));

  // ---------------- Status (stories) ----------------

  Future<void> refreshStatus() async {
    if (!account.loggedIn) return;
    final r = await _post('status/feed', {});
    if (!r.ok) return;
    final mine = r.data['mine'];
    myStatus = mine is List ? mine.whereType<Map>().map(StatusItem.fromJson).toList() : [];
    final ppl = r.data['people'];
    statusFeed = ppl is List
        ? ppl.whereType<Map>().map((p) {
            final items = (p['items'] is List ? p['items'] as List : const []).whereType<Map>().map(StatusItem.fromJson).toList();
            return StatusGroup(VoloUser.fromJson(p['user'] as Map), items);
          }).where((g) => g.items.isNotEmpty).toList()
        : [];
    notifyListeners();
  }

  Future<ApiResult> postTextStatus(String text, String bg) async {
    final r = await _post('status/post', {'type': 'text', 'text': text, 'bg': bg});
    if (r.ok) await refreshStatus();
    return r;
  }

  Future<ApiResult> postImageStatus(Uint8List jpeg, String caption) async {
    final r = await _post('status/post', {'type': 'image', 'image': base64Encode(jpeg), 'caption': caption},
        timeout: const Duration(seconds: 60));
    if (r.ok) await refreshStatus();
    return r;
  }

  Future<void> markStatusViewed(int id) => _post('status/view', {'status_id': id});

  Future<List<(VoloUser, DateTime)>> statusViewers(int id) async {
    final r = await _post('status/viewers', {'status_id': id});
    final l = r.data['viewers'];
    if (!r.ok || l is! List) return [];
    return l.whereType<Map>().map((v) {
      final t = int.tryParse('${v['viewed_at']}') ?? 0;
      return (VoloUser.fromJson(v), DateTime.fromMillisecondsSinceEpoch(t * 1000));
    }).toList();
  }

  Future<ApiResult> deleteStatus(int id) async {
    final r = await _post('status/delete', {'status_id': id});
    if (r.ok) await refreshStatus();
    return r;
  }

  int get unseenStatusCount => statusFeed.where((g) => !g.allViewed).length;
}
