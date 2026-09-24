import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../core/pdf/lector_pdf.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../data/models/documento.dart';
import '../../shared/illustrations/cedula_dibujo.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';
import '../compartir/enviar_documento.dart';
import '../guardar/guardar_screen.dart';
import '../paginas/paginas_screen.dart';
import 'visor_paginas.dart';

/// 6 · Documento: vista previa, datos, acciones y "Enviar por WhatsApp".
///
/// "Enviar por WhatsApp" arma un PDF con las fotos y abre WhatsApp directo
/// para elegir el contacto. "Compartir de otra forma" abre el menú de
/// compartir del celular con el mismo PDF (correo, Drive, imprimir…).
class DetalleScreen extends StatefulWidget {
  const DetalleScreen({super.key, this.documentoId});

  /// Si no llega ninguno se muestra el documento más reciente (catálogo).
  final String? documentoId;

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> with ToastMixin {
  /// Mientras se arma el PDF: `true` si va a WhatsApp, `false` si al menú.
  bool? _enviando;

  Future<void> _enviar(Documento d, {required bool porWhatsApp}) async {
    if (_enviando != null) return;
    setState(() => _enviando = porWhatsApp);
    await enviarDocumento(context, d, porWhatsApp: porWhatsApp, avisar: (m) => mounted ? showToast(m) : null);
    if (mounted) setState(() => _enviando = null);
  }

  /// Se vigila el documento: si se renombra, el título cambia al instante.
  late final Stream<Documento?> _doc = widget.documentoId != null
      ? context.repo.vigilarDocumento(widget.documentoId!)
      : context.repo.vigilarTodos().map((docs) => docs.firstOrNull);

  /// Mientras se descifran las páginas para editarlas.
  bool _abriendoPaginas = false;

  /// El PDF más largo que se deja editar (sus páginas se dibujan todas).
  static const _maximoPaginasPdf = 60;

  /// "Editar páginas": se descifran las páginas (o se dibujan las del PDF
  /// subido) y se abren con las herramientas de siempre.
  Future<void> _editarPaginas(Documento d) async {
    if (_abriendoPaginas) return;
    setState(() => _abriendoPaginas = true);
    final repo = context.repo;
    final cerrojo = context.cerrojo;
    final navigator = Navigator.of(context);
    try {
      var paginas = await repo.leerPaginas(d);
      var eraPdf = false;
      if (paginas.isEmpty) {
        final pdf = await repo.leerPdf(d);
        if (pdf != null) {
          final total = await LectorPdf.contarPaginas(pdf);
          if (total > _maximoPaginasPdf) {
            if (mounted) {
              showToast(
                'Este PDF tiene $total páginas; se pueden editar hasta $_maximoPaginasPdf. Puedes reemplazarlo.',
                duration: const Duration(seconds: 5),
              );
            }
            return;
          }
          paginas = await LectorPdf.dibujar(pdf, ancho: 1700);
          eraPdf = true;
        }
      }
      // Si la persona salió mientras tanto, primero abre con su llave.
      await cerrojo.esperarAbierto();
      if (!mounted) return;
      navigator.pushNamed(
        AppRoutes.paginas,
        arguments: EntradaPaginas(listas: paginas, edita: d, eraPdf: eraPdf),
      );
    } on ErrorPdf catch (e) {
      if (!mounted) return;
      showToast(
        e.problema == ProblemaPdf.conClave
            ? 'Este PDF tiene contraseña: sus páginas no se pueden editar aquí. Puedes reemplazarlo.'
            : e.mensaje,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) setState(() => _abriendoPaginas = false);
    }
  }

  Future<void> _eliminar(Documento d) async {
    final navigator = Navigator.of(context);
    final repo = context.repo;
    final ok = await confirmarEliminar(context, d.nombre);
    if (!ok) return;
    await repo.eliminarDocumento(d.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _doc,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(backgroundColor: AppColors.fondo);
        }
        final d = snap.data;
        if (d == null) return const _SinDocumento();
        return _pantalla(context, d);
      },
    );
  }

  Widget _pantalla(BuildContext context, Documento d) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BackHeader(title: d.nombre, backLabel: 'Volver a mi cajón'),
                Expanded(
                  child: NoScrollbar(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      children: [
                        _VistaPrevia(
                          documento: d,
                          onSinFoto: () => showToast('Este documento de ejemplo no tiene foto.'),
                        ),
                        const SizedBox(height: 14),
                        //  Botones primero
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: _Accion(
                                icono: AppIcons.lapiz,
                                etiqueta: 'Editar datos',
                                // Nombre, de quién es, tipo y vencimiento.
                                onTap: () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.guardar, arguments: EditarDatos(d)),
                              ),
                            ),
                            Expanded(
                              child: _Accion(
                                icono: AppIcons.galeria,
                                etiqueta: _abriendoPaginas ? 'Abriendo…' : 'Editar páginas',
                                onTap: () => _editarPaginas(d),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: _Accion(
                                icono: AppIcons.reemplazar,
                                etiqueta: 'Reemplazar',
                                // Mismo documento, páginas nuevas.
                                onTap: () => Navigator.of(context).pushNamed(AppRoutes.agregar, arguments: d),
                              ),
                            ),
                            Expanded(
                              child: _Accion(
                                icono: AppIcons.basura,
                                etiqueta: 'Eliminar',
                                color: AppColors.rojo,
                                onTap: () => _eliminar(d),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        //  Atributos después
                        _Datos(
                          filas: [
                            ('Carpeta', d.categoria.etiqueta),
                            ('Guardado', d.guardadoTexto),
                            ('Archivo', d.detalleCompleto),
                            ('Vencimiento', d.vencimientoTexto),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                BottomActionBar(
                  children: [
                    PrimaryButton(
                      label: 'Enviar por WhatsApp',
                      icon: AppIcons.whatsapp,
                      color: AppColors.verde,
                      disabledLabel: _enviando == true ? 'Preparando el PDF…' : null,
                      onTap: _enviando == null ? () => _enviar(d, porWhatsApp: true) : null,
                    ),
                    OutlineButtonTc(
                      label: _enviando == false ? 'Preparando el PDF…' : 'Compartir de otra forma',
                      icon: AppIcons.compartir,
                      onTap: _enviando == null ? () => _enviar(d, porWhatsApp: false) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          TcToast(message: toastMessage, bottom: 176),
        ],
      ),
    );
  }
}

/// Vista previa: la foto real de la primera página (descifrada solo en
/// memoria) o, en los documentos de ejemplo sin foto, una cédula dibujada.
class _VistaPrevia extends StatefulWidget {
  const _VistaPrevia({required this.documento, required this.onSinFoto});

  final Documento documento;
  final VoidCallback onSinFoto;

  @override
  State<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends State<_VistaPrevia> {
  Future<List<Uint8List>>? _paginas;
  String? _archivoCargado;

  /// Si el documento es un PDF subido: sus bytes (para dibujar las páginas).
  Uint8List? _pdf;
  bool _abriendoPdf = false;

  /// Fotos del documento, o la primera página del PDF subido dibujada.
  Future<List<Uint8List>> _leer() async {
    final repo = context.repo;
    final fotos = await repo.leerPaginas(widget.documento);
    if (fotos.isNotEmpty) return fotos;
    final pdf = await repo.leerPdf(widget.documento);
    if (pdf == null) return const [];
    _pdf = pdf;
    return LectorPdf.dibujar(pdf, ancho: 1000, hasta: 1);
  }

  /// "Ver completo" de un PDF: se dibujan todas sus páginas (hasta 60).
  Future<void> _verPdfCompleto(Uint8List pdf) async {
    if (_abriendoPdf) return;
    setState(() => _abriendoPdf = true);
    final navigator = Navigator.of(context);
    try {
      final paginas = await LectorPdf.dibujar(pdf, ancho: 1400, hasta: 60);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => VisorPaginas(titulo: widget.documento.nombre, paginas: paginas),
        ),
      );
    } on ErrorPdf catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _abriendoPdf = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cargar();
  }

  @override
  void didUpdateWidget(_VistaPrevia old) {
    super.didUpdateWidget(old);
    _cargar();
  }

  /// Descifra las fotos solo la primera vez (no en cada cambio de nombre).
  void _cargar() {
    final archivo = widget.documento.archivo;
    if (archivo == _archivoCargado) return;
    _archivoCargado = archivo;
    _pdf = null;
    _paginas = archivo == null ? null : _leer();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _paginas,
      builder: (context, snap) {
        final paginas = snap.data ?? const <Uint8List>[];
        final Widget contenido;
        if (_paginas == null) {
          contenido = const _HojaDibujada();
        } else if (snap.hasError) {
          final error = snap.error;
          contenido = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is ErrorPdf ? error.mensaje : 'No se pudo abrir el documento.',
                textAlign: TextAlign.center,
                style: AppText.secondary(15, height: 1.4),
              ),
            ),
          );
        } else if (!snap.hasData) {
          contenido = const Center(child: CircularProgressIndicator(color: AppColors.primario));
        } else if (paginas.isEmpty) {
          contenido = const _HojaDibujada();
        } else {
          contenido = Padding(
            padding: const EdgeInsets.all(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(paginas.first, fit: BoxFit.contain, cacheWidth: 900),
            ),
          );
        }
        final pdf = _pdf;
        return _marco(
          contenido,
          onVer: pdf != null
              ? () => _verPdfCompleto(pdf)
              : paginas.isEmpty
              ? widget.onSinFoto
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VisorPaginas(titulo: widget.documento.nombre, paginas: paginas),
                  ),
                ),
        );
      },
    );
  }

  Widget _marco(Widget contenido, {required VoidCallback onVer}) {
    final abriendo = _abriendoPdf;
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: AppColors.primarioSuave,
        borderRadius: BorderRadius.circular(AppDecor.radioTarjeta),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: contenido),
          Positioned(
            right: 12,
            bottom: 12,
            child: TcTap(
              onTap: onVer,
              color: AppColors.superficie,
              radius: 20,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  if (abriendo)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primario),
                    )
                  else
                    const TcIcon(AppIcons.ojo, size: 18, color: AppColors.texto),
                  Text(abriendo ? 'Abriendo…' : 'Ver completo', style: AppText.bold(14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja con la cédula dibujada (documentos de ejemplo, sin foto real).
class _HojaDibujada extends StatelessWidget {
  const _HojaDibujada();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 190,
        height: 246,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: [BoxShadow(color: Color(0x293C2814), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: const Column(
          spacing: 14,
          children: [
            CedulaFrente(width: 150, height: 94, escala: 0.6),
            CedulaReverso(width: 150, height: 94, escala: 0.6),
          ],
        ),
      ),
    );
  }
}

class _Datos extends StatelessWidget {
  const _Datos({required this.filas});

  final List<(String, String)> filas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: AppDecor.tarjeta(),
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 46),
              decoration: BoxDecoration(
                border: i < filas.length - 1
                    ? const Border(bottom: BorderSide(color: AppColors.divisor))
                    : null,
              ),
              child: Row(
                children: [
                  Text(filas[i].$1, style: AppText.secondary(15)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(filas[i].$2, textAlign: TextAlign.end, style: AppText.bold(16)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cuando el documento ya no existe (se eliminó o el cajón está vacío).
class _SinDocumento extends StatelessWidget {
  const _SinDocumento();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(title: 'Documento no encontrado', backLabel: 'Volver a mi cajón'),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Este documento ya no está en tu cajón.',
                style: AppText.secondary(16, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.color = AppColors.texto,
  });

  final String icono;
  final String etiqueta;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: AppColors.superficie,
      radius: 20,
      shadow: AppDecor.sombra,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 4,
        children: [
          TcIcon(icono, size: 20, color: color),
          Text(etiqueta, style: AppText.bold(14, color: color)),
        ],
      ),
    );
  }
}
