import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Por qué no se pudo leer un PDF.
enum ProblemaPdf {
  /// Tiene contraseña: se puede guardar, pero no mostrar sus páginas.
  conClave,

  /// No es un PDF válido o está dañado.
  invalido,

  /// Este celular (o el navegador) no puede dibujar PDF.
  noDisponible,
}

class ErrorPdf implements Exception {
  const ErrorPdf(this.problema);

  final ProblemaPdf problema;

  String get mensaje => switch (problema) {
    ProblemaPdf.conClave => 'Este PDF tiene contraseña. Se puede guardar, pero no ver sus páginas aquí.',
    ProblemaPdf.invalido => 'Este archivo no parece un PDF válido.',
    ProblemaPdf.noDisponible => 'La vista previa del PDF no está disponible en este dispositivo.',
  };

  @override
  String toString() => 'ErrorPdf($problema)';
}

/// Lee PDF con el lector nativo del celular (`LectorPdf.kt` en Android),
/// sin dejar copias sin cifrar en el disco.
abstract final class LectorPdf {
  static const _canal = MethodChannel('tu_cajon/pdf');

  /// `true` si los bytes empiezan como un PDF ("%PDF").
  static bool pareceUnPdf(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;

  /// Cuántas páginas tiene. Lanza [ErrorPdf] si no se puede leer.
  static Future<int> contarPaginas(Uint8List pdf) async {
    final n = await _llamar<int>('contar', {'pdf': pdf});
    return n ?? 0;
  }

  /// Las páginas [desde]‥[hasta] (sin incluir) como imágenes JPEG de [ancho]
  /// píxeles. Lanza [ErrorPdf] si no se puede leer.
  static Future<List<Uint8List>> dibujar(Uint8List pdf, {int ancho = 1200, int desde = 0, int? hasta}) async {
    final paginas = await _llamar<List<Object?>>('dibujar', {
      'pdf': pdf,
      'ancho': ancho,
      'desde': desde,
      'hasta': ?hasta,
    });
    return [for (final p in paginas ?? const []) p as Uint8List];
  }

  static Future<T?> _llamar<T>(String metodo, Map<String, Object?> datos) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const ErrorPdf(ProblemaPdf.noDisponible);
    }
    try {
      return await _canal.invokeMethod<T>(metodo, datos);
    } on MissingPluginException {
      throw const ErrorPdf(ProblemaPdf.noDisponible);
    } on PlatformException catch (e) {
      throw ErrorPdf(e.code == 'con_clave' ? ProblemaPdf.conClave : ProblemaPdf.invalido);
    }
  }
}
