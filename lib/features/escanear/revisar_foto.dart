import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import 'bordes.dart';
import 'filtros.dart';
import 'procesar_foto.dart';

export 'filtros.dart' show FiltroFoto;

/// Lo que decidió la persona al revisar una foto.
sealed class RevisionFoto {
  const RevisionFoto();
}

/// Se queda (tal cual, recortada y/o con filtro).
class FotoConservada extends RevisionFoto {
  const FotoConservada({
    required this.base,
    required this.filtro,
    required this.foto,
    this.original,
    this.esquinas,
    this.aTodas = false,
  });

  /// La foto sin filtro (ya recortada): de ella se parte si se cambia el filtro.
  final Uint8List base;
  final FiltroFoto filtro;

  /// La foto con el filtro aplicado: la que se guarda.
  final Uint8List foto;

  /// De dónde se recortó [base] y con qué esquinas (para volver a ajustar).
  final Uint8List? original;
  final Esquinas? esquinas;

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
/// - **Recortar**: sobre la foto original aparecen los bordes del papel
///   (los que se encontraron solos, o la foto entera). Se arrastran las
///   esquinas (con una lupa para afinar) o los lados enteros; "Detectar"
///   los busca solo. El visto recorta y endereza el papel (perspectiva).
/// - **Conservar** (el visto verde): vuelve a Escanear con la foto.
///
/// La X o "atrás" vuelven sin cambios.
class RevisarFotoScreen extends StatefulWidget {
  const RevisarFotoScreen({
    super.key,
    required this.base,
    this.filtro = FiltroFoto.original,
    this.foto,
    this.original,
    this.esquinas = Esquinas.todo,
    this.proporciones = const [],
    required this.numero,
    this.total = 1,
  });

  /// La foto sin filtro.
  final Uint8List base;
  final FiltroFoto filtro;

  /// La foto con [filtro] ya aplicado (si no llega, se usa [base]).
  final Uint8List? foto;

  /// De dónde salió [base] y con qué [esquinas] (si no llega, de sí misma).
  final Uint8List? original;
  final Esquinas esquinas;

  /// Proporciones del papel esperado, para enderezar (tarjeta, hoja).
  final List<double> proporciones;
  final int numero;

  /// Cuántas páginas hay (para "Usar en todas").
  final int total;

  @override
  State<RevisarFotoScreen> createState() => _RevisarFotoScreenState();
}

class _RevisarFotoScreenState extends State<RevisarFotoScreen> {
  late Uint8List _base = widget.base;
  late FiltroFoto _filtro = widget.filtro;
  late Uint8List _foto = widget.foto ?? widget.base;

  /// De dónde se recorta: no cambia, así los bordes se pueden volver a abrir.
  late final Uint8List _original = widget.original ?? widget.base;

  /// Las esquinas con las que [_base] salió de [_original].
  late Esquinas _esquinas = widget.original == null ? Esquinas.todo : widget.esquinas;

  /// Filtros ya calculados para esta foto: volver a uno es instantáneo.
  late final Map<FiltroFoto, Uint8List> _hechos = {FiltroFoto.original: _base, _filtro: _foto};

  /// La foto decodificada: se dibuja y da el tamaño para el recortador.
  ui.Image? _imagen;

  /// La original decodificada (si no es la misma que [_foto]).
  ui.Image? _imagenOriginal;

  bool _recortando = false;

  /// Recortando, buscando bordes o aplicando un filtro (en otro hilo).
  bool _procesando = false;
  bool _recortada = false;

  /// Los bordes mientras se ajustan, en fracciones de la original.
  Esquinas _editando = Esquinas.todo;

  /// Un aviso corto en lugar de la pista ("No encontramos los bordes…").
  String? _mensaje;

  /// Con qué se dibuja el recortador: la original.
  ui.Image? get _paraRecortar => identical(_original, _foto) ? _imagen : _imagenOriginal;

  @override
  void initState() {
    super.initState();
    _decodificar();
    _decodificarOriginal();
  }

  @override
  void dispose() {
    _imagen?.dispose();
    _imagenOriginal?.dispose();
    super.dispose();
  }

  static Future<ui.Image> _abrir(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final cuadro = await codec.getNextFrame();
    codec.dispose();
    return cuadro.image;
  }

  Future<void> _decodificar() async {
    final imagen = await _abrir(_foto);
    if (!mounted) {
      imagen.dispose();
      return;
    }
    setState(() {
      _imagen?.dispose();
      _imagen = imagen;
    });
  }

  Future<void> _decodificarOriginal() async {
    if (_imagenOriginal != null || identical(_original, _foto)) return;
    final imagen = await _abrir(_original);
    if (!mounted || _imagenOriginal != null) {
      imagen.dispose();
      return;
    }
    setState(() => _imagenOriginal = imagen);
  }

  void _conservar({bool aTodas = false}) => Navigator.of(context).pop(
    FotoConservada(
      base: _base,
      filtro: _filtro,
      foto: _foto,
      original: _original,
      esquinas: _esquinas,
      aTodas: aTodas,
    ),
  );

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

  void _empezarRecorte() {
    _decodificarOriginal();
    setState(() {
      _editando = _esquinas;
      _mensaje = null;
      _recortando = true;
    });
  }

  void _cancelarRecorte() => setState(() {
    _recortando = false;
    _mensaje = null;
  });

  /// "Detectar": busca los bordes del papel en la original.
  Future<void> _detectar() async {
    if (_procesando) return;
    setState(() {
      _procesando = true;
      _mensaje = null;
    });
    Esquinas? halladas;
    try {
      halladas = await detectarEnFoto(_original);
    } catch (e) {
      debugPrint('No se pudieron buscar los bordes: $e');
    }
    if (!mounted) return;
    setState(() {
      _procesando = false;
      if (halladas != null) {
        _editando = halladas;
        _mensaje = 'Encontramos los bordes del papel. Ajústalos si hace falta.';
      } else {
        _mensaje = 'No encontramos los bordes del papel: muévelos con el dedo.';
      }
    });
    HapticFeedback.selectionClick();
  }

  /// Recorta y endereza el papel desde la original, y le vuelve a poner el
  /// filtro elegido.
  Future<void> _aplicarRecorte() async {
    if (_procesando) return;
    if (_editando.casiIgual(_esquinas)) {
      _cancelarRecorte();
      return;
    }
    setState(() => _procesando = true);
    try {
      final nuevas = _editando;
      _base = nuevas.esTodo
          ? _original
          : await enderezarFoto(_original, nuevas, proporciones: widget.proporciones);
      final foto = await aplicarFiltro(_base, _filtro);
      _hechos
        ..clear()
        ..[FiltroFoto.original] = _base
        ..[_filtro] = foto;
      _foto = foto;
      _esquinas = nuevas;
      _recortada = true;
      await _decodificar();
    } catch (e) {
      debugPrint('No se pudo recortar: $e');
    }
    if (mounted) {
      setState(() {
        _procesando = false;
        _recortando = false;
        _mensaje = null;
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
    if (_mensaje case final mensaje?) return mensaje;
    if (_recortando) return 'Arrastra las esquinas hasta los bordes del papel. Toca el visto para recortar.';
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
            // "Restablecer" deja los bordes en la foto entera.
            SizedBox(
              width: 48,
              child: _recortando && !_editando.esTodo
                  ? TcTap(
                      onTap: () => setState(() {
                        _editando = Esquinas.todo;
                        _mensaje = null;
                      }),
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
    // Al recortar se ve la original entera (con lo que quedó afuera del recorte).
    final imagen = _recortando ? _paraRecortar : _imagen;
    // Sin Padding alrededor: el margen queda dentro del área, así las
    // esquinas se pueden agarrar aunque la foto llegue al margen.
    return LayoutBuilder(
      builder: (context, limites) {
        if (imagen == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.camaraMarco));
        }
        // Dónde queda la foto dentro del área (entera, centrada).
        final area = const EdgeInsets.fromLTRB(28, 20, 28, 20).deflateRect(Offset.zero & limites.biggest);
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
                child: _EditorBordes(
                  foto: rectFoto,
                  imagen: imagen,
                  esquinas: _editando,
                  onCambio: (e) => setState(() {
                    _editando = e;
                    _mensaje = null;
                  }),
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
              icono: AppIcons.destelloSolo,
              etiqueta: 'Detectar',
              color: AppColors.camaraFlash,
              onTap: _procesando || _paraRecortar == null ? null : _detectar,
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

/// Los bordes del papel sobre la foto: se arrastran las cuatro esquinas
/// (con una lupa para ver dónde quedan) o un lado entero (agarrándolo por la
/// mitad). Lo que queda afuera se oscurece.
class _EditorBordes extends StatefulWidget {
  const _EditorBordes({
    required this.foto,
    required this.imagen,
    required this.esquinas,
    required this.onCambio,
  });

  /// Dónde está la foto en pantalla.
  final Rect foto;

  /// La foto, para la lupa.
  final ui.Image imagen;

  /// En fracciones de la foto.
  final Esquinas esquinas;
  final ValueChanged<Esquinas> onCambio;

  @override
  State<_EditorBordes> createState() => _EditorBordesState();
}

class _EditorBordesState extends State<_EditorBordes> {
  /// Distancia (en px) a la que un dedo agarra una esquina o un lado.
  static const _alcanceEsquina = 40.0;
  static const _alcanceLado = 34.0;

  /// Qué se está arrastrando: una esquina (0 a 3) o un lado (0 a 3, el que
  /// va de la esquina i a la siguiente).
  int? _esquina;
  int? _lado;

  /// Dónde se apoyó el dedo y cómo estaban los bordes entonces: se mueven lo
  /// mismo que el dedo desde ahí.
  Offset _inicio = Offset.zero;
  Esquinas _inicial = Esquinas.todo;

  Offset _enPantalla(Offset f) =>
      Offset(widget.foto.left + f.dx * widget.foto.width, widget.foto.top + f.dy * widget.foto.height);

  List<Offset> get _puntos => [for (final e in widget.esquinas.lista) _enPantalla(e)];

  void _empezar(Offset dedo) {
    final p = _puntos;
    _inicio = dedo;
    _inicial = widget.esquinas;
    _esquina = null;
    _lado = null;
    var mejor = _alcanceEsquina;
    for (var i = 0; i < 4; i++) {
      final d = (p[i] - dedo).distance;
      if (d <= mejor) {
        mejor = d;
        _esquina = i;
      }
    }
    if (_esquina != null) {
      setState(() {});
      return;
    }
    mejor = _alcanceLado;
    for (var i = 0; i < 4; i++) {
      final d = ((p[i] + p[(i + 1) % 4]) / 2 - dedo).distance;
      if (d <= mejor) {
        mejor = d;
        _lado = i;
      }
    }
  }

  Offset _limitar(Offset f) => Offset(f.dx.clamp(0.0, 1.0), f.dy.clamp(0.0, 1.0));

  void _arrastrar(Offset dedo) {
    final movido = dedo - _inicio;
    final d = Offset(movido.dx / widget.foto.width, movido.dy / widget.foto.height);
    Esquinas nuevas;
    if (_esquina case final i?) {
      nuevas = _inicial.cambiar(i, _limitar(_inicial.lista[i] + d));
    } else if (_lado case final i?) {
      final j = (i + 1) % 4;
      nuevas = _inicial
          .cambiar(i, _limitar(_inicial.lista[i] + d))
          .cambiar(j, _limitar(_inicial.lista[j] + d));
    } else {
      return;
    }
    // Sin lados cruzados ni papel de nada: ese movimiento no se acepta.
    if (nuevas.esValido) widget.onCambio(nuevas);
  }

  void _soltar() {
    if (_esquina != null) setState(() => _esquina = null);
    _lado = null;
  }

  @override
  Widget build(BuildContext context) {
    final puntos = _puntos;
    final esquina = _esquina;
    return Semantics(
      label: 'Bordes del papel. Arrastra las esquinas o los lados para ajustarlos.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Se agarra lo que está donde se apoyó el dedo (si no, un gesto
        // rápido agarraría otra esquina).
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (d) => _empezar(d.localPosition),
        onPanUpdate: (d) => _arrastrar(d.localPosition),
        onPanEnd: (_) => _soltar(),
        onPanCancel: _soltar,
        child: LayoutBuilder(
          builder: (context, limites) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BordesPainter(foto: widget.foto, puntos: puntos, activa: esquina),
                ),
              ),
              if (esquina != null) _lupa(puntos, esquina, limites.biggest),
            ],
          ),
        ),
      ),
    );
  }

  /// Un círculo con la foto ampliada alrededor de la esquina, arriba del
  /// dedo (o debajo, si no cabe), para dejarla justo en el borde del papel.
  Widget _lupa(List<Offset> puntos, int i, Size area) {
    const tam = 112.0;
    final punto = puntos[i];
    // Arriba del dedo (puede tapar la pista de arriba mientras se arrastra).
    final arriba = punto.dy - 96 - tam / 2 >= -150;
    final centro = Offset(
      punto.dx.clamp(tam / 2, area.width - tam / 2),
      arriba ? punto.dy - 96 : punto.dy + 96,
    );
    return Positioned(
      left: centro.dx - tam / 2,
      top: centro.dy - tam / 2,
      width: tam,
      height: tam,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _LupaPainter(
            imagen: widget.imagen,
            foto: widget.foto,
            punto: punto,
            vecinos: [puntos[(i + 3) % 4], puntos[(i + 1) % 4]],
          ),
        ),
      ),
    );
  }
}

/// Oscurece lo que queda fuera del papel y dibuja sus bordes, las esquinas
/// (círculos) y la mitad de cada lado (una rayita para arrastrarlo entero).
class _BordesPainter extends CustomPainter {
  const _BordesPainter({required this.foto, required this.puntos, required this.activa});

  final Rect foto;
  final List<Offset> puntos;
  final int? activa;

  @override
  void paint(Canvas canvas, Size size) {
    final papel = Path()..addPolygon(puntos, true);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(foto)
        ..addPath(papel, Offset.zero),
      Paint()..color = const Color(0x8C000000),
    );
    canvas.drawPath(
      papel,
      Paint()
        ..color = AppColors.camaraMarco
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Rayita en la mitad de cada lado, en la dirección del lado.
    final raya = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = puntos[i], b = puntos[(i + 1) % 4];
      final medio = (a + b) / 2;
      final largo = (b - a).distance;
      if (largo < 60) continue;
      final u = (b - a) / largo * 12;
      canvas.drawLine(medio - u, medio + u, raya);
    }

    for (var i = 0; i < 4; i++) {
      final r = i == activa ? 15.0 : 11.0;
      canvas.drawCircle(puntos[i], r, Paint()..color = i == activa ? AppColors.camaraMarco : Colors.white);
      canvas.drawCircle(
        puntos[i],
        r,
        Paint()
          ..color = AppColors.camaraMarco
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_BordesPainter oldDelegate) =>
      oldDelegate.foto != foto || oldDelegate.activa != activa || !_mismos(oldDelegate.puntos, puntos);

  static bool _mismos(List<Offset> a, List<Offset> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// La lupa: la foto ampliada 2,5 veces alrededor del [punto], con los dos
/// lados que salen de esa esquina y una cruz en el centro.
class _LupaPainter extends CustomPainter {
  const _LupaPainter({required this.imagen, required this.foto, required this.punto, required this.vecinos});

  static const _aumento = 2.5;

  final ui.Image imagen;
  final Rect foto;
  final Offset punto;
  final List<Offset> vecinos;

  @override
  void paint(Canvas canvas, Size size) {
    final circulo = Offset.zero & size;
    final centro = circulo.center;
    canvas.save();
    canvas.clipPath(Path()..addOval(circulo));
    canvas.drawRect(circulo, Paint()..color = AppColors.fondoCamara);

    // Qué parte de la foto (en sus píxeles) va en la lupa.
    final escala = imagen.width / foto.width;
    final medio = size.width / 2 / _aumento;
    final enFoto = Offset((punto.dx - foto.left) * escala, (punto.dy - foto.top) * escala);
    final fuente = Rect.fromCenter(center: enFoto, width: 2 * medio * escala, height: 2 * medio * escala);
    final dentro = fuente.intersect(Offset.zero & Size(imagen.width.toDouble(), imagen.height.toDouble()));
    if (dentro.width > 0 && dentro.height > 0) {
      // Solo lo que está dentro de la foto (lo de afuera queda oscuro).
      Offset aLupa(Offset p) => centro + (p - enFoto) / escala * _aumento;
      canvas.drawImageRect(
        imagen,
        dentro,
        Rect.fromPoints(aLupa(dentro.topLeft), aLupa(dentro.bottomRight)),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // Los lados que salen de la esquina, también ampliados.
    final lado = Paint()
      ..color = AppColors.camaraMarco
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final v in vecinos) {
      canvas.drawLine(centro, centro + (v - punto) * _aumento, lado);
    }
    final cruz = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    canvas.drawLine(centro - const Offset(10, 0), centro + const Offset(10, 0), cruz);
    canvas.drawLine(centro - const Offset(0, 10), centro + const Offset(0, 10), cruz);
    canvas.restore();

    canvas.drawOval(
      circulo.deflate(1.5),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_LupaPainter oldDelegate) =>
      oldDelegate.punto != punto || oldDelegate.imagen != imagen || oldDelegate.foto != foto;
}
