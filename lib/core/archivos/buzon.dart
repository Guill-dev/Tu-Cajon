import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Por qué no se pudo recibir un archivo compartido.
enum ProblemaRecibido {
  /// Pasa del máximo (50 MB un PDF, 30 MB una foto).
  muyGrande,

  /// La otra app no dejó leerlo.
  noSePudo,
}

/// Un archivo que otra app compartió con Tu Cajón.
class ArchivoRecibido {
  const ArchivoRecibido({required this.nombre, required this.tipo, this.bytes, this.problema});

  /// "Certificado_EPS.pdf" (vacío si la otra app no lo dijo).
  final String nombre;

  /// El tipo que dice la otra app: "application/pdf", "image/jpeg"…
  final String tipo;

  /// El contenido, o `null` si hubo un [problema].
  final Uint8List? bytes;
  final ProblemaRecibido? problema;

  bool get esPdf => tipo == 'application/pdf' || nombre.toLowerCase().endsWith('.pdf');
  bool get esFoto => !esPdf && tipo.startsWith('image/');
}

/// Lo que llegó en un envío.
class Envio {
  const Envio({this.archivos = const [], this.sobrantes = 0});

  final List<ArchivoRecibido> archivos;

  /// Cuántos archivos de más no se recibieron (se aceptan hasta 30 a la vez).
  final int sobrantes;
}

/// El buzón de Tu Cajón: lo que otras apps comparten con "Compartir → Tu
/// Cajón" (WhatsApp, Gmail, Drive, la galería…).
///
/// En Android lo recibe `ArchivosRecibidos.kt`, que lee los archivos directo
/// a la memoria, sin copiarlos a ninguna carpeta.
abstract class Buzon {
  factory Buzon.paraEstaPlataforma() => BuzonDelSistema();

  /// Avisa cada vez que llega algo con la app abierta.
  Stream<void> get llegadas;

  /// Si la app se abrió con algo compartido que todavía no se ha tomado.
  Future<bool> hayAlgo();

  /// Lo que llegó, ya leído, y lo saca del buzón.
  Future<Envio> tomar();
}

class BuzonDelSistema implements Buzon {
  BuzonDelSistema() {
    if (_disponible) {
      _canal.setMethodCallHandler((llamada) async {
        if (llamada.method == 'llego') _llegadas.add(null);
      });
    }
  }

  static const _canal = MethodChannel('tu_cajon/recibir');

  final _llegadas = StreamController<void>.broadcast();

  /// Por ahora solo Android: en iPhone hace falta una extensión aparte.
  static bool get _disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<void> get llegadas => _llegadas.stream;

  @override
  Future<bool> hayAlgo() async {
    if (!_disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('revisar') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Envio> tomar() async {
    if (!_disponible) return const Envio();
    final datos = await _canal.invokeMapMethod<String, Object?>('tomar') ?? const {};
    return Envio(
      archivos: [
        for (final a in (datos['archivos'] as List<Object?>? ?? const []).cast<Map<Object?, Object?>>())
          ArchivoRecibido(
            nombre: a['nombre'] as String? ?? '',
            tipo: a['tipo'] as String? ?? '',
            bytes: a['bytes'] as Uint8List?,
            problema: switch (a['problema']) {
              'muy_grande' => ProblemaRecibido.muyGrande,
              null => a['bytes'] == null ? ProblemaRecibido.noSePudo : null,
              _ => ProblemaRecibido.noSePudo,
            },
          ),
      ],
      sobrantes: datos['sobrantes'] as int? ?? 0,
    );
  }
}

/// Para las pruebas: [recibir] hace como si otra app compartiera algo.
class BuzonSimulado implements Buzon {
  BuzonSimulado([this._pendiente]);

  Envio? _pendiente;
  final _llegadas = StreamController<void>.broadcast();

  void recibir(Envio envio) {
    _pendiente = envio;
    _llegadas.add(null);
  }

  @override
  Stream<void> get llegadas => _llegadas.stream;

  @override
  Future<bool> hayAlgo() async => _pendiente != null;

  @override
  Future<Envio> tomar() async {
    final envio = _pendiente ?? const Envio();
    _pendiente = null;
    return envio;
  }
}
