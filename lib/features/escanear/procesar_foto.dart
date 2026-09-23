import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'filtros.dart';
import 'pixeles.dart';
import 'recorte.dart';

/// Una página lista: [base] sin filtro (para poder cambiar de filtro sin
/// degradarla) y [foto] con el filtro puesto (la que se guarda).
typedef PaginaLista = ({Uint8List base, Uint8List foto});

/// Lo que pasa con cada foto recién tomada:
/// 1. se abre con el decodificador del celular (rápido);
/// 2. se recorta al marco ([recorte], fracciones de [marcoEnImagen]);
/// 3. si quedó muy grande se achica a 2400 px de lado (el detalle de las
///    letras pequeñas se conserva y el PDF no pesa de más);
/// 4. se pasa a JPEG sin los datos ocultos de la cámara (ubicación, modelo…);
/// 5. si hay [filtro], se aplica.
///
/// Los pasos 2 a 5 van en otro hilo, para no trabar la cámara.
Future<PaginaLista> prepararPagina(
  Uint8List jpegCamara, {
  Rect? recorte,
  double? proporcionCamara,
  FiltroFoto filtro = FiltroFoto.original,
}) async {
  final pixeles = await decodificarFoto(jpegCamara);
  return Isolate.run(() {
    var p = pixeles;
    if (recorte != null && proporcionCamara != null) {
      final parte = parteEnPixeles(recorte, proporcionCamara: proporcionCamara, ancho: p.ancho, alto: p.alto);
      if (parte != null) p = _cortar(p, parte);
    }
    p = achicarSiHaceFalta(p);
    final base = codificarJpg(p);
    final foto = filtro == FiltroFoto.original ? base : codificarJpg(filtrarPixeles(p, filtro));
    return (base: base, foto: foto);
  });
}

/// Recorta una foto ya tomada a la [parte] elegida con el recortador
/// (fracciones de 0 a 1 de la foto tal como se ve).
Future<Uint8List> recortarParte(Uint8List jpeg, Rect parte) async {
  final pixeles = await decodificarFoto(jpeg);
  return Isolate.run(() {
    final enPixeles = Rect.fromLTRB(
      parte.left * pixeles.ancho,
      parte.top * pixeles.alto,
      parte.right * pixeles.ancho,
      parte.bottom * pixeles.alto,
    );
    return codificarJpg(_cortar(pixeles, enPixeles));
  });
}

Pixeles _cortar(Pixeles p, Rect r) => recortarPixeles(
  p,
  r.left.round(),
  r.top.round(),
  math.max(1, r.width.round()),
  math.max(1, r.height.round()),
);
