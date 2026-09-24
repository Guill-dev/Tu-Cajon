import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/core/copia/llaves_de_copia.dart';
import 'package:tu_cajon/core/copia/red.dart';
import 'package:tu_cajon/data/copia/cifrado_copia.dart';
import 'package:tu_cajon/data/copia/copia_de_seguridad.dart';
import 'package:tu_cajon/data/copia/nube.dart';
import 'package:tu_cajon/data/copia/programador_de_copias.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';

Uint8List bytes(List<int> v) => Uint8List.fromList(v);

/// Un "celular": su cajón, sus llaves y su red, con la nube compartida.
class Celular {
  Celular(this.nube, {LlavesSimuladas? llaves, bool ejemplo = true, RedSimulada? red})
    : repo = MemoriaCajonRepositorio(ejemplo: ejemplo),
      llaves = llaves ?? LlavesSimuladas(),
      red = red ?? RedSimulada() {
    copia = CopiaDeSeguridad(repo: repo, nube: nube, llaves: this.llaves, red: this.red);
  }

  final NubeEnMemoria nube;
  final MemoriaCajonRepositorio repo;
  final LlavesSimuladas llaves;
  final RedSimulada red;
  late final CopiaDeSeguridad copia;

  Future<String> guardar(String nombre, List<Uint8List> paginas) async {
    // El id sale de la hora: dos documentos seguidos no pueden caer en el mismo instante.
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return repo.guardarDocumento(
      NuevoDocumento(perfilId: Perfil.idPropio, nombre: nombre, categoria: Categoria.identidad),
      paginas: paginas,
    );
  }
}

void main() {
  group('Cifrado de la copia', () {
    test('cifra y descifra; con otra llave o con otro nombre no abre', () async {
      final llave = CifradoCopia.nuevaLlave();
      final datos = bytes([1, 2, 3, 4, 5]);
      final cifrado = await CifradoCopia.cifrar(datos, llave, nombre: 'a.bin');
      expect(cifrado, isNot(contains(datos)));
      expect(await CifradoCopia.descifrar(cifrado, llave, nombre: 'a.bin'), datos);
      await expectLater(
        CifradoCopia.descifrar(cifrado, CifradoCopia.nuevaLlave(), nombre: 'a.bin'),
        throwsA(isA<LlaveEquivocada>()),
      );
      // Si alguien le cambia el nombre en la nube, tampoco abre.
      await expectLater(
        CifradoCopia.descifrar(cifrado, llave, nombre: 'b.bin'),
        throwsA(isA<LlaveEquivocada>()),
      );
      await expectLater(
        CifradoCopia.descifrar(bytes([9, 9]), llave, nombre: 'a.bin'),
        throwsA(isA<CopiaIlegible>()),
      );
    });

    test('empaqueta fotos y PDF sin perder nada', () {
      final fotos = [
        bytes([1, 2]),
        bytes([]),
        bytes([3, 4, 5]),
      ];
      final f = CifradoCopia.desempaquetar(CifradoCopia.empaquetar((paginas: fotos, pdf: null)));
      expect(f.pdf, isNull);
      expect(f.paginas, fotos);
      final p = CifradoCopia.desempaquetar(
        CifradoCopia.empaquetar((paginas: const [], pdf: bytes([7, 7, 7]))),
      );
      expect(p.pdf, bytes([7, 7, 7]));
      expect(p.paginas, isEmpty);
      expect(() => CifradoCopia.desempaquetar(bytes([1, 0, 0, 0, 9])), throwsA(isA<CopiaIlegible>()));
    });

    test('el código de emergencia se entiende escrito de cualquier forma', () {
      final codigo = CifradoCopia.nuevoCodigo();
      expect(codigo, matches(RegExp(r'^[0-9A-Z]{4}(-[0-9A-Z]{4}){3}$')));
      expect(CifradoCopia.normalizarCodigo(codigo.toLowerCase().replaceAll('-', ' ')), codigo);
      // La O se lee como cero, y la I o la L como uno.
      expect(CifradoCopia.normalizarCodigo('0000 1111 AAAA BBBB'), '0000-1111-AAAA-BBBB');
      expect(CifradoCopia.normalizarCodigo('oooo iiii llll aaaa'), '0000-1111-1111-AAAA');
      expect(CifradoCopia.normalizarCodigo('muy corto'), isNull);
      expect(CifradoCopia.normalizarCodigo('UUUU-UUUU-UUUU-UUUU'), isNull);
    });

    test('la llave protegida con el código solo abre con ese código', () async {
      final llave = CifradoCopia.nuevaLlave();
      final codigo = CifradoCopia.nuevoCodigo();
      final envuelta = await CifradoCopia.envolverLlave(llave, codigo);
      expect(await CifradoCopia.desenvolverLlave(envuelta, codigo), llave);
      await expectLater(
        CifradoCopia.desenvolverLlave(envuelta, CifradoCopia.nuevoCodigo()),
        throwsA(isA<CodigoEquivocado>()),
      );
    });
  });

  group('Hacer la copia', () {
    test('sin conectar no hace nada', () async {
      final a = Celular(NubeEnMemoria());
      await a.copia.hacerCopia();
      expect(a.nube.archivos, isEmpty);
      expect(a.copia.estado.value.ultima, isNull);
    });

    test('sube el índice y los archivos de cada documento, todo cifrado', () async {
      final a = Celular(NubeEnMemoria());
      await a.guardar('Cédula', [
        bytes([1, 2, 3]),
        bytes([4, 5, 6]),
      ]);
      await a.guardar('RUT', [
        bytes([7, 8, 9]),
      ]);
      expect(await a.copia.conectar(), isTrue);
      await a.copia.hacerCopia();

      final nombres = a.nube.archivos.keys.toSet();
      expect(nombres, contains(CopiaDeSeguridad.archivoIndice));
      expect(nombres.where((n) => n.startsWith('tucajon-doc-')), hasLength(2));
      // Nada se sube en claro: ni los nombres de los documentos.
      final todo = a.nube.archivos.values.expand((v) => v.$1).toList();
      expect(String.fromCharCodes(todo), isNot(contains('Cédula')));

      final e = a.copia.estado.value;
      expect(e.ultima, isNotNull);
      expect(e.documentos, 14); // los 12 de ejemplo (Marta y Mamá) y los 2 nuevos
      expect(e.bytes, greaterThan(0));
      expect(e.problema, isNull);
    });

    test('solo sube lo que cambió y borra lo que ya no se usa', () async {
      final a = Celular(NubeEnMemoria());
      final cedula = await a.guardar('Cédula', [
        bytes([1, 2, 3]),
      ]);
      final rut = await a.guardar('RUT', [
        bytes([4, 5, 6]),
      ]);
      await a.copia.conectar();
      await a.copia.hacerCopia();
      a.nube.subidos.clear();

      // Sin cambios: no sube nada.
      await a.copia.hacerCopia();
      expect(a.nube.subidos, isEmpty);

      // Cambiar solo el nombre: sube el índice, no los archivos.
      await a.repo.renombrarDocumento(rut, 'RUT 2026');
      await a.copia.hacerCopia();
      expect(a.nube.subidos, [CopiaDeSeguridad.archivoIndice]);
      a.nube.subidos.clear();

      // Cambiar las páginas: sube ese documento y borra su versión vieja.
      final antes = a.nube.archivos.keys.where((n) => n.contains(cedula)).single;
      await Future<void>.delayed(const Duration(milliseconds: 5)); // otra hora de guardado
      final doc = (await a.repo.leerContenido()).documentos.firstWhere((d) => d.id == cedula);
      await a.repo.actualizarDocumento(
        cedula,
        NuevoDocumento(perfilId: doc.perfilId, nombre: doc.nombre, categoria: doc.categoria),
        paginas: [
          bytes([9, 9, 9]),
        ],
      );
      await a.copia.hacerCopia();
      expect(a.nube.subidos.where((n) => n.contains(cedula)), hasLength(1));
      expect(a.nube.archivos.keys, isNot(contains(antes)));

      // Borrar un documento: su archivo sale de la nube.
      await a.repo.eliminarDocumento(rut);
      await a.copia.hacerCopia();
      expect(a.nube.archivos.keys.where((n) => n.contains(rut)), isEmpty);
    });

    test('la automática espera el Wi-Fi; la que pide la persona no', () async {
      final a = Celular(NubeEnMemoria(), red: RedSimulada(wifi: false));
      await a.guardar('Cédula', [
        bytes([1]),
      ]);
      await a.copia.conectar();

      await a.copia.hacerCopia(automatica: true);
      expect(a.copia.estado.value.esperandoWifi, isTrue);
      expect(a.nube.archivos, isEmpty);

      await a.copia.hacerCopia();
      expect(a.nube.archivos, isNotEmpty);
      expect(a.copia.estado.value.esperandoWifi, isFalse);

      // Sin "Solo con Wi-Fi", la automática también usa datos.
      await a.copia.cambiarSoloWifi(false);
      await a.guardar('RUT', [
        bytes([2]),
      ]);
      await a.copia.hacerCopia(automatica: true);
      expect(a.nube.archivos.keys.where((n) => n.startsWith('tucajon-doc-')), hasLength(2));
    });

    test('si falla, lo dice y la próxima vez vuelve a intentar', () async {
      final a = Celular(NubeEnMemoria());
      await a.guardar('Cédula', [
        bytes([1]),
      ]);
      await a.copia.conectar();
      a.nube.fallarCon = const SinConexion();
      await a.copia.hacerCopia();
      expect(a.copia.estado.value.problema, const SinConexion().mensaje);
      expect(a.copia.estado.value.haciendo, isFalse);

      await a.copia.hacerCopia();
      expect(a.copia.estado.value.problema, isNull);
      expect(a.nube.archivos, contains(CopiaDeSeguridad.archivoIndice));
    });

    test('si Google quita el permiso, queda desconectada', () async {
      final a = Celular(NubeEnMemoria());
      await a.copia.conectar();
      a.nube.fallarCon = const PermisoPerdido();
      await a.copia.hacerCopia();
      expect(a.copia.estado.value.conectada, isFalse);
      expect(a.copia.estado.value.problema, const PermisoPerdido().mensaje);
    });

    test('los ajustes de la copia se recuerdan al volver a abrir la app', () async {
      final a = Celular(NubeEnMemoria());
      await a.copia.conectar();
      await a.copia.cambiarSoloWifi(false);
      await a.copia.hacerCopia();
      final otraVez = CopiaDeSeguridad(repo: a.repo, nube: a.nube, llaves: a.llaves, red: a.red);
      await otraVez.listo;
      expect(otraVez.estado.value.cuenta, 'marta@gmail.com');
      expect(otraVez.estado.value.soloWifi, isFalse);
      expect(otraVez.estado.value.ultima, a.copia.estado.value.ultima);
    });

    test('desconectar deja la copia en la nube', () async {
      final a = Celular(NubeEnMemoria());
      await a.copia.conectar();
      await a.copia.hacerCopia();
      await a.copia.desconectar();
      expect(a.copia.estado.value.conectada, isFalse);
      expect(a.nube.archivos, contains(CopiaDeSeguridad.archivoIndice));
    });
  });

  group('Recuperar en un celular nuevo', () {
    Future<(Celular, Uint8List)> celularViejo(NubeEnMemoria nube) async {
      final a = Celular(nube);
      await a.guardar('Cédula', [
        bytes([1, 2, 3]),
        bytes([4, 5, 6]),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 3)); // otro id
      await a.repo.guardarDocumento(
        const NuevoDocumento(perfilId: 'mama', nombre: 'Fórmula médica', categoria: Categoria.salud),
        pdf: bytes([37, 80, 68, 70]),
      );
      await a.repo.descartarSugerencia('renovar:licencia');
      await a.copia.conectar();
      await a.copia.hacerCopia();
      return (a, (await a.llaves.leer())!);
    }

    test('con la llave que llegó sola (Block Store) trae todo igual', () async {
      final nube = NubeEnMemoria();
      final (a, llave) = await celularViejo(nube);
      final b = Celular(nube, llaves: LlavesSimuladas(deOtroCelular: llave), ejemplo: false);

      final copia = await b.copia.buscarCopia();
      expect(copia, isNotNull);
      expect(copia!.abierta, isTrue);
      expect(copia.indice!.contenido.nombre, 'Marta');
      await b.copia.recuperar(copia);

      final antes = await a.repo.leerContenido();
      final ahora = await b.repo.leerContenido();
      expect(ahora.nombre, antes.nombre);
      expect(ahora.perfiles.map((p) => p.id), antes.perfiles.map((p) => p.id));
      expect(ahora.documentos.map((d) => d.nombre).toSet(), antes.documentos.map((d) => d.nombre).toSet());
      expect(ahora.descartadas, contains('renovar:licencia'));
      final cedula = ahora.documentos.firstWhere((d) => d.nombre == 'Cédula');
      expect(await b.repo.leerPaginas(cedula), [
        bytes([1, 2, 3]),
        bytes([4, 5, 6]),
      ]);
      final formula = ahora.documentos.firstWhere((d) => d.nombre == 'Fórmula médica');
      expect(formula.perfilId, 'mama');
      expect(await b.repo.leerPdf(formula), bytes([37, 80, 68, 70]));

      // Queda conectada y sigue la misma copia: no vuelve a subir los archivos.
      expect(b.copia.estado.value.conectada, isTrue);
      nube.subidos.clear();
      await b.copia.hacerCopia();
      expect(nube.subidos.where((n) => n.startsWith('tucajon-doc-')), isEmpty);
    });

    test('sin la llave, se abre con el código de emergencia', () async {
      final nube = NubeEnMemoria();
      final (a, _) = await celularViejo(nube);
      final codigo = await a.copia.crearCodigoDeEmergencia();
      expect(a.copia.estado.value.codigoCreado, isNotNull);

      final b = Celular(nube, ejemplo: false);
      final copia = await b.copia.buscarCopia();
      expect(copia!.abierta, isFalse);
      expect(copia.conCodigo, isTrue);

      await expectLater(
        b.copia.abrirConCodigo(copia, CifradoCopia.nuevoCodigo()),
        throwsA(isA<CodigoEquivocado>()),
      );
      await expectLater(b.copia.abrirConCodigo(copia, 'no es un código'), throwsA(isA<CodigoEquivocado>()));

      final abierta = await b.copia.abrirConCodigo(copia, codigo.toLowerCase().replaceAll('-', ' '));
      await b.copia.recuperar(abierta);
      expect((await b.repo.leerContenido()).documentos.map((d) => d.nombre), contains('Cédula'));
      // La llave queda en este celular para las próximas copias.
      expect(await b.llaves.leer(), await a.llaves.leer());
    });

    test('un código nuevo reemplaza al anterior', () async {
      final nube = NubeEnMemoria();
      final (a, _) = await celularViejo(nube);
      final viejo = await a.copia.crearCodigoDeEmergencia();
      final nuevo = await a.copia.crearCodigoDeEmergencia();
      final b = Celular(nube, ejemplo: false);
      final copia = (await b.copia.buscarCopia())!;
      await expectLater(b.copia.abrirConCodigo(copia, viejo), throwsA(isA<CodigoEquivocado>()));
      expect((await b.copia.abrirConCodigo(copia, nuevo)).abierta, isTrue);
    });

    test('si no hay copia en la cuenta, lo dice', () async {
      final b = Celular(NubeEnMemoria(), ejemplo: false);
      expect(await b.copia.buscarCopia(), isNull);
      expect(b.copia.estado.value.conectada, isFalse);
    });

    test('si falla a mitad, el cajón queda como estaba', () async {
      final nube = NubeEnMemoria();
      final (_, llave) = await celularViejo(nube);
      final b = Celular(nube, llaves: LlavesSimuladas(deOtroCelular: llave));
      final antes = await b.repo.leerContenido();
      final copia = (await b.copia.buscarCopia())!;
      // Se pierde un archivo de la nube.
      nube.archivos.remove(nube.archivos.keys.firstWhere((n) => n.startsWith('tucajon-doc-')));
      await expectLater(b.copia.recuperar(copia), throwsA(anything));
      final despues = await b.repo.leerContenido();
      expect(despues.documentos.map((d) => d.id), antes.documentos.map((d) => d.id));
      expect(despues.nombre, antes.nombre);
    });
  });

  group('Conectar una cuenta que ya tiene copia', () {
    test('si es de este mismo celular, sigue con ella', () async {
      final a = Celular(NubeEnMemoria());
      await a.copia.conectar();
      await a.copia.hacerCopia();
      await a.copia.desconectar();
      expect(await a.copia.conectar(), isTrue);
    });

    test('si es de otro celular, pregunta; al reemplazar empieza de cero', () async {
      final nube = NubeEnMemoria();
      final a = Celular(nube);
      await a.guardar('Cédula', [
        bytes([1]),
      ]);
      await a.copia.conectar();
      await a.copia.hacerCopia();
      await a.copia.crearCodigoDeEmergencia();

      final b = Celular(nube, ejemplo: false);
      expect(await b.copia.conectar(), isFalse);
      expect(b.copia.estado.value.conectada, isFalse);
      await b.copia.reemplazarCopiaAjena();
      expect(b.copia.estado.value.conectada, isTrue);
      expect(nube.archivos, isEmpty);
      await b.copia.hacerCopia();
      expect(nube.archivos.keys.where((n) => n.startsWith('tucajon-doc-')), isEmpty);
      expect(nube.archivos, contains(CopiaDeSeguridad.archivoIndice));
    });
  });

  group('Programador', () {
    // Todo en el reloj de la prueba: la copia en memoria solo usa microtareas,
    // así que cada pump la deja terminada.
    testWidgets('hace la copia sola un rato después de un cambio', (tester) async {
      final a = Celular(NubeEnMemoria());
      await a.copia.conectar();
      final programador = ProgramadorDeCopias(
        copia: a.copia,
        repo: a.repo,
        espera: const Duration(seconds: 5),
      );
      addTearDown(programador.dispose);
      await tester.pump();
      // Recién conectada, sin copia: la programa sola.
      expect(a.copia.estado.value.ultima, isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(a.copia.estado.value.ultima, isNotNull);
      a.nube.subidos.clear();

      await a.repo.renombrarDocumento('licencia', 'Licencia nueva');
      await tester.pump(const Duration(seconds: 2));
      expect(a.nube.subidos, isEmpty, reason: 'todavía está esperando');
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(a.nube.subidos, contains(CopiaDeSeguridad.archivoIndice));
    });

    testWidgets('sin cuenta conectada no programa nada', (tester) async {
      final a = Celular(NubeEnMemoria());
      final programador = ProgramadorDeCopias(
        copia: a.copia,
        repo: a.repo,
        espera: const Duration(seconds: 1),
      );
      addTearDown(programador.dispose);
      await a.repo.renombrarDocumento('licencia', 'Otra');
      await tester.pump(const Duration(seconds: 3));
      expect(a.nube.archivos, isEmpty);
    });
  });
}
