import 'dart:ui';

import '../../core/icons/app_icons.dart';

/// Carpetas del cajón, cada una con su ícono y sus colores de ficha.
enum Categoria {
  identidad('Identidad', AppIcons.identidad, Color(0xFFE6E9FD), Color(0xFF5160EC)),
  impuestos('Impuestos', AppIcons.impuestos, Color(0xFFF1E8FC), Color(0xFF8A5CD6)),
  salud('Salud', AppIcons.salud, Color(0xFFFDE8E6), Color(0xFFD2473C)),
  estudios('Estudios', AppIcons.estudios, Color(0xFFFFF0D9), Color(0xFFB9770A)),
  vehiculo('Vehículo', AppIcons.vehiculo, Color(0xFFE0F4EA), Color(0xFF2E9468)),
  hogar('Hogar', AppIcons.hogar, Color(0xFFFFF5CC), Color(0xFF9A7400)),
  pension('Pensión', AppIcons.pension, Color(0xFFE3F0FF), Color(0xFF2F74D0)),
  otro('Otro', AppIcons.carpeta, Color(0xFFEEF0F6), Color(0xFF5F657A));

  const Categoria(this.etiqueta, this.icono, this.fondo, this.color);

  final String etiqueta;
  final String icono;
  final Color fondo;
  final Color color;

  /// Las que se ofrecen al guardar un documento nuevo (en el orden del diseño).
  static const alGuardar = [identidad, impuestos, salud, estudios, vehiculo, hogar, otro];
}
