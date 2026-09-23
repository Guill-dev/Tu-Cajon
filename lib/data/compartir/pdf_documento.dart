import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Une las fotos de un documento (JPEG, ya descifradas) en un PDF: una
/// página tamaño carta por foto, con la foto completa y centrada.
///
/// Las fotos van tal cual dentro del PDF (sin volver a comprimirlas), así que
/// se leen igual de bien que en la app y el archivo no crece de más.
/// Se arma dentro del celular: nada pasa por internet.
Future<Uint8List> armarPdf(List<Uint8List> fotos, {required String titulo}) {
  if (fotos.isEmpty) throw ArgumentError('Un PDF necesita al menos una foto.');
  final pdf = pw.Document(title: titulo, creator: 'Tu Cajón', producer: 'Tu Cajón');
  for (final foto in fotos) {
    final imagen = pw.MemoryImage(foto);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Center(child: pw.Image(imagen, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return pdf.save();
}
