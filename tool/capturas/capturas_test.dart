// Saca capturas de las pantallas con los datos de ejemplo (Marta y Mamá)
// para el folleto o la ficha de la tienda. No corre con `flutter test`
// normal; se corre a mano:
//
//   flutter test tool/capturas/capturas_test.dart
//
// Deja los PNG (1170×2532, celular de 390×844 a 3x) en build/capturas/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/app.dart';
import 'package:tu_cajon/core/router/app_routes.dart';
import 'package:tu_cajon/core/seguridad/llave_celular.dart';
import 'package:tu_cajon/data/datos_ejemplo.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';
import 'package:tu_cajon/features/cajon/cajon_shell.dart';
import 'package:tu_cajon/features/guardar/guardar_screen.dart';

const _carpeta = 'build/capturas';
final _marco = GlobalKey();

Future<void> _cargarLetras() async {
  final letras = FontLoader('PlusJakartaSans');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$peso.ttf').readAsBytesSync();
    letras.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await letras.load();
}

/// Abre [ruta] en un celular de 390×844 con barra de estado (40) y barra de
/// gestos (20), como se ve en un teléfono real.
Future<void> _abrir(WidgetTester tester, String ruta, {Object? args}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
  tester.view.viewPadding = const FakeViewPadding(top: 120, bottom: 60);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _marco,
      child: TuCajonApp(
        key: UniqueKey(),
        repo: MemoriaCajonRepositorio(),
        llave: LlaveSimulada(),
        rutaInicial: ruta,
        argumentos: args,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  await tester.pump();
  final limite = _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final imagen = await limite.toImage(pixelRatio: 3);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    await File('$_carpeta/$nombre.png').writeAsBytes(datos!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _cargarLetras();
    Directory(_carpeta).createSync(recursive: true);
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

  final pantallas = <String, (String, Object?, Duration)>{
    'carga': (AppRoutes.carga, null, const Duration(seconds: 2)),
    'desbloqueo': (AppRoutes.desbloqueo, null, Duration.zero),
    'proteccion': (AppRoutes.proteccion, null, Duration.zero),
    'inicio': (AppRoutes.cajon, CajonTab.inicio, Duration.zero),
    'detalle': (AppRoutes.detalle, 'licencia', Duration.zero),
    'detalle_cedula': (AppRoutes.detalle, 'cedula', Duration.zero),
    'agregar': (AppRoutes.agregar, null, Duration.zero),
    'guardar': (AppRoutes.guardar, 2, Duration.zero),
    'preguntar': (AppRoutes.preguntar, null, Duration.zero),
    'perfil': (AppRoutes.nuevoPerfil, null, Duration.zero),
    'ajustes': (AppRoutes.ajustes, null, Duration.zero),
  };

  for (final MapEntry(key: nombre, value: (ruta, args, espera)) in pantallas.entries) {
    testWidgets('Captura: $nombre', (tester) async {
      await _abrir(tester, ruta, args: args);
      await tester.pump(espera);
      await _capturar(tester, nombre);
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('Captura: avisos (con las notificaciones ya activadas)', (tester) async {
    // permission_handler: 1 = permitido.
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const permisos = MethodChannel('flutter.baseflow.com/permissions/methods');
    mensajero.setMockMethodCallHandler(permisos, (llamada) async {
      if (llamada.method == 'checkPermissionStatus') return 1;
      throw MissingPluginException();
    });
    addTearDown(
      () => mensajero.setMockMethodCallHandler(permisos, (_) async => throw MissingPluginException()),
    );
    await _abrir(tester, AppRoutes.cajon, args: CajonTab.avisos);
    await _capturar(tester, 'avisos');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Captura: escanear (con el frente ya tomado)', (tester) async {
    await _abrir(tester, AppRoutes.escanear);
    await tester.tap(find.bySemanticsLabel('Tomar foto'));
    // Cuadro a cuadro, para que el destello y la miniatura terminen.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _capturar(tester, 'escanear');
    await tester.pump(const Duration(seconds: 5));
  });

  Future<void> cuadros(WidgetTester tester, {int veces = 20}) async {
    for (var i = 0; i < veces; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Captura: IA · Pregúntale a tu cajón con respuestas', (tester) async {
    await _abrir(tester, AppRoutes.preguntar);
    await tester.tap(find.text('¿Cuál es mi número de pasaporte?'));
    await cuadros(tester);
    // Los ejemplos se van después de la primera pregunta: la segunda se escribe.
    await tester.enterText(find.byType(TextField), '¿Cuándo vence mi licencia?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    FocusManager.instance.primaryFocus?.unfocus();
    await cuadros(tester);
    await _capturar(tester, 'ia_preguntar');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Captura: IA · Sugerencias en Avisos', (tester) async {
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const permisos = MethodChannel('flutter.baseflow.com/permissions/methods');
    mensajero.setMockMethodCallHandler(permisos, (llamada) async {
      if (llamada.method == 'checkPermissionStatus') return 1;
      throw MissingPluginException();
    });
    addTearDown(
      () => mensajero.setMockMethodCallHandler(permisos, (_) async => throw MissingPluginException()),
    );
    await _abrir(tester, AppRoutes.cajon, args: CajonTab.avisos);
    await tester.drag(find.text('Por vencer'), const Offset(0, -318));
    await cuadros(tester);
    await _capturar(tester, 'ia_sugerencias');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Captura: IA · Guardar con los datos llenos', (tester) async {
    final cedula = DatosEjemplo.documentos(DateTime.now()).firstWhere((d) => d.id == 'licencia');
    await _abrir(tester, AppRoutes.guardar, args: EditarDatos(cedula));
    await cuadros(tester);
    await _capturar(tester, 'ia_guardar');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Captura: buscar', (tester) async {
    await _abrir(tester, AppRoutes.cajon, args: CajonTab.inicio);
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, 'cedula');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await _capturar(tester, 'buscar');
    await tester.pump(const Duration(seconds: 5));
  });
}
