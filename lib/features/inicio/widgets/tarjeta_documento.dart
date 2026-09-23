import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/documento.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tc_icon.dart';
import '../../../shared/widgets/tc_tap.dart';

/// Documento en la lista (como "Last read" en la referencia): ficha grande de
/// color a la izquierda, carpeta en mayúsculas pequeñas, nombre en grueso,
/// detalle, etiqueta opcional y botón verde de WhatsApp.
class TarjetaDocumento extends StatelessWidget {
  const TarjetaDocumento({
    super.key,
    required this.documento,
    required this.hoy,
    required this.onAbrir,
    required this.onWhatsApp,
  });

  final Documento documento;

  /// Fecha de referencia para "Vence en N días".
  final DateTime hoy;
  final VoidCallback onAbrir;
  final VoidCallback onWhatsApp;

  static (Color, Color) coloresTono(TonoAviso tono) => switch (tono) {
    TonoAviso.peligro => (const Color(0xFFFDE8E6), AppColors.rojo),
    TonoAviso.advertencia => (AppColors.ambarSuave, AppColors.ambar),
    TonoAviso.info => (AppColors.primarioSuave, AppColors.primario),
    TonoAviso.calma => (AppColors.calmaFondo, AppColors.textoTerciario),
  };

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final cat = d.categoria;
    final etiqueta = d.etiqueta(hoy);
    return DecoratedBox(
      decoration: AppDecor.tarjeta(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TcTap(
                onTap: onAbrir,
                radius: 18,
                semanticLabel: d.nombre,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 72,
                      decoration: BoxDecoration(color: cat.fondo, borderRadius: BorderRadius.circular(18)),
                      alignment: Alignment.center,
                      child: TcIcon(cat.icono, size: 28, color: cat.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(
                            cat.etiqueta.toUpperCase(),
                            style: AppText.bold(
                              11,
                              color: AppColors.textoSecundario,
                            ).copyWith(letterSpacing: 0.8),
                          ),
                          Text(
                            d.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bold(16, height: 1.25),
                          ),
                          Text(d.detalleArchivo, style: AppText.secondary(13, height: 1.3)),
                          if (etiqueta != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TcBadge(
                                label: etiqueta.texto,
                                bg: coloresTono(etiqueta.tono).$1,
                                fg: coloresTono(etiqueta.tono).$2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: AppIcons.whatsapp,
              semanticLabel: 'Enviar ${d.nombre} por WhatsApp',
              onTap: onWhatsApp,
              color: AppColors.verde,
              background: AppColors.verdeSuave,
              iconSize: 24,
            ),
          ],
        ),
      ),
    );
  }
}
