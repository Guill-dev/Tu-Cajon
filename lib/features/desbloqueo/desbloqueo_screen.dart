import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/illustrations/cajon_mini.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pulse_ring.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';

/// 4 · Abrir el cajón: lo que ve quien vuelve a la app.
/// Botón de huella con dos anillos latiendo (2 s, desfasados 1 s).
class DesbloqueoScreen extends StatefulWidget {
  const DesbloqueoScreen({super.key});

  @override
  State<DesbloqueoScreen> createState() => _DesbloqueoScreenState();
}

class _DesbloqueoScreenState extends State<DesbloqueoScreen> {
  late final Stream<String> _nombre = context.repo.vigilarNombre();
  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();

  void _abrir(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.cajon, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _nombre,
      builder: (context, snapNombre) => StreamBuilder(
        stream: _perfiles,
        builder: (context, snapPerfiles) {
          final nombre = snapNombre.data ?? '';
          final total = snapPerfiles.data?.firstWhere((p) => p.esPropio).documentos ?? 0;
          return _pantalla(context, nombre, total);
        },
      ),
    );
  }

  Widget _pantalla(BuildContext context, String nombre, int total) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 40),
          child: Column(
            children: [
              const CajonMini(width: 104),
              const SizedBox(height: 32),
              Semantics(
                header: true,
                label: 'Hola de nuevo, $nombre',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text('Hola de nuevo,', textAlign: TextAlign.center, style: AppText.displayLight(32)),
                    Text(nombre, textAlign: TextAlign.center, style: AppText.display(32)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tu cajón está cerrado con llave.',
                textAlign: TextAlign.center,
                style: AppText.body(18, color: AppColors.textoTerciario, height: 1.45),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              SizedBox(
                width: 136,
                height: 136,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const PulseRing(size: 136, color: AppColors.pulso),
                    const PulseRing(size: 136, color: AppColors.pulso, delay: Duration(seconds: 1)),
                    TcTap(
                      onTap: () => _abrir(context),
                      color: AppColors.primario,
                      radius: 68,
                      width: 136,
                      height: 136,
                      semanticLabel: 'Abrir con huella o rostro',
                      child: const Center(
                        child: TcIcon(AppIcons.huella, size: 72, strokeWidth: 1.3, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Toca para abrir', style: AppText.bold(19)),
              const SizedBox(height: 4),
              Text('Con tu huella o tu rostro', style: AppText.secondary(15)),
              const SizedBox(height: 28),
              TcTap(
                onTap: () => _abrir(context),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'Usar el PIN del celular',
                    style: AppText.bold(
                      17,
                      color: AppColors.primario,
                    ).copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.primario),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              PrivacyNote(
                total == 1
                    ? '1 documento guardado solo en este celular'
                    : '$total documentos guardados solo en este celular',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
