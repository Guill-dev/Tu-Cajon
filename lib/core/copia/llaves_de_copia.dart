import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde se guarda la llave de la copia de seguridad (32 bytes al azar).
///
/// - En este celular, en el almacén seguro del sistema, para seguir haciendo
///   copias.
/// - En "Block Store" de Google, protegida con el bloqueo de pantalla del
///   celular (PIN, patrón o contraseña), cifrada de extremo a extremo: ni
///   Google puede leerla. Cuando alguien estrena celular y restaura su cuenta
///   de Google con el PIN del anterior, la llave llega sola y la copia se
///   abre sin contraseñas.
abstract interface class LlavesDeCopia {
  factory LlavesDeCopia.paraEstaPlataforma() => LlavesDelSistema();

  /// `true` si la llave viaja protegida con el bloqueo de pantalla (Android 9
  /// o más nuevo, con PIN, patrón o contraseña). Si no, solo queda en este
  /// celular y para otro hace falta el código de emergencia.
  Future<bool> protegidaConBloqueo();

  Future<void> guardar(Uint8List llave);

  /// La llave de este celular o, si no hay, la que llegó de otro celular.
  Future<Uint8List?> leer();

  Future<void> borrar();
}

/// La de verdad: almacén seguro + Block Store (canal `tu_cajon/copia`,
/// ver `CopiaDeSeguridad.kt`). Fuera de Android, solo el almacén seguro.
class LlavesDelSistema implements LlavesDeCopia {
  static const _canal = MethodChannel('tu_cajon/copia');
  static const _almacen = FlutterSecureStorage();
  static const _clave = 'tu_cajon.clave_copia';

  static bool get _hayBlockStore => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> protegidaConBloqueo() async {
    if (!_hayBlockStore) return false;
    try {
      return await _canal.invokeMethod<bool>('llaveProtegida') ?? false;
    } on PlatformException catch (e) {
      debugPrint('No se pudo revisar Block Store: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> guardar(Uint8List llave) async {
    await _almacen.write(key: _clave, value: base64Encode(llave));
    if (!_hayBlockStore) return;
    try {
      await _canal.invokeMethod<bool>('guardarLlave', {'llave': llave});
    } on PlatformException catch (e) {
      // Queda en este celular; para otro, servirá el código de emergencia.
      debugPrint('No se pudo guardar la llave en Block Store: $e');
    } on MissingPluginException {
      // Pruebas: no hay Block Store.
    }
  }

  @override
  Future<Uint8List?> leer() async {
    final local = await _almacen.read(key: _clave);
    if (local != null) return base64Decode(local);
    if (!_hayBlockStore) return null;
    try {
      return await _canal.invokeMethod<Uint8List>('leerLlave');
    } on PlatformException catch (e) {
      debugPrint('No se pudo leer la llave de Block Store: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> borrar() async {
    await _almacen.delete(key: _clave);
    if (!_hayBlockStore) return;
    try {
      await _canal.invokeMethod<void>('borrarLlave');
    } on PlatformException catch (e) {
      debugPrint('No se pudo borrar la llave de Block Store: $e');
    } on MissingPluginException {
      // Pruebas.
    }
  }
}

/// Para pruebas y la vista web: todo en memoria.
class LlavesSimuladas implements LlavesDeCopia {
  LlavesSimuladas({this.protegida = true, this.deOtroCelular});

  /// Si el "celular" tiene bloqueo de pantalla.
  bool protegida;

  /// La llave que "llegó" con Block Store al estrenar celular.
  Uint8List? deOtroCelular;

  /// La guardada en este celular.
  Uint8List? local;

  @override
  Future<bool> protegidaConBloqueo() async => protegida;

  @override
  Future<void> guardar(Uint8List llave) async => local = llave;

  @override
  Future<Uint8List?> leer() async => local ?? deOtroCelular;

  @override
  Future<void> borrar() async => local = null;
}
