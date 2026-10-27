import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_cajon/core/copia/cuenta_google.dart';
import 'package:tu_cajon/core/copia/llaves_de_copia.dart';
import 'package:tu_cajon/core/copia/red.dart';
import 'package:tu_cajon/data/copia/copia_de_seguridad.dart';
import 'package:tu_cajon/data/copia/nube.dart';
import 'package:tu_cajon/data/copia/nube_drive.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/data/repositorio/memoria_repositorio.dart';

/// Una cuenta de Google de mentira: cada token nuevo es "t1", "t2"…
class CuentaFalsa implements CuentaGoogle {
  int tokens = 0;
  bool conectada = false;

  String get actual => 't$tokens';

  @override
  Future<String> conectar() async {
    conectada = true;
    tokens++;
    return 'marta@gmail.com';
  }

  @override
  Future<String> token({bool renovar = false}) async {
    if (renovar || tokens == 0) tokens++;
    return actual;
  }

  @override
  Future<void> desconectar() async => conectada = false;

  String? recordada;

  @override
  void recordar(String? correo) => recordada = correo;
}

/// Un Google Drive de mentira: la carpeta oculta de la app, en memoria. Responde
/// como la API de Drive v3 a lo que usa `NubeDrive`.
class DriveFalso {
  DriveFalso(this.cuenta);

  final CuentaFalsa cuenta;
  final Map<String, ({String nombre, Uint8List bytes})> archivos = {};
  final Map<String, ({String? id, String nombre})> _subidas = {};
  var _siguiente = 0;

  /// Lo que se responde a la próxima petición, en vez de lo normal.
  http.Response? proxima;

  /// Si el token vigente ya no sirve (venció).
  bool tokenVencido = false;
  int peticiones = 0;

  late final cliente = MockClient((r) async {
    peticiones++;
    final forzada = proxima;
    if (forzada != null) {
      proxima = null;
      return forzada;
    }
    if (r.headers['Authorization'] != 'Bearer ${cuenta.actual}' || tokenVencido) {
      tokenVencido = false; // el siguiente token ya sirve
      return http.Response('{"error":{"code":401}}', 401);
    }
    final u = r.url;
    // Sesión de subida: se mandan los bytes.
    if (u.host == 'subidas.test') {
      final s = _subidas.remove(u.pathSegments.last)!;
      final id = s.id ?? 'id${_siguiente++}';
      archivos[id] = (nombre: s.nombre, bytes: Uint8List.fromList(r.bodyBytes));
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (u.path.startsWith('/upload/drive/v3/files')) {
      expect(u.queryParameters['uploadType'], 'resumable');
      final sesion = 's${_siguiente++}';
      final id = u.pathSegments.length > 4 ? u.pathSegments.last : null;
      final nombre = id == null
          ? (jsonDecode(r.body) as Map<String, dynamic>)['name'] as String
          : archivos[id]!.nombre;
      if (id == null) {
        expect((jsonDecode(r.body) as Map<String, dynamic>)['parents'], ['appDataFolder']);
      }
      _subidas[sesion] = (id: id, nombre: nombre);
      return http.Response('', 200, headers: {'location': 'https://subidas.test/$sesion'});
    }
    if (u.path == '/drive/v3/files' && r.method == 'GET') {
      expect(u.queryParameters['spaces'], 'appDataFolder');
      final q = u.queryParameters['q'];
      final buscado = q == null ? null : RegExp(r"name = '([^']+)'").firstMatch(q)!.group(1);
      return http.Response(
        jsonEncode({
          'files': [
            for (final MapEntry(key: id, value: a) in archivos.entries)
              if (buscado == null || a.nombre == buscado)
                {
                  'id': id,
                  'name': a.nombre,
                  'size': '${a.bytes.length}',
                  'modifiedTime': '2026-10-25T12:00:00Z',
                },
          ],
        }),
        200,
      );
    }
    final id = u.pathSegments.last;
    if (r.method == 'GET' && u.queryParameters['alt'] == 'media') {
      final a = archivos[id];
      return a == null ? http.Response('', 404) : http.Response.bytes(a.bytes, 200);
    }
    if (r.method == 'DELETE') {
      return archivos.remove(id) == null ? http.Response('', 404) : http.Response('', 204);
    }
    return http.Response('no esperado: ${r.method} $u', 500);
  });
}

Uint8List bytes(List<int> v) => Uint8List.fromList(v);

void main() {
  late CuentaFalsa cuenta;
  late DriveFalso drive;
  late NubeDrive nube;

  setUp(() {
    cuenta = CuentaFalsa();
    drive = DriveFalso(cuenta);
    nube = NubeDrive(cuenta: cuenta, cliente: drive.cliente);
  });

  group('Google Drive', () {
    test('Sube, lista, baja, reemplaza y borra en la carpeta oculta de la app', () async {
      expect(nube.deprueba, isFalse);
      expect(await nube.conectar(), 'marta@gmail.com');
      expect(await nube.listar(), isEmpty);

      await nube.subir('tucajon-indice.bin', bytes([1, 2, 3]));
      await nube.subir('tucajon-doc-a-1.bin', bytes([4, 5]));
      final lista = await nube.listar();
      expect(lista.map((a) => (a.nombre, a.bytes)).toSet(), {
        ('tucajon-indice.bin', 3),
        ('tucajon-doc-a-1.bin', 2),
      });
      expect(await nube.bajar('tucajon-indice.bin'), [1, 2, 3]);

      // Reemplazar no crea otro archivo con el mismo nombre.
      await nube.subir('tucajon-indice.bin', bytes([9, 9]));
      expect(drive.archivos, hasLength(2));
      expect(await nube.bajar('tucajon-indice.bin'), [9, 9]);

      await nube.borrar('tucajon-doc-a-1.bin');
      await nube.borrar('tucajon-doc-a-1.bin'); // ya no estaba: no pasa nada
      expect((await nube.listar()).map((a) => a.nombre), ['tucajon-indice.bin']);
    });

    test('Encuentra lo que subió otro celular (sin haber listado antes)', () async {
      final otro = NubeDrive(cuenta: cuenta, cliente: drive.cliente);
      await otro.subir('tucajon-indice.bin', bytes([7]));
      expect(await nube.bajar('tucajon-indice.bin'), [7]);
    });

    test('Si el permiso venció, pide otro una vez y sigue', () async {
      await nube.conectar();
      drive.tokenVencido = true;
      await nube.subir('tucajon-indice.bin', bytes([1]));
      expect(cuenta.tokens, 2);
      expect(await nube.bajar('tucajon-indice.bin'), [1]);
    });

    test('Los problemas llegan con un mensaje para la persona', () async {
      await nube.conectar();
      drive.proxima = http.Response('{"error":{"errors":[{"reason":"storageQuotaExceeded"}]}}', 403);
      await expectLater(nube.subir('tucajon-indice.bin', bytes([1])), throwsA(isA<NubeLlena>()));

      drive.proxima = http.Response('{"error":{"code":500}}', 500);
      await expectLater(nube.listar(), throwsA(isA<FalloDeLaNube>()));

      final sinInternet = NubeDrive(
        cuenta: cuenta,
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      );
      await expectLater(sinInternet.listar(), throwsA(isA<SinConexion>()));

      // Google ya no acepta ningún permiso (se revocó): hay que conectar otra vez.
      final revocada = NubeDrive(
        cuenta: cuenta,
        cliente: MockClient((_) async => http.Response('{"error":{"code":401}}', 401)),
      );
      await expectLater(revocada.listar(), throwsA(isA<PermisoPerdido>()));
    });

    test('Una copia completa va a Drive y vuelve en otro celular', () async {
      final repo = MemoriaCajonRepositorio();
      await repo.guardarDocumento(
        const NuevoDocumento(perfilId: Perfil.idPropio, nombre: 'Cédula', categoria: Categoria.identidad),
        paginas: [
          bytes([1, 2, 3]),
        ],
      );
      final llaves = LlavesSimuladas();
      final copia = CopiaDeSeguridad(repo: repo, nube: nube, llaves: llaves, red: RedSimulada());
      expect(await copia.conectar(), isNull);
      await copia.hacerCopia();
      expect(copia.estado.value.problema, isNull);
      // En Drive solo hay bytes cifrados.
      expect(drive.archivos.values.map((a) => a.nombre), contains(CopiaDeSeguridad.archivoIndice));
      for (final a in drive.archivos.values) {
        expect(utf8.decode(a.bytes, allowMalformed: true), isNot(contains('Cédula')));
      }

      final nuevo = MemoriaCajonRepositorio(ejemplo: false);
      final otra = CopiaDeSeguridad(
        repo: nuevo,
        nube: NubeDrive(cuenta: cuenta, cliente: drive.cliente),
        llaves: LlavesSimuladas(deOtroCelular: await llaves.leer()),
        red: RedSimulada(),
      );
      final encontrada = await otra.buscarCopia();
      expect(encontrada?.abierta, isTrue);
      await otra.recuperar(encontrada!);
      final cedula = (await nuevo.vigilarTodos().first).firstWhere((d) => d.nombre == 'Cédula');
      expect(await nuevo.leerPaginas(cedula), [
        [1, 2, 3],
      ]);
    });

    test('Si antes la copia era de prueba (en el celular), queda por conectar con Google', () async {
      final repo = MemoriaCajonRepositorio();
      await repo.guardarAjuste('copia.cuenta', cuentaDePrueba);
      await repo.guardarAjuste('copia.ultima', '${DateTime(2026, 10, 1).millisecondsSinceEpoch}');
      final copia = CopiaDeSeguridad(repo: repo, nube: nube, llaves: LlavesSimuladas(), red: RedSimulada());
      await copia.listo;
      expect(copia.estado.value.conectada, isFalse);
      expect(copia.estado.value.ultima, isNull);
    });
  });
}
