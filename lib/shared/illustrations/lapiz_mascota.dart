import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion.dart';

/// El lápiz, mascota de Tu Cajón (viewBox 150×210).
///
/// [LapizMascota.saludando] flota suavemente (2.4 s, ida y vuelta) y agita
/// el brazo derecho (1.8 s). [LapizMascota.quieto] es la versión sin
/// animación, con los dos brazos abajo, que aparece en "Agregar documento".
class LapizMascota extends StatefulWidget {
  const LapizMascota.saludando({super.key, this.width = 140}) : animado = true;
  const LapizMascota.quieto({super.key, this.width = 68}) : animado = false;

  final double width;
  final bool animado;

  @override
  State<LapizMascota> createState() => _LapizMascotaState();
}

class _LapizMascotaState extends State<LapizMascota> with TickerProviderStateMixin {
  static const _vbW = 150.0;
  static const _vbH = 210.0;

  late final AnimationController _flota = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _saluda = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mover = widget.animado && !Motion.reduced(context);
    if (mover) {
      if (!_flota.isAnimating) _flota.repeat(reverse: true);
      if (!_saluda.isAnimating) _saluda.repeat();
    } else {
      _flota.stop();
      _saluda.stop();
    }
  }

  @override
  void dispose() {
    _flota.dispose();
    _saluda.dispose();
    super.dispose();
  }

  Widget _capa(String body, double w, double h) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $_vbW $_vbH">$body</svg>',
    width: w,
    height: h,
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.width / _vbW;
    final w = widget.width;
    final h = _vbH * s;

    if (!widget.animado) {
      return ExcludeSemantics(child: _capa(_quieto, w, h));
    }

    // El brazo gira sobre el hombro (106,108), pero ese punto está dentro del
    // grupo rotado -6° alrededor de (75,110). Rotado queda en ≈(105.6,104.8).
    const pivote = Offset(105.6, 104.8);

    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            _capa(_sombra, w, h),
            AnimatedBuilder(
              animation: Listenable.merge([_flota, _saluda]),
              builder: (context, _) {
                final dy = -5 * s * Curves.easeInOut.transform(_flota.value);
                // 0 → -18° → 0 con ease-in-out en cada mitad.
                final v = _saluda.value;
                final tramo = v < 0.5 ? v * 2 : (1 - v) * 2;
                final angulo = -18 * math.pi / 180 * Curves.easeInOut.transform(tramo);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Stack(
                    children: [
                      Transform.rotate(
                        angle: angulo,
                        alignment: Alignment.topLeft,
                        origin: pivote * s,
                        child: _capa(_brazoSaludo, w, h),
                      ),
                      _capa(_cuerpoSaludando, w, h),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _sombra = '<ellipse cx="75" cy="203" rx="34" ry="5" fill="#E2D8C8"/>';

  static const _brazoSaludo =
      '<g transform="rotate(-6 75 110)">'
      '<path d="M104 108 C 118 100, 124 88, 126 76" fill="none" stroke="#3B3A36" stroke-width="3.5" stroke-linecap="round"/>'
      '<circle cx="126.5" cy="72" r="5" fill="#3B3A36"/>'
      '</g>';

  static const _cuerpoSaludando =
      '<g transform="rotate(-6 75 110)">'
      '<path d="M46 114 C 34 120, 28 130, 26 140" fill="none" stroke="#3B3A36" stroke-width="3.5" stroke-linecap="round"/>'
      '<rect x="45" y="12" width="60" height="28" rx="11" fill="#D9908A"/>'
      '<rect x="43" y="34" width="64" height="16" rx="3" fill="#B7BAB3"/>'
      '<rect x="43" y="39" width="64" height="2.5" fill="#9FA29B"/>'
      '<rect x="43" y="44" width="64" height="2.5" fill="#9FA29B"/>'
      '<rect x="45" y="50" width="20" height="104" fill="#E6BD5E"/>'
      '<rect x="65" y="50" width="20" height="104" fill="#DCAE4A"/>'
      '<rect x="85" y="50" width="20" height="104" fill="#C99A3C"/>'
      '<path d="M45 154 L75 196 L105 154 Z" fill="#EBCB9F"/>'
      '<path d="M66 183.5 L75 196 L84 183.5 Z" fill="#3B3A36"/>'
      '<circle cx="63" cy="92" r="5.5" fill="#2B2A27"/>'
      '<circle cx="87" cy="92" r="5.5" fill="#2B2A27"/>'
      '<circle cx="64.8" cy="90" r="1.8" fill="#FFFFFF"/>'
      '<circle cx="88.8" cy="90" r="1.8" fill="#FFFFFF"/>'
      '<ellipse cx="55" cy="104" rx="6" ry="3.8" fill="#E58F7A" opacity="0.55"/>'
      '<ellipse cx="95" cy="104" rx="6" ry="3.8" fill="#E58F7A" opacity="0.55"/>'
      '<path d="M66 104 Q75 113 84 104" fill="none" stroke="#2B2A27" stroke-width="3" stroke-linecap="round"/>'
      '</g>';

  static const _quieto =
      '<g transform="rotate(-6 75 110)">'
      '<path d="M46 114 C 34 120, 28 130, 26 140" fill="none" stroke="#3B3A36" stroke-width="4" stroke-linecap="round"/>'
      '<path d="M104 110 C 116 116, 122 126, 124 136" fill="none" stroke="#3B3A36" stroke-width="4" stroke-linecap="round"/>'
      '<rect x="45" y="12" width="60" height="28" rx="11" fill="#D9908A"/>'
      '<rect x="43" y="34" width="64" height="16" rx="3" fill="#B7BAB3"/>'
      '<rect x="45" y="50" width="20" height="104" fill="#E6BD5E"/>'
      '<rect x="65" y="50" width="20" height="104" fill="#DCAE4A"/>'
      '<rect x="85" y="50" width="20" height="104" fill="#C99A3C"/>'
      '<path d="M45 154 L75 196 L105 154 Z" fill="#EBCB9F"/>'
      '<path d="M66 183.5 L75 196 L84 183.5 Z" fill="#3B3A36"/>'
      '<circle cx="63" cy="92" r="6" fill="#2B2A27"/>'
      '<circle cx="87" cy="92" r="6" fill="#2B2A27"/>'
      '<circle cx="65" cy="90" r="2" fill="#FFFFFF"/>'
      '<circle cx="89" cy="90" r="2" fill="#FFFFFF"/>'
      '<path d="M66 104 Q75 113 84 104" fill="none" stroke="#2B2A27" stroke-width="3.5" stroke-linecap="round"/>'
      '</g>';
}
