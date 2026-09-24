import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/archivos/selector_archivos.dart';
import '../../core/pdf/lector_pdf.dart';
import '../guardar/guardar_screen.dart';

/// El PDF más grande que se acepta (igual en `ArchivosRecibidos.kt`).
const maximoPdf = 50 * 1024 * 1024;

/// Por qué no se aceptó un PDF (el mensaje es para la persona).
class PdfRechazado implements Exception {
  const PdfRechazado(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'PdfRechazado($mensaje)';
}

/// Revisa que [pdf] se pueda guardar, cuenta sus páginas y dibuja la primera.
/// Lanza [PdfRechazado] si no es un PDF, pesa demasiado o está dañado.
///
/// Sirve para el que se sube desde el explorador y para el que llega por
/// "Compartir" ([recibido]).
Future<PdfSubido> prepararPdf(PdfElegido pdf, {bool recibido = false}) async {
  if (!LectorPdf.pareceUnPdf(pdf.bytes)) {
    throw const PdfRechazado('Ese archivo no es un PDF. Prueba con otro.');
  }
  if (pdf.bytes.length > maximoPdf) {
    throw const PdfRechazado('Ese PDF pesa más de 50 MB. Elige uno más liviano.');
  }
  var paginas = 1;
  Uint8List? portada;
  String? aviso;
  try {
    paginas = math.max(1, await LectorPdf.contarPaginas(pdf.bytes));
    portada = (await LectorPdf.dibujar(pdf.bytes, ancho: 400, hasta: 1)).firstOrNull;
  } on ErrorPdf catch (e) {
    if (e.problema == ProblemaPdf.invalido) throw PdfRechazado(e.mensaje);
    // Con contraseña se puede guardar igual; sin lector (web) también.
    if (e.problema == ProblemaPdf.conClave) aviso = e.mensaje;
  }
  return PdfSubido(
    bytes: pdf.bytes,
    paginas: paginas,
    nombreArchivo: pdf.nombre,
    portada: portada,
    aviso: aviso,
    recibido: recibido,
  );
}
