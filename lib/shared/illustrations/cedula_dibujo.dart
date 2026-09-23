import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Frente de una cédula esquemática (foto + líneas de texto).
class CedulaFrente extends StatelessWidget {
  const CedulaFrente({
    super.key,
    required this.width,
    required this.height,
    this.escala = 1,
    this.sombra = false,
  });

  final double width;
  final double height;

  /// 1 = tamaño de la vista previa del escáner; 0.6 ≈ miniatura del detalle.
  final double escala;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final e = escala;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(16 * e),
      decoration: _deco(e, sombra),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64 * e,
            height: 82 * e,
            decoration: BoxDecoration(color: AppColors.idFoto, borderRadius: BorderRadius.circular(5 * e)),
          ),
          SizedBox(width: 14 * e),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4 * e),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 9 * e,
                children: [
                  for (final f in const [0.85, 0.6, 0.72, 0.5]) _linea(f, e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reverso de la cédula (líneas, foto pequeña y código de barras).
class CedulaReverso extends StatelessWidget {
  const CedulaReverso({
    super.key,
    required this.width,
    required this.height,
    this.escala = 1,
    this.sombra = false,
  });

  final double width;
  final double height;
  final double escala;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final e = escala;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(16 * e),
      decoration: _deco(e, sombra),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linea(0.7, e),
          SizedBox(height: 9 * e),
          _linea(0.86, e),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 46 * e,
                height: 56 * e,
                decoration: BoxDecoration(
                  color: AppColors.idFoto,
                  borderRadius: BorderRadius.circular(5 * e),
                ),
              ),
              SizedBox(width: 12 * e),
              Expanded(
                child: CodigoBarras(height: 30 * e, barra: 3 * e),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barras verticales repetidas (repeating-linear-gradient del diseño).
class CodigoBarras extends StatelessWidget {
  const CodigoBarras({super.key, required this.height, this.barra = 3});

  final double height;
  final double barra;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _BarrasPainter(barra)),
    );
  }
}

class _BarrasPainter extends CustomPainter {
  _BarrasPainter(this.barra);

  final double barra;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.idBarras;
    for (var x = 0.0; x < size.width; x += barra * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, barra, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter old) => old.barra != barra;
}

BoxDecoration _deco(double e, bool sombra) => BoxDecoration(
  color: AppColors.idFondo,
  borderRadius: BorderRadius.circular(12 * e),
  boxShadow: sombra
      ? const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10))]
      : null,
);

Widget _linea(double fraccion, double e) => FractionallySizedBox(
  widthFactor: fraccion,
  child: Container(
    height: 8 * e,
    decoration: BoxDecoration(color: AppColors.idLinea, borderRadius: BorderRadius.circular(4 * e)),
  ),
);
