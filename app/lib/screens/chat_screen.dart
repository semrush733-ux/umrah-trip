import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/social_service.dart';

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
    if (_social.activeThread == widget.thread) _social.activeThread = null;
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _lastId => _msgs.isEmpty ? 0 : _msgs.last.id;

  Future<void> _load({bool initial = false}) async {
    final res = await _social.poll(widget.thread, initial ? 0 : _lastId);
    if (!mounted) return;
    if (res == null) {
      if (initial) setState(() {
        _loading = false;
        _error = 'Could not load messages. Check your connection and that plugin v1.4 is installed.';
      });
      return;
    }
    final fresh = res.where((m) => !_msgs.any((x) => x.id == m.id)).toList();
    final atBottom = !_scroll.hasClients ||
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
    setState(() {
      _msgs.addAll(fresh);
      _loading = false;
      _error = null;
    });
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
    final url = await _social.startCall(widget.thread, video: video);
    if (!mounted) return;
    if (url == null) {
      _snack('Could not start the call');
      return;
    }
    await _load();
    _toBottom();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
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
                            itemBuilder: (_, i) => _Bubble(
                              m: _msgs[i],
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.emerald, size: 30),
                    onPressed: _sending ? null : _attachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
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
                  IconButton.filled(
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
  const _Bubble({required this.m, required this.showName});

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
              onPressed: url.isEmpty
                  ? null
                  : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded, size: 18),
              label: Text(mine ? 'Rejoin' : 'Join call'),
            ),
          ],
        );
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
              child: Text(time,
                  style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.65))),
            ),
          ],
        ),
      ),
    );
  }
}
