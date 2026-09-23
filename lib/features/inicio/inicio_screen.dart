import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/categoria.dart';
import '../../data/models/documento.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';
import '../avisos/sugerencias.dart';
import 'widgets/avatar_perfil.dart';
import 'widgets/tarjeta_documento.dart';

/// 5 · Mi cajón: saludo en dos tonos, buscador, tarjetas de perfil, sugerencia
/// de la IA, filtros por carpeta y la lista de documentos.
///
/// Todo sale de la base de datos con `Stream`s: si guardas, renombras o
/// borras un documento en otra pantalla, esta se actualiza sola.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.onVerAvisos});

  /// Cambia a la pestaña Avisos (lo usa la tarjeta de sugerencia).
  final VoidCallback onVerAvisos;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with ToastMixin {
  final _busqueda = TextEditingController();
  String _perfilId = Perfil.idPropio;
  Categoria? _categoria; // null = "Todos"

  late final Stream<String> _nombre = context.repo.vigilarNombre();
  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();
  late final Stream<Set<String>> _descartadas = context.repo.vigilarSugerenciasDescartadas();

  /// Todos los documentos del perfil (para las carpetas y la sugerencia).
  late Stream<List<Documento>> _todos;

  /// Los que coinciden con la búsqueda (igual a [_todos] si no hay búsqueda).
  Stream<List<Documento>>? _encontrados;
  String _ultimaBusqueda = '';

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(_alBuscar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _abrirStreams();
  }

  void _abrirStreams() {
    _todos = context.repo.vigilarDocumentos(_perfilId);
    final q = _busqueda.text.trim();
    _encontrados = q.isEmpty ? null : context.repo.vigilarDocumentos(_perfilId, busqueda: q);
    _ultimaBusqueda = q;
  }

  void _alBuscar() {
    if (_busqueda.text.trim() == _ultimaBusqueda) {
      setState(() {}); // solo cambió el botón de borrar
      return;
    }
    setState(_abrirStreams);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _elegirPerfil(Perfil p) {
    setState(() {
      _perfilId = p.id;
      _categoria = null;
      _busqueda.removeListener(_alBuscar);
      _busqueda.clear();
      _busqueda.addListener(_alBuscar);
      _abrirStreams();
    });
  }

  void _verTodos() {
    setState(() => _categoria = null);
    _busqueda.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Nombre → perfiles → documentos → búsqueda → sugerencias descartadas.
    return StreamBuilder(
      stream: _nombre,
      builder: (context, nombre) => StreamBuilder(
        stream: _perfiles,
        builder: (context, perfiles) => StreamBuilder(
          stream: _todos,
          builder: (context, todos) => StreamBuilder(
            stream: _encontrados,
            builder: (context, encontrados) => StreamBuilder(
              stream: _descartadas,
              builder: (context, descartadas) {
                if (!perfiles.hasData || !todos.hasData) {
                  return const ColoredBox(color: AppColors.fondo);
                }
                return _contenido(
                  nombre: nombre.data ?? '',
                  perfiles: perfiles.data!,
                  todos: todos.data!,
                  encontrados: _encontrados == null ? todos.data! : (encontrados.data ?? const []),
                  descartadas: descartadas.data ?? const {},
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido({
    required String nombre,
    required List<Perfil> perfiles,
    required List<Documento> todos,
    required List<Documento> encontrados,
    required Set<String> descartadas,
  }) {
    final perfil = perfiles.firstWhere((p) => p.id == _perfilId, orElse: () => perfiles.first);
    final docs = encontrados.where((d) => _categoria == null || d.categoria == _categoria).toList();
    final categoriasPresentes = Categoria.values.where((c) => todos.any((d) => d.categoria == c)).toList();
    final hoy = DateTime.now();

    final n = todos.length;
    final subtitulo = perfil.esPropio
        ? (n == 1 ? '1 documento en tu cajón' : '$n documentos en tu cajón')
        : (n == 1 ? '1 documento guardado aquí' : '$n documentos guardados aquí');
    // La primera sugerencia de este perfil (sin contar "agregar papeles").
    final sugerencia = calcularSugerencias(
      todos,
      descartadas,
      hoy,
    ).where((s) => s.documento != null).firstOrNull;

    final String? ligero;
    final String fuerte;
    if (!perfil.esPropio) {
      ligero = 'El cajón de';
      fuerte = perfil.nombre;
    } else if (nombre.isEmpty) {
      ligero = 'Tu';
      fuerte = 'cajón';
    } else {
      ligero = 'Hola,';
      fuerte = nombre;
    }

    return ColoredBox(
      color: AppColors.fondo,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: NoScrollbar(
              child: ListView(
                padding: EdgeInsets.only(bottom: 120 + MediaQuery.paddingOf(context).bottom),
                children: [
                  _Encabezado(ligero: ligero, fuerte: fuerte, subtitulo: subtitulo),
                  const SizedBox(height: 20),
                  _Buscador(controller: _busqueda),
                  const SizedBox(height: 26),
                  const _TituloSeccion('Perfiles'),
                  const SizedBox(height: 12),
                  _FilaPerfiles(perfiles: perfiles, actual: perfil.id, onElegir: _elegirPerfil),
                  if (sugerencia != null) ...[
                    // La fila de perfiles ya deja 24 px abajo para su sombra.
                    const SizedBox(height: 2),
                    _TarjetaSugerencia(texto: sugerencia.resumen, onVer: widget.onVerAvisos),
                  ],
                  const SizedBox(height: 26),
                  _TituloSeccion(
                    'Documentos',
                    trailing: Text(
                      docs.length == 1 ? '1 documento' : '${docs.length} documentos',
                      style: AppText.secondary(14),
                    ),
                  ),
                  if (todos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _FilaCategorias(
                      categorias: categoriasPresentes,
                      actual: _categoria,
                      onElegir: (c) => setState(() => _categoria = c),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        for (final d in docs)
                          TarjetaDocumento(
                            documento: d,
                            hoy: hoy,
                            onAbrir: () =>
                                Navigator.of(context).pushNamed(AppRoutes.detalle, arguments: d.id),
                            onWhatsApp: () => showToast('Abriendo WhatsApp con “${d.nombre}”…'),
                          ),
                        if (todos.isEmpty)
                          _Vacio(
                            titulo: 'Este cajón está vacío',
                            texto: perfil.esPropio
                                ? 'Agrega tu primer documento con el botón +.'
                                : 'Agrega el primer documento de ${perfil.nombre}.',
                            onVerTodos: null,
                          )
                        else if (docs.isEmpty)
                          _Vacio(
                            titulo: 'No encontramos ese documento',
                            texto: 'Revisa cómo lo escribiste o agrégalo a este cajón.',
                            onVerTodos: _verTodos,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TcToast(message: toastMessage, icon: AppIcons.whatsapp, bottom: 100),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.ligero, required this.fuerte, required this.subtitulo});

  final String? ligero;
  final String fuerte;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                TwoToneTitle('', ligero: ligero, fuerte: fuerte, size: 32, maxLinesFuerte: 1),
                Text(subtitulo, style: AppText.secondary(15)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            spacing: 10,
            children: [
              SquircleButton(
                icon: 'M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9l-5 4z',
                extra:
                    '<circle cx="9" cy="10" r="1" fill="currentColor"/>'
                    '<circle cx="12.5" cy="10" r="1" fill="currentColor"/>'
                    '<circle cx="16" cy="10" r="1" fill="currentColor"/>',
                semanticLabel: 'Pregúntale a tu cajón',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.preguntar),
              ),
            ],
          ),
          const SizedBox(width: 10),
          SquircleButton(
            icon: AppIcons.ajustes,
            semanticLabel: 'Ajustes',
            color: AppColors.superficie,
            iconColor: AppColors.texto,
            shadow: true,
            onTap: () {}, // Pendiente: pantalla de ajustes.
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, {this.trailing});

  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(texto, style: AppText.bold(18))),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _FilaPerfiles extends StatelessWidget {
  const _FilaPerfiles({required this.perfiles, required this.actual, required this.onElegir});

  final List<Perfil> perfiles;
  final String actual;
  final ValueChanged<Perfil> onElegir;

  @override
  Widget build(BuildContext context) {
    // Alto según el tamaño de letra del celular: círculo + dos líneas + márgenes.
    final escala = MediaQuery.textScalerOf(context);
    final alto = 104 + escala.scale(15) * 1.3 + escala.scale(12) * 1.3;
    return SizedBox(
      height: alto + 24, // espacio para la sombra
      child: NoScrollbar(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          clipBehavior: Clip.none,
          children: [
            for (final p in perfiles) ...[
              TarjetaPerfil(
                perfil: p,
                documentos: p.documentos,
                seleccionado: p.id == actual,
                onTap: () => onElegir(p),
              ),
              const SizedBox(width: 12),
            ],
            const BotonNuevoPerfil(),
          ],
        ),
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: AppDecor.tarjeta(radius: 20),
      child: Row(
        children: [
          const TcIcon(AppIcons.buscar, size: 22, color: AppColors.textoSecundario, strokeWidth: 2),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: AppText.body(16),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Buscar: cédula, RUT, recibo…',
                hintStyle: AppText.body(16, color: AppColors.placeholder),
                semanticCounterText: '',
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            TcTap(
              onTap: controller.clear,
              radius: 20,
              width: 40,
              height: 40,
              semanticLabel: 'Borrar búsqueda',
              child: const Center(child: TcIcon(AppIcons.cerrar, size: 18, color: AppColors.textoSecundario)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaSugerencia extends StatelessWidget {
  const _TarjetaSugerencia({required this.texto, required this.onVer});

  final String texto;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TcTap(
        onTap: onVer,
        color: AppColors.ambarSuave,
        radius: AppDecor.radioTarjeta,
        semanticLabel: 'Sugerencia de la IA. Ver en Avisos',
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.amarillo, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const TcIcon(AppIcons.destello, size: 24, color: AppColors.ambar),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'SUGERENCIA DE LA IA',
                    style: AppText.bold(11, color: AppColors.ambar).copyWith(letterSpacing: 0.8),
                  ),
                  Text(texto, style: AppText.body(14, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const TcIcon(AppIcons.siguiente, size: 20, color: AppColors.ambar, strokeWidth: 2.2),
          ],
        ),
      ),
    );
  }
}

class _FilaCategorias extends StatelessWidget {
  const _FilaCategorias({required this.categorias, required this.actual, required this.onElegir});

  final List<Categoria> categorias;
  final Categoria? actual;
  final ValueChanged<Categoria?> onElegir;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: NoScrollbar(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            PillChip(label: 'Todos', selected: actual == null, onTap: () => onElegir(null)),
            for (final c in categorias) ...[
              const SizedBox(width: 10),
              PillChip(label: c.etiqueta, selected: actual == c, onTap: () => onElegir(c)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.titulo, required this.texto, required this.onVerTodos});

  final String titulo;
  final String texto;
  final VoidCallback? onVerTodos;

  @override
  Widget build(BuildContext context) {
    return DashedBorder(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      color: AppColors.bordePunteado,
      fill: AppColors.superficie,
      radius: AppDecor.radioTarjeta,
      child: Column(
        spacing: 12,
        children: [
          Text(titulo, textAlign: TextAlign.center, style: AppText.bold(17)),
          Text(texto, textAlign: TextAlign.center, style: AppText.secondary(14, height: 1.4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              if (onVerTodos != null) SmallButton(label: 'Ver todos', filled: false, onTap: onVerTodos),
              SmallButton(label: 'Agregar', onTap: () => Navigator.of(context).pushNamed(AppRoutes.agregar)),
            ],
          ),
        ],
      ),
    );
  }
}
