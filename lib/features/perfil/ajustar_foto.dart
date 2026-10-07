import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../escanear/fotos_del_celular.dart';
import '../escanear/pixeles.dart';

/// Lado de la foto de un perfil (cuadrada).
const ladoFotoPerfil = 512;

/// Abre la foto para acomodarla dentro del círculo. Devuelve la foto del
/// perfil (JPEG cuadrado de [ladoFotoPerfil] px), o `null` si se cancela.
Future<Uint8List?> ajustarFotoDePerfil(BuildContext context, Uint8List foto) =>
    Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => AjustarFotoScreen(foto: foto)));

/// Ajustar la foto del perfil: se mueve y se acerca con los dedos; lo que
/// queda dentro del círculo es la foto.
class AjustarFotoScreen extends StatefulWidget {
  const AjustarFotoScreen({super.key, required this.foto});

  final Uint8List foto;

  @override
  State<AjustarFotoScreen> createState() => _AjustarFotoScreenState();
}

class _AjustarFotoScreenState extends State<AjustarFotoScreen> {
  final _control = TransformationController();
  ui.Image? _imagen;
  bool _noAbre = false;
  bool _guardando = false;

  /// Lado del cuadro en pantalla y tamaño con que se dibuja la foto en él
  /// (la cubre entera, como "cover").
  double _lado = 0;
  Size _dibujada = Size.zero;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.foto);
      final cuadro = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        cuadro.image.dispose();
        return;
      }
      setState(() => _imagen = cuadro.image);
    } catch (_) {
      if (mounted) setState(() => _noAbre = true);
    }
  }

  @override
  void dispose() {
    _control.dispose();
    _imagen?.dispose();
    super.dispose();
  }

  /// La foto cubre el cuadro de [lado] y empieza centrada.
  void _medir(double lado) {
    final imagen = _imagen!;
    if (lado == _lado) return;
    final primera = _lado == 0;
    _lado = lado;
    final escala = lado / math.min(imagen.width, imagen.height);
    _dibujada = Size(imagen.width * escala, imagen.height * escala);
    final centrada = Matrix4.translationValues(
      -(_dibujada.width - lado) / 2,
      -(_dibujada.height - lado) / 2,
      0,
    );
    // Se mide mientras se construye: si el visor ya existe, se le avisa después.
    if (primera) {
      _control.value = centrada;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _control.value = centrada);
    }
  }

  /// Lo que se ve en el cuadro, en píxeles de la foto, recortado y achicado.
  Future<void> _usar() async {
    final imagen = _imagen;
    if (imagen == null || _guardando) return;
    setState(() => _guardando = true);
    final navigator = Navigator.of(context);
    try {
      final m = _control.value;
      final zoom = m.getMaxScaleOnAxis();
      final t = m.getTranslation();
      final porPixel = imagen.width / _dibujada.width;
      final x = (-t.x / zoom * porPixel).round();
      final y = (-t.y / zoom * porPixel).round();
      final lado = (_lado / zoom * porPixel).round();
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixeles = Pixeles(
        datos!.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
        imagen.width,
        imagen.height,
      );
      navigator.pop(await aJpeg(await _recortarCuadrado(pixeles, x, y, lado)));
    } catch (e) {
      debugPrint('No se pudo recortar la foto del perfil: $e');
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _imagen;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.fondoCamara,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    TcTap(
                      onTap: () => Navigator.of(context).pop(),
                      color: const Color(0x1AFFFFFF),
                      radius: 24,
                      width: 48,
                      height: 48,
                      semanticLabel: 'Cancelar',
                      child: const Center(child: TcIcon(AppIcons.cerrar, size: 22, color: Colors.white)),
                    ),
                    Expanded(
                      child: Text(
                        'Ajusta la foto',
                        textAlign: TextAlign.center,
                        style: AppText.bold(17, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                child: Text(
                  'Mueve y acerca la foto con los dedos. Lo que queda dentro del círculo es la foto del perfil.',
                  textAlign: TextAlign.center,
                  style: AppText.body(15, color: AppColors.camaraTextoSuave, height: 1.4),
                ),
              ),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, limites) {
                      final lado = math.min(limites.maxWidth - 40, limites.maxHeight - 40);
                      if (_noAbre) {
                        return Text(
                          'No se pudo abrir esta foto. Prueba con otra.',
                          style: AppText.body(15, color: Colors.white),
                        );
                      }
                      if (imagen == null) {
                        return const CircularProgressIndicator(color: AppColors.camaraMarco);
                      }
                      _medir(lado);
                      return SizedBox.square(
                        dimension: lado,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRect(
                                child: InteractiveViewer(
                                  transformationController: _control,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 6,
                                  boundaryMargin: EdgeInsets.zero,
                                  child: SizedBox.fromSize(
                                    size: _dibujada,
                                    child: RawImage(image: imagen, fit: BoxFit.fill),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: IgnorePointer(child: CustomPaint(painter: _MascaraCirculo())),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: PrimaryButton(
                  label: _guardando ? 'Preparando la foto…' : 'Usar esta foto',
                  icon: AppIcons.check,
                  disabledLabel: _noAbre ? 'Elige otra foto' : 'Abriendo la foto…',
                  onTap: imagen == null || _guardando ? null : _usar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El cuadrado de [lado] px desde ([x], [y]), achicado a [ladoFotoPerfil], en
/// otro hilo. (Afuera de la pantalla: así al otro hilo solo viajan los
/// píxeles, no la imagen dibujada.)
Future<Pixeles> _recortarCuadrado(Pixeles p, int x, int y, int lado) =>
    Isolate.run(() => achicarSiHaceFalta(recortarPixeles(p, x, y, lado, lado), ladoMaximo: ladoFotoPerfil));

/// Oscurece lo que queda fuera del círculo y marca su borde.
class _MascaraCirculo extends CustomPainter {
  const _MascaraCirculo();

  @override
  void paint(Canvas canvas, Size size) {
    final circulo = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 1);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(circulo),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawOval(
      circulo,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MascaraCirculo oldDelegate) => false;
}
