import 'dart:typed_data';
import 'dart:ui';

import '../models/contenido_cajon.dart';
import '../models/documento.dart';
import '../models/perfil.dart';

/// Todo lo que las pantallas pueden pedir o guardar. Es la única puerta a los
/// datos: hoy la implementan [DriftCajonRepositorio] (SQLite cifrado, en el
/// celular) y [MemoriaCajonRepositorio] (vista previa web y pruebas).
///
/// Los métodos `vigilar…` devuelven un `Stream` que emite de nuevo cada vez
/// que los datos cambian: si guardas un documento, "Mi cajón" se actualiza solo.
abstract interface class CajonRepositorio {
  // ── Ajustes ────────────────────────────────────────────────────────────

  /// Nombre o apodo del usuario ('' si todavía no lo ha escrito).
  Stream<String> vigilarNombre();
  Future<String> leerNombre();
  Future<void> guardarNombre(String nombre);

  /// `true` después de activar la llave en la bienvenida.
  Future<bool> llaveActivada();
  Future<void> activarLlave();

  // ── Perfiles ───────────────────────────────────────────────────────────

  /// Perfiles en orden (el propio primero), con su cantidad de documentos.
  Stream<List<Perfil>> vigilarPerfiles();
  Future<Perfil> crearPerfil({required String nombre, required TipoPerfil tipo, required Color color});

  // ── Documentos ─────────────────────────────────────────────────────────

  /// Documentos de un perfil, del más reciente al más antiguo. Con [busqueda]
  /// filtra por nombre, carpeta o texto leído del documento (sin tildes).
  Stream<List<Documento>> vigilarDocumentos(String perfilId, {String busqueda = ''});

  /// Documentos de todos los perfiles (para Avisos y la IA).
  Stream<List<Documento>> vigilarTodos();

  /// Un documento; emite `null` si se elimina.
  Stream<Documento?> vigilarDocumento(String id);

  /// Busca en todos los perfiles; los más relevantes primero.
  Future<List<Documento>> buscar(String texto);

  /// Guarda el documento. Si llegan [paginas] (fotos JPEG de la cámara o la
  /// galería) o un [pdf] subido, se guardan cifrados y el documento queda
  /// enlazado a ellos.
  Future<String> guardarDocumento(NuevoDocumento nuevo, {List<Uint8List> paginas = const [], Uint8List? pdf});

  /// Las fotos de las páginas, ya descifradas (vacío si no tiene archivo o
  /// si es un PDF subido).
  Future<List<Uint8List>> leerPaginas(Documento documento);

  /// El PDF subido, ya descifrado (`null` si el documento son fotos).
  Future<Uint8List?> leerPdf(Documento documento);

  /// Cambia los datos del documento [id] por los de [datos] (nombre, perfil,
  /// carpeta y vencimiento). Si llegan [paginas] o un [pdf], reemplazan a los
  /// archivos que tenía: primero se guardan los nuevos y después se borran
  /// los viejos, y el documento cuenta como guardado hoy.
  Future<void> actualizarDocumento(
    String id,
    NuevoDocumento datos, {
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
  });

  Future<void> renombrarDocumento(String id, String nombre);
  Future<void> eliminarDocumento(String id);

  // ── Sugerencias de la IA ───────────────────────────────────────────────

  /// Claves de las sugerencias que el usuario ya descartó.
  Stream<Set<String>> vigilarSugerenciasDescartadas();
  Future<void> descartarSugerencia(String clave);

  // ── Copia de seguridad ─────────────────────────────────────────────────

  /// Lo que va en la copia de seguridad. Los archivos no: se leen aparte,
  /// uno por uno, con [leerPaginas] y [leerPdf].
  Future<ContenidoCajon> leerContenido();

  /// Cambia todo el cajón por el de una copia. [archivosDe] trae los
  /// archivos de cada documento que los tenga (`archivo != null`).
  ///
  /// Todo o nada: si algo falla a mitad, el cajón queda como estaba. No toca
  /// la llave del cajón ni los ajustes de la copia.
  Future<void> restaurar(
    ContenidoCajon contenido, {
    required Future<ArchivosDocumento> Function(Documento documento) archivosDe,
  });

  /// Ajustes sueltos, como los de la copia de seguridad. `null` = no está.
  Future<String?> leerAjuste(String clave);

  /// Con [valor] `null`, se borra.
  Future<void> guardarAjuste(String clave, String? valor);

  // ── Desarrollo ─────────────────────────────────────────────────────────

  /// Borra todo y carga los datos de ejemplo (solo para desarrollo).
  Future<void> restablecerEjemplo();

  Future<void> cerrar();
}
