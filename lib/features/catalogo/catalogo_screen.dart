import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_tap.dart';
import '../cajon/cajon_shell.dart';

/// Solo para desarrollo: lista de las 12 pantallas del diseño para abrir
/// cualquiera directamente. Se abre manteniendo presionada la pantalla de carga.
class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  static const _pantallas = <(String, String, Object?)>[
    ('1 · Carga', AppRoutes.carga, null),
    ('2 · Bienvenida', AppRoutes.bienvenida, null),
    ('3 · La llave del cajón', AppRoutes.proteccion, null),
    ('4 · Abrir el cajón', AppRoutes.desbloqueo, null),
    ('5 · Mi cajón', AppRoutes.cajon, CajonTab.inicio),
    ('6 · Documento', AppRoutes.detalle, null),
    ('7 · Avisos', AppRoutes.cajon, CajonTab.avisos),
    ('8 · Agregar documento', AppRoutes.agregar, null),
    ('9 · Escanear', AppRoutes.escanear, null),
    ('10 · Guardar', AppRoutes.guardar, null),
    ('11 · Pregúntale a tu cajón', AppRoutes.preguntar, null),
    ('12 · Nuevo perfil', AppRoutes.nuevoPerfil, null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(title: 'Pantallas (desarrollo)'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _pantallas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final (titulo, ruta, args) = _pantallas[i];
                  return TcTap(
                    onTap: () => Navigator.of(context).pushNamed(ruta, arguments: args),
                    color: AppColors.superficie,
                    radius: 20,
                    shadow: AppDecor.sombra,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Text(titulo, style: AppText.bold(16)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlineButtonTc(
                label: 'Borrar todo y cargar datos de ejemplo',
                icon: AppIcons.reemplazar,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await context.repo.restablecerEjemplo();
                  messenger.showSnackBar(const SnackBar(content: Text('Datos de ejemplo cargados.')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
