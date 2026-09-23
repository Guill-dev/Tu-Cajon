import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'pixeles.dart';

/// Filtros "de escáner" para las fotos de documentos.
///
/// No usan inteligencia artificial: son fórmulas clásicas de procesamiento
/// de imagen que corren dentro del celular (sin internet).
enum FiltroFoto {
  /// La foto tal como salió de la cámara.
  original('Original'),

  /// Fondo blanco parejo (quita sombras), texto más oscuro y bordes nítidos.
  /// Conserva los colores (sellos, firmas en azul, fotos de la cédula).
  documento('Documento'),

  /// Blanco y negro de alto contraste, como una fotocopia.
  byn('B/N');

  const FiltroFoto(this.etiqueta);

  final String etiqueta;
}

/// Aplica el [filtro] a una foto JPEG. Se abre con el decodificador del
/// celular y se filtra en otro hilo, para no trabar la pantalla.
Future<Uint8List> aplicarFiltro(Uint8List jpeg, FiltroFoto filtro) async {
  if (filtro == FiltroFoto.original) return jpeg;
  final pixeles = await decodificarFoto(jpeg);
  return Isolate.run(() => codificarJpg(filtrarPixeles(pixeles, filtro)));
}

/// Ajustes de cada filtro.
///
/// La curva de tono va sobre la luz "relativa al papel" (papel = 1):
/// - por debajo de [negro] queda negro; por encima de [blanco], blanco puro
///   (así desaparecen la textura del papel y el ruido de la cámara);
/// - en medio, una curva suave con [gamma] > 1 oscurece los grises: los
///   trazos finos de las letras pequeñas, que la cámara ve grises, quedan
///   casi negros sin volverse manchas.
///
/// [nitidez]: cuánto se marcan los bordes (máscara de enfoque).
class _Ajuste {
  const _Ajuste({required this.negro, required this.blanco, required this.gamma, required this.nitidez});

  final double negro;
  final double blanco;
  final double gamma;
  final double nitidez;
}

const _ajustes = {
  FiltroFoto.documento: _Ajuste(negro: 0.10, blanco: 0.90, gamma: 1.3, nitidez: 1.0),
  FiltroFoto.byn: _Ajuste(negro: 0.42, blanco: 0.90, gamma: 1.35, nitidez: 1.4),
};

/// El filtro sobre los píxeles (en el hilo actual; lo usan las pruebas).
///
/// 1. **El color del papel.** La foto se divide en bloques; en cada bloque
///    se toma la parte más clara (no el promedio, para que la tinta no
///    oscurezca el cálculo), se completa con los bloques vecinos y se
///    suaviza. Así se sabe qué tan iluminado está el papel en cada zona, con
///    sombra o sin ella.
/// 2. **Iluminación pareja.** Cada píxel se divide por su papel: el papel
///    queda en 1 (blanco) en todas partes y la tinta conserva su contraste.
/// 3. **Nitidez.** Máscara de enfoque sobre la luz: se resalta la diferencia
///    entre cada píxel y el promedio suave de sus vecinos. Se hace antes de
///    la curva, que luego recorta los halos claros al blanco.
/// 4. **Curva de tono** (ver [_Ajuste]).
/// 5. **Color** (solo "Documento"): cada píxel conserva su tono; solo cambia
///    qué tan claro u oscuro es. En "B/N" sale en grises.
Pixeles filtrarPixeles(Pixeles p, FiltroFoto filtro) {
  final ajuste = _ajustes[filtro];
  if (ajuste == null) return p;
  final w = p.ancho;
  final h = p.alto;
  final rgba = p.rgba;
  final n = w * h;

  // Luz de cada píxel (0‥255).
  final luz = Uint8List(n);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    luz[i] = (rgba[j] * 77 + rgba[j + 1] * 150 + rgba[j + 2] * 29) >> 8;
  }

  // 1. Papel por bloques: el promedio de la celda más clara de cada bloque.
  final lado = math.max(12, (math.max(w, h) / 90).round()); // ~90 bloques en el lado largo
  final celda = math.max(3, lado ~/ 4);
  final gw = (w + lado - 1) ~/ lado;
  final gh = (h + lado - 1) ~/ lado;
  var papel = Float64List(gw * gh);
  for (var by = 0; by < gh; by++) {
    for (var bx = 0; bx < gw; bx++) {
      var mejor = 0.0;
      for (var cy = by * lado; cy < math.min(h, (by + 1) * lado); cy += celda) {
        for (var cx = bx * lado; cx < math.min(w, (bx + 1) * lado); cx += celda) {
          var suma = 0;
          var cuenta = 0;
          for (var y = cy; y < math.min(h, cy + celda); y++) {
            for (var x = cx; x < math.min(w, cx + celda); x++) {
              suma += luz[y * w + x];
              cuenta++;
            }
          }
          mejor = math.max(mejor, suma / cuenta);
        }
      }
      papel[by * gw + bx] = mejor;
    }
  }
  // Un bloque tapado del todo por tinta (un título grueso) toma el papel de
  // sus vecinos: el más claro de los 3×3 de alrededor.
  final vecinos = Float64List(gw * gh);
  for (var by = 0; by < gh; by++) {
    for (var bx = 0; bx < gw; bx++) {
      var mejor = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final x = bx + dx;
          final y = by + dy;
          if (x < 0 || y < 0 || x >= gw || y >= gh) continue;
          mejor = math.max(mejor, papel[y * gw + x]);
        }
      }
      vecinos[by * gw + bx] = mejor;
    }
  }
  // Y ninguna zona puede tener un papel más oscuro que la mitad del papel de
  // toda la hoja: así una foto (la de la cédula) o un recuadro negro grande
  // no se "lavan", y las sombras normales sí se corrigen.
  final ordenados = Float64List.fromList(vecinos)..sort();
  final papelHoja = ordenados[(ordenados.length * 0.9).floor().clamp(0, ordenados.length - 1)];
  papel = Float64List.fromList([for (final v in vecinos) math.max(v, papelHoja * 0.5)]);
  // Suavizado entre bloques (dos pasadas 3×3), para que no se noten.
  for (var pasada = 0; pasada < 2; pasada++) {
    final suave = Float64List(gw * gh);
    for (var by = 0; by < gh; by++) {
      for (var bx = 0; bx < gw; bx++) {
        var suma = 0.0;
        var cuenta = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final x = bx + dx;
            final y = by + dy;
            if (x < 0 || y < 0 || x >= gw || y >= gh) continue;
            suma += papel[y * gw + x];
            cuenta++;
          }
        }
        suave[by * gw + bx] = suma / cuenta;
      }
    }
    papel = suave;
  }

  // 2. Luz relativa al papel, interpolando el papel entre centros de bloque.
  //    Se guarda en 0‥1023 (papel = 1000) para no perder detalle.
  final relativa = Uint16List(n);
  for (var y = 0; y < h; y++) {
    final gy = ((y + 0.5) / lado - 0.5).clamp(0.0, gh - 1.0);
    final y0 = gy.floor();
    final y1 = math.min(y0 + 1, gh - 1);
    final fy = gy - y0;
    for (var x = 0; x < w; x++) {
      final gx = ((x + 0.5) / lado - 0.5).clamp(0.0, gw - 1.0);
      final x0 = gx.floor();
      final x1 = math.min(x0 + 1, gw - 1);
      final fx = gx - x0;
      final arriba = papel[y0 * gw + x0] * (1 - fx) + papel[y0 * gw + x1] * fx;
      final abajo = papel[y1 * gw + x0] * (1 - fx) + papel[y1 * gw + x1] * fx;
      final fondo = math.max(arriba * (1 - fy) + abajo * fy, 24.0);
      relativa[y * w + x] = math.min(1023, (luz[y * w + x] * 1000 / fondo).round());
    }
  }

  // 3. Nitidez: valor + fuerza · (valor − promedio 3×3 con pesos 1-2-1).
  final nitida = Uint16List.fromList(relativa);
  final fuerza = ajuste.nitidez;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final promedio =
          (relativa[i - w - 1] +
              2 * relativa[i - w] +
              relativa[i - w + 1] +
              2 * relativa[i - 1] +
              4 * relativa[i] +
              2 * relativa[i + 1] +
              relativa[i + w - 1] +
              2 * relativa[i + w] +
              relativa[i + w + 1]) /
          16;
      final v = relativa[i];
      nitida[i] = (v + fuerza * (v - promedio)).round().clamp(0, 1023);
    }
  }

  // 4. Curva de tono en una tabla (0‥1023 → 0‥255).
  final curva = Uint8List(1024);
  for (var v = 0; v < 1024; v++) {
    final t = ((v / 1000 - ajuste.negro) / (ajuste.blanco - ajuste.negro)).clamp(0.0, 1.0);
    // Extremos suaves (smoothstep mezclado) + gamma para oscurecer los grises.
    final suave = t * t * (3 - 2 * t);
    curva[v] = (math.pow(0.5 * t + 0.5 * suave, ajuste.gamma) * 255).round();
  }

  // 5. Armar la salida.
  final salida = Uint8List(n * 4);
  final byn = filtro == FiltroFoto.byn;
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    final nueva = curva[nitida[i]];
    if (byn) {
      salida[j] = nueva;
      salida[j + 1] = nueva;
      salida[j + 2] = nueva;
    } else {
      // Se conserva el tono: cada canal se escala igual que la luz, y lo que
      // la curva manda a blanco queda blanco puro.
      final antes = luz[i];
      if (nueva >= 255) {
        salida[j] = 255;
        salida[j + 1] = 255;
        salida[j + 2] = 255;
      } else {
        final factor = antes == 0 ? 0.0 : nueva / antes;
        salida[j] = (rgba[j] * factor).round().clamp(0, 255);
        salida[j + 1] = (rgba[j + 1] * factor).round().clamp(0, 255);
        salida[j + 2] = (rgba[j + 2] * factor).round().clamp(0, 255);
      }
    }
    salida[j + 3] = 255;
  }
  return Pixeles(salida, w, h);
}
