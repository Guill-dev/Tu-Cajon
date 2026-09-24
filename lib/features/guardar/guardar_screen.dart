import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

/// 10 · Guardar: el usuario revisa nombre, carpeta y si se vence.
///
/// Llega de tres lados: la cámara (la "IA" propone una cédula), la galería
/// (fotos ya revisadas, también las que llegan por "Compartir") o un PDF
/// subido o compartido desde otra app (se propone el nombre del archivo).
class GuardarScreen extends StatefulWidget {
  const GuardarScreen({
    super.key,
    this.paginas = 2,
    this.fotos = const [],
    this.origen = OrigenFotos.camara,
    this.pdf,
  });

  /// Páginas que se escanearon (2 = frente y reverso).
  final int paginas;

  /// Las fotos reales (JPEG) de la cámara o la galería. Vacío en modo simulado.
  final List<Uint8List> fotos;
  final OrigenFotos origen;

  /// Si se subió un PDF: se guarda tal cual, en vez de fotos.
  final PdfSubido? pdf;

  @override
  State<GuardarScreen> createState() => _GuardarScreenState();
}

class _GuardarScreenState extends State<GuardarScreen> {
  // Cámara: la "IA" todavía no lee el papel y propone una cédula, como en el
  // diseño. PDF: el nombre del archivo. Galería: lo escribe la persona.
  late final _nombre = TextEditingController(
    text: widget.pdf != null
        ? widget.pdf!.nombreSugerido
        : widget.origen == OrigenFotos.galeria
        ? ''
        : 'Cédula de ciudadanía',
  );
  late Categoria _categoria = widget.pdf == null && widget.origen == OrigenFotos.camara
      ? Categoria.identidad
      : Categoria.otro;
  String _perfilId = Perfil.idPropio;
  bool _seVence = false;
  bool _guardando = false;
  DateTime _fecha = DateTime.now().add(const Duration(days: 365));

  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();

  String get _fechaTexto => Formato.fechaLarga(_fecha);

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
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 20),
      helpText: 'Fecha de vencimiento',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cerrojo = context.cerrojo;
    final String id;
    final pdf = widget.pdf;
    try {
      id = await context.repo.guardarDocumento(
        NuevoDocumento(
          perfilId: _perfilId,
          nombre: _nombre.text,
          categoria: _categoria,
          paginas: pdf?.paginas ?? widget.paginas,
          // Sin fotos reales (modo simulado): tamaño aproximado de un escaneo.
          tamanoBytes: pdf?.bytes.length ?? widget.paginas * 240 * 1024,
          venceEn: _seVence ? _fecha : null,
        ),
        // Con fotos reales o un PDF, se guardan cifrados y el tamaño sale de ellos.
        paginas: widget.fotos,
        pdf: pdf?.bytes,
      );
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo guardar. Inténtalo de nuevo.')));
      rethrow;
    }
    // Si la persona salió mientras se guardaba, espera a que abra con su
    // llave: si no, el cambio de pantalla quitaría la pantalla de la llave.
    await cerrojo.esperarAbierto();
    // Vuelve a "Mi cajón" y abre el documento recién guardado encima.
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.detalle,
      (r) => r.settings.name == AppRoutes.cajon,
      arguments: id,
    );
  }

  bool get _desdeCamara => widget.pdf == null && widget.origen == OrigenFotos.camara;

  /// El recuadro de arriba: título y texto según de dónde viene el documento.
  (String, String) get _aviso {
    if (widget.pdf case final pdf?) {
      if (pdf.aviso case final aviso?) return ('Revisa este PDF', aviso);
      return pdf.recibido
          ? ('Llegó a tu cajón', 'Revisa el nombre y elige de quién es y qué tipo de documento es.')
          : ('Usamos el nombre del archivo', 'Revisa que esté bien y elige qué tipo de documento es.');
    }
    if (widget.origen == OrigenFotos.galeria) {
      return ('Ponle un nombre', 'Así lo encuentras rápido cuando lo busques.');
    }
    return ('Parece una cédula de ciudadanía', 'La IA llenó los datos por ti. Revisa que estén bien.');
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
            const BackHeader(title: 'Guardar documento'),
            Expanded(
              child: NoScrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    if (widget.pdf case final pdf?)
                      _PdfSubido(pdf: pdf)
                    else
                      _Paginas(
                        paginas: widget.paginas,
                        fotos: widget.fotos,
                        // Vuelve a la cámara o a las páginas de la galería sin
                        // perder las fotos que ya hay.
                        onOtra: () => widget.origen == OrigenFotos.galeria
                            ? Navigator.of(context).pushReplacementNamed(
                                AppRoutes.paginas,
                                arguments: EntradaPaginas(listas: widget.fotos),
                              )
                            : Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.escanear, arguments: widget.fotos),
                      ),
                    const SizedBox(height: 18),
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
                              _desdeCamara ? AppIcons.destello : AppIcons.lapiz,
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
                        for (final c in Categoria.alGuardar)
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
                  label: 'Guardar en mi cajón',
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
  final VoidCallback onOtra;

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
                  _Interruptor(activo: activo),
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
                          'Te avisaremos antes y la IA te dirá qué necesitas para renovarlo.',
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

/// Interruptor redondo del diseño (52×32, perilla que se desliza en 0.15 s).
class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 52,
      height: 32,
      decoration: BoxDecoration(
        color: activo ? AppColors.primario : AppColors.switchApagado,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
