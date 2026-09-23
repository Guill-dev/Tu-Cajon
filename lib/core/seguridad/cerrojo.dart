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
class Cerrojo {
  Cerrojo({required this.navegador, required this.pantallaCerrada}) {
    _oyente = AppLifecycleListener(onHide: cerrar);
  }

  final GlobalKey<NavigatorState> navegador;

  /// La pantalla que se pone encima. Recibe con qué avisar que ya abrió.
  final Widget Function(VoidCallback alAbrir) pantallaCerrada;

  late final AppLifecycleListener _oyente;
  bool _dentro = false;
  bool _cerrado = false;

  /// `true` mientras la pantalla de cerrado está puesta.
  bool get cerrado => _cerrado;

  /// La persona abrió su cajón (con la llave o al terminar la bienvenida).
  void entrar() => _dentro = true;

  void cerrar() {
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
    nav.push(ruta).whenComplete(() => _cerrado = false);
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
