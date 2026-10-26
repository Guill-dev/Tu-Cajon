import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import '../../data/copia/nube.dart';

/// El ID del cliente "web" del proyecto de Google Cloud de Tu Cajón. Google
/// lo pide para iniciar sesión en Android. No es secreto: identifica a la
/// app. Vacío mientras no esté configurado (la copia se prueba en el celular).
const clienteWebDeGoogle = '375957651818-aqci5bne40nsomau636ctkvv5jk37alu.apps.googleusercontent.com';

/// La cuenta de Google de la persona, para la copia en Google Drive.
///
/// Solo pide un permiso: `drive.appdata`, una carpeta oculta de la app en
/// su Drive. Con él, la app no puede ver ningún otro archivo de la persona.
abstract interface class CuentaGoogle {
  /// Abre el selector de cuentas y pide el permiso. Devuelve el correo o
  /// lanza [ConexionCancelada].
  Future<String> conectar();

  /// Un permiso de acceso vigente (sin mostrar nada). Con [renovar], uno
  /// nuevo (el anterior venció). Lanza [PermisoPerdido] si hay que conectar
  /// la cuenta otra vez.
  Future<String> token({bool renovar = false});

  /// Quita el permiso. La copia se queda en el Drive.
  Future<void> desconectar();

  /// El correo de la cuenta que ya había dado permiso (si el celular tiene
  /// varias cuentas, a cuál pedírselo).
  void recordar(String? correo);
}

/// La de verdad, con el inicio de sesión de Google del celular.
class CuentaGoogleDelSistema implements CuentaGoogle {
  CuentaGoogleDelSistema({required this.clienteWeb});

  final String clienteWeb;

  static const alcances = ['https://www.googleapis.com/auth/drive.appdata'];

  Future<void>? _iniciada;
  GoogleSignInAccount? _cuenta;
  String? _correo;
  String? _token;

  @override
  void recordar(String? correo) => _correo = correo;

  // Google pide iniciarlo una sola vez por cada vez que se abre la app.
  Future<void> _iniciar() => _iniciada ??= GoogleSignIn.instance.initialize(serverClientId: clienteWeb);

  @override
  Future<String> conectar() async {
    await _iniciar();
    try {
      final cuenta = await GoogleSignIn.instance.authenticate(scopeHint: alcances);
      final permiso = await cuenta.authorizationClient.authorizeScopes(alcances);
      _cuenta = cuenta;
      _correo = cuenta.email;
      _token = permiso.accessToken;
      return cuenta.email;
    } on GoogleSignInException catch (e) {
      throw _comoProblema(e);
    }
  }

  @override
  Future<String> token({bool renovar = false}) async {
    if (!renovar && _token != null) return _token!;
    await _iniciar();
    try {
      final vencido = _token;
      if (vencido != null) {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: vencido);
      }
      _token = null;
      // Sin mostrar nada (también con la app cerrada, a la hora de la copia):
      // el permiso que ya había dado esa cuenta.
      final permiso = await GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes(
        ClientAuthorizationTokensForScopesParameters(
          request: AuthorizationRequestDetails(
            scopes: alcances,
            userId: null,
            email: _cuenta?.email ?? _correo,
            promptIfUnauthorized: false,
          ),
        ),
      );
      if (permiso == null) throw const PermisoPerdido();
      return _token = permiso.accessToken;
    } on GoogleSignInException catch (e) {
      throw _comoProblema(e);
    }
  }

  @override
  Future<void> desconectar() async {
    await _iniciar();
    _cuenta = null;
    _correo = null;
    _token = null;
    try {
      await GoogleSignIn.instance.disconnect();
    } on GoogleSignInException catch (e) {
      // Si ya no estaba conectada, no pasa nada.
      debugPrint('Google al desconectar: ${e.code}');
    }
  }

  static ProblemaNube _comoProblema(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return const ConexionCancelada();
      case GoogleSignInExceptionCode.interrupted:
        return const SinConexion();
      default:
        // Casi siempre es la configuración del proyecto de Google (huella SHA-1,
        // nombre del paquete o el cliente web).
        debugPrint('Google no pudo conectar: ${e.code} ${e.description}');
        return const FalloDeLaNube();
    }
  }
}
