import 'dart:ui';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';

/// Carpetas del cajón, cada una con su ícono y sus colores de ficha (de día
/// y de noche).
enum Categoria {
  identidad('Identidad', AppIcons.identidad, Color(0xFFE6E9FD), Color(0xFF5160EC), Color(0xFF8D98FF)),
  impuestos('Impuestos', AppIcons.impuestos, Color(0xFFF1E8FC), Color(0xFF8A5CD6), Color(0xFFC3A3F5)),
  salud('Salud', AppIcons.salud, Color(0xFFFDE8E6), Color(0xFFD2473C), Color(0xFFFF8A80)),
  estudios('Estudios', AppIcons.estudios, Color(0xFFFFF0D9), Color(0xFFB9770A), Color(0xFFF0B860)),
  vehiculo('Vehículo', AppIcons.vehiculo, Color(0xFFE0F4EA), Color(0xFF2E9468), Color(0xFF6FD3A4)),
  hogar('Hogar', AppIcons.hogar, Color(0xFFFFF5CC), Color(0xFF9A7400), Color(0xFFE6C35A)),
  pension('Pensión', AppIcons.pension, Color(0xFFE3F0FF), Color(0xFF2F74D0), Color(0xFF7FB2FF)),
  otro('Otro', AppIcons.carpeta, Color(0xFFEEF0F6), Color(0xFF5F657A), Color(0xFFAEB4C8));

  const Categoria(this.etiqueta, this.icono, this._fondoDia, this._colorDia, this._colorNoche);

  final String etiqueta;
  final String icono;
  final Color _fondoDia;
  final Color _colorDia;
  final Color _colorNoche;

  /// Fondo de la ficha: de noche, un tinte del color sobre la tarjeta oscura.
  Color get fondo => AppColors.deNoche
      ? Color.alphaBlend(_colorNoche.withValues(alpha: 0.16), AppColors.superficie)
      : _fondoDia;

  /// El ícono y los textos de la carpeta.
  Color get color => AppColors.deNoche ? _colorNoche : _colorDia;

  /// Las que se ofrecen al guardar un documento nuevo (en el orden del diseño).
  static const alGuardar = [identidad, impuestos, salud, estudios, vehiculo, hogar, otro];
}
