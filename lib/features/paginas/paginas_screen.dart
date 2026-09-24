import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/archivos/selector_archivos.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/documento.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../escanear/pagina_editable.dart';
import '../escanear/procesar_foto.dart';
import '../escanear/revisar_foto.dart';
import '../guardar/guardar_screen.dart';

/// Con qué fotos se abre "Tus páginas".
class EntradaPaginas {
  const EntradaPaginas({
    this.listas = const [],
    this.nuevas = const [],
    this.aviso,
    this.devolver = false,
    this.edita,
    this.eraPdf = false,
  });

  /// Páginas ya preparadas (vuelven de Guardar con "Otra página", o son las
  /// de un documento guardado que se va a editar).
  final List<Uint8List> listas;

  /// Fotos recién elegidas en la galería (o compartidas desde otra app): se
  /// enderezan y se achican.
  final List<Uint8List> nuevas;

  /// Algo que decir al abrir (p. ej. que una foto compartida no llegó).
  final String? aviso;

  /// "Reemplazar": "Continuar" devuelve las fotos a quien abrió esta
  /// pantalla, en vez de ir a Guardar.
  final bool devolver;

  /// "Editar páginas": el documento guardado al que pertenecen [listas].
  /// "Guardar cambios" lo actualiza ahí mismo, sin volver a preguntar nada.
  final Documento? edita;

  /// El documento editado era un PDF subido (sus páginas llegan dibujadas).
  final bool eraPdf;
}

/// Tus páginas: las fotos elegidas en la galería, antes de guardarlas.
///
/// Se usan las mismas herramientas que con la cámara: tocar una página abre
/// la revisión (filtro, recortar, eliminar); arriba se puede mejorar todas
/// de una vez; manteniendo presionada una página se cambia el orden; y se
/// pueden agregar más páginas con la cámara o la galería. "Continuar" lleva
/// a Guardar, donde quedan como un documento PDF.
///
/// También es "Editar páginas" de un documento ya guardado ([EntradaPaginas.edita]):
/// ahí "Guardar cambios" lo actualiza en el mismo lugar, y salir con cambios
/// sin guardar pide confirmación.
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

  /// Al editar un documento: si ya se cambió algo, y si se está guardando.
  bool _cambios = false;
  bool _guardando = false;

  Documento? get _edita => widget.entrada.edita;

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
    if (widget.entrada.aviso case final aviso?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _avisar(aviso);
      });
    }
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
        setState(() {
          _paginas.add(PaginaEditable(base: lista.base, filtro: filtro, foto: lista.foto));
          _cambios = true;
        });
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

  Future<void> _agregarDeGaleria() async {
    final fotos = await context.elegirArchivos((s) => s.elegirFotos());
    if (mounted && fotos.isNotEmpty) await _preparar(fotos);
  }

  /// La cámara devuelve las páginas ya recortadas y mejoradas: van al final.
  Future<void> _agregarDeCamara() async {
    final fotos = await Navigator.of(context).pushNamed(AppRoutes.escanear, arguments: true);
    if (!mounted || fotos is! List<Uint8List> || fotos.isEmpty) return;
    setState(() {
      _paginas.addAll([for (final f in fotos) PaginaEditable.sinFiltro(f)]);
      _cambios = true;
    });
  }

  Future<void> _filtrarTodas(FiltroFoto filtro) async {
    setState(() {
      _filtroNuevas = filtro;
      _filtrando = true;
      _cambios = true;
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
        setState(() {
          _paginas[k] = PaginaEditable(base: base, filtro: filtro, foto: foto);
          if (!identical(foto, pagina.foto)) _cambios = true;
        });
        if (aTodas) await _filtrarTodas(filtro);
      case FotoEliminada():
        setState(() {
          _paginas.removeAt(k);
          _cambios = true;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Página ${k + 1} eliminada'),
            behavior: SnackBarBehavior.floating,
            margin: _margenAviso,
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
    if (desde == hasta) return;
    setState(() {
      _paginas.insert(hasta, _paginas.removeAt(desde));
      _cambios = true;
    });
  }

  /// "Editar páginas": guarda las páginas en el mismo documento (mismo
  /// perfil, tipo, nombre y fecha) y vuelve a él.
  Future<void> _guardarCambios(Documento d) async {
    setState(() => _guardando = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final cerrojo = context.cerrojo;
    final fotos = [for (final p in _paginas) p.foto];
    try {
      await context.repo.actualizarDocumento(
        d.id,
        NuevoDocumento(
          perfilId: d.perfilId,
          nombre: d.nombre,
          categoria: d.categoria,
          venceEn: d.venceEn,
          paginas: fotos.length,
        ),
        paginas: fotos,
      );
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar los cambios. Inténtalo de nuevo.')),
      );
      rethrow;
    }
    // Si la persona salió mientras se guardaba, se vuelve cuando abra con su llave.
    await cerrojo.esperarAbierto();
    _cambios = false;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Listo: «${d.nombre}» quedó con ${fotos.length == 1 ? '1 página' : '${fotos.length} páginas'}.',
        ),
        behavior: SnackBarBehavior.floating,
        margin: margenAvisoEnDocumento,
      ),
    );
    navigator.pop();
  }

  /// Salir de "Editar páginas" con cambios sin guardar: primero se pregunta.
  Future<void> _alSalir(bool salio, Object? _) async {
    if (salio) return;
    final navigator = Navigator.of(context);
    if (await confirmarSalirSinGuardar(context)) navigator.pop();
  }

  /// Los avisos van encima de la barra de abajo, para no tapar sus botones.
  static const _margenAviso = EdgeInsets.fromLTRB(16, 0, 16, 112);

  void _avisar(String mensaje) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating, margin: _margenAviso),
    );

  void _continuar() {
    // Un aviso de esta pantalla no debe quedar tapando el botón de Guardar.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (widget.entrada.devolver) {
      Navigator.of(context).pop(<Uint8List>[for (final p in _paginas) p.foto]);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.guardar, arguments: FotosDeGaleria([for (final p in _paginas) p.foto]));
  }

  @override
  Widget build(BuildContext context) {
    final edita = _edita;
    return PopScope(
      // Editando con cambios sin guardar, "atrás" primero pregunta.
      canPop: edita == null || !_cambios || _guardando,
      onPopInvokedWithResult: _alSalir,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: SafeArea(bottom: false, child: _contenido(edita)),
      ),
    );
  }

  Widget _contenido(Documento? edita) {
    final n = _paginas.length;
    final filtroDeTodas = _filtroDeTodas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BackHeader(title: edita == null ? 'Tus páginas' : 'Editar páginas', backLabel: 'Volver sin guardar'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Toca una página para recortarla, mejorarla o quitarla. Mantenla presionada para cambiar el orden.',
            style: AppText.secondary(15, height: 1.4),
          ),
        ),
        if (widget.entrada.eraPdf)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const TcIcon(AppIcons.subirArchivo, size: 18, color: AppColors.ambar),
                Expanded(
                  child: Text(
                    'Era un PDF: si guardas cambios, sus páginas quedan como imágenes (se ven igual).',
                    style: AppText.body(14, color: AppColors.ambar, height: 1.4),
                  ),
                ),
              ],
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
                // Agregar páginas: con la cámara o de la galería.
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _Agregar(
                        icono: AppIcons.camara,
                        texto: 'Tomar foto',
                        semantica: 'Agregar una página con la cámara',
                        onTap: _ocupado || _guardando ? null : _agregarDeCamara,
                      ),
                    ),
                    Expanded(
                      child: _Agregar(
                        icono: AppIcons.galeria,
                        texto: 'De la galería',
                        semantica: 'Agregar páginas de la galería',
                        onTap: _ocupado || _guardando ? null : _agregarDeGaleria,
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
            if (edita != null)
              PrimaryButton(
                label: 'Guardar cambios',
                icon: AppIcons.check,
                disabledLabel: _guardando
                    ? 'Guardando…'
                    : _ocupado
                    ? 'Preparando las fotos…'
                    : n == 0
                    ? 'Deja al menos una página'
                    : 'Todavía no hay cambios',
                onTap: _guardando || _ocupado || n == 0 || !_cambios ? null : () => _guardarCambios(edita),
              )
            else
              PrimaryButton(
                label: n == 1 ? 'Continuar con 1 página' : 'Continuar con $n páginas',
                icon: AppIcons.siguiente,
                disabledLabel: _ocupado ? 'Preparando las fotos…' : 'Agrega al menos una foto',
                onTap: _ocupado || n == 0 ? null : _continuar,
              ),
          ],
        ),
      ],
    );
  }
}

/// Botón punteado para agregar páginas (cámara o galería).
class _Agregar extends StatelessWidget {
  const _Agregar({required this.icono, required this.texto, required this.semantica, required this.onTap});

  final String icono;
  final String texto;
  final String semantica;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantica,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: DashedBorder(
          height: 64,
          radius: 20,
          color: AppColors.bordePunteado,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              TcIcon(icono, size: 22, color: AppColors.textoSecundario),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(texto, style: AppText.bold(15, color: AppColors.textoSecundario)),
                ),
              ),
            ],
          ),
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
