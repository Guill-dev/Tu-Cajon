import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Formas del estilo v3: tarjetas blancas muy redondeadas, sin borde, con una
/// sombra amplia y suave teñida de azul.
abstract final class AppDecor {
  static const radioTarjeta = 24.0;

  /// Sombra amplia y suave (de día teñida de azul; de noche, oscura).
  static List<BoxShadow> get sombra => AppColors.deNoche ? _sombraNoche : _sombraDia;
  static const _sombraDia = [BoxShadow(color: Color(0x142B3A8C), blurRadius: 28, offset: Offset(0, 10))];
  static const _sombraNoche = [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 10))];

  /// Sombra de color para elementos rellenos del acento (botones, tarjeta activa).
  static List<BoxShadow> sombraColor(Color c) => [
    BoxShadow(
      color: c.withValues(alpha: AppColors.deNoche ? 0.22 : 0.32),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static BoxDecoration tarjeta({double radius = radioTarjeta, Color? color}) => BoxDecoration(
    color: color ?? AppColors.superficie,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: sombra,
  );
}
