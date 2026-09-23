import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/features/escanear/pixeles.dart';
import 'package:tu_cajon/features/escanear/recorte.dart';

void main() {
  group('Marco en el visor', () {
    const visor = Size(350, 500);

    test('Cada formato respeta su proporción y cabe en el visor', () {
      for (final f in FormatoFoto.values) {
        final m = marcoEnVisor(visor, f);
        expect((Offset.zero & visor).contains(m.topLeft), isTrue, reason: f.name);
        expect(m.right <= visor.width + 0.01 && m.bottom <= visor.height + 0.01, isTrue, reason: f.name);
        if (f.proporcion != null) expect(m.width / m.height, closeTo(f.proporcion!, 0.001), reason: f.name);
        expect(m.center.dx, closeTo(visor.width / 2, 0.001));
      }
    });

    test('"Completa" es todo el visor', () {
      expect(marcoEnVisor(visor, FormatoFoto.completa), Offset.zero & visor);
    });
  });

  group('Marco en la imagen de la cámara', () {
    test('Sin recorte de "cover", las fracciones son las del visor', () {
      // Visor y cámara con la misma proporción (9:16).
      final r = marcoEnImagen(
        visor: const Size(360, 640),
        marco: const Rect.fromLTWH(36, 160, 288, 320),
        imagenCamara: const Size(1080, 1920),
      );
      expect(r.left, closeTo(0.1, 1e-9));
      expect(r.top, closeTo(0.25, 1e-9));
      expect(r.right, closeTo(0.9, 1e-9));
      expect(r.bottom, closeTo(0.75, 1e-9));
    });

    test('Si la cámara es más alta que el visor, se descuenta lo que no se ve', () {
      // Cámara 9:16 en un visor cuadrado: se ve solo la franja del medio.
      final r = marcoEnImagen(
        visor: const Size(400, 400),
        marco: Offset.zero & const Size(400, 400),
        imagenCamara: const Size(900, 1600),
      );
      expect(r.left, closeTo(0, 1e-9));
      expect(r.right, closeTo(1, 1e-9));
      // Alto mostrado = 1600 · (400/900) = 711,1 → se ven 400 de 711,1.
      expect(r.height, closeTo(400 / (1600 * 400 / 900), 1e-9));
      expect(r.center.dy, closeTo(0.5, 1e-9));
    });
  });

  group('Parte de la foto en píxeles', () {
    test('Con la misma proporción que la vista previa, son las fracciones de la foto', () {
      final r = parteEnPixeles(
        const Rect.fromLTRB(0.1, 0.25, 0.9, 0.75),
        proporcionCamara: 300 / 400,
        ancho: 300,
        alto: 400,
      )!;
      expect(r.left, closeTo(30, 1e-9));
      expect(r.top, closeTo(100, 1e-9));
      expect(r.width, closeTo(240, 1e-9));
      expect(r.height, closeTo(200, 1e-9));
    });

    test('Si la foto tiene otra proporción que la vista previa, se usa su parte central', () {
      // Foto 3:4 (300×400) y vista previa 9:16 → la vista previa es la franja
      // central de 225×400. La mitad izquierda de la vista previa: 112,5×400.
      final r = parteEnPixeles(
        const Rect.fromLTRB(0, 0, 0.5, 1),
        proporcionCamara: 9 / 16,
        ancho: 300,
        alto: 400,
      )!;
      expect(r.left, closeTo(37.5, 1e-9));
      expect(r.width, closeTo(112.5, 1e-9));
      expect(r.height, closeTo(400, 1e-9));
    });

    test('Una foto acostada al revés de la vista previa no se recorta', () {
      expect(
        parteEnPixeles(
          const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
          proporcionCamara: 9 / 16,
          ancho: 400,
          alto: 300,
        ),
        isNull,
      );
    });
  });

  group('Píxeles', () {
    /// Cada píxel guarda su x en rojo y su y en verde.
    Pixeles degradado(int w, int h) {
      final rgba = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          rgba[i] = x;
          rgba[i + 1] = y;
          rgba[i + 3] = 255;
        }
      }
      return Pixeles(rgba, w, h);
    }

    test('Recortar copia exactamente el rectángulo pedido', () {
      final r = recortarPixeles(degradado(100, 80), 10, 20, 30, 40);
      expect((r.ancho, r.alto), (30, 40));
      expect((r.rgba[0], r.rgba[1]), (10, 20)); // primer píxel
      final ultimo = (39 * 30 + 29) * 4;
      expect((r.rgba[ultimo], r.rgba[ultimo + 1]), (39, 59));
    });

    test('Recortar no se sale de la foto', () {
      final r = recortarPixeles(degradado(100, 80), 90, 70, 50, 50);
      expect((r.ancho, r.alto), (10, 10));
    });

    test('Una foto grande se achica al lado máximo y conserva la proporción', () {
      final chica = achicarSiHaceFalta(degradado(52, 26), ladoMaximo: 26);
      expect((chica.ancho, chica.alto), (26, 13));
      final igual = degradado(20, 10);
      expect(achicarSiHaceFalta(igual, ladoMaximo: 26), same(igual));
    });

    test('Se puede pasar a JPEG', () {
      final jpeg = codificarJpg(degradado(64, 48));
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]); // así empieza todo JPEG
    });
  });
}
