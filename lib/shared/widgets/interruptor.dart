import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Interruptor redondo del diseño (52×32, perilla que se desliza en 0.15 s).
class Interruptor extends StatelessWidget {
  const Interruptor({super.key, required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 52,
      height: 32,
      decoration: BoxDecoration(
        color: activo ? AppColors.primario : AppColors.switchApagado,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
