import 'package:flutter/widgets.dart';

import 'copia_de_seguridad.dart';

/// La copia programada con la app abierta.
///
/// A la hora exacta (cada día, semana o mes, desde que se eligió), Android
/// despierta a la app aunque esté cerrada y la copia se hace sola (ver
/// `copia_en_segundo_plano.dart`). Aquí, al abrir la app o volver a ella:
/// - se vuelve a leer cómo va (pudo hacerse mientras tanto),
/// - y si a una copia ya le tocó y no se hizo (el celular estaba apagado o
///   sin internet a esa hora), se hace de una vez.
class ProgramadorDeCopias with WidgetsBindingObserver {
  ProgramadorDeCopias({required this.copia}) {
    WidgetsBinding.instance.addObserver(this);
    copia.listo.then((_) => _ponerAlDia());
  }

  final CopiaDeSeguridad copia;
  bool _cerrado = false;

  Future<void> _ponerAlDia() async {
    if (_cerrado) return;
    await copia.recargar();
    if (_cerrado) return;
    await copia.siToca();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ponerAlDia();
  }

  void dispose() {
    _cerrado = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
