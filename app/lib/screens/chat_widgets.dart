import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/social_service.dart';

String fmtDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

/// Distance from my current position to a point (null if location is off).
double? distanceFromMe(BuildContext context, double lat, double lng) {
  final p = context.watch<AppState>().position;
  if (p == null) return null;
  return const Distance().as(LengthUnit.Meter, LatLng(p.latitude, p.longitude), LatLng(lat, lng));
}

void openWalkingRoute(double lat, double lng) => launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking'),
    mode: LaunchMode.externalApplication);

void openPin(double lat, double lng) => launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    mode: LaunchMode.externalApplication);

/// Small play/pause player for a voice message.
class VoiceNote extends StatefulWidget {
  final String url;
  final int seconds;
  final Color color;
  final Color accent;
  const VoiceNote(
      {super.key, required this.url, required this.seconds, required this.color, required this.accent});
  @override
  State<VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<VoiceNote> {
  AudioPlayer? _player;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _dur = Duration(seconds: widget.seconds);
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    if (_player == null) {
      final p = AudioPlayer();
      _player = p;
      _subs.add(p.onPositionChanged.listen((d) {
        if (mounted) setState(() => _pos = d);
      }));
      _subs.add(p.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _dur = d);
      }));
      _subs.add(p.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _pos = Duration.zero;
          });
        }
      }));
    }
    try {
      if (_playing) {
        await _player!.pause();
        setState(() => _playing = false);
      } else {
        if (_pos == Duration.zero) {
          await _player!.play(UrlSource(widget.url));
        } else {
          await _player!.resume();
        }
        setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not play this voice message')));
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(1, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds <= 0 ? 1 : _dur.inMilliseconds;
    final frac = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 210,
      child: Row(children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: CircleAvatar(
            radius: 19,
            backgroundColor: widget.accent,
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.slate, size: 24),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 4,
                backgroundColor: widget.color.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(widget.accent),
              ),
            ),
            const SizedBox(height: 4),
            Text('🎤 ${_fmt(_playing || _pos > Duration.zero ? _pos : _dur)}',
                style: TextStyle(fontSize: 12, color: widget.color.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }
}

/// Red alert card for an SOS message.
class SosCard extends StatelessWidget {
  final Map<String, dynamic> body;
  final String from;
  final bool mine;
  const SosCard({super.key, required this.body, required this.from, required this.mine});

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse('${body['lat']}');
    final lng = double.tryParse('${body['lng']}');
    final audio = (body['audio'] ?? '').toString();
    final dist = (lat != null && lng != null) ? distanceFromMe(context, lat, lng) : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.red.shade700, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(mine ? '🚨 You sent an SOS alert' : '🚨 SOS — $from needs help',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        if (dist != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${fmtDistance(dist)} from you',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ),
        if (lat == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Location was not available', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (lat != null && lng != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.red.shade800,
                  minimumSize: const Size(0, 36)),
              onPressed: () => openWalkingRoute(lat, lng),
              icon: const Icon(Icons.directions_walk_rounded, size: 18),
              label: const Text('Go to them'),
            ),
          if (lat != null && lng != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size(0, 36)),
              onPressed: () => openPin(lat, lng),
              child: const Text('Map'),
            ),
        ]),
        if (audio.isNotEmpty) ...[
          const SizedBox(height: 8),
          VoiceNote(url: audio, seconds: 15, color: Colors.white, accent: Colors.white),
        ],
      ]),
    );
  }
}

/// A meeting point shared in a chat.
class MeetCard extends StatelessWidget {
  final MeetPoint meet;
  final Color color;
  final bool mine;
  const MeetCard({super.key, required this.meet, required this.color, required this.mine});

  @override
  Widget build(BuildContext context) {
    final dist = distanceFromMe(context, meet.lat, meet.lng);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.push_pin_rounded, color: mine ? AppColors.goldLight : Colors.redAccent),
        const SizedBox(width: 6),
        Flexible(
          child: Text('Meeting point${meet.label.isNotEmpty ? ': ${meet.label}' : ''}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ),
      ]),
      if (dist != null)
        Text('${fmtDistance(dist)} from you', style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 12.5)),
      const SizedBox(height: 6),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            backgroundColor: mine ? AppColors.gold : AppColors.emerald,
            foregroundColor: mine ? AppColors.slate : Colors.white),
        onPressed: () => openWalkingRoute(meet.lat, meet.lng),
        icon: const Icon(Icons.directions_walk_rounded, size: 18),
        label: const Text('Walk there'),
      ),
    ]);
  }
}

/// Pinned strip at the top of a chat showing the current meeting point.
class MeetBanner extends StatelessWidget {
  final MeetPoint meet;
  const MeetBanner({super.key, required this.meet});

  @override
  Widget build(BuildContext context) {
    final dist = distanceFromMe(context, meet.lat, meet.lng);
    return Material(
      color: AppColors.gold.withValues(alpha: 0.22),
      child: InkWell(
        onTap: () => openWalkingRoute(meet.lat, meet.lng),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            const Icon(Icons.push_pin_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meeting point${meet.label.isNotEmpty ? ': ${meet.label}' : ''}'
                '${dist != null ? ' · ${fmtDistance(dist)}' : ''}'
                ' · set by ${meet.by} ${DateFormat('HH:mm').format(meet.at)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.directions_walk_rounded, color: AppColors.emerald),
          ]),
        ),
      ),
    );
  }
}

/// Centered grey line for group events ("Ali added Sara").
class SystemNote extends StatelessWidget {
  final String text;
  const SystemNote({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          ),
        ),
      );
}
