import 'dart:ui';

import 'package:flutter/material.dart';

/// Caja con borde punteado (`border: dashed` del diseño).
/// Con `circle: true` dibuja un círculo punteado.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 8,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
    this.fill,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.circle = false,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DashedPainter(
          color: color,
          radius: radius,
          strokeWidth: strokeWidth,
          dash: dash,
          gap: gap,
          fill: fill,
          circle: circle,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    required this.fill,
    required this.circle,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    if (fill != null) canvas.drawPath(path, Paint()..color = fill!);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.radius != radius || old.fill != fill || old.circle != circle;
}
