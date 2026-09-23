import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion.dart';

/// El cajón de la pantalla de carga (viewBox 260×300).
///
/// La ilustración está partida en 4 capas SVG apiladas para poder animarlas
/// por separado, igual que en el diseño:
///  1. `_base`: mueble, patas, tapete, adorno y cajón rojo (quieto).
///  2. `_interior`: el fondo del cajón que se "despliega" (scaleY 0.15 → 1).
///  3. `_papeles`: carpeta, cédula y recibo que suben y aparecen.
///  4. `_frente`: el frente azul que baja a su lugar (translateY -38, scale 0.9).
class CajonAnimado extends StatefulWidget {
  const CajonAnimado({super.key, this.width = 240});

  final double width;

  @override
  State<CajonAnimado> createState() => _CajonAnimadoState();
}

class _CajonAnimadoState extends State<CajonAnimado> with SingleTickerProviderStateMixin {
  static const _vbW = 260.0;
  static const _vbH = 300.0;

  // Tiempos del diseño: frente e interior 0.4 s → 1.3 s; papeles 1.05 s → 1.85 s.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  );
  late final Animation<double> _abre = CurvedAnimation(
    parent: _c,
    curve: const Interval(400 / 1850, 1300 / 1850, curve: Motion.suave),
  );
  late final Animation<double> _papeles = CurvedAnimation(
    parent: _c,
    curve: const Interval(1050 / 1850, 1.0, curve: Motion.suave),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.width / _vbW;
    final h = _vbH * s;
    Widget capa(String body) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $_vbW $_vbH">$body</svg>',
      width: widget.width,
      height: h,
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: h,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final a = _abre.value;
            final p = _papeles.value;
            return Stack(
              children: [
                capa(_svgBase),
                // Interior: se despliega desde su borde superior (y = 124).
                Transform(
                  alignment: Alignment.topLeft,
                  origin: Offset(130 * s, 124 * s),
                  transform: Matrix4.diagonal3Values(1, 0.15 + 0.85 * a, 1),
                  child: capa(_svgInterior),
                ),
                // Papeles: suben 36 unidades y aparecen.
                Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Transform.translate(offset: Offset(0, 36 * s * (1 - p)), child: capa(_svgPapeles)),
                ),
                // Frente: baja 38 unidades mientras crece de 0.9 a 1.
                Transform.translate(
                  offset: Offset(0, -38 * s * (1 - a)),
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * a,
                    alignment: Alignment.topLeft,
                    origin: Offset(130 * s, 187 * s),
                    child: capa(_svgFrente),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static final String _svgBase = () {
    final b = StringBuffer()
      ..write('<ellipse cx="130" cy="288" rx="112" ry="9" fill="#E2D8C8"/>')
      ..write('<path d="M46 264 h16 l-3 22 h-10 z" fill="#6B4128"/>')
      ..write('<path d="M198 264 h16 l-3 22 h-10 z" fill="#6B4128"/>')
      ..write('<rect x="24" y="258" width="212" height="9" rx="3" fill="#7A4A2D"/>')
      ..write('<rect x="28" y="112" width="204" height="150" rx="6" fill="#8E5B3A"/>')
      ..write('<rect x="28" y="112" width="10" height="150" fill="#83532F"/>')
      ..write('<rect x="222" y="112" width="10" height="150" fill="#83532F"/>')
      ..write('<rect x="28" y="112" width="204" height="5" fill="#7A4A2D"/>')
      ..write('<rect x="16" y="98" width="228" height="16" rx="5" fill="#FCD116"/>')
      ..write('<rect x="16" y="110" width="228" height="4" rx="2" fill="#D9A812"/>')
      // Tapete de encaje
      ..write('<rect x="68" y="94" width="124" height="8" rx="2" fill="#FBF7EE"/>');
    for (var x = 72; x <= 184; x += 8) {
      b.write('<circle cx="$x" cy="103" r="4.2" fill="#FBF7EE"/>');
    }
    b.write('<circle cx="188" cy="103" r="4.2" fill="#FBF7EE"/>');
    for (var x = 78; x <= 182; x += 13) {
      b.write('<circle cx="$x" cy="98" r="1.4" fill="#E3D8C6"/>');
    }
    b
      // Adorno dorado (la llave) sobre el mueble
      ..write('<ellipse cx="131" cy="81" rx="20" ry="3.5" fill="#8B6B33" opacity="0.3"/>')
      ..write(
        '<path d="M129 51 C 122 46, 121 38, 126 31" fill="none" stroke="#C9A15A" stroke-width="9" stroke-linecap="round"/>',
      )
      ..write(
        '<path d="M129 51 C 124 47, 123 40, 127 33" fill="none" stroke="#E5C888" stroke-width="3" stroke-linecap="round" opacity="0.75"/>',
      )
      ..write(
        '<path d="M131 50 C 142 50, 148 59, 148 67 C 148 76, 140 80, 131 80 C 122 80, 114 76, 114 67 C 114 59, 120 50, 131 50 Z" fill="#C9A15A"/>',
      )
      ..write(
        '<path d="M118 58 C 118 52, 123 51, 126 51 C 122 55, 120 61, 121 68 C 118 65, 117 61, 118 58 Z" fill="#E5C888" opacity="0.85"/>',
      )
      ..write(
        '<path d="M139 72 C 143 68, 145 62, 143 56 C 147 62, 147 71, 141 77 C 140 75, 139 73, 139 72 Z" fill="#8B6B33" opacity="0.5"/>',
      )
      ..write('<circle cx="127" cy="30" r="5.5" fill="#C9A15A"/>')
      ..write('<circle cx="127" cy="30" r="2.4" fill="#4A3117"/>')
      // Cajón rojo de abajo
      ..write('<rect x="42" y="200" width="176" height="50" rx="5" fill="#CE1126"/>')
      ..write(
        '<rect x="48" y="206" width="164" height="38" rx="3" fill="none" stroke="#20201C" stroke-width="2"/>',
      )
      ..write('<circle cx="130" cy="225" r="6" fill="#C9A15A"/>')
      ..write('<circle cx="128" cy="223" r="2" fill="#E5C888"/>')
      // Hueco oscuro del cajón de arriba
      ..write('<rect x="42" y="124" width="176" height="50" rx="4" fill="#3B2618"/>');
    return b.toString();
  }();

  static const _svgInterior =
      '<path d="M42 124 H218 L228 162 H32 Z" fill="#B07A50"/>'
      '<path d="M52 128 H208 L216 162 H44 Z" fill="#C48F66"/>';

  static const _svgPapeles =
      '<path d="M64 110 h30 l6 7 h68 v47 h-104 z" fill="#E0BD78" transform="rotate(-3 116 137)"/>'
      '<g transform="rotate(-8 104 128)">'
      '<rect x="72" y="104" width="64" height="44" rx="3" fill="#FFFFFF" stroke="#D6CEC0"/>'
      '<rect x="78" y="111" width="16" height="21" rx="2" fill="#D9E3E6"/>'
      '<rect x="100" y="113" width="30" height="3" rx="1.5" fill="#C9D2D4"/>'
      '<rect x="100" y="120" width="24" height="3" rx="1.5" fill="#C9D2D4"/>'
      '<rect x="100" y="127" width="28" height="3" rx="1.5" fill="#C9D2D4"/>'
      '<rect x="78" y="138" width="52" height="3" rx="1.5" fill="#E0D9CC"/>'
      '</g>'
      '<g transform="rotate(7 176 128)">'
      '<path d="M156 100 l4 -3 4 3 4 -3 4 3 4 -3 4 3 4 -3 4 3 V162 H156 Z" fill="#FFFDF6" stroke="#DDD5C6"/>'
      '<rect x="162" y="109" width="24" height="2.5" rx="1" fill="#D5CCBC"/>'
      '<rect x="162" y="116" width="18" height="2.5" rx="1" fill="#D5CCBC"/>'
      '<rect x="162" y="123" width="22" height="2.5" rx="1" fill="#D5CCBC"/>'
      '<rect x="162" y="138" width="26" height="3.5" rx="1" fill="#B9AE9B"/>'
      '</g>';

  static const _svgFrente =
      '<rect x="32" y="160" width="196" height="54" rx="6" fill="#003893"/>'
      '<rect x="39" y="167" width="182" height="40" rx="3" fill="none" stroke="#20201C" stroke-width="2"/>'
      '<circle cx="76" cy="187" r="5.5" fill="#C9A15A"/>'
      '<circle cx="74.5" cy="185.5" r="1.8" fill="#E5C888"/>'
      '<circle cx="184" cy="187" r="5.5" fill="#C9A15A"/>'
      '<circle cx="182.5" cy="185.5" r="1.8" fill="#E5C888"/>'
      '<rect x="122" y="176" width="16" height="22" rx="4" fill="#C9A15A"/>'
      '<circle cx="130" cy="184" r="3" fill="#5A3A22"/>'
      '<rect x="128.8" y="185" width="2.4" height="7" rx="1" fill="#5A3A22"/>';
}
