import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tu_cajon/core/theme/app_colors.dart';
import 'package:tu_cajon/data/db/base_cifrada.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/drift_repositorio.dart';

/// La base cifrada en un archivo real: se crea, se cierra y se vuelve a abrir,
/// como cuando el usuario cierra la app y vuelve a entrar. (El error de
/// "file is not a database" solo aparecía en esta segunda apertura.)
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory carpeta;
  late File archivo;
  const clave = 'clave-de-prueba_123ABCxyz';

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('tu_cajon_test');
    archivo = File(p.join(carpeta.path, 'tu_cajon.sqlite'));
  });
  tearDown(() => carpeta.delete(recursive: true));

  DriftCajonRepositorio abrir(String k) =>
      DriftCajonRepositorio(abrirBaseCifrada(archivo, k, enSegundoPlano: false));

  test('se cierra y se vuelve a abrir con sus datos', () async {
    final primera = abrir(clave);
    await primera.guardarNombre('Ana');
    await primera.activarLlave();
    await primera.crearPerfil(nombre: 'Mamá', tipo: TipoPerfil.persona, color: AppColors.primario);
    await primera.cerrar();

    // Segunda apertura: aquí fallaba antes.
    final segunda = abrir(clave);
    addTearDown(segunda.cerrar);
    expect(await segunda.leerNombre(), 'Ana');
    expect(await segunda.llaveActivada(), isTrue);
    final perfiles = await segunda.vigilarPerfiles().first;
    expect(perfiles.map((p) => p.nombre), ['Tú', 'Mamá']);
  });

  test('el archivo queda cifrado en el disco', () async {
    const nombreSecreto = 'Anacleta-Zuniga-Prueba-Cifrado';
    final repo = abrir(clave);
    await repo.guardarNombre(nombreSecreto);
    await repo.cerrar();

    final bytes = await archivo.readAsBytes();
    // Un SQLite normal empieza con "SQLite format 3"; uno cifrado, no.
    expect(ascii.decode(bytes.sublist(0, 15), allowInvalid: true), isNot('SQLite format 3'));
    // Y el nombre guardado no aparece en claro dentro del archivo.
    expect(latin1.decode(bytes).contains(nombreSecreto), isFalse);
  });

  test('con otra clave no se puede abrir', () async {
    final repo = abrir(clave);
    await repo.guardarNombre('Ana');
    await repo.cerrar();

    final intruso = abrir('otra-clave-distinta');
    addTearDown(intruso.cerrar);
    await expectLater(intruso.leerNombre(), throwsA(anything));
  });

  test('rechaza claves con caracteres que romperían el PRAGMA', () {
    expect(() => abrirBaseCifrada(archivo, "x'; DROP TABLE perfiles; --"), throwsArgumentError);
  });
}
