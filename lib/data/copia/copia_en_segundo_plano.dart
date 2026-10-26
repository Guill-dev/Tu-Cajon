import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/copia/cuenta_google.dart';
import '../../core/copia/llaves_de_copia.dart';
import '../../core/copia/red.dart';
import '../db/conexion.dart';
import '../repositorio/cajon_repositorio.dart';
import 'agenda_de_copias.dart';
import 'copia_de_seguridad.dart';
import 'nube_drive.dart';

/// Con qué nombre se reconocen en WorkManager las copias programadas.
const _etiqueta = 'tu_cajon.copia';
const _tarea = 'hacer_copia';

/// La agenda de Android (WorkManager): despierta a la app a la hora de la
/// copia aunque esté cerrada, y también después de reiniciar el celular. Si
/// la copia es "Solo con Wi-Fi", Android espera a tener Wi-Fi; si no, a
/// tener internet. Android puede correrla unos minutos después, para cuidar
/// la batería.
class AgendaDelSistema implements AgendaDeCopias {
  /// [enSegundoPlano]: la que usa la copia que Android despertó. Programa la
  /// siguiente sin cancelarse a sí misma, y no programa otra "para ya" (si
  /// algo falla, Android la reintenta solo).
  AgendaDelSistema({this.enSegundoPlano = false});

  final bool enSegundoPlano;

  @override
  Future<void> programar(DateTime cuando, {required bool soloWifi}) async {
    final ahora = DateTime.now();
    if (enSegundoPlano && cuando.difference(ahora) < const Duration(minutes: 1)) return;
    if (!enSegundoPlano) await Workmanager().cancelByTag(_etiqueta);
    final espera = cuando.isAfter(ahora) ? cuando.difference(ahora) : Duration.zero;
    await Workmanager().registerOneOffTask(
      // Un nombre por hora: la que está corriendo no se reemplaza a sí misma.
      'copia-${cuando.millisecondsSinceEpoch}',
      _tarea,
      tag: _etiqueta,
      initialDelay: espera,
      constraints: Constraints(networkType: soloWifi ? NetworkType.unmetered : NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  @override
  Future<void> cancelar() => Workmanager().cancelByTag(_etiqueta);
}

/// Se prepara al abrir la app (en `main`).
Future<void> prepararCopiasEnSegundoPlano() => Workmanager().initialize(copiaEnSegundoPlano);

/// Lo que corre cuando Android despierta a la app para la copia: abre el
/// cajón, la hace si le toca (con la app cerrada no hay huella: la copia sale
/// cifrada igual) y deja programada la siguiente.
@pragma('vm:entry-point')
void copiaEnSegundoPlano() {
  Workmanager().executeTask((tarea, datos) async {
    DartPluginRegistrant.ensureInitialized();
    if (clienteWebDeGoogle.isEmpty) return true;
    CajonRepositorio? repo;
    try {
      repo = await abrirRepositorio();
      final copia = CopiaDeSeguridad(
        repo: repo,
        nube: NubeDrive(cuenta: CuentaGoogleDelSistema(clienteWeb: clienteWebDeGoogle)),
        llaves: LlavesDeCopia.paraEstaPlataforma(),
        // Android ya esperó el Wi-Fi si hacía falta.
        red: RedSimulada(),
        agenda: AgendaDelSistema(enSegundoPlano: true),
      );
      await copia.listo;
      if (!copia.estado.value.tocaCopia(DateTime.now())) return true;
      await copia.hacerCopia(automatica: true);
      // Si no se pudo (sin internet, Drive lleno…), ya quedó programado otro
      // intento en media hora.
      final problema = copia.estado.value.problema;
      if (problema != null) debugPrint('La copia programada no se pudo hacer: $problema');
      return true;
    } catch (e) {
      // Ni siquiera se pudo abrir el cajón: Android lo vuelve a intentar más tarde.
      debugPrint('La copia programada falló: $e');
      return false;
    } finally {
      await repo?.cerrar();
    }
  });
}
