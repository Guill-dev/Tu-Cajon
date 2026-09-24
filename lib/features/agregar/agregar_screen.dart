import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/archivos/selector_archivos.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../shared/illustrations/lapiz_mascota.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../guardar/guardar_screen.dart';
import '../paginas/paginas_screen.dart';
import 'preparar_pdf.dart';

/// 8 · Agregar documento: escanear, subir un PDF, elegir fotos de la galería
/// o recibirlo por WhatsApp.
class AgregarScreen extends StatefulWidget {
  const AgregarScreen({super.key});

  @override
  State<AgregarScreen> createState() => _AgregarScreenState();
}

class _AgregarScreenState extends State<AgregarScreen> {
  /// Qué se está preparando (p. ej. "Leyendo el PDF…"); `null` si nada.
  String? _ocupado;

  void _avisar(String mensaje) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating));

  /// Explorador de archivos → se revisa que sea un PDF, se cuentan sus
  /// páginas y se dibuja la primera → Guardar.
  Future<void> _subirPdf() async {
    if (_ocupado != null) return;
    final PdfElegido? elegido;
    try {
      elegido = await context.elegirArchivos((s) => s.elegirPdf());
    } catch (e) {
      debugPrint('No se pudo abrir el explorador: $e');
      if (mounted) _avisar('No pudimos abrir tus archivos. Inténtalo de nuevo.');
      return;
    }
    if (!mounted || elegido == null) return;

    final cerrojo = context.cerrojo;
    setState(() => _ocupado = 'Leyendo el PDF…');
    final PdfSubido listo;
    try {
      listo = await prepararPdf(elegido);
    } on PdfRechazado catch (e) {
      if (mounted) {
        setState(() => _ocupado = null);
        _avisar(e.mensaje);
      }
      return;
    }
    // Si la persona salió mientras se leía, Guardar no se abre encima de la llave.
    await cerrojo.esperarAbierto();
    if (!mounted) return;
    setState(() => _ocupado = null);
    Navigator.of(context).pushNamed(AppRoutes.guardar, arguments: listo);
  }

  /// Galería (una o varias fotos) → Tus páginas, para revisarlas.
  Future<void> _elegirFotos() async {
    if (_ocupado != null) return;
    final List<Uint8List> fotos;
    try {
      fotos = await context.elegirArchivos((s) => s.elegirFotos());
    } catch (e) {
      debugPrint('No se pudo abrir la galería: $e');
      if (mounted) _avisar('No pudimos abrir tu galería. Inténtalo de nuevo.');
      return;
    }
    if (!mounted || fotos.isEmpty) return;
    Navigator.of(context).pushNamed(AppRoutes.paginas, arguments: EntradaPaginas(nuevas: fotos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          SafeArea(child: _contenido(context)),
          if (_ocupado != null) Positioned.fill(child: _Ocupado(mensaje: _ocupado!)),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    return FillScroll(
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
            titulo: 'Subir un PDF',
            texto: 'Búscalo en tu celular: Descargas, Drive, el correo…',
            onTap: _subirPdf,
          ),
          const SizedBox(height: 12),
          _Opcion(
            icono: AppIcons.galeria,
            titulo: 'Fotos de la galería',
            texto: 'Elige una o varias. Las puedes recortar, mejorar y volver PDF.',
            onTap: _elegirFotos,
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
                        'En WhatsApp, toca Compartir y elige Tu Cajón. También sirve desde Gmail, Drive o tu galería.',
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
    );
  }
}

/// Velo con una ruedita mientras se lee el PDF elegido.
class _Ocupado extends StatelessWidget {
  const _Ocupado({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: AppDecor.tarjeta(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primario),
              ),
              Flexible(
                child: Semantics(liveRegion: true, child: Text(mensaje, style: AppText.bold(16))),
              ),
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
