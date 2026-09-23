import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/tc_icon.dart';

/// Pantalla que se muestra si la base de datos no se pudo abrir al arrancar.
/// Antes la app se quedaba quieta en la carga sin decir nada.
class ErrorAperturaApp extends StatelessWidget {
  const ErrorAperturaApp({super.key, required this.detalle, required this.onReintentar});

  /// Texto técnico del error (se muestra pequeño, para poder reportarlo).
  final String detalle;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.fondo,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const TcIcon(AppIcons.candado, size: 40, color: AppColors.primario),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No pudimos abrir tu cajón',
                  textAlign: TextAlign.center,
                  style: AppText.display(26, height: 1.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tus documentos siguen guardados y cifrados en este celular. Cierra la app y vuelve a intentarlo.',
                  textAlign: TextAlign.center,
                  style: AppText.secondary(16, height: 1.45),
                ),
                const Spacer(),
                PrimaryButton(label: 'Intentar de nuevo', onTap: onReintentar),
                const SizedBox(height: 14),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(11, color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
