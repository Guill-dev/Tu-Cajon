import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../archivos/archivos_cifrados.dart';
import '../repositorio/cajon_repositorio.dart';
import '../repositorio/drift_repositorio.dart';
import 'base_cifrada.dart';

/// Abre la base de datos cifrada del celular.
///
/// - El archivo vive en la carpeta privada de la app (no la ve el usuario ni
///   otras apps): `tu_cajon.sqlite`.
/// - Está cifrado con SQLite3MultipleCiphers (`hooks` en `pubspec.yaml`).
/// - La clave es aleatoria, se crea la primera vez y se guarda en el
///   almacén seguro del sistema (Keychain en iPhone, Keystore en Android).
///   Nunca se escribe en el código ni sale del celular.
Future<CajonRepositorio> abrirRepositorio() async {
  final carpeta = await getApplicationSupportDirectory();
  final archivo = File(p.join(carpeta.path, 'tu_cajon.sqlite'));
  final clave = await _Claves.obtener(_Claves.baseDatos);

  // Las fotos de los documentos usan otra clave (AES-256-GCM; el paquete
  // cryptography_flutter lo acelera con el cifrado nativo del sistema).
  final archivos = ArchivosCifrados(
    carpetaBase: carpeta,
    clave: base64Url.decode(base64Url.normalize(await _Claves.obtener(_Claves.archivos))),
  );

  // En desarrollo, una base nueva arranca con los datos de ejemplo.
  final db = abrirBaseCifrada(archivo, clave, cargarEjemplo: kDebugMode);
  // Se abre ya (no en la primera consulta) para que un problema salga aquí,
  // al arrancar, y no a mitad de una pantalla.
  await db.customSelect('SELECT 1').get();
  return DriftCajonRepositorio(db, archivos: archivos);
}

abstract final class _Claves {
  static const baseDatos = 'tu_cajon.clave_bd';
  static const archivos = 'tu_cajon.clave_archivos';
  static const _almacen = FlutterSecureStorage();

  /// Lee la clave [nombre] del almacén seguro; si no existe, la crea.
  static Future<String> obtener(String nombre) async {
    final existente = await _almacen.read(key: nombre);
    if (existente != null) return existente;
    // 32 bytes aleatorios en base64url: solo letras, números, "-" y "_",
    // así que no rompen la instrucción PRAGMA.
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final nueva = base64UrlEncode(bytes).replaceAll('=', '');
    await _almacen.write(key: nombre, value: nueva);
    return nueva;
  }
}
