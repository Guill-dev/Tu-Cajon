import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/app.dart';
import 'package:image/image.dart' as img;
import 'package:tu_cajon/core/archivos/buzon.dart';
import 'package:tu_cajon/core/archivos/selector_archivos.dart';
import 'package:tu_cajon/core/compartir/compartidor.dart';
import 'package:tu_cajon/data/compartir/pdf_documento.dart';
import 'package:tu_cajon/core/router/app_routes.dart';
import 'package:tu_cajon/core/seguridad/llave_celular.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';
import 'package:tu_cajon/features/cajon/cajon_shell.dart';
import 'package:tu_cajon/shared/widgets/buttons.dart';

import 'foto_prueba.dart';

/// Deja correr trabajo real (abrir fotos, otro hilo) hasta que se cumpla
/// [listo], o falla a los ~10 s.
Future<void> esperarHasta(WidgetTester tester, bool Function() listo) async {
  for (var i = 0; i < 50 && !listo(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }
  expect(listo(), isTrue, reason: 'no terminó a tiempo');
}

/// Abre una ruta en un teléfono de 390×844 (el tamaño del diseño).
Future<void> abrir(WidgetTester tester, String ruta, {Object? args}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Las pantallas se prueban con datos en memoria; la base SQLite real se
  // prueba aparte en base_datos_test.dart.
  await tester.pumpWidget(
    TuCajonApp(
      key: UniqueKey(),
      repo: MemoriaCajonRepositorio(),
      llave: LlaveSimulada(),
      rutaInicial: ruta,
      argumentos: args,
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() {
    // En las pruebas no hay cámara ni permisos reales: el canal de permisos
    // responde "no implementado" y Escanear pasa a su modo simulado.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => throw MissingPluginException(),
    );
    // Tampoco hay lector de PDF nativo ni buzón de "Compartir": responden
    // "no implementado".
    for (final canal in ['tu_cajon/pdf', 'tu_cajon/recibir']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(canal),
        (_) async => throw MissingPluginException(),
      );
    }
  });

  final rutas = <String, (String, Object?)>{
    'Carga': (AppRoutes.carga, null),
    'Bienvenida': (AppRoutes.bienvenida, null),
    'Protección': (AppRoutes.proteccion, null),
    'Desbloqueo': (AppRoutes.desbloqueo, null),
    'Mi cajón': (AppRoutes.cajon, CajonTab.inicio),
    'Avisos': (AppRoutes.cajon, CajonTab.avisos),
    'Detalle': (AppRoutes.detalle, null),
    'Agregar': (AppRoutes.agregar, null),
    'Escanear': (AppRoutes.escanear, null),
    'Guardar': (AppRoutes.guardar, null),
    'Preguntar': (AppRoutes.preguntar, null),
    'Nuevo perfil': (AppRoutes.nuevoPerfil, null),
    'Catálogo': (AppRoutes.catalogo, null),
  };

  for (final MapEntry(key: nombre, value: (ruta, args)) in rutas.entries) {
    testWidgets('La pantalla "$nombre" se dibuja sin errores', (tester) async {
      await abrir(tester, ruta, args: args);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5)); // termina animaciones y la llave simulada
    });
  }

  testWidgets('Flujo de entrada: carga → nombre → llave → mi cajón', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TuCajonApp(repo: MemoriaCajonRepositorio(), llave: LlaveSimulada()));
    await tester.pump(const Duration(seconds: 2));

    // Toda la pantalla de carga es tocable.
    await tester.tapAt(const Offset(195, 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Escribe tu nombre para seguir'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump();
    expect(find.textContaining('¡Mucho gusto, Ana!'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Activar la llave'));
    await tester.pump();
    await tester.tap(find.text('Activar la llave'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Usa tu huella, rostro o PIN'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('¡Listo! Tu cajón quedó protegido'), findsOneWidget);

    await tester.ensureVisible(find.text('Abrir mi cajón'));
    await tester.pump();
    await tester.tap(find.text('Abrir mi cajón'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hola,'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('8 documentos en tu cajón'), findsOneWidget);

    // Buscar (sin tildes también encuentra).
    await tester.enterText(find.byType(TextField), 'licencia de conduccion');
    await tester.pump(const Duration(milliseconds: 300));
    final paginaVertical = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Licencia de conducción'),
      200,
      scrollable: paginaVertical.first,
    );
    expect(find.text('Licencia de conducción'), findsOneWidget);
    expect(find.text('RUT'), findsNothing);
    expect(find.text('1 documento'), findsOneWidget);

    // Cambiar al perfil de Mamá.
    await tester.scrollUntilVisible(find.text('Mamá'), -200, scrollable: paginaVertical.first);
    await tester.tap(find.text('Mamá'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(paginaVertical.first, const Offset(0, 3000)); // volver arriba
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('El cajón de'), findsOneWidget);

    // Pestaña Avisos y descartar las tres sugerencias.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Avisos')).first);
    await tester.pump(const Duration(milliseconds: 300));
    // Ejemplo: renovar la licencia, 2 certificados viejos y "agregar bancario".
    for (final boton in ['Ya lo hice', 'Descartar', 'Descartar', 'Ahora no']) {
      await tester.scrollUntilVisible(find.text(boton).first, 150, scrollable: find.byType(Scrollable).last);
      await tester.pump();
      await tester.tap(find.text(boton).first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.scrollUntilVisible(
      find.text('Estás al día. Te contamos cuando haya algo nuevo.'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Estás al día. Te contamos cuando haya algo nuevo.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Carga: sin registro muestra la flecha y espera al usuario', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TuCajonApp(repo: MemoriaCajonRepositorio(), llave: LlaveSimulada()));
    await tester.pump(const Duration(seconds: 6)); // más que la carga
    expect(find.byType(ArrowButton), findsOneWidget);
    expect(find.text('¿Tus papeles, siempre a la mano?'), findsOneWidget); // no avanzó sola
  });

  testWidgets('Carga: ya registrado es solo carga y avanza sola', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MemoriaCajonRepositorio();
    await repo.activarLlave();
    final llave = LlaveSimulada();
    await tester.pumpWidget(TuCajonApp(repo: repo, llave: llave));
    await tester.pump(const Duration(seconds: 1));
    // Sin flecha, y tocar la pantalla no hace nada.
    expect(find.byType(ArrowButton), findsNothing);
    await tester.tapAt(const Offset(195, 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Tus papeles, siempre a la mano?'), findsOneWidget);
    // A los ~4,5 s pasa sola a "Abrir el cajón"...
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hola de nuevo,'), findsOneWidget);
    // ...que pide de una vez la llave del celular y, al confirmarla, celebra
    // (1,1 s) y abre.
    expect(llave.intentos, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CajonShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desbloqueo: si se cancela la llave, se queda cerrado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final llave = LlaveSimulada(resultado: ResultadoLlave.cancelado);
    await tester.pumpWidget(
      TuCajonApp(repo: MemoriaCajonRepositorio(), llave: llave, rutaInicial: AppRoutes.desbloqueo),
    );
    // Animación (0,9 s) + diálogo simulado (1,2 s).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Hola de nuevo,'), findsOneWidget);
    expect(find.byType(CajonShell), findsNothing);

    // "Usar el PIN del celular" vuelve a pedir la llave.
    await tester.tap(find.text('Usar el PIN del celular'));
    await tester.pump(const Duration(seconds: 3));
    expect(llave.intentos, 2);
    expect(find.text('Hola de nuevo,'), findsOneWidget);
  });

  testWidgets('Desbloqueo: sin bloqueo de pantalla avisa qué hacer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TuCajonApp(
        repo: MemoriaCajonRepositorio(),
        llave: LlaveSimulada(resultado: ResultadoLlave.sinBloqueo),
        rutaInicial: AppRoutes.desbloqueo,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('no tiene bloqueo de pantalla'), findsOneWidget);
    expect(find.text('Hola de nuevo,'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // el aviso se va solo
  });

  testWidgets('Protección: si se cancela, no se activa la llave', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MemoriaCajonRepositorio();
    await tester.pumpWidget(
      TuCajonApp(
        repo: repo,
        llave: LlaveSimulada(resultado: ResultadoLlave.cancelado),
        rutaInicial: AppRoutes.proteccion,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Activar la llave'));
    await tester.pump();
    await tester.tap(find.text('Activar la llave'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¡Listo! Tu cajón quedó protegido'), findsNothing);
    expect(await repo.llaveActivada(), isFalse);
  });

  /// Simula que la persona se va a otra app (o apaga la pantalla).
  void salirDeLaApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void volverALaApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('Al volver de otra app se pide la llave y se sigue donde estaba', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final llave = LlaveSimulada();
    await tester.pumpWidget(
      TuCajonApp(repo: MemoriaCajonRepositorio(), llave: llave, rutaInicial: AppRoutes.desbloqueo),
    );
    // Animación + llave + celebración: entra a "Mi cajón".
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CajonShell), findsOneWidget);

    // Abre "Preguntar" y se va a otra app.
    final preguntar = find.bySemanticsLabel('Pregúntale a tu cajón').first;
    await tester.ensureVisible(preguntar);
    await tester.pump();
    await tester.tap(preguntar);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Cuándo vence mi licencia?'), findsOneWidget);
    salirDeLaApp(tester);
    await tester.pump();

    // Mientras no vuelva, no se pide la llave.
    await tester.pump(const Duration(seconds: 3));
    expect(llave.intentos, 1);

    // Vuelve: lo primero que se ve es el cajón cerrado, y "atrás" no lo salta.
    volverALaApp(tester);
    await tester.pump();
    expect(find.text('Hola de nuevo,'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hola de nuevo,'), findsOneWidget);

    // Se pide la llave y queda otra vez en "Preguntar".
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(llave.intentos, 2);
    expect(find.text('Hola de nuevo,'), findsNothing);
    expect(find.text('¿Cuándo vence mi licencia?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Antes de entrar al cajón, salir de la app no pone la llave', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TuCajonApp(repo: MemoriaCajonRepositorio(), llave: LlaveSimulada(), rutaInicial: AppRoutes.bienvenida),
    );
    await tester.pump(const Duration(seconds: 1));
    salirDeLaApp(tester);
    volverALaApp(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hola de nuevo,'), findsNothing);
    expect(find.text('Escribe tu nombre para seguir'), findsOneWidget);
  });

  testWidgets('Preguntar responde y Escanear cuenta páginas', (tester) async {
    await abrir(tester, AppRoutes.preguntar);
    await tester.tap(find.text('¿Cuándo vence mi licencia?'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('faltan 18 días'), findsOneWidget);

    await abrir(tester, AppRoutes.escanear);
    expect(find.text('Aún no hay páginas'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tomar foto'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel('Tomar foto'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 páginas'), findsOneWidget);
    expect(find.text('Página 3'), findsOneWidget);
  });

  testWidgets('Guardar crea el documento y abre su detalle', (tester) async {
    final repo = MemoriaCajonRepositorio();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TuCajonApp(repo: repo, llave: LlaveSimulada(), rutaInicial: AppRoutes.guardar, argumentos: 3),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'Certificado bancario');
    await tester.pump();
    await tester.tap(find.text('Guardar en mi cajón'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final docs = await repo.buscar('bancario');
    expect(docs.single.paginas, 3);
    // Título en dos tonos del detalle: "Certificado / bancario".
    expect(find.text('Certificado'), findsOneWidget);
    expect(find.text('bancario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escanear no tiene límite de páginas y cambia de formato', (tester) async {
    await abrir(tester, AppRoutes.escanear);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.bySemanticsLabel('Tomar foto'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('8 páginas'), findsOneWidget);
    expect(find.text('Página 9'), findsOneWidget);

    await tester.tap(find.text('Hoja'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Toca una miniatura para revisarla, toma otra página o toca Terminar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Subir un archivo', () {
    Future<void> abrirAgregar(
      WidgetTester tester, {
      required MemoriaCajonRepositorio repo,
      required SelectorSimulado selector,
      CompartidorSimulado? compartidor,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TuCajonApp(
          repo: repo,
          llave: LlaveSimulada(),
          compartidor: compartidor ?? CompartidorSimulado(),
          selector: selector,
          rutaInicial: AppRoutes.agregar,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tocar(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('Subir un PDF: se guarda tal cual y se envía tal cual', (tester) async {
      final pdf = await armarPdf([fotoPrueba], titulo: 'Certificado');
      final repo = MemoriaCajonRepositorio();
      final compartidor = CompartidorSimulado();
      await abrirAgregar(
        tester,
        repo: repo,
        compartidor: compartidor,
        selector: SelectorSimulado(
          pdf: PdfElegido(nombre: 'Certificado_EPS_2026.pdf', bytes: pdf),
        ),
      );

      await tocar(tester, find.text('Subir un PDF'));
      // Guardar propone el nombre del archivo, ya legible.
      expect(find.text('Usamos el nombre del archivo'), findsOneWidget);
      expect(find.text('Certificado EPS 2026'), findsOneWidget);
      expect(find.text('Certificado_EPS_2026.pdf'), findsOneWidget);

      await tocar(tester, find.text('Guardar en mi cajón'));
      await tester.pump(const Duration(seconds: 1));
      // (Los datos de ejemplo ya tienen otro certificado de la EPS.)
      final doc = (await repo.buscar('EPS 2026')).firstWhere((d) => d.nombre == 'Certificado EPS 2026');
      expect(await repo.leerPdf(doc), pdf);
      expect(await repo.leerPaginas(doc), isEmpty);

      // En el detalle (sin lector de PDF en las pruebas) se avisa, y al
      // enviarlo va el mismo PDF, sin rehacerlo.
      expect(find.textContaining('vista previa del PDF no está disponible'), findsOneWidget);
      await tocar(tester, find.text('Enviar por WhatsApp'));
      expect(compartidor.pdfsEnviados.single, pdf);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Un archivo que no es PDF no se acepta', (tester) async {
      await abrirAgregar(
        tester,
        repo: MemoriaCajonRepositorio(),
        selector: SelectorSimulado(
          pdf: PdfElegido(nombre: 'foto.pdf', bytes: fotoPrueba),
        ),
      );
      await tocar(tester, find.text('Subir un PDF'));
      expect(find.textContaining('no es un PDF'), findsOneWidget);
      expect(find.text('Guardar documento'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Fotos de la galería: se revisan, se mejoran todas y se guardan', (tester) async {
      Uint8List jpeg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));
      final repo = MemoriaCajonRepositorio();
      await abrirAgregar(
        tester,
        repo: repo,
        selector: SelectorSimulado(fotos: [jpeg(300, 400), jpeg(400, 300)]),
      );

      await tocar(tester, find.text('Fotos de la galería'));
      expect(find.textContaining('Toca una página para recortarla'), findsOneWidget);
      // Se preparan de verdad (se abren y se achican en otro hilo).
      await esperarHasta(tester, () => find.text('Continuar con 2 páginas').evaluate().isNotEmpty);
      expect(find.text('Página 1'), findsOneWidget);
      expect(find.text('Página 2'), findsOneWidget);

      // "Mejorar todas" con Documento.
      await tocar(tester, find.text('Documento'));
      await esperarHasta(tester, () => find.text('Filtro Documento').evaluate().length == 2);

      await tocar(tester, find.text('Continuar con 2 páginas'));
      expect(find.text('Ponle un nombre'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Recibo de luz');
      await tester.pump();
      await tocar(tester, find.text('Guardar en mi cajón'));
      await tester.pump(const Duration(seconds: 1));

      final doc = (await repo.buscar('Recibo de luz')).firstWhere((d) => d.nombre == 'Recibo de luz');
      expect(await repo.leerPaginas(doc), hasLength(2));
      expect(doc.paginas, 2);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Enviar como PDF', () {
    /// Guarda un documento con 2 fotos y abre su detalle.
    Future<void> abrirDetalleConFotos(WidgetTester tester, CompartidorSimulado compartidor) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MemoriaCajonRepositorio();
      final id = await repo.guardarDocumento(
        const NuevoDocumento(
          perfilId: Perfil.idPropio,
          nombre: 'Certificado laboral',
          categoria: Categoria.estudios,
          paginas: 2,
        ),
        paginas: [fotoPrueba, fotoPrueba],
      );
      await tester.pumpWidget(
        TuCajonApp(
          repo: repo,
          llave: LlaveSimulada(),
          compartidor: compartidor,
          rutaInicial: AppRoutes.detalle,
          argumentos: id,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('"Enviar por WhatsApp" arma el PDF con todas las fotos', (tester) async {
      final compartidor = CompartidorSimulado();
      await abrirDetalleConFotos(tester, compartidor);
      await tester.tap(find.text('Enviar por WhatsApp'));
      await tester.pump();
      expect(find.text('Preparando el PDF…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(compartidor.envios, [('Certificado_laboral.pdf', 2, true)]);
      expect(find.text('Enviar por WhatsApp'), findsOneWidget); // el botón vuelve a estar listo
    });

    testWidgets('"Compartir de otra forma" abre el menú del celular', (tester) async {
      final compartidor = CompartidorSimulado();
      await abrirDetalleConFotos(tester, compartidor);
      await tester.tap(find.text('Compartir de otra forma'));
      await tester.pump(const Duration(seconds: 1));
      expect(compartidor.envios, [('Certificado_laboral.pdf', 2, false)]);
    });

    testWidgets('Sin WhatsApp avisa y ofrece otra app', (tester) async {
      final compartidor = CompartidorSimulado(resultado: ResultadoCompartir.sinWhatsApp);
      await abrirDetalleConFotos(tester, compartidor);
      await tester.tap(find.text('Enviar por WhatsApp'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('No encontramos WhatsApp'), findsOneWidget);
      expect(compartidor.envios.map((e) => e.$3), [true, false]);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Un documento sin fotos no se envía', (tester) async {
      final compartidor = CompartidorSimulado();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Sin id: el detalle muestra el documento de ejemplo más reciente (sin foto).
      await tester.pumpWidget(
        TuCajonApp(
          repo: MemoriaCajonRepositorio(),
          llave: LlaveSimulada(),
          compartidor: compartidor,
          rutaInicial: AppRoutes.detalle,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Enviar por WhatsApp'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('no tiene fotos para enviar'), findsOneWidget);
      expect(compartidor.envios, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Ir a WhatsApp no cierra el cajón si se vuelve pronto', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var ahora = DateTime(2026, 9, 23, 10);
      final repo = MemoriaCajonRepositorio();
      await repo.guardarDocumento(
        const NuevoDocumento(
          perfilId: Perfil.idPropio,
          nombre: 'Certificado laboral',
          categoria: Categoria.estudios,
        ),
        paginas: [fotoPrueba],
      );
      final compartidor = CompartidorSimulado();
      await tester.pumpWidget(
        TuCajonApp(
          repo: repo,
          llave: LlaveSimulada(),
          compartidor: compartidor,
          reloj: () => ahora,
          rutaInicial: AppRoutes.desbloqueo,
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CajonShell), findsOneWidget);

      // Desde "Mi cajón", el botón verde de la tarjeta.
      final boton = find.bySemanticsLabel('Enviar Certificado laboral por WhatsApp');
      await tester.ensureVisible(boton);
      await tester.pump();
      await tester.tap(boton);
      await tester.pump(const Duration(seconds: 1));
      expect(compartidor.envios, [('Certificado_laboral.pdf', 1, true)]);

      // Va a WhatsApp y vuelve al minuto: sigue abierto.
      salirDeLaApp(tester);
      ahora = ahora.add(const Duration(minutes: 1));
      volverALaApp(tester);
      await tester.pump();
      expect(find.text('Hola de nuevo,'), findsNothing);
      expect(compartidor.limpiezas, 1); // solo la de cuando abrió la app

      // Otra vez, pero vuelve a los 3 minutos: se cierra y borra el PDF.
      await tester.pump(const Duration(seconds: 3)); // se va el aviso
      await tester.tap(boton);
      await tester.pump(const Duration(seconds: 1));
      salirDeLaApp(tester);
      ahora = ahora.add(const Duration(minutes: 3));
      volverALaApp(tester);
      await tester.pump();
      expect(find.text('Hola de nuevo,'), findsOneWidget);
      expect(compartidor.limpiezas, 2);

      // Una salida normal (sin compartir) sigue cerrando el cajón al momento.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hola de nuevo,'), findsNothing);
      salirDeLaApp(tester);
      volverALaApp(tester);
      await tester.pump();
      expect(find.text('Hola de nuevo,'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Recibir desde otra app (Compartir → Tu Cajón)', () {
    Future<void> abrirConBuzon(
      WidgetTester tester, {
      required MemoriaCajonRepositorio repo,
      required BuzonSimulado buzon,
      String ruta = AppRoutes.cajon,
      LlaveSimulada? llave,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        TuCajonApp(
          repo: repo,
          llave: llave ?? LlaveSimulada(),
          buzon: buzon,
          compartidor: CompartidorSimulado(),
          selector: SelectorSimulado(),
          rutaInicial: ruta,
        ),
      );
    }

    /// Deja pasar varios cuadros (cambios de pantalla y fundidos).
    Future<void> avanzar(WidgetTester tester, [int veces = 5]) async {
      for (var i = 0; i < veces; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    Future<void> tocar(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Uint8List jpeg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

    testWidgets('Un PDF compartido va directo a Guardar: nombre, de quién es y qué tipo', (tester) async {
      final pdf = await armarPdf([fotoPrueba], titulo: 'Fórmula');
      final repo = MemoriaCajonRepositorio();
      final buzon = BuzonSimulado(
        Envio(
          archivos: [ArchivoRecibido(nombre: 'Formula_medica_sept.pdf', tipo: 'application/pdf', bytes: pdf)],
        ),
      );
      await abrirConBuzon(tester, repo: repo, buzon: buzon);
      await avanzar(tester);

      expect(find.text('Llegó a tu cajón'), findsOneWidget);
      expect(find.text('Formula medica sept'), findsOneWidget);
      expect(find.text('¿De quién es?'), findsOneWidget);
      expect(find.text('¿Qué tipo de documento es?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Fórmula médica');
      await tester.pump();
      await tocar(tester, find.text('Mamá'));
      await tocar(tester, find.text('Salud'));
      await tocar(tester, find.text('Guardar en mi cajón'));
      await tester.pump(const Duration(seconds: 1));

      final doc = (await repo.buscar('Fórmula médica')).firstWhere((d) => d.nombre == 'Fórmula médica');
      expect(doc.perfilId, 'mama');
      expect(doc.categoria, Categoria.salud);
      expect(await repo.leerPdf(doc), pdf);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Fotos compartidas van a Tus páginas para editarlas y guardarlas', (tester) async {
      final repo = MemoriaCajonRepositorio();
      final buzon = BuzonSimulado();
      await abrirConBuzon(tester, repo: repo, buzon: buzon);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CajonShell), findsOneWidget);

      // Llegan con la app abierta: dos fotos y una que pesaba demasiado.
      buzon.recibir(
        Envio(
          archivos: [
            ArchivoRecibido(nombre: 'IMG-WA0001.jpg', tipo: 'image/jpeg', bytes: jpeg(300, 400)),
            ArchivoRecibido(nombre: 'IMG-WA0002.jpg', tipo: 'image/jpeg', bytes: jpeg(400, 300)),
            const ArchivoRecibido(
              nombre: 'grande.jpg',
              tipo: 'image/jpeg',
              problema: ProblemaRecibido.muyGrande,
            ),
          ],
        ),
      );
      await avanzar(tester, 3);
      expect(find.textContaining('Toca una página para recortarla'), findsOneWidget);
      expect(find.text('Una foto no se pudo recibir.'), findsWidgets);
      await esperarHasta(tester, () => find.text('Continuar con 2 páginas').evaluate().isNotEmpty);

      await tocar(tester, find.text('Continuar con 2 páginas'));
      await tester.enterText(find.byType(TextField), 'Recibo del agua');
      await tester.pump();
      await tocar(tester, find.text('Guardar en mi cajón'));
      await tester.pump(const Duration(seconds: 1));

      final doc = (await repo.buscar('Recibo del agua')).firstWhere((d) => d.nombre == 'Recibo del agua');
      expect(await repo.leerPaginas(doc), hasLength(2));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Si llega con el cajón cerrado, primero se pide la llave', (tester) async {
      final pdf = await armarPdf([fotoPrueba], titulo: 'Factura');
      final buzon = BuzonSimulado();
      final llave = LlaveSimulada();
      await abrirConBuzon(
        tester,
        repo: MemoriaCajonRepositorio(),
        buzon: buzon,
        llave: llave,
        ruta: AppRoutes.desbloqueo,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CajonShell), findsOneWidget);

      // Se va a WhatsApp y desde ahí comparte un PDF con Tu Cajón.
      salirDeLaApp(tester);
      await tester.pump();
      buzon.recibir(
        Envio(
          archivos: [ArchivoRecibido(nombre: 'Factura.pdf', tipo: 'application/pdf', bytes: pdf)],
        ),
      );
      await tester.pump();
      volverALaApp(tester);
      await tester.pump();

      // Lo primero es la llave; el documento no se ve todavía.
      expect(find.text('Hola de nuevo,'), findsOneWidget);
      expect(find.text('Llegó a tu cajón'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      await avanzar(tester);
      expect(llave.intentos, 2);
      expect(find.text('Hola de nuevo,'), findsNothing);
      expect(find.text('Llegó a tu cajón'), findsOneWidget);
      expect(find.text('Factura'), findsOneWidget);
    });

    testWidgets('Si la app se abre desde "Compartir", la carga es corta y sigue tras la llave', (
      tester,
    ) async {
      final pdf = await armarPdf([fotoPrueba], titulo: 'Certificado');
      final repo = MemoriaCajonRepositorio();
      await repo.activarLlave();
      final buzon = BuzonSimulado(
        Envio(
          archivos: [ArchivoRecibido(nombre: 'Certificado.pdf', tipo: 'application/pdf', bytes: pdf)],
        ),
      );
      await abrirConBuzon(tester, repo: repo, buzon: buzon, ruta: AppRoutes.carga);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Hola de nuevo,'), findsOneWidget);

      // Al abrir, "Mi cajón" no tapa lo que llegó: se abre Guardar encima.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      await avanzar(tester);
      expect(find.text('Llegó a tu cajón'), findsOneWidget);
      await tester.binding.handlePopRoute(); // botón "atrás" del celular
      await avanzar(tester, 2);
      expect(find.byType(CajonShell), findsOneWidget);
    });

    testWidgets('Un archivo que no sirve se explica y se vuelve al cajón', (tester) async {
      final buzon = BuzonSimulado(
        Envio(
          archivos: [ArchivoRecibido(nombre: 'factura.pdf', tipo: 'application/pdf', bytes: fotoPrueba)],
        ),
      );
      await abrirConBuzon(tester, repo: MemoriaCajonRepositorio(), buzon: buzon);
      await avanzar(tester);
      expect(find.text('No se pudo recibir'), findsOneWidget);
      expect(find.textContaining('no es un PDF'), findsOneWidget);
      await tocar(tester, find.text('Volver'));
      expect(find.byType(CajonShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
