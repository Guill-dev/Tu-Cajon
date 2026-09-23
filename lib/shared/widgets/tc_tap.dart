import 'package:flutter/material.dart';

/// Base táctil de la app: una superficie con forma redondeada, borde opcional
/// y efecto de toque. Todos los botones y tarjetas tocables se construyen
/// sobre esto para que se sientan iguales.
class TcTap extends StatelessWidget {
  const TcTap({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.transparent,
    this.radius = 14,
    this.borderRadius,
    this.border,
    this.semanticLabel,
    this.selected,
    this.padding,
    this.width,
    this.height,
    this.minHeight,
    this.shadow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final BorderRadius? borderRadius;
  final BorderSide? border;
  final String? semanticLabel;
  final bool? selected;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// Alto mínimo: crece si el texto es grande (letra ampliada del celular).
  final double? minHeight;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    Widget content = Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: br, side: border ?? BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          padding: padding,
          child: child,
        ),
      ),
    );
    if (shadow != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(borderRadius: br, boxShadow: shadow),
        child: content,
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      selected: selected,
      enabled: onTap != null,
      child: content,
    );
  }
}
