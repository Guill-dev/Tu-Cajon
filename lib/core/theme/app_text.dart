import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografía: Plus Jakarta Sans, una sans geométrica y redonda (como la
/// referencia de estilo), en pesos claros para leer y muy gruesos para títulos.
abstract final class AppText {
  /// Título grueso (800).
  static TextStyle display(double size, {Color color = AppColors.titulo, double height = 1.15}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: height,
        color: color,
        letterSpacing: -0.4,
      );

  /// Primera línea de los títulos en dos tonos ("Hola," en gris claro).
  static TextStyle displayLight(double size, {double height = 1.15}) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w500,
    height: height,
    color: AppColors.tituloSuave,
    letterSpacing: -0.4,
  );

  /// Texto de cuerpo.
  static TextStyle body(
    double size, {
    Color color = AppColors.texto,
    bool bold = false,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );

  static TextStyle bold(double size, {Color color = AppColors.texto, double? height}) =>
      body(size, color: color, bold: true, height: height);

  static TextStyle secondary(double size, {double? height}) =>
      body(size, color: AppColors.textoSecundario, height: height);
}
