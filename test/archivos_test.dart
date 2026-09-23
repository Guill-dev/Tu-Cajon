import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/data/archivos/archivos_cifrados.dart';
import 'package:tu_cajon/features/guardar/guardar_screen.dart';

void main() {
  late Directory carpeta;
  late ArchivosCifrados archivos;

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('tu_cajon_prueba_');
    archivos = ArchivosCifrados(carpetaBase: carpeta, clave: List.generate(32, (i) => i * 7 % 256));
  });

  tearDown(() => carpeta.delete(recursive: true));

  final pdf = Uint8List.fromList('%PDF-1.4 contenido de prueba %%EOF'.codeUnits);

  test('Un PDF subido se guarda cifrado y se lee igual', () async {
    final guardado = await archivos.guardarPdf(pdf, paginas: 3);
    expect(guardado.paginas, 3);
    expect(guardado.bytes, pdf.length);

    // En el disco no está el PDF en claro.
    final enDisco = await Directory('${carpeta.path}/${guardado.ruta}')
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    expect(enDisco, hasLength(1));
    final cifrado = await enDisco.single.readAsBytes();
    expect(String.fromCharCodes(cifrado).contains('%PDF'), isFalse);

    expect(await archivos.leerPdf(guardado.ruta), pdf);
    expect(await archivos.leerPaginas(guardado.ruta), isEmpty); // no son fotos
  });

  test('Un documento de fotos no tiene PDF', () async {
    final guardado = await archivos.guardarPaginas([
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5]),
    ]);
    expect(await archivos.leerPdf(guardado.ruta), isNull);
    expect(await archivos.leerPaginas(guardado.ruta), [
      [1, 2, 3],
      [4, 5],
    ]);
  });

  test('Borrar quita también el PDF', () async {
    final guardado = await archivos.guardarPdf(pdf, paginas: 1);
    await archivos.borrar(guardado.ruta);
    expect(await Directory('${carpeta.path}/${guardado.ruta}').exists(), isFalse);
  });

  test('El nombre del archivo se vuelve un nombre legible', () {
    PdfSubido con(String nombre) => PdfSubido(bytes: pdf, paginas: 1, nombreArchivo: nombre);
    expect(con('Certificado_EPS_2026.pdf').nombreSugerido, 'Certificado EPS 2026');
    expect(con('recibo-de-luz.PDF').nombreSugerido, 'Recibo de luz');
    expect(con('.pdf').nombreSugerido, '');
  });
}
