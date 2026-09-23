import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/documento.dart';
import '../../features/agregar/agregar_screen.dart';
import '../../features/bienvenida/bienvenida_screen.dart';
import '../../features/cajon/cajon_shell.dart';
import '../../features/carga/carga_screen.dart';
import '../../features/catalogo/catalogo_screen.dart';
import '../../features/desbloqueo/desbloqueo_screen.dart';
import '../../features/detalle/detalle_screen.dart';
import '../../features/escanear/escanear_screen.dart';
import '../../features/guardar/guardar_screen.dart';
import '../../features/paginas/paginas_screen.dart';
import '../../features/perfil/agregar_perfil_screen.dart';
import '../../features/preguntar/preguntar_screen.dart';
import '../../features/proteccion/proteccion_screen.dart';

/// Nombres de todas las rutas. El comentario dice qué artboard del diseño es.
abstract final class AppRoutes {
  static const carga = '/'; // 1 · Carga
  static const bienvenida = '/bienvenida'; // 2 · Bienvenida
  static const proteccion = '/proteccion'; // 3 · La llave del cajón
  static const desbloqueo = '/desbloqueo'; // 4 · Abrir el cajón
  static const cajon = '/cajon'; // 5 y 7 · Mi cajón + Avisos (con barra inferior)
  static const detalle = '/detalle'; // 6 · Documento
  static const agregar = '/agregar'; // 8 · Agregar documento
  static const escanear = '/escanear'; // 9 · Escanear
  static const paginas = '/paginas'; // Tus páginas (fotos de la galería)
  static const guardar = '/guardar'; // 10 · Guardar
  static const preguntar = '/preguntar'; // 11 · Pregúntale a tu cajón
  static const nuevoPerfil = '/perfil/nuevo'; // 12 · Nuevo perfil
  static const catalogo = '/_pantallas'; // Solo desarrollo: lista de pantallas

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      carga => const CargaScreen(),
      bienvenida => const BienvenidaScreen(),
      proteccion => const ProteccionScreen(),
      desbloqueo => const DesbloqueoScreen(),
      cajon => CajonShell(pestanaInicial: args is CajonTab ? args : CajonTab.inicio),
      // Documento: recibe el id (o el Documento). Sin argumento, abre el primero.
      detalle => DetalleScreen(documentoId: args is Documento ? args.id : (args is String ? args : null)),
      agregar => const AgregarScreen(),
      // Escanear: puede recibir las fotos ya tomadas ("Otra página").
      escanear => EscanearScreen(paginasPrevias: args is List<Uint8List> ? args : const []),
      // Tus páginas: fotos elegidas en la galería.
      paginas => PaginasScreen(entrada: args is EntradaPaginas ? args : const EntradaPaginas()),
      // Guardar: un PDF subido, fotos de la galería o de la cámara, o cuántas
      // páginas simuladas hubo.
      guardar => switch (args) {
        PdfSubido pdf => GuardarScreen(pdf: pdf),
        FotosDeGaleria(:final fotos) => GuardarScreen(
          fotos: fotos,
          paginas: fotos.length,
          origen: OrigenFotos.galeria,
        ),
        List<Uint8List> fotos => GuardarScreen(fotos: fotos, paginas: fotos.length),
        int n => GuardarScreen(paginas: n),
        _ => const GuardarScreen(),
      },
      preguntar => const PreguntarScreen(),
      nuevoPerfil => const AgregarPerfilScreen(),
      catalogo => const CatalogoScreen(),
      _ => const CargaScreen(),
    };

    // La carga entra con un fundido; el resto usa la transición del sistema.
    if (settings.name == bienvenida || settings.name == desbloqueo) {
      return PageRouteBuilder(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      );
    }
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}
