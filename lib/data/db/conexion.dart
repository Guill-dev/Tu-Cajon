/// Abre el repositorio correcto según la plataforma:
/// - Celular / escritorio: SQLite cifrado (`conexion_nativa.dart`).
/// - Web (vista previa): datos de ejemplo en memoria (`conexion_web.dart`).
library;

export 'conexion_nativa.dart' if (dart.library.js_interop) 'conexion_web.dart';
