import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Cómo terminó un intento de abrir el cajón.
enum ResultadoLlave {
  /// El celular confirmó que es su dueño.
  abierto,

  /// La persona cerró el diálogo del celular.
  cancelado,

  /// El celular no tiene bloqueo de pantalla (ni huella, ni rostro, ni PIN).
  sinBloqueo,

  /// Demasiados intentos fallidos: el celular pide esperar.
  bloqueado,

  /// Cualquier otro problema del sistema.
  fallo;

  /// Mensaje para la persona. `null` cuando no hay nada que avisar.
  String? get aviso => switch (this) {
    abierto || cancelado => null,
    sinBloqueo => 'Tu celular no tiene bloqueo de pantalla. Ponle un PIN, patrón, huella o rostro en los ajustes del celular y vuelve a intentarlo.',
    bloqueado => 'Hubo muchos intentos. Espera un momento y vuelve a intentarlo.',
    fallo => 'No pudimos usar la llave del celular. Vuelve a intentarlo.',
  };
}

/// La llave del cajón: lo mismo que desbloquea el celular (huella, rostro,
/// PIN, patrón o contraseña). El celular elige y muestra su propio diálogo.
abstract class LlaveCelular {
  /// Llave real en Android e iOS; simulada en el navegador, que no tiene.
  factory LlaveCelular.paraEstaPlataforma() => kIsWeb ? LlaveSimulada() : LlaveDelSistema();

  Future<ResultadoLlave> abrir(String motivo);
}

/// Usa el bloqueo del teléfono a través de `local_auth`.
class LlaveDelSistema implements LlaveCelular {
  LlaveDelSistema({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<ResultadoLlave> abrir(String motivo) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        // Huella o rostro si hay; si no, o si la persona prefiere, el PIN,
        // patrón o contraseña del celular.
        biometricOnly: false,
        // Si entra una llamada a mitad, se vuelve a pedir al regresar.
        persistAcrossBackgrounding: true,
        authMessages: const [
          AndroidAuthMessages(signInTitle: 'Abrir Tu Cajón', cancelButton: 'Cancelar'),
          IOSAuthMessages(cancelButton: 'Cancelar'),
        ],
      );
      return ok ? ResultadoLlave.abierto : ResultadoLlave.cancelado;
    } on LocalAuthException catch (e) {
      debugPrint('Llave del celular: ${e.code} ${e.description ?? ''}');
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress => ResultadoLlave.cancelado,
        LocalAuthExceptionCode.noCredentialsSet => ResultadoLlave.sinBloqueo,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => ResultadoLlave.bloqueado,
        _ => ResultadoLlave.fallo,
      };
    } on PlatformException catch (e) {
      debugPrint('Llave del celular: $e');
      return ResultadoLlave.fallo;
    }
  }
}

/// Para el navegador y las pruebas: abre sola después de [espera].
class LlaveSimulada implements LlaveCelular {
  LlaveSimulada({this.espera = const Duration(milliseconds: 1200), this.resultado = ResultadoLlave.abierto});

  final Duration espera;
  final ResultadoLlave resultado;

  /// Cuántas veces se pidió la llave (para las pruebas).
  int intentos = 0;

  @override
  Future<ResultadoLlave> abrir(String motivo) async {
    intentos++;
    await Future<void>.delayed(espera);
    return resultado;
  }
}

/// Pone la llave al alcance de las pantallas: `context.llave`.
class LlaveScope extends InheritedWidget {
  const LlaveScope({super.key, required this.llave, required super.child});

  final LlaveCelular llave;

  @override
  bool updateShouldNotify(LlaveScope oldWidget) => llave != oldWidget.llave;
}

extension LlaveContexto on BuildContext {
  LlaveCelular get llave {
    final scope = getInheritedWidgetOfExactType<LlaveScope>();
    assert(scope != null, 'Falta LlaveScope arriba en el árbol de widgets.');
    return scope!.llave;
  }
}
