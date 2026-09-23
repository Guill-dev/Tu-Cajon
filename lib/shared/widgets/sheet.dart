import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Hoja inferior dentro de la pantalla: fondo oscurecido + panel blanco que
/// sube con fade (como `.tc-rise` del diseño).
///
/// Va como último hijo de un `Stack` de pantalla completa.
class TcSheet extends StatelessWidget {
  const TcSheet({
    super.key,
    required this.open,
    required this.child,
    this.onDismiss,
    this.riseFrom = 60,
    this.duration = const Duration(milliseconds: 260),
    this.radius = 26,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    this.dismissLabel = 'Cerrar',
  });

  final bool open;
  final Widget child;

  /// Si es `null`, tocar el fondo no cierra la hoja.
  final VoidCallback? onDismiss;
  final double riseFrom;
  final Duration duration;
  final double radius;
  final EdgeInsets padding;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !open,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: duration,
                child: Semantics(
                  button: onDismiss != null,
                  label: onDismiss != null ? dismissLabel : null,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: const ColoredBox(color: AppColors.scrim),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: open ? 1 : 0),
                duration: duration,
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, riseFrom * (1 - t)), child: child),
                ),
                child: Container(
                  padding: padding.copyWith(
                    bottom: padding.bottom + MediaQuery.paddingOf(context).bottom * 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.superficie,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.tirador,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
