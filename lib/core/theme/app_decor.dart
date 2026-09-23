import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Formas del estilo v3: tarjetas blancas muy redondeadas, sin borde, con una
/// sombra amplia y suave teñida de azul.
abstract final class AppDecor {
  static const radioTarjeta = 24.0;

  static const sombra = [BoxShadow(color: Color(0x142B3A8C), blurRadius: 28, offset: Offset(0, 10))];

  /// Sombra de color para elementos rellenos del acento (botones, tarjeta activa).
  static List<BoxShadow> sombraColor(Color c) => [
    BoxShadow(color: c.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 8)),
  ];

  static BoxDecoration tarjeta({double radius = radioTarjeta, Color color = AppColors.superficie}) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: sombra);
}
