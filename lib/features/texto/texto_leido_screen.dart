import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/lectura/lectura_de_documentos.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';

/// Todo lo que se leyó de un documento, página por página, para leerlo con
/// calma, seleccionar una parte o copiarlo.
class TextoLeidoScreen extends StatelessWidget {
  const TextoLeidoScreen({super.key, required this.texto, this.numero});

  /// El texto del documento, con las páginas separadas por [separadorDePaginas].
  final String texto;

  /// El número principal (cédula, NIT, placa…), si se encontró.
  final String? numero;

  List<String> get _paginas => [
    for (final p in texto.split(separadorDePaginas))
      if (p.trim().isNotEmpty) p.trim(),
  ];

  void _copiarTodo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _paginas.join('\n\n')));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copiaste todo el texto.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 112),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(title: 'Lo que dice el documento'),
            Expanded(
              child: NoScrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.ambarSuave,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.ambarBorde),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          const TcIcon(AppIcons.destelloSolo, size: 20, color: AppColors.ambar),
                          Expanded(
                            child: Text(
                              'Lo leyó la IA aquí en tu celular. Puede equivocarse en alguna letra: '
                              'revisa los números importantes con el papel.',
                              style: AppText.body(14, color: AppColors.ambar, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (numero case final numero?) ...[
                      const SizedBox(height: 12),
                      FilaNumero(numero: numero),
                    ],
                    for (var i = 0; i < paginas.length; i++) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        decoration: AppDecor.tarjeta(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: [
                            if (paginas.length > 1)
                              Text(
                                'Página ${i + 1}',
                                style: AppText.bold(14, color: AppColors.textoSecundario),
                              ),
                            SelectableText(paginas[i], style: AppText.body(16, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                    if (paginas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No se encontraron letras en este documento.',
                          textAlign: TextAlign.center,
                          style: AppText.secondary(15),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (paginas.isNotEmpty)
              BottomActionBar(
                children: [
                  PrimaryButton(
                    label: 'Copiar todo el texto',
                    icon: AppIcons.copiar,
                    onTap: () => _copiarTodo(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "Número   52.348.910   [copiar]": el número principal, listo para copiarlo
/// (para pegarlo en un formulario o un trámite).
class FilaNumero extends StatelessWidget {
  const FilaNumero({super.key, required this.numero, this.alCopiar});

  final String numero;

  /// Para avisar con el toast de la pantalla; sin él, sale un SnackBar.
  final VoidCallback? alCopiar;

  void _copiar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: numero));
    if (alCopiar case final avisar?) {
      avisar();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copiaste el número.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 112),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: AppDecor.tarjeta(radius: 18),
      child: Row(
        children: [
          Text('Número', style: AppText.secondary(15)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(numero, textAlign: TextAlign.end, style: AppText.bold(17)),
          ),
          const SizedBox(width: 4),
          TcTap(
            onTap: () => _copiar(context),
            width: 48,
            height: 48,
            semanticLabel: 'Copiar el número $numero',
            child: const Center(child: TcIcon(AppIcons.copiar, size: 20, color: AppColors.primario)),
          ),
        ],
      ),
    );
  }
}
