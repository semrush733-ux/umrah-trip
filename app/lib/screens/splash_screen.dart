import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';

/// Animated, fully code-driven splash:
///  1. Deep-emerald backdrop with a soft radial golden glow that breathes.
///  2. The Umrah Trip logo scales in with an elastic pop + fade.
///  3. A golden arc orbits the logo like a tawaf ring.
///  4. The wordmark slides up, then the whole screen fades into the app.
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // one-shot entrance
  late final AnimationController _orbit; // repeating ring + glow
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _orbit = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();

    _logoScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _textSlide = Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _intro.forward();
    Future.delayed(const Duration(milliseconds: 2500), _goNext);
  }

  Future<void> _goNext() async {
    if (!mounted || _navigated) return;
    // Wait until startup loading (destinations + saved trip) is done.
    final app = context.read<AppState>();
    while (!app.ready) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }
    _navigated = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.62, 300.0);
    return Scaffold(
      backgroundColor: AppColors.emeraldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Breathing golden glow + emerald gradient backdrop.
          AnimatedBuilder(
            animation: _orbit,
            builder: (context, _) {
              final t = _orbit.value;
              final pulse = 0.55 + 0.15 * math.sin(t * 2 * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 1.1,
                    colors: [
                      Color.lerp(AppColors.emerald, AppColors.gold, 0.12)!
                          .withValues(alpha: pulse),
                      AppColors.emeraldDark,
                      const Color(0xFF032B24),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: logoSize + 56,
                  height: logoSize + 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Orbiting golden tawaf ring.
                      AnimatedBuilder(
                        animation: _orbit,
                        builder: (context, _) => CustomPaint(
                          size: Size.square(logoSize + 56),
                          painter: _OrbitRingPainter(progress: _orbit.value),
                        ),
                      ),
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  blurRadius: 60,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        const Text(
                          'UMRAH TRIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your Smart Umrah & Ziyarat Companion',
                          style: TextStyle(
                            color: AppColors.goldLight.withValues(alpha: 0.95),
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _textFade,
                  child: SizedBox(
                    width: 120,
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) => LinearProgressIndicator(
                        value: null,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // BWP Experts credit
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  Text(
                    'Sponsored by BIN-MUKHTAR TRAVELS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.goldLight.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by BWP Experts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
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

/// Golden arc that orbits the logo with a fading comet tail.
class _OrbitRingPainter extends CustomPainter {
  final double progress;
  _OrbitRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final start = progress * 2 * math.pi;

    // Faint full ring.
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.gold.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, base);

    // Comet arc with gradient tail.
    const sweep = math.pi * 0.85;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          AppColors.gold.withValues(alpha: 0.0),
          AppColors.gold,
          Colors.white,
        ],
        stops: const [0.0, 0.8, 1.0],
        transform: GradientRotation(0),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);

    // Head dot.
    final headAngle = start + sweep;
    final head = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    canvas.drawCircle(head, 4, Paint()..color = Colors.white);
    canvas.drawCircle(
        head, 8, Paint()..color = AppColors.gold.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) => old.progress != progress;
}
