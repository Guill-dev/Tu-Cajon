import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'bordes.dart';
import 'filtros.dart';
import 'pixeles.dart';
import 'recorte.dart';

/// Una página lista: [base] sin filtro (para poder cambiar de filtro sin
/// degradarla) y [foto] con el filtro puesto (la que se guarda).
///
/// [original] es la foto de la que salió (un poco más que el marco) y
/// [esquinas] dónde está el papel en ella: con eso se pueden volver a
/// ajustar los bordes sin perder nada. Si se encontró el papel, [tipo] dice
/// qué parece; [proporciones] son las medidas con que se enderezó.
typedef PaginaLista = ({
  Uint8List base,
  Uint8List foto,
  Uint8List original,
  Esquinas esquinas,
  bool detectada,
  TipoPapel? tipo,
  List<double> proporciones,
});

/// Lo que pasa con cada foto recién tomada:
/// 1. se abre con el decodificador del celular (rápido);
/// 2. se toma lo que está dentro del marco ([recorte], fracciones de
///    [marcoEnImagen]) y un poco más alrededor, por si el papel se salió;
/// 3. si quedó muy grande se achica a 2400 px de lado (el detalle de las
///    letras pequeñas se conserva y el PDF no pesa de más);
/// 4. con [detectar], se buscan los bordes del papel ([detectarBordes]); si
///    se encuentran, el papel se recorta y se endereza (como en un escáner).
///    Si no, queda lo que estaba dentro del marco. Se endereza con las medidas de [proporciones] o, sin ellas, con las
///    del papel que parece (tarjeta u hoja);
/// 5. se pasa a JPEG sin los datos ocultos de la cámara (ubicación, modelo…);
/// 6. si hay [filtro], se aplica.
///
/// Los pasos 2 a 6 van en otro hilo, para no trabar la cámara.
Future<PaginaLista> prepararPagina(
  Uint8List jpegCamara, {
  Rect? recorte,
  double? proporcionCamara,
  FiltroFoto filtro = FiltroFoto.original,
  bool detectar = true,
  List<double>? proporciones,
  double areaMinima = areaMinimaEnMarco,
}) async {
  final pixeles = await decodificarFoto(jpegCamara);
  return Isolate.run(() {
    var p = pixeles;
    var esquinas = Esquinas.todo;
    if (recorte != null && proporcionCamara != null) {
      final parte = parteEnPixeles(recorte, proporcionCamara: proporcionCamara, ancho: p.ancho, alto: p.alto);
      if (parte != null) {
        // Un poco más que el marco: si el papel quedó algo afuera, igual se encuentra.
        final margen = math.max(parte.width, parte.height) * 0.06;
        final amplia = parte
            .inflate(margen)
            .intersect(Rect.fromLTWH(0, 0, p.ancho.toDouble(), p.alto.toDouble()));
        p = _cortar(p, amplia);
        esquinas = Esquinas.deRect(
          Rect.fromLTRB(
            (parte.left - amplia.left) / amplia.width,
            (parte.top - amplia.top) / amplia.height,
            (parte.right - amplia.left) / amplia.width,
            (parte.bottom - amplia.top) / amplia.height,
          ),
        );
      }
    }
    p = achicarSiHaceFalta(p);
    final hallada = detectar ? detectarBordes(p, areaMinima: areaMinima) : null;
    if (hallada != null) esquinas = hallada;
    final tipo = hallada == null
        ? null
        : tipoDePapel(hallada, ancho: p.ancho.toDouble(), alto: p.alto.toDouble());
    final medidas = proporciones ?? proporcionesDe(tipo);
    final recortada = esquinas.esTodo ? p : enderezarPixeles(p, esquinas, proporciones: medidas);
    final base = codificarJpg(recortada);
    final foto = filtro == FiltroFoto.original ? base : codificarJpg(filtrarPixeles(recortada, filtro));
    return (
      base: base,
      foto: foto,
      original: esquinas.esTodo ? base : codificarJpg(p),
      esquinas: esquinas,
      detectada: hallada != null,
      tipo: tipo,
      proporciones: medidas,
    );
  });
}

/// Recorta y endereza el papel con sus [esquinas] dentro de la foto
/// [original] (para "Recortar" al revisar una página).
Future<Uint8List> enderezarFoto(
  Uint8List original,
  Esquinas esquinas, {
  List<double> proporciones = const [],
}) async {
  final pixeles = await decodificarFoto(original);
  return Isolate.run(
    () => codificarJpg(achicarSiHaceFalta(enderezarPixeles(pixeles, esquinas, proporciones: proporciones))),
  );
}

/// Busca los bordes del papel en una foto (para el botón "Detectar"): primero
/// un papel grande y, si no hay, también uno pequeño (una cédula de lejos).
Future<Esquinas?> detectarEnFoto(Uint8List jpeg) async {
  final pixeles = await decodificarFoto(jpeg);
  return Isolate.run(() => detectarBordes(pixeles) ?? detectarBordes(pixeles, areaMinima: areaMinimaEnVisor));
}

Pixeles _cortar(Pixeles p, Rect r) => recortarPixeles(
  p,
  r.left.round(),
  r.top.round(),
  math.max(1, r.width.round()),
  math.max(1, r.height.round()),
);
