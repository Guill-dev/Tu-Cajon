import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import 'cajon_dibujo.dart';

/// El cajón del ícono, pequeño (pantalla "Abrir el cajón" y "Recibir").
///
/// Con [abierto] la cerradura da un cuarto de vuelta, el cajón azul sale
/// hacia quien mira, los papeles saltan y brillan unas estrellitas.
class CajonMini extends StatefulWidget {
  const CajonMini({super.key, this.width = 104, this.abierto = false});

  final double width;
  final bool abierto;

  @override
  State<CajonMini> createState() => _CajonMiniState();
}

class _CajonMiniState extends State<CajonMini> with SingleTickerProviderStateMixin {
  // Si ya empieza abierto, se ve abierto sin animar.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    value: widget.abierto ? 1 : 0,
  );

  Animation<double> _tramo(double desde, double hasta, Curve curva) => CurvedAnimation(
    parent: _c,
    curve: Interval(desde, hasta, curve: curva),
  );

  late final _giro = _tramo(0, 0.35, Curves.easeInOut);
  late final _afuera = _tramo(0.22, 0.8, Curves.easeOutBack);
  late final _salto = _tramo(0.3, 0.95, Curves.easeOut);
  late final _destellos = _tramo(0.35, 1, Curves.easeOut);

  @override
  void didUpdateWidget(CajonMini old) {
    super.didUpdateWidget(old);
    if (widget.abierto == old.abierto) return;
    if (Motion.reduced(context)) {
      _c.value = widget.abierto ? 1 : 0;
    } else if (widget.abierto) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Al cerrar no hay fiesta: salto y estrellitas solo al abrir.
        final abriendo = _c.status != AnimationStatus.reverse;
        return CajonDibujo(
          width: widget.width,
          pose: PoseCajon(
            giro: _giro.value,
            afuera: _afuera.value,
            salto: abriendo ? math.sin(math.pi * _salto.value) : 0,
            destellos: abriendo ? _destellos.value : 0,
          ),
        );
      },
    );
  }
}
