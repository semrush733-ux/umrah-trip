import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/account_service.dart';
import '../services/device_state.dart';
import '../services/ringtone_service.dart';
import '../services/social_service.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import 'chat_widgets.dart';

/// "I'm lost / I need help": hold the button → your location goes to your
/// partner and family groups straight away, then a 15-second voice clip.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

enum _SosPhase { ready, sending, recording, done, failed }

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  _SosPhase _phase = _SosPhase.ready;
  bool _includeFriends = false;
  String _msg = '';
  List<String> _sentTo = [];
  final AudioRecorder _rec = AudioRecorder();
  Timer? _recTimer;
  int _recLeft = 15;
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _trigger();
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    _recTimer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  String _nameFor(String thread, SocialService s) {
    final g = s.groupFor(thread);
    if (g != null) return g.name;
    for (final c in s.contacts) {
      if (c.thread == thread) return c.user.displayName;
    }
    return 'Contact';
  }

  Future<void> _trigger() async {
    HapticFeedback.heavyImpact();
    final social = context.read<SocialService>();
    final app = context.read<DeviceState>();
    final threads = social.sosThreads(includeContacts: _includeFriends);
    if (threads.isEmpty) {
      setState(() {
        _phase = _SosPhase.failed;
        _msg = 'No one to alert yet. Add contacts or create a family group first.';
      });
      return;
    }
    setState(() {
      _phase = _SosPhase.sending;
      _msg = 'Getting your location…';
    });
    try {
      await app.refreshLocation().timeout(const Duration(seconds: 8));
    } catch (_) {}
    final p = app.position;
    final r = await social.sendSos(threads, lat: p?.latitude, lng: p?.longitude, acc: p?.accuracy);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _phase = _SosPhase.failed;
        _msg = r.error ?? 'Could not send the alert. Check your internet.';
      });
      return;
    }
    _sentTo = threads.map((t) => _nameFor(t, social)).toList();
    await _recordClip(threads);
  }

  Future<void> _recordClip(List<String> threads) async {
    try {
      if (!await _rec.hasPermission()) throw 'no mic';
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 40000, sampleRate: 22050, numChannels: 1),
          path: _recPath!);
      setState(() {
        _phase = _SosPhase.recording;
        _recLeft = 15;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recLeft--);
        if (_recLeft <= 0) {
          t.cancel();
          _finishClip(threads);
        }
      });
    } catch (_) {
      setState(() => _phase = _SosPhase.done);
    }
  }

  Future<void> _finishClip(List<String> threads, {bool send = true}) async {
    _recTimer?.cancel();
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    path ??= _recPath;
    if (mounted) setState(() => _phase = _SosPhase.done);
    if (!send || path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final social = context.read<SocialService>();
      final secs = 15 - _recLeft.clamp(0, 15);
      for (final t in threads) {
        await social.sendVoice(t, bytes, secs <= 0 ? 15 : secs);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final acct = context.watch<AccountService>();
    final targets = social.sosThreads(includeContacts: _includeFriends);
    return Scaffold(
      backgroundColor: const Color(0xFF3B0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('SOS — I need help'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_phase == _SosPhase.ready) ...[
              const Text(
                'Hold the button for 2 seconds. Your location is sent at once, then a 15-second voice clip is recorded and sent too.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTapDown: (_) => _hold.forward(from: 0),
                  onTapUp: (_) {
                    if (_hold.status != AnimationStatus.completed) _hold.reverse();
                  },
                  onTapCancel: () {
                    if (_hold.status != AnimationStatus.completed) _hold.reverse();
                  },
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (_, __) => Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: 10,
                          color: Colors.white,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.6), blurRadius: 30)],
                        ),
                        alignment: Alignment.center,
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.sos_rounded, color: Colors.white, size: 64),
                          Text('HOLD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Will alert:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      targets.isEmpty
                          ? 'Nobody yet — add contacts or a family group.'
                          : targets.map((t) => _nameFor(t, social)).join(', '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (acct.loggedIn && social.groups.isNotEmpty && social.contacts.isNotEmpty)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _includeFriends,
                        onChanged: (v) => setState(() => _includeFriends = v),
                        title: const Text('Also alert all my contacts', style: TextStyle(color: Colors.white)),
                      ),
                  ]),
                ),
              ),
            ],
            if (_phase == _SosPhase.sending)
              _status(Icons.send_rounded, 'Sending alert…', _msg, busy: true),
            if (_phase == _SosPhase.recording) ...[
              _status(Icons.check_circle_rounded, 'Alert sent ✅', 'Sent to ${_sentTo.join(', ')}.'),
              const SizedBox(height: 12),
              _status(Icons.mic_rounded, 'Recording voice clip… $_recLeft s',
                  'Say where you are or what happened.'),
              TextButton(
                onPressed: () => _finishClip(context.read<SocialService>().sosThreads(includeContacts: _includeFriends)),
                child: const Text('Send clip now', style: TextStyle(color: Colors.white)),
              ),
            ],
            if (_phase == _SosPhase.done)
              _status(Icons.check_circle_rounded, 'Help is on the way',
                  'Alert sent to ${_sentTo.join(', ')} with your location. Stay where you are if you can.'),
            if (_phase == _SosPhase.failed) _status(Icons.error_rounded, 'Not sent', _msg),
            if (_phase != _SosPhase.ready) ...[
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(50)),
              onPressed: () => launchUrl(Uri.parse('tel:911')),
              icon: const Icon(Icons.local_hospital_rounded),
              label: const Text('Saudi emergency: 911'),
            ),
            const SizedBox(height: 6),
            const Text('911 = police, ambulance & fire in Makkah, Madinah and Riyadh (997 ambulance, 999 police elsewhere).',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _status(IconData icon, String title, String body, {bool busy = false}) => Card(
        color: Colors.white10,
        child: ListTile(
          leading: busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
              : Icon(icon, color: Colors.white, size: 30),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          subtitle: Text(body, style: const TextStyle(color: Colors.white70)),
        ),
      );
}

/// Full-screen alert when someone you know sends an SOS.
class SosAlertScreen extends StatefulWidget {
  final SosAlert alert;
  const SosAlertScreen({super.key, required this.alert});
  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  @override
  void initState() {
    super.initState();
    RingtoneService.instance.startRingtone();
    // Ring for up to 30 s, then stay silent on screen.
    Future.delayed(const Duration(seconds: 30), RingtoneService.instance.stop);
  }

  @override
  void dispose() {
    RingtoneService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final social = context.read<SocialService>();
    final canCall = !a.thread.startsWith('grp:');
    final dist = (a.lat != null && a.lng != null) ? distanceFromMe(context, a.lat!, a.lng!) : null;
    String title = a.from;
    final g = social.groupFor(a.thread);
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.sos_rounded, color: Colors.white, size: 90),
              const SizedBox(height: 10),
              Text('${a.from} needs help',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              if (g != null)
                Text('in ${g.name}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                a.lat == null
                    ? 'Their location was not available.'
                    : dist != null
                        ? '${fmtDistance(dist)} from you'
                        : 'Location received',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Spacer(),
              if (a.audio != null && a.audio!.isNotEmpty) ...[
                Center(child: VoiceNote(url: a.audio!, seconds: 15, color: Colors.white, accent: Colors.white)),
                const SizedBox(height: 16),
              ],
              if (a.lat != null && a.lng != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.red.shade900,
                      minimumSize: const Size.fromHeight(54)),
                  onPressed: () {
                    RingtoneService.instance.stop();
                    openWalkingRoute(a.lat!, a.lng!);
                  },
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: const Text('Go to them', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 10),
              Row(children: [
                if (canCall)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                          minimumSize: const Size.fromHeight(50)),
                      onPressed: () {
                        RingtoneService.instance.stop();
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => CallScreen.outgoing(
                                thread: a.thread, peerName: a.from, video: false,
                                peerAvatar: social.avatarFor(a.thread))));
                      },
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call'),
                    ),
                  ),
                if (canCall) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(50)),
                    onPressed: () {
                      RingtoneService.instance.stop();
                      if (g != null) title = g.name;
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => ChatScreen(thread: a.thread, title: title)));
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Open chat'),
                  ),
                ),
              ]),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
