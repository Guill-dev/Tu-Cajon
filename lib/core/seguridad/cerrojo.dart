import 'dart:async';

import 'package:flutter/material.dart';

/// Vuelve a cerrar el cajón cada vez que la app sale de la pantalla (otra
/// app, el inicio del celular o la pantalla apagada).
///
/// Al salir pone encima de todo la pantalla "Abrir el cajón", sin animación,
/// para que al volver no se alcance a ver nada. Quien la abre regresa justo
/// donde estaba, porque las pantallas de debajo no se tocan.
///
/// Solo cierra cuando la persona ya había entrado a su cajón: durante la
/// bienvenida o el desbloqueo inicial no hay nada que proteger todavía. Si la
/// app se cierra por completo, al volver a abrirla pasa por la carga y el
/// desbloqueo de siempre.
///
/// Los diálogos del sistema (huella, permisos de cámara) no cuentan como
/// salir: la app sigue visible debajo.
///
/// Excepción: al compartir un documento, o al elegir fotos o un PDF, la app
/// se va a WhatsApp, a la galería o al explorador de archivos a propósito. Esa salida se permite con [permitirSalida]; si la
/// persona vuelve antes de [tiempoFueraPermitido], sigue donde estaba. Si
/// tarda más, al volver el cajón está cerrado como siempre.
class Cerrojo {
  Cerrojo({required this.navegador, required this.pantallaCerrada, this.alCerrar, DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now {
    _oyente = AppLifecycleListener(onHide: _alSalir, onShow: _alVolver);
  }

  /// Cuánto puede durar una salida permitida (ir a WhatsApp y enviar).
  static const tiempoFueraPermitido = Duration(minutes: 2);

  /// Margen para que la app alcance a salir después de [permitirSalida]
  /// (incluye armar el PDF, que con varias fotos toma unos segundos).
  static const _margenParaSalir = Duration(seconds: 20);

  final GlobalKey<NavigatorState> navegador;

  /// La pantalla que se pone encima. Recibe con qué avisar que ya abrió.
  final Widget Function(VoidCallback alAbrir) pantallaCerrada;

  /// Se llama cada vez que el cajón se cierra (p. ej. borrar PDF compartidos).
  final VoidCallback? alCerrar;

  final DateTime Function() _reloj;
  late final AppLifecycleListener _oyente;
  bool _dentro = false;
  bool _cerrado = false;

  /// Hasta cuándo la próxima salida no cierra el cajón.
  DateTime? _salidaPermitidaHasta;

  /// Cuándo empezó una salida permitida que todavía no ha vuelto.
  DateTime? _fueraDesde;

  /// `true` mientras la pantalla de cerrado está puesta.
  bool get cerrado => _cerrado;

  Completer<void>? _alAbrirse;

  /// Termina cuando el cajón está abierto (enseguida, si no está cerrado).
  /// Sirve para no seguir un proceso (p. ej. lo que se eligió en la
  /// galería) por encima de la pantalla de cerrado.
  Future<void> esperarAbierto() {
    if (!_cerrado) return Future.value();
    return (_alAbrirse ??= Completer<void>()).future;
  }

  /// La persona abrió su cajón (con la llave o al terminar la bienvenida).
  void entrar() => _dentro = true;

  /// La app está por irse a otra a propósito (compartir un documento).
  void permitirSalida() => _salidaPermitidaHasta = _reloj().add(_margenParaSalir);

  /// Al final no se salió (falló o no había nada que enviar).
  void cancelarSalida() => _salidaPermitidaHasta = null;

  void _alSalir() {
    final hasta = _salidaPermitidaHasta;
    _salidaPermitidaHasta = null;
    if (hasta != null && _reloj().isBefore(hasta)) {
      _fueraDesde = _reloj();
      return;
    }
    cerrar();
  }

  void _alVolver() {
    final desde = _fueraDesde;
    _fueraDesde = null;
    if (desde != null && _reloj().difference(desde) > tiempoFueraPermitido) cerrar();
  }

  void cerrar() {
    alCerrar?.call();
    final nav = navegador.currentState;
    if (!_dentro || _cerrado || nav == null) return;
    _cerrado = true;
    late final Route<void> ruta;
    ruta = PageRouteBuilder<void>(
      // Aparece de golpe (la app no se ve mientras tanto) y se va con fundido.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => PopScope(
        // El botón "atrás" no se salta la llave.
        canPop: false,
        child: pantallaCerrada(() => ruta.isCurrent ? nav.pop() : nav.removeRoute(ruta)),
      ),
      transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
    );
    nav.push(ruta).whenComplete(() {
      _cerrado = false;
      _alAbrirse?.complete();
      _alAbrirse = null;
    });
  }

  void dispose() => _oyente.dispose();
}

/// Pone el cerrojo al alcance de las pantallas: `context.cerrojo`.
class CerrojoScope extends InheritedWidget {
  const CerrojoScope({super.key, required this.cerrojo, required super.child});

  final Cerrojo cerrojo;

  @override
  bool updateShouldNotify(CerrojoScope oldWidget) => cerrojo != oldWidget.cerrojo;
}

extension CerrojoContexto on BuildContext {
  Cerrojo get cerrojo {
    final scope = getInheritedWidgetOfExactType<CerrojoScope>();
    assert(scope != null, 'Falta CerrojoScope arriba en el árbol de widgets.');
    return scope!.cerrojo;
  }
}
