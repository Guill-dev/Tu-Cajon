import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/copia/cifrado_copia.dart';
import '../../data/copia/copia_de_seguridad.dart';
import '../../data/copia/nube.dart';
import '../../shared/illustrations/cajon_mini.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/text_field.dart';

enum _Paso {
  /// Explica y ofrece conectar la cuenta.
  inicio,
  buscando,
  sinCopia,

  /// Hay copia pero la llave no llegó a este celular.
  faltaCodigo,

  /// Copia abierta: muestra qué tiene y ofrece traerla.
  lista,
  recuperando,
  listo,
  error,
}

/// Recuperar mi cajón: al estrenar celular, trae la copia de Google Drive.
///
/// 1. Conecta la cuenta y busca la copia.
/// 2. Si la llave llegó sola (Block Store), la copia ya se puede abrir; si
///    no, pide el código de emergencia.
/// 3. Muestra qué tiene la copia y la trae: cambia todo el cajón por ella.
/// 4. Sigue a la llave del cajón (huella o PIN) de este celular.
class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  _Paso _paso = _Paso.inicio;
  CopiaEncontrada? _encontrada;
  String? _problema;
  String? _problemaCodigo;
  bool _abriendo = false;
  int _hechos = 0;
  int _total = 0;
  final _codigo = TextEditingController();

  late final CopiaDeSeguridad _copia = context.copia;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() => _paso = _Paso.buscando);
    try {
      final copia = await _copia.buscarCopia();
      if (!mounted) return;
      setState(() {
        _encontrada = copia;
        _paso = copia == null
            ? _Paso.sinCopia
            : copia.abierta
            ? _Paso.lista
            : _Paso.faltaCodigo;
      });
    } on ConexionCancelada {
      if (mounted) setState(() => _paso = _Paso.inicio);
    } on ProblemaNube catch (e) {
      _fallo(e.mensaje);
    } catch (e) {
      debugPrint('No se pudo buscar la copia: $e');
      _fallo('No se pudo leer la copia. Intenta de nuevo.');
    }
  }

  Future<void> _otraCuenta() async {
    await _copia.desconectar();
    await _buscar();
  }

  Future<void> _abrirConCodigo() async {
    final encontrada = _encontrada;
    if (encontrada == null) return;
    setState(() {
      _abriendo = true;
      _problemaCodigo = null;
    });
    try {
      final abierta = await _copia.abrirConCodigo(encontrada, _codigo.text);
      if (!mounted) return;
      setState(() {
        _encontrada = abierta;
        _paso = _Paso.lista;
      });
    } on CodigoEquivocado {
      if (mounted) setState(() => _problemaCodigo = 'Ese código no abre la copia. Revísalo.');
    } on ProblemaNube catch (e) {
      if (mounted) setState(() => _problemaCodigo = e.mensaje);
    } catch (e) {
      debugPrint('No se pudo abrir con el código: $e');
      if (mounted) setState(() => _problemaCodigo = 'No se pudo abrir la copia. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _recuperar() async {
    final encontrada = _encontrada;
    if (encontrada == null) return;
    setState(() => _paso = _Paso.recuperando);
    try {
      await _copia.recuperar(
        encontrada,
        progreso: (hechos, total) {
          if (mounted) {
            setState(() {
              _hechos = hechos;
              _total = total;
            });
          }
        },
      );
      if (mounted) setState(() => _paso = _Paso.listo);
    } on ProblemaNube catch (e) {
      _fallo(e.mensaje);
    } catch (e) {
      debugPrint('No se pudo recuperar la copia: $e');
      _fallo('No se pudo traer la copia. Tu celular quedó como estaba; intenta de nuevo.');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _problema = mensaje;
      _paso = _Paso.error;
    });
  }

  /// Después de recuperar: la llave del cajón de este celular.
  void _seguir() => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.proteccion, (_) => false);

  @override
  Widget build(BuildContext context) {
    final ocupado = _paso == _Paso.buscando || _paso == _Paso.recuperando;
    return PopScope(
      // Mientras trae la copia no se sale a mitad.
      canPop: !ocupado && _paso != _Paso.listo,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ocupado && _paso != _Paso.listo)
                const BackHeader(title: 'Recuperar mi cajón', titleSize: 28)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 64, 20, 8),
                  child: Text('Recuperar mi cajón', style: AppText.display(28)),
                ),
              Expanded(
                child: FillScroll(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: CajonMini(width: 124, abierto: _paso == _Paso.listo)),
                      const SizedBox(height: 24),
                      ..._contenido(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    final prueba = _copia.nube.deprueba;
    switch (_paso) {
      case _Paso.inicio:
        return [
          _Texto(
            'Si ya usabas Tu Cajón en otro celular y tenías la copia en Google Drive, aquí la traes de '
            'vuelta: tus documentos, perfiles y fechas.',
          ),
          if (prueba) ...[
            const SizedBox(height: 12),
            _Texto('Modo de prueba: se busca la copia guardada dentro de este celular.', suave: true),
          ],
          const Spacer(),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Conectar con Google', icon: AppIcons.nube, onTap: _buscar),
        ];
      case _Paso.buscando:
        return [const _Cargando(texto: 'Buscando tu copia…'), const Spacer()];
      case _Paso.sinCopia:
        return [
          _Texto('No encontramos una copia de Tu Cajón en esta cuenta.', fuerte: true),
          const SizedBox(height: 8),
          _Texto('Si tenías otra cuenta de Google, prueba con esa.', suave: true),
          const Spacer(),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Probar con otra cuenta', onTap: _otraCuenta),
          const SizedBox(height: 10),
          OutlineButtonTc(label: 'Empezar de cero', onTap: () => Navigator.of(context).pop()),
        ];
      case _Paso.faltaCodigo:
        final e = _encontrada!;
        return [
          _Texto('Encontramos tu copia del ${Formato.fechaLarga(e.fecha)}.', fuerte: true),
          const SizedBox(height: 8),
          if (e.conCodigo) ...[
            _Texto(
              'Pero la llave no llegó a este celular. Escribe el código de emergencia que anotaste.',
              suave: true,
            ),
            const SizedBox(height: 18),
            TcTextField(
              label: 'Código de emergencia',
              controller: _codigo,
              hint: 'XXXX-XXXX-XXXX-XXXX',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _abrirConCodigo(),
            ),
            if (_problemaCodigo != null) ...[
              const SizedBox(height: 8),
              Text(_problemaCodigo!, style: AppText.bold(14, color: AppColors.rojo)),
            ],
            const Spacer(),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Abrir la copia',
              disabledLabel: 'Abriendo…',
              onTap: _abriendo ? null : _abrirConCodigo,
            ),
          ] else ...[
            _Texto(
              'Pero la llave no llegó a este celular, y esta copia no tiene código de emergencia. La llave '
              'llega sola cuando configuras el celular restaurando tu cuenta de Google con el PIN o patrón '
              'del celular anterior.',
              suave: true,
            ),
            const Spacer(),
            const SizedBox(height: 24),
            OutlineButtonTc(label: 'Empezar de cero', onTap: () => Navigator.of(context).pop()),
          ],
        ];
      case _Paso.lista:
        final e = _encontrada!;
        final c = e.indice!.contenido;
        return [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppDecor.tarjeta(),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarioSuave,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const TcIcon(AppIcons.nube, size: 26, color: AppColors.primario),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text('Copia del ${Formato.fechaLarga(e.fecha)}', style: AppText.bold(16)),
                      Text(
                        '${c.nombre.isEmpty ? '' : '${c.nombre} · '}${resumenDe(c)} · ${Formato.tamano(e.bytes)}',
                        style: AppText.secondary(14, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Texto('Todo lo que tiene la copia queda en este celular, cifrado como siempre.', suave: true),
          const Spacer(),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Recuperar mi cajón', onTap: _recuperar),
        ];
      case _Paso.recuperando:
        return [
          _Cargando(
            texto: _total == 0 ? 'Trayendo tu cajón…' : 'Trayendo tus documentos: $_hechos de $_total',
            valor: _total == 0 ? null : _hechos / _total,
          ),
          const SizedBox(height: 10),
          _Texto('No cierres la app mientras tanto.', suave: true),
          const Spacer(),
        ];
      case _Paso.listo:
        final c = _encontrada!.indice!.contenido;
        final n = c.documentos.length;
        return [
          _Texto(c.nombre.isEmpty ? '¡Listo!' : '¡Listo, ${c.nombre}!', fuerte: true),
          const SizedBox(height: 8),
          _Texto(
            'Recuperamos ${n == 1 ? '1 documento' : '$n documentos'}. Ahora protege tu cajón con la llave '
            'de este celular.',
            suave: true,
          ),
          const Spacer(),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Seguir', trailingIcon: AppIcons.siguiente, onTap: _seguir),
        ];
      case _Paso.error:
        return [
          _Texto(_problema ?? 'Algo salió mal.', fuerte: true),
          const Spacer(),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Intentar de nuevo', onTap: _buscar),
          const SizedBox(height: 10),
          TcTap(
            onTap: () => Navigator.of(context).pop(),
            height: 48,
            child: Center(
              child: Text('Volver', style: AppText.bold(16, color: AppColors.primario)),
            ),
          ),
        ];
    }
  }
}

class _Texto extends StatelessWidget {
  const _Texto(this.texto, {this.fuerte = false, this.suave = false});

  final String texto;
  final bool fuerte;
  final bool suave;

  @override
  Widget build(BuildContext context) {
    final estilo = fuerte
        ? AppText.bold(19, height: 1.35)
        : suave
        ? AppText.secondary(15, height: 1.45)
        : AppText.body(17, height: 1.45);
    return Semantics(
      liveRegion: fuerte,
      child: Text(texto, textAlign: TextAlign.center, style: estilo),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando({required this.texto, this.valor});

  final String texto;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(texto, textAlign: TextAlign.center, style: AppText.bold(17)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: valor,
            minHeight: 6,
            color: AppColors.primario,
            backgroundColor: AppColors.primarioSuave,
          ),
        ),
      ],
    );
  }
}
