import 'package:drift/drift.dart';

import '../datos_ejemplo.dart';
import '../models/categoria.dart';
import '../models/perfil.dart';
import 'tablas.dart';

part 'base_datos.g.dart';

/// Base de datos SQLite del cajón (cifrada en el celular, ver `conexion_nativa.dart`).
@DriftDatabase(tables: [Perfiles, Documentos, Ajustes, SugerenciasDescartadas])
class BaseDatos extends _$BaseDatos {
  /// Con [cargarEjemplo] la base nueva se llena con Marta y Mamá.
  BaseDatos(super.e, {this.cargarEjemplo = false});

  final bool cargarEjemplo;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _crearIndiceBusqueda();
      await sembrar(ejemplo: cargarEjemplo);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Índice de búsqueda de texto completo (FTS5). `remove_diacritics` hace
  /// que "conduccion" encuentre "conducción". Los triggers lo mantienen al
  /// día con cada cambio en `documentos`.
  Future<void> _crearIndiceBusqueda() async {
    await customStatement('''
      CREATE VIRTUAL TABLE documentos_fts USING fts5(
        doc_id UNINDEXED, nombre, categoria, texto,
        tokenize = 'unicode61 remove_diacritics 2'
      )''');
    await customStatement('''
      CREATE TRIGGER documentos_fts_insertar AFTER INSERT ON documentos BEGIN
        INSERT INTO documentos_fts (doc_id, nombre, categoria, texto)
        VALUES (new.id, new.nombre, new.categoria, new.texto_extraido);
      END''');
    await customStatement('''
      CREATE TRIGGER documentos_fts_borrar AFTER DELETE ON documentos BEGIN
        DELETE FROM documentos_fts WHERE doc_id = old.id;
      END''');
    await customStatement('''
      CREATE TRIGGER documentos_fts_actualizar AFTER UPDATE ON documentos BEGIN
        DELETE FROM documentos_fts WHERE doc_id = old.id;
        INSERT INTO documentos_fts (doc_id, nombre, categoria, texto)
        VALUES (new.id, new.nombre, new.categoria, new.texto_extraido);
      END''');
  }

  /// Crea el perfil propio y, si [ejemplo], los datos de Marta y Mamá.
  Future<void> sembrar({required bool ejemplo}) async {
    final nombre = ejemplo ? DatosEjemplo.nombreUsuario : '';
    final propio = DatosEjemplo.perfilPropio(nombre);
    await batch((b) {
      b.insert(perfiles, _perfilACompanion(propio));
      if (!ejemplo) return;
      b.insert(ajustes, AjustesCompanion.insert(clave: 'nombre', valor: nombre));
      b.insert(perfiles, _perfilACompanion(DatosEjemplo.perfilMama));
      for (final d in DatosEjemplo.documentos(DateTime.now())) {
        b.insert(
          documentos,
          DocumentosCompanion.insert(
            id: d.id,
            perfilId: d.perfilId,
            nombre: d.nombre,
            categoria: d.categoria,
            paginas: Value(d.paginas),
            tamanoBytes: Value(d.tamanoBytes),
            guardadoEn: d.guardadoEn,
            venceEn: Value(d.venceEn),
            textoExtraido: Value(d.textoExtraido),
          ),
        );
      }
    });
  }

  /// Borra todo y vuelve a sembrar (solo desarrollo).
  Future<void> restablecer({required bool ejemplo}) => transaction(() async {
    await delete(documentos).go();
    await delete(sugerenciasDescartadas).go();
    await delete(ajustes).go();
    await delete(perfiles).go();
    await sembrar(ejemplo: ejemplo);
  });

  static PerfilesCompanion _perfilACompanion(Perfil p) => PerfilesCompanion.insert(
    id: p.id,
    nombre: p.nombre,
    inicial: p.inicial,
    color: p.color.toARGB32(),
    tipo: p.tipo,
    esPropio: Value(p.esPropio),
  );
}
