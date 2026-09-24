import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/core/theme/app_colors.dart';
import 'package:tu_cajon/data/db/base_datos.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/drift_repositorio.dart';
import 'package:tu_cajon/features/avisos/sugerencias.dart';
import 'package:tu_cajon/features/preguntar/respuestas_demo.dart';

/// Pruebas de la base de datos real (Drift + SQLite con FTS5), en memoria.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DriftCajonRepositorio repo;

  DriftCajonRepositorio abrir({bool ejemplo = true}) =>
      DriftCajonRepositorio(BaseDatos(NativeDatabase.memory(), cargarEjemplo: ejemplo));

  setUp(() => repo = abrir());
  tearDown(() => repo.cerrar());

  group('Arranque', () {
    test('una base nueva sin ejemplo solo tiene el perfil propio', () async {
      final vacia = abrir(ejemplo: false);
      addTearDown(vacia.cerrar);
      final perfiles = await vacia.vigilarPerfiles().first;
      expect(perfiles, hasLength(1));
      expect(perfiles.single.esPropio, isTrue);
      expect(await vacia.vigilarTodos().first, isEmpty);
      expect(await vacia.leerNombre(), '');
      expect(await vacia.llaveActivada(), isFalse);
    });

    test('con ejemplo: Marta (8 documentos) y Mamá (4)', () async {
      final perfiles = await repo.vigilarPerfiles().first;
      expect(perfiles.map((p) => p.nombre), ['Tú', 'Mamá']);
      expect(perfiles.map((p) => p.documentos), [8, 4]);
      expect(await repo.leerNombre(), 'Marta');
    });
  });

  group('Ajustes', () {
    test('guardar el nombre actualiza la inicial del perfil propio', () async {
      await repo.guardarNombre('  ana ');
      expect(await repo.leerNombre(), 'ana');
      final propio = (await repo.vigilarPerfiles().first).firstWhere((p) => p.esPropio);
      expect(propio.inicial, 'A');
    });

    test('la llave queda activada', () async {
      await repo.activarLlave();
      expect(await repo.llaveActivada(), isTrue);
    });
  });

  group('Búsqueda (FTS5)', () {
    Future<List<String>> buscarEn(String perfil, String q) async =>
        (await repo.vigilarDocumentos(perfil, busqueda: q).first).map((d) => d.nombre).toList();

    test('encuentra sin tildes y por prefijo', () async {
      expect(await buscarEn(Perfil.idPropio, 'licencia de conduccion'), ['Licencia de conducción']);
      expect(await buscarEn(Perfil.idPropio, 'cedu'), ['Cédula de ciudadanía']);
    });

    test('busca también en el texto leído del documento', () async {
      expect(await buscarEn(Perfil.idPropio, 'AB1234567'), ['Pasaporte']);
    });

    test('solo busca en el perfil pedido', () async {
      expect(await buscarEn('mama', 'cedula'), ['Cédula de ciudadanía']);
      expect(await buscarEn('mama', 'pasaporte'), isEmpty);
    });

    test('signos raros no rompen la consulta', () async {
      expect(await buscarEn(Perfil.idPropio, '"(*) OR -'), isEmpty);
    });

    test('buscar() recorre todos los perfiles', () async {
      final r = await repo.buscar('pension');
      expect(r.single.perfilId, 'mama');
    });
  });

  group('Documentos', () {
    test('guardar, renombrar y eliminar se reflejan en los streams', () async {
      final emisiones = <int>[];
      final sub = repo.vigilarDocumentos(Perfil.idPropio).listen((d) => emisiones.add(d.length));
      addTearDown(sub.cancel);
      await pumpEventQueue(); // espera la primera emisión (8 documentos)

      final id = await repo.guardarDocumento(
        const NuevoDocumento(
          perfilId: Perfil.idPropio,
          nombre: 'Certificado bancario',
          categoria: Categoria.otro,
          textoExtraido: 'Cuenta de ahorros 123-456789-00',
        ),
      );
      await repo.renombrarDocumento(id, 'Certificado del banco');
      final doc = await repo.vigilarDocumento(id).first;
      expect(doc!.nombre, 'Certificado del banco');
      // El índice de búsqueda se actualizó con el nombre nuevo.
      expect((await repo.buscar('banco')).map((d) => d.id), contains(id));

      await repo.eliminarDocumento(id);
      expect(await repo.vigilarDocumento(id).first, isNull);
      expect(await repo.buscar('banco'), isEmpty);

      await pumpEventQueue();
      expect(emisiones.first, 8);
      expect(emisiones, contains(9));
      expect(emisiones.last, 8);
    });

    test('actualizar reemplaza las páginas del mismo documento y borra las viejas', () async {
      final id = await repo.guardarDocumento(
        const NuevoDocumento(perfilId: Perfil.idPropio, nombre: 'Licencia', categoria: Categoria.vehiculo),
        paginas: [
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5, 6]),
        ],
      );
      final antes = (await repo.vigilarDocumento(id).first)!;
      final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 7, 7, 7]);
      final vence = DateTime(2031, 5, 1);

      await repo.actualizarDocumento(
        id,
        NuevoDocumento(
          perfilId: 'mama',
          nombre: 'Licencia nueva',
          categoria: Categoria.vehiculo,
          venceEn: vence,
        ),
        pdf: pdf,
      );

      final despues = (await repo.vigilarDocumento(id).first)!;
      expect(despues.nombre, 'Licencia nueva');
      expect(despues.perfilId, 'mama');
      expect(despues.venceEn, vence);
      expect(await repo.leerPdf(despues), pdf);
      expect(await repo.leerPaginas(despues), isEmpty);
      // Las páginas de antes ya no están, y sigue siendo un solo documento.
      expect(await repo.leerPaginas(antes), isEmpty);
      expect(
        (await repo.vigilarTodos().first).where((d) => d.nombre.startsWith('Licencia nueva')),
        hasLength(1),
      );
      expect((await repo.buscar('nueva')).map((d) => d.id), contains(id));
    });

    test('actualizar solo los datos deja las páginas y la fecha de guardado', () async {
      final id = await repo.guardarDocumento(
        const NuevoDocumento(perfilId: Perfil.idPropio, nombre: 'RUT viejo', categoria: Categoria.otro),
        paginas: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      final antes = (await repo.vigilarDocumento(id).first)!;
      await repo.actualizarDocumento(
        id,
        const NuevoDocumento(perfilId: Perfil.idPropio, nombre: 'RUT', categoria: Categoria.impuestos),
      );
      final despues = (await repo.vigilarDocumento(id).first)!;
      expect(despues.categoria, Categoria.impuestos);
      expect(despues.guardadoEn, antes.guardadoEn);
      expect(await repo.leerPaginas(despues), hasLength(1));
    });

    test('crear un perfil lo agrega al final con 0 documentos', () async {
      final p = await repo.crearPerfil(
        nombre: 'Firulais',
        tipo: TipoPerfil.mascota,
        color: AppColors.primario,
      );
      final perfiles = await repo.vigilarPerfiles().first;
      expect(perfiles.last.id, p.id);
      expect(perfiles.last.tipo, TipoPerfil.mascota);
      expect(perfiles.last.documentos, 0);
    });
  });

  group('Etiquetas y sugerencias', () {
    final hoy = DateTime(2026, 9, 22);
    Documento doc({DateTime? vence, int guardadoHace = 5, String nombre = 'Licencia de conducción'}) =>
        Documento(
          id: 'x',
          perfilId: Perfil.idPropio,
          nombre: nombre,
          categoria: Categoria.vehiculo,
          guardadoEn: hoy.subtract(Duration(days: guardadoHace)),
          venceEn: vence,
        );

    test('etiquetas según la fecha de vencimiento', () {
      expect(doc(vence: hoy.add(const Duration(days: 18))).etiqueta(hoy)!.texto, 'Vence en 18 días');
      expect(doc(vence: hoy.add(const Duration(days: 145))).etiqueta(hoy)!.texto, 'Vence en 5 meses');
      expect(doc(vence: hoy.subtract(const Duration(days: 1))).etiqueta(hoy)!.tono, TonoAviso.peligro);
      expect(doc(nombre: 'Certificado de la EPS', guardadoHace: 62).etiqueta(hoy)!.texto, 'Tiene 2 meses');
      expect(doc().etiqueta(hoy), isNull);
    });

    test('las sugerencias descartadas no vuelven', () async {
      final docs = await repo.vigilarTodos().first;
      final antes = calcularSugerencias(docs, {}, DateTime.now());
      expect(antes.map((s) => s.tipo), contains(TipoSugerencia.renovar));

      await repo.descartarSugerencia(antes.first.clave);
      final descartadas = await repo.vigilarSugerenciasDescartadas().first;
      final despues = calcularSugerencias(docs, descartadas, DateTime.now());
      expect(despues, hasLength(antes.length - 1));
    });
  });

  group('Copia de seguridad', () {
    test('leer todo y restaurarlo en otra base deja el cajón igual', () async {
      final id = await repo.guardarDocumento(
        NuevoDocumento(
          perfilId: 'mama',
          nombre: 'Fórmula médica',
          categoria: Categoria.salud,
          venceEn: DateTime(2027, 1, 15),
        ),
        paginas: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      await repo.descartarSugerencia('renovar:licencia');
      final contenido = await repo.leerContenido();
      final archivos = {
        for (final d in contenido.documentos)
          d.id: (paginas: await repo.leerPaginas(d), pdf: await repo.leerPdf(d)),
      };

      final nueva = abrir(ejemplo: false);
      addTearDown(nueva.cerrar);
      await nueva.restaurar(contenido, archivosDe: (d) async => archivos[d.id]!);

      final ahora = await nueva.leerContenido();
      expect(ahora.nombre, 'Marta');
      expect(ahora.perfiles.map((p) => (p.id, p.nombre, p.esPropio, p.documentos)), [
        for (final p in await repo.vigilarPerfiles().first) (p.id, p.nombre, p.esPropio, p.documentos),
      ]);
      expect(ahora.documentos.map((d) => d.id).toSet(), contenido.documentos.map((d) => d.id).toSet());
      final formula = ahora.documentos.firstWhere((d) => d.id == id);
      final original = contenido.documentos.firstWhere((d) => d.id == id);
      expect(formula.perfilId, 'mama');
      expect(formula.venceEn, DateTime(2027, 1, 15));
      expect(formula.guardadoEn, original.guardadoEn);
      expect(await nueva.leerPaginas(formula), [
        [1, 2, 3],
      ]);
      // La búsqueda y lo descartado también vuelven; la llave de este celular no.
      expect((await nueva.buscar('formula')).map((d) => d.id), contains(id));
      expect(await nueva.vigilarSugerenciasDescartadas().first, contains('renovar:licencia'));
      expect(await nueva.llaveActivada(), isFalse);
    });

    test('si falla a mitad, la base queda como estaba', () async {
      await repo.guardarDocumento(
        const NuevoDocumento(perfilId: Perfil.idPropio, nombre: 'Con fotos', categoria: Categoria.otro),
        paginas: [
          Uint8List.fromList([1]),
        ],
      );
      final todo = await repo.leerContenido();
      final otra = abrir(ejemplo: false);
      addTearDown(otra.cerrar);
      await otra.guardarNombre('Luis');
      await expectLater(
        otra.restaurar(todo, archivosDe: (_) async => throw StateError('se cayó la red')),
        throwsStateError,
      );
      expect(await otra.leerNombre(), 'Luis');
      expect(await otra.vigilarTodos().first, isEmpty);
    });

    test('anotar los datos de la copia no cuenta como un cambio del nombre', () async {
      // El programador de copias escucha el nombre así; si cada copia terminada
      // contara como un cambio, se programaría otra copia sin parar.
      final emisiones = <String>[];
      final sub = repo.vigilarNombre().distinct().listen(emisiones.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.guardarAjuste('copia.ultima', '1');
      await repo.guardarAjuste('copia.huella', 'abc');
      await pumpEventQueue();
      expect(emisiones, ['Marta']);
      await repo.guardarNombre('Ana');
      await pumpEventQueue();
      expect(emisiones, ['Marta', 'Ana']);
    });

    test('los ajustes sueltos se guardan y se borran', () async {
      expect(await repo.leerAjuste('copia.cuenta'), isNull);
      await repo.guardarAjuste('copia.cuenta', 'marta@gmail.com');
      expect(await repo.leerAjuste('copia.cuenta'), 'marta@gmail.com');
      await repo.guardarAjuste('copia.cuenta', null);
      expect(await repo.leerAjuste('copia.cuenta'), isNull);
    });
  });

  group('Pregúntale a tu cajón', () {
    test('responde números y vencimientos desde la base', () async {
      final ia = AsistenteLocal(repo);
      expect((await ia.responder('¿Cuál es mi número de pasaporte?')).texto, contains('AB1234567'));
      expect((await ia.responder('¿Cuál es mi número de cédula?')).texto, contains('52.348.910'));
      expect((await ia.responder('¿Cuándo vence mi licencia?')).texto, contains('faltan 18 días'));
      expect((await ia.responder('¿Dónde está mi contrato de arriendo?')).cta, isNull);
    });
  });
}
