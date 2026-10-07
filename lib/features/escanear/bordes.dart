import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'pixeles.dart';

/// Las cuatro esquinas del papel dentro de una foto, en fracciones (0 a 1)
/// de su ancho y su alto.
class Esquinas {
  const Esquinas(this.arribaIzq, this.arribaDer, this.abajoDer, this.abajoIzq);

  Esquinas.deRect(Rect r) : this(r.topLeft, r.topRight, r.bottomRight, r.bottomLeft);

  /// En el orden de las agujas del reloj, desde arriba a la izquierda.
  Esquinas.deLista(List<Offset> l) : this(l[0], l[1], l[2], l[3]);

  /// La foto entera.
  static const todo = Esquinas(Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1));

  final Offset arribaIzq;
  final Offset arribaDer;
  final Offset abajoDer;
  final Offset abajoIzq;

  List<Offset> get lista => [arribaIzq, arribaDer, abajoDer, abajoIzq];

  Esquinas cambiar(int i, Offset punto) => Esquinas.deLista([...lista]..[i] = punto);

  /// Casi la foto entera (no hace falta recortar).
  bool get esTodo => casiIgual(todo);

  /// Las mismas esquinas, salvo diferencias que no se notan.
  bool casiIgual(Esquinas otras) {
    for (var i = 0; i < 4; i++) {
      if ((lista[i] - otras.lista[i]).distance > 0.004) return false;
    }
    return true;
  }

  /// Los cuatro lados derechos (se puede recortar sin enderezar).
  bool get esRectangulo =>
      (arribaIzq.dy - arribaDer.dy).abs() < 1e-4 &&
      (abajoIzq.dy - abajoDer.dy).abs() < 1e-4 &&
      (arribaIzq.dx - abajoIzq.dx).abs() < 1e-4 &&
      (arribaDer.dx - abajoDer.dx).abs() < 1e-4;

  /// Sin lados cruzados ni esquinas hacia adentro, y no demasiado chico.
  bool get esValido {
    final p = lista;
    var signo = 0;
    for (var i = 0; i < 4; i++) {
      final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
      final cruz = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
      final s = cruz.sign.toInt();
      if (s == 0) return false;
      if (signo == 0) signo = s;
      if (s != signo) return false;
    }
    return _area(p) > 0.004;
  }

  @override
  String toString() =>
      'Esquinas(${lista.map((p) => '(${p.dx.toStringAsFixed(3)}, ${p.dy.toStringAsFixed(3)})').join(' ')})';
}

double _area(List<Offset> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[i], r = p[(i + 1) % p.length];
    a += q.dx * r.dy - r.dx * q.dy;
  }
  return a.abs() / 2;
}

// ── Detectar los bordes ────────────────────────────────────────────────────

/// Busca los bordes del papel en la foto: las cuatro rectas más claras que
/// forman un cuadrilátero grande (como en los escáneres de celular).
///
/// Es visión por computador clásica, sin modelo de IA:
/// 1. la foto se achica (480 px) y se suaviza;
/// 2. se marcan los bordes (cambios fuertes de luz o de color);
/// 3. la transformada de Hough encuentra las rectas largas;
/// 4. de esas rectas, se elige el cuadrilátero con más borde a lo largo de
///    sus cuatro lados (y que sea grande y con ángulos de papel);
/// 5. cada lado se afina con los puntos de borde que tiene cerca.
///
/// Devuelve `null` si no encuentra un papel claro (p. ej. papel blanco sobre
/// mesa blanca, o el papel se sale de la foto): mejor no recortar que
/// recortar mal.
Esquinas? detectarBordes(Pixeles p) => _Busqueda(p).buscar();

class _Recta {
  _Recta(this.theta, this.rho, this.votos);

  /// Ángulo de la normal (radianes) y distancia al origen: x·cos θ + y·sin θ = ρ.
  final double theta;
  final double rho;
  final int votos;

  double get c => math.cos(theta);
  double get s => math.sin(theta);

  /// Horizontal si la normal apunta más o menos hacia arriba.
  bool get horizontal => (s).abs() > (c).abs();

  /// Altura de la recta en x (para las horizontales) o x en y (verticales).
  double posicion(double centroX, double centroY) =>
      horizontal ? (rho - centroX * c) / s : (rho - centroY * s) / c;

  Offset? cruce(_Recta o) {
    final det = c * o.s - s * o.c;
    if (det.abs() < 1e-6) return null;
    return Offset((rho * o.s - s * o.rho) / det, (c * o.rho - rho * o.c) / det);
  }
}

class _Busqueda {
  _Busqueda(Pixeles foto) {
    final escala = math.min(1.0, _lado / math.max(foto.ancho, foto.alto));
    w = math.max(8, (foto.ancho * escala).round());
    h = math.max(8, (foto.alto * escala).round());
    luz = Float32List(w * h);
    color = Float32List(w * h);
    _achicar(foto);
  }

  static const _lado = 480;

  late final int w;
  late final int h;
  late final Float32List luz;
  late final Float32List color;
  late final Float32List gx;
  late final Float32List gy;
  late final Float32List fuerza;
  late double umbral;

  /// Promedia unos pocos píxeles de cada cuadrito de la foto grande.
  void _achicar(Pixeles foto) {
    final fx = foto.ancho / w, fy = foto.alto / h;
    final rgba = foto.rgba;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var r = 0.0, g = 0.0, b = 0.0, n = 0;
        for (var j = 0; j < 3; j++) {
          final sy = math.min(foto.alto - 1, ((y + (j + 0.5) / 3) * fy).floor());
          for (var i = 0; i < 3; i++) {
            final sx = math.min(foto.ancho - 1, ((x + (i + 0.5) / 3) * fx).floor());
            final k = (sy * foto.ancho + sx) * 4;
            r += rgba[k];
            g += rgba[k + 1];
            b += rgba[k + 2];
            n++;
          }
        }
        r /= n;
        g /= n;
        b /= n;
        luz[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b;
        color[y * w + x] = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
      }
    }
  }

  /// Suavizado de 5 puntos (1 4 6 4 1) a lo ancho y a lo alto.
  void _suavizar(Float32List v) {
    final t = Float32List(w * h);
    const k = [1.0, 4.0, 6.0, 4.0, 1.0];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var s = 0.0;
        for (var i = -2; i <= 2; i++) {
          s += k[i + 2] * v[y * w + (x + i).clamp(0, w - 1)];
        }
        t[y * w + x] = s / 16;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var s = 0.0;
        for (var i = -2; i <= 2; i++) {
          s += k[i + 2] * t[(y + i).clamp(0, h - 1) * w + x];
        }
        v[y * w + x] = s / 16;
      }
    }
  }

  /// Cambios de luz o de color (Sobel): se queda el más fuerte de los dos.
  void _bordes() {
    gx = Float32List(w * h);
    gy = Float32List(w * h);
    fuerza = Float32List(w * h);
    final l = luz, c = color;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lx =
            (l[i - w + 1] + 2 * l[i + 1] + l[i + w + 1]) - (l[i - w - 1] + 2 * l[i - 1] + l[i + w - 1]);
        final ly =
            (l[i + w - 1] + 2 * l[i + w] + l[i + w + 1]) - (l[i - w - 1] + 2 * l[i - w] + l[i - w + 1]);
        // El color pesa un poco más: una cédula de colores sobre una mesa de la misma luz.
        final cx =
            1.4 *
            ((c[i - w + 1] + 2 * c[i + 1] + c[i + w + 1]) - (c[i - w - 1] + 2 * c[i - 1] + c[i + w - 1]));
        final cy =
            1.4 *
            ((c[i + w - 1] + 2 * c[i + w] + c[i + w + 1]) - (c[i - w - 1] + 2 * c[i - w] + c[i - w + 1]));
        final ml = lx * lx + ly * ly, mc = cx * cx + cy * cy;
        if (ml >= mc) {
          gx[i] = lx;
          gy[i] = ly;
          fuerza[i] = math.sqrt(ml);
        } else {
          gx[i] = cx;
          gy[i] = cy;
          fuerza[i] = math.sqrt(mc);
        }
      }
    }
    // El umbral: el 10 % de bordes más fuertes, pero nunca un cambio mínimo.
    final valores = Float32List.fromList([
      for (var i = 0; i < fuerza.length; i++)
        if (fuerza[i] > 0) fuerza[i],
    ])..sort();
    final p90 = valores.isEmpty ? 0.0 : valores[(valores.length * 0.9).floor().clamp(0, valores.length - 1)];
    umbral = math.max(p90, 48.0);
  }

  /// Solo el punto más fuerte a lo ancho de cada borde (bordes de 1 px).
  bool _esCresta(int x, int y) {
    final i = y * w + x;
    final f = fuerza[i];
    if (f < umbral) return false;
    final ax = gx[i].abs(), ay = gy[i].abs();
    int dx, dy;
    if (ax > 2.4 * ay) {
      dx = 1;
      dy = 0;
    } else if (ay > 2.4 * ax) {
      dx = 0;
      dy = 1;
    } else {
      dx = 1;
      dy = (gx[i] * gy[i] > 0) ? 1 : -1;
    }
    return f >= fuerza[(y + dy) * w + x + dx] && f >= fuerza[(y - dy) * w + x - dx];
  }

  List<_Recta> _rectas() {
    const pasos = 180;
    final diag = math.sqrt(w * w + h * h).ceil();
    final filas = 2 * diag + 1;
    final votos = Int32List(pasos * filas);
    final cosT = Float64List(pasos), sinT = Float64List(pasos);
    for (var t = 0; t < pasos; t++) {
      cosT[t] = math.cos(t * math.pi / pasos);
      sinT[t] = math.sin(t * math.pi / pasos);
    }
    for (var y = 2; y < h - 2; y++) {
      for (var x = 2; x < w - 2; x++) {
        if (!_esCresta(x, y)) continue;
        final i = y * w + x;
        // La normal de la recta va en la dirección del cambio: se vota cerca de ese ángulo.
        var grados = (math.atan2(gy[i], gx[i]) * 180 / math.pi).round();
        if (grados < 0) grados += 180;
        for (var d = -5; d <= 5; d++) {
          final t = (grados + d) % pasos;
          final rho = (x * cosT[t] + y * sinT[t]).round() + diag;
          votos[t * filas + rho]++;
        }
      }
    }
    final minimo = (0.1 * math.min(w, h)).round();
    final picos = <_Recta>[];
    for (var t = 0; t < pasos; t++) {
      for (var r = 0; r < filas; r++) {
        final v = votos[t * filas + r];
        if (v < minimo) continue;
        var esMaximo = true;
        for (var dt = -3; dt <= 3 && esMaximo; dt++) {
          final tt = (t + dt + pasos) % pasos;
          // Al dar la vuelta (179° → 0°) la misma recta tiene ρ con el signo cambiado.
          final cruza = t + dt < 0 || t + dt >= pasos;
          for (var dr = -4; dr <= 4; dr++) {
            if (dt == 0 && dr == 0) continue;
            final rr = cruza ? (filas - 1 - r) + dr : r + dr;
            if (rr < 0 || rr >= filas) continue;
            final o = votos[tt * filas + rr];
            if (o > v || (o == v && (dt < 0 || (dt == 0 && dr < 0)))) {
              esMaximo = false;
              break;
            }
          }
        }
        if (esMaximo) picos.add(_Recta(t * math.pi / pasos, (r - diag).toDouble(), v));
      }
    }
    picos.sort((a, b) => b.votos.compareTo(a.votos));
    final elegidas = <_Recta>[];
    for (final p in picos) {
      final parecida = elegidas.any((e) {
        var dt = (e.theta - p.theta).abs();
        var dr = (e.rho - p.rho).abs();
        if (dt > math.pi / 2) {
          dt = math.pi - dt;
          dr = (e.rho + p.rho).abs();
        }
        return dt < 4 * math.pi / 180 && dr < 8;
      });
      if (!parecida) elegidas.add(p);
      if (elegidas.length >= 28) break;
    }
    return elegidas;
  }

  /// Qué parte del lado [a]→[b] tiene borde debajo (0 a 1), contando solo
  /// bordes que van en la misma dirección que el lado.
  double _apoyo(Offset a, Offset b) {
    final largo = (b - a).distance;
    if (largo < 4) return 0;
    final nx = -(b.dy - a.dy) / largo, ny = (b.dx - a.dx) / largo;
    final n = math.max(12, largo ~/ 3);
    final debil = umbral * 0.5;
    var dentro = 0, conBorde = 0;
    for (var k = 0; k < n; k++) {
      final f = (k + 0.5) / n;
      final px = (a.dx + (b.dx - a.dx) * f).round(), py = (a.dy + (b.dy - a.dy) * f).round();
      if (px < 2 || py < 2 || px >= w - 2 || py >= h - 2) continue;
      dentro++;
      var hay = false;
      for (var dy = -1; dy <= 1 && !hay; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final i = (py + dy) * w + px + dx;
          final fu = fuerza[i];
          if (fu < debil) continue;
          if ((gx[i] * nx + gy[i] * ny).abs() >= 0.88 * fu) {
            hay = true;
            break;
          }
        }
      }
      if (hay) conBorde++;
    }
    // Un lado que casi no está dentro de la foto no cuenta como visto.
    if (dentro < n * 0.6) return 0;
    return conBorde / dentro;
  }

  /// Rehace la recta del lado [a]→[b] con los puntos de borde que tiene a
  /// menos de 2,5 px (mínimos cuadrados), para no depender de la cuadrícula
  /// de Hough.
  _Recta? _afinar(Offset a, Offset b) {
    final largo = (b - a).distance;
    if (largo < 8) return null;
    final ux = (b.dx - a.dx) / largo, uy = (b.dy - a.dy) / largo;
    final nx = -uy, ny = ux;
    var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0, n = 0;
    final minX = math.max(2, math.min(a.dx, b.dx).floor() - 3);
    final maxX = math.min(w - 3, math.max(a.dx, b.dx).ceil() + 3);
    final minY = math.max(2, math.min(a.dy, b.dy).floor() - 3);
    final maxY = math.min(h - 3, math.max(a.dy, b.dy).ceil() + 3);
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final distancia = (x - a.dx) * nx + (y - a.dy) * ny;
        if (distancia.abs() > 2.5) continue;
        final avance = (x - a.dx) * ux + (y - a.dy) * uy;
        if (avance < largo * 0.05 || avance > largo * 0.95) continue;
        final i = y * w + x;
        final fu = fuerza[i];
        if (fu < umbral * 0.5 || (gx[i] * nx + gy[i] * ny).abs() < 0.88 * fu) continue;
        sx += x;
        sy += y;
        sxx += x * x;
        syy += y * y;
        sxy += x * y;
        n++;
      }
    }
    if (n < 10) return null;
    final mx = sx / n, my = sy / n;
    final cxx = sxx / n - mx * mx, cyy = syy / n - my * my, cxy = sxy / n - mx * my;
    // La normal es el vector propio de la menor varianza.
    final theta = 0.5 * math.atan2(2 * cxy, cxx - cyy) + math.pi / 2;
    return _Recta(theta, mx * math.cos(theta) + my * math.sin(theta), n);
  }

  Esquinas? buscar() {
    _suavizar(luz);
    _suavizar(color);
    _bordes();
    final rectas = _rectas();
    final cx = w / 2, cy = h / 2;
    final horizontales = rectas.where((r) => r.horizontal).toList()
      ..sort((a, b) => a.posicion(cx, cy).compareTo(b.posicion(cx, cy)));
    final verticales = rectas.where((r) => !r.horizontal).toList()
      ..sort((a, b) => a.posicion(cx, cy).compareTo(b.posicion(cx, cy)));

    List<Offset>? mejor;
    var mejorPuntaje = 0.0;
    final areaFoto = (w * h).toDouble();
    // Los cruces y lo que se mide de cada lado se repiten entre cuadriláteros:
    // se calculan una vez.
    final cruces = [
      for (final hz in horizontales) [for (final v in verticales) hz.cruce(v)],
    ];
    final medidos = <int, double>{};
    double apoyo(int clave, Offset a, Offset b) => medidos[clave] ??= _apoyo(a, b);
    for (var i = 0; i < horizontales.length; i++) {
      for (var j = i + 1; j < horizontales.length; j++) {
        final arriba = horizontales[i], abajo = horizontales[j];
        if (abajo.posicion(cx, cy) - arriba.posicion(cx, cy) < h * 0.15) continue;
        for (var k = 0; k < verticales.length; k++) {
          for (var l = k + 1; l < verticales.length; l++) {
            final izq = verticales[k], der = verticales[l];
            if (der.posicion(cx, cy) - izq.posicion(cx, cy) < w * 0.15) continue;
            final p = [cruces[i][k], cruces[i][l], cruces[j][l], cruces[j][k]];
            if (p.contains(null)) continue;
            final q = p.cast<Offset>();
            if (!_forma(q)) continue;
            final area = _area(q) / areaFoto;
            if (area < 0.18) continue;
            // Cada lado: su recta y las dos que lo cortan.
            final claves = [
              (i * 64 + k) * 64 + l,
              (1 << 20) + (l * 64 + i) * 64 + j,
              (j * 64 + k) * 64 + l,
              (1 << 20) + (k * 64 + i) * 64 + j,
            ];
            var suma = 0.0;
            var sirve = true;
            for (var s = 0; s < 4; s++) {
              final a = apoyo(claves[s], q[s], q[(s + 1) % 4]);
              if (a < 0.45) {
                sirve = false;
                break;
              }
              suma += a;
            }
            if (!sirve) continue;
            final puntaje = (suma / 4) * (0.6 + 0.4 * math.sqrt(area));
            if (puntaje > mejorPuntaje) {
              mejorPuntaje = puntaje;
              mejor = q;
            }
          }
        }
      }
    }
    if (mejor == null || mejorPuntaje < 0.5) return null;

    // Afinar cada lado y volver a cruzarlos.
    final lados = [for (var s = 0; s < 4; s++) _afinar(mejor[s], mejor[(s + 1) % 4])];
    var esquinas = mejor;
    if (!lados.contains(null)) {
      final l = lados.cast<_Recta>();
      // Esquina s = cruce del lado anterior (s-1) con el lado s.
      final afinadas = [for (var s = 0; s < 4; s++) l[(s + 3) % 4].cruce(l[s])];
      if (!afinadas.contains(null)) {
        final a = afinadas.cast<Offset>();
        final cercanas = [for (var s = 0; s < 4; s++) (a[s] - mejor[s]).distance < 6].every((c) => c);
        if (cercanas && _forma(a)) esquinas = a;
      }
    }
    return Esquinas.deLista([
      for (final e in esquinas) Offset((e.dx / w).clamp(0.0, 1.0), (e.dy / h).clamp(0.0, 1.0)),
    ]);
  }

  /// Dentro de la foto (con un margen), convexo y con ángulos de papel
  /// (entre 50° y 130°).
  bool _forma(List<Offset> q) {
    for (final p in q) {
      if (p.dx < -0.08 * w || p.dx > 1.08 * w || p.dy < -0.08 * h || p.dy > 1.08 * h) return false;
    }
    if (!Esquinas.deLista(q).esValido) return false;
    for (var i = 0; i < 4; i++) {
      final a = q[(i + 3) % 4] - q[i], b = q[(i + 1) % 4] - q[i];
      final cos = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
      if (cos.abs() > 0.643) return false; // más allá de 50°–130°
    }
    return true;
  }
}

// ── Enderezar ──────────────────────────────────────────────────────────────

/// Proporciones (ancho ÷ alto) de papeles conocidos: si el papel enderezado
/// se parece mucho a una, se usa esa (la perspectiva deja la medida un poco
/// corrida).
const proporcionesTarjeta = [85.6 / 54];
const proporcionesHoja = [8.5 / 11, 210 / 297, 8.5 / 14];

/// Recorta el papel con sus [esquinas] y lo deja derecho, como si la foto se
/// hubiera tomado de frente (corrección de perspectiva). Si [proporciones]
/// trae la de este papel y se parece, se ajusta a ella.
Pixeles enderezarPixeles(
  Pixeles p,
  Esquinas esquinas, {
  List<double> proporciones = const [],
  int ladoMaximo = 2400,
}) {
  final q = [for (final e in esquinas.lista) Offset(e.dx * p.ancho, e.dy * p.alto)];
  if (esquinas.esRectangulo) {
    // Sin perspectiva: un recorte simple.
    final r = Rect.fromPoints(q[0], q[2]);
    return recortarPixeles(
      p,
      r.left.round(),
      r.top.round(),
      math.max(1, r.width.round()),
      math.max(1, r.height.round()),
    );
  }
  var ancho = math.max((q[1] - q[0]).distance, (q[2] - q[3]).distance);
  var alto = math.max((q[3] - q[0]).distance, (q[2] - q[1]).distance);
  final medida = ancho / alto;
  for (final pr in proporciones) {
    for (final objetivo in [pr, 1 / pr]) {
      if ((medida / objetivo - 1).abs() < 0.12) {
        final area = ancho * alto;
        ancho = math.sqrt(area * objetivo);
        alto = ancho / objetivo;
      }
    }
  }
  final achique = math.min(1.0, ladoMaximo / math.max(ancho, alto));
  final w = math.max(1, (ancho * achique).round());
  final h = math.max(1, (alto * achique).round());

  // Del cuadrado unidad (u, v) al cuadrilátero de la foto (Heckbert).
  final x0 = q[0].dx, y0 = q[0].dy, x1 = q[1].dx, y1 = q[1].dy;
  final x2 = q[2].dx, y2 = q[2].dy, x3 = q[3].dx, y3 = q[3].dy;
  final dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
  final dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  double a, b, c, d, e, f, g, hh;
  if (dx3.abs() < 1e-9 && dy3.abs() < 1e-9) {
    a = x1 - x0;
    b = x2 - x1;
    c = x0;
    d = y1 - y0;
    e = y2 - y1;
    f = y0;
    g = 0;
    hh = 0;
  } else {
    final det = dx1 * dy2 - dx2 * dy1;
    g = (dx3 * dy2 - dx2 * dy3) / det;
    hh = (dx1 * dy3 - dx3 * dy1) / det;
    a = x1 - x0 + g * x1;
    b = x3 - x0 + hh * x3;
    c = x0;
    d = y1 - y0 + g * y1;
    e = y3 - y0 + hh * y3;
    f = y0;
  }

  final fuente = p.rgba;
  final salida = Uint8List(w * h * 4);
  final maxX = p.ancho - 1, maxY = p.alto - 1;
  for (var j = 0; j < h; j++) {
    final v = (j + 0.5) / h;
    for (var i = 0; i < w; i++) {
      final u = (i + 0.5) / w;
      final z = g * u + hh * v + 1;
      final sx = ((a * u + b * v + c) / z - 0.5).clamp(0.0, maxX.toDouble());
      final sy = ((d * u + e * v + f) / z - 0.5).clamp(0.0, maxY.toDouble());
      final ix = sx.floor(), iy = sy.floor();
      final fx = sx - ix, fy = sy - iy;
      final ix1 = math.min(ix + 1, maxX), iy1 = math.min(iy + 1, maxY);
      final k00 = (iy * p.ancho + ix) * 4, k10 = (iy * p.ancho + ix1) * 4;
      final k01 = (iy1 * p.ancho + ix) * 4, k11 = (iy1 * p.ancho + ix1) * 4;
      final o = (j * w + i) * 4;
      for (var canal = 0; canal < 3; canal++) {
        final arriba = fuente[k00 + canal] + (fuente[k10 + canal] - fuente[k00 + canal]) * fx;
        final abajo = fuente[k01 + canal] + (fuente[k11 + canal] - fuente[k01 + canal]) * fx;
        salida[o + canal] = (arriba + (abajo - arriba) * fy).round();
      }
      salida[o + 3] = 255;
    }
  }
  return Pixeles(salida, w, h);
}
