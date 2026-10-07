import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/archivos/selector_archivos.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/datos_ejemplo.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/text_field.dart';
import '../inicio/widgets/avatar_perfil.dart';
import 'ajustar_foto.dart';

/// 12 · Nuevo perfil: para guardar papeles de Mamá, los hijos o la mascota.
///
/// Con [perfil], lo edita: su nombre, tipo, color o foto, y se puede
/// eliminar. Del perfil propio ("Tú") solo se cambian el color y la foto, y
/// no se puede eliminar.
class AgregarPerfilScreen extends StatefulWidget {
  const AgregarPerfilScreen({super.key, this.perfil});

  final Perfil? perfil;

  @override
  State<AgregarPerfilScreen> createState() => _AgregarPerfilScreenState();
}

class _AgregarPerfilScreenState extends State<AgregarPerfilScreen> {
  late final _nombre = TextEditingController(text: widget.perfil?.nombre ?? '');
  late TipoPerfil _tipo = widget.perfil?.tipo ?? TipoPerfil.persona;
  late Color _color = widget.perfil?.color ?? DatosEjemplo.coloresPerfil[1].$1;
  late Uint8List? _foto = widget.perfil?.foto;
  bool _ocupado = false;

  bool get _editando => widget.perfil != null;
  bool get _propio => widget.perfil?.esPropio ?? false;

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

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    final navigator = Navigator.of(context);
    final repo = context.repo;
    final perfil = widget.perfil;
    if (perfil == null) {
      await repo.crearPerfil(nombre: _nombre.text, tipo: _tipo, color: _color, foto: _foto);
    } else {
      await repo.editarPerfil(perfil.id, nombre: _nombre.text, tipo: _tipo, color: _color, foto: _foto);
    }
    navigator.pop();
  }

  /// Elige una foto de la galería y la acomoda en el círculo.
  Future<void> _elegirFoto() async {
    final elegida = await context.elegirArchivos((s) => s.elegirUnaFoto());
    if (elegida == null || !mounted) return;
    final lista = await ajustarFotoDePerfil(context, elegida);
    if (lista != null && mounted) setState(() => _foto = lista);
  }

  /// Pregunta otra vez (y qué hacer con sus documentos) antes de eliminar.
  Future<void> _eliminar() async {
    final perfil = widget.perfil!;
    final navigator = Navigator.of(context);
    final repo = context.repo;
    final eleccion = await confirmarEliminarPerfil(
      context,
      nombre: perfil.nombre,
      documentos: perfil.documentos,
    );
    if (eleccion == null || !mounted) return;
    setState(() => _ocupado = true);
    await repo.eliminarPerfil(perfil.id, conDocumentos: eleccion == AlEliminarPerfil.eliminarDocumentos);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _nombre.text.trim();
    final vistaPrevia = Perfil(
      id: 'vista',
      nombre: nombre,
      inicial: _propio
          ? widget.perfil!.inicial
          : (nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase()),
      color: _color,
      tipo: _tipo,
      foto: _foto,
    );
    final titulo = !_editando
        ? 'Nuevo perfil'
        : _propio
        ? 'Tu perfil'
        : 'Editar perfil';

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackHeader(title: titulo, backLabel: 'Cancelar'),
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
                    if (!_propio) ...[
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
                    ],
                    const SizedBox(height: 22),
                    Text('Foto del perfil', style: AppText.bold(16)),
                    const SizedBox(height: 4),
                    Text(
                      'Elige un color o una foto de tu galería.',
                      style: AppText.secondary(14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _OpcionFoto(foto: _foto, onTap: _elegirFoto),
                        for (final (color, nombreColor) in DatosEjemplo.coloresPerfil)
                          _OpcionColor(
                            color: color,
                            nombre: nombreColor,
                            elegido: _foto == null && color.toARGB32() == _color.toARGB32(),
                            // Un color en vez de la foto.
                            onTap: () => setState(() {
                              _color = color;
                              _foto = null;
                            }),
                          ),
                      ],
                    ),
                    if (_editando && !_propio) ...[
                      const SizedBox(height: 22),
                      TcTap(
                        onTap: _ocupado ? null : _eliminar,
                        color: AppColors.superficie,
                        radius: 18,
                        shadow: AppDecor.sombra,
                        minHeight: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 8,
                          children: [
                            TcIcon(AppIcons.basura, size: 20, color: AppColors.rojo),
                            Text('Eliminar perfil', style: AppText.bold(16, color: AppColors.rojo)),
                          ],
                        ),
                      ),
                    ],
                    if (!_propio) ...[
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
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
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
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                PrimaryButton(
                  label: _editando ? 'Guardar cambios' : 'Crear perfil',
                  icon: _editando ? AppIcons.check : AppIcons.mas,
                  disabledLabel: _ocupado ? 'Guardando…' : 'Escribe un nombre para seguir',
                  onTap: _ocupado || (!_propio && nombre.isEmpty) ? null : _guardar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Anillo de la opción elegida (color o foto).
List<BoxShadow> _anillo(Color color) => [
  BoxShadow(color: color, spreadRadius: 5),
  BoxShadow(color: AppColors.fondo, spreadRadius: 3),
];

class _OpcionColor extends StatelessWidget {
  const _OpcionColor({required this.color, required this.nombre, required this.elegido, required this.onTap});

  final Color color;
  final String nombre;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Color $nombre',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: elegido ? _anillo(color) : const [],
          ),
        ),
      ),
    );
  }
}

/// "Foto": abre la galería. Si ya hay una, se ve pequeña y elegida.
class _OpcionFoto extends StatelessWidget {
  const _OpcionFoto({required this.foto, required this.onTap});

  final Uint8List? foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foto = this.foto;
    return Semantics(
      button: true,
      selected: foto != null,
      label: foto == null ? 'Elegir una foto de la galería' : 'Cambiar la foto',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primarioSuave,
            shape: BoxShape.circle,
            boxShadow: foto != null ? _anillo(AppColors.primario) : const [],
          ),
          alignment: Alignment.center,
          child: foto == null
              ? TcIcon(AppIcons.galeria, size: 22, color: AppColors.primario)
              : Image.memory(foto, fit: BoxFit.cover, width: 44, height: 44, cacheWidth: 150),
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
    final fg = activo ? AppColors.sobrePrimario : AppColors.texto;
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
