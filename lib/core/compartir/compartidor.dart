import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/compartir/pdf_documento.dart';

/// Cómo terminó un intento de compartir.
enum ResultadoCompartir {
  /// Se abrió WhatsApp o la persona eligió una app en el menú.
  enviado,

  /// La persona cerró el menú de compartir sin elegir nada.
  cancelado,

  /// El celular no tiene WhatsApp (ni WhatsApp Business).
  sinWhatsApp,

  /// No se pudo armar o entregar el PDF.
  fallo,
}

/// Arma el PDF de un documento y lo entrega a otra app.
///
/// El PDF es la única copia sin cifrar que sale del cajón: se escribe en la
/// carpeta temporal privada de la app (otras apps solo lo leen con el permiso
/// que se les da al compartir) y se borra con [limpiar] al volver a abrir la
/// app, al compartir otro y cada vez que el cajón se cierra con llave.
abstract class Compartidor {
  /// El real en Android e iOS; simulado en el navegador.
  factory Compartidor.paraEstaPlataforma() => kIsWeb ? CompartidorSimulado() : CompartidorDelSistema();

  /// [porWhatsApp]: directo a WhatsApp. Si no, el menú de compartir.
  ///
  /// Si llega un [pdf] (documento subido) se envía tal cual; si no, se arma
  /// uno con las fotos de [paginas].
  Future<ResultadoCompartir> enviar({
    required String nombreArchivo,
    required String titulo,
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
    required bool porWhatsApp,
  });

  /// Borra los PDF que se compartieron antes.
  Future<void> limpiar();
}

class CompartidorDelSistema implements Compartidor {
  /// Canal con `MainActivity.kt`, que abre WhatsApp directamente en Android.
  static const _canal = MethodChannel('tu_cajon/compartir');

  /// Carpetas temporales con PDF sin cifrar: la nuestra y la copia que hace
  /// el menú de compartir (share_plus) en Android.
  Future<List<Directory>> _carpetas() async {
    final temporal = (await getTemporaryDirectory()).path;
    return [Directory(p.join(temporal, 'compartidos')), Directory(p.join(temporal, 'share_plus'))];
  }

  @override
  Future<void> limpiar() async {
    try {
      for (final carpeta in await _carpetas()) {
        if (await carpeta.exists()) await carpeta.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('No se pudieron borrar los PDF compartidos: $e');
    }
  }

  @override
  Future<ResultadoCompartir> enviar({
    required String nombreArchivo,
    required String titulo,
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
    required bool porWhatsApp,
  }) async {
    final File archivo;
    try {
      await limpiar();
      // Armar el PDF con fotos grandes toma un momento: se hace aparte para
      // que la animación de "Preparando" no se trabe.
      final bytes = pdf ?? await _armarAparte(paginas, titulo);
      final carpeta = (await _carpetas()).first;
      await carpeta.create(recursive: true);
      archivo = File(p.join(carpeta.path, nombreArchivo));
      await archivo.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('No se pudo armar el PDF: $e');
      return ResultadoCompartir.fallo;
    }

    if (porWhatsApp) {
      // En iOS no se puede elegir la app: se usa el menú, donde sale WhatsApp.
      if (!Platform.isAndroid) return _menu(archivo, titulo);
      try {
        final abrio = await _canal.invokeMethod<bool>('whatsapp', {'ruta': archivo.path});
        return abrio == true ? ResultadoCompartir.enviado : ResultadoCompartir.sinWhatsApp;
      } on PlatformException catch (e) {
        debugPrint('No se pudo abrir WhatsApp: $e');
        return ResultadoCompartir.fallo;
      }
    }
    return _menu(archivo, titulo);
  }

  /// Estática a propósito: lo único que viaja al otro hilo son las fotos.
  static Future<Uint8List> _armarAparte(List<Uint8List> paginas, String titulo) =>
      Isolate.run(() => armarPdf(paginas, titulo: titulo));

  Future<ResultadoCompartir> _menu(File archivo, String titulo) async {
    try {
      final r = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path, mimeType: 'application/pdf')],
          title: titulo,
          subject: titulo,
        ),
      );
      return r.status == ShareResultStatus.dismissed
          ? ResultadoCompartir.cancelado
          : ResultadoCompartir.enviado;
    } catch (e) {
      debugPrint('No se pudo abrir el menú de compartir: $e');
      return ResultadoCompartir.fallo;
    }
  }
}

/// Para el navegador y las pruebas: no arma nada, solo recuerda qué se pidió.
class CompartidorSimulado implements Compartidor {
  CompartidorSimulado({this.resultado = ResultadoCompartir.enviado});

  ResultadoCompartir resultado;

  /// Cada envío: (nombre del archivo, cantidad de páginas, ¿por WhatsApp?).
  final envios = <(String, int, bool)>[];

  /// Los PDF subidos que se enviaron tal cual.
  final pdfsEnviados = <Uint8List>[];
  int limpiezas = 0;

  @override
  Future<ResultadoCompartir> enviar({
    required String nombreArchivo,
    required String titulo,
    List<Uint8List> paginas = const [],
    Uint8List? pdf,
    required bool porWhatsApp,
  }) async {
    envios.add((nombreArchivo, paginas.length, porWhatsApp));
    if (pdf != null) pdfsEnviados.add(pdf);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Como el celular real: sin WhatsApp, el menú de compartir sí funciona.
    if (!porWhatsApp && resultado == ResultadoCompartir.sinWhatsApp) return ResultadoCompartir.enviado;
    return resultado;
  }

  @override
  Future<void> limpiar() async => limpiezas++;
}

/// Pone el compartidor al alcance de las pantallas: `context.compartidor`.
class CompartidorScope extends InheritedWidget {
  const CompartidorScope({super.key, required this.compartidor, required super.child});

  final Compartidor compartidor;

  @override
  bool updateShouldNotify(CompartidorScope oldWidget) => compartidor != oldWidget.compartidor;
}

extension CompartidorContexto on BuildContext {
  Compartidor get compartidor {
    final scope = getInheritedWidgetOfExactType<CompartidorScope>();
    assert(scope != null, 'Falta CompartidorScope arriba en el árbol de widgets.');
    return scope!.compartidor;
  }
}
