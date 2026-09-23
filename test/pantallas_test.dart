import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tu_cajon/app.dart';
import 'package:tu_cajon/core/router/app_routes.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';
import 'package:tu_cajon/features/cajon/cajon_shell.dart';
import 'package:tu_cajon/shared/widgets/buttons.dart';

/// Abre una ruta en un teléfono de 390×844 (el tamaño del diseño).
Future<void> abrir(WidgetTester tester, String ruta, {Object? args}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Las pantallas se prueban con datos en memoria; la base SQLite real se
  // prueba aparte en base_datos_test.dart.
  await tester.pumpWidget(
    TuCajonApp(key: UniqueKey(), repo: MemoriaCajonRepositorio(), rutaInicial: ruta, argumentos: args),
  );
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // En las pruebas no hay cámara ni permisos reales: el canal de permisos
    // responde "no implementado" y Escanear pasa a su modo simulado.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => throw MissingPluginException(),
    );
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
    });
  }

  testWidgets('Flujo de entrada: carga → nombre → llave → mi cajón', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TuCajonApp(repo: MemoriaCajonRepositorio()));
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
    expect(find.text('Toca el sensor de huella'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
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
    await tester.pumpWidget(TuCajonApp(repo: MemoriaCajonRepositorio()));
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
    await tester.pumpWidget(TuCajonApp(repo: repo));
    await tester.pump(const Duration(seconds: 1));
    // Sin flecha, y tocar la pantalla no hace nada.
    expect(find.byType(ArrowButton), findsNothing);
    await tester.tapAt(const Offset(195, 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Tus papeles, siempre a la mano?'), findsOneWidget);
    // A los ~4,5 s pasa sola a "Abrir el cajón".
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hola de nuevo,'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.pumpWidget(TuCajonApp(repo: repo, rutaInicial: AppRoutes.guardar, argumentos: 3));
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

  testWidgets('Detalle abre y cierra el menú de compartir', (tester) async {
    await abrir(tester, AppRoutes.detalle);
    await tester.tap(find.text('Compartir de otra forma'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Imprimir'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Preparando para imprimir…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
