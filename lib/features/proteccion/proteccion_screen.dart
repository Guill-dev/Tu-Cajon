import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/motion.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../core/seguridad/llave_celular.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pulse_ring.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/toast.dart';

enum _Paso { intro, escaneando, listo }

/// 3 · La llave del cajón: explica la protección y activa la llave.
///
/// "Activar la llave" abre la hoja con el sensor latiendo y pide al celular
/// su propio diálogo de desbloqueo (huella, rostro, PIN o patrón). Si la
/// persona lo confirma, pasa a "¡Listo!".
class ProteccionScreen extends StatefulWidget {
  const ProteccionScreen({super.key});

  /// Cuánto se ve la hoja con la huella latiendo antes del diálogo del celular.
  static const antesDelDialogo = Duration(milliseconds: 1000);

  @override
  State<ProteccionScreen> createState() => _ProteccionScreenState();
}

class _ProteccionScreenState extends State<ProteccionScreen> with ToastMixin {
  _Paso _paso = _Paso.intro;

  /// Sube con cada intento: si la persona cancela y vuelve a activar, la
  /// respuesta del intento viejo se ignora.
  int _intento = 0;

  Future<void> _activar() async {
    final intento = ++_intento;
    setState(() => _paso = _Paso.escaneando);
    // Primero se luce la huella latiendo; luego sale el diálogo del celular.
    await Future<void>.delayed(ProteccionScreen.antesDelDialogo);
    if (!mounted || intento != _intento || _paso != _Paso.escaneando) return;
    final resultado = await context.llave.abrir('Confirma que eres tú para ponerle llave a tu cajón');
    if (!mounted || intento != _intento || _paso != _Paso.escaneando) return;
    if (resultado == ResultadoLlave.abierto) {
      setState(() => _paso = _Paso.listo);
    } else {
      setState(() => _paso = _Paso.intro);
      final aviso = resultado.aviso;
      if (aviso != null) showToast(aviso, duration: const Duration(seconds: 5));
    }
  }

  void _cancelar() {
    _intento++;
    setState(() => _paso = _Paso.intro);
  }

  Future<void> _abrirCajon() async {
    final navigator = Navigator.of(context);
    context.cerrojo.entrar();
    await context.repo.activarLlave();
    navigator.pushNamedAndRemoveUntil(AppRoutes.cajon, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == _Paso.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _paso == _Paso.escaneando) _cancelar();
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            SafeArea(
              child: FillScroll(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Transform.translate(offset: const Offset(-10, 0), child: const BackButtonTc()),
                          const Spacer(),
                          Text('Paso 2 de 2', style: AppText.secondary(14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(child: _SelloHuella()),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      label: 'Tu cajón tiene llave',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text('Tu cajón', textAlign: TextAlign.center, style: AppText.displayLight(32)),
                          Text('tiene llave', textAlign: TextAlign.center, style: AppText.display(32)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Se abre con lo mismo que desbloquea tu celular: tu huella, tu rostro o tu PIN.',
                        textAlign: TextAlign.center,
                        style: AppText.body(18, color: AppColors.textoTerciario, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _ListaGarantias(),
                    const Spacer(),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Activar la llave', icon: AppIcons.huellaBoton, onTap: _activar),
                  ],
                ),
              ),
            ),
            TcSheet(
              open: _paso != _Paso.intro,
              riseFrom: 40,
              duration: const Duration(milliseconds: 280),
              radius: 28,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _paso == _Paso.listo
                    ? _HojaListo(key: const ValueKey('listo'), onAbrir: _abrirCajon)
                    : _HojaEscaneando(key: const ValueKey('scan'), onCancelar: _cancelar),
              ),
            ),
            TcToast(message: toastMessage, bottom: 104, icon: AppIcons.candado),
          ],
        ),
      ),
    );
  }
}

class _SelloHuella extends StatelessWidget {
  const _SelloHuella();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const TcIcon(AppIcons.huella, size: 88, strokeWidth: 1.3, color: AppColors.primario),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primario,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.fondo, width: 4),
              ),
              alignment: Alignment.center,
              child: const TcIcon(AppIcons.candado, size: 22, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaGarantias extends StatelessWidget {
  const _ListaGarantias();

  @override
  Widget build(BuildContext context) {
    const items = [
      (AppIcons.celular, 'Todo se queda en este celular', 'No subimos tus documentos a internet.'),
      (AppIcons.escudo, 'Blindado por dentro', 'Tus archivos quedan cifrados en la memoria del teléfono.'),
      (AppIcons.sinRegistro, 'Sin registro', 'No te pedimos correo, número ni contraseña nueva.'),
    ];
    return Container(
      decoration: AppDecor.tarjeta(),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.divisor),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarioSuave,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: TcIcon(items[i].$1, size: 22, color: AppColors.primario),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(items[i].$2, style: AppText.bold(16)),
                        Text(items[i].$3, style: AppText.secondary(14, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HojaEscaneando extends StatelessWidget {
  const _HojaEscaneando({super.key, required this.onCancelar});

  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 28),
        SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const PulseRing(
                size: 104,
                color: AppColors.pulso,
                period: Duration(milliseconds: 1500),
                maxScale: 1.55,
                startOpacity: 0.55,
              ),
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const TcIcon(AppIcons.huella, size: 60, strokeWidth: 1.3, color: AppColors.primario),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Usa tu huella, rostro o PIN', textAlign: TextAlign.center, style: AppText.bold(21)),
        const SizedBox(height: 6),
        Text(
          'Lo mismo con que desbloqueas tu celular',
          textAlign: TextAlign.center,
          style: AppText.secondary(16, height: 1.4),
        ),
        const SizedBox(height: 24),
        SmallButton(label: 'Cancelar', filled: false, onTap: onCancelar),
      ],
    );
  }
}

class _HojaListo extends StatelessWidget {
  const _HojaListo({super.key, required this.onAbrir});

  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        // El check entra rebotando, como en "Abrir el cajón".
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: Motion.reduced(context) ? 1 : 0.4, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, escala, hijo) => Transform.scale(scale: escala, child: hijo),
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(color: AppColors.verdeSuave, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const TcIcon(AppIcons.check, size: 52, color: AppColors.verde),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            '¡Listo! Tu cajón quedó protegido',
            textAlign: TextAlign.center,
            style: AppText.bold(21),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cada vez que entres te pediremos tu huella, rostro o PIN.',
          textAlign: TextAlign.center,
          style: AppText.secondary(16, height: 1.4),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Abrir mi cajón', onTap: onAbrir),
      ],
    );
  }
}
