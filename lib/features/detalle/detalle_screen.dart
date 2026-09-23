import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../core/formato.dart';
import '../../core/router/app_routes.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../data/models/documento.dart';
import '../../shared/illustrations/cedula_dibujo.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';
import 'visor_paginas.dart';

/// 6 · Documento: vista previa, datos, acciones y "Enviar por WhatsApp".
/// "Compartir de otra forma" abre el menú de compartir del celular (simulado).
class DetalleScreen extends StatefulWidget {
  const DetalleScreen({super.key, this.documentoId});

  /// Si no llega ninguno se muestra el documento más reciente (catálogo).
  final String? documentoId;

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> with ToastMixin {
  bool _hoja = false;

  /// Se vigila el documento: si se renombra, el título cambia al instante.
  late final Stream<Documento?> _doc = widget.documentoId != null
      ? context.repo.vigilarDocumento(widget.documentoId!)
      : context.repo.vigilarTodos().map((docs) => docs.firstOrNull);

  Future<void> _renombrar(Documento d) async {
    final nuevo = await pedirNombre(context, actual: d.nombre);
    if (!mounted || nuevo == null || nuevo.trim().isEmpty || nuevo.trim() == d.nombre) return;
    await context.repo.renombrarDocumento(d.id, nuevo);
    showToast('Listo. Ahora se llama “${nuevo.trim()}”.');
  }

  Future<void> _eliminar(Documento d) async {
    final navigator = Navigator.of(context);
    final repo = context.repo;
    final ok = await confirmarEliminar(context, d.nombre);
    if (!ok) return;
    await repo.eliminarDocumento(d.id);
    navigator.pop();
  }

  void _toastYCerrar(String msg) {
    setState(() => _hoja = false);
    showToast(msg);
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
    final destinos = <(String, String, String)>[
      ('Correo', AppIcons.correo, 'Abriendo tu correo con el documento adjunto…'),
      ('Mensajes', AppIcons.mensajes, 'Abriendo Mensajes…'),
      ('Bluetooth', AppIcons.bluetooth, 'Buscando equipos cerca…'),
      ('Archivos', AppIcons.carpeta, 'Guardando una copia en Archivos…'),
      ('Imprimir', AppIcons.imprimir, 'Preparando para imprimir…'),
      ('Copiar', AppIcons.copiar, 'Documento copiado'),
      ('Cerca', AppIcons.cerca, 'Buscando celulares cerca…'),
      ('Más apps', AppIcons.masApps, 'Mostrando más apps…'),
    ];

    return PopScope(
      canPop: !_hoja,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _hoja = false);
      },
      child: Scaffold(
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
                          _Datos(
                            filas: [
                              ('Carpeta', d.categoria.etiqueta),
                              ('Guardado', d.guardadoTexto),
                              ('Archivo', d.detalleCompleto),
                              ('Vencimiento', d.vencimientoTexto),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            spacing: 8,
                            children: [
                              Expanded(
                                child: _Accion(
                                  icono: AppIcons.lapiz,
                                  etiqueta: 'Renombrar',
                                  onTap: () => _renombrar(d),
                                ),
                              ),
                              Expanded(
                                child: _Accion(
                                  icono: AppIcons.reemplazar,
                                  etiqueta: 'Reemplazar',
                                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.agregar),
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
                        onTap: () =>
                            showToast('Abriendo WhatsApp con “${d.nombre}”. Solo elige el contacto.'),
                      ),
                      OutlineButtonTc(
                        label: 'Compartir de otra forma',
                        icon: AppIcons.compartir,
                        onTap: () => setState(() => _hoja = true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TcToast(message: toastMessage, bottom: 176),
            TcSheet(
              open: _hoja,
              onDismiss: () => setState(() => _hoja = false),
              dismissLabel: 'Cerrar menú de compartir',
              child: Semantics(
                scopesRoute: _hoja,
                namesRoute: true,
                label: 'Compartir con',
                explicitChildNodes: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.superficieSuave,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text('PDF', style: AppText.bold(11, color: AppColors.rojo)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(d.nombreArchivo, style: AppText.bold(16)),
                              Text(
                                '${Formato.tamano(d.tamanoBytes)} · Menú para compartir del celular',
                                style: AppText.secondary(14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 4,
                        // Ícono + hasta dos líneas de texto, según el tamaño de letra.
                        mainAxisExtent: 70 + MediaQuery.textScalerOf(context).scale(13) * 1.2 * 2,
                      ),
                      children: [
                        for (final t in destinos)
                          _Destino(etiqueta: t.$1, icono: t.$2, onTap: () => _toastYCerrar(t.$3)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    TcTap(
                      onTap: () => setState(() => _hoja = false),
                      color: AppColors.superficieSuave,
                      radius: 16,
                      height: 52,
                      child: Center(child: Text('Cancelar', style: AppText.bold(17))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    _paginas = archivo == null ? null : context.repo.leerPaginas(widget.documento);
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
          contenido = Center(child: Text('No se pudo abrir la foto.', style: AppText.secondary(15)));
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
        return _marco(
          contenido,
          onVer: paginas.isEmpty
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
                  const TcIcon(AppIcons.ojo, size: 18, color: AppColors.texto),
                  Text('Ver completo', style: AppText.bold(14)),
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

class _Destino extends StatelessWidget {
  const _Destino({required this.etiqueta, required this.icono, required this.onTap});

  final String etiqueta;
  final String icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          spacing: 6,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.superficieSuave, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: TcIcon(icono, size: 24, color: AppColors.primario),
            ),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(13, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
