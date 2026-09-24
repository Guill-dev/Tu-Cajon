import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/motion.dart';
import '../../core/router/app_routes.dart';
import '../../core/seguridad/cerrojo.dart';
import '../../core/seguridad/llave_celular.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/repositorio_scope.dart';
import '../../shared/illustrations/cajon_mini.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pulse_ring.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';

enum _Estado {
  /// Esperando a que la persona toque.
  quieto,

  /// La animación de la huella corre sola antes de que salga el diálogo.
  preparando,

  /// El diálogo del celular está encima.
  esperando,

  /// Confirmado: la huella se vuelve un check verde y el cajón se abre.
  abierto,
}

/// 4 · Abrir el cajón: lo que ve quien vuelve a la app.
/// Botón de huella con dos anillos latiendo (2 s, desfasados 1 s).
///
/// Al aparecer pide sola la llave del celular (huella, rostro, PIN o patrón):
/// 1. primero se luce la animación de la huella (los anillos laten más rápido),
/// 2. luego sale el diálogo del celular, que tapa parte de la pantalla,
/// 3. al confirmar, la huella se vuelve un check verde con un destello, el
///    cajón del dibujo se abre y recién ahí se entra.
///
/// Si la persona cancela, el botón y "Usar el PIN" la vuelven a pedir.
///
/// También es la pantalla que pone el [Cerrojo] encima cuando la persona
/// vuelve de otra app; en ese caso [alAbrir] la quita y se sigue donde estaba.
class DesbloqueoScreen extends StatefulWidget {
  const DesbloqueoScreen({super.key, this.alAbrir});

  /// Qué hacer al abrir. Sin él, se entra a "Mi cajón" desde el principio.
  final VoidCallback? alAbrir;

  /// Cuánto se ve la animación de la huella antes del diálogo del celular.
  static const antesDelDialogo = Duration(milliseconds: 900);

  /// Cuánto dura la celebración de "abierto" antes de entrar.
  static const celebracion = Duration(milliseconds: 1100);

  @override
  State<DesbloqueoScreen> createState() => _DesbloqueoScreenState();
}

class _DesbloqueoScreenState extends State<DesbloqueoScreen> with ToastMixin {
  late final Stream<String> _nombre = context.repo.vigilarNombre();
  late final Stream<List<Perfil>> _perfiles = context.repo.vigilarPerfiles();

  _Estado _estado = _Estado.quieto;

  /// Espera a que la app vuelva a estar en pantalla antes de pedir la llave.
  AppLifecycleListener? _oyente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrir();
    });
  }

  @override
  void dispose() {
    _oyente?.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    // Mientras el diálogo del celular está abierto no se puede pedir otro.
    if (_estado != _Estado.quieto) return;
    setState(() => _estado = _Estado.preparando);
    await Future<void>.delayed(DesbloqueoScreen.antesDelDialogo);
    await _esperarPrimerPlano();
    if (!mounted) return;
    setState(() => _estado = _Estado.esperando);

    final resultado = await context.llave.abrir('Abre tu cajón con lo mismo que desbloquea tu celular');
    if (!mounted) return;
    if (resultado != ResultadoLlave.abierto) {
      setState(() => _estado = _Estado.quieto);
      final aviso = resultado.aviso;
      if (aviso != null) showToast(aviso, duration: const Duration(seconds: 5));
      return;
    }

    context.cerrojo.entrar();
    setState(() => _estado = _Estado.abierto);
    await Future<void>.delayed(DesbloqueoScreen.celebracion);
    if (!mounted) return;
    if (widget.alAbrir case final alAbrir?) {
      alAbrir();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.cajon, (_) => false);
    }
  }

  /// Si la persona volvió a salir de la app, el diálogo espera a que regrese.
  Future<void> _esperarPrimerPlano() async {
    final ahora = WidgetsBinding.instance.lifecycleState;
    if (ahora == null || ahora == AppLifecycleState.resumed) return;
    final volvio = Completer<void>();
    _oyente?.dispose();
    _oyente = AppLifecycleListener(onResume: () => volvio.isCompleted ? null : volvio.complete());
    await volvio.future;
    _oyente?.dispose();
    _oyente = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _nombre,
      builder: (context, snapNombre) => StreamBuilder(
        stream: _perfiles,
        builder: (context, snapPerfiles) {
          final nombre = snapNombre.data ?? '';
          final total = snapPerfiles.data?.firstWhere((p) => p.esPropio).documentos ?? 0;
          return Scaffold(
            backgroundColor: AppColors.fondo,
            body: Stack(
              children: [
                _contenido(nombre, total),
                TcToast(message: toastMessage, bottom: 24, icon: AppIcons.candado),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _contenido(String nombre, int total) {
    final abierto = _estado == _Estado.abierto;
    final (titulo, detalle) = switch (_estado) {
      _Estado.quieto => ('Toca para abrir', 'Con tu huella, rostro o PIN'),
      _Estado.preparando || _Estado.esperando => ('Abriendo tu cajón…', 'Usa tu huella, rostro o PIN'),
      _Estado.abierto => ('¡Listo, está abierto!', 'Entrando a tu cajón…'),
    };
    return SafeArea(
      child: FillScroll(
        padding: const EdgeInsets.fromLTRB(32, 64, 32, 40),
        child: Column(
          children: [
            CajonMini(width: 124, abierto: abierto),
            const SizedBox(height: 32),
            Semantics(
              header: true,
              label: 'Hola de nuevo, $nombre',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text('Hola de nuevo,', textAlign: TextAlign.center, style: AppText.displayLight(32)),
                  Text(nombre, textAlign: TextAlign.center, style: AppText.display(32)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Cambiante(
              valor: abierto ? 'Tu cajón está abierto.' : 'Tu cajón está cerrado con llave.',
              estilo: AppText.body(18, color: AppColors.textoTerciario, height: 1.45),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            _BotonHuella(estado: _estado, onTap: _abrir),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: _Cambiante(valor: titulo, estilo: AppText.bold(19)),
            ),
            const SizedBox(height: 4),
            _Cambiante(valor: detalle, estilo: AppText.secondary(15)),
            const SizedBox(height: 28),
            // El diálogo del celular ofrece el PIN o patrón como alternativa.
            AnimatedOpacity(
              opacity: _estado == _Estado.quieto ? 1 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: TcTap(
                onTap: _estado == _Estado.quieto ? _abrir : null,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'Usar el PIN del celular',
                    style: AppText.bold(
                      17,
                      color: AppColors.primario,
                    ).copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.primario),
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            PrivacyNote(
              total == 1
                  ? '1 documento guardado solo en este celular'
                  : '$total documentos guardados solo en este celular',
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto que cambia con un fundido corto.
class _Cambiante extends StatelessWidget {
  const _Cambiante({required this.valor, required this.estilo});

  final String valor;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Text(valor, key: ValueKey(valor), textAlign: TextAlign.center, style: estilo),
    );
  }
}

/// El botón grande de la huella y sus animaciones:
/// - quieto: dos anillos laten despacio (2 s);
/// - abriendo: laten el doble de rápido y el botón crece un poco;
/// - abierto: se pone verde, la huella se vuelve un check que rebota y sale
///   un destello verde hacia afuera.
class _BotonHuella extends StatelessWidget {
  const _BotonHuella({required this.estado, required this.onTap});

  static const _tam = 136.0;

  final _Estado estado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final abierto = estado == _Estado.abierto;
    final activo = estado == _Estado.preparando || estado == _Estado.esperando;
    final periodo = activo ? const Duration(milliseconds: 1000) : const Duration(seconds: 2);
    return SizedBox(
      width: _tam,
      height: _tam,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (abierto)
            const _Destello(tam: _tam)
          else ...[
            // La clave nueva reinicia los anillos con el ritmo nuevo.
            PulseRing(key: ValueKey('a$activo'), size: _tam, color: AppColors.pulso, period: periodo),
            PulseRing(
              key: ValueKey('b$activo'),
              size: _tam,
              color: AppColors.pulso,
              period: periodo,
              delay: periodo ~/ 2,
            ),
          ],
          AnimatedScale(
            scale: activo ? 1.06 : 1,
            duration: const Duration(milliseconds: 420),
            curve: Motion.suave,
            child: TcTap(
              onTap: estado == _Estado.quieto ? onTap : null,
              color: abierto ? AppColors.verde : AppColors.primario,
              radius: _tam / 2,
              width: _tam,
              height: _tam,
              semanticLabel: abierto ? 'Cajón abierto' : 'Abrir con huella, rostro o PIN',
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (hijo, animacion) => ScaleTransition(
                    scale: animacion,
                    child: FadeTransition(opacity: animacion, child: hijo),
                  ),
                  child: abierto
                      ? const TcIcon(AppIcons.check, key: ValueKey('check'), size: 68, color: Colors.white)
                      : const TcIcon(
                          AppIcons.huella,
                          key: ValueKey('huella'),
                          size: 72,
                          strokeWidth: 1.3,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un aro verde y un halo suave que salen una sola vez hacia afuera.
class _Destello extends StatelessWidget {
  const _Destello({required this.tam});

  final double tam;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return SizedBox.square(dimension: tam);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.5 * (1 - t),
            child: Transform.scale(
              scale: 1 + 0.7 * t,
              child: Container(
                width: tam,
                height: tam,
                decoration: const BoxDecoration(color: AppColors.verdeSuave, shape: BoxShape.circle),
              ),
            ),
          ),
          Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 1 + 0.45 * t,
              child: Container(
                width: tam,
                height: tam,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.verde, width: 5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
