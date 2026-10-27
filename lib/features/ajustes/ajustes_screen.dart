import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decor.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tema_del_celular.dart';
import '../../data/copia/copia_de_seguridad.dart';
import '../../data/copia/frecuencia_copia.dart';
import '../../data/copia/nube.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/interruptor.dart';
import '../../shared/widgets/tc_icon.dart';
import '../../shared/widgets/tc_tap.dart';
import '../../shared/widgets/toast.dart';

/// Ajustes: cómo se ve la app (de día o de noche) y la copia de seguridad en
/// Google Drive.
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

  late final CopiaDeSeguridad _copia = context.copia;

  @override
  void initState() {
    super.initState();
    // Pudo hacerse una copia programada con la app en segundo plano.
    _copia.recargar();
  }

  Future<void> _conectar() async {
    setState(() => _conectando = true);
    try {
      final encontrada = await _copia.conectar();
      if (encontrada != null) {
        await _yaHayCopia(encontrada);
        return;
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

  /// La cuenta ya tenía una copia con cosas que este celular no tiene (se
  /// borraron los datos de la app, o es de otro celular). Nada se toca hasta
  /// elegir: restaurarla, borrarla (con otra confirmación) o dejarla así.
  Future<void> _yaHayCopia(CopiaEncontrada encontrada) async {
    final indice = encontrada.indice;
    final fecha = 'Copia del ${Formato.fechaLarga(encontrada.fecha)}';
    final cual = indice == null
        ? '$fecha · ${Formato.tamano(encontrada.bytes)}'
        : '$fecha\n${resumenDe(indice.contenido)}';
    final texto = indice != null
        ? 'Tiene cosas que este celular no tiene. Al restaurarla vuelven a tu cajón, y lo que ya tienes '
              'aquí se queda.'
        : encontrada.conCodigo
        ? 'Para abrirla en este celular te pediremos el código de emergencia que anotaste. Lo que ya '
              'tienes aquí se queda.'
        : 'Es de antes de que la llave se guardara en tu Drive: su llave no está ni en Drive ni en este '
              'celular, y no tiene código de emergencia, así que nadie la puede abrir. Puedes borrarla y '
              'empezar una copia nueva.';
    while (true) {
      if (!mounted) return;
      final eleccion = await preguntarPorLaCopia(
        context,
        cual: cual,
        texto: texto,
        sePuedeRestaurar: encontrada.abierta || encontrada.conCodigo,
      );
      if (!mounted) return;
      switch (eleccion) {
        case ConLaCopia.restaurar:
          await Navigator.of(context).pushNamed(AppRoutes.recuperar, arguments: encontrada);
          // Volvió sin traerla: la copia sigue como estaba.
          if (!_copia.estado.value.conectada) await _copia.desconectar();
          return;
        case ConLaCopia.borrar:
          final seguro = await confirmar(
            context,
            titulo: '¿Borrar tu copia de Drive?',
            texto:
                'La copia del ${Formato.fechaLarga(encontrada.fecha)}'
                '${indice == null ? '' : ', con ${resumenDe(indice.contenido)},'} se borra para siempre y '
                'no se puede recuperar. Desde ahora la copia será la de este celular.',
            accion: 'Borrar la copia',
            cancelar: 'No, volver',
          );
          if (!seguro) continue;
          await _copia.reemplazarCopia();
          unawaited(_copia.hacerCopia());
          return;
        case null:
          await _copia.desconectar();
          if (mounted) showToast('Tu copia sigue en Drive, sin cambios.');
          return;
      }
    }
  }

  /// Cada cuánto: cuenta desde ahora (la primera copia es ya mismo).
  Future<void> _cambiarFrecuencia(FrecuenciaCopia frecuencia) async {
    if (frecuencia == _copia.estado.value.frecuencia) return;
    await _copia.cambiarFrecuencia(frecuencia);
    if (!mounted) return;
    final proxima = _copia.estado.value.proxima(DateTime.now());
    showToast(
      proxima == null
          ? 'Listo: la copia se hace solo cuando la pidas.'
          : '${frecuencia.etiqueta}, desde ahora. La próxima: ${_cuandoSera(proxima, DateTime.now())}',
    );
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
                          Semantics(header: true, child: Text('Apariencia', style: AppText.bold(18))),
                          const SizedBox(height: 12),
                          const _TarjetaApariencia(),
                          const SizedBox(height: 28),
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
                              onFrecuencia: _cambiarFrecuencia,
                              onSoloWifi: () => _copia.cambiarSoloWifi(!e.soloWifi),
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

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String _hora(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  // Espacios que no se cortan: "p. m." no queda partido entre dos renglones.
  return '$h:${f.minute.toString().padLeft(2, '0')}\u00A0${f.hour < 12 ? 'a.\u00A0m.' : 'p.\u00A0m.'}';
}

/// "hoy a las 8:30 p. m." · "mañana a las…" · "el martes 3 de noviembre a las…".
String _cuandoSera(DateTime f, DateTime ahora) {
  if (!f.isAfter(ahora.add(const Duration(minutes: 1)))) return 'ahora mismo';
  final dias = Formato.diasEntre(ahora, f);
  final dia = switch (dias) {
    0 => 'hoy',
    1 => 'mañana',
    _ => 'el ${_diasSemana[f.weekday - 1]} ${Formato.diaMes(f)}',
  };
  return '$dia a las ${_hora(f)}';
}

/// "hoy, 3:45 p. m." · "ayer, 9:10 a. m." · "12 de septiembre".
String _cuando(DateTime f, DateTime ahora) {
  final hora = _hora(f);
  final dias = Formato.diasEntre(f, ahora);
  if (dias == 0) return 'hoy, $hora';
  if (dias == 1) return 'ayer, $hora';
  return f.year == ahora.year ? Formato.diaMes(f) : Formato.fechaLarga(f);
}

/// De día, de noche o igual que el celular. Se aplica en el momento.
class _TarjetaApariencia extends StatelessWidget {
  const _TarjetaApariencia();

  static const _iconos = {
    Apariencia.celular: AppIcons.celular,
    Apariencia.clara: AppIcons.sol,
    Apariencia.oscura: AppIcons.luna,
  };

  @override
  Widget build(BuildContext context) {
    final scope = AparienciaScope.of(context);
    return Container(
      decoration: AppDecor.tarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in Apariencia.values) ...[
            if (a.index > 0) Divider(height: 1, color: AppColors.divisor),
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: a == scope.apariencia,
              label: '${a.etiqueta}. ${a.explicacion}',
              excludeSemantics: true,
              child: TcTap(
                onTap: () => scope.cambiar(a),
                radius: 0,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  spacing: 14,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: TcIcon(_iconos[a]!, size: 21, color: AppColors.primario),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(a.etiqueta, style: AppText.bold(16)),
                          Text(a.explicacion, style: AppText.secondary(14, height: 1.35)),
                        ],
                      ),
                    ),
                    _Elegida(elegida: a == scope.apariencia),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El circulito de la opción: relleno con un visto si está elegida.
class _Elegida extends StatelessWidget {
  const _Elegida({required this.elegida});

  final bool elegida;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: elegida ? AppColors.primario : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: elegida ? AppColors.primario : AppColors.bordeInput, width: 2),
      ),
      alignment: Alignment.center,
      child: elegida
          ? TcIcon(AppIcons.check, size: 16, color: AppColors.sobrePrimario, strokeWidth: 2.6)
          : null,
    );
  }
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
                child: TcIcon(AppIcons.nube, size: 26, color: AppColors.primario),
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
            'Guarda una copia cifrada de tu cajón en tu Google Drive. Se hace sola cada día, semana o mes '
                '(tú eliges). Si ya tenías una, al conectar podrás restaurarla.',
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
      return _Linea(
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
    required this.onFrecuencia,
    required this.onSoloWifi,
    required this.onDesconectar,
  });

  final ValueChanged<FrecuenciaCopia> onFrecuencia;
  final EstadoCopia estado;
  final VoidCallback onSoloWifi;
  final VoidCallback onDesconectar;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final proxima = estado.proxima(ahora);
    final desde = estado.desde;
    final cuenta = switch (estado.frecuencia) {
      FrecuenciaCopia.manual => 'Solo cuando toques «Hacer copia ahora».',
      _ when proxima == null => 'Se hace sola a la hora en que la elegiste.',
      _ when estado.esperandoWifi => 'Toca ahora: se hace apenas haya Wi-Fi.',
      _ =>
        'Próxima copia: ${_cuandoSera(proxima, ahora)}'
            '${desde == null ? '' : '\nCuenta desde el ${Formato.diaMes(desde)} a las ${_hora(desde)}'}',
    };
    return Container(
      decoration: AppDecor.tarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text('Cada cuánto se hace', style: AppText.bold(16)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in FrecuenciaCopia.values)
                      _OpcionFrecuencia(
                        etiqueta: f.etiqueta,
                        elegida: f == estado.frecuencia,
                        onTap: () => onFrecuencia(f),
                      ),
                  ],
                ),
                Semantics(liveRegion: true, child: Text(cuenta, style: AppText.secondary(14, height: 1.4))),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divisor),
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
          Divider(height: 1, color: AppColors.divisor),
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

/// Una de las opciones de "Cada cuánto se hace" (dentro de la tarjeta, así
/// que la que no está elegida lleva el color del fondo).
class _OpcionFrecuencia extends StatelessWidget {
  const _OpcionFrecuencia({required this.etiqueta, required this.elegida, required this.onTap});

  final String etiqueta;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TcTap(
      onTap: onTap,
      selected: elegida,
      color: elegida ? AppColors.primario : AppColors.fondo,
      radius: 22,
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        widthFactor: 1,
        child: Text(
          etiqueta,
          style: AppText.bold(14, color: elegida ? AppColors.sobrePrimario : AppColors.texto),
        ),
      ),
    );
  }
}

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  static const _puntos = [
    (AppIcons.celular, 'Tus documentos siguen viviendo en tu celular.'),
    (
      AppIcons.candado,
      'La copia va cifrada, en una carpeta privada de tu Drive: no se ve en Drive y otras apps no la '
          'pueden abrir.',
    ),
    (
      AppIcons.escudo,
      'No hay contraseñas ni códigos que recordar: tu copia se abre con tu cuenta de Google.',
    ),
    (
      AppIcons.nube,
      'Si estrenas celular o borras los datos de la app, conecta otra vez Google Drive y restaura tu copia.',
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
