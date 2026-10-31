import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:volo_chat/screens/call_screen.dart';
import 'package:volo_chat/screens/chat_screen.dart';
import 'package:volo_chat/services/account_service.dart';
import 'package:volo_chat/services/device_state.dart';
import 'package:volo_chat/services/social_service.dart';

/// Opens the call screen with all native plugins stubbed and reports any
/// exception thrown while building/starting it (the "white screen" bug).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final log = <String>[];

  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<Object?> stub(MethodCall c) async {
      log.add(c.method);
      switch (c.method) {
        case 'createVideoRenderer':
          return {'textureId': 1};
        case 'getUserMedia':
          return {'streamId': 's1', 'audioTracks': <dynamic>[], 'videoTracks': <dynamic>[]};
        case 'createPeerConnection':
          return {'peerConnectionId': 'pc1'};
        case 'createOffer':
          return {'sdp': 'v=0', 'type': 'offer'};
        case 'getLocalDescription':
          return {'sdp': 'v=0', 'type': 'offer'};
        default:
          return null;
      }
    }

    for (final ch in [
      'FlutterWebRTC.Method',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'dexterous.com/flutter/local_notifications',
      'plugins.flutter.io/shared_preferences',
    ]) {
      m.setMockMethodCallHandler(MethodChannel(ch), stub);
    }
    m.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC/Texture1'), (_) async => null);
    m.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Event'), (_) async => null);
  });

  Widget host(Widget child) {
    final dev = DeviceState();
    final acct = AccountService();
    final social = SocialService(acct, dev);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dev),
        ChangeNotifierProvider.value(value: acct),
        ChangeNotifierProvider.value(value: social),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('outgoing call screen builds without exceptions', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (!s.contains('MissingPluginException')) errors.add('$s\n${d.stack}');
    };
    await tester.pumpWidget(host(const CallScreen.outgoing(
        thread: 'dm:1', peerName: 'Ayesha', video: false)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final ex = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    FlutterError.onError = old;
    // ignore: avoid_print
    print('CALLSCREEN plugin calls: $log');
    // ignore: avoid_print
    print('CALLSCREEN errors: ${errors.isEmpty ? 'none' : errors.join('\n----\n')} / exception: $ex');
    expect(errors, isEmpty);
    expect(ex, isNull);
  });

  testWidgets('incoming + video call screen builds without exceptions', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (!s.contains('MissingPluginException')) errors.add('$s\n${d.stack}');
    };
    await tester.pumpWidget(host(const CallScreen.incoming(
        thread: 'dm:1', peerName: 'Ayesha', video: true, callId: 'abc')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final ex = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    FlutterError.onError = old;
    // ignore: avoid_print
    print('INCOMING errors: ${errors.isEmpty ? 'none' : errors.join('\n----\n')} / exception: $ex');
    expect(errors, isEmpty);
    expect(ex, isNull);
  });

  testWidgets('chat screen builds without exceptions', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (!s.contains('MissingPluginException')) errors.add('$s\n${d.stack}');
    };
    await tester.pumpWidget(host(const ChatScreen(thread: 'dm:1', title: 'Ayesha')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final ex = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    FlutterError.onError = old;
    // ignore: avoid_print
    print('CHAT errors: ${errors.isEmpty ? 'none' : errors.join('\n----\n')} / exception: $ex');
    expect(errors, isEmpty);
    expect(ex, isNull);
  });
}
