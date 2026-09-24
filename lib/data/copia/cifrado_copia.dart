import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/contenido_cajon.dart';

/// La llave no abre la copia (es de otra copia, o de otro celular).
class LlaveEquivocada implements Exception {
  const LlaveEquivocada();
}

/// El código de emergencia no abre la copia.
class CodigoEquivocado implements Exception {
  const CodigoEquivocado();
}

/// El archivo no es una copia de Tu Cajón, o está dañado.
class CopiaIlegible implements Exception {
  const CopiaIlegible();
}

/// El cifrado de la copia de seguridad.
///
/// - Cada archivo que sube a la nube va cifrado con AES-256-GCM y la llave de
///   la copia (32 bytes al azar, ver `LlavesDeCopia`). Su nombre va como
///   dato asociado: si alguien le cambia el nombre en la nube, ya no abre.
/// - Formato: `versión (1 byte) + nonce (12) + texto cifrado + MAC (16)`.
/// - El código de emergencia (16 letras y números, 80 bits al azar) protege
///   una copia de la llave que también va a la nube, por si la llave no
///   llega sola a un celular nuevo.
abstract final class CifradoCopia {
  static final _aes = AesGcm.with256bits();
  static const _version = 1;

  static Uint8List nuevaLlave() => _alAzar(32);

  static Uint8List _alAzar(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Future<Uint8List> cifrar(Uint8List datos, Uint8List llave, {required String nombre}) async {
    final caja = await _aes.encrypt(datos, secretKey: SecretKey(llave), aad: utf8.encode(nombre));
    return (BytesBuilder(copy: false)
          ..addByte(_version)
          ..add(caja.nonce)
          ..add(caja.cipherText)
          ..add(caja.mac.bytes))
        .takeBytes();
  }

  /// Lanza [LlaveEquivocada] si la llave no es la de este archivo.
  static Future<Uint8List> descifrar(Uint8List cifrado, Uint8List llave, {required String nombre}) async {
    final minimo = 1 + _aes.nonceLength + _aes.macAlgorithm.macLength;
    if (cifrado.length < minimo || cifrado[0] != _version) throw const CopiaIlegible();
    final caja = SecretBox.fromConcatenation(
      Uint8List.sublistView(cifrado, 1),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
      copy: false,
    );
    try {
      final plano = await _aes.decrypt(caja, secretKey: SecretKey(llave), aad: utf8.encode(nombre));
      return plano is Uint8List ? plano : Uint8List.fromList(plano);
    } on SecretBoxAuthenticationError {
      throw const LlaveEquivocada();
    }
  }

  // ── Los archivos de un documento, en un solo paquete ──────────────────

  static const _tipoFotos = 1;
  static const _tipoPdf = 2;

  /// `tipo (1 byte) + cuántas partes (4) + [largo (4) + bytes]…`
  static Uint8List empaquetar(ArchivosDocumento a) {
    final partes = a.pdf != null ? [a.pdf!] : a.paginas;
    final b = BytesBuilder(copy: false)
      ..addByte(a.pdf != null ? _tipoPdf : _tipoFotos)
      ..add(_entero(partes.length));
    for (final parte in partes) {
      b
        ..add(_entero(parte.length))
        ..add(parte);
    }
    return b.takeBytes();
  }

  static ArchivosDocumento desempaquetar(Uint8List datos) {
    try {
      final vista = ByteData.sublistView(datos);
      final tipo = datos[0];
      final cuantas = vista.getUint32(1);
      var i = 5;
      final partes = <Uint8List>[];
      for (var n = 0; n < cuantas; n++) {
        final largo = vista.getUint32(i);
        i += 4;
        if (i + largo > datos.length) throw const CopiaIlegible();
        partes.add(Uint8List.sublistView(datos, i, i + largo));
        i += largo;
      }
      return switch (tipo) {
        _tipoPdf when partes.length == 1 => (paginas: const <Uint8List>[], pdf: partes.first),
        _tipoFotos => (paginas: partes, pdf: null),
        _ => throw const CopiaIlegible(),
      };
    } on RangeError {
      throw const CopiaIlegible();
    }
  }

  static Uint8List _entero(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

  // ── Código de emergencia ──────────────────────────────────────────────

  /// Letras y números sin los que se confunden (sin I, L, O ni U).
  static const _letras = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Un código nuevo: "K7Q2-9XMA-PL4D-83TZ".
  static String nuevoCodigo() {
    final r = Random.secure();
    final letras = List.generate(16, (_) => _letras[r.nextInt(_letras.length)]).join();
    return _agrupar(letras);
  }

  static String _agrupar(String s) => [for (var i = 0; i < s.length; i += 4) s.substring(i, i + 4)].join('-');

  /// Lo que escribió la persona, en su forma normal ("k7q2 9xma…" →
  /// "K7Q2-9XMA-…"); `null` si no tiene la forma de un código.
  static String? normalizarCodigo(String escrito) {
    final limpio = escrito
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1');
    if (limpio.length != 16 || limpio.split('').any((c) => !_letras.contains(c))) return null;
    return _agrupar(limpio);
  }

  static const _nombreEmergencia = 'tucajon-emergencia';

  static Future<SecretKey> _llaveDelCodigo(String codigo, List<int> sal) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(utf8.encode(codigo)),
        nonce: sal,
        info: utf8.encode('tu_cajon.codigo_de_emergencia'),
      );

  /// La llave de la copia, protegida con el código: `versión + sal (16) + caja`.
  static Future<Uint8List> envolverLlave(Uint8List llave, String codigo) async {
    final sal = _alAzar(16);
    final caja = await _aes.encrypt(
      llave,
      secretKey: await _llaveDelCodigo(codigo, sal),
      aad: utf8.encode(_nombreEmergencia),
    );
    return (BytesBuilder(copy: false)
          ..addByte(_version)
          ..add(sal)
          ..add(caja.concatenation()))
        .takeBytes();
  }

  /// Lanza [CodigoEquivocado] si el código no es el de esta copia.
  static Future<Uint8List> desenvolverLlave(Uint8List envuelta, String codigo) async {
    if (envuelta.length < 1 + 16 + 12 + 32 + 16 || envuelta[0] != _version) throw const CopiaIlegible();
    final sal = Uint8List.sublistView(envuelta, 1, 17);
    final caja = SecretBox.fromConcatenation(
      Uint8List.sublistView(envuelta, 17),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    try {
      final llave = await _aes.decrypt(
        caja,
        secretKey: await _llaveDelCodigo(codigo, sal),
        aad: utf8.encode(_nombreEmergencia),
      );
      return Uint8List.fromList(llave);
    } on SecretBoxAuthenticationError {
      throw const CodigoEquivocado();
    }
  }

  /// Huella (SHA-256) de unos bytes, para saber si algo cambió.
  static Future<String> huella(Uint8List datos) async => base64Encode((await Sha256().hash(datos)).bytes);
}
