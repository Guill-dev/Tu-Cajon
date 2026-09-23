import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'base_datos.dart';

/// Abre (o crea) la base de datos cifrada en [archivo] con [clave].
///
/// El orden importa: la clave va **antes de cualquier otra consulta**.
/// SQLite lee el archivo en cuanto prepara la primera instrucción; si el
/// archivo ya existe y todavía no tiene la clave, ve bytes cifrados y
/// responde "file is not a database". Por eso antes solo funcionaba la
/// primera vez (cuando el archivo aún no existía).
///
/// [clave] solo puede tener letras, números, "-" y "_" (base64url), para no
/// romper la instrucción `PRAGMA`.
BaseDatos abrirBaseCifrada(
  File archivo,
  String clave, {
  bool cargarEjemplo = false,
  bool enSegundoPlano = true,
}) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(clave)) {
    throw ArgumentError('La clave de la base de datos tiene caracteres no permitidos.');
  }
  final conexion = enSegundoPlano
      ? NativeDatabase.createInBackground(archivo, setup: _prepararCifrado(clave))
      : NativeDatabase(archivo, setup: _prepararCifrado(clave));
  return BaseDatos(conexion, cargarEjemplo: cargarEjemplo);
}

// Función de primer nivel (no un cierre sobre objetos grandes) para que se
// pueda enviar al isolate de fondo de Drift.
void Function(Database) _prepararCifrado(String clave) {
  return (Database raw) {
    // 1. La clave, lo primero de todo.
    raw.execute("PRAGMA key = '$clave'");
    // 2. Si por error se enlazara SQLite sin cifrado, esta función no existe
    //    y la app falla aquí en vez de guardar documentos en claro.
    raw.select('SELECT sqlite3mc_version()');
    // 3. Confirma que la clave abre el archivo (con otra clave, falla aquí).
    raw.select('SELECT count(*) FROM sqlite_master');
  };
}
