import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/datos_ejemplo.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/text_field.dart';
import '../inicio/widgets/avatar_perfil.dart';

/// 12 · Nuevo perfil: para guardar papeles de Mamá, los hijos o la mascota.
class AgregarPerfilScreen extends StatefulWidget {
  const AgregarPerfilScreen({super.key});

  @override
  State<AgregarPerfilScreen> createState() => _AgregarPerfilScreenState();
}

class _AgregarPerfilScreenState extends State<AgregarPerfilScreen> {
  final _nombre = TextEditingController();
  TipoPerfil _tipo = TipoPerfil.persona;
  Color _color = DatosEjemplo.coloresPerfil[1].$1;

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

  Future<void> _crear() async {
    final navigator = Navigator.of(context);
    await context.repo.crearPerfil(nombre: _nombre.text, tipo: _tipo, color: _color);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _nombre.text.trim();
    final vistaPrevia = Perfil(
      id: 'vista',
      nombre: nombre,
      inicial: nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
      color: _color,
      tipo: _tipo,
    );

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(title: 'Nuevo perfil', backLabel: 'Cancelar'),
            Expanded(
              child: NoScrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  children: [
                    Center(child: CirculoPerfil(perfil: vistaPrevia, relleno: true, size: 96, fontSize: 36)),
                    const SizedBox(height: 10),
                    Text(
                      'Así se verá en tu cajón',
                      textAlign: TextAlign.center,
                      style: AppText.secondary(15),
                    ),
                    const SizedBox(height: 22),
                    TcTextField(
                      label: '¿Cómo se llama?',
                      controller: _nombre,
                      hint: 'Ej: Mamá, Papá, Firulais',
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 22),
                    Text('¿Qué tipo de perfil es?', style: AppText.bold(16)),
                    const SizedBox(height: 10),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: _BotonTipo(
                            icono: AppIcons.persona,
                            etiqueta: 'Persona',
                            activo: _tipo == TipoPerfil.persona,
                            onTap: () => setState(() => _tipo = TipoPerfil.persona),
                          ),
                        ),
                        Expanded(
                          child: _BotonTipo(
                            icono: AppIcons.huellita,
                            etiqueta: 'Mascota',
                            activo: _tipo == TipoPerfil.mascota,
                            onTap: () => setState(() => _tipo = TipoPerfil.mascota),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('Color del perfil', style: AppText.bold(16)),
                    const SizedBox(height: 10),
                    Row(
                      spacing: 12,
                      children: [
                        for (final (color, nombreColor) in DatosEjemplo.coloresPerfil)
                          Semantics(
                            button: true,
                            selected: color == _color,
                            label: nombreColor,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => setState(() => _color = color),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: color == _color
                                      ? [
                                          BoxShadow(color: color, spreadRadius: 5),
                                          const BoxShadow(color: AppColors.fondo, spreadRadius: 3),
                                        ]
                                      : const [],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primarioSuave,
                        borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: TcIcon(AppIcons.candado, size: 22, color: AppColors.primario),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este perfil se guarda cifrado en este mismo celular, junto con el tuyo. No se crea ninguna cuenta nueva ni se pide el celular de nadie más.',
                              style: AppText.body(15, color: AppColors.primarioTextoSuave, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                PrimaryButton(
                  label: 'Crear perfil',
                  icon: AppIcons.mas,
                  disabledLabel: 'Escribe un nombre para seguir',
                  onTap: nombre.isEmpty ? null : _crear,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({required this.icono, required this.etiqueta, required this.activo, required this.onTap});

  final String icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = activo ? Colors.white : AppColors.texto;
    return TcTap(
      onTap: onTap,
      selected: activo,
      color: activo ? AppColors.primario : AppColors.superficie,
      radius: 18,
      shadow: activo ? AppDecor.sombraColor(AppColors.primario) : AppDecor.sombra,
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          TcIcon(icono, size: 20, color: fg),
          Text(etiqueta, style: AppText.bold(16, color: fg)),
        ],
      ),
    );
  }
}
