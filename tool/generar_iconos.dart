// Genera todos los íconos de Tu Cajón (Android, iPhone, web y Play Store) a
// partir del diseño en assets/icono/icono.png. Desde la raíz del proyecto:
//
//   dart run tool/generar_iconos.dart
//
// El diseño trae el fondo redondeado ya dibujado, con las esquinas en blanco.
// Pero cada celular recorta el ícono con su propia forma (círculo, cuadrado
// redondeado, gota…), así que primero se rellena todo el cuadrado con el
// color de fondo, y después cada tamaño se arma con el margen que pide su
// plataforma para que el cajón nunca quede cortado.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// El fondo del diseño (igual en android/app/src/main/res/values/colors.xml).
const fondo = (0xF3, 0xF6, 0xFA);

/// Radio de las esquinas del diseño, en fracción del lado (307 de 1254 px).
const radioDiseno = 0.245;

/// Hasta dónde llega el dibujo desde el centro, en fracción de medio lado
/// (las esquinas de abajo del cajón). Sirve para calcular los márgenes.
const alcanceDibujo = 0.95;

const densidades = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

void main() {
  final original = img.decodePng(File('assets/icono/icono.png').readAsBytesSync());
  if (original == null || original.width != original.height) {
    stderr.writeln('assets/icono/icono.png debe ser un PNG cuadrado.');
    exit(1);
  }
  final lienzo = _rellenarFondo(original);

  // Android 8 en adelante: ícono adaptable. Se ven los 72 dp del centro de un
  // lienzo de 108 dp, y lo seguro para cualquier forma es un círculo de 66 dp.
  // El diseño ocupa el 92 % de los 72 dp: así el cajón queda dentro de ese círculo.
  const escalaAdaptable = 72 / 108 * 0.92;
  for (final MapEntry(key: carpeta, value: d) in densidades.entries) {
    final res = 'android/app/src/main/res/mipmap-$carpeta';
    _guardar('$res/ic_launcher_foreground.png', _armar(lienzo, (108 * d).round(), escalaAdaptable));
    // Android 7 (sin ícono adaptable): la forma del diseño ya recortada, y
    // una versión redonda para los que usan íconos redondos.
    final n = (48 * d).round();
    _guardar('$res/ic_launcher.png', _armar(lienzo, n, 44 / 48, forma: _Forma.redondeado));
    _guardar('$res/ic_launcher_round.png', _armar(lienzo, n, 44 / 48 * 0.92, forma: _Forma.circulo));
  }

  // iPhone: cuadrado completo sin transparencia; iOS pone las esquinas.
  final ios = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  for (final archivo in ios.listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
    final n = img.decodePng(archivo.readAsBytesSync())!.width;
    _guardar(archivo.path, _armar(lienzo, n, 1, transparencia: false));
  }

  // Web: con la forma del diseño; los "maskable" dejan el dibujo en el 80 %
  // del centro, que es lo que el navegador garantiza.
  _guardar('web/favicon.png', _armar(lienzo, 16, 1, forma: _Forma.redondeado));
  for (final n in [192, 512]) {
    _guardar('web/icons/Icon-$n.png', _armar(lienzo, n, 1, forma: _Forma.redondeado));
    _guardar('web/icons/Icon-maskable-$n.png', _armar(lienzo, n, 0.8 / alcanceDibujo, transparencia: false));
  }

  // Para la ficha de la Play Store (512 × 512, cuadrado completo).
  _guardar('assets/icono/play_store_512.png', _armar(lienzo, 512, 1));
  stdout.writeln('Listo: íconos de Android, iPhone, web y Play Store.');
}

enum _Forma { cuadrado, redondeado, circulo }

/// El diseño con todo el cuadrado del color de fondo: sin las esquinas
/// blancas ni el borde del redondeado.
img.Image _rellenarFondo(img.Image original) {
  final lado = original.width;
  final r = radioDiseno * lado;
  final lienzo = img.Image(width: lado, height: lado);
  for (var y = 0; y < lado; y++) {
    for (var x = 0; x < lado; x++) {
      // Distancia al borde del redondeado (metido 12 px para no dejar el filo).
      final cx = x.clamp(r, lado - 1 - r);
      final cy = y.clamp(r, lado - 1 - r);
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      final p = original.getPixel(x, y);
      // Cerca del borde, lo que sea más claro que el fondo es el blanco de afuera.
      final blanco = d > r * 0.5 && p.r >= 0xF7 && p.g >= 0xF9 && p.b >= 0xFC;
      if (d > r - 12 || blanco) {
        lienzo.setPixelRgb(x, y, fondo.$1, fondo.$2, fondo.$3);
      } else {
        lienzo.setPixelRgb(x, y, p.r, p.g, p.b);
      }
    }
  }
  return lienzo;
}

/// Un ícono de [n] × [n] px con el diseño ocupando [escala] del lado, sobre el
/// color de fondo, recortado con [forma] (con bordes suaves).
img.Image _armar(
  img.Image lienzo,
  int n,
  double escala, {
  _Forma forma = _Forma.cuadrado,
  bool transparencia = true,
}) {
  final icono = img.Image(width: n, height: n, numChannels: transparencia ? 4 : 3)
    ..clear(img.ColorRgba8(fondo.$1, fondo.$2, fondo.$3, 255));
  final lado = math.min(n, (n * escala).round());
  // Se achica antes de recortar para que el borde transparente no ensucie el color.
  final dibujo = img.copyResize(lienzo, width: lado, height: lado, interpolation: img.Interpolation.average);
  img.compositeImage(icono, dibujo, dstX: (n - lado) ~/ 2, dstY: (n - lado) ~/ 2);
  if (forma == _Forma.cuadrado) return icono;

  // La forma ocupa lo mismo que el dibujo (el redondeado) o 44/48 (el círculo).
  final tamano = forma == _Forma.redondeado ? lado.toDouble() : n * 44 / 48;
  final inicio = (n - tamano) / 2;
  bool dentro(double x, double y) {
    if (forma == _Forma.circulo) {
      return math.pow(x - n / 2, 2) + math.pow(y - n / 2, 2) <= math.pow(tamano / 2, 2);
    }
    final r = radioDiseno * tamano;
    final cx = x.clamp(inicio + r, inicio + tamano - r);
    final cy = y.clamp(inicio + r, inicio + tamano - r);
    return x >= inicio &&
        y >= inicio &&
        x <= inicio + tamano &&
        y <= inicio + tamano &&
        math.pow(x - cx, 2) + math.pow(y - cy, 2) <= r * r;
  }

  // Cuánto de cada píxel queda dentro de la forma (4 × 4 muestras).
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var adentro = 0;
      for (var j = 0; j < 4; j++) {
        for (var i = 0; i < 4; i++) {
          if (dentro(x + (i + 0.5) / 4, y + (j + 0.5) / 4)) adentro++;
        }
      }
      icono.getPixel(x, y).a = (255 * adentro / 16).round();
    }
  }
  return icono;
}

void _guardar(String ruta, img.Image imagen) {
  File(ruta)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(imagen));
  stdout.writeln('  $ruta (${imagen.width} px)');
}
