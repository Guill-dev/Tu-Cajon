import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import 'filtros.dart';
import 'procesar_foto.dart';

export 'filtros.dart' show FiltroFoto;

/// Lo que decidió la persona al revisar una foto.
sealed class RevisionFoto {
  const RevisionFoto();
}

/// Se queda (tal cual, recortada y/o con filtro).
class FotoConservada extends RevisionFoto {
  const FotoConservada({required this.base, required this.filtro, required this.foto, this.aTodas = false});

  /// La foto sin filtro (ya recortada): de ella se parte si se cambia el filtro.
  final Uint8List base;
  final FiltroFoto filtro;

  /// La foto con el filtro aplicado: la que se guarda.
  final Uint8List foto;

  /// La persona pidió usar este filtro en todas las páginas.
  final bool aTodas;
}

/// Se descarta.
class FotoEliminada extends RevisionFoto {
  const FotoEliminada();
}

/// Revisar una página recién tomada: verla en grande y decidir.
///
/// - **Filtro**: Original, Documento o B/N (ver [FiltroFoto]). Siempre se
///   parte de la foto sin filtro, así cambiar de filtro no la degrada.
/// - **Eliminar**: la descarta (en Escanear se puede deshacer).
/// - **Recortar**: aparece un marco con esquinas y bordes que se arrastran;
///   el visto aplica el recorte y la foto se ve ya recortada.
/// - **Conservar** (el visto verde): vuelve a Escanear con la foto.
///
/// La X o "atrás" vuelven sin cambios.
class RevisarFotoScreen extends StatefulWidget {
  const RevisarFotoScreen({
    super.key,
    required this.base,
    this.filtro = FiltroFoto.original,
    this.foto,
    required this.numero,
    this.total = 1,
  });

  /// La foto sin filtro.
  final Uint8List base;
  final FiltroFoto filtro;

  /// La foto con [filtro] ya aplicado (si no llega, se usa [base]).
  final Uint8List? foto;
  final int numero;

  /// Cuántas páginas hay (para "Usar en todas").
  final int total;

  @override
  State<RevisarFotoScreen> createState() => _RevisarFotoScreenState();
}

class _RevisarFotoScreenState extends State<RevisarFotoScreen> {
  static const _entera = Rect.fromLTRB(0, 0, 1, 1);

  late Uint8List _base = widget.base;
  late FiltroFoto _filtro = widget.filtro;
  late Uint8List _foto = widget.foto ?? widget.base;

  /// Filtros ya calculados para esta foto: volver a uno es instantáneo.
  late final Map<FiltroFoto, Uint8List> _hechos = {FiltroFoto.original: _base, _filtro: _foto};

  /// La foto decodificada: se dibuja y da el tamaño para el recortador.
  ui.Image? _imagen;

  bool _recortando = false;

  /// Recortando o aplicando un filtro (en otro hilo).
  bool _procesando = false;
  bool _recortada = false;

  /// Parte elegida con el recortador, en fracciones de la foto.
  Rect _parte = _entera;

  @override
  void initState() {
    super.initState();
    _decodificar();
  }

  @override
  void dispose() {
    _imagen?.dispose();
    super.dispose();
  }

  Future<void> _decodificar() async {
    final codec = await ui.instantiateImageCodec(_foto);
    final cuadro = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      cuadro.image.dispose();
      return;
    }
    setState(() {
      _imagen?.dispose();
      _imagen = cuadro.image;
    });
  }

  void _conservar({bool aTodas = false}) =>
      Navigator.of(context).pop(FotoConservada(base: _base, filtro: _filtro, foto: _foto, aTodas: aTodas));

  Future<void> _elegirFiltro(FiltroFoto filtro) async {
    if (filtro == _filtro || _procesando) return;
    final hecho = _hechos[filtro];
    setState(() {
      _filtro = filtro;
      _procesando = hecho == null;
    });
    try {
      final foto = hecho ?? await aplicarFiltro(_base, filtro);
      _hechos[filtro] = foto;
      _foto = foto;
      await _decodificar();
    } catch (e) {
      debugPrint('No se pudo aplicar el filtro: $e');
    }
    if (mounted) setState(() => _procesando = false);
  }

  void _eliminar() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(const FotoEliminada());
  }

  void _empezarRecorte() => setState(() {
    _parte = _entera;
    _recortando = true;
  });

  void _cancelarRecorte() => setState(() => _recortando = false);

  /// Recorta la foto sin filtro y le vuelve a poner el filtro elegido.
  Future<void> _aplicarRecorte() async {
    if (_procesando) return;
    if (_parte == _entera) {
      _cancelarRecorte();
      return;
    }
    setState(() => _procesando = true);
    try {
      _base = await recortarParte(_base, _parte);
      final foto = await aplicarFiltro(_base, _filtro);
      _hechos
        ..clear()
        ..[FiltroFoto.original] = _base
        ..[_filtro] = foto;
      _foto = foto;
      _recortada = true;
      await _decodificar();
    } catch (e) {
      debugPrint('No se pudo recortar: $e');
    }
    if (mounted) {
      setState(() {
        _procesando = false;
        _recortando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Con el recortador abierto, "atrás" solo lo cierra.
      canPop: !_recortando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelarRecorte();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.fondoCamara,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _barraSuperior(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _pista,
                      key: ValueKey(_pista),
                      textAlign: TextAlign.center,
                      style: AppText.body(15, color: AppColors.camaraTextoSuave, height: 1.4),
                    ),
                  ),
                ),
                if (!_recortando) _selectorFiltro(),
                Expanded(child: _areaFoto()),
                _recortando ? _barraRecorte() : _barraRevision(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _pista {
    if (_recortando) return 'Arrastra las esquinas o los bordes. Toca el visto para recortar.';
    if (_recortada) return 'Así quedó recortada. Toca el visto para conservarla.';
    return '¿Se ve bien? Mejórala con un filtro, recórtala o elimínala.';
  }

  /// Original · Documento · B/N, y "Usar en todas" si hay varias páginas.
  Widget _selectorFiltro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              for (final f in FiltroFoto.values)
                Expanded(
                  child: TcTap(
                    onTap: _procesando ? null : () => _elegirFiltro(f),
                    color: f == _filtro ? Colors.white : const Color(0x1FFFFFFF),
                    radius: 19,
                    height: 38,
                    semanticLabel: 'Filtro ${f.etiqueta}',
                    selected: f == _filtro,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          f.etiqueta,
                          maxLines: 1,
                          style: AppText.bold(14, color: f == _filtro ? AppColors.fondoCamara : Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.total > 1)
            TcTap(
              onTap: _procesando ? null : () => _conservar(aTodas: true),
              radius: 16,
              minHeight: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'Usar «${_filtro.etiqueta}» en las ${widget.total} páginas',
                  style: AppText.bold(14, color: AppColors.camaraMarco),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(
          children: [
            _BotonRedondo(
              icono: AppIcons.cerrar,
              etiqueta: _recortando ? 'Cancelar recorte' : 'Volver sin cambios',
              onTap: _recortando ? _cancelarRecorte : () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                'Página ${widget.numero}',
                textAlign: TextAlign.center,
                style: AppText.bold(17, color: Colors.white),
              ),
            ),
            // "Restablecer" deja el marco del recortador en la foto entera.
            SizedBox(
              width: 48,
              child: _recortando && _parte != _entera
                  ? TcTap(
                      onTap: () => setState(() => _parte = _entera),
                      radius: 24,
                      width: 48,
                      height: 48,
                      semanticLabel: 'Restablecer recorte',
                      child: const Center(child: TcIcon(AppIcons.restablecer, size: 22, color: Colors.white)),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaFoto() {
    final imagen = _imagen;
    // Sin Padding alrededor: el margen queda dentro del área, así los bordes
    // del recortador se pueden agarrar aunque la foto llegue al margen.
    return LayoutBuilder(
      builder: (context, limites) {
        if (imagen == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.camaraMarco));
        }
        // Dónde queda la foto dentro del área (entera, centrada).
        final area = const EdgeInsets.fromLTRB(24, 16, 24, 16).deflateRect(Offset.zero & limites.biggest);
        final tamFoto = Size(imagen.width.toDouble(), imagen.height.toDouble());
        final ajuste = applyBoxFit(BoxFit.contain, tamFoto, area.size);
        final rectFoto = Alignment.center.inscribe(ajuste.destination, area);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rectFoto,
              child: Semantics(
                image: true,
                label: 'Foto de la página ${widget.numero}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_recortando ? 0 : 10),
                  child: RawImage(image: imagen, fit: BoxFit.fill),
                ),
              ),
            ),
            if (_recortando)
              Positioned.fill(
                child: _Recortador(
                  foto: rectFoto,
                  parte: _parte,
                  onCambio: (p) => setState(() => _parte = p),
                ),
              ),
            if (_procesando) const Center(child: CircularProgressIndicator(color: AppColors.camaraMarco)),
          ],
        );
      },
    );
  }

  Widget _barraRevision() {
    final lista = _imagen != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      child: Row(
        children: [
          Expanded(
            child: _Accion(
              icono: AppIcons.basura,
              etiqueta: 'Eliminar',
              color: AppColors.camaraEliminar,
              onTap: _procesando ? null : _eliminar,
            ),
          ),
          Expanded(
            child: _Accion(
              icono: AppIcons.recortar,
              etiqueta: 'Recortar',
              color: Colors.white,
              onTap: lista && !_procesando ? _empezarRecorte : null,
            ),
          ),
          Expanded(
            child: _Accion(
              icono: AppIcons.check,
              etiqueta: 'Conservar',
              color: Colors.white,
              fondo: AppColors.verde,
              grande: true,
              onTap: _procesando ? null : _conservar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraRecorte() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      child: Row(
        children: [
          Expanded(
            child: _Accion(
              icono: AppIcons.cerrar,
              etiqueta: 'Cancelar',
              color: Colors.white,
              onTap: _procesando ? null : _cancelarRecorte,
            ),
          ),
          Expanded(
            child: _Accion(
              icono: AppIcons.check,
              etiqueta: 'Recortar',
              color: Colors.white,
              fondo: AppColors.verde,
              grande: true,
              onTap: _procesando ? null : _aplicarRecorte,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón redondo con su etiqueta debajo.
class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.onTap,
    this.fondo = const Color(0x1FFFFFFF),
    this.grande = false,
  });

  final String icono;
  final String etiqueta;
  final Color color;
  final Color fondo;
  final bool grande;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tam = grande ? 68.0 : 56.0;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: etiqueta,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        // Tocar la etiqueta también cuenta (el círculo tiene su propio efecto).
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              TcTap(
                onTap: onTap,
                color: fondo,
                radius: tam / 2,
                width: tam,
                height: tam,
                child: Center(
                  child: TcIcon(icono, size: grande ? 30 : 24, color: color),
                ),
              ),
              // Con letra muy grande se achica en vez de salirse.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  style: AppText.bold(14, color: onTap == null ? AppColors.camaraTerminarOff : color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.etiqueta, required this.onTap});

  final String icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: const Color(0x1AFFFFFF),
      radius: 24,
      width: 48,
      height: 48,
      semanticLabel: etiqueta,
      child: Center(child: TcIcon(icono, size: 22, color: Colors.white)),
    );
  }
}

/// De dónde se está arrastrando el recortador.
enum _Agarre { arribaIzq, arribaDer, abajoIzq, abajoDer, izq, der, arriba, abajo, mover }

/// Marco de recorte sobre la foto: se arrastran las esquinas, los bordes o
/// el marco entero. Lo que queda afuera se oscurece.
class _Recortador extends StatefulWidget {
  const _Recortador({required this.foto, required this.parte, required this.onCambio});

  /// Dónde está la foto en pantalla.
  final Rect foto;

  /// Parte elegida, en fracciones de la foto.
  final Rect parte;
  final ValueChanged<Rect> onCambio;

  @override
  State<_Recortador> createState() => _RecortadorState();
}

class _RecortadorState extends State<_Recortador> {
  /// Distancia (en px) a la que un dedo "agarra" una esquina o un borde.
  static const _alcance = 32.0;

  /// El recorte no puede quedar más chico que esto (en px de pantalla).
  static const _minimo = 48.0;

  _Agarre? _agarre;

  /// Dónde se apoyó el dedo y cómo estaba el recorte en ese momento: el
  /// borde se mueve lo mismo que el dedo desde ahí, sin quedarse atrás.
  Offset _inicio = Offset.zero;
  Rect _parteInicial = const Rect.fromLTRB(0, 0, 1, 1);

  void _empezar(Offset punto) {
    _agarre = _queAgarra(punto);
    _inicio = punto;
    _parteInicial = widget.parte;
  }

  Rect get _enPantalla {
    final f = widget.foto;
    final p = widget.parte;
    return Rect.fromLTRB(
      f.left + p.left * f.width,
      f.top + p.top * f.height,
      f.left + p.right * f.width,
      f.top + p.bottom * f.height,
    );
  }

  _Agarre? _queAgarra(Offset punto) {
    final r = _enPantalla;
    bool cerca(Offset esquina) => (punto - esquina).distance <= _alcance;
    if (cerca(r.topLeft)) return _Agarre.arribaIzq;
    if (cerca(r.topRight)) return _Agarre.arribaDer;
    if (cerca(r.bottomLeft)) return _Agarre.abajoIzq;
    if (cerca(r.bottomRight)) return _Agarre.abajoDer;
    final dentroV = punto.dy > r.top - _alcance && punto.dy < r.bottom + _alcance;
    final dentroH = punto.dx > r.left - _alcance && punto.dx < r.right + _alcance;
    if (dentroV && (punto.dx - r.left).abs() <= _alcance) return _Agarre.izq;
    if (dentroV && (punto.dx - r.right).abs() <= _alcance) return _Agarre.der;
    if (dentroH && (punto.dy - r.top).abs() <= _alcance) return _Agarre.arriba;
    if (dentroH && (punto.dy - r.bottom).abs() <= _alcance) return _Agarre.abajo;
    if (r.contains(punto)) return _Agarre.mover;
    return null;
  }

  /// [punto]: dónde está el dedo ahora.
  void _arrastrar(Offset punto) {
    final agarre = _agarre;
    if (agarre == null) return;
    final f = widget.foto;
    final movido = punto - _inicio;
    final dx = movido.dx / f.width;
    final dy = movido.dy / f.height;
    final minW = math.min(1.0, _minimo / f.width);
    final minH = math.min(1.0, _minimo / f.height);
    var Rect(:left, :top, :right, :bottom) = _parteInicial;

    if (agarre == _Agarre.mover) {
      final w = right - left;
      final h = bottom - top;
      left = (left + dx).clamp(0.0, 1.0 - w);
      top = (top + dy).clamp(0.0, 1.0 - h);
      widget.onCambio(Rect.fromLTWH(left, top, w, h));
      return;
    }
    if (agarre case _Agarre.izq || _Agarre.arribaIzq || _Agarre.abajoIzq) {
      left = (left + dx).clamp(0.0, right - minW);
    }
    if (agarre case _Agarre.der || _Agarre.arribaDer || _Agarre.abajoDer) {
      right = (right + dx).clamp(left + minW, 1.0);
    }
    if (agarre case _Agarre.arriba || _Agarre.arribaIzq || _Agarre.arribaDer) {
      top = (top + dy).clamp(0.0, bottom - minH);
    }
    if (agarre case _Agarre.abajo || _Agarre.abajoIzq || _Agarre.abajoDer) {
      bottom = (bottom + dy).clamp(top + minH, 1.0);
    }
    widget.onCambio(Rect.fromLTRB(left, top, right, bottom));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Marco de recorte. Arrastra las esquinas o los bordes para ajustarlo.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Se agarra lo que está donde se apoyó el dedo, no donde está al
        // empezar a moverse (si no, un gesto rápido agarraría otro borde).
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (d) => _empezar(d.localPosition),
        onPanUpdate: (d) => _arrastrar(d.localPosition),
        onPanEnd: (_) => _agarre = null,
        onPanCancel: () => _agarre = null,
        child: CustomPaint(
          painter: _RecortePainter(foto: widget.foto, recorte: _enPantalla),
        ),
      ),
    );
  }
}

/// Oscurece la foto fuera del recorte y dibuja el marco, la cuadrícula de
/// tercios y las agarraderas (esquinas y mitad de cada borde).
class _RecortePainter extends CustomPainter {
  const _RecortePainter({required this.foto, required this.recorte});

  final Rect foto;
  final Rect recorte;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(foto)
        ..addRect(recorte),
      Paint()..color = const Color(0x99000000),
    );

    final linea = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(recorte, linea);

    // Cuadrícula de tercios, suave.
    final guia = Paint()
      ..color = const Color(0x59FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = recorte.left + recorte.width * i / 3;
      final y = recorte.top + recorte.height * i / 3;
      canvas.drawLine(Offset(x, recorte.top), Offset(x, recorte.bottom), guia);
      canvas.drawLine(Offset(recorte.left, y), Offset(recorte.right, y), guia);
    }

    // Esquinas en L y rayitas en la mitad de cada borde.
    final agarradera = Paint()
      ..color = AppColors.camaraMarco
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const largo = 22.0;
    final r = recorte;
    for (final (esquina, sx, sy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(esquina.dx, esquina.dy + sy * largo)
          ..lineTo(esquina.dx, esquina.dy)
          ..lineTo(esquina.dx + sx * largo, esquina.dy),
        agarradera,
      );
    }
    const medio = 12.0;
    canvas.drawLine(Offset(r.center.dx - medio, r.top), Offset(r.center.dx + medio, r.top), agarradera);
    canvas.drawLine(Offset(r.center.dx - medio, r.bottom), Offset(r.center.dx + medio, r.bottom), agarradera);
    canvas.drawLine(Offset(r.left, r.center.dy - medio), Offset(r.left, r.center.dy + medio), agarradera);
    canvas.drawLine(Offset(r.right, r.center.dy - medio), Offset(r.right, r.center.dy + medio), agarradera);
  }

  @override
  bool shouldRepaint(_RecortePainter oldDelegate) =>
      oldDelegate.foto != foto || oldDelegate.recorte != recorte;
}
