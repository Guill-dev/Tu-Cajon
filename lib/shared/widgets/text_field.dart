import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';

/// Campo de texto con etiqueta arriba: tarjeta blanca sin borde, con sombra
/// suave y un borde del acento al enfocar.
class TcTextField extends StatelessWidget {
  const TcTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.height = 56,
    this.fontSize = 18,
    this.radius = 18,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final double height;
  final double fontSize;
  final double radius;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.bold(16)),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(borderRadius: br, boxShadow: AppDecor.sombra),
          child: TextField(
            controller: controller,
            autocorrect: false,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: AppText.body(fontSize, height: 1.2),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body(fontSize, color: AppColors.placeholder, height: 1.2),
              filled: true,
              fillColor: AppColors.superficie,
              hoverColor: AppColors.superficie,
              isDense: true,
              // El alto sale del relleno: (alto del diseño − una línea de texto) / 2.
              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: (height - fontSize * 1.2) / 2),
              enabledBorder: OutlineInputBorder(borderRadius: br, borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: br,
                borderSide: const BorderSide(color: AppColors.primario, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
