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
class CajonShell extends StatefulWidget {
  const CajonShell({super.key, this.pestanaInicial = CajonTab.inicio});

  final CajonTab pestanaInicial;

  @override
  State<CajonShell> createState() => _CajonShellState();
}

class _CajonShellState extends State<CajonShell> {
  late CajonTab _tab = widget.pestanaInicial;
  late final Stream<List<Documento>> _todos = context.repo.vigilarTodos();
  late final Stream<Set<String>> _descartadas = context.repo.vigilarSugerenciasDescartadas();

  void _ir(CajonTab tab) => setState(() => _tab = tab);

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
                  InicioScreen(onVerAvisos: () => _ir(CajonTab.avisos)),
                  const AvisosScreen(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
          ],
        ),
      ),
    );
  }
}
