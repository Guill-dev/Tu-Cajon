import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/copia/llaves_de_copia.dart';
import '../../core/copia/red.dart';
import '../models/contenido_cajon.dart';
import '../models/documento.dart';
import '../repositorio/cajon_repositorio.dart';
import 'agenda_de_copias.dart';
import 'cifrado_copia.dart';
import 'frecuencia_copia.dart';
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
    this.frecuencia = FrecuenciaCopia.diaria,
    this.desde,
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

  /// Cada cuánto se hace sola, contando desde [desde] (cuando se eligió).
  final FrecuenciaCopia frecuencia;
  final DateTime? desde;

  bool get conectada => cuenta != null;

  /// Si ya le tocó una copia programada que todavía no se hizo (a esa hora
  /// el celular estaba apagado, sin internet o esperando el Wi-Fi).
  bool tocaCopia(DateTime ahora) {
    final d = desde;
    if (!conectada || d == null) return false;
    final debida = frecuencia.ultimaVez(d, ahora);
    final u = ultima;
    return debida != null && (u == null || u.isBefore(debida));
  }

  /// Cuándo se hará la próxima copia sola (`null`: a mano o sin conectar).
  /// Si ya le tocó una, es [ahora].
  DateTime? proxima(DateTime ahora) {
    final d = desde;
    if (!conectada || d == null || frecuencia == FrecuenciaCopia.manual) return null;
    if (tocaCopia(ahora)) return ahora;
    return frecuencia.siguienteVez(d, ahora);
  }

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
    FrecuenciaCopia? frecuencia,
    DateTime? desde,
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
    frecuencia: frecuencia ?? this.frecuencia,
    desde: desde ?? this.desde,
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
/// - `tucajon-llave.bin`: la llave misma, sin cifrar. Así la copia se abre
///   con solo conectar la misma cuenta de Google, también después de borrar
///   los datos de la app o en un celular nuevo. Está en la carpeta privada
///   de la app en Drive: no se ve en Drive y otras apps no la pueden leer.
/// - `tucajon-indice.bin`: los datos (perfiles, documentos, fechas…).
/// - `tucajon-doc-<id>-<versión>.bin`: los archivos de cada documento. Solo
///   se sube lo nuevo: si un documento no cambió, su archivo ya está allá.
/// - `tucajon-emergencia.bin`: la llave protegida con el código de
///   emergencia (copias de antes, si se creó uno).
///
/// El orden cuida que la copia de la nube siempre esté completa: primero la
/// llave y los archivos nuevos, después el índice y al final se borra lo que
/// ya no se usa.
class CopiaDeSeguridad {
  CopiaDeSeguridad({
    required this.repo,
    required this.nube,
    required this.llaves,
    required this.red,
    AgendaDeCopias? agenda,
    DateTime Function()? reloj,
  }) : agenda = agenda ?? AgendaSimulada(),
       _reloj = reloj ?? DateTime.now;

  /// Para pruebas y la vista web: todo en memoria.
  factory CopiaDeSeguridad.simulada(CajonRepositorio repo) =>
      CopiaDeSeguridad(repo: repo, nube: NubeEnMemoria(), llaves: LlavesSimuladas(), red: RedSimulada());

  final CajonRepositorio repo;
  final Nube nube;
  final LlavesDeCopia llaves;
  final Red red;

  /// Despierta a la app a la hora de la próxima copia, aunque esté cerrada.
  final AgendaDeCopias agenda;
  final DateTime Function() _reloj;

  final estado = ValueNotifier(const EstadoCopia());

  // Nombres en la nube.
  static const archivoIndice = 'tucajon-indice.bin';
  static const archivoLlave = 'tucajon-llave.bin';
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
  static const _aFrecuencia = 'copia.frecuencia';
  static const _aDesde = 'copia.desde';

  late final Future<void> listo = _cargar();

  /// Ahora, en milisegundos (así queda igual al guardarlo y volver a leerlo).
  DateTime get _ahora => DateTime.fromMillisecondsSinceEpoch(_reloj().millisecondsSinceEpoch);

  Future<void> _cargar() async {
    // La copia se había probado dentro del celular y ahora va a Google Drive
    // de verdad: queda sin conectar, para conectar la cuenta de Google (y el
    // código de emergencia de la prueba no está en Drive: se crea otro).
    if (!nube.deprueba && await repo.leerAjuste(_aCuenta) == cuentaDePrueba) {
      for (final clave in [_aCuenta, _aUltima, _aDocumentos, _aBytes, _aHuella, _aCodigo]) {
        await repo.guardarAjuste(clave, null);
      }
    }
    await _leerEstado();
    // Conectada antes de que se pudiera elegir cada cuánto: cada día, desde
    // la última copia (o desde ahora).
    final e = estado.value;
    if (e.conectada && e.desde == null) await _guardarDesde(e.ultima ?? _ahora);
    nube.recordarCuenta(estado.value.cuenta);
    await _reprogramar();
  }

  Future<void> _leerEstado() async {
    DateTime? fecha(String? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    estado.value = EstadoCopia(
      cuenta: await repo.leerAjuste(_aCuenta),
      ultima: fecha(await repo.leerAjuste(_aUltima)),
      documentos: int.tryParse(await repo.leerAjuste(_aDocumentos) ?? '') ?? 0,
      bytes: int.tryParse(await repo.leerAjuste(_aBytes) ?? '') ?? 0,
      soloWifi: await repo.leerAjuste(_aSoloWifi) != 'no',
      codigoCreado: fecha(await repo.leerAjuste(_aCodigo)),
      frecuencia: FrecuenciaCopia.deTexto(await repo.leerAjuste(_aFrecuencia)),
      desde: fecha(await repo.leerAjuste(_aDesde)),
    );
  }

  /// Vuelve a leer cómo va (la copia programada pudo hacerse con la app en
  /// segundo plano).
  Future<void> recargar() async {
    await listo;
    if (estado.value.haciendo) return;
    final problema = estado.value.problema;
    await _leerEstado();
    if (problema != null) _poner(estado.value.copyWith(problema: problema));
  }

  Future<void> _guardarDesde(DateTime desde) async {
    await repo.guardarAjuste(_aDesde, '${desde.millisecondsSinceEpoch}');
    _poner(estado.value.copyWith(desde: desde));
  }

  /// Le pide a Android que despierte a la app para la próxima copia (o que
  /// no la despierte, si es a mano o no hay cuenta). Si la que tocaba falló,
  /// se vuelve a intentar en media hora.
  Future<void> _reprogramar({bool trasFallo = false}) async {
    final ahora = _ahora;
    final e = estado.value;
    var cuando = e.proxima(ahora);
    try {
      if (cuando == null) {
        await agenda.cancelar();
        return;
      }
      if (trasFallo && !cuando.isAfter(ahora)) cuando = ahora.add(const Duration(minutes: 30));
      await agenda.programar(cuando, soloWifi: e.soloWifi);
    } catch (error) {
      // Sin agenda (p. ej. en pruebas sin el plugin): la copia se hará al abrir la app.
      debugPrint('No se pudo programar la copia: $error');
    }
  }

  /// Si ya le tocó una copia programada, la hace (al abrir la app).
  Future<void> siToca() async {
    await listo;
    if (estado.value.tocaCopia(_ahora)) await hacerCopia(automatica: true);
  }

  /// Cada cuánto se hace sola. Cuenta desde ahora: la primera es ya mismo y
  /// las siguientes, a esta misma hora cada día, semana o mes.
  Future<void> cambiarFrecuencia(FrecuenciaCopia frecuencia) async {
    await listo;
    await repo.guardarAjuste(_aFrecuencia, frecuencia == FrecuenciaCopia.diaria ? null : frecuencia.name);
    _poner(estado.value.copyWith(frecuencia: frecuencia));
    await _guardarDesde(_ahora);
    if (frecuencia == FrecuenciaCopia.manual) {
      await _reprogramar();
    } else {
      await hacerCopia(automatica: true);
    }
  }

  void _poner(EstadoCopia nuevo) => estado.value = nuevo;

  Future<void> _guardarCuenta(String cuenta) async {
    await repo.guardarAjuste(_aCuenta, cuenta);
    _poner(estado.value.copyWith(cuenta: cuenta, quitarProblema: true));
    nube.recordarCuenta(cuenta);
    // Al conectar, cuenta desde ahora (cada día, si no se eligió otra cosa).
    await _guardarDesde(_ahora);
    await _reprogramar();
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

  /// Conecta la cuenta. Si en ella ya hay una copia con algo que este
  /// celular no tiene (se borraron los datos de la app, o es de otro
  /// celular), no la toca: la devuelve y la cuenta queda esperando a que la
  /// persona elija qué hacer con ella:
  /// - [recuperar] la trae (si no viene abierta, antes [abrirConCodigo]);
  /// - [reemplazarCopia] la borra y empieza la de este celular;
  /// - [desconectar] la deja como está.
  ///
  /// `null`: quedó conectada (no había copia, o era la de este celular).
  Future<CopiaEncontrada?> conectar() async {
    await listo;
    final cuenta = await nube.conectar();
    final copia = await _copiaEn(cuenta);
    if (copia != null && !(copia.abierta && await _todoEstaAqui(copia.indice!.contenido))) return copia;
    final llave = _llaveDeLaCopia;
    _olvidarCopia();
    await _guardarCuenta(cuenta);
    if (llave != null) {
      await llaves.guardar(llave);
    } else {
      await _llaveOCrear();
    }
    return null;
  }

  /// La cuenta y la llave de la copia encontrada que espera a que se elija
  /// qué hacer con ella (la llave, solo si la copia se pudo abrir).
  String? _cuentaDeLaCopia;
  Uint8List? _llaveDeLaCopia;

  void _olvidarCopia() {
    _cuentaDeLaCopia = null;
    _llaveDeLaCopia = null;
  }

  /// La copia que hay en la cuenta (abierta si su llave está en la nube o en
  /// este celular), o `null` si no hay.
  Future<CopiaEncontrada?> _copiaEn(String cuenta) async {
    final lista = await nube.listar();
    final indice = lista.where((a) => a.nombre == archivoIndice).firstOrNull;
    if (indice == null) return null;
    _cuentaDeLaCopia = cuenta;
    _llaveDeLaCopia = null;
    final copia = CopiaEncontrada(
      fecha: indice.modificado,
      bytes: lista.where((a) => a.nombre.startsWith(_prefijo)).fold(0, (s, a) => s + a.bytes),
      conCodigo: lista.any((a) => a.nombre == archivoEmergencia),
    );
    final candidatas = [
      if (lista.any((a) => a.nombre == archivoLlave)) await nube.bajar(archivoLlave),
      await llaves.leer(),
    ];
    for (final llave in candidatas.nonNulls) {
      if (llave.length != CifradoCopia.largoLlave) continue;
      try {
        final leido = await _leerIndice(llave);
        _llaveDeLaCopia = llave;
        return copia.conIndice(leido);
      } on LlaveEquivocada {
        // Se prueba con la siguiente.
      } on CopiaIlegible {
        // Se prueba con la siguiente.
      }
    }
    return copia;
  }

  /// Si todo lo de la copia ya está en este celular (es su propia copia):
  /// seguir con ella no pierde nada.
  Future<bool> _todoEstaAqui(ContenidoCajon deLaCopia) async {
    final aqui = await repo.leerContenido();
    final documentos = {for (final d in aqui.documentos) d.id};
    final perfiles = {for (final p in aqui.perfiles) p.id};
    return deLaCopia.documentos.every((d) => documentos.contains(d.id)) &&
        deLaCopia.perfiles.every((p) => perfiles.contains(p.id));
  }

  /// Borra la copia que había en la cuenta y empieza una nueva, la de este
  /// celular.
  Future<void> reemplazarCopia() async {
    final cuenta = _cuentaDeLaCopia;
    if (cuenta == null) throw StateError('No hay ninguna cuenta esperando');
    for (final a in await nube.listar()) {
      if (a.nombre.startsWith(_prefijo)) await nube.borrar(a.nombre);
    }
    await llaves.guardar(CifradoCopia.nuevaLlave());
    await repo.guardarAjuste(_aCodigo, null);
    await repo.guardarAjuste(_aHuella, null);
    _olvidarCopia();
    await _guardarCuenta(cuenta);
  }

  /// Desconecta la cuenta. La copia se queda en la nube.
  Future<void> desconectar() async {
    await nube.desconectar();
    _olvidarCopia();
    for (final clave in [_aCuenta, _aUltima, _aDocumentos, _aBytes, _aHuella, _aDesde]) {
      await repo.guardarAjuste(clave, null);
    }
    _poner(
      EstadoCopia(
        soloWifi: estado.value.soloWifi,
        codigoCreado: estado.value.codigoCreado,
        frecuencia: estado.value.frecuencia,
      ),
    );
    await _reprogramar();
  }

  Future<void> cambiarSoloWifi(bool soloWifi) async {
    await repo.guardarAjuste(_aSoloWifi, soloWifi ? null : 'no');
    _poner(estado.value.copyWith(soloWifi: soloWifi, esperandoWifi: soloWifi && estado.value.esperandoWifi));
    await _reprogramar();
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
      // Android la hace apenas haya Wi-Fi.
      _poner(estado.value.copyWith(esperandoWifi: true));
      await _reprogramar();
      return;
    }
    try {
      await _subir();
    } finally {
      await _reprogramar(trasFallo: estado.value.problema != null);
    }
  }

  Future<void> _subir() async {
    _poner(
      estado.value.copyWith(haciendo: true, hechos: 0, total: 0, esperandoWifi: false, quitarProblema: true),
    );
    try {
      final llave = await _llaveOCrear();
      final contenido = await repo.leerContenido();
      final enNube = {for (final a in await nube.listar()) a.nombre: a};

      // 0. La llave, para abrir la copia con solo la cuenta de Google (las
      //    copias de antes no la tenían).
      if (enNube[archivoLlave] == null || !listEquals(await nube.bajar(archivoLlave), llave)) {
        await nube.subir(archivoLlave, llave);
      }

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

  // ── Recuperar (al estrenar celular o tras borrar los datos) ────────────

  /// Conecta la cuenta y busca una copia; `null` si no hay. Si la llave está
  /// en este celular (o llegó sola), la copia viene ya abierta; si no, hace
  /// falta [abrirConCodigo].
  Future<CopiaEncontrada?> buscarCopia() async {
    await listo;
    final copia = await _copiaEn(await nube.conectar());
    if (copia == null) await nube.desconectar();
    return copia;
  }

  /// Abre la copia con el código de emergencia. Lanza [CodigoEquivocado] si
  /// no es el código de esta copia.
  Future<CopiaEncontrada> abrirConCodigo(CopiaEncontrada copia, String escrito) async {
    final codigo = CifradoCopia.normalizarCodigo(escrito);
    if (codigo == null) throw const CodigoEquivocado();
    final llave = await CifradoCopia.desenvolverLlave(await nube.bajar(archivoEmergencia), codigo);
    final leido = await _leerIndice(llave);
    _llaveDeLaCopia = llave;
    return copia.conIndice(leido);
  }

  /// Trae la copia a este celular: el cajón queda como en la copia, y lo que
  /// este celular tenga y la copia no (documentos o perfiles nuevos) se queda.
  /// [progreso]: documentos de la copia listos de cuántos.
  Future<void> recuperar(CopiaEncontrada copia, {void Function(int hechos, int total)? progreso}) async {
    final indice = copia.indice;
    final llave = _llaveDeLaCopia;
    final cuenta = _cuentaDeLaCopia;
    if (indice == null || llave == null || cuenta == null) {
      throw StateError('La copia todavía no está abierta');
    }
    final deLaCopia = indice.contenido;
    final aqui = await repo.leerContenido();
    final perfilesDeLaCopia = {for (final p in deLaCopia.perfiles) p.id};
    final documentosDeLaCopia = {for (final d in deLaCopia.documentos) d.id};
    final soloAqui = {
      for (final d in aqui.documentos)
        if (!documentosDeLaCopia.contains(d.id)) d.id,
    };
    final juntos = ContenidoCajon(
      nombre: deLaCopia.nombre.isEmpty ? aqui.nombre : deLaCopia.nombre,
      perfiles: [...deLaCopia.perfiles, ...aqui.perfiles.where((p) => !perfilesDeLaCopia.contains(p.id))],
      documentos: [...deLaCopia.documentos, ...aqui.documentos.where((d) => soloAqui.contains(d.id))],
      descartadas: {...deLaCopia.descartadas, ...aqui.descartadas},
    );
    final total = deLaCopia.documentos.where((d) => d.archivo != null).length;
    var hechos = 0;
    progreso?.call(0, total);
    await repo.restaurar(
      juntos,
      archivosDe: (d) async {
        if (soloAqui.contains(d.id)) {
          final paginas = await repo.leerPaginas(d);
          return (paginas: paginas, pdf: paginas.isEmpty ? await repo.leerPdf(d) : null);
        }
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
    _olvidarCopia();
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
