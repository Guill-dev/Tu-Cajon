import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/lectura/lector_de_texto.dart';
import '../models/documento.dart';
import '../repositorio/cajon_repositorio.dart';
import 'lectura_de_documentos.dart';

/// Lee, uno por uno y sin molestar, los documentos que todavía no tienen su
/// texto: los que se guardaron antes de que la app supiera leer, o los que
/// se guardaron antes de que terminara la lectura. Así la búsqueda y
/// "Pregúntale a tu cajón" los encuentran por lo que dicen.
///
/// Cada documento se intenta una sola vez (y otra si se le cambian las
/// páginas): una foto sin letras no se vuelve a leer cada vez que se abre.
class LectorDelCajon {
  LectorDelCajon({required this.repo, required this.lectura, this.espera = const Duration(seconds: 8)}) {
    _cambios = repo.vigilarTodos().listen(_programar);
  }

  final CajonRepositorio repo;
  final LecturaDeDocumentos lectura;

  /// Cuánto se espera después de un cambio, para no competir con lo que la
  /// persona está haciendo (p. ej. la lectura de la pantalla de Guardar).
  final Duration espera;

  static const _claveIntentados = 'lectura.intentados';

  late final StreamSubscription<List<Documento>> _cambios;
  Timer? _temporizador;
  bool _leyendo = false;
  bool _cerrado = false;

  static bool _faltaLeer(Documento d) => d.archivo != null && d.textoExtraido.trim().isEmpty;

  /// La versión de las páginas: al reemplazarlas cambia la fecha de guardado.
  static String _clave(Documento d) => '${d.id}@${d.guardadoEn.millisecondsSinceEpoch}';

  void _programar(List<Documento> documentos) {
    if (_cerrado || !lectura.disponible || !documentos.any(_faltaLeer)) return;
    _temporizador?.cancel();
    _temporizador = Timer(espera, leerPendientes);
  }

  Future<Set<String>> _intentados() async {
    final guardado = await repo.leerAjuste(_claveIntentados);
    if (guardado == null) return {};
    try {
      return {...(jsonDecode(guardado) as List<Object?>).cast<String>()};
    } catch (_) {
      return {};
    }
  }

  /// Lee los que falten. Si ya está leyendo, no hace nada.
  Future<void> leerPendientes() async {
    if (_leyendo || _cerrado) return;
    _leyendo = true;
    try {
      final intentados = await _intentados();
      while (!_cerrado) {
        final documentos = await repo.vigilarTodos().first;
        final siguiente = documentos
            .where((d) => _faltaLeer(d) && !intentados.contains(_clave(d)))
            .firstOrNull;
        if (siguiente == null) break;
        intentados.add(_clave(siguiente));
        try {
          final leido = await lectura.releer(repo, siguiente);
          if (_cerrado) break;
          if (leido.conTexto) await repo.guardarTexto(siguiente.id, leido.texto);
        } on LecturaNoDisponible {
          break;
        } catch (e) {
          debugPrint('No se pudo leer «${siguiente.nombre}»: $e');
        }
        // Solo los que siguen en el cajón (los borrados no se guardan para siempre).
        final vigentes = {for (final d in documentos) _clave(d)};
        await repo.guardarAjuste(_claveIntentados, jsonEncode(intentados.where(vigentes.contains).toList()));
      }
    } finally {
      _leyendo = false;
    }
  }

  void dispose() {
    _cerrado = true;
    _temporizador?.cancel();
    _cambios.cancel();
  }
}
