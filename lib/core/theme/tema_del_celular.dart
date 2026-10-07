import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Cómo se ve la app (Ajustes → Apariencia).
enum Apariencia {
  celular('Igual que el celular', 'De día o de noche según tu celular, y cambia con él.'),
  clara('Siempre claro', 'Fondo claro, aunque el celular esté en modo oscuro.'),
  oscura('Siempre oscuro', 'Fondo oscuro, aunque el celular esté de día.');

  const Apariencia(this.etiqueta, this.explicacion);

  final String etiqueta;
  final String explicacion;

  /// Dónde se guarda (en los ajustes de la base). Sin valor: igual que el celular.
  static const clave = 'apariencia';

  static Apariencia deTexto(String? texto) =>
      values.firstWhere((a) => a.name == texto, orElse: () => Apariencia.celular);
}

/// Pone la app de día o de noche según la [Apariencia] elegida: igual que el
/// celular (y la cambia en el momento en que el celular cambia, a mano o
/// solo a la hora programada), o siempre clara, o siempre oscura.
///
/// Los colores de la app salen de [AppColors], que lee la [Paleta] en uso:
/// al cambiarla se vuelve a construir y a pintar toda la app (también lo que
/// no depende del tema de Material, como los dibujos y las pantallas que
/// están debajo de la actual).
class TemaDelCelular extends StatefulWidget {
  const TemaDelCelular({
    super.key,
    this.apariencia = Apariencia.celular,
    this.alCambiar,
    required this.builder,
  });

  /// La que se eligió en Ajustes (se lee antes de abrir la app).
  final Apariencia apariencia;

  /// Para guardar la que se elija.
  final void Function(Apariencia)? alCambiar;

  final Widget Function(BuildContext context, Paleta paleta) builder;

  @override
  State<TemaDelCelular> createState() => _TemaDelCelularState();
}

class _TemaDelCelularState extends State<TemaDelCelular> with WidgetsBindingObserver {
  late Apariencia _apariencia = widget.apariencia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppColors.paleta = _queToca();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Paleta _queToca() => switch (_apariencia) {
    Apariencia.clara => Paleta.dia,
    Apariencia.oscura => Paleta.noche,
    Apariencia.celular =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
          ? Paleta.noche
          : Paleta.dia,
  };

  @override
  void didChangePlatformBrightness() {
    if (_apariencia == Apariencia.celular) _aplicar();
  }

  void _cambiar(Apariencia apariencia) {
    if (apariencia == _apariencia) return;
    setState(() => _apariencia = apariencia);
    widget.alCambiar?.call(apariencia);
    _aplicar();
  }

  void _aplicar() {
    final paleta = _queToca();
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
  Widget build(BuildContext context) => AparienciaScope._(
    apariencia: _apariencia,
    cambiar: _cambiar,
    child: widget.builder(context, AppColors.paleta),
  );
}

/// La [Apariencia] elegida y cómo cambiarla, para Ajustes.
class AparienciaScope extends InheritedWidget {
  const AparienciaScope._({required this.apariencia, required this.cambiar, required super.child});

  final Apariencia apariencia;
  final void Function(Apariencia) cambiar;

  static AparienciaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AparienciaScope>();
    assert(scope != null, 'Falta TemaDelCelular arriba de esta pantalla');
    return scope!;
  }

  @override
  bool updateShouldNotify(AparienciaScope oldWidget) => oldWidget.apariencia != apariencia;
}
