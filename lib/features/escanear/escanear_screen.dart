import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/illustrations/cedula_dibujo.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';

/// Estado de la cámara en la pantalla de escaneo.
enum _Camara {
  /// Pidiendo permiso o abriendo la cámara.
  cargando,

  /// Cámara real funcionando.
  lista,

  /// Sin cámara (web, pruebas): se dibuja la cédula de ejemplo.
  simulada,

  /// El usuario dijo "No permitir"; se puede volver a pedir.
  sinPermiso,

  /// Permiso negado para siempre: hay que ir a Ajustes.
  bloqueado,

  /// La cámara no se pudo abrir (otra app la usa, no hay cámara…).
  error,
}

/// 9 · Escanear: la cámara trasera dentro del marco, indicaciones, flash y
/// miniaturas de las páginas tomadas.
///
/// Las fotos solo viven en memoria hasta que se guardan cifradas; la copia
/// temporal que deja la cámara se borra apenas se lee.
class EscanearScreen extends StatefulWidget {
  const EscanearScreen({super.key, this.paginasPrevias = const []});

  /// Páginas que ya se habían tomado (al tocar "Otra página" en Guardar).
  final List<Uint8List> paginasPrevias;

  @override
  State<EscanearScreen> createState() => _EscanearScreenState();
}

class _EscanearScreenState extends State<EscanearScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _maxPaginas = 6;
  static const _pistas = [
    'Pon el frente de la cédula sobre una mesa, dentro del marco',
    '¡Bien! Ahora voltéala y escanea el reverso',
    'Listo. Puedes agregar otra página o tocar Terminar',
  ];

  _Camara _estado = _Camara.cargando;
  CameraController? _camara;
  bool _iniciando = false;
  bool _pausada = false;
  bool _tomando = false;
  String _detalleError = '';

  late final List<Uint8List> _fotos = List.of(widget.paginasPrevias);
  int _simuladas = 0;
  bool _flash = false;

  int get _paginas => _estado == _Camara.simulada ? _simuladas : _fotos.length;

  // Destello blanco al tomar la foto: opacidad 0.85 → 0 en 0.35 s.
  late final AnimationController _destello = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar(pedir: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camara?.dispose();
    _destello.dispose();
    super.dispose();
  }

  /// Al salir de la app se suelta la cámara (y la linterna); al volver, se
  /// reabre. También sirve al regresar de Ajustes después de dar el permiso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final c = _camara;
      if (c != null) {
        _camara = null;
        _pausada = true;
        _flash = false;
        c.dispose();
        if (mounted) setState(() => _estado = _Camara.cargando);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausada || _estado == _Camara.bloqueado || _estado == _Camara.sinPermiso) {
        _pausada = false;
        _iniciar(pedir: false);
      }
    }
  }

  /// Revisa el permiso (y lo pide si [pedir]) y abre la cámara trasera.
  Future<void> _iniciar({required bool pedir}) async {
    if (_iniciando) return;
    _iniciando = true;
    try {
      if (kIsWeb) {
        _poner(_Camara.simulada);
        return;
      }
      PermissionStatus permiso;
      try {
        permiso = pedir ? await Permission.camera.request() : await Permission.camera.status;
      } on MissingPluginException {
        _poner(_Camara.simulada); // pruebas automáticas: no hay plugins
        return;
      }
      if (permiso.isPermanentlyDenied || permiso.isRestricted) {
        _poner(_Camara.bloqueado);
        return;
      }
      if (!permiso.isGranted) {
        _poner(_Camara.sinPermiso);
        return;
      }

      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        _detalleError = 'Este celular no tiene cámara disponible.';
        _poner(_Camara.error);
        return;
      }
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final c = CameraController(
        trasera,
        ResolutionPreset.veryHigh, // 1080p: se leen bien los números
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await c.setFlashMode(FlashMode.off);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _camara = c;
        _flash = false;
        _estado = _Camara.lista;
      });
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied') {
        _poner(_Camara.sinPermiso);
      } else {
        _detalleError =
            'No pudimos abrir la cámara. Cierra otras apps que la estén usando e inténtalo de nuevo.';
        _poner(_Camara.error);
      }
    } on MissingPluginException {
      _poner(_Camara.simulada);
    } catch (_) {
      // Cualquier otra falla del sistema: se muestra el panel con "Intentar de nuevo".
      _detalleError = 'No pudimos abrir la cámara. Inténtalo de nuevo.';
      _poner(_Camara.error);
    } finally {
      _iniciando = false;
    }
  }

  void _poner(_Camara estado) {
    if (mounted) setState(() => _estado = estado);
  }

  Future<void> _cambiarFlash() async {
    final nuevo = !_flash;
    setState(() => _flash = nuevo);
    try {
      await _camara?.setFlashMode(nuevo ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      if (mounted) setState(() => _flash = false); // sin linterna en este celular
    }
  }

  Future<void> _capturar() async {
    if (_paginas >= _maxPaginas || _tomando) return;
    if (_estado == _Camara.simulada) {
      HapticFeedback.lightImpact();
      setState(() => _simuladas++);
      _destello.forward(from: 0);
      return;
    }
    final c = _camara;
    if (_estado != _Camara.lista || c == null || !c.value.isInitialized) return;
    _tomando = true;
    try {
      HapticFeedback.lightImpact();
      _destello.forward(from: 0);
      final foto = await c.takePicture();
      final bytes = await foto.readAsBytes();
      // La cámara deja una copia temporal sin cifrar: se borra ya.
      try {
        await File(foto.path).delete();
      } on FileSystemException {
        // Si ya no está, mejor.
      }
      if (mounted) setState(() => _fotos.add(bytes));
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo tomar la foto. Inténtalo otra vez.')));
      }
    } finally {
      _tomando = false;
    }
  }

  void _terminar() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.guardar,
      arguments: _estado == _Camara.simulada ? _simuladas : List<Uint8List>.of(_fotos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _paginas;
    final esFrente = n.isEven;
    final hayCamara = _estado == _Camara.lista || _estado == _Camara.simulada;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.fondoCamara,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior
              Container(
                height: 68,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    CircleButtonDark(
                      icon: AppIcons.cerrar,
                      semanticLabel: 'Cancelar escaneo',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Página ${n + 1}',
                        textAlign: TextAlign.center,
                        style: AppText.bold(17, color: Colors.white),
                      ),
                    ),
                    CircleButtonDark(
                      icon: AppIcons.flash,
                      semanticLabel: _flash ? 'Apagar linterna' : 'Encender linterna',
                      selected: _flash,
                      color: _flash ? AppColors.camaraFlash : Colors.white,
                      onTap: hayCamara ? _cambiarFlash : null,
                    ),
                  ],
                ),
              ),
              // Indicación
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Semantics(
                    key: ValueKey(n.clamp(0, 2)),
                    liveRegion: true,
                    child: Text(
                      _pistas[n.clamp(0, 2)],
                      textAlign: TextAlign.center,
                      style: AppText.body(16, color: Colors.white, height: 1.4),
                    ),
                  ),
                ),
              ),
              // Visor de la cámara
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.camaraMesa,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._visor(esFrente),
                      if (hayCamara)
                        Positioned(
                          bottom: 14,
                          child: Text(
                            esFrente ? 'Frente' : 'Reverso',
                            style: AppText.bold(15, color: AppColors.camaraEtiqueta),
                          ),
                        ),
                      // Destello de la foto
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _destello,
                            builder: (context, _) => ColoredBox(
                              color: Colors.white.withValues(
                                alpha: 0.85 * (1 - Curves.easeOut.transform(_destello.value)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Controles
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                child: Column(
                  spacing: 14,
                  children: [
                    SizedBox(
                      height: 60,
                      child: n == 0
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Aún no hay páginas',
                                style: AppText.body(15, color: AppColors.camaraTextoSuave),
                              ),
                            )
                          : NoScrollbar(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: n,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => Center(
                                  child: _Miniatura(
                                    numero: i + 1,
                                    imagen: i < _fotos.length ? _fotos[i] : null,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(
                            n == 0 ? '' : (n == 1 ? '1 página' : '$n páginas'),
                            style: AppText.body(15, color: AppColors.camaraTextoSuave),
                          ),
                        ),
                        Expanded(
                          child: Center(child: _Obturador(onTap: hayCamara ? _capturar : null)),
                        ),
                        SizedBox(
                          width: 112,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: n > 0
                                ? TcTap(
                                    onTap: _terminar,
                                    color: Colors.white,
                                    radius: 24,
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: const _EtiquetaTerminar(color: AppColors.fondoCamara),
                                  )
                                : Semantics(
                                    button: true,
                                    enabled: false,
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0x24FFFFFF),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const _EtiquetaTerminar(color: AppColors.camaraTerminarOff),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lo que se ve dentro del visor según el estado de la cámara.
  List<Widget> _visor(bool esFrente) {
    switch (_estado) {
      case _Camara.lista:
        final c = _camara!;
        final tam = c.value.previewSize;
        return [
          // La vista previa llena el visor recortando lo que sobre (como una foto "cover").
          Positioned.fill(
            child: tam == null
                ? CameraPreview(c)
                : FittedBox(
                    fit: BoxFit.cover,
                    // En vertical el sensor entrega la imagen "acostada": se invierten ancho y alto.
                    child: SizedBox(width: tam.height, height: tam.width, child: CameraPreview(c)),
                  ),
          ),
          const _MarcoDocumento(),
        ];
      case _Camara.simulada:
        return [
          Transform.rotate(
            angle: -3 * 3.14159265 / 180,
            child: SizedBox(
              width: 272,
              height: 180,
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: esFrente
                          ? const CedulaFrente(key: ValueKey('frente'), width: 252, height: 160, sombra: true)
                          : const CedulaReverso(
                              key: ValueKey('reverso'),
                              width: 252,
                              height: 160,
                              sombra: true,
                            ),
                    ),
                  ),
                  const _Esquina(top: true, left: true),
                  const _Esquina(top: true, left: false),
                  const _Esquina(top: false, left: true),
                  const _Esquina(top: false, left: false),
                ],
              ),
            ),
          ),
        ];
      case _Camara.cargando:
        return const [CircularProgressIndicator(color: AppColors.camaraMarco)];
      case _Camara.sinPermiso:
        return [
          _AvisoCamara(
            titulo: 'Tu Cajón necesita la cámara',
            texto: 'La usamos solo para fotografiar tus documentos. Las fotos se guardan cifradas en este celular y no se suben a internet.',
            boton: 'Permitir la cámara',
            onBoton: () => _iniciar(pedir: true),
            onSubir: () => Navigator.of(context).pushReplacementNamed(AppRoutes.guardar),
          ),
        ];
      case _Camara.bloqueado:
        return [
          _AvisoCamara(
            titulo: 'La cámara está desactivada',
            texto: 'Para escanear, entra a Ajustes › Permisos › Cámara y elige "Permitir solo mientras se usa la app".',
            boton: 'Abrir Ajustes',
            onBoton: openAppSettings,
            onSubir: () => Navigator.of(context).pushReplacementNamed(AppRoutes.guardar),
          ),
        ];
      case _Camara.error:
        return [
          _AvisoCamara(
            titulo: 'No se pudo abrir la cámara',
            texto: _detalleError,
            boton: 'Intentar de nuevo',
            onBoton: () => _iniciar(pedir: false),
            onSubir: () => Navigator.of(context).pushReplacementNamed(AppRoutes.guardar),
          ),
        ];
    }
  }
}

/// Marco con esquinas del tamaño de una cédula (85,6 × 54 mm) sobre la cámara.
class _MarcoDocumento extends StatelessWidget {
  const _MarcoDocumento();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: FractionallySizedBox(
        widthFactor: 0.86,
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Stack(
            children: [
              _Esquina(top: true, left: true),
              _Esquina(top: true, left: false),
              _Esquina(top: false, left: true),
              _Esquina(top: false, left: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel dentro del visor cuando no hay cámara: explica qué pasa y qué hacer.
class _AvisoCamara extends StatelessWidget {
  const _AvisoCamara({
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onBoton,
    required this.onSubir,
  });

  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback onBoton;
  final VoidCallback onSubir;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const TcIcon(AppIcons.camara, size: 34, color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: AppText.bold(19, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: AppText.body(15, color: AppColors.camaraTextoSuave, height: 1.45),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: boton, onTap: onBoton, height: 54),
          const SizedBox(height: 10),
          TcTap(
            onTap: onSubir,
            radius: 16,
            minHeight: 48,
            child: Center(
              child: Text('Mejor subir un archivo', style: AppText.bold(15, color: AppColors.camaraMarco)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Terminar" en una sola línea; se achica si la letra del celular es muy grande.
class _EtiquetaTerminar extends StatelessWidget {
  const _EtiquetaTerminar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Terminar', maxLines: 1, style: AppText.bold(16, color: color)),
      ),
    );
  }
}

/// Botón redondo translúcido de la cámara.
class CircleButtonDark extends StatelessWidget {
  const CircleButtonDark({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.color = Colors.white,
    this.selected,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color color;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: const Color(0x1AFFFFFF),
      radius: 24,
      width: 48,
      height: 48,
      semanticLabel: semanticLabel,
      selected: selected,
      child: Center(child: TcIcon(icon, size: 22, color: color)),
    );
  }
}

class _Esquina extends StatelessWidget {
  const _Esquina({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Transform.flip(
        flipX: !left,
        flipY: !top,
        child: const CustomPaint(size: Size(28, 28), painter: _EsquinaPainter()),
      ),
    );
  }
}

/// Esquina superior izquierda del marco (las otras se obtienen volteándola).
class _EsquinaPainter extends CustomPainter {
  const _EsquinaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const w = 4.0;
    const r = 10.0;
    final p = Paint()
      ..color = AppColors.camaraMarco
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    final path = Path()
      ..moveTo(w / 2, size.height)
      ..lineTo(w / 2, r)
      ..arcToPoint(Offset(r, w / 2), radius: const Radius.circular(r - w / 2))
      ..lineTo(size.width, w / 2);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_EsquinaPainter oldDelegate) => false;
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.numero, this.imagen});

  final int numero;

  /// La foto tomada (JPEG); en modo simulado es `null`.
  final Uint8List? imagen;

  @override
  Widget build(BuildContext context) {
    // Entra creciendo de 0.6 a 1 con fundido (0.3 s).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Semantics(
        label: 'Página $numero',
        child: SizedBox(
          width: 50,
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.idFondo,
                  border: Border.all(color: AppColors.camaraMarco, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: imagen == null
                    ? null
                    // cacheWidth: decodifica la miniatura pequeña, no la foto de 1080p entera.
                    : Image.memory(imagen!, fit: BoxFit.cover, cacheWidth: 120, gaplessPlayback: true),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AppColors.primario, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$numero', style: AppText.bold(12, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Obturador extends StatelessWidget {
  const _Obturador({required this.onTap});

  /// `null` mientras la cámara no está lista (el botón se ve apagado).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tomar foto',
      enabled: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
