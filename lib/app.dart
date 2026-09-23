import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_routes.dart';
import 'core/seguridad/cerrojo.dart';
import 'core/seguridad/llave_celular.dart';
import 'core/theme/app_theme.dart';
import 'data/repositorio/cajon_repositorio.dart';
import 'data/repositorio/repositorio_scope.dart';
import 'features/desbloqueo/desbloqueo_screen.dart';

class TuCajonApp extends StatefulWidget {
  TuCajonApp({
    super.key,
    required this.repo,
    LlaveCelular? llave,
    this.rutaInicial = AppRoutes.carga,
    this.argumentos,
  }) : llave = llave ?? LlaveCelular.paraEstaPlataforma();

  final CajonRepositorio repo;

  /// La huella, rostro o PIN del celular (simulada en pruebas y navegador).
  final LlaveCelular llave;

  /// Para pruebas: abrir directamente otra pantalla.
  final String rutaInicial;
  final Object? argumentos;

  @override
  State<TuCajonApp> createState() => _TuCajonAppState();
}

class _TuCajonAppState extends State<TuCajonApp> {
  final _navegador = GlobalKey<NavigatorState>();

  /// Cierra el cajón cada vez que la app sale de la pantalla.
  late final Cerrojo _cerrojo = Cerrojo(
    navegador: _navegador,
    pantallaCerrada: (alAbrir) => DesbloqueoScreen(alAbrir: alAbrir),
  );

  @override
  void dispose() {
    _cerrojo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositorioScope(
      repo: widget.repo,
      child: LlaveScope(
        llave: widget.llave,
        child: CerrojoScope(
          cerrojo: _cerrojo,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: MaterialApp(
              navigatorKey: _navegador,
              title: 'Tu Cajón',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              locale: const Locale('es', 'CO'),
              supportedLocales: const [Locale('es', 'CO'), Locale('es')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              onGenerateInitialRoutes: (_) => [
                AppRoutes.onGenerateRoute(
                  RouteSettings(name: widget.rutaInicial, arguments: widget.argumentos),
                ),
              ],
              onGenerateRoute: AppRoutes.onGenerateRoute,
            ),
          ),
        ),
      ),
    );
  }
}
