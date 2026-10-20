import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/pair_state.dart';
import 'experiences_screen.dart';

/// Couple pairing — four ways to link the two phones with ONE security code:
///   1. Show QR on Phone 1 → Scan QR on Phone 2 (camera, after permission)
///   2. Share the code (AirDrop / WhatsApp / any share-sheet app)
///   3. Same-WiFi pairing — both phones tap one button on the same network
///   4. Type the 6-character code manually
/// Live location stays a visible, consensual toggle; either side can un-pair.
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
    _nameCtrl.text = context.read<PairState>().myName;
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

  String get _name =>
      _nameCtrl.text.trim().isEmpty ? 'Pilgrim' : _nameCtrl.text.trim();

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
            'Privacy: pairing is mutual — both phones must use the same code. '
            'Live location is OFF by default, shared only while the toggle is on '
            'and the app is in use. Either of you can stop or un-pair anytime. '
            'Photos are sent only when you tap the camera button and allow the permission.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  // ----------------------------- SETUP -----------------------------

  List<Widget> _setupSection(PairState pair) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your name',
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

      // Method 1+2: create code → QR + share
      _methodCard(
        icon: Icons.qr_code_2_rounded,
        title: 'Phone 1 — Create code',
        subtitle: 'QR banega: Phone 2 scan kare, ya code AirDrop/WhatsApp se bhejein',
        button: FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final code =
                        await context.read<PairState>().createPair(_name);
                    if (code != null && mounted) _showCodeSheet(code);
                  }),
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text('Create security code'),
        ),
      ),

      // Method 3: same WiFi
      _methodCard(
        icon: Icons.wifi_rounded,
        title: 'Same WiFi — automatic',
        subtitle:
            'Dono phones isi WiFi par hon to dono par ye button dabayen (2 minute ke andar) — khud pair ho jayenge',
        button: FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final code =
                        await context.read<PairState>().nearbyPair(_name);
                    if (!mounted) return;
                    if (code != null) {
                      final joined =
                          context.read<PairState>().partner != null;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(joined
                              ? 'Paired ✓'
                              : 'Code $code — ab dusre phone par bhi "Same WiFi" dabayen')));
                    }
                  }),
          icon: const Icon(Icons.wifi_tethering_rounded),
          label: const Text('Pair on same WiFi'),
        ),
      ),

      // Method 1b: scan QR
      _methodCard(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Phone 2 — Scan QR',
        subtitle: 'Phone 1 ke QR ko camera se scan karein (permission ke baad)',
        button: OutlinedButton.icon(
          onPressed: _busy ? null : _scanQr,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan QR code'),
        ),
      ),

      // Method 4: manual code
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.keyboard_rounded, color: AppColors.emerald),
                SizedBox(width: 10),
                Text('Phone 2 — Enter code',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: '6-character code (e.g. AB3K7M)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _run(() => _join(_codeCtrl.text)),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Join with code'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _methodCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Widget button}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.emerald),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: button),
          ],
        ),
      ),
    );
  }

  Future<void> _join(String code) async {
    final ok = await context.read<PairState>().joinPair(code, _name);
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Paired ✓')));
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (code != null && code.isNotEmpty && mounted) {
      await _run(() => _join(code));
    }
  }

  void _showCodeSheet(String code) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scan on the second phone',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: QrImageView(
                  data: 'umrahtrip-pair:$code',
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(code,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: AppColors.emerald)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code)),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Share.share(
                          'Umrah Trip pairing code: $code\nApp mein "Join with code" par ye code dalein.'),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share / AirDrop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------- PAIRED -----------------------------

  List<Widget> _pairedSection(PairState pair) {
    final p = pair.partner;
    final locFresh = p?.locAt != null &&
        DateTime.now().difference(p!.locAt!) < const Duration(minutes: 2);
    return [
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
              if (p == null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.slate,
                            minimumSize: const Size(0, 46)),
                        onPressed: () => _showCodeSheet(pair.code!),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                        label: const Text('Show QR / Share'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size(0, 46)),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await context.read<PairState>().unpair();
                                }),
                        child: const Text('Enter code instead'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // ---- Live location: toggle + in-app map (OpenStreetMap, no key) ----
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
            _LiveMapCard(pair: pair),
            if (p != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        size: 16, color: locFresh ? Colors.redAccent : Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !p.sharing
                            ? '${p.name}: location sharing OFF (unke phone par toggle on karwayen)'
                            : p.lat == null
                                ? '${p.name}: pehli location ka intezar… (unka app khula ho)'
                                : '${p.name}: ${locFresh ? 'LIVE' : 'last seen'} ${p.locAt != null ? DateFormat('HH:mm:ss').format(p.locAt!) : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: locFresh ? Colors.green : Colors.grey),
                      ),
                    ),
                    if (p.sharing && p.lat != null)
                      TextButton.icon(
                        icon: const Icon(Icons.directions_rounded, size: 17),
                        label: const Text('Route', style: TextStyle(fontSize: 12)),
                        onPressed: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=walking'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ---- Photos — WhatsApp style: one tap, instant send ----
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Photos',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  if (pair.uploadingPhoto)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 58),
                          backgroundColor: AppColors.emerald),
                      onPressed: (_busy || pair.uploadingPhoto)
                          ? null
                          : () => _capture(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded, size: 26),
                      label: const Text('Photo bhejo (1-tap)',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: (_busy || pair.uploadingPhoto)
                          ? null
                          : () => _capture(ImageSource.gallery),
                      child: const Icon(Icons.photo_library_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                  'Camera khulta hai → photo lo → khud-ba-khud partner ko chali jati hai.',
                  style: TextStyle(fontSize: 11.5)),
              if (pair.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pair.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final ph = pair.photos[i];
                      return GestureDetector(
                        onTap: () => _viewPhoto(ph.url,
                            '${ph.by} · ${DateFormat('d MMM HH:mm').format(ph.at)}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(ph.url,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 86,
                                      height: 86,
                                      color: Colors.black12,
                                      child: const Icon(
                                          Icons.broken_image_rounded))),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(ph.by,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 9.5)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                          'The code stops working for both of you and shared data on the server is removed.'),
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
                  if (sure == true && mounted) {
                    await context.read<PairState>().unpair();
                  }
                }),
        icon: const Icon(Icons.link_off_rounded),
        label: const Text('Un-pair'),
      ),
    ];
  }

  void _viewPhoto(String url, String caption) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, w, prog) => prog == null
                        ? w
                        : const Padding(
                            padding: EdgeInsets.all(60),
                            child: CircularProgressIndicator())),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(10),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capture(ImageSource source) async {
    final pair = context.read<PairState>();
    await _run(() async {
      try {
        final shot = await ImagePicker().pickImage(
          source: source,
          imageQuality: 45,
          maxWidth: 1080,
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

/// In-app live map (OpenStreetMap — works without any API key):
/// shows MY pin and the PARTNER's pin together, updating with each sync.
class _LiveMapCard extends StatefulWidget {
  final PairState pair;
  const _LiveMapCard({required this.pair});
  @override
  State<_LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<_LiveMapCard> {
  final MapController _controller = MapController();
  bool _didAutoFit = false;

  LatLng? get _me {
    final p = widget.pair.app.position;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  LatLng? get _partner {
    final p = widget.pair.partner;
    return (p != null && p.sharing && p.lat != null && p.lng != null)
        ? LatLng(p.lat!, p.lng!)
        : null;
  }

  void _fit() {
    final pts = [if (_me != null) _me!, if (_partner != null) _partner!];
    if (pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        _controller.move(pts.first, 15);
      } else {
        _controller.fitCamera(CameraFit.coordinates(
            coordinates: pts, padding: const EdgeInsets.all(48)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final partner = _partner;
    final center = partner ?? me ?? const LatLng(21.4225, 39.8262);
    if (!_didAutoFit && (me != null || partner != null)) {
      _didAutoFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 230,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bwpexperts.umrah_journey',
                  ),
                  MarkerLayer(markers: [
                    if (me != null)
                      Marker(
                        point: me,
                        width: 46,
                        height: 46,
                        child: const Column(children: [
                          Icon(Icons.person_pin_circle_rounded,
                              color: Colors.blue, size: 34),
                          Text('Me',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue)),
                        ]),
                      ),
                    if (partner != null)
                      Marker(
                        point: partner,
                        width: 60,
                        height: 50,
                        child: Column(children: [
                          const Icon(Icons.favorite_rounded,
                              color: Colors.redAccent, size: 30),
                          Text(widget.pair.partner!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.redAccent)),
                        ]),
                      ),
                  ]),
                ],
              ),
              // Attribution (OSM requirement)
              Positioned(
                left: 4,
                bottom: 2,
                child: Text('© OpenStreetMap',
                    style: TextStyle(
                        fontSize: 9, color: Colors.black.withValues(alpha: 0.6))),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Column(children: [
                  _mapBtn(Icons.center_focus_strong_rounded, 'Fit both', _fit),
                  const SizedBox(height: 6),
                  if (me != null)
                    _mapBtn(Icons.my_location_rounded, 'Me',
                        () => _controller.move(me, 16)),
                  const SizedBox(height: 6),
                  if (partner != null)
                    _mapBtn(Icons.favorite_rounded, 'Partner',
                        () => _controller.move(partner, 16)),
                ]),
              ),
              if (me == null && partner == null)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: const Text(
                    'Location sharing on karein —\ndono ke pins yahin dikhen ge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapBtn(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(
          tooltip: tip,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: AppColors.emerald),
          onPressed: onTap,
        ),
      );
}

/// Minimal QR scanner — returns the pairing code via Navigator.pop.
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();
  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pairing QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue ?? '';
                final code = raw.startsWith('umrahtrip-pair:')
                    ? raw.substring('umrahtrip-pair:'.length)
                    : (RegExp(r'^[A-Z2-9]{6}$').hasMatch(raw.toUpperCase().trim())
                        ? raw.toUpperCase().trim()
                        : null);
                if (code != null && code.length == 6) {
                  _done = true;
                  Navigator.of(context).pop(code);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 3),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Text(
              'Phone 1 ke "Show QR" ko frame mein layen',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)]),
            ),
          ),
        ],
      ),
    );
  }
}
