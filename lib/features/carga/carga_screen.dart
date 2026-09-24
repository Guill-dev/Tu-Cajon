import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/archivos/recepcion.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/illustrations/cajon_animado.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/tc_icon.dart';

enum _Modo {
  /// Todavía se está leyendo si el usuario ya se registró.
  revisando,

  /// Primera vez (o registro sin terminar): flecha y puntos; espera el toque.
  bienvenida,

  /// Ya entró antes a su cajón: pantalla de carga que avanza sola.
  carga,
}

/// 1 · Carga: el cajón se abre con animación sobre unos aros blancos, datos
/// clave en píldoras y una pregunta grande.
///
/// - **Primera vez** (o si no terminó el registro): lleva la flecha y los
///   puntos, y espera a que el usuario toque para ir a la Bienvenida.
/// - **Ya registrado** (activó la llave y entró a su cajón): es solo una
///   pantalla de carga, sin flecha ni nada que tocar, y a los
///   [duracionCarga] pasa sola a "Abrir el cajón".
///
/// En modo desarrollo, mantener presionado abre el catálogo de pantallas.
class CargaScreen extends StatefulWidget {
  const CargaScreen({super.key});

  /// Cuánto dura la pantalla de carga para quien ya está registrado.
  static const duracionCarga = Duration(milliseconds: 4500);

  /// Cuando se abrió desde "Compartir": solo un vistazo.
  static const cargaCorta = Duration(milliseconds: 1200);

  @override
  State<CargaScreen> createState() => _CargaScreenState();
}

class _CargaScreenState extends State<CargaScreen> {
  _Modo _modo = _Modo.revisando;
  Timer? _temporizador;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modo == _Modo.revisando) _revisarRegistro();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  /// "Registrado" = terminó la bienvenida: escribió su nombre, activó la
  /// llave y entró a su cajón. Si se quedó a mitad, se le vuelve a mostrar
  /// la bienvenida.
  Future<void> _revisarRegistro() async {
    final messenger = ScaffoldMessenger.of(context);
    final recepcion = context.recepcion;
    try {
      final registrado = await context.repo.llaveActivada();
      // Si se abrió desde "Compartir → Tu Cajón" o desde un aviso, la persona
      // viene a algo: la carga es corta y pasa rápido a la llave.
      final llegoAlgo =
          registrado &&
          (await recepcion.revisado.timeout(const Duration(seconds: 1), onTimeout: () => false) ||
              recepcion.hayAlgoPorAbrir);
      if (!mounted) return;
      setState(() => _modo = registrado ? _Modo.carga : _Modo.bienvenida);
      if (registrado) {
        _temporizador = Timer(llegoAlgo ? CargaScreen.cargaCorta : CargaScreen.duracionCarga, _irAlCajon);
      }
    } catch (e) {
      // Antes el error se perdía y la pantalla se quedaba quieta sin avisar.
      debugPrint('No se pudo leer la base de datos: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos abrir tu cajón. Cierra la app y vuelve a intentarlo.')),
      );
    }
  }

  void _irAlCajon() {
    if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.desbloqueo);
  }

  void _irABienvenida() => Navigator.of(context).pushReplacementNamed(AppRoutes.bienvenida);

  @override
  Widget build(BuildContext context) {
    final esBienvenida = _modo == _Modo.bienvenida;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Semantics(
        // En modo carga no hay nada que tocar: se anuncia que está abriendo.
        label: _modo == _Modo.carga ? 'Abriendo Tu Cajón' : null,
        liveRegion: _modo == _Modo.carga,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Solo en la bienvenida se avanza tocando la pantalla.
          onTap: esBienvenida ? _irABienvenida : null,
          onLongPress: kDebugMode ? () => Navigator.of(context).pushNamed(AppRoutes.catalogo) : null,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const TcIcon(
                                  AppIcons.cajon,
                                  size: 22,
                                  color: AppColors.primario,
                                  strokeWidth: 2,
                                ),
                                const SizedBox(width: 8),
                                Text('Tu Cajón', style: AppText.display(18)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const _Ilustracion(),
                            const SizedBox(height: 20),
                            const Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _Dato(fuerte: '100%', suave: 'en tu celular'),
                                _Dato(fuerte: 'Sin', suave: 'registro'),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text('¿Tus papeles, siempre a la mano?', style: AppText.display(30, height: 1.2)),
                            const SizedBox(height: 10),
                            Text(
                              'Guarda tu cédula, recibos y certificados, y envíalos por WhatsApp en segundos.',
                              style: AppText.secondary(15, height: 1.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Mismo alto en los tres modos, para que nada salte de lugar.
                        SizedBox(
                          height: 56,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: esBienvenida
                                ? Row(
                                    key: const ValueKey('flecha'),
                                    children: [
                                      const _Puntos(),
                                      const Spacer(),
                                      ArrowButton(onTap: _irABienvenida, semanticLabel: 'Entrar a Tu Cajón'),
                                    ],
                                  )
                                : const SizedBox.shrink(key: ValueKey('vacio')),
                          ),
                        ),
                      ],
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

/// El cajón animado sobre dos aros blancos (los arcos de la referencia).
class _Ilustracion extends StatelessWidget {
  const _Ilustracion();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40,
            top: 0,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.superficie, width: 22),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 10,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
            ),
          ),
          const CajonAnimado(width: 250),
        ],
      ),
    );
  }
}

/// Píldora de dato ("500K+ books" en la referencia).
class _Dato extends StatelessWidget {
  const _Dato({required this.fuerte, required this.suave});

  final String fuerte;
  final String suave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.primarioSuave, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(fuerte, style: AppText.bold(16, color: AppColors.primario)),
          Text(suave, style: AppText.body(13, color: AppColors.primarioTextoSuave)),
        ],
      ),
    );
  }
}

/// Indicador de páginas: la actual es una raya larga del acento.
class _Puntos extends StatelessWidget {
  const _Puntos();

  @override
  Widget build(BuildContext context) {
    Widget raya(double w, Color c) => Container(
      width: w,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          raya(24, AppColors.primario),
          raya(6, AppColors.bordePunteado),
          raya(6, AppColors.bordePunteado),
        ],
      ),
    );
  }
}
