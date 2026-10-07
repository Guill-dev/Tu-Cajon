import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'bordes.dart';
import 'filtros.dart';
import 'fotos_del_celular.dart';
import 'pixeles.dart';
import 'recorte.dart';

/// Una página lista: [base] sin filtro (para poder cambiar de filtro sin
/// degradarla) y [foto] con el filtro puesto (la que se guarda).
///
/// [original] es la foto de la que salió (un poco más que el marco) y
/// [esquinas] dónde está la página en ella: con eso "Recortar" puede mover
/// los bordes (también hacia afuera) y "Detectar" buscar el papel, sin
/// perder nada.
typedef PaginaLista = ({Uint8List base, Uint8List foto, Uint8List original, Esquinas esquinas});

/// Lo que pasa con cada foto recién tomada (rápido: los bordes del papel no
/// se buscan aquí sino en Recortar → Detectar):
/// 1. se toma lo que está dentro del marco ([recorte], fracciones de
///    [marcoEnImagen]) y un 6 % más alrededor, la [PaginaLista.original];
/// 2. se endereza según su marca de giro y se achica a 2400 px de lado como
///    máximo (el detalle de las letras pequeñas se conserva y el PDF no pesa
///    de más);
/// 3. se pasa a JPEG sin los datos ocultos de la cámara (ubicación, modelo…);
/// 4. si hay [filtro], se aplica.
///
/// Lo hace el celular con sus propias herramientas ([FotosDelCelular]); sin
/// ellas (pruebas), en Dart y en otro hilo.
Future<PaginaLista> prepararPagina(
  Uint8List jpegCamara, {
  Rect? recorte,
  double? proporcionCamara,
  FiltroFoto filtro = FiltroFoto.original,
}) async {
  final lista =
      await _enElCelular(jpegCamara, recorte, proporcionCamara) ??
      await _enDart(jpegCamara, recorte, proporcionCamara);
  return (
    base: lista.base,
    foto: await aplicarFiltro(lista.base, filtro),
    original: lista.original,
    esquinas: lista.esquinas,
  );
}

typedef _Partes = ({Uint8List base, Uint8List original, Esquinas esquinas});

Future<_Partes?> _enElCelular(Uint8List jpeg, Rect? recorte, double? proporcionCamara) async {
  final medidas = await FotosDelCelular.medir(jpeg);
  if (medidas == null) return null;
  final (parte, amplia) = _partes(recorte, proporcionCamara, medidas.$1, medidas.$2);
  final r = await FotosDelCelular.preparar(jpeg, amplia: amplia, parte: parte);
  if (r == null) return null;
  return (base: r.base, original: r.original, esquinas: _esquinas(parte, amplia));
}

Future<_Partes> _enDart(Uint8List jpeg, Rect? recorte, double? proporcionCamara) async {
  final pixeles = await decodificarFoto(jpeg);
  return Isolate.run(() {
    final (parte, amplia) = _partes(recorte, proporcionCamara, pixeles.ancho, pixeles.alto);
    final esquinas = _esquinas(parte, amplia);
    final p = achicarSiHaceFalta(_cortar(pixeles, amplia));
    final original = codificarJpg(p);
    if (esquinas.esTodo) return (base: original, original: original, esquinas: Esquinas.todo);
    final r = Rect.fromLTRB(
      esquinas.arribaIzq.dx * p.ancho,
      esquinas.arribaIzq.dy * p.alto,
      esquinas.abajoDer.dx * p.ancho,
      esquinas.abajoDer.dy * p.alto,
    );
    return (base: codificarJpg(_cortar(p, r)), original: original, esquinas: esquinas);
  });
}

/// En píxeles de una foto de [ancho]×[alto]: la parte que se guarda (lo que
/// estaba dentro del marco) y la "amplia", con un 6 % más alrededor por si
/// el papel quedó algo afuera.
(Rect, Rect) _partes(Rect? recorte, double? proporcionCamara, int ancho, int alto) {
  final todo = Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble());
  final parte = recorte == null || proporcionCamara == null
      ? null
      : parteEnPixeles(recorte, proporcionCamara: proporcionCamara, ancho: ancho, alto: alto);
  if (parte == null) return (todo, todo);
  final margen = math.max(parte.width, parte.height) * 0.06;
  return (parte, parte.inflate(margen).intersect(todo));
}

/// Dónde queda la [parte] dentro de la [amplia], en fracciones.
Esquinas _esquinas(Rect parte, Rect amplia) {
  final e = Esquinas.deRect(
    Rect.fromLTRB(
      (parte.left - amplia.left) / amplia.width,
      (parte.top - amplia.top) / amplia.height,
      (parte.right - amplia.left) / amplia.width,
      (parte.bottom - amplia.top) / amplia.height,
    ),
  );
  return e.esTodo ? Esquinas.todo : e;
}

/// Recorta y endereza el papel con sus [esquinas] dentro de la foto
/// [original] (para "Recortar" al revisar una página). Sin [proporciones],
/// se usan las del papel que parece (tarjeta u hoja), si se parece.
Future<Uint8List> enderezarFoto(
  Uint8List original,
  Esquinas esquinas, {
  List<double> proporciones = const [],
}) async {
  final pixeles = await decodificarFoto(original);
  final derecha = await Isolate.run(() {
    final medidas = proporciones.isNotEmpty
        ? proporciones
        : proporcionesDe(
            tipoDePapel(esquinas, ancho: pixeles.ancho.toDouble(), alto: pixeles.alto.toDouble()),
          );
    return achicarSiHaceFalta(enderezarPixeles(pixeles, esquinas, proporciones: medidas));
  });
  return aJpeg(derecha);
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
