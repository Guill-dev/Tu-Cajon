import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'buttons.dart';
import 'text_field.dart';

/// Diálogo para escribir un nombre nuevo. Devuelve `null` si se cancela.
Future<String?> pedirNombre(BuildContext context, {required String actual}) {
  final controller = TextEditingController(text: actual);
  return showDialog<String>(
    context: context,
    builder: (context) => DialogoTc(
      titulo: 'Renombrar',
      contenido: TcTextField(
        label: 'Nombre del documento',
        controller: controller,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      acciones: [
        SmallButton(label: 'Cancelar', filled: false, onTap: () => Navigator.of(context).pop()),
        SmallButton(label: 'Guardar', onTap: () => Navigator.of(context).pop(controller.text)),
      ],
    ),
  );
  // El controlador no se libera aquí a propósito: el campo sigue visible
  // durante la animación de cierre. Sin oyentes, el recolector lo limpia.
}

/// Pide confirmación antes de borrar. Devuelve `true` si el usuario acepta.
Future<bool> confirmarEliminar(BuildContext context, String nombre) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => DialogoTc(
      titulo: '¿Eliminar “$nombre”?',
      contenido: Text(
        'Se borra de este celular y no se puede recuperar.',
        style: AppText.secondary(15, height: 1.4),
      ),
      acciones: [
        SmallButton(label: 'Cancelar', filled: false, onTap: () => Navigator.of(context).pop(false)),
        _BotonPeligro(etiqueta: 'Eliminar', onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// Salir con cambios sin guardar. Devuelve `true` si el usuario quiere salir.
Future<bool> confirmarSalirSinGuardar(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => DialogoTc(
      titulo: '¿Salir sin guardar?',
      contenido: Text(
        'Los cambios que hiciste en las páginas se pierden. El documento queda como estaba.',
        style: AppText.secondary(15, height: 1.4),
      ),
      acciones: [
        SmallButton(label: 'Seguir editando', filled: false, onTap: () => Navigator.of(context).pop(false)),
        _BotonPeligro(etiqueta: 'Salir', onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// Pregunta antes de algo que cuesta deshacer. Devuelve `true` si acepta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String accion,
  String cancelar = 'Cancelar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => DialogoTc(
      titulo: titulo,
      contenido: Text(texto, style: AppText.secondary(15, height: 1.4)),
      acciones: [
        SmallButton(label: cancelar, filled: false, onTap: () => Navigator.of(context).pop(false)),
        _BotonPeligro(etiqueta: accion, onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// El diálogo de la app: título grande, contenido y botones abajo a la derecha.
class DialogoTc extends StatelessWidget {
  const DialogoTc({super.key, required this.titulo, required this.contenido, required this.acciones});

  final String titulo;
  final Widget contenido;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: AppText.display(22, height: 1.25)),
            const SizedBox(height: 16),
            contenido,
            const SizedBox(height: 22),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: acciones),
          ],
        ),
      ),
    );
  }
}

class _BotonPeligro extends StatelessWidget {
  const _BotonPeligro({required this.etiqueta, required this.onTap});

  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rojo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Center(
              widthFactor: 1,
              child: Text(etiqueta, style: AppText.bold(14, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
