import 'package:flutter/widgets.dart';

/// Curvas y ayudas de animación compartidas.
abstract final class Motion {
  /// cubic-bezier(.2,.8,.2,1): la curva "suave al llegar" del diseño.
  static const suave = Cubic(0.2, 0.8, 0.2, 1);

  /// `true` si el usuario pidió reducir animaciones en su celular.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
