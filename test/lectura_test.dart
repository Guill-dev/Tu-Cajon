import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/app.dart';
import 'package:tu_cajon/core/avisos/recordatorios.dart';
import 'package:tu_cajon/core/lectura/lector_de_texto.dart';
import 'package:tu_cajon/core/pdf/lector_pdf.dart';
import 'package:tu_cajon/core/router/app_routes.dart';
import 'package:tu_cajon/core/seguridad/llave_celular.dart';
import 'package:tu_cajon/data/lectura/interprete.dart';
import 'package:tu_cajon/data/lectura/lector_del_cajon.dart';
import 'package:tu_cajon/data/lectura/lectura_de_documentos.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';
import 'package:tu_cajon/features/guardar/guardar_screen.dart';

import 'foto_prueba.dart';

// Textos como los que devuelve el lector al leer papeles de verdad.
const cedulaFrente = '''REPUBLICA DE COLOMBIA
IDENTIFICACION PERSONAL
CEDULA DE CIUDADANIA
NUMERO 52.348.910
GOMEZ RUIZ
APELLIDOS
MARTA LUCIA
NOMBRES''';

const cedulaReverso = '''FECHA DE NACIMIENTO 12-MAR-1985
BOGOTA D.C. (CUNDINAMARCA)
LUGAR DE NACIMIENTO
1.62 O+ F
ESTATURA G.S. RH SEXO
20-ABR-2003 BOGOTA D.C.
FECHA Y LUGAR DE EXPEDICION''';

const pasaporte = '''REPUBLICA DE COLOMBIA
PASAPORTE / PASSPORT
Pasaporte No. / Passport No. AB1234567
Fecha de nacimiento / Date of birth 12 MAR/MAR 1985
Fecha de expedición / Date of issue 10 FEB/FEB 2020
Fecha de vencimiento / Date of expiry 10 FEB/FEB 2030''';

const licencia = '''LICENCIA DE CONDUCCION
REPUBLICA DE COLOMBIA
No. 52348910
GOMEZ RUIZ MARTA LUCIA
FECHA EXPEDICION 05/06/2018
CATEGORIA B1 VIGENCIA 05/06/2028''';

const soat = '''SEGURO OBLIGATORIO DE ACCIDENTES DE TRANSITO SOAT
Póliza No. 1234-5678
PLACA ABC123
VIGENCIA DESDE 01/02/2026 HASTA 31/01/2027''';

void main() {
  group('Entender el texto', () {
    test('Cédula: tipo, carpeta y número; la cédula no se vence', () {
      final d = Interprete.entender('$cedulaFrente\n$cedulaReverso');
      expect(d.nombre, 'Cédula de ciudadanía');
      expect(d.categoria, Categoria.identidad);
      expect(d.numero, '52.348.910');
      expect(d.reconocido, isTrue);
      // Nacimiento y expedición no son vencimientos.
      expect(d.venceEn, isNull);
    });

    test('Pasaporte: el número y la fecha de vencimiento (no la de nacimiento ni la de expedición)', () {
      final d = Interprete.entender(pasaporte);
      expect(d.nombre, 'Pasaporte');
      expect(d.numero, 'AB1234567');
      expect(d.venceEn, DateTime(2030, 2, 10));
    });

    test('Licencia de conducción: vence con la vigencia de la categoría', () {
      final d = Interprete.entender(licencia);
      expect(d.nombre, 'Licencia de conducción');
      expect(d.categoria, Categoria.vehiculo);
      expect(d.numero, '52348910');
      expect(d.venceEn, DateTime(2028, 6, 5));
      // Sin la palabra "vigencia", también: es la fecha más lejana que no es de expedición.
      expect(Interprete.entender(licencia.replaceAll('VIGENCIA ', '')).venceEn, DateTime(2028, 6, 5));
    });

    test('SOAT: la placa va en el nombre y vence en el "hasta", no en el "desde"', () {
      final d = Interprete.entender(soat);
      expect(d.nombre, 'SOAT · ABC123');
      expect(d.categoria, Categoria.vehiculo);
      expect(d.numero, 'ABC123');
      expect(d.venceEn, DateTime(2027, 1, 31));
    });

    test('RUT: el NIT, en Impuestos y sin vencimiento', () {
      final d = Interprete.entender(
        'Formulario del Registro Único Tributario\nDIAN\nNIT 52348910-1\nFecha generación 15/01/2024',
      );
      expect(d.nombre, 'RUT');
      expect(d.categoria, Categoria.impuestos);
      expect(d.numero, '52348910-1');
      expect(d.venceEn, isNull);
    });

    test('Un certificado que menciona la cédula sigue siendo un certificado (gana el título)', () {
      final eps = Interprete.entender(
        'CERTIFICADO DE AFILIACIÓN\nLa EPS SANITAS certifica que MARTA LUCIA GOMEZ identificada con '
        'cédula de ciudadanía No. 52.348.910 se encuentra afiliada.\nFecha de expedición: 3 de octubre de 2026',
      );
      expect(eps.nombre, 'Certificado de la EPS');
      expect(eps.categoria, Categoria.salud);
      expect(eps.numero, '52.348.910');
      expect(eps.venceEn, isNull);

      final laboral = Interprete.entender(
        'CERTIFICADO LABORAL\nLa empresa certifica que el señor identificado con cédula de ciudadanía '
        'No. 1.023.456.789 labora en esta compañía. Teléfono 3001234567',
      );
      expect(laboral.nombre, 'Certificado laboral');
      expect(laboral.numero, '1.023.456.789');
    });

    test('Un recibo de la luz va a Hogar, y su fecha de pago no es un vencimiento', () {
      final d = Interprete.entender(
        'ENEL\nFactura de servicios públicos\nEnergía 152 kWh\nTotal a pagar \$ 85.400\nPago oportuno 15/10/2026',
      );
      expect(d.nombre, 'Recibo de la luz');
      expect(d.categoria, Categoria.hogar);
      expect(d.venceEn, isNull);
    });

    test('Un papel desconocido: propone su título (la letra más grande) y la fecha si dice que vence', () {
      final pagina = PaginaLeida.deTexto(
        'CONSTANCIA DE PARTICIPACIÓN\nSe entrega a Marta Lucía Gómez\nVálida hasta el 15 de octubre de 2027',
        titulos: {0},
      );
      final d = Interprete.entender(pagina.texto, lineas: pagina.lineas);
      expect(d.nombre, 'Constancia de participación');
      expect(d.categoria, isNull);
      expect(d.reconocido, isFalse);
      expect(d.venceEn, DateTime(2027, 10, 15));
    });

    test('Sin un título que se destaque no se inventa nombre; una fecha imposible no cuenta', () {
      final pagina = PaginaLeida.deTexto('Hola\nEsto es una nota\nVence el 31/02/2026');
      final d = Interprete.entender(pagina.texto, lineas: pagina.lineas);
      expect(d.nombre, isNull);
      expect(d.venceEn, isNull);
      expect(Interprete.entender('').nombre, isNull);
    });

    test('El número para "Pregúntale" sale igual que antes en los datos de ejemplo', () {
      expect(Interprete.numero('Pasaporte. República de Colombia. Número AB1234567'), 'AB1234567');
      expect(
        Interprete.numero('República de Colombia. Cédula de ciudadanía. Número 52.348.910'),
        '52.348.910',
      );
      expect(Interprete.numero('Registro Único Tributario. NIT 52348910-1'), '52348910-1');
      expect(Interprete.numero('Factura de energía. Referencia de pago 998877'), '998877');
    });
  });

  group('Leer documentos', () {
    test('Lee cada foto, junta el texto por páginas y entiende el documento', () async {
      final lector = LectorSimulado(textos: [cedulaFrente, cedulaReverso]);
      final avance = <(int, int)>[];
      final l = await LecturaDeDocumentos(lector: lector)
          .leer(fotos: [fotoPrueba, fotoPrueba], alAvanzar: (a, b) => avance.add((a, b)));
      expect(lector.leidas, 2);
      expect(avance, [(0, 2), (1, 2)]);
      expect(l.texto.split(separadorDePaginas), hasLength(2));
      expect(l.datos.nombre, 'Cédula de ciudadanía');
      expect(l.datos.numero, '52.348.910');
    });

    test('Un PDF se lee dibujando sus páginas de a pocas, hasta el máximo', () async {
      final pedidas = <(int, int)>[];
      final lectura = LecturaDeDocumentos(
        lector: LectorSimulado(textos: [soat]),
        maximoPaginas: 6,
        contarPdf: (_) async => 9,
        dibujarPdf: (_, desde, hasta) async {
          pedidas.add((desde, hasta));
          return [for (var i = desde; i < hasta; i++) fotoPrueba];
        },
      );
      final l = await lectura.leer(pdf: fotoPrueba);
      expect(pedidas, [(0, 4), (4, 6)]);
      expect(l.paginas, hasLength(6));
      expect(l.datos.nombre, 'SOAT · ABC123');
    });

    test('Un PDF con contraseña queda sin texto; si el celular no dibuja PDF, no se puede leer', () async {
      LecturaDeDocumentos con(ProblemaPdf problema) => LecturaDeDocumentos(
        lector: LectorSimulado(textos: [soat]),
        contarPdf: (_) async => throw ErrorPdf(problema),
      );
      expect((await con(ProblemaPdf.conClave).leer(pdf: fotoPrueba)).conTexto, isFalse);
      await expectLater(
        con(ProblemaPdf.noDisponible).leer(pdf: fotoPrueba),
        throwsA(isA<LecturaNoDisponible>()),
      );
    });

    test('Sin lector (navegador, iPhone por ahora) se avisa', () async {
      final lectura = LecturaDeDocumentos(lector: const LectorNoDisponible());
      expect(lectura.disponible, isFalse);
      await expectLater(lectura.leer(fotos: [fotoPrueba]), throwsA(isA<LecturaNoDisponible>()));
    });
  });

  group('Leer lo que ya estaba guardado', () {
    Future<String> guardarSinTexto(MemoriaCajonRepositorio repo, String nombre) => repo.guardarDocumento(
      NuevoDocumento(perfilId: Perfil.idPropio, nombre: nombre, categoria: Categoria.otro),
      paginas: [fotoPrueba],
    );

    Future<Documento> doc(MemoriaCajonRepositorio repo, String id) async =>
        (await repo.vigilarDocumento(id).first)!;

    test('Lee los documentos sin texto una sola vez, y otra vez si cambian sus páginas', () async {
      final repo = MemoriaCajonRepositorio(ejemplo: false);
      final id = await guardarSinTexto(repo, 'Mi licencia');
      final lector = LectorSimulado(textos: [licencia]);
      final cajon = LectorDelCajon(
        repo: repo,
        lectura: LecturaDeDocumentos(lector: lector),
        espera: const Duration(days: 1),
      );
      addTearDown(cajon.dispose);

      await cajon.leerPendientes();
      expect((await doc(repo, id)).textoExtraido, contains('52348910'));
      expect(await repo.buscar('52348910'), hasLength(1));
      expect(lector.leidas, 1);

      // Ya leído: no se vuelve a leer.
      await cajon.leerPendientes();
      expect(lector.leidas, 1);

      // Páginas nuevas (sin texto todavía): se leen de nuevo.
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final d = await doc(repo, id);
      await repo.actualizarDocumento(
        id,
        NuevoDocumento(perfilId: d.perfilId, nombre: d.nombre, categoria: d.categoria),
        paginas: [fotoPrueba],
      );
      expect((await doc(repo, id)).textoExtraido, isEmpty);
      await cajon.leerPendientes();
      expect(lector.leidas, 2);
      expect((await doc(repo, id)).textoExtraido, isNotEmpty);
    });

    test('Una foto sin letras se intenta una vez y no se insiste', () async {
      final repo = MemoriaCajonRepositorio(ejemplo: false);
      final id = await guardarSinTexto(repo, 'Foto del perro');
      final lector = LectorSimulado(textos: ['']);
      final cajon = LectorDelCajon(
        repo: repo,
        lectura: LecturaDeDocumentos(lector: lector),
        espera: const Duration(days: 1),
      );
      addTearDown(cajon.dispose);
      await cajon.leerPendientes();
      await cajon.leerPendientes();
      expect(lector.leidas, 1);
      expect((await doc(repo, id)).textoExtraido, isEmpty);
    });
  });

  group('Guardar con la lectura', () {
    setUpAll(() {
      for (final canal in [
        'flutter.baseflow.com/permissions/methods',
        'tu_cajon/pdf',
        'tu_cajon/recibir',
        'dexterous.com/flutter/local_notifications',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(canal),
          (_) async => throw MissingPluginException(),
        );
      }
    });

    Future<MemoriaCajonRepositorio> abrirGuardar(
      WidgetTester tester,
      LectorSimulado lector, {
      int fotos = 2,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MemoriaCajonRepositorio();
      await tester.pumpWidget(
        TuCajonApp(
          repo: repo,
          llave: LlaveSimulada(),
          recordatorios: RecordatoriosSimulados(),
          lectorDeTexto: lector,
          rutaInicial: AppRoutes.guardar,
          argumentos: FotosDeGaleria([for (var i = 0; i < fotos; i++) fotoPrueba]),
        ),
      );
      return repo;
    }

    String nombreEscrito(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('Llena el nombre y el tipo, lo marca, y guarda el texto para buscarlo', (tester) async {
      final repo = await abrirGuardar(
        tester,
        LectorSimulado(textos: [cedulaFrente, cedulaReverso], demora: const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.text('Leyendo tu documento…'), findsOneWidget);
      expect(find.textContaining('Página 1 de 2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('La IA leyó tu documento'), findsOneWidget);
      expect(find.textContaining('Llenó el nombre y el tipo'), findsOneWidget);
      expect(nombreEscrito(tester), 'Cédula de ciudadanía');
      // Junto al nombre y junto al tipo (este, más abajo de lo que se ve).
      expect(find.text('Lo leyó la IA', skipOffstage: false), findsNWidgets(2));

      await tester.tap(find.text('Guardar en mi cajón'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // El nuevo (los de ejemplo de Marta no tienen id "doc-…").
      final guardado = (await repo.vigilarTodos().first).singleWhere((d) => d.id.startsWith('doc-'));
      expect(guardado.nombre, 'Cédula de ciudadanía');
      expect(guardado.categoria, Categoria.identidad);
      expect(guardado.textoExtraido, contains('FECHA DE NACIMIENTO'));

      // El detalle muestra lo que dice, con el número listo para copiar.
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(find.text('Ver todo el texto'), 200);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump();
      expect(find.text('Lo que dice el documento'), findsOneWidget);
      expect(find.text('52.348.910'), findsOneWidget);
      await tester.tap(find.text('Ver todo el texto'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Copiar todo el texto'), findsOneWidget);
      expect(find.textContaining('MARTA LUCIA'), findsOneWidget);
      expect(find.text('Página 2', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('FECHA DE NACIMIENTO', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Llena la fecha de vencimiento y no pisa lo que la persona ya escribió', (tester) async {
      await abrirGuardar(
        tester,
        LectorSimulado(textos: [licencia], demora: const Duration(seconds: 1)),
        fotos: 1,
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Mi pase');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(nombreEscrito(tester), 'Mi pase');
      expect(find.textContaining('Llenó el tipo y la fecha de vencimiento'), findsOneWidget);
      // La lista (el campo de texto también tiene su propio desplazamiento).
      await tester.scrollUntilVisible(
        find.text('Fecha de vencimiento'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('5 de junio de 2028'), findsOneWidget);
      expect(find.text('Lo leyó la IA', skipOffstage: false), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Si se guarda antes de que termine, el texto llega después', (tester) async {
      final repo = await abrirGuardar(
        tester,
        LectorSimulado(textos: [soat], demora: const Duration(seconds: 3)),
        fotos: 1,
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Seguro del carro');
      await tester.pump();
      await tester.tap(find.text('Guardar en mi cajón'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final guardado = (await repo.vigilarTodos().first).firstWhere((d) => d.nombre == 'Seguro del carro');
      expect(guardado.textoExtraido, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      final despues = (await repo.vigilarDocumento(guardado.id).first)!;
      expect(despues.textoExtraido, contains('ABC123'));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('Sin letras en la foto, se dice y se puede guardar igual', (tester) async {
      await abrirGuardar(tester, LectorSimulado(textos: ['']), fotos: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No encontramos letras'), findsOneWidget);
      expect(nombreEscrito(tester), isEmpty);
    });
  });
}
