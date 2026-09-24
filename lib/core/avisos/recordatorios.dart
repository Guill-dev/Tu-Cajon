import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_colors.dart';

/// Un aviso para el celular: cuándo, qué dice y qué documento abre al tocarlo.
class AvisoProgramado {
  const AvisoProgramado({
    required this.cuando,
    required this.titulo,
    required this.cuerpo,
    required this.documentoId,
  });

  final DateTime cuando;
  final String titulo;
  final String cuerpo;
  final String documentoId;

  @override
  String toString() => 'AvisoProgramado($cuando, $titulo)';
}

/// Si la app puede mostrar notificaciones.
enum PermisoAvisos {
  permitido,

  /// Todavía se puede pedir.
  sinPedir,

  /// La persona dijo que no para siempre: solo se activa desde los ajustes.
  bloqueado,
}

/// Las notificaciones de Tu Cajón: los avisos de vencimiento y los
/// recordatorios sueltos ("Recordarme el lunes").
///
/// Todo se programa en el mismo celular (sin internet). Android los muestra
/// aunque la app esté cerrada y los vuelve a programar si se reinicia.
abstract class Recordatorios {
  factory Recordatorios.paraEstaPlataforma() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? RecordatoriosDelSistema()
      : RecordatoriosSimulados();

  /// Prepara las notificaciones. [alTocar] recibe el documento de un aviso
  /// que la persona tocó (también si la app se abrió desde uno).
  Future<void> iniciar(void Function(String documentoId) alTocar);

  Future<PermisoAvisos> permiso();

  /// Muestra el diálogo del celular para permitir las notificaciones.
  /// Devuelve si quedaron permitidas.
  Future<bool> pedirPermiso();

  /// Los ajustes de notificaciones de la app (si se bloquearon).
  Future<void> abrirAjustes();

  /// Cambia todos los avisos de vencimiento por [avisos].
  Future<void> programarVencimientos(List<AvisoProgramado> avisos);

  /// Un recordatorio suelto; no se borra al cambiar los vencimientos.
  Future<void> programarRecordatorio(AvisoProgramado aviso);
}

class RecordatoriosDelSistema implements Recordatorios {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Los avisos de vencimiento usan los números 1 a 99 999; los
  /// recordatorios sueltos, del 100 000 en adelante.
  static const _primerRecordatorio = 100000;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'vencimientos',
      'Vencimientos',
      channelDescription: 'Te avisa antes de que venza un documento.',
      icon: 'ic_notificacion',
      color: AppColors.primario,
      category: AndroidNotificationCategory.reminder,
      // En la pantalla bloqueada, si el celular oculta el contenido
      // sensible, no se ve el nombre del documento.
      visibility: NotificationVisibility.private,
    ),
  );

  @override
  Future<void> iniciar(void Function(String documentoId) alTocar) async {
    void tocado(NotificationResponse r) {
      final id = r.payload;
      if (id != null && id.isNotEmpty) alTocar(id);
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notificacion')),
        onDidReceiveNotificationResponse: tocado,
      );
      final inicio = await _plugin.getNotificationAppLaunchDetails();
      if (inicio != null && inicio.didNotificationLaunchApp) {
        if (inicio.notificationResponse case final r?) tocado(r);
      }
    } catch (e) {
      // Sin notificaciones (p. ej. en las pruebas automáticas) la app sigue igual.
      debugPrint('No se pudieron preparar las notificaciones: $e');
    }
  }

  @override
  Future<PermisoAvisos> permiso() async {
    try {
      final estado = await Permission.notification.status;
      if (estado.isGranted) return PermisoAvisos.permitido;
      if (estado.isPermanentlyDenied) return PermisoAvisos.bloqueado;
    } catch (e) {
      debugPrint('No se pudo revisar el permiso de notificaciones: $e');
    }
    return PermisoAvisos.sinPedir;
  }

  @override
  Future<bool> pedirPermiso() async {
    try {
      return (await Permission.notification.request()).isGranted;
    } catch (e) {
      // Por ejemplo, si ya había otro permiso pidiéndose.
      debugPrint('No se pudo pedir el permiso de notificaciones: $e');
      return false;
    }
  }

  @override
  Future<void> abrirAjustes() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {
      await openAppSettings();
    }
  }

  @override
  Future<void> programarVencimientos(List<AvisoProgramado> avisos) async {
    try {
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.id < _primerRecordatorio) await _plugin.cancel(id: p.id);
      }
      for (final (i, aviso) in avisos.take(_primerRecordatorio - 1).indexed) {
        await _programar(i + 1, aviso);
      }
    } catch (e) {
      debugPrint('No se pudieron programar los avisos: $e');
    }
  }

  @override
  Future<void> programarRecordatorio(AvisoProgramado aviso) async {
    // El mismo documento el mismo día reemplaza al anterior.
    final id = _primerRecordatorio + Object.hash(aviso.documentoId, aviso.cuando).abs() % 1000000000;
    await _programar(id, aviso);
  }

  Future<void> _programar(int id, AvisoProgramado aviso) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        // La hora ya viene en la hora del celular; en UTC es el mismo momento.
        scheduledDate: tz.TZDateTime.from(aviso.cuando, tz.UTC),
        notificationDetails: _detalles,
        // Sin alarma exacta (no hace falta pedir otro permiso): llega hacia esa hora.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: aviso.titulo,
        body: aviso.cuerpo,
        payload: aviso.documentoId,
      );
    } on ArgumentError catch (e) {
      // Ya pasó la hora mientras se programaba.
      debugPrint('Aviso no programado: $e');
    }
  }
}

/// Para las pruebas y el navegador: anota lo que se programa.
class RecordatoriosSimulados implements Recordatorios {
  RecordatoriosSimulados({this.estado = PermisoAvisos.permitido, this.aceptaAlPedir = true});

  PermisoAvisos estado;

  /// Qué responde la persona si se le pide el permiso.
  bool aceptaAlPedir;

  List<AvisoProgramado> vencimientos = const [];
  final recordatorios = <AvisoProgramado>[];
  int permisosPedidos = 0;
  int ajustesAbiertos = 0;
  void Function(String documentoId)? _alTocar;

  /// Hace como si la persona tocara un aviso de [documentoId].
  void tocar(String documentoId) => _alTocar?.call(documentoId);

  @override
  Future<void> iniciar(void Function(String documentoId) alTocar) async => _alTocar = alTocar;

  @override
  Future<PermisoAvisos> permiso() async => estado;

  @override
  Future<bool> pedirPermiso() async {
    permisosPedidos++;
    if (aceptaAlPedir) estado = PermisoAvisos.permitido;
    return estado == PermisoAvisos.permitido;
  }

  @override
  Future<void> abrirAjustes() async => ajustesAbiertos++;

  @override
  Future<void> programarVencimientos(List<AvisoProgramado> avisos) async => vencimientos = [...avisos];

  @override
  Future<void> programarRecordatorio(AvisoProgramado aviso) async => recordatorios.add(aviso);
}

/// Pone las notificaciones al alcance de las pantallas: `context.recordatorios`.
class RecordatoriosScope extends InheritedWidget {
  const RecordatoriosScope({super.key, required this.recordatorios, required super.child});

  final Recordatorios recordatorios;

  @override
  bool updateShouldNotify(RecordatoriosScope oldWidget) => recordatorios != oldWidget.recordatorios;
}

extension RecordatoriosContexto on BuildContext {
  Recordatorios get recordatorios {
    final scope = getInheritedWidgetOfExactType<RecordatoriosScope>();
    assert(scope != null, 'Falta RecordatoriosScope arriba en el árbol de widgets.');
    return scope!.recordatorios;
  }
}
