import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/copia/cuenta_google.dart';
import 'nube.dart';

/// La copia de seguridad en Google Drive, en la carpeta oculta de la app
/// (`appDataFolder`): la persona no la ve entre sus archivos y la app no
/// puede ver nada más de su Drive. Habla con la API de Drive (v3) directo,
/// con el permiso de la [cuenta].
///
/// Los archivos llegan ya cifrados (ver `CifradoCopia`): Google guarda solo
/// bytes que no puede leer.
class NubeDrive implements Nube {
  NubeDrive({required this.cuenta, http.Client? cliente}) : _http = cliente ?? http.Client();

  final CuentaGoogle cuenta;
  final http.Client _http;

  static const _archivos = 'https://www.googleapis.com/drive/v3/files';
  static const _subidas = 'https://www.googleapis.com/upload/drive/v3/files';

  /// Nombre → id en Drive (Drive identifica los archivos por id).
  final Map<String, String> _ids = {};

  @override
  bool get deprueba => false;

  @override
  Future<String> conectar() => cuenta.conectar();

  @override
  Future<void> desconectar() async {
    _ids.clear();
    await cuenta.desconectar();
  }

  @override
  void recordarCuenta(String? correo) => cuenta.recordar(correo);

  /// Hace el pedido con el permiso vigente. Si venció (401), lo renueva una
  /// vez. Traduce los errores a lo que entiende la copia.
  Future<http.Response> _pedir(
    Future<http.Response> Function(Map<String, String> permiso) hacer, {
    Set<int> tambienBien = const {},
  }) async {
    for (var intento = 0; ; intento++) {
      final token = await cuenta.token(renovar: intento > 0);
      final http.Response r;
      try {
        r = await hacer({'Authorization': 'Bearer $token'}).timeout(const Duration(minutes: 3));
      } on http.ClientException {
        throw const SinConexion();
      } on TimeoutException {
        throw const SinConexion();
      }
      final codigo = r.statusCode;
      if ((codigo >= 200 && codigo < 300) || tambienBien.contains(codigo)) return r;
      if (codigo == 401) {
        if (intento == 0) continue;
        throw const PermisoPerdido();
      }
      if (codigo == 403 && r.body.contains('storageQuotaExceeded')) throw const NubeLlena();
      if (codigo == 403 && (r.body.contains('insufficient') || r.body.contains('SCOPE'))) {
        throw const PermisoPerdido();
      }
      debugPrint('Google Drive respondió $codigo');
      throw const FalloDeLaNube();
    }
  }

  @override
  Future<List<ArchivoEnNube>> listar() async {
    final lista = <ArchivoEnNube>[];
    final ids = <String, String>{};
    String? pagina;
    do {
      final uri = Uri.parse(_archivos).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'fields': 'nextPageToken,files(id,name,size,modifiedTime)',
          'pageSize': '1000',
          'pageToken': ?pagina,
        },
      );
      final r = await _pedir((permiso) => _http.get(uri, headers: permiso));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      for (final f in (j['files'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
        final nombre = f['name'] as String;
        ids[nombre] = f['id'] as String;
        lista.add(
          ArchivoEnNube(
            nombre: nombre,
            bytes: int.tryParse('${f['size'] ?? 0}') ?? 0,
            modificado: DateTime.tryParse(f['modifiedTime'] as String? ?? '') ?? DateTime(2000),
          ),
        );
      }
      pagina = j['nextPageToken'] as String?;
    } while (pagina != null);
    _ids
      ..clear()
      ..addAll(ids);
    return lista;
  }

  /// El id del archivo [nombre], o `null` si no está.
  Future<String?> _id(String nombre) async {
    final conocido = _ids[nombre];
    if (conocido != null) return conocido;
    // Los nombres los pone la app ("tucajon-…"): no llevan comillas.
    final uri = Uri.parse(_archivos).replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': "name = '$nombre' and trashed = false",
        'fields': 'files(id)',
      },
    );
    final r = await _pedir((permiso) => _http.get(uri, headers: permiso));
    final archivos = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List<dynamic>? ?? const [];
    if (archivos.isEmpty) return null;
    return _ids[nombre] = (archivos.first as Map<String, dynamic>)['id'] as String;
  }

  /// Sube con una "subida reanudable" (sirve para archivos grandes): primero
  /// se abre la subida y después se mandan los bytes.
  @override
  Future<void> subir(String nombre, Uint8List datos) async {
    final id = await _id(nombre);
    Map<String, String> encabezados(Map<String, String> permiso) => {
      ...permiso,
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Upload-Content-Type': 'application/octet-stream',
      'X-Upload-Content-Length': '${datos.length}',
    };
    final abierta = await _pedir(
      (permiso) => id == null
          ? _http.post(
              Uri.parse('$_subidas?uploadType=resumable'),
              headers: encabezados(permiso),
              body: jsonEncode({
                'name': nombre,
                'parents': ['appDataFolder'],
              }),
            )
          : _http.patch(
              Uri.parse('$_subidas/$id?uploadType=resumable'),
              headers: encabezados(permiso),
              body: '{}',
            ),
    );
    final destino = abierta.headers['location'];
    if (destino == null) throw const FalloDeLaNube();
    final r = await _pedir(
      (permiso) => _http.put(
        Uri.parse(destino),
        headers: {...permiso, 'Content-Type': 'application/octet-stream'},
        body: datos,
      ),
    );
    final nuevoId = (jsonDecode(r.body) as Map<String, dynamic>)['id'] as String?;
    if (nuevoId != null) _ids[nombre] = nuevoId;
  }

  @override
  Future<Uint8List> bajar(String nombre) async {
    final id = await _id(nombre);
    if (id == null) throw StateError('No existe $nombre en Google Drive');
    final r = await _pedir((permiso) => _http.get(Uri.parse('$_archivos/$id?alt=media'), headers: permiso));
    return r.bodyBytes;
  }

  @override
  Future<void> borrar(String nombre) async {
    final id = await _id(nombre);
    if (id == null) return;
    // 404: ya no estaba.
    await _pedir(
      (permiso) => _http.delete(Uri.parse('$_archivos/$id'), headers: permiso),
      tambienBien: {404},
    );
    _ids.remove(nombre);
  }
}
