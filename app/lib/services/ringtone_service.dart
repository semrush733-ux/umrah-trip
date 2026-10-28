import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Call sounds: the "tuu… tuu…" ringback the caller hears while the other
/// phone rings, and the ringtone (+ vibration) for an incoming call.
class RingtoneService {
  static final RingtoneService instance = RingtoneService._();
  RingtoneService._();

  AudioPlayer? _player;
  Timer? _vibrate;

  static final _ringbackContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.allowBluetooth,
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.voiceCommunicationSignalling,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  static final _ringtoneContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
  );

  Future<void> _play(String asset, AudioContext ctx, double volume) async {
    await stop();
    try {
      final p = AudioPlayer();
      _player = p;
      await p.setAudioContext(ctx);
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume);
      await p.play(AssetSource(asset));
    } catch (_) {
      // Sounds are a nicety — never break a call because of them.
    }
  }

  /// Caller side: plays while the other phone is ringing.
  Future<void> startRingback() => _play('sounds/ringback.wav', _ringbackContext, 0.7);

  /// Callee side: ringtone + vibration until answered/declined.
  Future<void> startRingtone() async {
    await _play('sounds/ringtone.wav', _ringtoneContext, 1.0);
    _vibrate?.cancel();
    HapticFeedback.vibrate();
    _vibrate = Timer.periodic(const Duration(milliseconds: 1500), (_) => HapticFeedback.vibrate());
  }

  Future<void> stop() async {
    _vibrate?.cancel();
    _vibrate = null;
    final p = _player;
    _player = null;
    if (p != null) {
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
  }
}
