import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

abstract final class AppTheme {
  /// De día.
  static ThemeData get light => de(Paleta.dia);

  /// De noche.
  static ThemeData get dark => de(Paleta.noche);

  /// El tema de Material con los colores de la [paleta] (diálogos del
  /// sistema, selección de texto, calendario…).
  static ThemeData de(Paleta paleta) {
    final brillo = paleta.deNoche ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      fontFamily: AppText.familia,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Paleta.dia.primario,
        brightness: brillo,
        primary: paleta.primario,
        onPrimary: paleta.sobrePrimario,
        surface: paleta.fondo,
        onSurface: paleta.texto,
        error: paleta.rojo,
      ),
      scaffoldBackgroundColor: paleta.fondo,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: paleta.texto, displayColor: paleta.titulo),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: paleta.primario,
        selectionColor: paleta.pulso,
        selectionHandleColor: paleta.primario,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: paleta.superficie,
        headerBackgroundColor: paleta.primario,
        headerForegroundColor: paleta.sobrePrimario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: paleta.superficie),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: paleta.toast,
        contentTextStyle: AppText.body(15, color: Colors.white),
        actionTextColor: Paleta.noche.primario,
      ),
    );
  }
}
