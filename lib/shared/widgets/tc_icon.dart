import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Dibuja un ícono de trazo del diseño (viewBox 24×24).
///
/// [path] es el `d` de [AppIcons]. [extra] permite sumar elementos SVG crudos
/// (por ejemplo puntos rellenos) que usen `currentColor`.
class TcIcon extends StatelessWidget {
  const TcIcon(
    this.path, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.9,
    this.filled = false,
    this.extra = '',
  });

  final String path;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// Si es `true` el trazo se rellena en vez de dibujarse como línea.
  final bool filled;
  final String extra;

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    final paint = filled
        ? 'fill="currentColor" stroke="none"'
        : 'fill="none" stroke="currentColor" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round"';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<path d="$path" $paint/>$extra</svg>';
    return ExcludeSemantics(
      child: SvgPicture.string(
        svg,
        width: size,
        height: size,
        theme: SvgTheme(currentColor: c),
      ),
    );
  }
}
