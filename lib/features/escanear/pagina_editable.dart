import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'filtros.dart';
import 'revisar_foto.dart';

/// Una página que todavía se puede editar (de la cámara o de la galería):
/// la foto sin filtro ([base], ya recortada) y cómo quedó con su [filtro]
/// ([foto], la que se guarda).
class PaginaEditable {
  const PaginaEditable({required this.base, required this.filtro, required this.foto});

  PaginaEditable.sinFiltro(Uint8List foto) : this(base: foto, filtro: FiltroFoto.original, foto: foto);

  final Uint8List base;
  final FiltroFoto filtro;
  final Uint8List foto;

  /// La misma página con otro [filtro], partiendo siempre de la [base].
  Future<PaginaEditable> conFiltro(FiltroFoto filtro) async =>
      PaginaEditable(base: base, filtro: filtro, foto: await aplicarFiltro(base, filtro));
}

/// Abre la página en grande para revisarla (filtro, recorte o eliminar).
Future<RevisionFoto?> abrirRevision(
  BuildContext context,
  PaginaEditable pagina, {
  required int numero,
  required int total,
}) {
  return Navigator.of(context).push<RevisionFoto>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => RevisarFotoScreen(
        base: pagina.base,
        filtro: pagina.filtro,
        foto: pagina.foto,
        numero: numero,
        total: total,
      ),
      transitionsBuilder: (_, a, _, hijo) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: hijo),
      ),
    ),
  );
}

/// Pone el [filtro] en todas las [paginas] que no lo tengan, una por una.
/// [alCambiar] recibe cada página nueva para reemplazar a la vieja (si la
/// lista cambió mientras tanto, quien llama decide qué hacer).
Future<void> filtrarTodas(
  List<PaginaEditable> paginas,
  FiltroFoto filtro,
  void Function(PaginaEditable vieja, PaginaEditable nueva) alCambiar,
) async {
  for (final pagina in List.of(paginas)) {
    if (pagina.filtro == filtro) continue;
    try {
      alCambiar(pagina, await pagina.conFiltro(filtro));
    } catch (e) {
      debugPrint('No se pudo aplicar el filtro a una página: $e');
    }
  }
}
