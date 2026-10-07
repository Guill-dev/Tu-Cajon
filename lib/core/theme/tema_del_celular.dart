import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Pone la app de día o de noche igual que el celular, y la cambia en el
/// momento en que el celular cambia (a mano, o solo a la hora programada).
///
/// Los colores de la app salen de [AppColors], que lee la [Paleta] en uso:
/// al cambiarla se vuelve a construir y a pintar toda la app (también lo que
/// no depende del tema de Material, como los dibujos y las pantallas que
/// están debajo de la actual).
class TemaDelCelular extends StatefulWidget {
  const TemaDelCelular({super.key, required this.builder});

  final Widget Function(BuildContext context, Paleta paleta) builder;

  @override
  State<TemaDelCelular> createState() => _TemaDelCelularState();
}

class _TemaDelCelularState extends State<TemaDelCelular> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppColors.paleta = _segunElCelular();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static Paleta _segunElCelular() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
      ? Paleta.noche
      : Paleta.dia;

  @override
  void didChangePlatformBrightness() {
    final paleta = _segunElCelular();
    if (identical(paleta, AppColors.paleta)) return;
    AppColors.paleta = paleta;
    setState(() {});
    _redibujarTodo();
  }

  /// Muchos widgets son constantes o no dependen del tema: se marcan todos
  /// para construirlos otra vez, y después del cuadro se repinta todo (los
  /// dibujos leen sus colores al pintar).
  void _redibujarTodo() {
    void construir(Element e) {
      e.markNeedsBuild();
      e.visitChildren(construir);
    }

    (context as Element).visitChildren(construir);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void pintar(RenderObject r) {
        r.markNeedsPaint();
        r.visitChildren(pintar);
      }

      for (final vista in RendererBinding.instance.renderViews) {
        pintar(vista);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, AppColors.paleta);
}
