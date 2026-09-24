import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../data/copia/copia_de_seguridad.dart';
import '../../data/copia/nube.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/interruptor.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';

/// Ajustes. Por ahora: la copia de seguridad en Google Drive.
///
/// Todo lo que muestra sale de `CopiaDeSeguridad.estado`, así que se
/// actualiza solo mientras la copia avanza.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> with ToastMixin {
  bool _conectando = false;

  /// Si la llave viaja sola a otro celular (bloqueo de pantalla + Block Store).
  bool? _protegida;

  late final CopiaDeSeguridad _copia = context.copia;

  @override
  void initState() {
    super.initState();
    _copia.llaveProtegidaConBloqueo().then((p) {
      if (mounted) setState(() => _protegida = p);
    });
  }

  Future<void> _conectar() async {
    setState(() => _conectando = true);
    try {
      final lista = await _copia.conectar();
      if (!lista) {
        if (!mounted) return;
        final reemplazar = await confirmar(
          context,
          titulo: 'Ya hay una copia en esta cuenta',
          texto:
              'Es de otro celular y este no la puede abrir. Si sigues, esa copia se borra y queda la de '
              'este celular.',
          accion: 'Reemplazarla',
        );
        if (!reemplazar) {
          await _copia.desconectar();
          return;
        }
        await _copia.reemplazarCopiaAjena();
      }
      // La primera copia, de una vez.
      unawaited(_copia.hacerCopia());
    } on ConexionCancelada {
      // Cerró el selector de cuentas: no pasa nada.
    } on ProblemaNube catch (e) {
      if (mounted) showToast(e.mensaje);
    } catch (e) {
      debugPrint('No se pudo conectar: $e');
      if (mounted) showToast('No se pudo conectar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  Future<void> _copiarAhora() async {
    await _copia.hacerCopia();
    if (mounted && _copia.estado.value.problema == null) showToast('Listo: tu copia está al día.');
  }

  Future<void> _desconectar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Desconectar Google Drive?',
      texto:
          'La copia que ya está en tu Drive se queda allá. Este celular deja de hacer copias hasta que '
          'lo conectes otra vez.',
      accion: 'Desconectar',
    );
    if (ok) await _copia.desconectar();
  }

  Future<void> _crearCodigo() async {
    if (_copia.estado.value.codigoCreado != null) {
      final ok = await confirmar(
        context,
        titulo: '¿Crear otro código?',
        texto: 'El código que tienes anotado deja de servir. Tendrás que anotar el nuevo.',
        accion: 'Crear otro',
      );
      if (!ok) return;
    }
    try {
      final codigo = await _copia.crearCodigoDeEmergencia();
      if (mounted) await _mostrarCodigo(codigo);
    } on ProblemaNube catch (e) {
      if (mounted) showToast(e.mensaje);
    } catch (e) {
      debugPrint('No se pudo crear el código: $e');
      if (mounted) showToast('No se pudo crear el código. Intenta de nuevo.');
    }
  }

  Future<void> _mostrarCodigo(String codigo) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DialogoTc(
      titulo: 'Tu código de emergencia',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                codigo,
                style: AppText.bold(24, color: AppColors.primarioOscuro).copyWith(letterSpacing: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Anótalo en papel y guárdalo con tus cosas importantes. Solo lo necesitarías si estrenas '
            'celular y tu copia no se abre sola.',
            style: AppText.secondary(15, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text('No lo volveremos a mostrar.', style: AppText.bold(15)),
        ],
      ),
      acciones: [
        SmallButton(
          label: 'Copiar',
          filled: false,
          onTap: () => Clipboard.setData(ClipboardData(text: codigo)),
        ),
        SmallButton(label: 'Ya lo anoté', onTap: () => Navigator.of(context).pop()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BackHeader(title: 'Ajustes'),
                Expanded(
                  child: NoScrollbar(
                    child: ValueListenableBuilder(
                      valueListenable: _copia.estado,
                      builder: (context, e, _) => ListView(
                        padding: EdgeInsets.fromLTRB(20, 6, 20, 32 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          Semantics(header: true, child: Text('Copia de seguridad', style: AppText.bold(18))),
                          const SizedBox(height: 12),
                          if (_copia.nube.deprueba) ...[const _AvisoDePrueba(), const SizedBox(height: 12)],
                          _TarjetaCopia(
                            estado: e,
                            conectando: _conectando,
                            onConectar: _conectar,
                            onCopiar: _copiarAhora,
                          ),
                          if (e.conectada) ...[
                            const SizedBox(height: 12),
                            _Opciones(
                              estado: e,
                              protegida: _protegida,
                              onSoloWifi: () => _copia.cambiarSoloWifi(!e.soloWifi),
                              onCodigo: _crearCodigo,
                              onDesconectar: _desconectar,
                            ),
                          ],
                          const SizedBox(height: 28),
                          Semantics(header: true, child: Text('Cómo te cuida', style: AppText.bold(18))),
                          const SizedBox(height: 12),
                          const _ComoFunciona(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TcToast(message: toastMessage, bottom: 24, icon: AppIcons.nube),
        ],
      ),
    );
  }
}

/// "hoy, 3:45 p. m." · "ayer, 9:10 a. m." · "12 de septiembre".
String _cuando(DateTime f, DateTime ahora) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final hora = '$h:${f.minute.toString().padLeft(2, '0')} ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
  final dias = Formato.diasEntre(f, ahora);
  if (dias == 0) return 'hoy, $hora';
  if (dias == 1) return 'ayer, $hora';
  return f.year == ahora.year ? Formato.diaMes(f) : Formato.fechaLarga(f);
}

class _AvisoDePrueba extends StatelessWidget {
  const _AvisoDePrueba();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ambarSuave,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ambarBorde),
      ),
      child: Text(
        'Modo de prueba: todavía no está conectada con Google. La copia se guarda dentro de este '
        'mismo celular para probar cómo funciona.',
        style: AppText.body(14, height: 1.4),
      ),
    );
  }
}

class _TarjetaCopia extends StatelessWidget {
  const _TarjetaCopia({
    required this.estado,
    required this.conectando,
    required this.onConectar,
    required this.onCopiar,
  });

  final EstadoCopia estado;
  final bool conectando;
  final VoidCallback onConectar;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecor.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                  spacing: 2,
                  children: [
                    Text('Google Drive', style: AppText.bold(17)),
                    Text(
                      e.cuenta ?? 'Sin conectar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary(14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(liveRegion: true, child: _estadoTexto(e)),
          const SizedBox(height: 16),
          if (!e.conectada)
            PrimaryButton(
              label: 'Conectar con Google',
              disabledLabel: 'Conectando…',
              height: 56,
              onTap: conectando ? null : onConectar,
            )
          else
            OutlineButtonTc(
              label: e.haciendo ? 'Haciendo la copia…' : 'Hacer copia ahora',
              onTap: e.haciendo ? null : onCopiar,
            ),
        ],
      ),
    );
  }

  Widget _estadoTexto(EstadoCopia e) {
    if (!e.conectada) {
      return Text(
        e.problema ??
            'Guarda una copia cifrada de tu cajón en tu Google Drive. Se hace sola cada vez que guardas '
                'algo, y solo tú puedes abrirla.',
        style: AppText.secondary(15, height: 1.45),
      );
    }
    if (e.haciendo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            e.total == 0 ? 'Preparando la copia…' : 'Revisando tus documentos: ${e.hechos} de ${e.total}',
            style: AppText.body(15),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: e.total == 0 ? null : e.hechos / e.total,
              minHeight: 6,
              color: AppColors.primario,
              backgroundColor: AppColors.primarioSuave,
            ),
          ),
        ],
      );
    }
    final problema = e.problema;
    if (problema != null) {
      return _Linea(icono: AppIcons.cerrar, color: AppColors.rojo, texto: problema);
    }
    if (e.esperandoWifi) {
      return const _Linea(
        icono: AppIcons.reloj,
        color: AppColors.ambar,
        texto: 'La copia automática espera el Wi-Fi para no gastar tus datos.',
      );
    }
    final ultima = e.ultima;
    if (ultima == null) {
      return Text('Todavía no hay copia.', style: AppText.secondary(15));
    }
    final docs = e.documentos == 1 ? '1 documento' : '${e.documentos} documentos';
    return _Linea(
      icono: AppIcons.check,
      color: AppColors.verde,
      texto: 'Última copia: ${_cuando(ultima, DateTime.now())}\n$docs · ${Formato.tamano(e.bytes)}',
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.color, required this.texto});

  final String icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: TcIcon(icono, size: 20, color: color, strokeWidth: 2.2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: AppText.body(15, height: 1.45))),
      ],
    );
  }
}

class _Opciones extends StatelessWidget {
  const _Opciones({
    required this.estado,
    required this.protegida,
    required this.onSoloWifi,
    required this.onCodigo,
    required this.onDesconectar,
  });

  final EstadoCopia estado;
  final bool? protegida;
  final VoidCallback onSoloWifi;
  final VoidCallback onCodigo;
  final VoidCallback onDesconectar;

  @override
  Widget build(BuildContext context) {
    final codigo = estado.codigoCreado;
    final textoCodigo = codigo != null
        ? 'Creado el ${Formato.fechaLarga(codigo)}. Si lo perdiste, crea otro.'
        : protegida == false
        ? 'Tu celular no tiene bloqueo de pantalla: sin este código no podrías abrir la copia en otro '
              'celular. Te recomendamos crearlo.'
        : 'Por si estrenas celular y la copia no se abre sola.';
    return Container(
      decoration: AppDecor.tarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            toggled: estado.soloWifi,
            label: 'Solo con Wi-Fi',
            excludeSemantics: true,
            child: TcTap(
              onTap: onSoloWifi,
              radius: 0,
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text('Solo con Wi-Fi', style: AppText.bold(16)),
                        Text(
                          'La copia automática espera el Wi-Fi para no gastar tus datos.',
                          style: AppText.secondary(14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Interruptor(activo: estado.soloWifi),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divisor),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('Código de emergencia', style: AppText.bold(16)),
                      Text(textoCodigo, style: AppText.secondary(14, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SmallButton(
                  label: codigo == null ? 'Crear' : 'Crear otro',
                  filled: codigo == null,
                  onTap: onCodigo,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divisor),
          TcTap(
            onTap: onDesconectar,
            radius: 0,
            minHeight: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Desconectar Google Drive', style: AppText.bold(16, color: AppColors.rojo)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  static const _puntos = [
    (AppIcons.celular, 'Tus documentos siguen viviendo en tu celular.'),
    (AppIcons.candado, 'La copia va cifrada: Google la guarda, pero no la puede abrir.'),
    (
      AppIcons.escudo,
      'La llave de la copia se protege con el bloqueo de pantalla de tu celular. No hay contraseñas que recordar.',
    ),
    (
      AppIcons.nube,
      'Si estrenas celular, restaura tu cuenta de Google, instala Tu Cajón y elige “Recuperar mi cajón”.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: AppDecor.tarjeta(),
      child: Column(
        children: [
          for (final (icono, texto) in _puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TcIcon(icono, size: 22, color: AppColors.primario),
                  const SizedBox(width: 12),
                  Expanded(child: Text(texto, style: AppText.body(15, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
