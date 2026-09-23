import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/illustrations/lapiz_mascota.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/text_field.dart';

/// 2 · Bienvenida: el lápiz saluda y pregunta cómo llamarte.
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final _nombre = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final navigator = Navigator.of(context);
    await context.repo.guardarNombre(_nombre.text);
    navigator.pushNamed(AppRoutes.proteccion);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _nombre.text.trim();
    final tieneNombre = nombre.isNotEmpty;
    final burbuja = tieneNombre
        ? '¡Mucho gusto, $nombre! Así te voy a saludar cada vez que abras tu cajón.'
        : '¡Hola! Soy el lápiz de Tu Cajón. ¿Cómo quieres que te llamemos?';

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const TcIcon(AppIcons.cajon, size: 22, color: AppColors.titulo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu Cajón',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(20, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Paso 1 de 2', style: AppText.secondary(14)),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Burbuja de 300 px en el diseño (342 − 2×21). Se usa Padding y no
              // SizedBox(width) para que la pantalla calcule bien su alto al desplazarse.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: SpeechBubble(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Semantics(
                      key: ValueKey(tieneNombre),
                      liveRegion: true,
                      child: Text(burbuja, textAlign: TextAlign.center, style: AppText.body(20, height: 1.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(child: LapizMascota.saludando(width: 140)),
              const SizedBox(height: 20),
              TcTextField(
                label: 'Tu nombre o apodo',
                controller: _nombre,
                hint: 'Ej: Marta, Mami, Don Luis',
                height: 60,
                fontSize: 20,
                radius: 16,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_nombre.text.trim().isNotEmpty) _continuar();
                },
              ),
              const SizedBox(height: 12),
              const PrivacyNote(
                'Sin registro. Solo tu nombre, y se queda en tu celular.',
                center: false,
                size: 15,
              ),
              const Spacer(),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Continuar',
                trailingIcon: AppIcons.siguiente,
                disabledLabel: 'Escribe tu nombre para seguir',
                onTap: tieneNombre ? _continuar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
