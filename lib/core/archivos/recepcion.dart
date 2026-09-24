import 'dart:async';

import 'package:flutter/widgets.dart';

import '../router/app_routes.dart';
import '../seguridad/cerrojo.dart';
import 'buzon.dart';

/// Lleva lo que llega desde afuera a su pantalla: lo compartido con
/// "Compartir → Tu Cajón" a la de recibir, y el documento de un aviso que se
/// tocó a su detalle. Pero solo con la persona ya dentro de su cajón:
///
/// - si el cajón está cerrado, primero tiene que abrirlo con su llave;
/// - si la app apenas arranca (carga, desbloqueo) o todavía no termina la
///   bienvenida, espera a que entre a "Mi cajón".
///
/// Así nada se ve sin la llave, y nada de lo que llega se pone encima de la
/// pantalla de la llave.
class Recepcion {
  Recepcion({required this.buzon, required this.navegador, required this.cerrojo}) {
    rutas.addListener(_programar);
    _suscripcion = buzon.llegadas.listen((_) {
      _pendiente = true;
      _programar();
    });
    revisado = buzon.hayAlgo().then((hay) {
      if (hay) {
        _pendiente = true;
        _programar();
      }
      return hay;
    }, onError: (Object _) => false);
  }

  final Buzon buzon;
  final GlobalKey<NavigatorState> navegador;
  final Cerrojo cerrojo;

  /// Va en `MaterialApp.navigatorObservers`: dice qué pantallas están abiertas.
  final rutas = RutasAbiertas();

  /// Termina al saber si la app se abrió con algo compartido.
  late final Future<bool> revisado;

  late final StreamSubscription<void> _suscripcion;
  bool _pendiente = false;
  bool _esperandoLlave = false;

  /// Documentos por abrir (se tocó su aviso).
  final _porAbrir = <String>[];

  /// Hay algo esperando la llave: lo compartido o un aviso que se tocó.
  bool get hayAlgoPorAbrir => _pendiente || _porAbrir.isNotEmpty;

  /// Abre el documento [id] en cuanto la persona esté dentro de su cajón.
  void abrirDocumento(String id) {
    _porAbrir.add(id);
    _programar();
  }

  // Los avisos llegan en medio de un cambio de pantalla; se atienden después.
  void _programar() => scheduleMicrotask(_intentar);

  void _intentar() {
    if (!_pendiente && _porAbrir.isEmpty) return;
    if (cerrojo.cerrado) {
      if (!_esperandoLlave) {
        _esperandoLlave = true;
        cerrojo.esperarAbierto().then((_) {
          _esperandoLlave = false;
          _programar();
        });
      }
      return;
    }
    // Cada cambio de pantalla vuelve a revisar.
    if (!rutas.contiene(AppRoutes.cajon)) return;
    final nav = navegador.currentState;
    if (nav == null) return;
    for (final id in _porAbrir) {
      nav.pushNamed(AppRoutes.detalle, arguments: id);
    }
    _porAbrir.clear();
    if (_pendiente) {
      _pendiente = false;
      nav.pushNamed(AppRoutes.recibir, arguments: buzon.tomar());
    }
  }

  void dispose() {
    rutas.removeListener(_programar);
    _suscripcion.cancel();
    rutas.dispose();
  }
}

/// Anota qué pantallas están abiertas y avisa cuando cambian.
class RutasAbiertas extends NavigatorObserver with ChangeNotifier {
  final _rutas = <Route<dynamic>>[];

  bool contiene(String nombre) => _rutas.any((r) => r.settings.name == nombre);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(() => _rutas.add(route));

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(() => _rutas.remove(route));

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(() => _rutas.remove(route));

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _cambiar(() {
    _rutas.remove(oldRoute);
    if (newRoute != null) _rutas.add(newRoute);
  });

  void _cambiar(VoidCallback cambio) {
    cambio();
    notifyListeners();
  }
}

/// Pone la recepción al alcance de las pantallas: `context.recepcion`.
class RecepcionScope extends InheritedWidget {
  const RecepcionScope({super.key, required this.recepcion, required super.child});

  final Recepcion recepcion;

  @override
  bool updateShouldNotify(RecepcionScope oldWidget) => recepcion != oldWidget.recepcion;
}

extension RecepcionContexto on BuildContext {
  Recepcion get recepcion {
    final scope = getInheritedWidgetOfExactType<RecepcionScope>();
    assert(scope != null, 'Falta RecepcionScope arriba en el árbol de widgets.');
    return scope!.recepcion;
  }
}
