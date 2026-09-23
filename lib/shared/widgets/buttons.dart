import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import 'tc_icon.dart';
import 'tc_tap.dart';

/// Botón grande de acción principal (60 px, acento azul-violeta con sombra de color).
///
/// Si [onTap] es `null` se muestra deshabilitado con [disabledLabel].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.disabledLabel,
    this.color = AppColors.primario,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final String? trailingIcon;
  final String? disabledLabel;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: enabled
          ? TcTap(
              key: const ValueKey('on'),
              onTap: onTap,
              color: color,
              radius: 20,
              minHeight: height,
              shadow: AppDecor.sombraColor(color),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    TcIcon(icon!, size: 22, color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.bold(18, color: Colors.white),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 10),
                    TcIcon(trailingIcon!, size: 22, color: Colors.white),
                  ],
                ],
              ),
            )
          : Semantics(
              key: const ValueKey('off'),
              button: true,
              enabled: false,
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deshabilitadoFondo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  disabledLabel ?? label,
                  textAlign: TextAlign.center,
                  style: AppText.bold(18, color: AppColors.deshabilitadoTexto),
                ),
              ),
            ),
    );
  }
}

/// Botón secundario: tarjeta blanca con sombra y texto en el acento.
class OutlineButtonTc extends StatelessWidget {
  const OutlineButtonTc({super.key, required this.label, this.icon, this.onTap, this.height = 56});

  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: AppColors.superficie,
      radius: 20,
      shadow: AppDecor.sombra,
      minHeight: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            TcIcon(icon!, size: 22, color: AppColors.primario),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.bold(16, color: AppColors.primario),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón pequeño (44 px) usado en tarjetas: relleno o solo texto.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, this.onTap, this.filled = true});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: filled ? AppColors.primario : AppColors.primarioSuave,
      radius: 14,
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: AppText.bold(14, color: filled ? Colors.white : AppColors.primario)),
      ),
    );
  }
}

/// Botón cuadrado de esquinas redondas (52 px), como la campana amarilla de
/// la referencia. Por defecto amarillo con el ícono en el acento.
class SquircleButton extends StatelessWidget {
  const SquircleButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.color = AppColors.amarillo,
    this.iconColor = AppColors.primario,
    this.size = 52,
    this.iconSize = 22,
    this.extra = '',
    this.shadow = false,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;
  final double iconSize;
  final String extra;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: color,
      radius: size * 0.34,
      width: size,
      height: size,
      shadow: shadow ? AppDecor.sombra : null,
      semanticLabel: semanticLabel,
      child: Center(
        child: TcIcon(icon, size: iconSize, color: iconColor, extra: extra),
      ),
    );
  }
}

/// Botón de flecha en el acento (el "›" de la referencia).
class ArrowButton extends StatelessWidget {
  const ArrowButton({super.key, required this.onTap, required this.semanticLabel, this.size = 56});

  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: AppColors.primario,
      radius: size * 0.36,
      width: size,
      height: size,
      shadow: AppDecor.sombraColor(AppColors.primario),
      semanticLabel: semanticLabel,
      child: const Center(child: TcIcon(AppIcons.siguiente, size: 24, color: Colors.white)),
    );
  }
}

/// Botón circular de 48 px (ej. WhatsApp en la lista).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.color = AppColors.texto,
    this.background = AppColors.superficie,
    this.border = BorderSide.none,
    this.size = 48,
    this.iconSize = 22,
    this.extra = '',
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color color;
  final Color background;
  final BorderSide border;
  final double size;
  final double iconSize;
  final String extra;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: background,
      radius: size / 2,
      border: border,
      width: size,
      height: size,
      semanticLabel: semanticLabel,
      child: Center(
        child: TcIcon(icon, size: iconSize, color: color, extra: extra),
      ),
    );
  }
}

/// Flecha de volver (48×48) usada en los encabezados.
class BackButtonTc extends StatelessWidget {
  const BackButtonTc({super.key, this.onTap, this.semanticLabel = 'Volver', this.icon = AppIcons.atras});

  final VoidCallback? onTap;
  final String semanticLabel;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      radius: 24,
      width: 48,
      height: 48,
      semanticLabel: semanticLabel,
      child: Center(child: TcIcon(icon, size: 24, color: AppColors.texto, strokeWidth: 2.2)),
    );
  }
}

/// Chip en forma de píldora blanca (categorías, carpetas). El seleccionado
/// se rellena con el acento.
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      selected: selected,
      color: selected ? AppColors.primario : AppColors.superficie,
      radius: 22,
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: AppText.bold(14, color: selected ? Colors.white : AppColors.texto)),
      ),
    );
  }
}
