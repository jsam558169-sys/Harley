import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A small speedometer-style dial for showing a stat, playing on the
/// "Motor" half of Motor Café — used on the dashboards instead of plain
/// number tiles. Draws a track arc, a filled progress arc, and a needle-ish
/// tick at the current value.
class GaugeDial extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue; // value at/above this fills the dial completely
  final Color color;
  final String? valueSuffix;

  const GaugeDial({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    this.color = AppColors.rust,
    this.valueSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 108,
          height: 72,
          child: CustomPaint(
            painter: _GaugePainter(fraction: fraction, color: color),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$value${valueSuffix ?? ""}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brown,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.brown, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  _GaugePainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, (size.width - 8));
    const startAngle = math.pi; // 180deg, left side
    const sweep = math.pi; // half circle

    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, trackPaint);
    canvas.drawArc(rect, startAngle, sweep * fraction, false, valuePaint);

    // Needle
    final center = Offset(rect.center.dx, rect.center.dy + rect.height / 2 - 4);
    final needleAngle = startAngle + sweep * fraction;
    final needleLength = rect.width / 2 - 12;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = AppColors.brown
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 3.5, Paint()..color = AppColors.brown);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
