import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/archivos/buzon.dart';
import 'core/avisos/recordatorios.dart';
import 'core/archivos/recepcion.dart';
import 'core/archivos/selector_archivos.dart';
import 'core/compartir/compartidor.dart';
import 'core/router/app_routes.dart';
import 'core/seguridad/cerrojo.dart';
import 'core/seguridad/llave_celular.dart';
import 'core/theme/app_theme.dart';
import 'data/copia/copia_de_seguridad.dart';
import 'data/copia/programador_de_copias.dart';
import 'data/repositorio/cajon_repositorio.dart';
import 'data/repositorio/repositorio_scope.dart';
import 'features/avisos/avisos_programados.dart';
import 'features/desbloqueo/desbloqueo_screen.dart';

class TuCajonApp extends StatefulWidget {
  TuCajonApp({
    super.key,
    required this.repo,
    LlaveCelular? llave,
    Compartidor? compartidor,
    SelectorArchivos? selector,
    Buzon? buzon,
    Recordatorios? recordatorios,
    CopiaDeSeguridad? copia,
    this.reloj,
    this.rutaInicial = AppRoutes.carga,
    this.argumentos,
  }) : llave = llave ?? LlaveCelular.paraEstaPlataforma(),
       compartidor = compartidor ?? Compartidor.paraEstaPlataforma(),
       selector = selector ?? SelectorArchivos.paraEstaPlataforma(),
       buzon = buzon ?? Buzon.paraEstaPlataforma(),
       recordatorios = recordatorios ?? Recordatorios.paraEstaPlataforma(),
       copia = copia ?? CopiaDeSeguridad.simulada(repo);

  final CajonRepositorio repo;

  /// La huella, rostro o PIN del celular (simulada en pruebas y navegador).
  final LlaveCelular llave;

  /// Arma el PDF y lo pasa a WhatsApp o a otra app (simulado en pruebas).
  final Compartidor compartidor;

  /// Abre la galería y el explorador de archivos (simulado en pruebas).
  final SelectorArchivos selector;

  /// Lo que otras apps comparten con "Compartir → Tu Cajón" (simulado en pruebas).
  final Buzon buzon;

  /// Las notificaciones: avisos de vencimiento y recordatorios (simuladas en pruebas).
  final Recordatorios recordatorios;

  /// La copia de seguridad en la nube (simulada en pruebas).
  final CopiaDeSeguridad copia;

  /// Para pruebas: la hora que usa el cerrojo.
  final DateTime Function()? reloj;

  /// Para pruebas: abrir directamente otra pantalla.
  final String rutaInicial;
  final Object? argumentos;

  @override
  State<TuCajonApp> createState() => _TuCajonAppState();
}

class _TuCajonAppState extends State<TuCajonApp> {
  final _navegador = GlobalKey<NavigatorState>();

  /// Cierra el cajón cada vez que la app sale de la pantalla.
  /// Al cerrarse, borra los PDF que se compartieron.
  late final Cerrojo _cerrojo = Cerrojo(
    navegador: _navegador,
    pantallaCerrada: (alAbrir) => DesbloqueoScreen(alAbrir: alAbrir),
    alCerrar: widget.compartidor.limpiar,
    reloj: widget.reloj,
  );

  /// Lleva lo que llega por "Compartir", o el documento de un aviso que se
  /// tocó, a su pantalla, con el cajón abierto.
  late final Recepcion _recepcion;

  /// Mantiene los avisos de vencimiento al día con los documentos.
  late final ProgramadorDeAvisos _avisos;

  /// Hace la copia de seguridad sola cuando algo cambia.
  late final ProgramadorDeCopias _copias;

  @override
  void initState() {
    super.initState();
    // Si la app se cerró después de compartir, el PDF se borra al volver.
    widget.compartidor.limpiar();
    // Desde ya: la app pudo abrirse con algo compartido o desde un aviso.
    _recepcion = Recepcion(buzon: widget.buzon, navegador: _navegador, cerrojo: _cerrojo);
    widget.recordatorios.iniciar(_recepcion.abrirDocumento);
    _avisos = ProgramadorDeAvisos(repo: widget.repo, recordatorios: widget.recordatorios);
    _copias = ProgramadorDeCopias(copia: widget.copia, repo: widget.repo);
  }

  @override
  void dispose() {
    _avisos.dispose();
    _copias.dispose();
    _recepcion.dispose();
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
          child: CompartidorScope(
            compartidor: widget.compartidor,
            child: SelectorScope(
              selector: widget.selector,
              child: RecepcionScope(
                recepcion: _recepcion,
                child: RecordatoriosScope(
                  recordatorios: widget.recordatorios,
                  child: CopiaScope(
                    copia: widget.copia,
                    child: AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
                      child: MaterialApp(
                        navigatorKey: _navegador,
                        navigatorObservers: [_recepcion.rutas],
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
