import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'almacen_archivos.dart';

/// Guarda cada página de un documento como un archivo cifrado con
/// AES-256-GCM dentro de la carpeta privada de la app:
///
/// ```
/// <soporte de la app>/documentos/<id>/pagina_1.bin
/// ```
///
/// Formato de cada archivo: `nonce (12 bytes) + texto cifrado + MAC (16 bytes)`.
/// GCM también verifica que nadie haya alterado el archivo.
class ArchivosCifrados implements AlmacenArchivos {
  ArchivosCifrados({required this.carpetaBase, required List<int> clave}) : _clave = SecretKey(clave);

  /// Carpeta privada donde van las subcarpetas de cada documento.
  final Directory carpetaBase;
  final SecretKey _clave;
  final _aes = AesGcm.with256bits();

  static const _raiz = 'documentos';

  String _nuevoId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Directory _carpeta(String ruta) {
    // La ruta sale de nuestra base de datos, pero igual se valida:
    // nada de rutas absolutas ni "..".
    final normal = p.normalize(ruta);
    if (p.isAbsolute(normal) || normal.startsWith('..') || !normal.startsWith(_raiz)) {
      throw ArgumentError.value(ruta, 'ruta', 'Ruta de archivo no válida');
    }
    return Directory(p.join(carpetaBase.path, normal));
  }

  @override
  Future<ArchivoGuardado> guardarPaginas(List<Uint8List> paginas) async {
    final ruta = p.join(_raiz, _nuevoId());
    final carpeta = _carpeta(ruta);
    await carpeta.create(recursive: true);
    try {
      var total = 0;
      for (var i = 0; i < paginas.length; i++) {
        final caja = await _aes.encrypt(paginas[i], secretKey: _clave);
        await File(p.join(carpeta.path, 'pagina_${i + 1}.bin'))
            .writeAsBytes(caja.concatenation(), flush: true);
        total += paginas[i].length;
      }
      return ArchivoGuardado(ruta: ruta, bytes: total, paginas: paginas.length);
    } catch (_) {
      // Si algo falla a mitad, no se dejan páginas sueltas.
      await carpeta.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<List<Uint8List>> leerPaginas(String ruta) async {
    final carpeta = _carpeta(ruta);
    if (!await carpeta.exists()) return const [];
    final archivos =
        await carpeta.list().where((e) => e is File && e.path.endsWith('.bin')).cast<File>().toList()
          ..sort((a, b) => _numero(a.path).compareTo(_numero(b.path)));
    final paginas = <Uint8List>[];
    for (final f in archivos) {
      final caja = SecretBox.fromConcatenation(
        await f.readAsBytes(),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      paginas.add(Uint8List.fromList(await _aes.decrypt(caja, secretKey: _clave)));
    }
    return paginas;
  }

  static int _numero(String ruta) =>
      int.tryParse(RegExp(r'pagina_(\d+)\.bin$').firstMatch(ruta)?.group(1) ?? '') ?? 0;

  @override
  Future<void> borrar(String ruta) async {
    final carpeta = _carpeta(ruta);
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
  }

  @override
  Future<void> borrarTodo() async {
    final raiz = Directory(p.join(carpetaBase.path, _raiz));
    if (await raiz.exists()) await raiz.delete(recursive: true);
  }
}
