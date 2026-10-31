import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/volo_logo.dart';

/// Full-screen brand gradient with soft floating bubbles.
class VoloBackdrop extends StatefulWidget {
  final Widget child;
  const VoloBackdrop({super.key, required this.child});
  @override
  State<VoloBackdrop> createState() => _VoloBackdropState();
}

class _VoloBackdropState extends State<VoloBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1240), VoloColors.night, Color(0xFF0B2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(size: Size.infinite, painter: _BubblesPainter(_c.value)),
        ),
        widget.child,
      ]),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final double t;
  _BubblesPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final specs = [
      (0.15, 0.20, 90.0, VoloColors.violet),
      (0.85, 0.30, 120.0, VoloColors.mint),
      (0.30, 0.80, 140.0, const Color(0xFF7B5CFF)),
      (0.75, 0.85, 80.0, VoloColors.mint),
    ];
    for (var i = 0; i < specs.length; i++) {
      final (x, y, r, c) = specs[i];
      final a = t * 2 * math.pi + i * 1.7;
      final o = Offset(s.width * x + math.sin(a) * 24, s.height * y + math.cos(a) * 30);
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..color = c.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}

/// Animated logo splash → Welcome or the app.
class SplashScreen extends StatefulWidget {
  final Widget Function() next;
  const SplashScreen({super.key, required this.next});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => widget.next(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.elasticOut));
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    return Scaffold(
      body: VoloBackdrop(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(scale: scale, child: const VoloLogo(size: 120)),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: fade,
              child: const Column(children: [
                Text('Volo Chat',
                    style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 6),
                Text('Talk. Share. Stay close.', style: TextStyle(color: Colors.white70, fontSize: 15)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Three-slide welcome, then phone sign-in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _slides = [
    (Icons.forum_rounded, 'Chat in real time', 'Messages with green ticks, voice notes, photos and replies — fast and simple.'),
    (Icons.videocam_rounded, 'Crystal-clear calls', 'Free HD voice and video calls that connect the moment they pick up.'),
    (Icons.shield_moon_rounded, 'Stay close & safe', 'Status updates, family groups, live location, meeting points and one-tap SOS.'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: VoloBackdrop(
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              VoloLogo(size: 34),
              SizedBox(width: 10),
              Text('Volo Chat', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (icon, title, body) = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: VoloColors.brandGradient,
                          boxShadow: [BoxShadow(color: VoloColors.violet.withValues(alpha: 0.55), blurRadius: 50)],
                        ),
                        child: Icon(icon, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 40),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Text(body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                    ]),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: i == _page ? VoloColors.mint : Colors.white24, borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: VoloColors.mint, foregroundColor: VoloColors.ink),
                  onPressed: () {
                    if (!last) {
                      _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen()));
                    }
                  },
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen())),
              child: const Text('Skip', style: TextStyle(color: Colors.white60)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _Country {
  final String flag, name, code;
  const _Country(this.flag, this.name, this.code);
}

const _countries = [
  _Country('🇵🇰', 'Pakistan', '+92'),
  _Country('🇸🇦', 'Saudi Arabia', '+966'),
  _Country('🇦🇪', 'UAE', '+971'),
  _Country('🇬🇧', 'United Kingdom', '+44'),
  _Country('🇺🇸', 'United States', '+1'),
  _Country('🇮🇳', 'India', '+91'),
  _Country('🇧🇩', 'Bangladesh', '+880'),
  _Country('🇶🇦', 'Qatar', '+974'),
  _Country('🇰🇼', 'Kuwait', '+965'),
  _Country('🇴🇲', 'Oman', '+968'),
  _Country('🇧🇭', 'Bahrain', '+973'),
  _Country('🇹🇷', 'Türkiye', '+90'),
  _Country('🇲🇾', 'Malaysia', '+60'),
  _Country('🇨🇦', 'Canada', '+1'),
  _Country('🇦🇺', 'Australia', '+61'),
  _Country('🇩🇪', 'Germany', '+49'),
];

/// Step 1: phone number.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  _Country _c = _countries.first;
  final _num = TextEditingController();
  bool _busy = false;
  String? _err;

  String get _full {
    var n = _num.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = n.substring(1); // 0300… → 300…
    return '${_c.code}$n';
  }

  Future<void> _next() async {
    final digits = _num.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) {
      setState(() => _err = 'Enter your phone number');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Is this number correct?'),
        content: Text(_full, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Edit')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, send code')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await context.read<AccountService>().startPhone(_full);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      setState(() => _err = r.error);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(phone: '${r.data['phone'] ?? _full}', testMode: r.data['test_mode'] == true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VoloBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            const Text('Enter your phone number',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Volo Chat will send you an SMS with a 6-digit code to verify your number.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
            const SizedBox(height: 30),
            _GlassCard(
              child: Column(children: [
                InkWell(
                  onTap: () async {
                    final c = await showModalBottomSheet<_Country>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => ListView(
                        children: _countries
                            .map((c) => ListTile(
                                  leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                                  title: Text(c.name),
                                  trailing: Text(c.code),
                                  onTap: () => Navigator.pop(ctx, c),
                                ))
                            .toList(),
                      ),
                    );
                    if (c != null) setState(() => _c = c);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Text(_c.flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_c.name, style: const TextStyle(color: Colors.white, fontSize: 16))),
                      const Icon(Icons.expand_more_rounded, color: Colors.white70),
                    ]),
                  ),
                ),
                const Divider(color: Colors.white24),
                Row(children: [
                  Text(_c.code, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _num,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                      style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 1.5),
                      decoration: const InputDecoration(
                        hintText: '300 1234567',
                        hintStyle: TextStyle(color: Colors.white30),
                        filled: false,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _next(),
                    ),
                  ),
                ]),
              ]),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_err!, style: const TextStyle(color: Color(0xFFFF8A8A))),
              ),
            const SizedBox(height: 30),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VoloColors.mint, foregroundColor: VoloColors.ink),
              onPressed: _busy ? null : _next,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Send code'),
            ),
            const SizedBox(height: 16),
            const Text('Carrier SMS charges may apply.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// Step 2: 6-digit SMS code.
class OtpScreen extends StatefulWidget {
  final String phone;
  final bool testMode;
  const OtpScreen({super.key, required this.phone, this.testMode = false});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;
  int _wait = 60;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _t?.cancel();
    setState(() => _wait = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length < 4 || _busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final acct = context.read<AccountService>();
    final r = await acct.verifyCode(widget.phone, _code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      setState(() => _err = r.error);
      return;
    }
    // AppGate (root) decides the next step: profile → email → home.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _resend() async {
    final r = await context.read<AccountService>().startPhone(widget.phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'New code sent' : (r.error ?? 'Failed'))));
    if (r.ok) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final digits = _code.text;
    return Scaffold(
      body: VoloBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            const Text('Verify your number',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Enter the 6-digit code we sent to ${widget.phone}',
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
            if (widget.testMode)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Test mode: use the test code set in the admin panel.',
                    style: TextStyle(color: VoloColors.mint, fontSize: 13)),
              ),
            const SizedBox(height: 34),
            // Six boxes over an invisible text field
            Stack(alignment: Alignment.center, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final filled = i < digits.length;
                  final active = i == digits.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: filled ? 0.16 : 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? VoloColors.mint : Colors.white24, width: active ? 2 : 1),
                    ),
                    child: Text(filled ? digits[i] : '',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  );
                }),
              ),
              Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (v) {
                    setState(() {});
                    if (v.length == 6) _verify();
                  },
                ),
              ),
            ]),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_err!, style: const TextStyle(color: Color(0xFFFF8A8A))),
              ),
            const SizedBox(height: 30),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VoloColors.mint, foregroundColor: VoloColors.ink),
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _wait > 0 ? null : _resend,
              child: Text(_wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code',
                  style: TextStyle(color: _wait > 0 ? Colors.white38 : VoloColors.mint)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Step 3: name, photo, about.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _about = TextEditingController(text: 'Hey there! I am using Volo Chat.');
  bool _busy = false;
  bool _photoBusy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final me = context.read<AccountService>().me;
    if (me != null && me.name.isNotEmpty) _name.text = me.name;
    if (me != null && me.about.isNotEmpty) _about.text = me.about;
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
    if (x == null || !mounted) return;
    setState(() => _photoBusy = true);
    final r = await context.read<AccountService>().setAvatar(await x.readAsBytes());
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (!r.ok) setState(() => _err = r.error);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Please enter your name');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await context.read<AccountService>().updateProfile(name: _name.text.trim(), about: _about.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) setState(() => _err = r.error);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AccountService>().me;
    return Scaffold(
      body: VoloBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 20),
            const Text('Your profile', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Add your name and a photo so your friends recognise you.',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: _photoBusy ? null : _photo,
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: VoloColors.brandGradient),
                    child: UserAvatar(name: _name.text.isEmpty ? '+' : _name.text, url: me?.avatar, radius: 58),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: VoloColors.mint,
                      child: _photoBusy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_rounded, color: VoloColors.ink, size: 19),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 30),
            _GlassCard(
              child: Column(children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    labelStyle: TextStyle(color: Colors.white60),
                    counterStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.person_rounded, color: Colors.white60),
                    filled: false,
                  ),
                ),
                TextField(
                  controller: _about,
                  maxLength: 140,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'About',
                    labelStyle: TextStyle(color: Colors.white60),
                    counterStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.info_outline_rounded, color: Colors.white60),
                    filled: false,
                  ),
                ),
              ]),
            ),
            if (_err != null)
              Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Color(0xFFFF8A8A)))),
            const SizedBox(height: 26),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VoloColors.mint, foregroundColor: VoloColors.ink),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Continue'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Step 4: verify an email address.
class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});
  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _err;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await context.read<AccountService>().sendEmailCode(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _sent = true;
      } else {
        _err = r.error;
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await context.read<AccountService>().verifyEmail(_code.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) setState(() => _err = r.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VoloBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 20),
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: VoloColors.brandGradient),
              child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            const Text('Verify your email', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                _sent
                    ? 'We sent a 6-digit code to ${_email.text.trim()}. Check your inbox (and spam folder).'
                    : 'Add your email to secure your account and recover it if you change phones.',
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
            const SizedBox(height: 26),
            _GlassCard(
              child: !_sent
                  ? TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: TextStyle(color: Colors.white30),
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: Colors.white60),
                        filled: false,
                        border: InputBorder.none,
                      ),
                    )
                  : TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          hintText: '••••••',
                          hintStyle: TextStyle(color: Colors.white30),
                          counterText: '',
                          filled: false,
                          border: InputBorder.none),
                      onChanged: (v) {
                        if (v.length == 6) _verify();
                      },
                    ),
            ),
            if (_err != null)
              Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Color(0xFFFF8A8A)))),
            const SizedBox(height: 26),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VoloColors.mint, foregroundColor: VoloColors.ink),
              onPressed: _busy ? null : (_sent ? _verify : _send),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_sent ? 'Verify email' : 'Send code'),
            ),
            if (_sent)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _sent = false),
                child: const Text('Change email / resend', style: TextStyle(color: VoloColors.mint)),
              ),
            TextButton(
              onPressed: () => context.read<AccountService>().logout(),
              child: const Text('Use a different phone number', style: TextStyle(color: Colors.white38)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      );
}
