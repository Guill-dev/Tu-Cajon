import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../shared/illustrations/lapiz_mascota.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';

/// 8 · Agregar documento: escanear, subir un archivo o recibirlo por WhatsApp.
class AgregarScreen extends StatelessWidget {
  const AgregarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-8, 0),
                  child: const BackButtonTc(semanticLabel: 'Volver a mi cajón'),
                ),
              ),
              const SizedBox(height: 2),
              const TwoToneTitle('Agregar documento', size: 32),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const LapizMascota.quieto(width: 68),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: SpeechBubble(
                        tail: BubbleTail.left,
                        radius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Text(
                          '¿Cómo tienes tu documento? Elige una opción.',
                          style: AppText.body(18, height: 1.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Opcion(
                icono: AppIcons.camara,
                titulo: 'Escanear con la cámara',
                texto: 'Le tomas foto al papel y lo convertimos en PDF.',
                destacada: true,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.escanear),
              ),
              const SizedBox(height: 12),
              _Opcion(
                icono: AppIcons.subirArchivo,
                titulo: 'Subir un archivo',
                texto: 'Un PDF o una foto que ya tengas en el celular.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.guardar),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.verdeSuave,
                  borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.superficie, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const TcIcon(AppIcons.whatsapp, size: 22, color: AppColors.verde),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            '¿Te lo mandaron por WhatsApp?',
                            style: AppText.bold(16, color: AppColors.verdeTexto),
                          ),
                          Text(
                            'Abre el archivo en WhatsApp, toca Compartir y elige Tu Cajón. Llega directo aquí.',
                            style: AppText.body(15, color: AppColors.verdeTextoSuave, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              const PrivacyNote('Todo lo que agregas se guarda cifrado en este celular'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
    this.destacada = false,
  });

  final String icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    // La opción destacada va rellena del acento, como la categoría activa de la referencia.
    final fg = destacada ? Colors.white : AppColors.texto;
    return TcTap(
      onTap: onTap,
      color: destacada ? AppColors.primario : AppColors.superficie,
      radius: AppDecor.radioTarjeta,
      shadow: destacada ? AppDecor.sombraColor(AppColors.primario) : AppDecor.sombra,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: destacada ? Colors.white.withValues(alpha: 0.2) : AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: TcIcon(icono, size: 30, color: destacada ? Colors.white : AppColors.primario),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(titulo, style: AppText.bold(18, color: fg)),
                Text(
                  texto,
                  style: AppText.body(
                    14,
                    color: destacada ? Colors.white.withValues(alpha: 0.88) : AppColors.textoSecundario,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TcIcon(
            AppIcons.siguiente,
            size: 22,
            strokeWidth: 2.2,
            color: destacada ? Colors.white : AppColors.textoSecundario,
          ),
        ],
      ),
    );
  }
}
