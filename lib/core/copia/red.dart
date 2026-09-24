import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cómo está conectado el celular, para que la copia automática no gaste
/// los datos del plan.
abstract interface class Red {
  factory Red.paraEstaPlataforma() => RedDelSistema();

  /// `true` si la conexión no cobra por datos (Wi-Fi, casi siempre).
  Future<bool> sinLimiteDeDatos();
}

/// La de verdad (canal `tu_cajon/copia`, ver `CopiaDeSeguridad.kt`).
class RedDelSistema implements Red {
  static const _canal = MethodChannel('tu_cajon/copia');

  @override
  Future<bool> sinLimiteDeDatos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _canal.invokeMethod<bool>('red') ?? false;
    } on PlatformException catch (e) {
      debugPrint('No se pudo revisar la red: $e');
      return false;
    } on MissingPluginException {
      return true;
    }
  }
}

/// Para pruebas.
class RedSimulada implements Red {
  RedSimulada({this.wifi = true});

  bool wifi;

  @override
  Future<bool> sinLimiteDeDatos() async => wifi;
}
