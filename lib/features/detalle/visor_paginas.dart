import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';

/// "Ver completo": las páginas del documento a pantalla completa, con
/// deslizar entre páginas y pellizcar para acercar.
class VisorPaginas extends StatefulWidget {
  const VisorPaginas({super.key, required this.titulo, required this.paginas});

  final String titulo;
  final List<Uint8List> paginas;

  @override
  State<VisorPaginas> createState() => _VisorPaginasState();
}

class _VisorPaginasState extends State<VisorPaginas> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.paginas.length;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.fondoCamara,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    TcTap(
                      onTap: () => Navigator.of(context).pop(),
                      color: const Color(0x1AFFFFFF),
                      radius: 24,
                      width: 48,
                      height: 48,
                      semanticLabel: 'Cerrar',
                      child: const Center(child: TcIcon(AppIcons.cerrar, size: 22, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bold(17, color: Colors.white),
                      ),
                    ),
                    if (total > 1)
                      Text(
                        '${_actual + 1} de $total',
                        style: AppText.body(15, color: AppColors.camaraTextoSuave),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _actual = i),
                  itemBuilder: (context, i) => InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Semantics(
                        image: true,
                        label: 'Página ${i + 1} de $total',
                        child: Image.memory(widget.paginas[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
