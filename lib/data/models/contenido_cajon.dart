import 'dart:typed_data';

import 'documento.dart';
import 'perfil.dart';

/// Todo lo que hay en el cajón, menos los archivos: lo que va en la copia de
/// seguridad y lo que vuelve al recuperarla.
class ContenidoCajon {
  const ContenidoCajon({
    required this.nombre,
    required this.perfiles,
    required this.documentos,
    this.descartadas = const {},
  });

  /// El nombre o apodo del dueño.
  final String nombre;

  /// En su orden (el propio primero).
  final List<Perfil> perfiles;
  final List<Documento> documentos;

  /// Sugerencias que ya se descartaron, para que no vuelvan a salir.
  final Set<String> descartadas;
}

/// Los archivos de un documento: sus fotos, o el PDF que se subió.
typedef ArchivosDocumento = ({List<Uint8List> paginas, Uint8List? pdf});
