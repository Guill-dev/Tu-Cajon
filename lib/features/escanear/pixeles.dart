import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Los píxeles de una foto (RGBA, 4 bytes por píxel), ya derecha.
///
/// Se pueden mandar a otro hilo (`Isolate.run`) para recortar, filtrar y
/// volver a JPEG sin trabar la pantalla.
class Pixeles {
  const Pixeles(this.rgba, this.ancho, this.alto);

  final Uint8List rgba;
  final int ancho;
  final int alto;
}

/// Abre un JPEG con el decodificador del celular (rápido, fuera de Dart) y
/// devuelve sus píxeles. Si la cámara guardó la foto "acostada" con una marca
/// de giro, sale ya enderezada.
Future<Pixeles> decodificarFoto(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final cuadro = await codec.getNextFrame();
  codec.dispose();
  final imagen = cuadro.image;
  try {
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (datos == null) throw StateError('No se pudieron leer los píxeles de la foto.');
    return Pixeles(
      datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
      imagen.width,
      imagen.height,
    );
  } finally {
    imagen.dispose();
  }
}

/// Pasa los píxeles a JPEG (calidad alta y sin mezclar el color entre
/// píxeles vecinos, para que los bordes de las letras queden limpios).
Uint8List codificarJpg(Pixeles p, {int calidad = 90}) {
  final foto = img.Image.fromBytes(
    width: p.ancho,
    height: p.alto,
    bytes: p.rgba.buffer,
    bytesOffset: p.rgba.offsetInBytes,
    numChannels: 4,
  );
  return img.encodeJpg(foto, quality: calidad, chroma: img.JpegChroma.yuv444);
}

/// Copia el rectángulo (en píxeles) sin salirse de la foto.
Pixeles recortarPixeles(Pixeles p, int x, int y, int ancho, int alto) {
  final px = x.clamp(0, p.ancho - 1);
  final py = y.clamp(0, p.alto - 1);
  final w = ancho.clamp(1, p.ancho - px);
  final h = alto.clamp(1, p.alto - py);
  final salida = Uint8List(w * h * 4);
  for (var fila = 0; fila < h; fila++) {
    final desde = ((py + fila) * p.ancho + px) * 4;
    salida.setRange(fila * w * 4, (fila + 1) * w * 4, p.rgba, desde);
  }
  return Pixeles(salida, w, h);
}

/// Si la foto tiene un lado más largo que [ladoMaximo], la achica
/// promediando píxeles (sin perder nitidez). Así el PDF no pesa de más.
Pixeles achicarSiHaceFalta(Pixeles p, {int ladoMaximo = 2400}) {
  final lado = math.max(p.ancho, p.alto);
  if (lado <= ladoMaximo) return p;
  final escala = ladoMaximo / lado;
  final foto = img.Image.fromBytes(
    width: p.ancho,
    height: p.alto,
    bytes: p.rgba.buffer,
    bytesOffset: p.rgba.offsetInBytes,
    numChannels: 4,
  );
  final chica = img.copyResize(
    foto,
    width: math.max(1, (p.ancho * escala).round()),
    height: math.max(1, (p.alto * escala).round()),
    interpolation: img.Interpolation.average,
  );
  return Pixeles(chica.getBytes(order: img.ChannelOrder.rgba), chica.width, chica.height);
}
