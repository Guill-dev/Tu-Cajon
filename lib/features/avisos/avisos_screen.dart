import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/documento.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';
import 'sugerencias.dart';

/// 7 · Avisos: documentos por vencer (de las fechas guardadas) y sugerencias
/// de la IA que se pueden aceptar o descartar. Lo descartado queda guardado
/// en la base de datos. Cuando no queda ninguna: "Estás al día".
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key});

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> with ToastMixin {
  late final Stream<List<Documento>> _todos = context.repo.vigilarTodos();
  late final Stream<Set<String>> _descartadas = context.repo.vigilarSugerenciasDescartadas();
  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();

  void _agregar() => Navigator.of(context).pushNamed(AppRoutes.agregar);

  void _abrir(Documento d) => Navigator.of(context).pushNamed(AppRoutes.detalle, arguments: d.id);

  Future<void> _descartar(Sugerencia s, {String? mensaje}) async {
    await context.repo.descartarSugerencia(s.clave);
    if (mensaje != null) showToast(mensaje, duration: const Duration(milliseconds: 2800));
  }

  static DateTime _proximoLunes(DateTime hoy) {
    final dias = (DateTime.monday - hoy.weekday + 7) % 7;
    return hoy.add(Duration(days: dias == 0 ? 7 : dias));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _todos,
      builder: (context, todos) => StreamBuilder(
        stream: _descartadas,
        builder: (context, descartadas) => StreamBuilder(
          stream: _perfiles,
          builder: (context, perfiles) => _contenido(todos.data ?? const [], descartadas.data ?? const {}, {
            for (final p in perfiles.data ?? const <Perfil>[]) p.id: p,
          }),
        ),
      ),
    );
  }

  Widget _contenido(List<Documento> docs, Set<String> descartadas, Map<String, Perfil> perfiles) {
    final hoy = DateTime.now();
    final porVencer = docs.where((d) {
      final dias = d.diasParaVencer(hoy);
      return dias != null && dias >= -30 && dias <= 365;
    }).toList()..sort((a, b) => a.venceEn!.compareTo(b.venceEn!));
    final sugerencias = calcularSugerencias(docs, descartadas, hoy);

    return ColoredBox(
      color: AppColors.fondo,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      const TwoToneTitle('', ligero: 'Tus', fuerte: 'avisos', size: 32),
                      Text(
                        'Te avisamos antes de que tus documentos se venzan.',
                        style: AppText.secondary(15, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NoScrollbar(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 120 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        const _Titulo('Por vencer'),
                        const SizedBox(height: 12),
                        if (porVencer.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: AppDecor.tarjeta(),
                            child: Text(
                              'Ningún documento vence en los próximos meses.',
                              style: AppText.secondary(15, height: 1.4),
                            ),
                          ),
                        for (final d in porVencer) ...[
                          _FechaVence(
                            documento: d,
                            perfil: perfiles[d.perfilId],
                            hoy: hoy,
                            onTap: () => _abrir(d),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            const TcIcon(AppIcons.reloj, size: 16, color: AppColors.textoSecundario),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Te avisamos 30 días y 7 días antes de cada fecha.',
                                style: AppText.secondary(14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            Expanded(child: _Titulo('Sugerencias para ti')),
                            TcBadge(
                              label: 'Con IA',
                              icon: AppIcons.destello,
                              bg: AppColors.ambarSuave,
                              fg: AppColors.ambar,
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final s in sugerencias)
                                Padding(
                                  key: ValueKey(s.clave),
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _tarjeta(s, hoy),
                                ),
                              if (sugerencias.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                                    decoration: BoxDecoration(
                                      color: AppColors.verdeSuave,
                                      borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
                                    ),
                                    child: Row(
                                      children: [
                                        const TcIcon(AppIcons.check, size: 26, color: AppColors.verdeOscuro),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Estás al día. Te contamos cuando haya algo nuevo.',
                                            style: AppText.bold(
                                              16,
                                              color: AppColors.verdeOscuro,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const PrivacyNote(
                          'Las sugerencias se preparan en tu celular a partir de tus fechas. Tus documentos no salen del teléfono.',
                          center: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          TcToast(message: toastMessage, bottom: 100),
        ],
      ),
    );
  }

  Widget _tarjeta(Sugerencia s, DateTime hoy) {
    final d = s.documento;
    final icono = d?.categoria.icono ?? AppIcons.cajon;
    final color = d?.categoria.color ?? AppColors.primario;
    final List<Widget> acciones = switch (s.tipo) {
      TipoSugerencia.vencido => [
        SmallButton(label: 'Escanear el nuevo', onTap: _agregar),
        SmallButton(label: 'Ya lo hice', filled: false, onTap: () => _descartar(s)),
      ],
      TipoSugerencia.renovar => [
        SmallButton(
          label: 'Recordarme el lunes',
          onTap: () => showToast(
            'Listo. Te lo recordamos el lunes ${Formato.diaMes(_proximoLunes(hoy))}.',
            duration: const Duration(milliseconds: 2800),
          ),
        ),
        SmallButton(
          label: 'Ya lo hice',
          filled: false,
          onTap: () => _descartar(s, mensaje: '¡Bien! Cuando tengas el nuevo, escanéalo para reemplazarlo.'),
        ),
      ],
      TipoSugerencia.actualizar => [
        SmallButton(label: 'Reemplazar documento', onTap: _agregar),
        SmallButton(label: 'Descartar', filled: false, onTap: () => _descartar(s)),
      ],
      TipoSugerencia.agregar => [
        SmallButton(label: 'Agregar uno', onTap: _agregar),
        SmallButton(label: 'Ahora no', filled: false, onTap: () => _descartar(s)),
      ],
    };
    return _Sugerencia(
      icono: icono,
      color: color,
      etiqueta: s.etiqueta,
      titulo: s.titulo,
      texto: s.texto,
      acciones: acciones,
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(header: true, child: Text(texto, style: AppText.bold(18))),
    );
  }
}

/// Fila de "Por vencer": fecha en un cuadro de color, nombre, cuánto falta
/// (y de quién es, si no es tuyo) y una etiqueta Pronto / A tiempo / Vencido.
class _FechaVence extends StatelessWidget {
  const _FechaVence({required this.documento, required this.perfil, required this.hoy, required this.onTap});

  final Documento documento;
  final Perfil? perfil;
  final DateTime hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final dias = d.diasParaVencer(hoy)!;
    final (
      String etiqueta,
      Color fondo,
      Color color,
      Color etiquetaFondo,
      Color etiquetaColor,
    ) = switch (dias) {
      < 0 => ('Vencido', const Color(0xFFFDE8E6), AppColors.rojo, const Color(0xFFFDE8E6), AppColors.rojo),
      <= 30 => ('Pronto', AppColors.ambarSuave, AppColors.ambar, AppColors.ambarSuave, AppColors.ambar),
      _ => (
        'A tiempo',
        AppColors.calmaFondo,
        AppColors.textoTerciario,
        AppColors.verdeSuave,
        AppColors.verdeOscuro,
      ),
    };
    final cuanto = d.etiqueta(hoy)?.texto ?? 'Vence el ${Formato.fechaLarga(d.venceEn!)}';
    final deQuien = perfil == null || perfil!.esPropio ? '' : ' · ${perfil!.nombre}';
    final anio = d.venceEn!.year != hoy.year ? ' · ${d.venceEn!.year}' : '';

    return TcTap(
      onTap: onTap,
      color: AppColors.superficie,
      radius: AppDecor.radioTarjeta,
      shadow: AppDecor.sombra,
      semanticLabel: '${d.nombre}. $cuanto$deQuien',
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 62,
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Text('${d.venceEn!.day}', style: AppText.bold(24, color: color, height: 1)),
                Text(Formato.mesCorto(d.venceEn!), style: AppText.bold(13, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(d.nombre, style: AppText.bold(17)),
                Text('$cuanto$anio$deQuien', style: AppText.secondary(14)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TcBadge(label: etiqueta, bg: etiquetaFondo, fg: etiquetaColor),
        ],
      ),
    );
  }
}

class _Sugerencia extends StatelessWidget {
  const _Sugerencia({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.titulo,
    required this.texto,
    required this.acciones,
  });

  final String icono;
  final Color color;
  final String etiqueta;
  final String titulo;
  final String texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecor.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              TcIcon(icono, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(etiqueta, style: AppText.bold(13, color: color).copyWith(letterSpacing: 0.65)),
              ),
            ],
          ),
          Text(titulo, style: AppText.bold(18, height: 1.3)),
          Text(texto, style: AppText.body(15, color: AppColors.textoTerciario, height: 1.45)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, runSpacing: 8, children: acciones),
          ),
        ],
      ),
    );
  }
}
