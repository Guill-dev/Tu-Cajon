import 'dart:typed_data';
import 'dart:ui';

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

  /// Guarda el documento. Si llegan [paginas] (fotos JPEG de la cámara), se
  /// guardan cifradas y el documento queda enlazado a ellas.
  Future<String> guardarDocumento(NuevoDocumento nuevo, {List<Uint8List> paginas = const []});

  /// Las fotos de las páginas, ya descifradas (vacío si no tiene archivo).
  Future<List<Uint8List>> leerPaginas(Documento documento);

  Future<void> renombrarDocumento(String id, String nombre);
  Future<void> eliminarDocumento(String id);

  // ── Sugerencias de la IA ───────────────────────────────────────────────

  /// Claves de las sugerencias que el usuario ya descartó.
  Stream<Set<String>> vigilarSugerenciasDescartadas();
  Future<void> descartarSugerencia(String clave);

  // ── Desarrollo ─────────────────────────────────────────────────────────

  /// Borra todo y carga los datos de ejemplo (solo para desarrollo).
  Future<void> restablecerEjemplo();

  Future<void> cerrar();
}
