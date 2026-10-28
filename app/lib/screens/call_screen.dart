import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notifications_service.dart';
import '../services/ringtone_service.dart';
import '../services/social_service.dart';

/// In-app voice/video call over WebRTC. The website only relays one offer
/// and one answer (non-trickle ICE, candidates embedded in the SDP); audio
/// and video flow phone-to-phone (or via TURN when configured).
class CallScreen extends StatefulWidget {
  final String thread;
  final String peerName;
  final bool video;
  final String? peerAvatar; // profile photo URL
  final String? incomingCallId; // set when answering

  const CallScreen.outgoing(
      {super.key,
      required this.thread,
      required this.peerName,
      required this.video,
      this.peerAvatar})
      : incomingCallId = null;

  const CallScreen.incoming(
      {super.key,
      required this.thread,
      required this.peerName,
      required this.video,
      this.peerAvatar,
      required String callId})
      : incomingCallId = callId;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Phase { preparing, ringing, incoming, connecting, connected, ended }

class _CallScreenState extends State<CallScreen> {
  late final SocialService _social;
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  String? _callId;
  _Phase _phase = _Phase.preparing;
  String _status = 'Preparing…';
  bool _muted = false;
  bool _camOff = false;
  bool _speaker = true;
  bool _remoteHasVideo = false;
  Timer? _poll;
  Timer? _clock;
  Timer? _giveUp;
  int _seconds = 0;
  bool _closing = false;
  bool _isCaller = true;
  late bool _video;

  @override
  void initState() {
    super.initState();
    _isCaller = widget.incomingCallId == null;
    _video = widget.video;
    _social = context.read<SocialService>();
    _social.inCall = true;
    _start();
  }

  Future<void> _start() async {
    await _local.initialize();
    await _remote.initialize();
    if (_isCaller) {
      await _startOutgoing();
    } else {
      _callId = widget.incomingCallId;
      _social.markCallHandled(_callId!);
      setState(() {
        _phase = _Phase.incoming;
        _status = _video ? 'Incoming video call' : 'Incoming voice call';
      });
      RingtoneService.instance.startRingtone();
      // Watch for the caller hanging up before we answer.
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _watchIncoming());
    }
  }

  // ---------------- media & peer connection ----------------

  Future<bool> _openMedia() async {
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _video
            ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24}
            : false,
      });
      if (_video) _local.srcObject = _stream;
      await Helper.setSpeakerphoneOn(_video);
      _speaker = _video;
      return true;
    } catch (e) {
      _fail('Microphone${_video ? '/camera' : ''} permission is needed for calls.');
      return false;
    }
  }

  Future<void> _createPc() async {
    _pc = await createPeerConnection({
      'iceServers': _social.iceServers,
      'sdpSemantics': 'unified-plan',
    });
    for (final track in _stream!.getTracks()) {
      await _pc!.addTrack(track, _stream!);
    }
    _pc!.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        _remote.srcObject = e.streams.first;
        if (e.track.kind == 'video' && mounted) setState(() => _remoteHasVideo = true);
      }
    };
    _pc!.onConnectionState = (RTCPeerConnectionState s) {
      if (!mounted) return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _giveUp?.cancel();
        setState(() {
          _phase = _Phase.connected;
          _status = 'Connected';
        });
        _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _fail('Could not connect. The network may block direct calls — the admin can add a TURN server.');
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected &&
          _phase == _Phase.connected) {
        setState(() => _status = 'Reconnecting…');
      }
    };
  }

  /// Waits until ICE gathering completes (max ~4 s) and returns the full SDP.
  Future<Map<String, dynamic>> _completeLocalDescription() async {
    final done = Completer<void>();
    _pc!.onIceGatheringState = (RTCIceGatheringState s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !done.isCompleted) {
        done.complete();
      }
    };
    if (_pc!.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    final d = await _pc!.getLocalDescription();
    return {'type': d?.type ?? '', 'sdp': d?.sdp ?? ''};
  }

  // ---------------- caller ----------------

  Future<void> _startOutgoing() async {
    if (!await _openMedia()) return;
    await _createPc();
    setState(() => _status = 'Calling…');
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _video,
    });
    await _pc!.setLocalDescription(offer);
    final full = await _completeLocalDescription();
    final r = await _social.callStart(widget.thread, full, _video);
    if (!mounted) return;
    if (!r.ok) {
      _fail(r.error ?? 'Could not start the call');
      return;
    }
    if (r.data['busy'] == true) {
      _endWith('${widget.peerName} is on another call');
      return;
    }
    final join = '${r.data['join'] ?? ''}';
    if (join.isNotEmpty) {
      // They were calling us at the same moment — just connect to their call.
      _isCaller = false;
      _callId = join;
      _social.markCallHandled(join);
      if (r.data['video'] == true) _video = true;
      await _accept();
      return;
    }
    _callId = '${r.data['call_id']}';
    _social.markCallHandled(_callId!);
    setState(() {
      _phase = _Phase.ringing;
      _status = 'Ringing…';
    });
    RingtoneService.instance.startRingback();
    _giveUp = Timer(const Duration(seconds: 60), () {
      if (_phase == _Phase.ringing) _hangUp(reason: 'No answer');
    });
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _watchOutgoing());
  }

  bool _answerApplied = false;

  Future<void> _watchOutgoing() async {
    if (_callId == null || _closing) return;
    final c = await _social.callGet(widget.thread, _callId!);
    if (c == null || !mounted) return;
    final st = '${c['status']}';
    if (st == 'declined') { _endWith('Call declined'); return; }
    if (st == 'busy') { _endWith('${widget.peerName} is on another call'); return; }
    if (st == 'ended') { _endWith('Call ended'); return; }
    if (st == 'missed') { _endWith('No answer'); return; }
    final ans = c['answer'];
    if (!_answerApplied && ans is Map && '${ans['sdp']}'.isNotEmpty) {
      _answerApplied = true;
      RingtoneService.instance.stop();
      setState(() {
        _phase = _Phase.connecting;
        _status = 'Connecting…';
      });
      await _pc!.setRemoteDescription(RTCSessionDescription('${ans['sdp']}', '${ans['type']}'));
      _giveUp?.cancel();
      _giveUp = Timer(const Duration(seconds: 25), () {
        if (_phase != _Phase.connected) {
          _fail('Could not connect. The network may block direct calls — the admin can add a TURN server.');
        }
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _watchEnded());
    }
  }

  // ---------------- callee ----------------

  Future<void> _watchIncoming() async {
    if (_callId == null || _closing || _phase != _Phase.incoming) return;
    final c = await _social.callGet(widget.thread, _callId!);
    if (c == null || !mounted) return;
    final st = '${c['status']}';
    if (st != 'ringing') _endWith(st == 'missed' ? 'Missed call' : 'Call ended');
  }

  Future<void> _accept() async {
    _poll?.cancel();
    RingtoneService.instance.stop();
    NotificationsService.instance.cancelCall();
    setState(() {
      _phase = _Phase.connecting;
      _status = 'Connecting…';
    });
    final c = await _social.callGet(widget.thread, _callId!);
    if (!mounted) return;
    final offer = c?['offer'];
    if (c == null || '${c['status']}' != 'ringing' || offer is! Map) {
      _endWith('This call has already ended');
      return;
    }
    if (_stream == null && !await _openMedia()) return;
    if (_stream != null && _video && _local.srcObject == null) {
      // Joined a video call from a voice-call start: reopen with camera.
      try {
        for (final t in _stream!.getTracks()) {
          t.stop();
        }
      } catch (_) {}
      _stream = null;
      if (!await _openMedia()) return;
    }
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    await _createPc();
    await _pc!.setRemoteDescription(RTCSessionDescription('${offer['sdp']}', '${offer['type']}'));
    final answer = await _pc!.createAnswer({});
    await _pc!.setLocalDescription(answer);
    final full = await _completeLocalDescription();
    final r = await _social.callAnswer(widget.thread, _callId!, full);
    if (!mounted) return;
    if (!r.ok) { _fail(r.error ?? 'Could not answer'); return; }
    _giveUp = Timer(const Duration(seconds: 25), () {
      if (_phase != _Phase.connected) {
        _fail('Could not connect. The network may block direct calls — the admin can add a TURN server.');
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _watchEnded());
  }

  Future<void> _decline() async {
    RingtoneService.instance.stop();
    NotificationsService.instance.cancelCall();
    if (_callId != null) await _social.callEnd(widget.thread, _callId!, declined: true);
    _close();
  }

  // ---------------- shared ----------------

  Future<void> _watchEnded() async {
    if (_callId == null || _closing) return;
    final c = await _social.callGet(widget.thread, _callId!);
    if (c == null || !mounted) return;
    final st = '${c['status']}';
    if (st == 'ended' || st == 'declined') _endWith('Call ended');
  }

  void _fail(String msg) {
    if (!mounted || _closing) return;
    if (_callId != null) _social.callEnd(widget.thread, _callId!);
    _endWith(msg);
  }

  Future<void> _hangUp({String reason = 'Call ended'}) async {
    if (_callId != null) await _social.callEnd(widget.thread, _callId!);
    _endWith(reason);
  }

  void _endWith(String msg) {
    if (!mounted || _closing) return;
    setState(() {
      _phase = _Phase.ended;
      _status = msg;
    });
    _teardown();
    Future.delayed(const Duration(milliseconds: 1600), _close);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _teardown();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _teardown() {
    RingtoneService.instance.stop();
    _poll?.cancel();
    _clock?.cancel();
    _giveUp?.cancel();
    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    try {
      _pc?.close();
    } catch (_) {}
    _pc = null;
  }

  @override
  void dispose() {
    _social.inCall = false;
    NotificationsService.instance.cancelCall();
    _teardown();
    _local.srcObject = null;
    _remote.srcObject = null;
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  // ---------------- controls ----------------

  void _toggleMute() {
    _muted = !_muted;
    for (final t in _stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_muted;
    }
    setState(() {});
  }

  void _toggleCam() {
    _camOff = !_camOff;
    for (final t in _stream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_camOff;
    }
    setState(() {});
  }

  Future<void> _switchCam() async {
    final v = _stream?.getVideoTracks();
    if (v != null && v.isNotEmpty) await Helper.switchCamera(v.first);
  }

  Future<void> _toggleSpeaker() async {
    _speaker = !_speaker;
    await Helper.setSpeakerphoneOn(_speaker);
    setState(() {});
  }

  String get _time =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = _video && _remoteHasVideo && _phase == _Phase.connected;
    return PopScope(
      canPop: _phase == _Phase.ended || _closing,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1F1B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (showRemoteVideo)
              RTCVideoView(_remote,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.emerald, Color(0xFF0B1F1B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                ),
              ),
            // Hidden renderer keeps remote audio playing in voice calls.
            if (!showRemoteVideo)
              Positioned(left: 0, top: 0, width: 1, height: 1, child: RTCVideoView(_remote)),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  if (!showRemoteVideo) ...[
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.gold,
                      foregroundImage: (widget.peerAvatar ?? '').isNotEmpty
                          ? NetworkImage(widget.peerAvatar!)
                          : null,
                      child: Text(
                          widget.peerName.isEmpty ? '?' : widget.peerName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.slate)),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(widget.peerName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 8)])),
                  const SizedBox(height: 6),
                  Text(_phase == _Phase.connected ? _time : _status,
                      style: const TextStyle(
                          color: AppColors.goldLight, fontSize: 15, shadows: [Shadow(blurRadius: 8)])),
                  const Spacer(),
                  if (_phase == _Phase.incoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundBtn(
                              icon: Icons.call_end_rounded,
                              color: Colors.redAccent,
                              label: 'Decline',
                              onTap: _decline),
                          _RoundBtn(
                              icon: _video ? Icons.videocam_rounded : Icons.call_rounded,
                              color: Colors.green,
                              label: 'Accept',
                              onTap: _accept),
                        ],
                      ),
                    )
                  else if (_phase != _Phase.ended)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _RoundBtn(
                              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              color: _muted ? Colors.white : Colors.white24,
                              iconColor: _muted ? AppColors.slate : Colors.white,
                              label: _muted ? 'Unmute' : 'Mute',
                              onTap: _toggleMute),
                          if (_video)
                            _RoundBtn(
                                icon: _camOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                color: _camOff ? Colors.white : Colors.white24,
                                iconColor: _camOff ? AppColors.slate : Colors.white,
                                label: 'Camera',
                                onTap: _toggleCam),
                          if (_video)
                            _RoundBtn(
                                icon: Icons.cameraswitch_rounded,
                                color: Colors.white24,
                                label: 'Flip',
                                onTap: _switchCam),
                          _RoundBtn(
                              icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                              color: _speaker ? Colors.white : Colors.white24,
                              iconColor: _speaker ? AppColors.slate : Colors.white,
                              label: 'Speaker',
                              onTap: _toggleSpeaker),
                          _RoundBtn(
                              icon: Icons.call_end_rounded,
                              color: Colors.redAccent,
                              label: 'End',
                              onTap: () => _hangUp()),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 120),
                ],
              ),
            ),

            // Local preview (picture-in-picture)
            if (_video && _stream != null && !_camOff && _phase != _Phase.ended)
              Positioned(
                right: 16,
                top: MediaQuery.paddingOf(context).top + 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(_local,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _RoundBtn(
      {required this.icon,
      required this.color,
      this.iconColor = Colors.white,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 64, height: 64, child: Icon(icon, color: iconColor, size: 30)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
