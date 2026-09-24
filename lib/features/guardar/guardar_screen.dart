import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/avisos/recordatorios.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../core/formato.dart';
import '../../data/models/categoria.dart';
import '../../data/models/documento.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/interruptor.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/text_field.dart';
import '../paginas/paginas_screen.dart';

/// De dónde vienen las fotos (a dónde lleva "Otra página").
enum OrigenFotos { camara, galeria }

/// Fotos elegidas en la galería (y ya revisadas), listas para guardar.
class FotosDeGaleria {
  const FotosDeGaleria(this.fotos);

  final List<Uint8List> fotos;
}

/// Un PDF subido desde el explorador de archivos (o que llegó por
/// "Compartir"), listo para guardar.
class PdfSubido {
  const PdfSubido({
    required this.bytes,
    required this.paginas,
    required this.nombreArchivo,
    this.portada,
    this.aviso,
    this.recibido = false,
  });

  final Uint8List bytes;
  final int paginas;

  /// "Certificado_EPS_2026.pdf".
  final String nombreArchivo;

  /// La primera página dibujada (JPEG), si se pudo.
  final Uint8List? portada;

  /// Algo que decirle a la persona (p. ej. que el PDF tiene contraseña).
  final String? aviso;

  /// Llegó desde otra app con "Compartir → Tu Cajón".
  final bool recibido;

  /// "Certificado_EPS_2026.pdf" → "Certificado EPS 2026".
  String get nombreSugerido {
    final sinExtension = nombreArchivo.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    final limpio = sinExtension.replaceAll(RegExp(r'[_\-.]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpio.isEmpty) return '';
    return limpio[0].toUpperCase() + limpio.substring(1);
  }
}

/// "Reemplazar": las páginas nuevas (fotos o un PDF) para un documento que
/// ya está guardado.
class Reemplazo {
  const Reemplazo({required this.documento, this.fotos = const [], this.pdf});

  final Documento documento;
  final List<Uint8List> fotos;
  final PdfSubido? pdf;
}

/// Avisos que se ven al volver al documento: van encima de sus botones de
/// WhatsApp y compartir, para no taparlos.
const margenAvisoEnDocumento = EdgeInsets.fromLTRB(16, 0, 16, 184);

/// "Editar datos": cambiar nombre, de quién es, tipo o vencimiento de un
/// documento, sin tocar sus páginas.
class EditarDatos {
  const EditarDatos(this.documento);

  final Documento documento;
}

enum _Modo {
  /// Un documento nuevo.
  nuevo,

  /// Páginas nuevas para un documento que ya existe.
  reemplazar,

  /// Solo los datos de un documento que ya existe.
  editar,
}

/// 10 · Guardar: el usuario revisa nombre, de quién es, qué tipo de
/// documento es y si se vence.
///
/// Llega de la cámara, de la galería (fotos ya revisadas, también las que
/// llegan por "Compartir") o de un PDF subido o compartido (se propone el
/// nombre del archivo). Con [existente], los datos de ese documento vienen
/// ya puestos: si llegan páginas nuevas, reemplazan a las suyas
/// ("Reemplazar"); si no, solo se cambian sus datos ("Editar datos").
class GuardarScreen extends StatefulWidget {
  const GuardarScreen({
    super.key,
    this.paginas = 2,
    this.fotos = const [],
    this.origen = OrigenFotos.camara,
    this.pdf,
    this.existente,
  });

  /// Páginas que se escanearon (2 = frente y reverso).
  final int paginas;

  /// Las fotos reales (JPEG) de la cámara o la galería. Vacío en modo simulado.
  final List<Uint8List> fotos;
  final OrigenFotos origen;

  /// Si se subió un PDF: se guarda tal cual, en vez de fotos.
  final PdfSubido? pdf;

  /// El documento que ya está guardado ("Reemplazar" o "Editar datos").
  final Documento? existente;

  @override
  State<GuardarScreen> createState() => _GuardarScreenState();
}

class _GuardarScreenState extends State<GuardarScreen> {
  // Nada se adivina: todavía no hay nada que lea el papel. Un PDF propone el
  // nombre de su archivo; al reemplazar, quedan los datos que ya tenía.
  late final _nombre = TextEditingController(
    text: widget.existente?.nombre ?? widget.pdf?.nombreSugerido ?? '',
  );
  late Categoria _categoria = widget.existente?.categoria ?? Categoria.otro;
  late String _perfilId = widget.existente?.perfilId ?? Perfil.idPropio;
  late bool _seVence = widget.existente?.venceEn != null;
  bool _guardando = false;
  late DateTime _fecha = widget.existente?.venceEn ?? DateTime.now().add(const Duration(days: 365));

  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();

  String get _fechaTexto => Formato.fechaLarga(_fecha);

  _Modo get _modo => widget.existente == null
      ? _Modo.nuevo
      : widget.fotos.isEmpty && widget.pdf == null
      ? _Modo.editar
      : _Modo.reemplazar;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year - 1);
    final hasta = DateTime(hoy.year + 20);
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      // Un documento que ya venció hace tiempo trae una fecha más vieja.
      firstDate: _fecha.isBefore(desde) ? _fecha : desde,
      lastDate: _fecha.isAfter(hasta) ? _fecha : hasta,
      helpText: 'Fecha de vencimiento',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cerrojo = context.cerrojo;
    final recordatorios = context.recordatorios;
    final String id;
    final pdf = widget.pdf;
    final existente = widget.existente;
    final modo = _modo;
    final datos = NuevoDocumento(
      perfilId: _perfilId,
      nombre: _nombre.text,
      categoria: _categoria,
      paginas: pdf?.paginas ?? widget.paginas,
      // Sin fotos reales (modo simulado): tamaño aproximado de un escaneo.
      tamanoBytes: pdf?.bytes.length ?? widget.paginas * 240 * 1024,
      venceEn: _seVence ? _fecha : null,
    );
    try {
      // Con fotos reales o un PDF, se guardan cifrados y el tamaño sale de ellos.
      // Si no llegan (editar datos), las páginas del documento no se tocan.
      if (existente != null) {
        await context.repo.actualizarDocumento(existente.id, datos, paginas: widget.fotos, pdf: pdf?.bytes);
        id = existente.id;
      } else {
        id = await context.repo.guardarDocumento(datos, paginas: widget.fotos, pdf: pdf?.bytes);
      }
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo guardar. Inténtalo de nuevo.')));
      rethrow;
    }
    // Si la persona salió mientras se guardaba, espera a que abra con su
    // llave: si no, el cambio de pantalla quitaría la pantalla de la llave.
    await cerrojo.esperarAbierto();
    // Con fecha de vencimiento, es el momento de pedir las notificaciones
    // (solo si nunca se han pedido; si dijo que no, no se insiste).
    if (_seVence && await recordatorios.permiso() == PermisoAvisos.sinPedir) {
      await recordatorios.pedirPermiso();
    }
    if (modo == _Modo.editar) {
      // De vuelta al documento, que ya muestra los datos nuevos.
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Listo: cambios guardados.'),
          behavior: SnackBarBehavior.floating,
          margin: margenAvisoEnDocumento,
        ),
      );
      navigator.pop();
      return;
    }
    if (modo == _Modo.reemplazar) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Listo: «${datos.nombre.trim()}» ya tiene las páginas nuevas.'),
          behavior: SnackBarBehavior.floating,
          margin: margenAvisoEnDocumento,
        ),
      );
    }
    // Vuelve a "Mi cajón" y abre el documento recién guardado encima.
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.detalle,
      (r) => r.settings.name == AppRoutes.cajon,
      arguments: id,
    );
  }

  /// El recuadro de arriba: título y texto según de dónde viene el documento.
  (String, String) get _aviso {
    if (widget.pdf?.aviso case final aviso?) return ('Revisa este PDF', aviso);
    if (widget.existente case final d?) {
      return _modo == _Modo.editar
          ? ('Cambia lo que necesites', 'Las páginas no se tocan. Para cambiarlas, usa «Editar páginas».')
          : (
              'Reemplazas «${d.nombre}»',
              'Las páginas nuevas cambian a las de antes. Si cambió la fecha de vencimiento, actualízala abajo.',
            );
    }
    if (widget.pdf case final pdf?) {
      return pdf.recibido
          ? ('Llegó a tu cajón', 'Revisa el nombre y elige de quién es y qué tipo de documento es.')
          : ('Usamos el nombre del archivo', 'Revisa que esté bien y elige qué tipo de documento es.');
    }
    return ('Ponle un nombre', 'Así lo encuentras rápido cuando lo busques.');
  }

  /// Vuelve a la cámara o a las páginas de la galería sin perder las fotos
  /// que ya hay. Al reemplazar no aplica: las páginas ya se revisaron.
  VoidCallback? get _otraPagina {
    if (widget.existente != null) return null;
    return () => widget.origen == OrigenFotos.galeria
        ? Navigator.of(context)
              .pushReplacementNamed(AppRoutes.paginas, arguments: EntradaPaginas(listas: widget.fotos))
        : Navigator.of(context).pushReplacementNamed(AppRoutes.escanear, arguments: widget.fotos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackHeader(
              title: switch (_modo) {
                _Modo.nuevo => 'Guardar documento',
                _Modo.reemplazar => 'Reemplazar documento',
                _Modo.editar => 'Editar datos',
              },
            ),
            Expanded(
              child: NoScrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    if (widget.pdf case final pdf?)
                      _PdfSubido(pdf: pdf)
                    else if (_modo != _Modo.editar)
                      _Paginas(paginas: widget.paginas, fotos: widget.fotos, onOtra: _otraPagina),
                    if (_modo != _Modo.editar) const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarioSuave,
                        borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: TcIcon(
                              _modo == _Modo.reemplazar ? AppIcons.reemplazar : AppIcons.lapiz,
                              size: 22,
                              color: AppColors.primario,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                Text(_aviso.$1, style: AppText.bold(16, color: AppColors.primario)),
                                Text(
                                  _aviso.$2,
                                  style: AppText.body(14, color: AppColors.primarioTextoSuave, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TcTextField(label: 'Nombre del documento', controller: _nombre),
                    const SizedBox(height: 18),
                    Text('¿De quién es?', style: AppText.bold(16)),
                    const SizedBox(height: 10),
                    StreamBuilder(
                      stream: _perfiles,
                      builder: (context, snap) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in snap.data ?? const <Perfil>[])
                            PillChip(
                              label: p.esPropio ? 'Mío' : p.nombre,
                              selected: p.id == _perfilId,
                              onTap: () => setState(() => _perfilId = p.id),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('¿Qué tipo de documento es?', style: AppText.bold(16)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Al reemplazar, también la que ya tenía aunque no se ofrezca al guardar.
                        for (final c in [
                          ...Categoria.alGuardar,
                          if (!Categoria.alGuardar.contains(_categoria)) _categoria,
                        ])
                          PillChip(
                            label: c.etiqueta,
                            selected: c == _categoria,
                            onTap: () => setState(() => _categoria = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Vencimiento(
                      activo: _seVence,
                      fecha: _fechaTexto,
                      onToggle: () => setState(() => _seVence = !_seVence),
                      onFecha: _elegirFecha,
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                const PrivacyNote('Se guarda cifrado, solo en este celular'),
                PrimaryButton(
                  label: switch (_modo) {
                    _Modo.nuevo => 'Guardar en mi cajón',
                    _Modo.reemplazar => 'Reemplazar documento',
                    _Modo.editar => 'Guardar cambios',
                  },
                  icon: AppIcons.cajon,
                  disabledLabel: _guardando ? 'Guardando…' : 'Escribe un nombre para guardar',
                  onTap: _guardando || _nombre.text.trim().isEmpty ? null : _guardar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Paginas extends StatelessWidget {
  const _Paginas({required this.paginas, required this.fotos, required this.onOtra});

  final int paginas;
  final List<Uint8List> fotos;

  /// "Otra página"; sin él, no se ofrece.
  final VoidCallback? onOtra;

  @override
  Widget build(BuildContext context) {
    Widget pagina(String etiqueta, Uint8List? foto) => Container(
      width: 96,
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: AppDecor.tarjeta(radius: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // La foto toma el alto que sobre; con letra grande se achica.
          Flexible(
            child: Container(
              width: 78,
              height: foto == null ? 50 : 78,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: AppColors.idFondo, borderRadius: BorderRadius.circular(8)),
              child: foto == null ? null : Image.memory(foto, fit: BoxFit.cover, cacheWidth: 200),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(etiqueta, maxLines: 1, style: AppText.bold(13, color: AppColors.textoSecundario)),
          ),
        ],
      ),
    );

    // Dos páginas son frente y reverso; con más, se numeran.
    final etiquetas = paginas == 2
        ? const ['Frente', 'Reverso']
        : [for (var i = 1; i <= paginas; i++) 'Página $i'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < etiquetas.length; i++) pagina(etiquetas[i], i < fotos.length ? fotos[i] : null),
        if (onOtra case final onOtra?)
          Semantics(
            button: true,
            label: 'Agregar otra página',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onOtra,
              child: DashedBorder(
                width: 96,
                height: 124,
                radius: 20,
                color: AppColors.bordePunteado,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6,
                  children: [
                    const TcIcon(AppIcons.mas, size: 24, color: AppColors.textoSecundario),
                    Text('Otra página', style: AppText.bold(13, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// El PDF subido: su primera página (o la etiqueta "PDF") y cuántas páginas tiene.
class _PdfSubido extends StatelessWidget {
  const _PdfSubido({required this.pdf});

  final PdfSubido pdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.tarjeta(radius: 20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 94,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.superficieSuave,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borde),
            ),
            alignment: Alignment.center,
            child: pdf.portada != null
                ? Image.memory(pdf.portada!, fit: BoxFit.cover, cacheWidth: 220)
                : Text('PDF', style: AppText.bold(14, color: AppColors.rojo)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  pdf.nombreArchivo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bold(16),
                ),
                Text(
                  'PDF · ${pdf.paginas == 1 ? '1 página' : '${pdf.paginas} páginas'} · ${Formato.tamano(pdf.bytes.length)}',
                  style: AppText.secondary(14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Vencimiento extends StatelessWidget {
  const _Vencimiento({
    required this.activo,
    required this.fecha,
    required this.onToggle,
    required this.onFecha,
  });

  final bool activo;
  final String fecha;
  final VoidCallback onToggle;
  final VoidCallback onFecha;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecor.tarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            toggled: activo,
            label: '¿Este documento se vence?',
            excludeSemantics: true,
            child: TcTap(
              onTap: onToggle,
              radius: 0,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const TcIcon(AppIcons.calendario, size: 22, color: AppColors.primario),
                  const SizedBox(width: 10),
                  Expanded(child: Text('¿Este documento se vence?', style: AppText.bold(16))),
                  const SizedBox(width: 12),
                  Interruptor(activo: activo),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: activo
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.divisor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        Text('Fecha de vencimiento', style: AppText.bold(15)),
                        TcTap(
                          onTap: onFecha,
                          color: AppColors.superficieSuave,
                          radius: 14,
                          height: 52,
                          semanticLabel: 'Fecha de vencimiento: $fecha. Toca para cambiarla',
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Expanded(child: Text(fecha, style: AppText.body(17))),
                              const TcIcon(AppIcons.calendario, size: 20, color: AppColors.textoSecundario),
                            ],
                          ),
                        ),
                        Text(
                          'Te avisamos con una notificación 30 días y 7 días antes, y el mismo día.',
                          style: AppText.secondary(14, height: 1.4),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
