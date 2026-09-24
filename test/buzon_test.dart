import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/core/archivos/buzon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('tu_cajon/recibir');
  final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => mensajero.setMockMethodCallHandler(canal, null));

  test('El buzón entiende lo que llega del lado de Android', () async {
    final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
    mensajero.setMockMethodCallHandler(canal, (llamada) async {
      return switch (llamada.method) {
        'revisar' => true,
        'tomar' => {
          'archivos': [
            {'nombre': 'Certificado.pdf', 'tipo': 'application/pdf', 'bytes': pdf},
            {'nombre': 'foto.jpg', 'tipo': 'image/jpeg', 'problema': 'muy_grande'},
            {'nombre': '', 'tipo': '', 'problema': 'no_se_pudo'},
          ],
          'sobrantes': 2,
        },
        _ => null,
      };
    });

    final buzon = BuzonDelSistema();
    expect(await buzon.hayAlgo(), isTrue);
    final envio = await buzon.tomar();
    expect(envio.sobrantes, 2);
    final [certificado, foto, rara] = envio.archivos;
    expect(certificado.esPdf, isTrue);
    expect(certificado.bytes, pdf);
    expect(certificado.problema, isNull);
    expect(foto.esFoto, isTrue);
    expect(foto.problema, ProblemaRecibido.muyGrande);
    expect(rara.problema, ProblemaRecibido.noSePudo);
    expect(rara.esPdf || rara.esFoto, isFalse);
  });

  test('Un PDF se reconoce por el tipo o por el nombre', () {
    expect(const ArchivoRecibido(nombre: 'x', tipo: 'application/pdf').esPdf, isTrue);
    expect(const ArchivoRecibido(nombre: 'Factura.PDF', tipo: 'application/octet-stream').esPdf, isTrue);
    expect(const ArchivoRecibido(nombre: 'foto.png', tipo: 'image/png').esFoto, isTrue);
    expect(const ArchivoRecibido(nombre: 'foto.png', tipo: 'image/png').esPdf, isFalse);
  });

  test('Sin la parte nativa, el buzón dice que no hay nada', () async {
    mensajero.setMockMethodCallHandler(canal, (_) async => throw MissingPluginException());
    expect(await BuzonDelSistema().hayAlgo(), isFalse);
  });
}
