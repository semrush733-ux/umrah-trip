import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';
import 'call_screen.dart';
import 'chat_widgets.dart';
import 'groups_screen.dart';

/// Live chat (polling every 3 s while open) with text, photos, location and
/// one-tap voice/video calls (private Jitsi room).
class ChatScreen extends StatefulWidget {
  final String thread; // dm:<fid> or pair:<code>
  final String title;
  final String? subtitle;
  const ChatScreen({super.key, required this.thread, required this.title, this.subtitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _msgs = [];
  Timer? _timer;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  late final SocialService _social;
  int _peerDelivered = 0;
  int _peerSeen = 0;
  List<String> _typing = const [];
  MeetPoint? _meet;
  // voice notes
  final AudioRecorder _rec = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _recPath;

  bool get _isGroup => widget.thread.startsWith('grp:');

  @override
  void initState() {
    super.initState();
    _social = context.read<SocialService>();
    _social.activeThread = widget.thread;
    _load(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recTimer?.cancel();
    if (_recording) _rec.stop().catchError((_) => null);
    _rec.dispose();
    if (_social.activeThread == widget.thread) _social.activeThread = null;
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _lastId => _msgs.isEmpty ? 0 : _msgs.last.id;

  Future<void> _load({bool initial = false}) async {
    final res = await _social.poll(widget.thread, initial ? 0 : _lastId, seen: _lastId);
    if (!mounted) return;
    if (res == null) {
      if (initial) setState(() {
        _loading = false;
        _error = 'Could not load messages. Check your connection and that plugin v1.7 is installed.';
      });
      return;
    }
    final fresh = res.messages.where((m) => !_msgs.any((x) => x.id == m.id)).toList();
    final atBottom = !_scroll.hasClients ||
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
    setState(() {
      _msgs.addAll(fresh);
      _loading = false;
      _error = null;
      _peerDelivered = res.peerDelivered;
      _peerSeen = res.peerSeen;
      _typing = res.typing;
      _meet = res.meet;
    });
    // Tell the server we've now seen the newest message (next poll carries it).
    if (fresh.isNotEmpty && !initial) _social.poll(widget.thread, _lastId, seen: _lastId);
    if (_msgs.isNotEmpty) _social.markSeen(widget.thread, _msgs.last.id);
    if (fresh.isNotEmpty && (initial || atBottom)) _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await _social.sendText(widget.thread, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _ctrl.clear();
      await _load();
      _toBottom();
    } else {
      _snack(r.error ?? 'Not sent');
    }
  }

  Future<void> _sendPhoto(ImageSource src) async {
    try {
      final shot = await ImagePicker().pickImage(
          source: src, imageQuality: 45, maxWidth: 1080, requestFullMetadata: false);
      if (shot == null) return;
      setState(() => _sending = true);
      final r = await _social.sendImage(widget.thread, await shot.readAsBytes());
      if (!mounted) return;
      setState(() => _sending = false);
      if (r.ok) {
        await _load();
        _toBottom();
      } else {
        _snack(r.error ?? 'Photo not sent');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _snack('Camera or photos permission is needed ($e)');
      }
    }
  }

  Future<void> _sendLocation() async {
    final app = context.read<AppState>();
    await app.refreshLocation();
    final p = app.position;
    if (p == null) {
      _snack('Location is off — please allow location access.');
      return;
    }
    setState(() => _sending = true);
    final r = await _social.sendLocation(widget.thread, p.latitude, p.longitude);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      await _load();
      _toBottom();
    } else {
      _snack(r.error ?? 'Location not sent');
    }
  }

  Future<void> _call({required bool video}) async {
    await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen.outgoing(
            thread: widget.thread,
            peerName: widget.title,
            peerAvatar: _social.avatarFor(widget.thread),
            video: video)));
    if (!mounted) return;
    await _load();
    _toBottom();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _startRecording() async {
    try {
      if (!await _rec.hasPermission()) {
        _snack('Microphone permission is needed for voice messages.');
        return;
      }
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
          const RecordConfig(
              encoder: AudioEncoder.aacLc, bitRate: 40000, sampleRate: 22050, numChannels: 1),
          path: _recPath!);
      setState(() {
        _recording = true;
        _recSeconds = 0;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recSeconds++);
        if (_recSeconds >= 180) _stopRecording(send: true); // 3 min max
      });
    } catch (e) {
      _snack('Could not start recording ($e)');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    final secs = _recSeconds;
    if (mounted) setState(() => _recording = false);
    path ??= _recPath;
    if (!send || path == null) return;
    if (secs < 1) {
      _snack('Hold on a little longer to record a voice message.');
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      setState(() => _sending = true);
      final r = await _social.sendVoice(widget.thread, bytes, secs);
      if (!mounted) return;
      setState(() => _sending = false);
      if (r.ok) {
        await _load();
        _toBottom();
      } else {
        _snack(r.error ?? 'Voice message not sent');
      }
      File(path).delete().catchError((_) => File(path!));
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _snack('Voice message not sent ($e)');
      }
    }
  }

  int _tickFor(ChatMessage m) => !m.mine
      ? -1
      : m.id <= _peerSeen
          ? 2
          : m.id <= _peerDelivered
              ? 1
              : 0;

  void _attachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.emerald),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _sendPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.emerald),
              title: const Text('Photo library'),
              onTap: () {
                Navigator.pop(ctx);
                _sendPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded, color: AppColors.emerald),
              title: const Text('Share my location'),
              onTap: () {
                Navigator.pop(ctx);
                _sendLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          UserAvatar(name: widget.title, url: _social.avatarFor(widget.thread), radius: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (_typing.isNotEmpty)
              Text(_isGroup ? '${_typing.join(', ')} typing…' : 'typing…',
                  style: const TextStyle(fontSize: 12, color: AppColors.goldLight, fontStyle: FontStyle.italic))
            else if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 12)),
          ],
          )),
        ]),
        actions: _isGroup
            ? [
                IconButton(
                  tooltip: 'Group map',
                  icon: const Icon(Icons.map_rounded),
                  onPressed: () {
                    final g = _social.groupFor(widget.thread);
                    if (g != null) {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GroupMapScreen(group: g)));
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Group info',
                  icon: const Icon(Icons.group_rounded),
                  onPressed: () {
                    final g = _social.groupFor(widget.thread);
                    if (g != null) {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: g.id)));
                    }
                  },
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Voice call',
                  icon: const Icon(Icons.call_rounded),
                  onPressed: () => _call(video: false),
                ),
                IconButton(
                  tooltip: 'Video call',
                  icon: const Icon(Icons.videocam_rounded),
                  onPressed: () => _call(video: true),
                ),
              ],
      ),
      body: Column(
        children: [
          if (_meet != null) MeetBanner(meet: _meet!),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center)))
                    : _msgs.isEmpty
                        ? const Center(child: Text('No messages yet — say salam 👋'))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) => _msgs[i].type == 'system'
                                ? SystemNote(text: '${(_msgs[i].body is Map ? (_msgs[i].body as Map)['text'] : _msgs[i].body) ?? ''}')
                                : _Bubble(
                                    thread: widget.thread,
                                    peerName: widget.title,
                                    m: _msgs[i],
                                    tick: _tickFor(_msgs[i]),
                                    showName: !widget.thread.startsWith('dm:') &&
                                        !_msgs[i].mine,
                                  ),
                          ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: _recording
                  ? Row(children: [
                      IconButton(
                        tooltip: 'Cancel',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                        onPressed: () => _stopRecording(send: false),
                      ),
                      const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Recording…  ${(_recSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.emerald),
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: () => _stopRecording(send: true),
                      ),
                    ])
                  : Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.emerald, size: 30),
                    onPressed: _sending ? null : _attachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onChanged: (v) {
                        if (v.trim().isNotEmpty) _social.typing(widget.thread);
                        setState(() {}); // toggles mic ↔ send
                      },
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ctrl.text.trim().isEmpty
                      ? IconButton.filled(
                          tooltip: 'Voice message',
                          style: IconButton.styleFrom(backgroundColor: AppColors.emerald),
                          icon: const Icon(Icons.mic_rounded, color: Colors.white),
                          onPressed: _sending ? null : _startRecording,
                        )
                      : IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppColors.emerald),
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _sending ? null : _send,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool showName;
  final String thread;
  final String peerName;
  final int tick; // -1 none, 0 sent, 1 delivered, 2 seen
  const _Bubble(
      {required this.m,
      required this.showName,
      required this.thread,
      required this.peerName,
      this.tick = -1});

  @override
  Widget build(BuildContext context) {
    final mine = m.mine;
    final bg = mine ? AppColors.emerald : Theme.of(context).colorScheme.surface;
    final fg = mine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final time = DateFormat('HH:mm').format(m.at);

    Widget content;
    switch (m.type) {
      case 'image':
        final url = '${m.body}';
        content = GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(8),
              child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url,
                width: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    width: 220, height: 120, child: Icon(Icons.broken_image_rounded))),
          ),
        );
      case 'location':
        final b = m.body is Map ? m.body as Map : const {};
        final lat = b['lat'], lng = b['lng'];
        content = InkWell(
          onTap: () => launchUrl(
              Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
              mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_rounded, color: mine ? AppColors.goldLight : Colors.redAccent),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Location — tap to open in Maps',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      case 'call':
        final b = m.body is Map ? m.body as Map : const {};
        final video = b['video'] == true;
        final url = '${b['url'] ?? ''}';
        final callId = '${b['call_id'] ?? ''}';
        final fresh = DateTime.now().difference(m.at) < const Duration(minutes: 1);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(video ? Icons.videocam_rounded : Icons.call_rounded,
                  color: mine ? AppColors.goldLight : AppColors.emerald),
              const SizedBox(width: 6),
              Text(mine
                      ? (video ? 'You started a video call' : 'You started a voice call')
                      : (video ? 'Video call' : 'Voice call'),
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: mine ? AppColors.gold : AppColors.emerald,
                  foregroundColor: mine ? AppColors.slate : Colors.white),
              onPressed: callId.isNotEmpty
                  ? (mine || !fresh
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => CallScreen.outgoing(
                              thread: thread,
                              peerName: peerName,
                              peerAvatar: context.read<SocialService>().avatarFor(thread),
                              video: video)))
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => CallScreen.incoming(
                              thread: thread,
                              peerName: m.name,
                              peerAvatar: context.read<SocialService>().avatarFor(thread),
                              video: video,
                              callId: callId))))
                  : (url.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
              icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded, size: 18),
              label: Text(callId.isNotEmpty
                  ? (mine || !fresh ? 'Call back' : 'Answer')
                  : (mine ? 'Rejoin' : 'Join call')),
            ),
          ],
        );
      case 'voice':
        final b = m.body is Map ? m.body as Map : const {};
        content = VoiceNote(
            url: '${b['url'] ?? ''}',
            seconds: int.tryParse('${b['dur'] ?? 0}') ?? 0,
            color: fg,
            accent: mine ? AppColors.goldLight : AppColors.emerald);
      case 'sos':
        content = SosCard(body: m.body is Map ? Map<String, dynamic>.from(m.body as Map) : const {}, from: m.name, mine: mine);
      case 'meet':
        final mp = MeetPoint.fromJson(m.body);
        content = mp == null
            ? Text('📌 Meeting point', style: TextStyle(color: fg))
            : MeetCard(meet: mp, color: fg, mine: mine);
      default:
        content = Text('${m.body}', style: TextStyle(color: fg, fontSize: 15, height: 1.35));
    }

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(m.name,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.gold)),
              ),
            content,
            const SizedBox(height: 2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(time, style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.65))),
                if (tick >= 0) ...[
                  const SizedBox(width: 4),
                  Icon(tick == 0 ? Icons.done_rounded : Icons.done_all_rounded,
                      size: 15,
                      color: tick == 2 ? const Color(0xFF7FD1FF) : fg.withValues(alpha: 0.65)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
