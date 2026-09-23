import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../cajon/cajon_shell.dart';
import 'respuestas_demo.dart';

/// 11 · Pregúntale a tu cajón: chat con la IA que busca datos en tus
/// documentos. Por ahora responde con reglas fijas (ver `respuestas_demo.dart`).
class PreguntarScreen extends StatefulWidget {
  const PreguntarScreen({super.key});

  @override
  State<PreguntarScreen> createState() => _PreguntarScreenState();
}

class _PreguntarScreenState extends State<PreguntarScreen> {
  final _entrada = TextEditingController();
  final _scroll = ScrollController();
  final _mensajes = <Mensaje>[];

  static const _ejemplos = [
    '¿Cuál es mi número de pasaporte?',
    '¿Cuándo vence mi licencia?',
    '¿Cuál es mi número de cédula?',
  ];

  @override
  void dispose() {
    _entrada.dispose();
    _scroll.dispose();
    super.dispose();
  }

  late final _asistente = AsistenteLocal(context.repo);

  Future<void> _preguntar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty) return;
    setState(() {
      _mensajes.add(Mensaje.usuario(t));
      _entrada.clear();
    });
    _bajar();
    final respuesta = await _asistente.responder(t);
    if (!mounted) return;
    setState(() => _mensajes.add(respuesta));
    _bajar();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _abrirCta(Cta cta) {
    switch (cta) {
      case AbrirDocumento(:final documentoId):
        Navigator.of(context).pushNamed(AppRoutes.detalle, arguments: documentoId);
      case VerAvisos():
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.cajon, (_) => false, arguments: CajonTab.avisos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(
              title: 'Pregúntale a tu cajón',
              titleSize: 21,
              backLabel: 'Volver a mi cajón',
              trailing: TcBadge(
                label: 'IA',
                icon: AppIcons.destello,
                bg: AppColors.ambarSuave,
                fg: AppColors.ambar,
              ),
            ),
            Expanded(
              child: NoScrollbar(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    const _Burbuja(
                      mensaje: Mensaje.ia(
                        'Puedo buscar un dato puntual en tus documentos guardados, como un número o una fecha. Pregúntame algo o toca un ejemplo.',
                      ),
                      animar: false,
                    ),
                    for (final m in _mensajes) ...[
                      const SizedBox(height: 14),
                      _Burbuja(key: ObjectKey(m), mensaje: m, onCta: _abrirCta),
                    ],
                    if (_mensajes.isEmpty) ...[
                      const SizedBox(height: 18),
                      for (final e in _ejemplos) ...[
                        TcTap(
                          onTap: () => _preguntar(e),
                          color: AppColors.superficie,
                          radius: 18,
                          shadow: AppDecor.sombra,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Text(e, style: AppText.bold(15, color: AppColors.primario)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              color: AppColors.fondo,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppDecor.sombra,
                      ),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _entrada,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _preguntar,
                        style: AppText.body(16),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Escribe tu pregunta…',
                          hintStyle: AppText.body(16, color: AppColors.placeholder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TcTap(
                    onTap: () => _preguntar(_entrada.text),
                    color: AppColors.primario,
                    radius: 18,
                    shadow: AppDecor.sombraColor(AppColors.primario),
                    width: 52,
                    height: 52,
                    semanticLabel: 'Enviar pregunta',
                    child: const Center(child: TcIcon(AppIcons.enviar, size: 22, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrivacyNote(
                'Busca solo en tus documentos de este celular; nada sale a internet. En celulares más sencillos, busca por palabra clave.',
                center: false,
                size: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({super.key, required this.mensaje, this.onCta, this.animar = true});

  final Mensaje mensaje;
  final ValueChanged<Cta>? onCta;
  final bool animar;

  @override
  Widget build(BuildContext context) {
    final ia = mensaje.esIa;
    final burbuja = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 268),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ia ? AppColors.superficie : AppColors.primario,
          boxShadow: ia ? AppDecor.sombra : null,
          borderRadius: ia
              ? const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje.texto,
              style: AppText.body(16, color: ia ? AppColors.texto : Colors.white, height: 1.4),
            ),
            if (ia && mensaje.cta != null && onCta != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  link: true,
                  child: GestureDetector(
                    onTap: () => onCta!(mensaje.cta!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(mensaje.cta!.etiqueta, style: AppText.bold(15, color: AppColors.primario)),
                        const TcIcon(AppIcons.siguiente, size: 16, color: AppColors.primario),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final fila = Row(
      mainAxisAlignment: ia ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ia) ...[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.primario, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const TcIcon(AppIcons.destelloSolo, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: burbuja),
      ],
    );

    if (!animar) return fila;
    // Sube 10 px con fundido (0.2 s).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: fila,
    );
  }
}
