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
///
/// Un documento es o una lista de fotos (escaneadas o de la galería) o un
/// PDF que se subió tal cual: cada uno en su propia carpeta.
abstract interface class AlmacenArchivos {
  Future<ArchivoGuardado> guardarPaginas(List<Uint8List> paginas);

  /// Guarda un PDF subido, sin tocarlo. [paginas]: cuántas tiene.
  Future<ArchivoGuardado> guardarPdf(Uint8List pdf, {required int paginas});

  /// Las fotos del documento (vacío si es un PDF subido).
  Future<List<Uint8List>> leerPaginas(String ruta);

  /// El PDF subido (`null` si el documento son fotos).
  Future<Uint8List?> leerPdf(String ruta);
  Future<void> borrar(String ruta);
  Future<void> borrarTodo();
}

/// Versión en memoria (vista web y pruebas).
class ArchivosEnMemoria implements AlmacenArchivos {
  final _datos = <String, List<Uint8List>>{};
  final _pdfs = <String, Uint8List>{};
  var _siguiente = 0;

  @override
  Future<ArchivoGuardado> guardarPdf(Uint8List pdf, {required int paginas}) async {
    final ruta = 'memoria/${_siguiente++}';
    _pdfs[ruta] = pdf;
    return ArchivoGuardado(ruta: ruta, bytes: pdf.length, paginas: paginas);
  }

  @override
  Future<Uint8List?> leerPdf(String ruta) async => _pdfs[ruta];

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
  Future<void> borrar(String ruta) async {
    _datos.remove(ruta);
    _pdfs.remove(ruta);
  }

  @override
  Future<void> borrarTodo() async {
    _datos.clear();
    _pdfs.clear();
  }
}
