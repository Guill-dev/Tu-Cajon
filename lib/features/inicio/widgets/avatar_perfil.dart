import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/perfil.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../shared/widgets/tc_icon.dart';

/// Ancho de las tarjetas de perfil.
const _ancho = 112.0;

/// Tarjeta de perfil (como "Popular category" en la referencia): la
/// seleccionada va rellena del color del perfil; las demás, blancas.
class TarjetaPerfil extends StatelessWidget {
  const TarjetaPerfil({
    super.key,
    required this.perfil,
    required this.documentos,
    required this.seleccionado,
    required this.onTap,
  });

  final Perfil perfil;
  final int documentos;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = seleccionado ? Colors.white : AppColors.texto;
    final sub = seleccionado ? Colors.white.withValues(alpha: 0.85) : AppColors.textoSecundario;
    return Semantics(
      button: true,
      selected: seleccionado,
      label: 'Perfil ${perfil.nombre}, $documentos documentos',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: _ancho,
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
          decoration: BoxDecoration(
            color: seleccionado ? perfil.color : AppColors.superficie,
            borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
            boxShadow: seleccionado ? AppDecor.sombraColor(perfil.color) : AppDecor.sombra,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CirculoPerfil(perfil: perfil, sobreColor: seleccionado, size: 52, fontSize: 20),
              const SizedBox(height: 12),
              Text(
                perfil.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bold(15, color: fg),
              ),
              const SizedBox(height: 2),
              Text(
                documentos == 1 ? '1 documento' : '$documentos documentos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(12, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo del perfil con su inicial (o una huellita si es mascota).
///
/// Sobre fondo blanco usa un tono suave del color del perfil; con
/// [sobreColor] (tarjeta seleccionada) usa blanco translúcido. [relleno]
/// pinta el círculo con el color pleno (vista previa al crear un perfil).
class CirculoPerfil extends StatelessWidget {
  const CirculoPerfil({
    super.key,
    required this.perfil,
    this.sobreColor = false,
    this.relleno = false,
    this.size = 56,
    this.fontSize = 20,
  });

  final Perfil perfil;
  final bool sobreColor;
  final bool relleno;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final Color fondo;
    final Color fg;
    if (relleno) {
      fondo = perfil.color;
      fg = Colors.white;
    } else if (sobreColor) {
      fondo = Colors.white.withValues(alpha: 0.22);
      fg = Colors.white;
    } else {
      fondo = perfil.color.withValues(alpha: 0.14);
      fg = perfil.color;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: perfil.tipo == TipoPerfil.mascota
          ? TcIcon(AppIcons.huellita, size: size * 0.46, color: fg, filled: true)
          : Text(perfil.inicial, style: AppText.display(fontSize, color: fg, height: 1)),
    );
  }
}

/// Tarjeta punteada "+ Nuevo" que abre la creación de perfil.
class BotonNuevoPerfil extends StatelessWidget {
  const BotonNuevoPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nuevo perfil',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.nuevoPerfil),
        behavior: HitTestBehavior.opaque,
        child: DashedBorder(
          width: _ancho,
          radius: AppDecor.radioTarjeta,
          color: AppColors.bordePunteado,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const TcIcon(AppIcons.mas, size: 24, color: AppColors.primario, strokeWidth: 2.2),
              ),
              const SizedBox(height: 12),
              Text('Nuevo', maxLines: 1, style: AppText.bold(15, color: AppColors.primario)),
              const SizedBox(height: 2),
              Text('perfil', maxLines: 1, style: AppText.body(12, color: AppColors.textoSecundario)),
            ],
          ),
        ),
      ),
    );
  }
}
