import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/compartir/compartidor.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../data/models/documento.dart';
import '../../data/repositorio/repositorio_scope.dart';

/// Envía un documento como PDF: directo a WhatsApp ([porWhatsApp]) o con el
/// menú de compartir del celular. Lo usan "Mi cajón" y el detalle.
///
/// 1. descifra las fotos del documento, o el PDF subido (solo en memoria),
/// 2. el [Compartidor] arma el PDF (o usa el subido) y abre WhatsApp o el menú,
/// 3. el [Cerrojo] deja salir a WhatsApp sin cerrar el cajón (si se vuelve
///    en menos de 2 minutos).
///
/// Si el celular no tiene WhatsApp, avisa y abre el menú para elegir otra app.
/// [avisar] muestra los mensajes en la pantalla que lo llamó.
Future<void> enviarDocumento(
  BuildContext context,
  Documento documento, {
  required bool porWhatsApp,
  required void Function(String mensaje) avisar,
}) async {
  final repo = context.repo;
  final compartidor = context.compartidor;
  final cerrojo = context.cerrojo;

  // Fotos (escaneadas o de la galería) o un PDF que se subió tal cual.
  final List<Uint8List> paginas;
  Uint8List? pdf;
  try {
    paginas = await repo.leerPaginas(documento);
    if (paginas.isEmpty) pdf = await repo.leerPdf(documento);
  } catch (e) {
    debugPrint('No se pudo leer el documento: $e');
    avisar('No pudimos abrir este documento. Vuelve a intentarlo.');
    return;
  }
  if (paginas.isEmpty && pdf == null) {
    avisar('Este documento no tiene fotos para enviar. Escanéalo para poder compartirlo.');
    return;
  }

  Future<ResultadoCompartir> intentar({required bool whatsapp}) {
    cerrojo.permitirSalida();
    return compartidor.enviar(
      nombreArchivo: documento.nombreArchivo,
      titulo: documento.nombre,
      paginas: paginas,
      pdf: pdf,
      porWhatsApp: whatsapp,
    );
  }

  var resultado = await intentar(whatsapp: porWhatsApp);
  if (resultado == ResultadoCompartir.sinWhatsApp) {
    cerrojo.cancelarSalida();
    avisar('No encontramos WhatsApp en tu celular. Elige otra app para enviarlo.');
    resultado = await intentar(whatsapp: false);
  }
  if (resultado == ResultadoCompartir.fallo) {
    cerrojo.cancelarSalida();
    avisar('No pudimos preparar el PDF. Vuelve a intentarlo.');
  }
}
