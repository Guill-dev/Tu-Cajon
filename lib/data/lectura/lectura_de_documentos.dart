import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/lectura/lector_de_texto.dart';
import '../../core/pdf/lector_pdf.dart';
import '../models/documento.dart';
import '../repositorio/cajon_repositorio.dart';
import 'interprete.dart';

/// Separa las páginas dentro de `textoExtraido` (un salto de página).
const separadorDePaginas = '\f';

/// Todo lo que se leyó de un documento.
class Lectura {
  const Lectura({this.paginas = const [], this.datos = const DatosLeidos()});

  final List<PaginaLeida> paginas;

  /// Lo que se entendió: tipo, número y vencimiento.
  final DatosLeidos datos;

  /// Todo el texto, con las páginas separadas por [separadorDePaginas].
  String get texto => paginas.map((p) => p.texto.trim()).join(separadorDePaginas).trim();

  bool get conTexto => texto.isNotEmpty;

  static const vacia = Lectura();
}

typedef ContarPaginasPdf = Future<int> Function(Uint8List pdf);
typedef DibujarPaginasPdf = Future<List<Uint8List>> Function(Uint8List pdf, int desde, int hasta);

/// Lee los documentos: cada página con el [lector] (fotos tal cual; un PDF,
/// dibujando sus páginas) y el texto completo con el [Interprete].
///
/// Todo pasa en el celular: las páginas ya descifradas solo viven en memoria.
class LecturaDeDocumentos {
  LecturaDeDocumentos({
    required this.lector,
    this.maximoPaginas = 40,
    ContarPaginasPdf? contarPdf,
    DibujarPaginasPdf? dibujarPdf,
  }) : _contarPdf = contarPdf ?? LectorPdf.contarPaginas,
       _dibujarPdf =
           dibujarPdf ??
           ((pdf, desde, hasta) => LectorPdf.dibujar(pdf, ancho: 1600, desde: desde, hasta: hasta));

  final LectorDeTexto lector;

  /// Un PDF muy largo se lee hasta aquí (cada página tarda un poco).
  final int maximoPaginas;

  final ContarPaginasPdf _contarPdf;
  final DibujarPaginasPdf _dibujarPdf;

  /// `false` si en este dispositivo no se puede leer.
  bool get disponible => lector.disponible;

  /// Lee las [fotos] de un documento o su [pdf]. [alAvanzar] cuenta las
  /// páginas: (las que ya se leyeron, cuántas son).
  ///
  /// Lanza [LecturaNoDisponible] si este dispositivo no sabe leer (o no sabe
  /// dibujar PDF). Un PDF con contraseña o dañado devuelve [Lectura.vacia].
  Future<Lectura> leer({
    List<Uint8List> fotos = const [],
    Uint8List? pdf,
    void Function(int leidas, int total)? alAvanzar,
  }) async {
    final paginas = <PaginaLeida>[];
    if (fotos.isNotEmpty) {
      final total = math.min(fotos.length, maximoPaginas);
      for (var i = 0; i < total; i++) {
        alAvanzar?.call(i, total);
        paginas.add(await _leerUna(fotos[i]));
      }
    } else if (pdf != null) {
      try {
        final total = math.min(await _contarPdf(pdf), maximoPaginas);
        // De a pocas páginas, para no tener todas las imágenes en memoria.
        for (var desde = 0; desde < total; desde += 4) {
          final imagenes = await _dibujarPdf(pdf, desde, math.min(desde + 4, total));
          for (final imagen in imagenes) {
            alAvanzar?.call(paginas.length, total);
            paginas.add(await _leerUna(imagen));
          }
        }
      } on ErrorPdf catch (e) {
        if (e.problema == ProblemaPdf.noDisponible) throw const LecturaNoDisponible();
        debugPrint('No se pudo leer el PDF: $e');
        return Lectura.vacia;
      }
    }
    final texto = Lectura(paginas: paginas).texto;
    return Lectura(
      paginas: paginas,
      datos: Interprete.entender(texto, lineas: paginas.firstOrNull?.lineas ?? const []),
    );
  }

  /// Lee un documento ya guardado (sus fotos o su PDF, descifrados en memoria).
  Future<Lectura> releer(CajonRepositorio repo, Documento documento) async {
    final fotos = await repo.leerPaginas(documento);
    if (fotos.isNotEmpty) return leer(fotos: fotos);
    final pdf = await repo.leerPdf(documento);
    return pdf == null ? Lectura.vacia : leer(pdf: pdf);
  }

  /// Lee las páginas nuevas de un documento y guarda su texto. No lanza: si
  /// no se puede leer, el documento queda como estaba.
  Future<void> leerYGuardar(
    CajonRepositorio repo,
    String documentoId, {
    List<Uint8List> fotos = const [],
    Uint8List? pdf,
  }) async {
    if (!disponible) return;
    try {
      final lectura = await leer(fotos: fotos, pdf: pdf);
      if (lectura.conTexto) await repo.guardarTexto(documentoId, lectura.texto);
    } catch (e) {
      debugPrint('No se pudo leer el documento: $e');
    }
  }

  /// Una página que no se pudo leer (foto dañada) cuenta como vacía; si el
  /// dispositivo no sabe leer, se avisa.
  Future<PaginaLeida> _leerUna(Uint8List imagen) async {
    try {
      return await lector.leer(imagen);
    } on LecturaNoDisponible {
      rethrow;
    } catch (e) {
      debugPrint('No se pudo leer una página: $e');
      return PaginaLeida.vacia;
    }
  }
}

/// Pone la lectura al alcance de las pantallas: `context.lectura`.
class LecturaScope extends InheritedWidget {
  const LecturaScope({super.key, required this.lectura, required super.child});

  final LecturaDeDocumentos lectura;

  static LecturaDeDocumentos of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LecturaScope>();
    assert(scope != null, 'Falta LecturaScope arriba en el árbol de widgets.');
    return scope!.lectura;
  }

  @override
  bool updateShouldNotify(LecturaScope oldWidget) => lectura != oldWidget.lectura;
}

extension LecturaContexto on BuildContext {
  LecturaDeDocumentos get lectura => LecturaScope.of(this);
}
