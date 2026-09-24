import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/copia/llaves_de_copia.dart';
import '../../core/copia/red.dart';
import '../models/contenido_cajon.dart';
import '../models/documento.dart';
import '../repositorio/cajon_repositorio.dart';
import 'cifrado_copia.dart';
import 'indice_copia.dart';
import 'nube.dart';

/// Cómo va la copia de seguridad (lo muestra Ajustes).
@immutable
class EstadoCopia {
  const EstadoCopia({
    this.cuenta,
    this.ultima,
    this.documentos = 0,
    this.bytes = 0,
    this.haciendo = false,
    this.hechos = 0,
    this.total = 0,
    this.problema,
    this.esperandoWifi = false,
    this.soloWifi = true,
    this.codigoCreado,
  });

  /// La cuenta conectada; `null` = sin conectar.
  final String? cuenta;

  /// Cuándo terminó la última copia, y qué tenía.
  final DateTime? ultima;
  final int documentos;
  final int bytes;

  /// Si se está haciendo ahora: documentos revisados de [total].
  final bool haciendo;
  final int hechos;
  final int total;

  /// Mensaje de lo que salió mal la última vez.
  final String? problema;

  /// La copia automática espera a que haya Wi-Fi.
  final bool esperandoWifi;
  final bool soloWifi;

  /// Cuándo se creó el código de emergencia; `null` = no hay.
  final DateTime? codigoCreado;

  bool get conectada => cuenta != null;

  EstadoCopia copyWith({
    String? cuenta,
    bool quitarCuenta = false,
    DateTime? ultima,
    bool quitarUltima = false,
    int? documentos,
    int? bytes,
    bool? haciendo,
    int? hechos,
    int? total,
    String? problema,
    bool quitarProblema = false,
    bool? esperandoWifi,
    bool? soloWifi,
    DateTime? codigoCreado,
  }) => EstadoCopia(
    cuenta: quitarCuenta ? null : (cuenta ?? this.cuenta),
    ultima: quitarUltima ? null : (ultima ?? this.ultima),
    documentos: documentos ?? this.documentos,
    bytes: bytes ?? this.bytes,
    haciendo: haciendo ?? this.haciendo,
    hechos: hechos ?? this.hechos,
    total: total ?? this.total,
    problema: quitarProblema ? null : (problema ?? this.problema),
    esperandoWifi: esperandoWifi ?? this.esperandoWifi,
    soloWifi: soloWifi ?? this.soloWifi,
    codigoCreado: codigoCreado ?? this.codigoCreado,
  );
}

/// Una copia encontrada en la nube al estrenar celular.
class CopiaEncontrada {
  const CopiaEncontrada({required this.fecha, required this.bytes, required this.conCodigo, this.indice});

  final DateTime fecha;
  final int bytes;

  /// Si la copia tiene código de emergencia.
  final bool conCodigo;

  /// Lo que tiene; `null` mientras no haya llave (falta el código).
  final IndiceCopia? indice;

  bool get abierta => indice != null;

  CopiaEncontrada conIndice(IndiceCopia indice) =>
      CopiaEncontrada(fecha: fecha, bytes: bytes, conCodigo: conCodigo, indice: indice);
}

/// La copia de seguridad del cajón en la nube (Google Drive).
///
/// Qué sube, todo cifrado con la llave de la copia (ver [CifradoCopia]):
/// - `tucajon-indice.bin`: los datos (perfiles, documentos, fechas…).
/// - `tucajon-doc-<id>-<versión>.bin`: los archivos de cada documento. Solo
///   se sube lo nuevo: si un documento no cambió, su archivo ya está allá.
/// - `tucajon-emergencia.bin`: la llave protegida con el código de
///   emergencia (si se creó uno).
///
/// El orden cuida que la copia de la nube siempre esté completa: primero
/// los archivos nuevos, después el índice y al final se borra lo que ya no
/// se usa.
class CopiaDeSeguridad {
  CopiaDeSeguridad({
    required this.repo,
    required this.nube,
    required this.llaves,
    required this.red,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  /// Para pruebas y la vista web: todo en memoria.
  factory CopiaDeSeguridad.simulada(CajonRepositorio repo) =>
      CopiaDeSeguridad(repo: repo, nube: NubeEnMemoria(), llaves: LlavesSimuladas(), red: RedSimulada());

  final CajonRepositorio repo;
  final Nube nube;
  final LlavesDeCopia llaves;
  final Red red;
  final DateTime Function() _reloj;

  final estado = ValueNotifier(const EstadoCopia());

  // Nombres en la nube.
  static const archivoIndice = 'tucajon-indice.bin';
  static const archivoEmergencia = 'tucajon-emergencia.bin';
  static const _prefijoDocumento = 'tucajon-doc-';
  static const _prefijo = 'tucajon-';

  /// Cambia cuando cambian los archivos del documento (al editar sus páginas
  /// o reemplazarlo, `guardadoEn` pasa a ser hoy).
  static String archivoDe(Documento d) =>
      '$_prefijoDocumento${d.id}-${d.guardadoEn.millisecondsSinceEpoch}.bin';

  // Lo que se recuerda en la base (tabla de ajustes).
  static const _aCuenta = 'copia.cuenta';
  static const _aUltima = 'copia.ultima';
  static const _aDocumentos = 'copia.documentos';
  static const _aBytes = 'copia.bytes';
  static const _aSoloWifi = 'copia.solo_wifi';
  static const _aCodigo = 'copia.codigo';
  static const _aHuella = 'copia.huella';

  late final Future<void> listo = _cargar();

  Future<void> _cargar() async {
    DateTime? fecha(String? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    estado.value = EstadoCopia(
      cuenta: await repo.leerAjuste(_aCuenta),
      ultima: fecha(await repo.leerAjuste(_aUltima)),
      documentos: int.tryParse(await repo.leerAjuste(_aDocumentos) ?? '') ?? 0,
      bytes: int.tryParse(await repo.leerAjuste(_aBytes) ?? '') ?? 0,
      soloWifi: await repo.leerAjuste(_aSoloWifi) != 'no',
      codigoCreado: fecha(await repo.leerAjuste(_aCodigo)),
    );
  }

  void _poner(EstadoCopia nuevo) => estado.value = nuevo;

  Future<void> _guardarCuenta(String cuenta) async {
    await repo.guardarAjuste(_aCuenta, cuenta);
    _poner(estado.value.copyWith(cuenta: cuenta, quitarProblema: true));
  }

  Future<Uint8List> _llaveOCrear() async {
    final existente = await llaves.leer();
    if (existente != null) return existente;
    final nueva = CifradoCopia.nuevaLlave();
    await llaves.guardar(nueva);
    return nueva;
  }

  Future<IndiceCopia> _leerIndice(Uint8List llave) async => IndiceCopia.deBytes(
    await CifradoCopia.descifrar(await nube.bajar(archivoIndice), llave, nombre: archivoIndice),
  );

  // ── Conectar ───────────────────────────────────────────────────────────

  /// Conecta la cuenta. Devuelve `false` si en esa cuenta ya hay una copia
  /// que este celular no puede abrir (de otro celular): para seguir hay que
  /// llamar a [reemplazarCopiaAjena], o a [desconectar] para dejarla así.
  Future<bool> conectar() async {
    await listo;
    final cuenta = await nube.conectar();
    final hayCopia = (await nube.listar()).any((a) => a.nombre == archivoIndice);
    if (hayCopia) {
      final llave = await llaves.leer();
      var abre = false;
      if (llave != null) {
        try {
          await _leerIndice(llave);
          abre = true;
        } on LlaveEquivocada {
          abre = false;
        } on CopiaIlegible {
          abre = false;
        }
      }
      if (!abre) {
        _cuentaPendiente = cuenta;
        return false;
      }
    }
    await _guardarCuenta(cuenta);
    await _llaveOCrear();
    return true;
  }

  String? _cuentaPendiente;

  /// Borra la copia que había en la cuenta y empieza una nueva, de este celular.
  Future<void> reemplazarCopiaAjena() async {
    final cuenta = _cuentaPendiente;
    if (cuenta == null) throw StateError('No hay ninguna cuenta esperando');
    for (final a in await nube.listar()) {
      if (a.nombre.startsWith(_prefijo)) await nube.borrar(a.nombre);
    }
    await llaves.guardar(CifradoCopia.nuevaLlave());
    await repo.guardarAjuste(_aCodigo, null);
    await repo.guardarAjuste(_aHuella, null);
    _cuentaPendiente = null;
    await _guardarCuenta(cuenta);
  }

  /// Desconecta la cuenta. La copia se queda en la nube.
  Future<void> desconectar() async {
    await nube.desconectar();
    _cuentaPendiente = null;
    for (final clave in [_aCuenta, _aUltima, _aDocumentos, _aBytes, _aHuella]) {
      await repo.guardarAjuste(clave, null);
    }
    _poner(EstadoCopia(soloWifi: estado.value.soloWifi, codigoCreado: estado.value.codigoCreado));
  }

  Future<void> cambiarSoloWifi(bool soloWifi) async {
    await repo.guardarAjuste(_aSoloWifi, soloWifi ? null : 'no');
    _poner(estado.value.copyWith(soloWifi: soloWifi, esperandoWifi: soloWifi && estado.value.esperandoWifi));
  }

  // ── Hacer la copia ─────────────────────────────────────────────────────

  Future<void>? _enCurso;

  /// Hace la copia. La [automatica] (la que se hace sola) respeta "Solo con
  /// Wi-Fi"; la que pide la persona se hace de una vez.
  Future<void> hacerCopia({bool automatica = false}) =>
      _enCurso ??= _copiar(automatica).whenComplete(() => _enCurso = null);

  Future<void> _copiar(bool automatica) async {
    await listo;
    if (!estado.value.conectada) return;
    if (automatica && estado.value.soloWifi && !await red.sinLimiteDeDatos()) {
      _poner(estado.value.copyWith(esperandoWifi: true));
      return;
    }
    _poner(
      estado.value.copyWith(haciendo: true, hechos: 0, total: 0, esperandoWifi: false, quitarProblema: true),
    );
    try {
      final llave = await _llaveOCrear();
      final contenido = await repo.leerContenido();
      final enNube = {for (final a in await nube.listar()) a.nombre: a};

      // 1. Los archivos de cada documento: solo los que no estén ya.
      final conArchivos = contenido.documentos.where((d) => d.archivo != null).toList();
      _poner(estado.value.copyWith(total: conArchivos.length));
      final archivos = <String, String>{};
      var bytes = 0;
      for (final (i, d) in conArchivos.indexed) {
        final nombre = archivoDe(d);
        final ya = enNube[nombre];
        if (ya != null) {
          archivos[d.id] = nombre;
          bytes += ya.bytes;
        } else {
          final paginas = await repo.leerPaginas(d);
          final pdf = paginas.isEmpty ? await repo.leerPdf(d) : null;
          if (paginas.isNotEmpty || pdf != null) {
            final datos = await CifradoCopia.cifrar(
              CifradoCopia.empaquetar((paginas: paginas, pdf: pdf)),
              llave,
              nombre: nombre,
            );
            await nube.subir(nombre, datos);
            archivos[d.id] = nombre;
            bytes += datos.length;
          }
        }
        _poner(estado.value.copyWith(hechos: i + 1));
      }

      // 2. El índice, si cambió desde la última vez.
      final indice = IndiceCopia.de(contenido, archivos).aBytes();
      final huella = await CifradoCopia.huella(indice);
      final indiceEnNube = enNube[archivoIndice];
      if (indiceEnNube == null || huella != await repo.leerAjuste(_aHuella)) {
        final cifrado = await CifradoCopia.cifrar(indice, llave, nombre: archivoIndice);
        await nube.subir(archivoIndice, cifrado);
        await repo.guardarAjuste(_aHuella, huella);
        bytes += cifrado.length;
      } else {
        bytes += indiceEnNube.bytes;
      }

      // 3. Lo que ya no se usa: documentos borrados o con páginas cambiadas.
      final usados = archivos.values.toSet();
      for (final nombre in enNube.keys) {
        if (nombre.startsWith(_prefijoDocumento) && !usados.contains(nombre)) await nube.borrar(nombre);
      }

      // Se guarda en milisegundos: así queda igual al volver a leerla.
      final ahora = DateTime.fromMillisecondsSinceEpoch(_reloj().millisecondsSinceEpoch);
      await repo.guardarAjuste(_aUltima, '${ahora.millisecondsSinceEpoch}');
      await repo.guardarAjuste(_aDocumentos, '${contenido.documentos.length}');
      await repo.guardarAjuste(_aBytes, '$bytes');
      _poner(
        estado.value.copyWith(
          haciendo: false,
          ultima: ahora,
          documentos: contenido.documentos.length,
          bytes: bytes,
        ),
      );
    } on ProblemaNube catch (e) {
      _poner(estado.value.copyWith(haciendo: false, problema: e.mensaje));
      if (e is PermisoPerdido) {
        await repo.guardarAjuste(_aCuenta, null);
        _poner(estado.value.copyWith(quitarCuenta: true));
      }
    } catch (e, pila) {
      debugPrint('No se pudo hacer la copia: $e\n$pila');
      _poner(
        estado.value.copyWith(
          haciendo: false,
          problema: 'No se pudo hacer la copia. Se intentará de nuevo más tarde.',
        ),
      );
    }
  }

  // ── Código de emergencia ───────────────────────────────────────────────

  /// Si la llave llega sola a otro celular (bloqueo de pantalla + Block Store).
  Future<bool> llaveProtegidaConBloqueo() => llaves.protegidaConBloqueo();

  /// Crea un código de emergencia nuevo (el anterior deja de servir) y sube la
  /// llave protegida con él. Devuelve el código para mostrarlo una sola vez.
  Future<String> crearCodigoDeEmergencia() async {
    await listo;
    if (!estado.value.conectada) throw StateError('Primero hay que conectar la cuenta');
    final codigo = CifradoCopia.nuevoCodigo();
    await nube.subir(archivoEmergencia, await CifradoCopia.envolverLlave(await _llaveOCrear(), codigo));
    final ahora = DateTime.fromMillisecondsSinceEpoch(_reloj().millisecondsSinceEpoch);
    await repo.guardarAjuste(_aCodigo, '${ahora.millisecondsSinceEpoch}');
    _poner(estado.value.copyWith(codigoCreado: ahora));
    return codigo;
  }

  // ── Recuperar (al estrenar celular) ────────────────────────────────────

  String? _cuentaRecuperada;
  Uint8List? _llaveRecuperada;

  /// Conecta la cuenta y busca una copia; `null` si no hay. Si la llave llegó
  /// a este celular, la copia viene ya abierta; si no, hace falta
  /// [abrirConCodigo].
  Future<CopiaEncontrada?> buscarCopia() async {
    await listo;
    final cuenta = await nube.conectar();
    final lista = await nube.listar();
    final indice = lista.where((a) => a.nombre == archivoIndice).firstOrNull;
    if (indice == null) {
      await nube.desconectar();
      return null;
    }
    _cuentaRecuperada = cuenta;
    final copia = CopiaEncontrada(
      fecha: indice.modificado,
      bytes: lista.where((a) => a.nombre.startsWith(_prefijo)).fold(0, (s, a) => s + a.bytes),
      conCodigo: lista.any((a) => a.nombre == archivoEmergencia),
    );
    final llave = await llaves.leer();
    if (llave == null) return copia;
    try {
      final leido = await _leerIndice(llave);
      _llaveRecuperada = llave;
      return copia.conIndice(leido);
    } on LlaveEquivocada {
      return copia;
    }
  }

  /// Abre la copia con el código de emergencia. Lanza [CodigoEquivocado] si
  /// no es el código de esta copia.
  Future<CopiaEncontrada> abrirConCodigo(CopiaEncontrada copia, String escrito) async {
    final codigo = CifradoCopia.normalizarCodigo(escrito);
    if (codigo == null) throw const CodigoEquivocado();
    final llave = await CifradoCopia.desenvolverLlave(await nube.bajar(archivoEmergencia), codigo);
    final leido = await _leerIndice(llave);
    _llaveRecuperada = llave;
    return copia.conIndice(leido);
  }

  /// Trae la copia a este celular: cambia todo el cajón por el de la copia.
  /// [progreso]: documentos listos de cuántos.
  Future<void> recuperar(CopiaEncontrada copia, {void Function(int hechos, int total)? progreso}) async {
    final indice = copia.indice;
    final llave = _llaveRecuperada;
    final cuenta = _cuentaRecuperada;
    if (indice == null || llave == null || cuenta == null) {
      throw StateError('La copia todavía no está abierta');
    }
    final total = indice.contenido.documentos.where((d) => d.archivo != null).length;
    var hechos = 0;
    progreso?.call(0, total);
    await repo.restaurar(
      indice.contenido,
      archivosDe: (d) async {
        final nombre = d.archivo!;
        final datos = await CifradoCopia.descifrar(await nube.bajar(nombre), llave, nombre: nombre);
        progreso?.call(++hechos, total);
        return CifradoCopia.desempaquetar(datos);
      },
    );
    // Desde ya, este celular sigue la misma copia.
    await llaves.guardar(llave);
    await repo.guardarAjuste(_aUltima, '${copia.fecha.millisecondsSinceEpoch}');
    await repo.guardarAjuste(_aDocumentos, '${indice.documentos}');
    await repo.guardarAjuste(_aBytes, '${copia.bytes}');
    if (copia.conCodigo) await repo.guardarAjuste(_aCodigo, '${copia.fecha.millisecondsSinceEpoch}');
    await _guardarCuenta(cuenta);
    _poner(
      estado.value.copyWith(
        ultima: copia.fecha,
        documentos: indice.documentos,
        bytes: copia.bytes,
        codigoCreado: copia.conCodigo ? copia.fecha : null,
      ),
    );
  }
}

class CopiaScope extends InheritedWidget {
  const CopiaScope({super.key, required this.copia, required super.child});

  final CopiaDeSeguridad copia;

  @override
  bool updateShouldNotify(CopiaScope oldWidget) => copia != oldWidget.copia;
}

extension CopiaContexto on BuildContext {
  CopiaDeSeguridad get copia {
    final scope = getInheritedWidgetOfExactType<CopiaScope>();
    assert(scope != null, 'Falta CopiaScope arriba en el árbol de widgets.');
    return scope!.copia;
  }
}

/// Resumen de una copia: "14 documentos · 2 perfiles".
String resumenDe(ContenidoCajon c) {
  final d = c.documentos.length;
  final p = c.perfiles.length;
  return '${d == 1 ? '1 documento' : '$d documentos'} · ${p == 1 ? '1 perfil' : '$p perfiles'}';
}
