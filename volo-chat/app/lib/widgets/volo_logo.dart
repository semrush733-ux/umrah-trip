import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The Volo mark: a gradient chat bubble with a bold "V" and a mint pulse.
class VoloLogo extends StatelessWidget {
  final double size;
  const VoloLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final rect = Rect.fromLTWH(0, 0, w, h * 0.86);
    final bubble = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.30));
    final grad = const LinearGradient(
      colors: [Color(0xFF8B6CFF), VoloColors.violetDeep],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & s);
    c.drawShadow(Path()..addRRect(bubble), VoloColors.violet, w * 0.08, true);
    final p = Paint()..shader = grad;
    c.drawRRect(bubble, p);
    // tail
    final tail = Path()
      ..moveTo(w * 0.22, h * 0.80)
      ..lineTo(w * 0.16, h)
      ..lineTo(w * 0.42, h * 0.84)
      ..close();
    c.drawPath(tail, p);
    // V
    final v = Path()
      ..moveTo(w * 0.27, h * 0.24)
      ..lineTo(w * 0.50, h * 0.66)
      ..lineTo(w * 0.73, h * 0.24);
    c.drawPath(
        v,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    // mint dot
    c.drawCircle(Offset(w * 0.84, h * 0.14), w * 0.10, Paint()..color = VoloColors.mint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
