/// La nube de prueba, mientras la app no esté conectada con Google Drive:
/// - Celular: una carpeta dentro de la carpeta privada de la app
///   (`nube_de_prueba_io.dart`).
/// - Web (vista previa): en memoria (`nube_de_prueba_web.dart`).
library;

export 'nube_de_prueba_io.dart' if (dart.library.js_interop) 'nube_de_prueba_web.dart';
