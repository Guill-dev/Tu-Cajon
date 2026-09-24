import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../data/models/documento.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../avisos/avisos_screen.dart';
import '../avisos/sugerencias.dart';
import '../inicio/inicio_screen.dart';
import 'widgets/barra_inferior.dart';

enum CajonTab { inicio, avisos }

/// Contenedor de las dos pestañas con barra inferior: "Mi cajón" y "Avisos".
///
/// Usa un `IndexedStack` para que cada pestaña conserve su estado (filtros,
/// búsqueda, sugerencias descartadas) al cambiar de una a otra.
/// El botón central "Agregar" abre la pantalla de agregar documento.
///
/// Mientras el teclado está abierto (al buscar) la barra se esconde: si no,
/// subiría pegada al teclado y taparía los resultados.
class CajonShell extends StatefulWidget {
  const CajonShell({super.key, this.pestanaInicial = CajonTab.inicio});

  final CajonTab pestanaInicial;

  @override
  State<CajonShell> createState() => _CajonShellState();
}

class _CajonShellState extends State<CajonShell> with WidgetsBindingObserver {
  late CajonTab _tab = widget.pestanaInicial;
  late final Stream<List<Documento>> _todos = context.repo.vigilarTodos();
  late final Stream<Set<String>> _descartadas = context.repo.vigilarSugerenciasDescartadas();

  /// Si el teclado está abierto. Se lee del celular y no de `MediaQuery`
  /// para que solo se redibuje la barra, no las pestañas enteras.
  final _teclado = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    didChangeMetrics();
  }

  @override
  void didChangeMetrics() {
    _teclado.value = View.of(context).viewInsets.bottom > 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teclado.dispose();
    super.dispose();
  }

  void _ir(CajonTab tab) {
    // Al cambiar de pestaña no queda el buscador activo por detrás.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // En "Avisos", el botón atrás del sistema vuelve a "Mi cajón".
      canPop: _tab == CajonTab.inicio,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ir(CajonTab.inicio);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  InicioScreen(activa: _tab == CajonTab.inicio, onVerAvisos: () => _ir(CajonTab.avisos)),
                  const AvisosScreen(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder(
                valueListenable: _teclado,
                // Se esconde de una vez y vuelve a aparecer suave.
                builder: (context, teclado, barra) => AnimatedOpacity(
                  opacity: teclado ? 0 : 1,
                  duration: teclado ? Duration.zero : const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: teclado,
                    child: ExcludeSemantics(excluding: teclado, child: barra),
                  ),
                ),
                // El número rojo de "Avisos" = sugerencias pendientes.
                child: StreamBuilder(
                  stream: _todos,
                  builder: (context, todos) => StreamBuilder(
                    stream: _descartadas,
                    builder: (context, descartadas) => BarraInferior(
                      actual: _tab,
                      avisosPendientes: calcularSugerencias(
                        todos.data ?? const [],
                        descartadas.data ?? const {},
                        DateTime.now(),
                      ).length,
                      onInicio: () => _ir(CajonTab.inicio),
                      onAvisos: () => _ir(CajonTab.avisos),
                      onAgregar: () => Navigator.of(context).pushNamed(AppRoutes.agregar),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
