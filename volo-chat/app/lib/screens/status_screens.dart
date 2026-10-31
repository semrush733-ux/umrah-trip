import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return 'Today, ${DateFormat('HH:mm').format(t)}';
  return 'Yesterday, ${DateFormat('HH:mm').format(t)}';
}

Color _hex(String h) {
  try {
    return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return VoloColors.violet;
  }
}

/// Avatar with a segmented ring (one segment per status; mint = unseen).
class StatusRing extends StatelessWidget {
  final VoloUser user;
  final int count;
  final bool allViewed;
  final double radius;
  const StatusRing({super.key, required this.user, required this.count, required this.allViewed, this.radius = 26});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingPainter(count, allViewed ? Colors.grey : VoloColors.mint),
        child: Padding(padding: const EdgeInsets.all(4), child: UserAvatar(name: user.displayName, url: user.avatar, radius: radius)),
      );
}

class _RingPainter extends CustomPainter {
  final int n;
  final Color color;
  _RingPainter(this.n, this.color);
  @override
  void paint(Canvas c, Size s) {
    if (n <= 0) return;
    final rect = Offset.zero & s;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final gap = n == 1 ? 0.0 : 0.12;
    final sweep = (2 * math.pi - gap * n) / n;
    for (var i = 0; i < n; i++) {
      c.drawArc(rect.deflate(1.5), -math.pi / 2 + i * (sweep + gap), sweep, false, p);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.n != n || o.color != color;
}

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  Future<void> _photo(BuildContext context) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1440, imageQuality: 80);
    if (x == null || !context.mounted) return;
    final bytes = await x.readAsBytes();
    if (!context.mounted) return;
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add a caption'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, height: 220, fit: BoxFit.cover)),
            const SizedBox(height: 10),
            TextField(controller: c, decoration: const InputDecoration(hintText: 'Caption (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Post')),
          ],
        );
      },
    );
    if (caption == null || !context.mounted) return;
    final r = await context.read<SocialService>().postImageStatus(bytes, caption);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'Status posted' : (r.error ?? 'Failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialService>();
    final me = context.watch<AccountService>().me;
    final unseen = s.statusFeed.where((g) => !g.allViewed).toList();
    final seen = s.statusFeed.where((g) => g.allViewed).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'st_text',
          backgroundColor: VoloColors.violet,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextStatusComposer())),
          child: const Icon(Icons.edit_rounded),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'st_photo',
          backgroundColor: VoloColors.mint,
          foregroundColor: VoloColors.ink,
          onPressed: () => _photo(context),
          child: const Icon(Icons.photo_camera_rounded),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: s.refreshStatus,
        child: ListView(children: [
          if (me != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: s.myStatus.isEmpty
                  ? Stack(children: [
                      UserAvatar(name: me.displayName, url: me.avatar, radius: 28),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(radius: 10, backgroundColor: VoloColors.mint, child: Icon(Icons.add, size: 14, color: VoloColors.ink)),
                      ),
                    ])
                  : StatusRing(user: me, count: s.myStatus.length, allViewed: false, radius: 26),
              title: const Text('My status', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(s.myStatus.isEmpty
                  ? 'Tap to add a status update'
                  : '${s.myStatus.length} update${s.myStatus.length == 1 ? '' : 's'} · ${_ago(s.myStatus.last.at)}'),
              onTap: () {
                if (s.myStatus.isEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextStatusComposer()));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true, builder: (_) => StatusViewer(group: StatusGroup(me, s.myStatus), mine: true)));
                }
              },
            ),
          if (unseen.isNotEmpty) const _Header('Recent updates'),
          ...unseen.map((g) => _row(context, g)),
          if (seen.isNotEmpty) const _Header('Viewed updates'),
          ...seen.map((g) => _row(context, g)),
          if (s.statusFeed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No status updates from your contacts yet.\nStatus disappears after 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
          const SizedBox(height: 120),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, StatusGroup g) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: StatusRing(user: g.user, count: g.items.length, allViewed: g.allViewed),
        title: Text(g.user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_ago(g.items.last.at)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => StatusViewer(group: g))),
      );
}

class _Header extends StatelessWidget {
  final String t;
  const _Header(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t,
            style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      );
}

/// Write a coloured text status.
class TextStatusComposer extends StatefulWidget {
  const TextStatusComposer({super.key});
  @override
  State<TextStatusComposer> createState() => _TextStatusComposerState();
}

class _TextStatusComposerState extends State<TextStatusComposer> {
  static const _colors = ['#6C4CF1', '#12B981', '#E8505B', '#F59E0B', '#0EA5E9', '#111827', '#DB2777', '#7C3AED'];
  int _ci = 0;
  final _t = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hex(_colors[_ci]);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Colour',
            icon: const Icon(Icons.palette_rounded),
            onPressed: () => setState(() => _ci = (_ci + 1) % _colors.length),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: TextField(
            controller: _t,
            autofocus: true,
            maxLines: null,
            maxLength: 700,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Type a status',
              hintStyle: TextStyle(color: Colors.white54),
              filled: false,
              border: InputBorder.none,
              counterStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VoloColors.mint,
        foregroundColor: VoloColors.ink,
        onPressed: _busy
            ? null
            : () async {
                if (_t.text.trim().isEmpty) return;
                setState(() => _busy = true);
                final r = await context.read<SocialService>().postTextStatus(_t.text.trim(), _colors[_ci]);
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (r.ok) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'Failed')));
                }
              },
        child: _busy ? const CircularProgressIndicator() : const Icon(Icons.send_rounded),
      ),
    );
  }
}

/// Full-screen story viewer with progress bars; tap right/left to move.
class StatusViewer extends StatefulWidget {
  final StatusGroup group;
  final bool mine;
  const StatusViewer({super.key, required this.group, this.mine = false});
  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  int _i = 0;
  bool _paused = false;

  List<StatusItem> get _items => widget.group.items;

  @override
  void initState() {
    super.initState();
    // Start at the first unseen update.
    final first = _items.indexWhere((s) => !s.viewed);
    _i = widget.mine || first < 0 ? 0 : first;
    _a.addStatusListener((st) {
      if (st == AnimationStatus.completed) _next();
    });
    _show();
  }

  void _show() {
    if (!widget.mine) context.read<SocialService>().markStatusViewed(_items[_i].id);
    _a.forward(from: 0);
  }

  void _next() {
    if (_i < _items.length - 1) {
      setState(() => _i++);
      _show();
    } else {
      context.read<SocialService>().refreshStatus();
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
      _show();
    } else {
      _a.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Future<void> _viewers() async {
    _a.stop();
    final list = await context.read<SocialService>().statusViewers(_items[_i].id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Viewed by ${list.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        ...list.map((v) => ListTile(
              leading: UserAvatar(name: v.$1.displayName, url: v.$1.avatar),
              title: Text(v.$1.displayName),
              subtitle: Text(_ago(v.$2)),
            )),
      ]),
    );
    if (mounted) _a.forward();
  }

  @override
  Widget build(BuildContext context) {
    final it = _items[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.sizeOf(context).width;
          d.globalPosition.dx < w / 3 ? _prev() : _next();
        },
        onLongPressStart: (_) {
          _paused = true;
          _a.stop();
        },
        onLongPressEnd: (_) {
          if (_paused) _a.forward();
          _paused = false;
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Stack(fit: StackFit.expand, children: [
          if (it.type == 'image')
            Image.network(it.body,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60)))
          else
            Container(
              color: _hex(it.bg),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: Text(it.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.3)),
            ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: List.generate(_items.length, (k) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _a,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: k < _i ? 1 : (k == _i ? _a.value : 0),
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              ListTile(
                leading: UserAvatar(name: widget.group.user.displayName, url: widget.group.user.avatar),
                title: Text(widget.mine ? 'My status' : widget.group.user.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Text(_ago(it.at), style: const TextStyle(color: Colors.white70)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.mine)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      onPressed: () async {
                        _a.stop();
                        await context.read<SocialService>().deleteStatus(it.id);
                        if (context.mounted) Navigator.of(context).maybePop();
                      },
                    ),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
                ]),
              ),
              const Spacer(),
              if (it.caption.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.black45,
                  padding: const EdgeInsets.all(16),
                  child: Text(it.caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              if (widget.mine)
                TextButton.icon(
                  onPressed: _viewers,
                  icon: const Icon(Icons.visibility_rounded, color: Colors.white),
                  label: Text('${it.views} views', style: const TextStyle(color: Colors.white)),
                ),
              const SizedBox(height: 12),
            ]),
          ),
        ]),
      ),
    );
  }
}
