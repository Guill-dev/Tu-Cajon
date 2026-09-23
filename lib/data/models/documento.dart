import '../../core/formato.dart';
import 'categoria.dart';

/// Tono de la etiqueta de un documento ("Vence en 18 días", etc.).
enum TonoAviso { peligro, advertencia, info, calma }

/// Etiqueta corta que acompaña a un documento en la lista.
class EtiquetaDocumento {
  const EtiquetaDocumento(this.texto, this.tono);

  final String texto;
  final TonoAviso tono;
}

/// Un papel guardado en el cajón. Solo guarda datos; los textos que se
/// muestran ("Vence en 18 días", "PDF · 2 páginas") se calculan aquí.
class Documento {
  const Documento({
    required this.id,
    required this.perfilId,
    required this.nombre,
    required this.categoria,
    required this.guardadoEn,
    this.paginas = 1,
    this.tamanoBytes = 0,
    this.venceEn,
    this.archivo,
    this.textoExtraido = '',
  });

  final String id;
  final String perfilId;
  final String nombre;
  final Categoria categoria;
  final DateTime guardadoEn;
  final int paginas;
  final int tamanoBytes;
  final DateTime? venceEn;

  /// Ruta del archivo cifrado dentro de la carpeta privada de la app.
  /// `null` mientras la cámara y la subida de archivos sean simuladas.
  final String? archivo;

  /// Texto que se leyó del documento (para buscar y para "Pregúntale").
  final String textoExtraido;

  /// Cédulas, licencias y tarjetas: dos páginas son "frente y reverso".
  bool get _esTarjeta => categoria == Categoria.identidad || categoria == Categoria.vehiculo;

  String get detallePaginas {
    if (paginas == 2 && _esTarjeta) return 'frente y reverso';
    return paginas == 1 ? '1 página' : '$paginas páginas';
  }

  /// "PDF · frente y reverso".
  String get detalleArchivo => 'PDF · $detallePaginas';

  /// "PDF · 2 páginas · 480 KB".
  String get detalleCompleto =>
      'PDF · ${paginas == 1 ? '1 página' : '$paginas páginas'} · ${Formato.tamano(tamanoBytes)}';

  String get guardadoTexto => Formato.fechaLarga(guardadoEn);

  String get vencimientoTexto => venceEn == null ? 'No se vence' : Formato.fechaLarga(venceEn!);

  /// "Cedula_de_ciudadania.pdf".
  String get nombreArchivo {
    final base = Formato.normalizar(nombre)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final limpio = base.isEmpty ? 'documento' : base;
    return '${limpio[0].toUpperCase()}${limpio.substring(1)}.pdf';
  }

  /// Días que faltan para que venza (negativo si ya venció).
  int? diasParaVencer(DateTime hoy) => venceEn == null ? null : Formato.diasEntre(hoy, venceEn!);

  /// Certificados que en los trámites piden "recientes".
  bool get esCertificado => Formato.normalizar(nombre).contains('certificado');

  /// Meses desde que se guardó.
  int mesesGuardado(DateTime hoy) => Formato.diasEntre(guardadoEn, hoy) ~/ 30;

  /// La etiqueta de la lista, según la fecha de hoy:
  /// vencido · vence en ≤ 30 días · vence en ≤ 1 año · certificado viejo.
  EtiquetaDocumento? etiqueta(DateTime hoy) {
    final dias = diasParaVencer(hoy);
    if (dias != null) {
      if (dias < 0) return const EtiquetaDocumento('Vencido', TonoAviso.peligro);
      if (dias == 0) return const EtiquetaDocumento('Vence hoy', TonoAviso.peligro);
      if (dias <= 30) {
        return EtiquetaDocumento(dias == 1 ? 'Vence mañana' : 'Vence en $dias días', TonoAviso.advertencia);
      }
      if (dias <= 365) {
        final meses = (dias / 30).round();
        return EtiquetaDocumento(meses <= 1 ? 'Vence en 1 mes' : 'Vence en $meses meses', TonoAviso.calma);
      }
      return null;
    }
    final meses = mesesGuardado(hoy);
    if (esCertificado && meses >= 1) {
      return EtiquetaDocumento(meses == 1 ? 'Tiene 1 mes' : 'Tiene $meses meses', TonoAviso.info);
    }
    return null;
  }

  Documento copyWith({
    String? nombre,
    Categoria? categoria,
    DateTime? venceEn,
    bool quitarVencimiento = false,
  }) => Documento(
    id: id,
    perfilId: perfilId,
    nombre: nombre ?? this.nombre,
    categoria: categoria ?? this.categoria,
    guardadoEn: guardadoEn,
    paginas: paginas,
    tamanoBytes: tamanoBytes,
    venceEn: quitarVencimiento ? null : (venceEn ?? this.venceEn),
    archivo: archivo,
    textoExtraido: textoExtraido,
  );
}

/// Lo que se necesita para guardar un documento nuevo.
class NuevoDocumento {
  const NuevoDocumento({
    required this.perfilId,
    required this.nombre,
    required this.categoria,
    this.paginas = 1,
    this.tamanoBytes = 0,
    this.venceEn,
    this.archivo,
    this.textoExtraido = '',
  });

  final String perfilId;
  final String nombre;
  final Categoria categoria;
  final int paginas;
  final int tamanoBytes;
  final DateTime? venceEn;
  final String? archivo;
  final String textoExtraido;
}
