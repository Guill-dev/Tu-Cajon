import 'package:flutter/material.dart';

import '../../core/motion.dart';

/// Círculo que crece y se desvanece en bucle (el "latido" del botón de huella).
///
/// [delay] desfasa el anillo dentro del ciclo, para poner dos anillos
/// alternados como en la pantalla de desbloqueo.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.size,
    required this.color,
    this.period = const Duration(seconds: 2),
    this.delay = Duration.zero,
    this.maxScale = 1.6,
    this.startOpacity = 0.45,
  });

  final double size;
  final Color color;
  final Duration period;
  final Duration delay;
  final double maxScale;
  final double startOpacity;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      // Arranca el ciclo ya desfasado según el retraso pedido.
      _c.value = (widget.delay.inMilliseconds / widget.period.inMilliseconds) % 1.0;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return SizedBox.square(dimension: widget.size);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: (widget.startOpacity * (1 - t)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1 + (widget.maxScale - 1) * t,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}
