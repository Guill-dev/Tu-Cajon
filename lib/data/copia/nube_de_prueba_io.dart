import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'nube.dart';

/// Nube de prueba: una carpeta dentro de la carpeta privada de la app
/// (`nube_de_prueba/`). Sirve para probar la copia completa en el celular
/// antes de conectar Google Drive. Lo que se guarda aquí va cifrado igual
/// que irá a Drive.
class NubeDePrueba implements Nube {
  NubeDePrueba();

  late final Future<Directory> _carpeta = getApplicationSupportDirectory().then(
    (base) => Directory(p.join(base.path, 'nube_de_prueba')).create(recursive: true),
  );

  /// Solo nombres simples: nada de rutas ni "..".
  Future<File> _archivo(String nombre) async {
    if (nombre != p.basename(nombre) || nombre.startsWith('.')) {
      throw ArgumentError.value(nombre, 'nombre', 'Nombre de archivo no válido');
    }
    return File(p.join((await _carpeta).path, nombre));
  }

  @override
  bool get deprueba => true;

  @override
  Future<String> conectar() async => 'Modo de prueba';

  @override
  Future<void> desconectar() async {}

  @override
  Future<List<ArchivoEnNube>> listar() async {
    final archivos = await (await _carpeta)
        .list()
        .where((e) => e is File && !e.path.endsWith('.parcial'))
        .cast<File>()
        .toList();
    return [
      for (final f in archivos)
        ArchivoEnNube(
          nombre: p.basename(f.path),
          bytes: await f.length(),
          modificado: await f.lastModified(),
        ),
    ];
  }

  @override
  Future<void> subir(String nombre, Uint8List datos) async {
    // Primero a un temporal y luego se cambia el nombre: nunca queda un
    // archivo a medias con el nombre bueno.
    final destino = await _archivo(nombre);
    final temporal = File('${destino.path}.parcial');
    await temporal.writeAsBytes(datos, flush: true);
    await temporal.rename(destino.path);
  }

  @override
  Future<Uint8List> bajar(String nombre) async => (await _archivo(nombre)).readAsBytes();

  @override
  Future<void> borrar(String nombre) async {
    final f = await _archivo(nombre);
    if (await f.exists()) await f.delete();
  }
}
