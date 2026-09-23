import 'package:flutter/widgets.dart';

import 'cajon_repositorio.dart';

/// Pone el repositorio al alcance de todas las pantallas: `context.repo`.
class RepositorioScope extends InheritedWidget {
  const RepositorioScope({super.key, required this.repo, required super.child});

  final CajonRepositorio repo;

  static CajonRepositorio of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositorioScope>();
    assert(scope != null, 'Falta RepositorioScope arriba en el árbol de widgets.');
    return scope!.repo;
  }

  @override
  bool updateShouldNotify(RepositorioScope oldWidget) => repo != oldWidget.repo;
}

extension RepositorioContexto on BuildContext {
  CajonRepositorio get repo => RepositorioScope.of(this);
}
