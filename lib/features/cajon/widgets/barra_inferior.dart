import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/tc_icon.dart';
import '../../../shared/widgets/tc_tap.dart';
import '../cajon_shell.dart';

/// Barra inferior flotante en forma de píldora blanca: Mi cajón · (+) · Avisos.
///
/// La pestaña activa se expande y muestra su nombre sobre un fondo del
/// acento suave; las demás muestran solo el ícono.
class BarraInferior extends StatelessWidget {
  const BarraInferior({
    super.key,
    required this.actual,
    required this.onInicio,
    required this.onAvisos,
    required this.onAgregar,
    this.avisosPendientes = 2,
  });

  final CajonTab actual;
  final VoidCallback onInicio;
  final VoidCallback onAvisos;
  final VoidCallback onAgregar;
  final int avisosPendientes;

  static const alto = 68.0;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + abajo * 0.6),
      child: Semantics(
        container: true,
        label: 'Menú principal',
        child: Container(
          height: alto,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(alto / 2),
            boxShadow: const [BoxShadow(color: Color(0x262B3A8C), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: _ItemTab(
                    icono: AppIcons.cajon,
                    etiqueta: 'Mi cajón',
                    activo: actual == CajonTab.inicio,
                    onTap: onInicio,
                  ),
                ),
              ),
              _BotonAgregar(onTap: onAgregar),
              Expanded(
                child: Center(
                  child: _ItemTab(
                    icono: AppIcons.campana,
                    etiqueta: 'Avisos',
                    activo: actual == CajonTab.avisos,
                    onTap: onAvisos,
                    contador: actual == CajonTab.avisos ? 0 : avisosPendientes,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTab extends StatelessWidget {
  const _ItemTab({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.contador = 0,
  });

  final String icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;
  final int contador;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.primario : AppColors.textoSecundario;
    // El nombre solo se muestra si cabe completo (pantallas angostas o letra grande).
    return LayoutBuilder(
      builder: (context, c) => _contenido(color, c.maxWidth >= 72 + _anchoEtiqueta(context)),
    );
  }

  double _anchoEtiqueta(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: etiqueta, style: AppText.bold(14)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final ancho = tp.width;
    tp.dispose();
    return ancho;
  }

  Widget _contenido(Color color, bool mostrarEtiqueta) {
    return Semantics(
      selected: activo,
      button: true,
      label: contador > 0 ? '$etiqueta, $contador nuevos' : etiqueta,
      excludeSemantics: true,
      child: TcTap(
        onTap: onTap,
        radius: 24,
        color: activo ? AppColors.primarioSuave : Colors.transparent,
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: activo ? 16 : 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  TcIcon(icono, size: 24, color: color, strokeWidth: 2),
                  if (contador > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.rojo,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.superficie, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text('$contador', style: AppText.bold(10, color: Colors.white)),
                      ),
                    ),
                ],
              ),
              if (activo && mostrarEtiqueta) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bold(14, color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonAgregar extends StatelessWidget {
  const _BotonAgregar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: AppColors.primario,
      radius: 18,
      width: 52,
      height: 52,
      shadow: AppDecor.sombraColor(AppColors.primario),
      semanticLabel: 'Agregar documento',
      child: const Center(child: TcIcon(AppIcons.mas, size: 26, color: Colors.white, strokeWidth: 2.4)),
    );
  }
}
