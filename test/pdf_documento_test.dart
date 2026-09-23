import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/data/compartir/pdf_documento.dart';

import 'foto_prueba.dart';

void main() {
  test('Arma un PDF con una página por foto', () async {
    final pdf = await armarPdf([fotoPrueba, fotoPrueba], titulo: 'Cédula de ciudadanía');
    final texto = latin1.decode(pdf);
    expect(texto.startsWith('%PDF-'), isTrue);
    expect(texto.trimRight().endsWith('%%EOF'), isTrue);
    // Dos páginas: "/Type /Page" sin la "s" de "/Pages".
    expect(RegExp(r'/Type\s*/Page(?!s)').allMatches(texto).length, 2);
  });

  test('Sin fotos no hay PDF', () {
    expect(() => armarPdf(const [], titulo: 'Vacío'), throwsArgumentError);
  });
}
