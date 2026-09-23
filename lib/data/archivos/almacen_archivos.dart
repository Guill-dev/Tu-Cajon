import 'dart:typed_data';

/// Resultado de guardar las páginas de un documento.
class ArchivoGuardado {
  const ArchivoGuardado({required this.ruta, required this.bytes, required this.paginas});

  /// Carpeta relativa donde quedaron las páginas (va en `documentos.archivo`).
  final String ruta;

  /// Tamaño total de las imágenes (sin cifrar).
  final int bytes;
  final int paginas;
}

/// Dónde viven las fotos de los documentos. En el celular: cifradas en la
/// carpeta privada de la app ([ArchivosCifrados]); en web y pruebas: en memoria.
abstract interface class AlmacenArchivos {
  Future<ArchivoGuardado> guardarPaginas(List<Uint8List> paginas);
  Future<List<Uint8List>> leerPaginas(String ruta);
  Future<void> borrar(String ruta);
  Future<void> borrarTodo();
}

/// Versión en memoria (vista web y pruebas).
class ArchivosEnMemoria implements AlmacenArchivos {
  final _datos = <String, List<Uint8List>>{};
  var _siguiente = 0;

  @override
  Future<ArchivoGuardado> guardarPaginas(List<Uint8List> paginas) async {
    final ruta = 'memoria/${_siguiente++}';
    _datos[ruta] = List.of(paginas);
    return ArchivoGuardado(
      ruta: ruta,
      bytes: paginas.fold(0, (s, p) => s + p.length),
      paginas: paginas.length,
    );
  }

  @override
  Future<List<Uint8List>> leerPaginas(String ruta) async => _datos[ruta] ?? const [];

  @override
  Future<void> borrar(String ruta) async => _datos.remove(ruta);

  @override
  Future<void> borrarTodo() async => _datos.clear();
}
