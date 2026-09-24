import 'dart:async';

import 'package:flutter/widgets.dart';

import '../repositorio/cajon_repositorio.dart';
import 'copia_de_seguridad.dart';

/// Hace la copia sola, sin que nadie tenga que acordarse:
/// - un rato después de guardar o cambiar algo ([espera], por si la persona
///   sigue haciendo cambios, así sale una sola copia),
/// - y al abrir la app o volver a ella, si la última tiene más de un día.
///
/// Solo con la cuenta conectada. La copia respeta "Solo con Wi-Fi".
class ProgramadorDeCopias with WidgetsBindingObserver {
  ProgramadorDeCopias({
    required this.copia,
    required CajonRepositorio repo,
    this.espera = const Duration(seconds: 20),
    this.cadaCuanto = const Duration(days: 1),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    // Cada cambio en el cajón (el primer valor de cada Stream es el actual, no un cambio).
    _cambios = [
      repo.vigilarTodos().skip(1).listen((_) => _programar()),
      repo.vigilarPerfiles().skip(1).listen((_) => _programar()),
      // `distinct`: el nombre vive en la tabla de ajustes, donde la copia también
      // anota lo suyo; sin esto, cada copia terminada programaría otra.
      repo.vigilarNombre().distinct().skip(1).listen((_) => _programar()),
      repo.vigilarSugerenciasDescartadas().skip(1).listen((_) => _programar()),
    ];
    copia.listo.then((_) => _siHaceFalta());
  }

  final CopiaDeSeguridad copia;
  final Duration espera;
  final Duration cadaCuanto;
  final DateTime Function() _reloj;

  late final List<StreamSubscription<Object?>> _cambios;
  Timer? _temporizador;
  bool _cerrado = false;

  void _programar() {
    if (_cerrado || !copia.estado.value.conectada) return;
    _temporizador?.cancel();
    _temporizador = Timer(espera, () => copia.hacerCopia(automatica: true));
  }

  void _siHaceFalta() {
    final e = copia.estado.value;
    if (!e.conectada) return;
    final ultima = e.ultima;
    if (ultima == null || e.esperandoWifi || _reloj().difference(ultima) >= cadaCuanto) _programar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _siHaceFalta();
  }

  void dispose() {
    _cerrado = true;
    _temporizador?.cancel();
    for (final s in _cambios) {
      s.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
  }
}
