import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/archivos/selector_archivos.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../escanear/pagina_editable.dart';
import '../escanear/procesar_foto.dart';
import '../escanear/revisar_foto.dart';
import '../guardar/guardar_screen.dart';

/// Con qué fotos se abre "Tus páginas".
class EntradaPaginas {
  const EntradaPaginas({this.listas = const [], this.nuevas = const []});

  /// Páginas ya preparadas (vuelven de Guardar con "Otra página").
  final List<Uint8List> listas;

  /// Fotos recién elegidas en la galería: se enderezan y se achican.
  final List<Uint8List> nuevas;
}

/// Tus páginas: las fotos elegidas en la galería, antes de guardarlas.
///
/// Se usan las mismas herramientas que con la cámara: tocar una página abre
/// la revisión (filtro, recortar, eliminar); arriba se puede mejorar todas
/// de una vez; manteniendo presionada una página se cambia el orden; y se
/// pueden agregar más fotos. "Continuar" lleva a Guardar, donde quedan
/// como un documento PDF.
class PaginasScreen extends StatefulWidget {
  const PaginasScreen({super.key, this.entrada = const EntradaPaginas()});

  final EntradaPaginas entrada;

  @override
  State<PaginasScreen> createState() => _PaginasScreenState();
}

class _PaginasScreenState extends State<PaginasScreen> {
  late final List<PaginaEditable> _paginas = [
    for (final f in widget.entrada.listas) PaginaEditable.sinFiltro(f),
  ];

  /// Fotos que todavía se están preparando.
  int _preparando = 0;

  /// Aplicando un filtro a todas.
  bool _filtrando = false;

  /// El filtro de las fotos nuevas (el último que se eligió para todas).
  FiltroFoto _filtroNuevas = FiltroFoto.original;

  bool get _ocupado => _preparando > 0 || _filtrando;

  /// El filtro que tienen todas, o `null` si están mezclados.
  FiltroFoto? get _filtroDeTodas {
    if (_paginas.isEmpty) return _filtroNuevas;
    final primero = _paginas.first.filtro;
    return _paginas.every((p) => p.filtro == primero) ? primero : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.entrada.nuevas.isNotEmpty) _preparar(widget.entrada.nuevas);
  }

  /// Endereza y achica cada foto (en otro hilo) y la agrega al final.
  Future<void> _preparar(List<Uint8List> fotos) async {
    setState(() => _preparando += fotos.length);
    var fallidas = 0;
    for (final foto in fotos) {
      try {
        final filtro = _filtroNuevas;
        final lista = await prepararPagina(foto, filtro: filtro);
        if (!mounted) return;
        setState(() => _paginas.add(PaginaEditable(base: lista.base, filtro: filtro, foto: lista.foto)));
      } catch (e) {
        debugPrint('No se pudo abrir una foto de la galería: $e');
        fallidas++;
      } finally {
        if (mounted) setState(() => _preparando--);
      }
    }
    if (mounted && fallidas > 0) {
      _avisar(fallidas == 1 ? 'Una foto no se pudo abrir.' : '$fallidas fotos no se pudieron abrir.');
    }
  }

  Future<void> _agregarMas() async {
    final fotos = await context.elegirArchivos((s) => s.elegirFotos());
    if (mounted && fotos.isNotEmpty) await _preparar(fotos);
  }

  Future<void> _filtrarTodas(FiltroFoto filtro) async {
    setState(() {
      _filtroNuevas = filtro;
      _filtrando = true;
    });
    await filtrarTodas(_paginas, filtro, (vieja, nueva) {
      final i = _paginas.indexOf(vieja);
      if (mounted && i >= 0) setState(() => _paginas[i] = nueva);
    });
    if (mounted) setState(() => _filtrando = false);
  }

  Future<void> _revisar(int i) async {
    if (_ocupado || i >= _paginas.length) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final pagina = _paginas[i];
    final r = await abrirRevision(context, pagina, numero: i + 1, total: _paginas.length);
    if (!mounted || r == null) return;
    final k = _paginas.indexOf(pagina);
    if (k < 0) return;
    switch (r) {
      case FotoConservada(:final base, :final filtro, :final foto, :final aTodas):
        setState(() => _paginas[k] = PaginaEditable(base: base, filtro: filtro, foto: foto));
        if (aTodas) await _filtrarTodas(filtro);
      case FotoEliminada():
        setState(() => _paginas.removeAt(k));
        messenger.showSnackBar(
          SnackBar(
            content: Text('Página ${k + 1} eliminada'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                if (mounted) setState(() => _paginas.insert(math.min(k, _paginas.length), pagina));
              },
            ),
          ),
        );
    }
  }

  /// [hasta] ya viene corregido (cuenta la lista sin la página que se mueve).
  void _mover(int desde, int hasta) {
    setState(() => _paginas.insert(hasta, _paginas.removeAt(desde)));
  }

  void _avisar(String mensaje) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating));

  void _continuar() => Navigator.of(context)
      .pushReplacementNamed(AppRoutes.guardar, arguments: FotosDeGaleria([for (final p in _paginas) p.foto]));

  @override
  Widget build(BuildContext context) {
    final n = _paginas.length;
    final filtroDeTodas = _filtroDeTodas;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackHeader(title: 'Tus páginas', backLabel: 'Volver sin guardar'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Toca una página para recortarla, mejorarla o quitarla. Mantenla presionada para cambiar el orden.',
                style: AppText.secondary(15, height: 1.4),
              ),
            ),
            // Mejorar todas de una vez.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Mejorar todas:', style: AppText.bold(15)),
                  for (final f in FiltroFoto.values)
                    PillChip(
                      label: f.etiqueta,
                      selected: f == filtroDeTodas,
                      onTap: () => _ocupado || f == filtroDeTodas ? null : _filtrarTodas(f),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: n,
                onReorderItem: _mover,
                itemBuilder: (context, i) => Padding(
                  key: ObjectKey(_paginas[i]),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaPagina(numero: i + 1, pagina: _paginas[i], indice: i, onTap: () => _revisar(i)),
                ),
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_preparando > 0 || _filtrando)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 10,
                          children: [
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primario),
                            ),
                            Flexible(
                              child: Text(
                                _filtrando
                                    ? 'Mejorando las páginas…'
                                    : _preparando == 1
                                    ? 'Preparando 1 foto…'
                                    : 'Preparando $_preparando fotos…',
                                style: AppText.secondary(15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Semantics(
                      button: true,
                      label: 'Agregar más fotos de la galería',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: _ocupado ? null : _agregarMas,
                        child: DashedBorder(
                          height: 64,
                          radius: 20,
                          color: AppColors.bordePunteado,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 8,
                            children: [
                              const TcIcon(AppIcons.mas, size: 22, color: AppColors.textoSecundario),
                              Text(
                                'Agregar más fotos',
                                style: AppText.bold(15, color: AppColors.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                PrimaryButton(
                  label: n == 1 ? 'Continuar con 1 página' : 'Continuar con $n páginas',
                  icon: AppIcons.siguiente,
                  disabledLabel: _ocupado ? 'Preparando las fotos…' : 'Agrega al menos una foto',
                  onTap: _ocupado || n == 0 ? null : _continuar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Una página en la lista: miniatura, número, filtro y la agarradera para
/// cambiarla de lugar.
class _FilaPagina extends StatelessWidget {
  const _FilaPagina({required this.numero, required this.pagina, required this.indice, required this.onTap});

  final int numero;
  final PaginaEditable pagina;
  final int indice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      color: AppColors.superficie,
      radius: 20,
      shadow: AppDecor.sombra,
      padding: const EdgeInsets.all(10),
      semanticLabel: 'Página $numero. Toca para revisarla',
      child: Row(
        children: [
          Container(
            width: 64,
            height: 84,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.idFondo, borderRadius: BorderRadius.circular(10)),
            child: Image.memory(pagina.foto, fit: BoxFit.cover, cacheWidth: 200, gaplessPlayback: true),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('Página $numero', style: AppText.bold(16)),
                Text(
                  pagina.filtro == FiltroFoto.original ? 'Sin filtro' : 'Filtro ${pagina.filtro.etiqueta}',
                  style: AppText.secondary(14),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: indice,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: TcIcon(AppIcons.arrastrar, size: 22, color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}
