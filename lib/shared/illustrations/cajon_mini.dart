import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Cómoda pequeña con dos cajones (pantalla "Abrir el cajón"), viewBox 120×110.
class CajonMini extends StatelessWidget {
  const CajonMini({super.key, this.width = 104});

  final double width;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 110">'
      '<ellipse cx="60" cy="104" rx="48" ry="4" fill="#E2D8C8"/>'
      '<rect x="20" y="92" width="7" height="11" rx="2" fill="#6B4128"/>'
      '<rect x="93" y="92" width="7" height="11" rx="2" fill="#6B4128"/>'
      '<rect x="12" y="24" width="96" height="70" rx="5" fill="#8E5B3A"/>'
      '<rect x="6" y="16" width="108" height="10" rx="4" fill="#A56B45"/>'
      '<rect x="32" y="12" width="56" height="5" rx="2" fill="#FBF7EE"/>'
      '<rect x="19" y="32" width="82" height="25" rx="3" fill="#A26A45"/>'
      '<rect x="23" y="36" width="74" height="17" rx="2" fill="none" stroke="#87552F" stroke-width="2.5"/>'
      '<rect x="19" y="62" width="82" height="25" rx="3" fill="#9A6441"/>'
      '<rect x="23" y="66" width="74" height="17" rx="2" fill="none" stroke="#87552F" stroke-width="2.5"/>'
      '<rect x="56" y="38" width="8" height="12" rx="2" fill="#C9A15A"/>'
      '<circle cx="60" cy="42.5" r="1.6" fill="#5A3A22"/>'
      '<rect x="59.3" y="43" width="1.4" height="4" fill="#5A3A22"/>'
      '<circle cx="60" cy="74.5" r="3.2" fill="#C9A15A"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.string(_svg, width: width, height: width * 110 / 120),
    );
  }
}
