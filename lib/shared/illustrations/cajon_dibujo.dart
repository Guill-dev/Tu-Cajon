import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_text.dart';

/// Cómo está el cajón del ícono en un momento de una animación.
///
/// Todos los valores van de 0 a 1 (las curvas con rebote pueden pasarse un
/// poco, y eso se ve como un rebote).
@immutable
class PoseCajon {
  const PoseCajon({
    this.caida = const [1, 1, 1],
    this.flotar,
    this.vaiven = 1,
    this.salto = 0,
    this.hundir = 0,
    this.giro = 0,
    this.afuera = 0,
    this.brillo = 0,
    this.destellos = 0,
  });

  /// Cuánto ha caído cada papel a la bandeja: 0 = arriba y sin verse,
  /// 1 = en su sitio. Orden: cédula, RUT, hoja.
  final List<double> caida;

  /// Vaivén suave de los papeles en reposo (una vuelta completa de 0 a 1).
  /// `null` = quietos.
  final double? flotar;

  /// Qué tan amplio es ese vaivén (para arrancarlo de a poco).
  final double vaiven;

  /// Los papeles saltan de alegría (0 abajo, 1 lo más alto).
  final double salto;

  /// El mueble se aplasta un poquito cuando cae un papel.
  final double hundir;

  /// Giro de la cerradura: 0 = vertical, 1 = un cuarto de vuelta.
  final double giro;

  /// El cajón azul sale hacia quien mira.
  final double afuera;

  /// Reflejo que cruza la cerradura, de izquierda a derecha.
  final double brillo;

  /// Estrellitas alrededor de la cerradura.
  final double destellos;
}

/// El cajón del ícono de la app (bandeja amarilla, cajón azul con cerradura,
/// cajón rojo y tres papeles), dibujado en código para poder moverlo por
/// partes. El lienzo sigue las medidas del ícono original y mide 1000×900.
class CajonDibujo extends StatelessWidget {
  const CajonDibujo({super.key, required this.width, this.pose = const PoseCajon()});

  final double width;
  final PoseCajon pose;

  /// Alto / ancho del dibujo.
  static const proporcion = 0.9;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size(width, width * proporcion), painter: _PintorCajon(pose)),
    );
  }
}

// Colores del ícono.
const _amarillo = Color(0xFFFFC918);
const _amarilloClaro = Color(0xFFFFDA45);
const _amarilloOscuro = Color(0xFFEAA600);
const _azul = Color(0xFF0C3CAC);
const _azulClaro = Color(0xFF1A4CC0);
const _azulOscuro = Color(0xFF062777);
const _azulHueco = Color(0xFF041746);
const _rojo = Color(0xFFE5222A);
const _rojoClaro = Color(0xFFEE3A3D);
const _rojoOscuro = Color(0xFFA9111A);
const _papel = Color(0xFFFBF9F4);
const _papelBorde = Color(0xFFE6E1D6);
const _linea = Color(0xFFC9CFD8);
const _tinta = Color(0xFF4A4F58);

class _PintorCajon extends CustomPainter {
  _PintorCajon(this.pose);

  final PoseCajon pose;

  // El dibujo usa las coordenadas del ícono de 1254 px; esta es la parte que se ve.
  static const _origen = Offset(127, 150);
  static const _ancho = 1000.0;

  // Piezas del mueble.
  static const _cuerpoAzul = Rect.fromLTRB(183, 566, 1072, 812);
  static const _cuerpoRojo = Rect.fromLTRB(183, 806, 1072, 1022);
  static const _frenteAzul = Rect.fromLTRB(218, 606, 1037, 786);
  static const _frenteRojo = Rect.fromLTRB(218, 834, 1037, 988);
  static const _piso = Offset(627, 1022);
  static const _cerradura = Offset(627, 696);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _ancho;
    canvas
      ..scale(s)
      ..translate(-_origen.dx, -_origen.dy);

    _sombra(canvas);

    // Al caer un papel el mueble se aplasta desde el piso.
    final h = pose.hundir.clamp(0.0, 1.0);
    canvas
      ..save()
      ..translate(_piso.dx, _piso.dy)
      ..scale(1 + 0.012 * h, 1 - 0.035 * h)
      ..translate(-_piso.dx, -_piso.dy);

    _bandejaAtras(canvas);
    canvas
      ..save()
      // Lo que queda dentro de la bandeja no se ve.
      ..clipRect(const Rect.fromLTRB(0, -2000, 2000, 470));
    _papeles(canvas);
    canvas.restore();
    _cuerpo(canvas);
    _cajonRojo(canvas);
    _cajonAzul(canvas);
    _bandejaFrente(canvas);
    canvas.restore();

    _destellos(canvas);
  }

  void _sombra(Canvas c) {
    c.drawOval(
      Rect.fromCenter(center: _piso + const Offset(0, 4), width: 980, height: 46),
      Paint()
        ..color = const Color(0x221B2A4A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  // ── Bandeja amarilla ──────────────────────────────────────────────────

  void _bandejaAtras(Canvas c) {
    // Cara de arriba del borde y el hueco donde entran los papeles.
    c.drawRRect(
      RRect.fromLTRBR(160, 404, 1095, 486, const Radius.circular(28)),
      Paint()..color = _amarilloClaro,
    );
    c.drawRRect(
      RRect.fromLTRBR(226, 430, 1030, 484, const Radius.circular(16)),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 430), const Offset(0, 484), [
          const Color(0xFFD99500),
          _amarilloOscuro,
        ]),
    );
  }

  void _bandejaFrente(Canvas c) {
    final frente = RRect.fromLTRBAndCorners(
      150,
      462,
      1105,
      576,
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: const Radius.circular(24),
      bottomRight: const Radius.circular(24),
    );
    c.drawRRect(
      frente,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 462),
          const Offset(0, 576),
          [const Color(0xFFFFD836), _amarillo, const Color(0xFFF5B400)],
          [0, 0.45, 1],
        ),
    );
    // Brillo del borde de arriba.
    c.drawRRect(
      RRect.fromLTRBR(170, 468, 1085, 478, const Radius.circular(5)),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  // ── Mueble ────────────────────────────────────────────────────────────

  void _cuerpo(Canvas c) {
    c.drawRect(
      _cuerpoAzul,
      Paint()
        ..shader = ui.Gradient.linear(_cuerpoAzul.topCenter, _cuerpoAzul.bottomCenter, [_azulClaro, _azul]),
    );
    c.drawRRect(
      RRect.fromRectAndCorners(
        _cuerpoRojo,
        bottomLeft: const Radius.circular(30),
        bottomRight: const Radius.circular(30),
      ),
      Paint()
        ..shader = ui.Gradient.linear(_cuerpoRojo.topCenter, _cuerpoRojo.bottomCenter, [_rojoClaro, _rojo]),
    );
    // Unión entre los dos cajones.
    c.drawRect(const Rect.fromLTRB(183, 804, 1072, 812), Paint()..color = const Color(0x33000000));
    // Sombra de la bandeja sobre el cajón azul.
    c.drawRect(
      const Rect.fromLTRB(183, 572, 1072, 596),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 572), const Offset(0, 596), [
          const Color(0x40000000),
          const Color(0x00000000),
        ]),
    );
  }

  void _frente(Canvas c, Rect r, {required Color relleno, required Color borde}) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(16));
    c.drawRRect(rr, Paint()..color = relleno);
    // Bisel: una línea de luz arriba adentro.
    c.drawLine(
      Offset(r.left + 22, r.top + 11),
      Offset(r.right - 22, r.top + 11),
      Paint()
        ..color = const Color(0x2EFFFFFF)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    c.drawRRect(
      rr,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  void _cajonRojo(Canvas c) {
    _frente(c, _frenteRojo, relleno: _rojo, borde: _rojoOscuro);
    _perilla(c, Offset(_cerradura.dx, _frenteRojo.center.dy), 36);
  }

  void _cajonAzul(Canvas c) {
    final a = pose.afuera;
    if (a > 0) {
      // El hueco que deja al salir.
      c.drawRRect(
        RRect.fromRectAndRadius(_frenteAzul.inflate(4), const Radius.circular(18)),
        Paint()..color = _azulHueco,
      );
    }
    final centro = _frenteAzul.center;
    c
      ..save()
      // Sale hacia quien mira: baja un poco y crece.
      ..translate(centro.dx, centro.dy + 34 * a)
      ..scale(1 + 0.1 * a)
      ..translate(-centro.dx, -centro.dy);
    if (a > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(_frenteAzul.shift(Offset(0, 18 * a)), const Radius.circular(16)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.3 * a.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    _frente(c, _frenteAzul, relleno: _azul, borde: _azulOscuro);
    _perilla(c, Offset(378, centro.dy), 35);
    _perilla(c, Offset(876, centro.dy), 35);
    _placa(c);
    c.restore();
  }

  void _perilla(Canvas c, Offset o, double r) {
    c.drawCircle(
      o + Offset(0, r * 0.3),
      r,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          o + Offset(-r * 0.3, -r * 0.4),
          r * 1.4,
          [const Color(0xFFFFE468), _amarillo, const Color(0xFFE09B00)],
          [0, 0.5, 1],
        ),
    );
    c.drawOval(
      Rect.fromCenter(center: o + Offset(-r * 0.28, -r * 0.4), width: r * 0.72, height: r * 0.44),
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  /// La cerradura: placa amarilla con el ojo de la llave.
  void _placa(Canvas c) {
    final placa = RRect.fromRectAndRadius(
      Rect.fromCenter(center: _cerradura, width: 82, height: 128),
      const Radius.circular(41),
    );
    c.drawRRect(
      placa.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    c.drawRRect(
      placa,
      Paint()
        ..shader = ui.Gradient.linear(
          placa.outerRect.topLeft,
          placa.outerRect.bottomRight,
          [const Color(0xFFFFE25C), _amarillo, const Color(0xFFE9A300)],
          [0, 0.5, 1],
        ),
    );
    c.drawRRect(
      placa.deflate(2),
      Paint()
        ..color = const Color(0xFFD99500)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Ojo de la llave, que gira con [PoseCajon.giro].
    final eje = _cerradura + const Offset(0, -4);
    c
      ..save()
      ..translate(eje.dx, eje.dy)
      ..rotate(pose.giro * math.pi / 2)
      ..translate(-eje.dx, -eje.dy);
    final ojo = Path()
      ..addOval(Rect.fromCircle(center: eje + const Offset(0, -12), radius: 15))
      ..addRRect(RRect.fromLTRBR(eje.dx - 9, eje.dy - 10, eje.dx + 9, eje.dy + 34, const Radius.circular(5)));
    c.drawPath(ojo, Paint()..color = const Color(0xFF3B2A12));
    c.restore();

    // Reflejo que cruza la placa.
    final b = pose.brillo;
    if (b > 0 && b < 1) {
      final r = placa.outerRect;
      final x = r.left - 50 + (r.width + 100) * b;
      c
        ..save()
        ..clipRRect(placa);
      c.drawPath(
        Path()
          ..moveTo(x - 14, r.bottom)
          ..lineTo(x + 26, r.top)
          ..lineTo(x + 50, r.top)
          ..lineTo(x + 10, r.bottom)
          ..close(),
        Paint()..color = const Color(0x99FFFFFF),
      );
      c.restore();
    }
  }

  // ── Papeles ───────────────────────────────────────────────────────────

  void _papeles(Canvas c) {
    // Dónde queda cada papel (centro y giro) y cuánto más gira al caer.
    const sitios = [
      (Offset(398, 352), -15.0, -26.0),
      (Offset(660, 318), 2.0, 14.0),
      (Offset(878, 362), 11.0, 24.0),
    ];
    for (var i = 0; i < 3; i++) {
      final (centro, giro, giroAlCaer) = sitios[i];
      final caida = pose.caida[i];
      if (caida <= 0) continue;
      var dy = -280 * (1 - caida) - 44 * pose.salto * (1 + 0.25 * i);
      var angulo = giro + giroAlCaer * (1 - caida);
      final vaiven = pose.flotar;
      if (vaiven != null) {
        final fase = 2 * math.pi * (vaiven + i / 3);
        dy += 7 * pose.vaiven * math.sin(fase);
        angulo += 1.2 * pose.vaiven * math.cos(fase);
      }
      final opacidad = (caida * 3).clamp(0.0, 1.0);
      c
        ..save()
        ..translate(centro.dx, centro.dy + dy)
        ..rotate(angulo * math.pi / 180);
      if (opacidad < 1) {
        c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacidad));
      }
      switch (i) {
        case 0:
          _cedula(c);
        case 1:
          _rut(c);
        case 2:
          _hoja(c);
      }
      if (opacidad < 1) c.restore();
      c.restore();
    }
  }

  void _hojaBase(Canvas c, Path forma) {
    c.drawPath(
      forma.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x2A1B2A4A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    c.drawPath(forma, Paint()..color = _papel);
    c.drawPath(
      forma,
      Paint()
        ..color = _papelBorde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _raya(Canvas c, double x, double y, double largo, {Color color = _linea, double grueso = 15}) {
    c.drawLine(
      Offset(x, y),
      Offset(x + largo, y),
      Paint()
        ..color = color
        ..strokeWidth = grueso
        ..strokeCap = StrokeCap.round,
    );
  }

  /// La cédula: franja con la bandera, foto y datos.
  void _cedula(Canvas c) {
    _hojaBase(c, Path()..addRRect(RRect.fromLTRBR(-152, -118, 152, 118, const Radius.circular(20))));
    // Bandera: amarillo, azul y rojo.
    c
      ..save()
      ..clipRRect(RRect.fromLTRBR(-122, -92, 0, -64, const Radius.circular(5)));
    c
      ..drawRect(const Rect.fromLTRB(-122, -92, 0, -78), Paint()..color = const Color(0xFFFCD116))
      ..drawRect(const Rect.fromLTRB(-122, -78, 0, -71), Paint()..color = const Color(0xFF003893))
      ..drawRect(const Rect.fromLTRB(-122, -71, 0, -64), Paint()..color = const Color(0xFFCE1126));
    c.restore();
    // Foto.
    final foto = RRect.fromLTRBR(-122, -48, -12, 78, const Radius.circular(12));
    c.drawRRect(foto, Paint()..color = const Color(0xFFD8DEE7));
    c
      ..save()
      ..clipRRect(foto);
    final gris = Paint()..color = const Color(0xFF8D98AA);
    c
      ..drawCircle(const Offset(-67, -2), 24, gris)
      ..drawOval(Rect.fromCenter(center: const Offset(-67, 70), width: 92, height: 70), gris);
    c.restore();
    // Datos.
    _raya(c, 12, -40, 112);
    _raya(c, 12, -4, 120);
    _raya(c, 12, 32, 98);
  }

  /// El RUT: título grande y dos renglones.
  void _rut(Canvas c) {
    _hojaBase(c, Path()..addRRect(RRect.fromLTRBR(-148, -154, 148, 154, const Radius.circular(18))));
    _textoRut.paint(c, Offset(-_textoRut.width / 2, -118));
    _raya(c, -76, 22, 150, color: const Color(0xFFD9D8D4), grueso: 16);
    _raya(c, -76, 58, 124, color: const Color(0xFFD9D8D4), grueso: 16);
  }

  static final _textoRut = TextPainter(
    text: TextSpan(
      text: 'RUT',
      style: AppText.bold(76, color: _tinta).copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Una hoja con la esquina doblada.
  void _hoja(Canvas c) {
    const doblez = 46.0;
    final forma = Path()
      ..moveTo(-116, -104)
      ..lineTo(116 - doblez, -104)
      ..lineTo(116, -104 + doblez)
      ..lineTo(116, 104)
      ..lineTo(-116, 104)
      ..close();
    _hojaBase(c, forma);
    c.drawPath(
      Path()
        ..moveTo(116 - doblez, -104)
        ..lineTo(116 - doblez, -104 + doblez - 6)
        ..quadraticBezierTo(116 - doblez, -104 + doblez, 116 - doblez + 6, -104 + doblez)
        ..lineTo(116, -104 + doblez)
        ..close(),
      Paint()..color = const Color(0xFFE9E5DC),
    );
    _raya(c, -86, -38, 146, color: const Color(0xFFD2D2D0));
    _raya(c, -86, 0, 162, color: const Color(0xFFD2D2D0));
    _raya(c, -86, 38, 118, color: const Color(0xFFD2D2D0));
  }

  // ── Estrellitas ───────────────────────────────────────────────────────

  void _destellos(Canvas c) {
    final d = pose.destellos;
    if (d <= 0) return;
    const puntos = [
      (Offset(-104, -70), 1.0),
      (Offset(100, -52), 0.8),
      (Offset(86, 76), 0.6),
      (Offset(-90, 70), 0.5),
    ];
    for (final (lugar, tam) in puntos) {
      final r = 46 * tam * math.sin(math.pi * d.clamp(0.0, 1.0));
      if (r <= 0) continue;
      final o = _cerradura + lugar;
      final estrella = Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
        ..close();
      c.drawPath(estrella, Paint()..color = const Color(0xFFFFFFFF));
      c.drawPath(
        estrella,
        Paint()
          ..color = const Color(0xFFFFD84A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorCajon old) => old.pose != pose;
}
