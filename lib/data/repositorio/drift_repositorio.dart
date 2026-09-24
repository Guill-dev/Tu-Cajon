import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/formato.dart';
import '../archivos/almacen_archivos.dart';
import '../datos_ejemplo.dart';
import '../db/base_datos.dart';
import '../models/contenido_cajon.dart';
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

  Selectable<Perfil> _perfilesEnOrden() => db
      .customSelect(
        'SELECT p.*, (SELECT COUNT(*) FROM documentos d WHERE d.perfil_id = p.id) AS total '
        'FROM perfiles p ORDER BY p.es_propio DESC, p.creado_en, p.rowid',
        readsFrom: {db.perfiles, db.documentos},
      )
      .map((f) => _aPerfil(db.perfiles.map(f.data), f.read<int>('total')));

  @override
  Stream<List<Perfil>> vigilarPerfiles() => _perfilesEnOrden().watch();

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
  Future<String> guardarDocumento(
    NuevoDocumento n, {
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
  }) async {
    final id = 'doc-${DateTime.now().microsecondsSinceEpoch}';
    // Primero el archivo (cifrado); si la base falla después, se borra.
    final archivo = pdf != null
        ? await archivos.guardarPdf(pdf, paginas: n.paginas)
        : paginas.isEmpty
        ? null
        : await archivos.guardarPaginas(paginas);
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
  Future<Uint8List?> leerPdf(Documento documento) async =>
      documento.archivo == null ? null : archivos.leerPdf(documento.archivo!);

  @override
  Future<void> actualizarDocumento(
    String id,
    NuevoDocumento n, {
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
  }) async {
    final anterior = await (db.select(db.documentos)..where((d) => d.id.equals(id))).getSingleOrNull();
    if (anterior == null) throw StateError('No existe el documento $id');
    // Primero los archivos nuevos (cifrados); si la base falla, se borran y
    // el documento queda como estaba.
    final archivo = pdf != null
        ? await archivos.guardarPdf(pdf, paginas: n.paginas)
        : paginas.isEmpty
        ? null
        : await archivos.guardarPaginas(paginas);
    try {
      await (db.update(db.documentos)..where((d) => d.id.equals(id))).write(
        DocumentosCompanion(
          perfilId: Value(n.perfilId),
          nombre: Value(n.nombre.trim()),
          categoria: Value(n.categoria),
          venceEn: Value(n.venceEn),
          // Con archivos nuevos: sus datos, y cuenta como guardado hoy.
          paginas: archivo == null ? const Value.absent() : Value(archivo.paginas),
          tamanoBytes: archivo == null ? const Value.absent() : Value(archivo.bytes),
          archivo: archivo == null ? const Value.absent() : Value(archivo.ruta),
          guardadoEn: archivo == null ? const Value.absent() : Value(DateTime.now()),
          textoExtraido: archivo == null ? const Value.absent() : const Value(''),
        ),
      );
    } catch (_) {
      if (archivo != null) await archivos.borrar(archivo.ruta);
      rethrow;
    }
    // Ya quedaron los nuevos: se borran las páginas de antes.
    if (archivo != null && anterior.archivo != null) await archivos.borrar(anterior.archivo!);
  }

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

  // ── Copia de seguridad ─────────────────────────────────────────────────

  @override
  Future<ContenidoCajon> leerContenido() async {
    final documentos = await (db.select(
      db.documentos,
    )..orderBy([(d) => OrderingTerm.asc(d.guardadoEn)])).get();
    final descartadas = await db.select(db.sugerenciasDescartadas).get();
    return ContenidoCajon(
      nombre: await leerNombre(),
      perfiles: await _perfilesEnOrden().get(),
      documentos: documentos.map(_aDocumento).toList(),
      descartadas: {for (final f in descartadas) f.clave},
    );
  }

  @override
  Future<void> restaurar(
    ContenidoCajon c, {
    required Future<ArchivosDocumento> Function(Documento documento) archivosDe,
  }) async {
    final antes = await db.select(db.documentos).map((f) => f.archivo).get();
    // 1. Los archivos de la copia, cifrados como todos los demás.
    final nuevos = <String, ArchivoGuardado>{};
    try {
      for (final d in c.documentos) {
        if (d.archivo == null) continue;
        final a = await archivosDe(d);
        final guardado = a.pdf != null
            ? await archivos.guardarPdf(a.pdf!, paginas: d.paginas)
            : a.paginas.isEmpty
            ? null
            : await archivos.guardarPaginas(a.paginas);
        if (guardado != null) nuevos[d.id] = guardado;
      }
      // 2. La base cambia en una sola transacción: todo o nada.
      await db.transaction(() async {
        await db.delete(db.documentos).go();
        await db.delete(db.perfiles).go();
        await db.delete(db.sugerenciasDescartadas).go();
        for (final p in c.perfiles) {
          await db
              .into(db.perfiles)
              .insert(
                PerfilesCompanion.insert(
                  id: p.id,
                  nombre: p.nombre,
                  inicial: p.inicial,
                  color: p.color.toARGB32(),
                  tipo: p.tipo,
                  esPropio: Value(p.esPropio),
                ),
              );
        }
        for (final d in c.documentos) {
          await db
              .into(db.documentos)
              .insert(
                DocumentosCompanion.insert(
                  id: d.id,
                  perfilId: d.perfilId,
                  nombre: d.nombre,
                  categoria: d.categoria,
                  paginas: Value(d.paginas),
                  tamanoBytes: Value(d.tamanoBytes),
                  guardadoEn: d.guardadoEn,
                  venceEn: Value(d.venceEn),
                  archivo: Value(nuevos[d.id]?.ruta),
                  textoExtraido: Value(d.textoExtraido),
                ),
              );
        }
        for (final clave in c.descartadas) {
          await db
              .into(db.sugerenciasDescartadas)
              .insert(SugerenciasDescartadasCompanion.insert(clave: clave));
        }
        await _guardarAjuste(_claveNombre, c.nombre);
      });
    } catch (_) {
      for (final a in nuevos.values) {
        await archivos.borrar(a.ruta);
      }
      rethrow;
    }
    // 3. Los archivos de antes ya no se usan.
    for (final ruta in antes.nonNulls) {
      await archivos.borrar(ruta);
    }
  }

  @override
  Future<String?> leerAjuste(String clave) => _ajuste(clave).getSingleOrNull();

  @override
  Future<void> guardarAjuste(String clave, String? valor) async {
    if (valor != null) return _guardarAjuste(clave, valor);
    await (db.delete(db.ajustes)..where((a) => a.clave.equals(clave))).go();
  }

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
