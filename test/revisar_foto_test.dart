import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tu_cajon/features/escanear/bordes.dart';
import 'package:tu_cajon/features/escanear/filtros.dart';
import 'package:tu_cajon/features/escanear/pixeles.dart';
import 'package:tu_cajon/features/escanear/procesar_foto.dart';
import 'package:tu_cajon/features/escanear/revisar_foto.dart';

/// Una foto de 200×300 px.
final _foto = Uint8List.fromList(img.encodeJpg(img.Image(width: 200, height: 300)));

void main() {
  /// Abre la revisión desde un botón y guarda lo que devuelve.
  Future<List<RevisionFoto?>> abrirRevision(WidgetTester tester, {int total = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final resultados = <RevisionFoto?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => resultados.add(
              await Navigator.of(context).push<RevisionFoto>(
                MaterialPageRoute(
                  builder: (_) => RevisarFotoScreen(base: _foto, numero: 2, total: total),
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    // Mientras se decodifica la foto hay una ruedita girando: no se puede
    // esperar a que "todo se quede quieto".
    await tester.pump(const Duration(milliseconds: 400));
    await esperarDeVerdad(tester);
    await tester.pumpAndSettle();
    return resultados;
  }

  testWidgets('Muestra la foto y "Conservar" la devuelve igual', (tester) async {
    final resultados = await abrirRevision(tester);
    expect(find.text('Página 2'), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);
    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    final r = resultados.single;
    expect(r, isA<FotoConservada>());
    expect((r! as FotoConservada).foto, same(_foto));
  });

  testWidgets('"Eliminar" la descarta', (tester) async {
    final resultados = await abrirRevision(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(resultados.single, isA<FotoEliminada>());
  });

  testWidgets('La X vuelve sin cambios', (tester) async {
    final resultados = await abrirRevision(tester);
    await tester.tap(find.bySemanticsLabel('Volver sin cambios'));
    await tester.pumpAndSettle();
    expect(resultados.single, isNull);
  });

  testWidgets('Recortar: al arrastrar el borde derecho a la mitad, la foto queda la mitad de ancha', (
    tester,
  ) async {
    final resultados = await abrirRevision(tester);
    await tester.tap(find.text('Recortar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Arrastra las esquinas'), findsOneWidget);

    // La foto ocupa el área de la foto entera; se toma su rectángulo en pantalla.
    final foto = tester.getRect(find.byType(RawImage));
    await tester.dragFrom(foto.centerRight, Offset(-foto.width / 2, 0));
    await tester.pumpAndSettle();
    // Al mover el marco aparece "Restablecer".
    expect(find.bySemanticsLabel('Restablecer recorte'), findsOneWidget);

    // El visto verde aplica el recorte (se hace en otro hilo).
    await tester.tap(find.bySemanticsLabel('Recortar').last);
    await esperarDeVerdad(tester);
    expect(find.textContaining('Así quedó recortada'), findsOneWidget);

    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    final recortada = img.decodeJpg((resultados.single! as FotoConservada).foto)!;
    expect(recortada.width, closeTo(100, 3));
    expect(recortada.height, 300);
  });

  testWidgets('Cancelar el recorte deja la foto como estaba', (tester) async {
    final resultados = await abrirRevision(tester);
    await tester.tap(find.text('Recortar'));
    await tester.pumpAndSettle();
    final foto = tester.getRect(find.byType(RawImage));
    await tester.dragFrom(foto.bottomCenter, Offset(0, -foto.height / 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    expect((resultados.single! as FotoConservada).foto, same(_foto));
  });

  testWidgets('Filtro "Documento": se guarda con filtro y conserva la foto original', (tester) async {
    final resultados = await abrirRevision(tester);
    await tester.tap(find.text('Documento'));
    await esperarDeVerdad(tester);
    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    final r = resultados.single! as FotoConservada;
    expect(r.filtro, FiltroFoto.documento);
    expect(r.base, same(_foto)); // la original queda intacta para cambiar de filtro
    expect(r.foto, isNot(same(_foto)));
    expect(r.aTodas, isFalse);
  });

  testWidgets('Con varias páginas se puede usar el filtro en todas', (tester) async {
    final resultados = await abrirRevision(tester, total: 3);
    await tester.tap(find.text('B/N'));
    await esperarDeVerdad(tester);
    await tester.tap(find.text('Usar «B/N» en las 3 páginas'));
    await tester.pumpAndSettle();
    final r = resultados.single! as FotoConservada;
    expect(r.filtro, FiltroFoto.byn);
    expect(r.aTodas, isTrue);
  });

  group('Bordes del papel', () {
    /// Una foto de 600×800 de un papel blanco con renglones sobre una mesa
    /// oscura, con el papel en las [esquinas] (fracciones).
    Uint8List fotoDePapel(List<Offset> esquinas, {int ancho = 600, int alto = 800}) {
      final f = img.Image(width: ancho, height: alto);
      img.fill(f, color: img.ColorRgb8(70, 55, 45));
      img.fillPolygon(
        f,
        vertices: [for (final p in esquinas) img.Point(p.dx * ancho, p.dy * alto)],
        color: img.ColorRgb8(238, 238, 232),
      );
      for (var t = 0.2; t < 0.8; t += 0.07) {
        final a = Offset.lerp(
          Offset.lerp(esquinas[0], esquinas[3], t),
          Offset.lerp(esquinas[1], esquinas[2], t),
          0.15,
        )!;
        final b = Offset.lerp(
          Offset.lerp(esquinas[0], esquinas[3], t),
          Offset.lerp(esquinas[1], esquinas[2], t),
          0.85,
        )!;
        img.drawLine(
          f,
          x1: (a.dx * ancho).round(),
          y1: (a.dy * alto).round(),
          x2: (b.dx * ancho).round(),
          y2: (b.dy * alto).round(),
          color: img.ColorRgb8(50, 50, 60),
          thickness: 2,
        );
      }
      return Uint8List.fromList(img.encodeJpg(f, quality: 92));
    }

    const papel = [Offset(0.15, 0.12), Offset(0.85, 0.1), Offset(0.88, 0.9), Offset(0.12, 0.88)];

    Future<List<RevisionFoto?>> abrirCon(
      WidgetTester tester, {
      required Uint8List base,
      Uint8List? original,
      Esquinas esquinas = Esquinas.todo,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final resultados = <RevisionFoto?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultados.add(
                await Navigator.of(context).push<RevisionFoto>(
                  MaterialPageRoute(
                    builder: (_) =>
                        RevisarFotoScreen(base: base, original: original, esquinas: esquinas, numero: 1),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 400));
      await esperarDeVerdad(tester);
      await tester.pumpAndSettle();
      return resultados;
    }

    testWidgets(
      'Los bordes que se encontraron se reabren sobre la original, y se puede volver a la foto entera',
      (tester) async {
        final original = fotoDePapel(papel);
        final resultados = await abrirCon(
          tester,
          base: _foto,
          original: original,
          esquinas: Esquinas.deLista(papel),
        );
        await tester.tap(find.text('Recortar'));
        await esperarDeVerdad(tester);
        await tester.pumpAndSettle();
        // Se ve la original (600×800), no la página ya recortada (200×300).
        final foto = tester.getRect(find.byType(RawImage));
        expect(foto.width / foto.height, closeTo(600 / 800, 0.01));
        expect(find.textContaining('hasta los bordes del papel'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Restablecer recorte'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Restablecer recorte'), findsNothing);
        await tester.tap(find.bySemanticsLabel('Recortar').last);
        await esperarDeVerdad(tester);
        await tester.tap(find.text('Conservar'));
        await tester.pumpAndSettle();
        final r = resultados.single! as FotoConservada;
        expect(r.base, same(original));
        expect(r.esquinas!.esTodo, isTrue);
      },
    );

    testWidgets('Arrastrar el lado de arriba hasta la mitad deja la mitad de abajo', (tester) async {
      final resultados = await abrirCon(tester, base: _foto);
      await tester.tap(find.text('Recortar'));
      await tester.pumpAndSettle();
      final foto = tester.getRect(find.byType(RawImage));
      await tester.dragFrom(foto.topCenter, Offset(0, foto.height / 2));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Recortar').last);
      await esperarDeVerdad(tester);
      await tester.tap(find.text('Conservar'));
      await tester.pumpAndSettle();
      final recortada = img.decodeJpg((resultados.single! as FotoConservada).foto)!;
      expect(recortada.width, 200);
      expect(recortada.height, closeTo(150, 3));
    });

    testWidgets('"Detectar" encuentra el papel y al recortar queda derecho', (tester) async {
      final original = fotoDePapel(papel);
      final resultados = await abrirCon(tester, base: original);
      await tester.tap(find.text('Recortar'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Detectar'));
      await esperarDeVerdad(tester);
      expect(find.textContaining('Encontramos los bordes del papel'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Recortar').last);
      await esperarDeVerdad(tester);
      await tester.tap(find.text('Conservar'));
      await tester.pumpAndSettle();

      final r = resultados.single! as FotoConservada;
      for (var i = 0; i < 4; i++) {
        expect((r.esquinas!.lista[i] - papel[i]).distance, lessThan(0.02));
      }
      // El papel derecho: el lado más largo de arriba/abajo y de los costados.
      final derecha = img.decodeJpg(r.base)!;
      expect(derecha.width, closeTo(456, 12));
      expect(derecha.height, closeTo(640, 12));
    });

    testWidgets('Al tomar la foto queda lo del marco, sin buscar bordes (eso se hace en Detectar)', (
      tester,
    ) async {
      // Aunque se vea el papel, se guarda la foto entera (rápido).
      final conPapel = await tester.runAsync(() => prepararPagina(fotoDePapel(papel)));
      expect(conPapel!.esquinas.esTodo, isTrue);
      expect(conPapel.original, same(conPapel.base));
      final entera = img.decodeJpg(conPapel.base)!;
      expect((entera.width, entera.height), (600, 800));

      // Con un marco: lo que está dentro, y la original con un poco más alrededor.
      final lisa = Uint8List.fromList(img.encodeJpg(img.Image(width: 600, height: 800)));
      final enMarco = await tester.runAsync(
        () => prepararPagina(lisa, recorte: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9), proporcionCamara: 0.75),
      );
      final marco = img.decodeJpg(enMarco!.base)!;
      expect((marco.width, marco.height), (480, 640));
      final original = img.decodeJpg(enMarco.original)!;
      expect(original.width, greaterThan(480));
      // Las esquinas marcan dónde queda el marco dentro de la original.
      final e = enMarco.esquinas;
      expect(e.esTodo, isFalse);
      expect((e.abajoDer.dx - e.arribaIzq.dx) * original.width, closeTo(480, 2));
    });
  });

  group('Filtros de escáner', () {
    const lado = 240;

    /// Una hoja con sombra (el papel va de gris oscuro a la izquierda a claro
    /// a la derecha, un poco amarillento), un bloque grande de tinta y trazos
    /// finos de 1 px como los de las letras pequeñas: la cámara los ve grises
    /// (72 % de la luz del papel), no negros.
    Pixeles hojaConSombra() {
      final rgba = Uint8List(lado * lado * 4);
      for (var y = 0; y < lado; y++) {
        for (var x = 0; x < lado; x++) {
          final papel = 110 + x * 90 ~/ lado; // 110 → 200
          final tinta = x >= 100 && x < 140 && y >= 20 && y < 60;
          final trazoFino = (x == 60 || x == 180) && y >= 120 && y < 220;
          final v = tinta ? papel * 0.3 : (trazoFino ? papel * 0.72 : papel.toDouble());
          final i = (y * lado + x) * 4;
          rgba[i] = v.round();
          rgba[i + 1] = v.round();
          rgba[i + 2] = (v * 0.9).round();
          rgba[i + 3] = 255;
        }
      }
      return Pixeles(rgba, lado, lado);
    }

    int brillo(Pixeles p, int x, int y) {
      final i = (y * p.ancho + x) * 4;
      return ((p.rgba[i] + p.rgba[i + 1] + p.rgba[i + 2]) / 3).round();
    }

    test('"Documento": papel blanco parejo, tinta oscura y trazos finos marcados', () {
      final entrada = hojaConSombra();
      final salida = filtrarPixeles(entrada, FiltroFoto.documento);
      expect((salida.ancho, salida.alto), (lado, lado));
      // Papel con sombra y papel claro: los dos quedan casi blancos.
      expect(brillo(salida, 20, 170), greaterThan(240));
      expect(brillo(salida, 225, 170), greaterThan(240));
      // El bloque de tinta sigue oscuro (no se "lava").
      expect(brillo(salida, 120, 40), lessThan(80));
      // Los trazos finos: antes se distinguían poco del papel; ahora mucho más.
      for (final x in [60, 180]) {
        final antes = brillo(entrada, x - 3, 170) - brillo(entrada, x, 170);
        final despues = brillo(salida, x - 3, 170) - brillo(salida, x, 170);
        expect(despues, greaterThan(antes * 2.5), reason: 'trazo en x=$x');
        expect(brillo(salida, x, 170), lessThan(170), reason: 'trazo en x=$x');
      }
    });

    test('"B/N": en grises, papel blanco y los trazos finos casi negros', () {
      final salida = filtrarPixeles(hojaConSombra(), FiltroFoto.byn);
      final i = (150 * lado + 20) * 4;
      expect((salida.rgba[i], salida.rgba[i + 1]), (salida.rgba[i + 1], salida.rgba[i + 2])); // sin color
      expect(brillo(salida, 20, 170), greaterThan(240));
      expect(brillo(salida, 225, 170), greaterThan(240));
      expect(brillo(salida, 120, 40), lessThan(30));
      expect(brillo(salida, 60, 170), lessThan(100));
      expect(brillo(salida, 180, 170), lessThan(100));
    });

    test('"Original" no toca la foto', () {
      final hoja = hojaConSombra();
      expect(filtrarPixeles(hoja, FiltroFoto.original), same(hoja));
    });
  });
}

/// Deja correr trabajo real (decodificar la foto, el otro hilo del recorte).
Future<void> esperarDeVerdad(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }
}
