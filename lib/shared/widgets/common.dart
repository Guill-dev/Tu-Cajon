import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import 'buttons.dart';
import 'tc_icon.dart';

/// Línea pequeña con candado: "Guardado solo en tu celular", etc.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote(
    this.text, {
    super.key,
    this.center = true,
    this.size = 14,
    this.color = AppColors.textoSecundario,
  });

  final String text;
  final bool center;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: AppText.body(size, color: color, height: 1.4),
      textAlign: center ? TextAlign.center : TextAlign.start,
    );
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: center ? 0 : 2),
          child: TcIcon(AppIcons.candado, size: size + 2, color: color),
        ),
        const SizedBox(width: 6),
        if (center) Flexible(child: label) else Expanded(child: label),
      ],
    );
  }
}

/// Título en dos tonos, como en la referencia ("Search / **your book**"):
/// la primera palabra en gris claro y el resto en negro grueso, en dos líneas.
///
/// Si el texto es una sola palabra, sale completo en grueso. Se puede forzar
/// la división con [ligero] y [fuerte].
class TwoToneTitle extends StatelessWidget {
  const TwoToneTitle(
    this.texto, {
    super.key,
    this.size = 30,
    this.ligero,
    this.fuerte,
    this.maxLinesFuerte = 2,
  });

  final String texto;
  final double size;
  final String? ligero;
  final String? fuerte;
  final int maxLinesFuerte;

  @override
  Widget build(BuildContext context) {
    var a = ligero;
    var b = fuerte;
    if (a == null && b == null) {
      final i = texto.indexOf(' ');
      if (i > 0) {
        a = texto.substring(0, i);
        b = texto.substring(i + 1);
      } else {
        b = texto;
      }
    }
    return Semantics(
      header: true,
      label: [a, b].whereType<String>().join(' '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a != null && a.isNotEmpty)
            Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.displayLight(size)),
          if (b != null)
            Text(b, maxLines: maxLinesFuerte, overflow: TextOverflow.ellipsis, style: AppText.display(size)),
        ],
      ),
    );
  }
}

/// Encabezado de las pantallas internas: flecha de volver arriba y debajo el
/// título grande en dos tonos (como "Choose / your book").
class BackHeader extends StatelessWidget {
  const BackHeader({
    super.key,
    required this.title,
    this.titleSize = 30,
    this.onBack,
    this.backLabel = 'Volver',
    this.trailing,
    this.ligero,
    this.fuerte,
  });

  final String title;
  final double titleSize;
  final VoidCallback? onBack;
  final String backLabel;
  final Widget? trailing;
  final String? ligero;
  final String? fuerte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackButtonTc(onTap: onBack, semanticLabel: backLabel),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TwoToneTitle(title, size: titleSize, ligero: ligero, fuerte: fuerte),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta redondeada pequeña (badges: "Pronto", "Con IA", "Vence en…").
class TcBadge extends StatelessWidget {
  const TcBadge({super.key, required this.label, required this.bg, required this.fg, this.icon});

  final String label;
  final Color bg;
  final Color fg;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[TcIcon(icon!, size: 14, color: fg), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bold(13, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra inferior fija con borde arriba (para botones de acción al pie).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + MediaQuery.paddingOf(context).bottom * 0.5),
      color: AppColors.fondo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: children,
      ),
    );
  }
}

/// Burbuja de diálogo blanca con "colita" (la usa el lápiz).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.tail = BubbleTail.bottom,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    this.radius = 22,
  });

  final Widget child;
  final BubbleTail tail;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const tailSize = 16.0;
    final tailWidget = Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: tailSize,
        height: tailSize,
        decoration: BoxDecoration(color: AppColors.superficie),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: padding,
          decoration: AppDecor.tarjeta(radius: radius),
          child: child,
        ),
        if (tail == BubbleTail.bottom)
          Positioned(bottom: -9, left: 0, right: 0, child: Center(child: tailWidget))
        else
          Positioned(left: -8, bottom: 16, child: tailWidget),
      ],
    );
  }
}

enum BubbleTail { bottom, left }

/// Columna que ocupa toda la altura disponible (para usar `Spacer`) pero que
/// se desplaza si no cabe, p. ej. con el teclado abierto o letra grande.
class FillScroll extends StatelessWidget {
  const FillScroll({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverFillRemaining(hasScrollBody: false, child: child),
        ),
      ],
    );
  }
}

/// Oculta la barra de desplazamiento (como `.tc-noscroll` del diseño).
class NoScrollbar extends StatelessWidget {
  const NoScrollbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
  }
}
