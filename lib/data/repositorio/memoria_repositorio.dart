import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import '../../core/formato.dart';
import '../archivos/almacen_archivos.dart';
import '../datos_ejemplo.dart';
import '../models/documento.dart';
import '../models/perfil.dart';
import 'cajon_repositorio.dart';

/// Repositorio en memoria (se pierde al cerrar). Lo usa la vista previa web,
/// donde no hay SQLite nativo, y sirve para pruebas rápidas de pantallas.
class MemoriaCajonRepositorio implements CajonRepositorio {
  MemoriaCajonRepositorio({bool ejemplo = true}) {
    _sembrar(ejemplo: ejemplo);
  }

  final _cambios = StreamController<void>.broadcast();
  final _archivos = ArchivosEnMemoria();
  String _nombre = '';
  bool _llave = false;
  final List<Perfil> _perfiles = [];
  final List<Documento> _documentos = [];
  final Set<String> _descartadas = {};

  void _sembrar({required bool ejemplo}) {
    _nombre = ejemplo ? DatosEjemplo.nombreUsuario : '';
    _llave = false;
    _perfiles
      ..clear()
      ..add(DatosEjemplo.perfilPropio(_nombre));
    _documentos.clear();
    _descartadas.clear();
    if (ejemplo) {
      _perfiles.add(DatosEjemplo.perfilMama);
      _documentos.addAll(DatosEjemplo.documentos(DateTime.now()));
    }
  }

  void _avisar() => _cambios.add(null);

  /// Emite el valor actual y lo vuelve a emitir con cada cambio.
  Stream<T> _vigilar<T>(T Function() leer) async* {
    yield leer();
    await for (final _ in _cambios.stream) {
      yield leer();
    }
  }

  List<Documento> _ordenados(Iterable<Documento> docs) =>
      docs.toList()..sort((a, b) => b.guardadoEn.compareTo(a.guardadoEn));

  bool _coincide(Documento d, List<String> palabras, {required bool todas}) {
    final texto = Formato.normalizar('${d.nombre} ${d.categoria.name} ${d.textoExtraido}');
    bool esta(String p) => RegExp('(^|[^a-z0-9])$p').hasMatch(texto);
    return todas ? palabras.every(esta) : palabras.any(esta);
  }

  static List<String> _palabras(String s) =>
      Formato.normalizar(s).split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();

  // ── Ajustes ────────────────────────────────────────────────────────────

  @override
  Stream<String> vigilarNombre() => _vigilar(() => _nombre);

  @override
  Future<String> leerNombre() async => _nombre;

  @override
  Future<void> guardarNombre(String nombre) async {
    _nombre = nombre.trim();
    final i = _perfiles.indexWhere((p) => p.esPropio);
    _perfiles[i] = DatosEjemplo.perfilPropio(_nombre);
    _avisar();
  }

  @override
  Future<bool> llaveActivada() async => _llave;

  @override
  Future<void> activarLlave() async => _llave = true;

  // ── Perfiles ───────────────────────────────────────────────────────────

  @override
  Stream<List<Perfil>> vigilarPerfiles() => _vigilar(
    () => [
      for (final p in _perfiles)
        Perfil(
          id: p.id,
          nombre: p.nombre,
          inicial: p.inicial,
          color: p.color,
          tipo: p.tipo,
          esPropio: p.esPropio,
          documentos: _documentos.where((d) => d.perfilId == p.id).length,
        ),
    ],
  );

  @override
  Future<Perfil> crearPerfil({required String nombre, required TipoPerfil tipo, required Color color}) async {
    final limpio = nombre.trim();
    final p = Perfil(
      id: 'perfil-${DateTime.now().microsecondsSinceEpoch}',
      nombre: limpio,
      inicial: DatosEjemplo.inicialDe(limpio),
      color: color,
      tipo: tipo,
    );
    _perfiles.add(p);
    _avisar();
    return p;
  }

  // ── Documentos ─────────────────────────────────────────────────────────

  @override
  Stream<List<Documento>> vigilarDocumentos(String perfilId, {String busqueda = ''}) {
    final palabras = _palabras(busqueda);
    return _vigilar(
      () => _ordenados(
        _documentos.where(
          (d) => d.perfilId == perfilId && (palabras.isEmpty || _coincide(d, palabras, todas: true)),
        ),
      ),
    );
  }

  @override
  Stream<List<Documento>> vigilarTodos() => _vigilar(() => _ordenados(_documentos));

  @override
  Stream<Documento?> vigilarDocumento(String id) =>
      _vigilar(() => _documentos.where((d) => d.id == id).firstOrNull);

  @override
  Future<List<Documento>> buscar(String texto) async {
    final palabras = _palabras(texto);
    if (palabras.isEmpty) return const [];
    return _documentos.where((d) => _coincide(d, palabras, todas: false)).toList();
  }

  @override
  Future<String> guardarDocumento(
    NuevoDocumento n, {
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
  }) async {
    final id = 'doc-${DateTime.now().microsecondsSinceEpoch}';
    final archivo = pdf != null
        ? await _archivos.guardarPdf(pdf, paginas: n.paginas)
        : paginas.isEmpty
        ? null
        : await _archivos.guardarPaginas(paginas);
    _documentos.add(
      Documento(
        id: id,
        perfilId: n.perfilId,
        nombre: n.nombre.trim(),
        categoria: n.categoria,
        guardadoEn: DateTime.now(),
        paginas: archivo?.paginas ?? n.paginas,
        tamanoBytes: archivo?.bytes ?? n.tamanoBytes,
        venceEn: n.venceEn,
        archivo: archivo?.ruta ?? n.archivo,
        textoExtraido: n.textoExtraido,
      ),
    );
    _avisar();
    return id;
  }

  @override
  Future<List<Uint8List>> leerPaginas(Documento documento) async =>
      documento.archivo == null ? const [] : _archivos.leerPaginas(documento.archivo!);

  @override
  Future<Uint8List?> leerPdf(Documento documento) async =>
      documento.archivo == null ? null : _archivos.leerPdf(documento.archivo!);

  @override
  Future<void> renombrarDocumento(String id, String nombre) async {
    final i = _documentos.indexWhere((d) => d.id == id);
    if (i < 0) return;
    _documentos[i] = _documentos[i].copyWith(nombre: nombre.trim());
    _avisar();
  }

  @override
  Future<void> eliminarDocumento(String id) async {
    final archivo = _documentos.where((d) => d.id == id).firstOrNull?.archivo;
    _documentos.removeWhere((d) => d.id == id);
    if (archivo != null) await _archivos.borrar(archivo);
    _avisar();
  }

  // ── Sugerencias ────────────────────────────────────────────────────────

  @override
  Stream<Set<String>> vigilarSugerenciasDescartadas() => _vigilar(() => {..._descartadas});

  @override
  Future<void> descartarSugerencia(String clave) async {
    _descartadas.add(clave);
    _avisar();
  }

  @override
  Future<void> restablecerEjemplo() async {
    _sembrar(ejemplo: true);
    _avisar();
  }

  @override
  Future<void> cerrar() => _cambios.close();
}
