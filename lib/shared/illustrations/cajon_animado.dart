import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import 'cajon_dibujo.dart';

/// El cajón del ícono en la pantalla de carga, con una entrada animada:
///  1. el mueble aparece con un pequeño rebote,
///  2. caen los papeles a la bandeja uno por uno (el RUT, la cédula y la
///     hoja); el mueble se aplasta un poquito con cada uno,
///  3. la cerradura da una vuelta, brilla y salen unas estrellitas: los
///     papeles quedaron guardados con llave.
///
/// Después queda en reposo: los papeles se mecen suave y la cerradura brilla
/// de vez en cuando. Si el celular pide reducir animaciones, se ve quieto.
class CajonAnimado extends StatefulWidget {
  const CajonAnimado({super.key, this.width = 240});

  final double width;

  @override
  State<CajonAnimado> createState() => _CajonAnimadoState();
}

class _CajonAnimadoState extends State<CajonAnimado> with TickerProviderStateMixin {
  /// Duración de la entrada, en milisegundos.
  static const _total = 2600.0;

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total.round()),
  )..addStatusListener(_alTerminarEntrada);

  /// Vaivén de reposo, en bucle.
  late final AnimationController _reposo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  /// Sube el vaivén de a poco, para que no arranque de golpe.
  late final AnimationController _calma = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Animation<double> _tramo(double desde, double hasta, [Curve curva = Curves.linear]) => CurvedAnimation(
    parent: _entrada,
    curve: Interval(desde / _total, hasta / _total, curve: curva),
  );

  late final _aparece = _tramo(0, 560, Curves.easeOutBack);

  /// Cuándo empieza a caer cada papel (cédula, RUT, hoja) y cuánto tarda.
  static const _inicioCaida = [700.0, 460.0, 940.0];
  static const _duracionCaida = 620.0;
  late final _caidas = [
    for (final inicio in _inicioCaida) _tramo(inicio, inicio + _duracionCaida, const _Caida()),
  ];

  late final _giro = _tramo(1620, 2140, Curves.easeInOut);
  late final _brillo = _tramo(1900, 2420);
  late final _destellos = _tramo(2020, 2600, Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _entrada.value = 1;
      _reposo.stop();
    } else if (_entrada.value == 0 && !_entrada.isAnimating) {
      _entrada.forward();
    }
  }

  void _alTerminarEntrada(AnimationStatus estado) {
    if (!mounted || estado != AnimationStatus.completed || Motion.reduced(context)) return;
    _calma.forward();
    _reposo.repeat();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _reposo.dispose();
    _calma.dispose();
    super.dispose();
  }

  /// El golpecito en el mueble justo cuando cae cada papel.
  double _hundir() {
    final ms = _entrada.value * _total;
    var h = 0.0;
    for (final inicio in _inicioCaida) {
      final u = (ms - (inicio + _duracionCaida * _Caida.aterriza)) / 220;
      if (u > 0 && u < 1) h += math.sin(math.pi * u);
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrada, _reposo, _calma]),
        builder: (context, _) {
          final a = _aparece.value;
          // En reposo, la cerradura brilla una vez por vuelta.
          final r = _reposo.value;
          final brilloReposo = _reposo.isAnimating && r > 0.55 && r < 0.8 ? (r - 0.55) / 0.25 : 0.0;
          return Opacity(
            opacity: a.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + 0.4 * a,
              alignment: Alignment.bottomCenter,
              child: CajonDibujo(
                width: widget.width,
                pose: PoseCajon(
                  caida: [for (final c in _caidas) c.value],
                  flotar: _calma.value > 0 ? r : null,
                  vaiven: Curves.easeInOut.transform(_calma.value),
                  hundir: _hundir(),
                  giro: math.sin(math.pi * _giro.value),
                  brillo: _brillo.value > 0 && _brillo.value < 1 ? _brillo.value : brilloReposo,
                  destellos: _destellos.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// La caída de un papel: acelera hasta la bandeja ([aterriza]), se hunde un
/// poco, rebota y se acomoda.
class _Caida extends Curve {
  const _Caida();

  /// En qué parte de la caída llega a la bandeja.
  static const aterriza = 0.58;

  @override
  double transformInternal(double t) {
    if (t < aterriza) {
      final u = t / aterriza;
      return u * u;
    }
    final u = (t - aterriza) / (1 - aterriza);
    return 1 + 0.09 * math.sin(2 * math.pi * u) * (1 - u);
  }
}
