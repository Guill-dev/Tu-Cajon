import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primario,
        primary: AppColors.primario,
        surface: AppColors.fondo,
      ),
      scaffoldBackgroundColor: AppColors.fondo,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.texto, displayColor: AppColors.titulo),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primario,
        selectionColor: AppColors.pulso,
        selectionHandleColor: AppColors.primario,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.superficie,
        headerBackgroundColor: AppColors.primario,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
