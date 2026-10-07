import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tu_cajon/features/escanear/bordes.dart';
import 'package:tu_cajon/features/escanear/pixeles.dart';

/// Una "foto" de [ancho]×[alto] con un papel en las esquinas [papel] (en
/// fracciones), con renglones de texto, ruido y una sombra suave.
Pixeles foto({
  int ancho = 900,
  int alto = 1200,
  required List<Offset> papel,
  img.Color? fondo,
  img.Color? colorPapel,
  bool renglones = true,
  bool recuadro = false,
  int semilla = 1,
}) {
  final f = img.Image(width: ancho, height: alto);
  img.fill(f, color: fondo ?? img.ColorRgb8(92, 72, 55));
  final v = [for (final p in papel) img.Point(p.dx * ancho, p.dy * alto)];
  img.fillPolygon(f, vertices: v, color: colorPapel ?? img.ColorRgb8(236, 236, 230));
  Offset en(double u, double t) {
    // Punto (u, t) del papel, mezclando sus esquinas (aproximado, basta para dibujar).
    final arriba = Offset.lerp(papel[0], papel[1], u)!;
    final abajo = Offset.lerp(papel[3], papel[2], u)!;
    final p = Offset.lerp(arriba, abajo, t)!;
    return Offset(p.dx * ancho, p.dy * alto);
  }

  if (renglones) {
    for (var t = 0.15; t < 0.85; t += 0.06) {
      final a = en(0.12, t), b = en(0.88, t);
      img.drawLine(
        f,
        x1: a.dx.round(),
        y1: a.dy.round(),
        x2: b.dx.round(),
        y2: b.dy.round(),
        color: img.ColorRgb8(60, 60, 70),
        thickness: 3,
      );
    }
  }
  if (recuadro) {
    // La foto de la cédula: un recuadro oscuro adentro.
    final c = [en(0.06, 0.2), en(0.36, 0.2), en(0.36, 0.85), en(0.06, 0.85)];
    img.fillPolygon(
      f,
      vertices: [for (final p in c) img.Point(p.dx, p.dy)],
      color: img.ColorRgb8(70, 80, 110),
    );
  }
  // Ruido de cámara.
  final azar = math.Random(semilla);
  for (final px in f) {
    final n = azar.nextInt(17) - 8;
    px
      ..r = (px.r + n).clamp(0, 255)
      ..g = (px.g + n).clamp(0, 255)
      ..b = (px.b + n).clamp(0, 255);
  }
  final suave = img.gaussianBlur(f, radius: 1);
  return Pixeles(Uint8List.fromList(suave.getBytes(order: img.ChannelOrder.rgba)), ancho, alto);
}

void esperarCerca(Esquinas? hallada, List<Offset> esperada, {double tolerancia = 0.015}) {
  expect(hallada, isNotNull, reason: 'no encontró el papel');
  for (var i = 0; i < 4; i++) {
    final d = (hallada!.lista[i] - esperada[i]).distance;
    expect(d, lessThan(tolerancia), reason: 'esquina $i: ${hallada.lista[i]} en vez de ${esperada[i]}');
  }
}

void main() {
  group('Detectar los bordes', () {
    test('Una hoja torcida y en perspectiva sobre una mesa', () {
      const papel = [Offset(0.16, 0.12), Offset(0.84, 0.08), Offset(0.9, 0.9), Offset(0.1, 0.86)];
      final imagen = foto(papel: papel);
      esperarCerca(detectarBordes(imagen), papel);
      // Rápido, para no hacer esperar después de la foto. Se mide la segunda
      // vez (la primera incluye compilar el código; en el celular ya viene
      // compilado y es varias veces más rápido que aquí).
      final reloj = Stopwatch()..start();
      detectarBordes(imagen);
      reloj.stop();
      debugPrint('Detectar los bordes tardó ${reloj.elapsedMilliseconds} ms');
      expect(reloj.elapsedMilliseconds, lessThan(2500));
    });

    test('Una cédula con su recuadro de foto: gana el borde de afuera', () {
      const papel = [Offset(0.1, 0.3), Offset(0.92, 0.27), Offset(0.94, 0.73), Offset(0.08, 0.7)];
      final e = detectarBordes(
        foto(
          ancho: 1200,
          alto: 900,
          papel: papel,
          fondo: img.ColorRgb8(128, 128, 128),
          colorPapel: img.ColorRgb8(205, 218, 236),
          recuadro: true,
          semilla: 2,
        ),
      );
      esperarCerca(e, papel);
    });

    test('Una hoja casi derecha que ocupa casi toda la foto', () {
      const papel = [Offset(0.04, 0.03), Offset(0.96, 0.035), Offset(0.955, 0.97), Offset(0.045, 0.965)];
      esperarCerca(detectarBordes(foto(papel: papel, semilla: 3)), papel);
    });

    test('Sobre una mesa de madera con vetas y con un dedo tapando un borde', () {
      const papel = [Offset(0.14, 0.14), Offset(0.86, 0.1), Offset(0.88, 0.88), Offset(0.12, 0.9)];
      final f = img.Image(width: 900, height: 1200);
      img.fill(f, color: img.ColorRgb8(120, 85, 55));
      // Vetas de la madera: rayas largas y un poco inclinadas.
      final azar = math.Random(7);
      for (var k = 0; k < 40; k++) {
        final y = azar.nextInt(1200);
        img.drawLine(
          f,
          x1: 0,
          y1: y,
          x2: 900,
          y2: y + azar.nextInt(80) - 40,
          color: img.ColorRgb8(95, 65, 40),
          thickness: 2 + azar.nextInt(3),
        );
      }
      img.fillPolygon(
        f,
        vertices: [for (final p in papel) img.Point(p.dx * 900, p.dy * 1200)],
        color: img.ColorRgb8(238, 236, 228),
      );
      // Un dedo sobre el borde izquierdo.
      img.fillCircle(f, x: 110, y: 600, radius: 70, color: img.ColorRgb8(205, 150, 120));
      final p = Pixeles(
        Uint8List.fromList(img.gaussianBlur(f, radius: 1).getBytes(order: img.ChannelOrder.rgba)),
        900,
        1200,
      );
      esperarCerca(detectarBordes(p), papel);
    });

    test('Sin papel claro no inventa: foto lisa, papel que se sale, blanco sobre blanco', () {
      final lisa = foto(
        papel: const [Offset(0, 0), Offset(0, 0), Offset(0, 0), Offset(0, 0)],
        renglones: false,
      );
      expect(detectarBordes(lisa), isNull);

      const seSale = [Offset(-0.2, -0.2), Offset(1.2, -0.2), Offset(1.2, 1.2), Offset(-0.2, 1.2)];
      expect(detectarBordes(foto(papel: seSale)), isNull);

      const papel = [Offset(0.15, 0.12), Offset(0.85, 0.1), Offset(0.88, 0.9), Offset(0.12, 0.88)];
      final blanco = foto(
        papel: papel,
        fondo: img.ColorRgb8(238, 238, 236),
        colorPapel: img.ColorRgb8(241, 241, 239),
        renglones: false,
      );
      expect(detectarBordes(blanco), isNull);
    });
  });

  group('Enderezar', () {
    test('Un rectángulo derecho es un recorte simple', () {
      final p = foto(papel: const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)], renglones: false);
      final r = enderezarPixeles(
        p,
        const Esquinas(Offset(0, 0), Offset(0.5, 0), Offset(0.5, 1), Offset(0, 1)),
      );
      expect(r.ancho, 450);
      expect(r.alto, 1200);
    });

    test('En perspectiva: el centro del papel queda en el centro, y la tarjeta toma su proporción', () {
      const papel = [Offset(0.2, 0.25), Offset(0.85, 0.2), Offset(0.95, 0.8), Offset(0.1, 0.75)];
      final f = img.Image(width: 1000, height: 800);
      img.fill(f, color: img.ColorRgb8(90, 90, 90));
      img.fillPolygon(
        f,
        vertices: [for (final p in papel) img.Point(p.dx * 1000, p.dy * 800)],
        color: img.ColorRgb8(240, 240, 240),
      );
      // El centro de un cuadrilátero en perspectiva es donde se cruzan sus diagonales.
      Offset px(Offset p) => Offset(p.dx * 1000, p.dy * 800);
      final a = px(papel[0]), b = px(papel[2]), c = px(papel[1]), d = px(papel[3]);
      final t =
          ((c.dx - a.dx) * (d.dy - c.dy) - (c.dy - a.dy) * (d.dx - c.dx)) /
          ((b.dx - a.dx) * (d.dy - c.dy) - (b.dy - a.dy) * (d.dx - c.dx));
      final centro = a + (b - a) * t;
      img.fillCircle(
        f,
        x: centro.dx.round(),
        y: centro.dy.round(),
        radius: 10,
        color: img.ColorRgb8(200, 0, 0),
      );
      final p = Pixeles(Uint8List.fromList(f.getBytes(order: img.ChannelOrder.rgba)), 1000, 800);

      final r = enderezarPixeles(p, Esquinas.deLista(papel), proporciones: proporcionesTarjeta);
      final k = ((r.alto ~/ 2) * r.ancho + r.ancho ~/ 2) * 4;
      expect(r.rgba[k], greaterThan(150)); // rojo
      expect(r.rgba[k + 1], lessThan(80));
      expect(r.ancho / r.alto, closeTo(85.6 / 54, 0.01));
      // Las esquinas de la salida son papel (blanco), no mesa.
      expect(r.rgba[(3 * r.ancho + 3) * 4], greaterThan(200));
    });
  });
}
