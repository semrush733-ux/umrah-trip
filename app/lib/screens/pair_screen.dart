import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/pair_state.dart';
import 'experiences_screen.dart';

/// Couple pairing: husband + wife link two phones with ONE security code.
/// Both sides opt in, live location is a visible toggle (foreground only),
/// photos are captured with the camera AFTER the OS permission prompt and
/// sent manually. Either side can stop sharing or un-pair at any time.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});
  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pair = context.read<PairState>();
    _nameCtrl.text = pair.myName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = context.watch<PairState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Couple Pairing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!pair.paired) ..._setupSection(pair) else ..._pairedSection(pair),
          if (pair.lastError != null) ...[
            const SizedBox(height: 10),
            Text(pair.lastError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
          ],
          const SizedBox(height: 24),
          Text(
            'Privacy: pairing is mutual — both phones must enter the same code. '
            'Live location is OFF by default, only shared while the toggle is on '
            'and the app is in use, and either of you can stop or un-pair anytime. '
            'Photos are only sent when you tap the camera button and allow the '
            'camera permission.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  List<Widget> _setupSection(PairState pair) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1) Your name',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Sheraz',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('2) Pair your two phones',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final code = await context
                              .read<PairState>()
                              .createPair(_nameCtrl.text.trim());
                          if (code != null && mounted) {
                            _showCodeDialog(code);
                          }
                        }),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Create security code (Phone 1)'),
              ),
              const SizedBox(height: 14),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR', style: TextStyle(fontSize: 12))),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Enter 6-character code from Phone 1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final ok = await context.read<PairState>().joinPair(
                              _codeCtrl.text, _nameCtrl.text.trim());
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Paired ✓')));
                          }
                        }),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Join with code (Phone 2)'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _showCodeDialog(String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your security code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(code,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: AppColors.emerald)),
            const SizedBox(height: 8),
            const Text(
                'Enter this code on the second phone (Join with code). '
                'Both phones stay linked under this one code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  List<Widget> _pairedSection(PairState pair) {
    final p = pair.partner;
    final locFresh = p?.locAt != null &&
        DateTime.now().difference(p!.locAt!) < const Duration(minutes: 2);
    return [
      // Status / code card
      Card(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.emerald, AppColors.emeraldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.goldLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        p == null
                            ? 'Waiting for partner to join…'
                            : 'Paired with ${p.name}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText('Security code: ${pair.code}',
                  style: TextStyle(
                      color: AppColors.goldLight.withValues(alpha: 0.95),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
              if (pair.lastSyncAt != null)
                Text(
                    'Synced ${DateFormat('HH:mm:ss').format(pair.lastSyncAt!)}'
                    '${p?.lastSeen != null ? ' · ${p!.name} seen ${DateFormat('HH:mm').format(p.lastSeen!)}' : ''}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Live location
      Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: Icon(Icons.share_location_rounded,
                  color: pair.sharingLocation ? Colors.redAccent : AppColors.emerald),
              title: const Text('Share my live location',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(pair.sharingLocation
                  ? 'SHARING NOW — partner can see your pin'
                  : 'Off — nothing is shared'),
              value: pair.sharingLocation,
              onChanged: (v) => pair.setSharing(v),
            ),
            if (p != null)
              ListTile(
                leading: Icon(Icons.person_pin_circle_rounded,
                    color: locFresh ? Colors.green : Colors.grey, size: 30),
                title: Text('${p.name}\'s location',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  !p.sharing
                      ? 'Not sharing right now'
                      : p.lat == null
                          ? 'Waiting for first fix…'
                          : '${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}'
                              '${p.locAt != null ? ' · ${DateFormat('HH:mm:ss').format(p.locAt!)}' : ''}'
                              '${locFresh ? ' · LIVE' : ' · stale'}',
                ),
                trailing: p.sharing && p.lat != null
                    ? IconButton(
                        icon: const Icon(Icons.map_rounded, color: AppColors.emerald),
                        tooltip: 'Open in Maps',
                        onPressed: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}'),
                          mode: LaunchMode.externalApplication,
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Photo share (camera with permission)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send a photo to each other',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                  'Camera opens after you allow the permission; the photo goes '
                  'only to your paired partner.',
                  style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _capture(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
        title: const Text('Shared Experiences',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('What each of you has visited + shared photos'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ExperiencesScreen())),
      ),
      const SizedBox(height: 12),

      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
        onPressed: _busy
            ? null
            : () => _run(() async {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Un-pair both phones?'),
                      content: const Text(
                          'The code stops working for both of you and shared '
                          'data on the server is removed.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Un-pair')),
                      ],
                    ),
                  );
                  if (sure == true) await context.read<PairState>().unpair();
                }),
        icon: const Icon(Icons.link_off_rounded),
        label: const Text('Un-pair'),
      ),
    ];
  }

  Future<void> _capture(ImageSource source) async {
    final pair = context.read<PairState>();
    await _run(() async {
      try {
        // The OS shows the camera/photos permission prompt here; if the user
        // denies it we simply get null back — nothing is captured or sent.
        final shot = await ImagePicker().pickImage(
          source: source,
          imageQuality: 55,
          maxWidth: 1280,
          requestFullMetadata: false,
        );
        if (shot == null) return;
        final bytes = await shot.readAsBytes();
        final ok = await pair.sendPhoto(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Photo sent ✓' : (pair.lastError ?? 'Failed'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Camera unavailable or permission denied ($e)')));
        }
      }
    });
  }
}
