import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pixeles.dart';

/// Calidad de los JPEG que hace el celular (de 0 a 100).
const calidadJpg = 92;

/// Lo pesado de las fotos (abrir, recortar, achicar y pasar a JPEG) con el
/// decodificador y el codificador del celular, varias veces más rápidos que
/// hacerlo en Dart. Canal con `FotosDelCelular.kt`.
///
/// Si no están (pruebas automáticas, web, iPhone por ahora) cada función
/// devuelve `null` y quien llama lo hace en Dart.
abstract final class FotosDelCelular {
  static const _canal = MethodChannel('tu_cajon/fotos');

  /// Se apaga la primera vez que el canal no existe.
  static bool _hay = true;

  /// Ancho y alto de la foto ya derecha (según su marca de giro).
  static Future<(int, int)?> medir(Uint8List jpeg) => _llamar(() async {
    final m = await _canal.invokeMapMethod<String, int>('medir', {'jpeg': jpeg});
    return m == null ? null : (m['ancho']!, m['alto']!);
  });

  /// La parte [amplia] de la foto (en píxeles de la foto derecha), derecha y
  /// achicada a [ladoMaximo] ([original]), y la [parte] dentro de ella
  /// ([base]), en JPEG y sin los datos ocultos de la cámara.
  static Future<({Uint8List base, Uint8List original})?> preparar(
    Uint8List jpeg, {
    required Rect amplia,
    required Rect parte,
    int ladoMaximo = 2400,
  }) => _llamar(() async {
    final r = await _canal.invokeMapMethod<String, Uint8List>('preparar', {
      'jpeg': jpeg,
      'amplia': [amplia.left, amplia.top, amplia.right, amplia.bottom],
      'parte': [parte.left, parte.top, parte.right, parte.bottom],
      'ladoMaximo': ladoMaximo,
      'calidad': calidadJpg,
    });
    return r == null ? null : (base: r['base']!, original: r['original']!);
  });

  /// Los píxeles en JPEG.
  static Future<Uint8List?> jpeg(Pixeles p) => _llamar(
    () => _canal.invokeMethod<Uint8List>('codificar', {
      'rgba': p.rgba,
      'ancho': p.ancho,
      'alto': p.alto,
      'calidad': calidadJpg,
    }),
  );

  static Future<T?> _llamar<T>(Future<T?> Function() llamada) async {
    if (!_hay) return null;
    try {
      return await llamada();
    } on MissingPluginException {
      _hay = false;
      return null;
    } on PlatformException catch (e) {
      debugPrint('La foto se prepara en Dart: ${e.message}');
      return null;
    }
  }
}

/// Pasa los píxeles a JPEG: con el codificador del celular si está, o en
/// Dart en otro hilo.
Future<Uint8List> aJpeg(Pixeles p) async =>
    await FotosDelCelular.jpeg(p) ?? await Isolate.run(() => codificarJpg(p));
