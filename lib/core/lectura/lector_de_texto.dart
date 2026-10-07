import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Una línea de texto leída y dónde está en la página (en píxeles).
class LineaLeida {
  const LineaLeida(this.texto, this.caja);

  final String texto;
  final Rect caja;
}

/// Lo que se leyó en una página.
class PaginaLeida {
  const PaginaLeida({this.texto = '', this.lineas = const []});

  /// Una página hecha solo de texto, con una línea por renglón (pruebas y
  /// datos de ejemplo). Los renglones miden lo mismo, salvo los de
  /// [titulos], que son más altos, como la letra grande de un título.
  factory PaginaLeida.deTexto(String texto, {Set<int> titulos = const {}}) {
    final renglones = texto.split('\n');
    var y = 0.0;
    final lineas = <LineaLeida>[];
    for (var i = 0; i < renglones.length; i++) {
      final alto = titulos.contains(i) ? 60.0 : 30.0;
      lineas.add(LineaLeida(renglones[i], Rect.fromLTWH(40, y, renglones[i].length * 14.0, alto)));
      y += alto + 12;
    }
    return PaginaLeida(texto: texto, lineas: lineas);
  }

  final String texto;
  final List<LineaLeida> lineas;

  static const vacia = PaginaLeida();
}

/// En este celular (o en el navegador) no se pueden leer documentos.
class LecturaNoDisponible implements Exception {
  const LecturaNoDisponible();

  @override
  String toString() => 'LecturaNoDisponible';
}

/// Lee el texto de la foto de una página.
///
/// En Android usa el reconocimiento de texto de ML Kit (`LectorDeTexto.kt`):
/// un modelo que viene dentro de la app, así que funciona sin internet y la
/// foto no sale del celular.
abstract interface class LectorDeTexto {
  factory LectorDeTexto.paraEstaPlataforma() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? LectorDelSistema()
      : const LectorNoDisponible();

  /// `false` si en este dispositivo no se puede leer.
  bool get disponible;

  /// Lee una imagen (JPEG o PNG). Lanza [LecturaNoDisponible] si este
  /// dispositivo no sabe leer.
  Future<PaginaLeida> leer(Uint8List imagen);
}

/// El de verdad (canal `tu_cajon/leer`).
class LectorDelSistema implements LectorDeTexto {
  static const _canal = MethodChannel('tu_cajon/leer');

  /// Se vuelve `true` si el canal no existe (p. ej. en las pruebas).
  bool _sinCanal = false;

  @override
  bool get disponible => !_sinCanal;

  @override
  Future<PaginaLeida> leer(Uint8List imagen) async {
    if (_sinCanal) throw const LecturaNoDisponible();
    final Map<String, Object?>? r;
    try {
      r = await _canal.invokeMapMethod<String, Object?>('leer', {'imagen': imagen});
    } on MissingPluginException {
      _sinCanal = true;
      throw const LecturaNoDisponible();
    }
    if (r == null) return PaginaLeida.vacia;
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    return PaginaLeida(
      texto: r['texto'] as String? ?? '',
      lineas: [
        for (final l in (r['lineas'] as List<Object?>? ?? const []).cast<Map<Object?, Object?>>())
          LineaLeida(
            l['texto'] as String? ?? '',
            Rect.fromLTWH(n(l['x']), n(l['y']), n(l['ancho']), n(l['alto'])),
          ),
      ],
    );
  }
}

/// Navegador, iPhone (por ahora) y celulares sin el lector.
class LectorNoDisponible implements LectorDeTexto {
  const LectorNoDisponible();

  @override
  bool get disponible => false;

  @override
  Future<PaginaLeida> leer(Uint8List imagen) => Future.error(const LecturaNoDisponible());
}

/// Para pruebas: "lee" los [textos] dados, uno por página, en orden (si se
/// acaban, repite el último).
class LectorSimulado implements LectorDeTexto {
  LectorSimulado({this.textos = const [], this.disponible = true, this.titulos = const {}, this.demora});

  final List<String> textos;

  /// Renglones que se ven como título (más altos), en cada página.
  final Set<int> titulos;

  /// Cuánto tarda cada página (para probar el "Leyendo…").
  final Duration? demora;

  @override
  bool disponible;

  /// Cuántas páginas se han leído.
  int leidas = 0;

  @override
  Future<PaginaLeida> leer(Uint8List imagen) async {
    if (!disponible) throw const LecturaNoDisponible();
    if (demora case final d?) await Future<void>.delayed(d);
    final texto = textos.isEmpty ? '' : textos[math.min(leidas, textos.length - 1)];
    leidas++;
    return PaginaLeida.deTexto(texto, titulos: titulos);
  }
}
