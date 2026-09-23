import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/repositorio/cajon_repositorio.dart';
import 'data/repositorio/repositorio_scope.dart';

class TuCajonApp extends StatelessWidget {
  const TuCajonApp({super.key, required this.repo, this.rutaInicial = AppRoutes.carga, this.argumentos});

  final CajonRepositorio repo;

  /// Para pruebas: abrir directamente otra pantalla.
  final String rutaInicial;
  final Object? argumentos;

  @override
  Widget build(BuildContext context) {
    return RepositorioScope(
      repo: repo,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: MaterialApp(
          title: 'Tu Cajón',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('es', 'CO'),
          supportedLocales: const [Locale('es', 'CO'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          onGenerateInitialRoutes: (_) => [
            AppRoutes.onGenerateRoute(RouteSettings(name: rutaInicial, arguments: argumentos)),
          ],
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
