import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Formatos del marco de la cámara. Se guarda solo lo que queda adentro.
enum FormatoFoto {
  /// Tarjeta: cédula, licencia, carné (85,6 × 54 mm).
  cedula('Cédula', 85.6 / 54),

  /// Hoja tamaño carta en vertical (21,6 × 27,9 cm).
  hoja('Hoja', 8.5 / 11),
  tresCuartos('3:4', 3 / 4),
  cuadrado('1:1', 1),
  panoramica('16:9', 16 / 9),

  /// Todo lo que se ve en el visor.
  completa('Completa', null);

  const FormatoFoto(this.etiqueta, this.proporcion);

  final String etiqueta;

  /// Ancho ÷ alto del marco; `null` en [completa].
  final double? proporcion;
}

/// El marco dentro del visor: centrado, lo más grande posible sin pasar del
/// 86 % del ancho ni del 82 % del alto (en [FormatoFoto.completa], el visor
/// entero).
Rect marcoEnVisor(Size visor, FormatoFoto formato) {
  final proporcion = formato.proporcion;
  if (proporcion == null) return Offset.zero & visor;
  final ancho = math.min(visor.width * 0.86, visor.height * 0.82 * proporcion);
  final alto = ancho / proporcion;
  return Rect.fromCenter(center: visor.center(Offset.zero), width: ancho, height: alto);
}

/// Dónde cae el [marco] dentro de la imagen de la cámara, en fracciones de
/// 0 a 1 (izquierda, arriba, derecha, abajo).
///
/// La vista previa ([imagenCamara], ya en vertical) llena el [visor]
/// recortando lo que sobra por los lados o por arriba y abajo ("cover"), así
/// que hay que deshacer esa escala y ese corrimiento.
Rect marcoEnImagen({required Size visor, required Rect marco, required Size imagenCamara}) {
  final escala = math.max(visor.width / imagenCamara.width, visor.height / imagenCamara.height);
  final ancho = imagenCamara.width * escala;
  final alto = imagenCamara.height * escala;
  final dx = (visor.width - ancho) / 2;
  final dy = (visor.height - alto) / 2;
  Rect fraccion(Rect r) => Rect.fromLTRB(
    (r.left - dx) / ancho,
    (r.top - dy) / alto,
    (r.right - dx) / ancho,
    (r.bottom - dy) / alto,
  );
  return fraccion(marco).intersect(const Rect.fromLTRB(0, 0, 1, 1));
}

/// Qué parte de la foto tomada (en píxeles) corresponde al [recorte]
/// (fracciones de [marcoEnImagen]).
///
/// La foto puede tener otra proporción que la vista previa (p. ej. 4:3 y
/// 16:9): la vista previa es la parte central más grande con su proporción.
/// Si la foto quedó acostada al revés de la vista previa, devuelve `null`
/// (mejor no recortar que recortar mal).
Rect? parteEnPixeles(
  Rect recorte, {
  required double proporcionCamara,
  required int ancho,
  required int alto,
}) {
  final w = ancho.toDouble();
  final h = alto.toDouble();
  if ((w > h) != (proporcionCamara > 1)) return null;
  final (vw, vh) = w / h > proporcionCamara ? (h * proporcionCamara, h) : (w, w / proporcionCamara);
  final ox = (w - vw) / 2;
  final oy = (h - vh) / 2;
  return Rect.fromLTRB(
    ox + recorte.left * vw,
    oy + recorte.top * vh,
    ox + recorte.right * vw,
    oy + recorte.bottom * vh,
  );
}
