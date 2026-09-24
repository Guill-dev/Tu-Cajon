import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/avisos/recordatorios.dart';
import '../../core/formato.dart';
import '../../data/models/documento.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/cajon_repositorio.dart';

/// A qué hora llegan los avisos (hora del celular).
const horaDeAvisos = 9;

/// Cuántos días antes del vencimiento se avisa (0 = el mismo día).
const diasDeAviso = [30, 7, 0];

/// Los avisos de vencimiento de [docs] que todavía no han pasado: 30 días
/// antes, 7 días antes y el mismo día, a las 9 de la mañana. Del más
/// próximo al más lejano.
List<AvisoProgramado> calcularAvisos(List<Documento> docs, Map<String, Perfil> perfiles, DateTime ahora) {
  final avisos = <AvisoProgramado>[];
  for (final d in docs) {
    final vence = d.venceEn;
    if (vence == null) continue;
    final nombre = _nombreCon(d, perfiles);
    for (final dias in diasDeAviso) {
      final cuando = DateTime(vence.year, vence.month, vence.day - dias, horaDeAvisos);
      if (!cuando.isAfter(ahora)) continue;
      avisos.add(
        AvisoProgramado(
          cuando: cuando,
          titulo: dias == 0 ? '$nombre vence hoy' : '$nombre vence en $dias días',
          cuerpo: dias == 0
              ? 'Si ya lo renovaste, guarda el nuevo con «Reemplazar».'
              : 'Vence el ${Formato.fechaLarga(vence)}. Toca para verlo.',
          documentoId: d.id,
        ),
      );
    }
  }
  avisos.sort((a, b) => a.cuando.compareTo(b.cuando));
  return avisos;
}

/// "Recordarme el lunes": un aviso ese [lunes] a las 9 de la mañana.
AvisoProgramado avisoDeRenovar(Documento d, Map<String, Perfil> perfiles, DateTime lunes) => AvisoProgramado(
  cuando: DateTime(lunes.year, lunes.month, lunes.day, horaDeAvisos),
  titulo: 'Recuerda renovar ${_nombreCon(d, perfiles)}',
  cuerpo: d.venceEn == null
      ? 'Toca para verlo.'
      : 'Vence el ${Formato.fechaLarga(d.venceEn!)}. Toca para verlo.',
  documentoId: d.id,
);

/// "«Licencia de conducción»", o "«Licencia de conducción» de Mamá" si es
/// de otro perfil.
String _nombreCon(Documento d, Map<String, Perfil> perfiles) {
  final perfil = perfiles[d.perfilId];
  final de = perfil == null || perfil.esPropio ? '' : ' de ${perfil.nombre}';
  return '«${d.nombre}»$de';
}

/// Mantiene programados los avisos de vencimiento: cada vez que cambian los
/// documentos (uno nuevo, otra fecha, uno borrado), los vuelve a calcular.
class ProgramadorDeAvisos {
  ProgramadorDeAvisos({
    required CajonRepositorio repo,
    required this.recordatorios,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now {
    _docs = repo.vigilarTodos().listen((d) {
      _documentos = d;
      _reprogramar();
    });
    _perfilesSub = repo.vigilarPerfiles().listen((p) {
      _perfiles = {for (final x in p) x.id: x};
      _reprogramar();
    });
  }

  final Recordatorios recordatorios;
  final DateTime Function() _reloj;
  late final StreamSubscription<List<Documento>> _docs;
  late final StreamSubscription<List<Perfil>> _perfilesSub;
  List<Documento>? _documentos;
  Map<String, Perfil> _perfiles = const {};

  /// Una sola programación a la vez; si llegan cambios mientras tanto, al
  /// terminar se hace una más con lo último.
  Future<void> _cola = Future.value();
  bool _hayCambios = false;

  void _reprogramar() {
    if (_documentos == null) return;
    if (_hayCambios) return;
    _hayCambios = true;
    _cola = _cola
        .then((_) {
          _hayCambios = false;
          return recordatorios.programarVencimientos(calcularAvisos(_documentos!, _perfiles, _reloj()));
        })
        .catchError((Object e) => debugPrint('No se pudieron programar los avisos: $e'));
  }

  void dispose() {
    _docs.cancel();
    _perfilesSub.cancel();
  }
}
