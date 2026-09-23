import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/formato.dart';
import '../archivos/almacen_archivos.dart';
import '../datos_ejemplo.dart';
import '../db/base_datos.dart';
import '../models/documento.dart';
import '../models/perfil.dart';
import 'cajon_repositorio.dart';

/// Repositorio sobre la base SQLite (Drift). Es el que usa la app en el celular.
class DriftCajonRepositorio implements CajonRepositorio {
  DriftCajonRepositorio(this.db, {AlmacenArchivos? archivos}) : archivos = archivos ?? ArchivosEnMemoria();

  final BaseDatos db;

  /// Dónde se guardan las fotos de los documentos (cifradas en el celular).
  final AlmacenArchivos archivos;

  static const _claveNombre = 'nombre';
  static const _claveLlave = 'llave_activada';

  // ── Ajustes ────────────────────────────────────────────────────────────

  Selectable<String?> _ajuste(String clave) =>
      (db.select(db.ajustes)..where((a) => a.clave.equals(clave))).map((a) => a.valor);

  Future<void> _guardarAjuste(String clave, String valor) =>
      db.into(db.ajustes).insertOnConflictUpdate(AjustesCompanion.insert(clave: clave, valor: valor));

  @override
  Stream<String> vigilarNombre() => _ajuste(_claveNombre).watchSingleOrNull().map((v) => v ?? '');

  @override
  Future<String> leerNombre() async => await _ajuste(_claveNombre).getSingleOrNull() ?? '';

  @override
  Future<void> guardarNombre(String nombre) => db.transaction(() async {
    final limpio = nombre.trim();
    await _guardarAjuste(_claveNombre, limpio);
    // La inicial del perfil propio sale del nombre.
    await (db.update(db.perfiles)..where((p) => p.id.equals(Perfil.idPropio))).write(
      PerfilesCompanion(inicial: Value(DatosEjemplo.inicialDe(limpio))),
    );
  });

  @override
  Future<bool> llaveActivada() async => await _ajuste(_claveLlave).getSingleOrNull() == 'si';

  @override
  Future<void> activarLlave() => _guardarAjuste(_claveLlave, 'si');

  // ── Perfiles ───────────────────────────────────────────────────────────

  @override
  Stream<List<Perfil>> vigilarPerfiles() {
    return db
        .customSelect(
          'SELECT p.*, (SELECT COUNT(*) FROM documentos d WHERE d.perfil_id = p.id) AS total '
          'FROM perfiles p ORDER BY p.es_propio DESC, p.creado_en, p.rowid',
          readsFrom: {db.perfiles, db.documentos},
        )
        .watch()
        .map((filas) => [for (final f in filas) _aPerfil(db.perfiles.map(f.data), f.read<int>('total'))]);
  }

  @override
  Future<Perfil> crearPerfil({required String nombre, required TipoPerfil tipo, required Color color}) async {
    final limpio = nombre.trim();
    final perfil = Perfil(
      id: 'perfil-${DateTime.now().microsecondsSinceEpoch}',
      nombre: limpio,
      inicial: DatosEjemplo.inicialDe(limpio),
      color: color,
      tipo: tipo,
    );
    await db
        .into(db.perfiles)
        .insert(
          PerfilesCompanion.insert(
            id: perfil.id,
            nombre: perfil.nombre,
            inicial: perfil.inicial,
            color: color.toARGB32(),
            tipo: tipo,
          ),
        );
    return perfil;
  }

  // ── Documentos ─────────────────────────────────────────────────────────

  /// Convierte lo que escribe el usuario en una consulta FTS5 segura:
  /// cada palabra como prefijo ("licen*"). [cualquiera] une con OR.
  static String? _consultaFts(String texto, {bool cualquiera = false}) {
    final palabras = Formato.normalizar(texto).split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty);
    if (palabras.isEmpty) return null;
    return palabras.map((p) => '"$p"*').join(cualquiera ? ' OR ' : ' ');
  }

  @override
  Stream<List<Documento>> vigilarDocumentos(String perfilId, {String busqueda = ''}) {
    final consulta = _consultaFts(busqueda);
    if (consulta == null) {
      final q = db.select(db.documentos)
        ..where((d) => d.perfilId.equals(perfilId))
        ..orderBy([(d) => OrderingTerm.desc(d.guardadoEn)]);
      return q.watch().map((filas) => filas.map(_aDocumento).toList());
    }
    return db
        .customSelect(
          'SELECT d.* FROM documentos d JOIN documentos_fts f ON f.doc_id = d.id '
          'WHERE documentos_fts MATCH ? AND d.perfil_id = ? ORDER BY f.rank',
          variables: [Variable.withString(consulta), Variable.withString(perfilId)],
          readsFrom: {db.documentos},
        )
        .watch()
        .map((filas) => [for (final f in filas) _aDocumento(db.documentos.map(f.data))]);
  }

  @override
  Stream<List<Documento>> vigilarTodos() {
    final q = db.select(db.documentos)..orderBy([(d) => OrderingTerm.desc(d.guardadoEn)]);
    return q.watch().map((filas) => filas.map(_aDocumento).toList());
  }

  @override
  Stream<Documento?> vigilarDocumento(String id) => (db.select(
    db.documentos,
  )..where((d) => d.id.equals(id))).watchSingleOrNull().map((f) => f == null ? null : _aDocumento(f));

  @override
  Future<List<Documento>> buscar(String texto) async {
    final consulta = _consultaFts(texto, cualquiera: true);
    if (consulta == null) return const [];
    final filas = await db
        .customSelect(
          'SELECT d.* FROM documentos d JOIN documentos_fts f ON f.doc_id = d.id '
          'WHERE documentos_fts MATCH ? ORDER BY f.rank',
          variables: [Variable.withString(consulta)],
          readsFrom: {db.documentos},
        )
        .get();
    return [for (final f in filas) _aDocumento(db.documentos.map(f.data))];
  }

  @override
  Future<String> guardarDocumento(NuevoDocumento n, {List<Uint8List> paginas = const []}) async {
    final id = 'doc-${DateTime.now().microsecondsSinceEpoch}';
    // Primero las fotos (cifradas); si la base falla después, se borran.
    final archivo = paginas.isEmpty ? null : await archivos.guardarPaginas(paginas);
    try {
      await db
          .into(db.documentos)
          .insert(
            DocumentosCompanion.insert(
              id: id,
              perfilId: n.perfilId,
              nombre: n.nombre.trim(),
              categoria: n.categoria,
              paginas: Value(archivo?.paginas ?? n.paginas),
              tamanoBytes: Value(archivo?.bytes ?? n.tamanoBytes),
              guardadoEn: DateTime.now(),
              venceEn: Value(n.venceEn),
              archivo: Value(archivo?.ruta ?? n.archivo),
              textoExtraido: Value(n.textoExtraido),
            ),
          );
    } catch (_) {
      if (archivo != null) await archivos.borrar(archivo.ruta);
      rethrow;
    }
    return id;
  }

  @override
  Future<List<Uint8List>> leerPaginas(Documento documento) async =>
      documento.archivo == null ? const [] : archivos.leerPaginas(documento.archivo!);

  @override
  Future<void> renombrarDocumento(String id, String nombre) => (db.update(
    db.documentos,
  )..where((d) => d.id.equals(id))).write(DocumentosCompanion(nombre: Value(nombre.trim())));

  @override
  Future<void> eliminarDocumento(String id) async {
    final fila = await (db.select(db.documentos)..where((d) => d.id.equals(id))).getSingleOrNull();
    await (db.delete(db.documentos)..where((d) => d.id.equals(id))).go();
    // Al borrar el documento también se borran sus fotos cifradas.
    if (fila?.archivo != null) await archivos.borrar(fila!.archivo!);
  }

  // ── Sugerencias ────────────────────────────────────────────────────────

  @override
  Stream<Set<String>> vigilarSugerenciasDescartadas() =>
      db.select(db.sugerenciasDescartadas).watch().map((filas) => {for (final f in filas) f.clave});

  @override
  Future<void> descartarSugerencia(String clave) => db
      .into(db.sugerenciasDescartadas)
      .insert(SugerenciasDescartadasCompanion.insert(clave: clave), mode: InsertMode.insertOrIgnore);

  // ── Desarrollo ─────────────────────────────────────────────────────────

  @override
  Future<void> restablecerEjemplo() async {
    await db.restablecer(ejemplo: true);
    await archivos.borrarTodo();
  }

  @override
  Future<void> cerrar() => db.close();

  // ── Conversión de filas a modelos ──────────────────────────────────────

  static Perfil _aPerfil(PerfilFila f, int total) => Perfil(
    id: f.id,
    nombre: f.nombre,
    inicial: f.inicial,
    color: Color(f.color),
    tipo: f.tipo,
    esPropio: f.esPropio,
    documentos: total,
  );

  static Documento _aDocumento(DocumentoFila f) => Documento(
    id: f.id,
    perfilId: f.perfilId,
    nombre: f.nombre,
    categoria: f.categoria,
    guardadoEn: f.guardadoEn,
    paginas: f.paginas,
    tamanoBytes: f.tamanoBytes,
    venceEn: f.venceEn,
    archivo: f.archivo,
    textoExtraido: f.textoExtraido,
  );
}
