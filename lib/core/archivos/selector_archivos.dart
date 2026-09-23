import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../seguridad/cerrojo.dart';

/// Un PDF elegido en el explorador de archivos.
class PdfElegido {
  const PdfElegido({required this.nombre, required this.bytes});

  /// Nombre del archivo, p. ej. "Certificado_EPS.pdf".
  final String nombre;
  final Uint8List bytes;
}

/// Abre las ventanas del celular para elegir fotos (galería) o un PDF
/// (explorador de archivos: Descargas, Drive…).
///
/// En Android se usan las ventanas del sistema, que no piden permiso de
/// almacenamiento: la app solo recibe lo que la persona elige.
abstract class SelectorArchivos {
  factory SelectorArchivos.paraEstaPlataforma() => SelectorDelSistema();

  /// Una o varias fotos de la galería (vacío si se cancela).
  Future<List<Uint8List>> elegirFotos();

  /// Un PDF (`null` si se cancela).
  Future<PdfElegido?> elegirPdf();
}

class SelectorDelSistema implements SelectorArchivos {
  @override
  Future<List<Uint8List>> elegirFotos() async {
    // Sin metadatos extra (ubicación, etc.): no los necesitamos.
    final fotos = await ImagePicker().pickMultiImage(requestFullMetadata: false);
    return [for (final f in fotos) await f.readAsBytes()];
  }

  @override
  Future<PdfElegido?> elegirPdf() async {
    const pdf = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final archivo = await openFile(acceptedTypeGroups: const [pdf]);
    if (archivo == null) return null;
    return PdfElegido(nombre: archivo.name, bytes: await archivo.readAsBytes());
  }
}

/// Para las pruebas: devuelve lo que se le diga.
class SelectorSimulado implements SelectorArchivos {
  SelectorSimulado({this.fotos = const [], this.pdf});

  List<Uint8List> fotos;
  PdfElegido? pdf;

  @override
  Future<List<Uint8List>> elegirFotos() async => fotos;

  @override
  Future<PdfElegido?> elegirPdf() async => pdf;
}

/// Pone el selector al alcance de las pantallas: `context.selector`.
class SelectorScope extends InheritedWidget {
  const SelectorScope({super.key, required this.selector, required super.child});

  final SelectorArchivos selector;

  @override
  bool updateShouldNotify(SelectorScope oldWidget) => selector != oldWidget.selector;
}

extension SelectorContexto on BuildContext {
  SelectorArchivos get selector {
    final scope = getInheritedWidgetOfExactType<SelectorScope>();
    assert(scope != null, 'Falta SelectorScope arriba en el árbol de widgets.');
    return scope!.selector;
  }

  /// Abre la galería o el explorador sin que el cajón se cierre al salir, y
  /// no devuelve nada hasta que el cajón esté abierto (si la persona tardó
  /// tanto que se cerró, primero tiene que abrirlo con su llave).
  Future<T> elegirArchivos<T>(Future<T> Function(SelectorArchivos selector) elegir) async {
    final cerrojo = this.cerrojo;
    final selector = this.selector;
    cerrojo.permitirSalida();
    try {
      final elegido = await elegir(selector);
      await cerrojo.esperarAbierto();
      return elegido;
    } finally {
      cerrojo.cancelarSalida();
    }
  }
}
