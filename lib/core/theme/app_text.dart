import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografía: Plus Jakarta Sans, una sans geométrica y redonda (como la
/// referencia de estilo), en pesos claros para leer y muy gruesos para títulos.
///
/// Los archivos van dentro de la app (`assets/fonts/`, declarados en
/// `pubspec.yaml`), así que funciona sin internet desde la primera vez.
abstract final class AppText {
  /// Nombre de la familia declarada en `pubspec.yaml`.
  static const familia = 'PlusJakartaSans';

  static TextStyle _estilo({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: familia,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// Título grueso (800).
  static TextStyle display(double size, {Color color = AppColors.titulo, double height = 1.15}) =>
      _estilo(size: size, weight: FontWeight.w800, height: height, color: color, letterSpacing: -0.4);

  /// Primera línea de los títulos en dos tonos ("Hola," en gris claro).
  static TextStyle displayLight(double size, {double height = 1.15}) => _estilo(
    size: size,
    weight: FontWeight.w500,
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
  }) => _estilo(
    size: size,
    weight: bold ? FontWeight.w700 : FontWeight.w500,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );

  static TextStyle bold(double size, {Color color = AppColors.texto, double? height}) =>
      body(size, color: color, bold: true, height: height);

  static TextStyle secondary(double size, {double? height}) =>
      body(size, color: AppColors.textoSecundario, height: height);
}
