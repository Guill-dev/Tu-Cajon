import 'package:drift/drift.dart';

import '../models/categoria.dart';
import '../models/perfil.dart';

/// Tablas de la base de datos local. Drift genera a partir de aquí las
/// clases de filas (`PerfilFila`, `DocumentoFila`…) en `base_datos.g.dart`.
///
/// Si cambias una tabla: sube `schemaVersion` en `base_datos.dart`, agrega
/// el paso en `onUpgrade` y vuelve a generar con
/// `dart run build_runner build`.

@DataClassName('PerfilFila')
class Perfiles extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get inicial => text()();

  /// Color en formato ARGB (0xFF5160EC).
  IntColumn get color => integer()();
  TextColumn get tipo => textEnum<TipoPerfil>()();
  BoolColumn get esPropio => boolean().withDefault(const Constant(false))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DocumentoFila')
class Documentos extends Table {
  TextColumn get id => text()();

  /// Si se borra el perfil, se borran sus documentos.
  TextColumn get perfilId => text().references(Perfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get nombre => text()();
  TextColumn get categoria => textEnum<Categoria>()();
  IntColumn get paginas => integer().withDefault(const Constant(1))();
  IntColumn get tamanoBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get guardadoEn => dateTime()();
  DateTimeColumn get venceEn => dateTime().nullable()();

  /// Ruta relativa del archivo cifrado (null mientras la cámara es simulada).
  TextColumn get archivo => text().nullable()();

  /// Texto leído del documento; alimenta la búsqueda y "Pregúntale".
  TextColumn get textoExtraido => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pares clave → valor: nombre del usuario, si activó la llave, etc.
@DataClassName('AjusteFila')
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Sugerencias de la IA que el usuario descartó ("Ya lo hice", "Ahora no").
@DataClassName('SugerenciaDescartadaFila')
class SugerenciasDescartadas extends Table {
  TextColumn get clave => text()();
  DateTimeColumn get descartadaEn => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {clave};
}
