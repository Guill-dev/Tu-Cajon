import '../../core/formato.dart';
import '../../core/lectura/lector_de_texto.dart';
import '../models/categoria.dart';

/// Lo que se entendió de un documento a partir de su texto.
class DatosLeidos {
  const DatosLeidos({this.nombre, this.categoria, this.numero, this.venceEn, this.reconocido = false});

  /// "Cédula de ciudadanía", "SOAT · ABC123" o el título del papel.
  final String? nombre;
  final Categoria? categoria;

  /// El número principal: cédula, pasaporte, NIT, placa…
  final String? numero;
  final DateTime? venceEn;

  /// `true` si se reconoció el tipo de documento (no solo su título).
  final bool reconocido;
}

/// Si un tipo de documento tiene fecha de vencimiento.
enum _Vence {
  /// No se vence (registro civil, diplomas, recibos…): no se busca fecha.
  nunca,

  /// Solo si el texto dice cuál es ("vence", "válido hasta", "vigencia"…).
  siLoDice,

  /// Se vence: si no lo dice, es la fecha más lejana del papel.
  laMasLejana,
}

/// Qué número buscar en cada tipo.
enum _Numero { identidad, pasaporte, nit, placa, general }

class _Tipo {
  const _Tipo(
    this.nombre,
    this.categoria,
    this.patron, {
    this.vence = _Vence.siLoDice,
    this.numero = _Numero.general,
    this.requiere,
  });

  final String nombre;
  final Categoria categoria;

  /// Se busca en el texto normalizado (minúsculas, sin tildes).
  final String patron;
  final _Vence vence;
  final _Numero numero;

  /// Otra cosa que tiene que aparecer en algún lado (p. ej. "factura").
  final String? requiere;
}

class _Fecha {
  const _Fecha(this.fecha, this.inicio, this.fin);

  final DateTime fecha;
  final int inicio;
  final int fin;
}

/// Entiende qué es un documento a partir del texto que se leyó: el tipo
/// (y su carpeta), el número y la fecha de vencimiento.
///
/// Son reglas pensadas para los papeles de Colombia: no adivina. Si no
/// reconoce el documento, propone el título (la letra más grande de arriba).
abstract final class Interprete {
  static const _recibo = r'factura|recibo|cuenta de cobro|total a pagar|valor a pagar|pago oportuno';

  /// Los tipos que reconoce. Gana el que aparece primero en el texto (el
  /// título va arriba): un certificado que dice "identificado con cédula"
  /// sigue siendo un certificado.
  static const _tipos = [
    // Identidad
    _Tipo('Cédula de extranjería', Categoria.identidad, r'cedula de extranjeria', numero: _Numero.identidad),
    _Tipo('Tarjeta de identidad', Categoria.identidad, r'tarjeta de identidad', numero: _Numero.identidad),
    _Tipo(
      'Cédula de ciudadanía',
      Categoria.identidad,
      r'cedula de ciudadania|identificacion personal',
      numero: _Numero.identidad,
    ),
    _Tipo(
      'Registro civil de nacimiento',
      Categoria.identidad,
      r'registro civil',
      vence: _Vence.nunca,
      numero: _Numero.identidad,
    ),
    _Tipo(
      'Pasaporte',
      Categoria.identidad,
      r'pasaporte|passport',
      vence: _Vence.laMasLejana,
      numero: _Numero.pasaporte,
    ),
    _Tipo(
      'Permiso por Protección Temporal',
      Categoria.identidad,
      r'permiso por proteccion temporal',
      numero: _Numero.identidad,
    ),
    _Tipo(
      'Libreta militar',
      Categoria.identidad,
      r'libreta militar|tarjeta militar',
      vence: _Vence.nunca,
      numero: _Numero.identidad,
    ),
    // Vehículo
    _Tipo(
      'Licencia de conducción',
      Categoria.vehiculo,
      r'licencia de conduccion|licencia de conducir',
      vence: _Vence.laMasLejana,
      numero: _Numero.identidad,
    ),
    _Tipo(
      'Tarjeta de propiedad',
      Categoria.vehiculo,
      r'licencia de transito|tarjeta de propiedad',
      vence: _Vence.nunca,
      numero: _Numero.placa,
    ),
    _Tipo(
      'SOAT',
      Categoria.vehiculo,
      r'\bsoat\b|seguro obligatorio',
      vence: _Vence.laMasLejana,
      numero: _Numero.placa,
    ),
    _Tipo(
      'Revisión técnico-mecánica',
      Categoria.vehiculo,
      r'tecnico.?mecanica|revision tecnica',
      vence: _Vence.laMasLejana,
      numero: _Numero.placa,
    ),
    // Impuestos
    _Tipo(
      'Certificado de ingresos y retenciones',
      Categoria.impuestos,
      r'certificado de ingresos y retenciones|formulario 220',
      vence: _Vence.nunca,
      numero: _Numero.nit,
    ),
    _Tipo(
      'Declaración de renta',
      Categoria.impuestos,
      r'declaracion de renta|formulario 210|formulario 110',
      vence: _Vence.nunca,
      numero: _Numero.nit,
    ),
    _Tipo(
      'RUT',
      Categoria.impuestos,
      r'registro unico tributario|\brut\b',
      vence: _Vence.nunca,
      numero: _Numero.nit,
    ),
    _Tipo('Impuesto predial', Categoria.impuestos, r'impuesto predial', vence: _Vence.nunca),
    _Tipo(
      'Impuesto vehicular',
      Categoria.impuestos,
      r'impuesto (?:sobre |de )?vehicul',
      vence: _Vence.nunca,
      numero: _Numero.placa,
    ),
    // Salud
    _Tipo(
      'Certificado de la EPS',
      Categoria.salud,
      r'certificado de afiliacion|entidad promotora de salud|\beps\b',
      vence: _Vence.nunca,
      numero: _Numero.identidad,
    ),
    _Tipo('Carné de vacunación', Categoria.salud, r'vacunacion|\bvacunas?\b', vence: _Vence.nunca),
    _Tipo('Historia clínica', Categoria.salud, r'historia clinica|epicrisis', vence: _Vence.nunca),
    _Tipo('Fórmula médica', Categoria.salud, r'formula medica|receta medica'),
    _Tipo('Orden médica', Categoria.salud, r'orden medica|autorizacion de servicios|orden de servicio'),
    _Tipo('Incapacidad médica', Categoria.salud, r'incapacidad', vence: _Vence.nunca),
    _Tipo(
      'Resultados de laboratorio',
      Categoria.salud,
      r'laboratorio clinico|resultados? de laboratorio|hemograma',
      vence: _Vence.nunca,
    ),
    // Estudios
    _Tipo('Acta de grado', Categoria.estudios, r'acta de grado', vence: _Vence.nunca),
    _Tipo(
      'Diploma',
      Categoria.estudios,
      r'diploma|otorga el titulo|confiere el titulo|titulo de bachiller',
      vence: _Vence.nunca,
    ),
    _Tipo('Resultados Saber 11', Categoria.estudios, r'saber 11|icfes|saber pro', vence: _Vence.nunca),
    _Tipo(
      'Certificado de notas',
      Categoria.estudios,
      r'certificado de (?:notas|calificaciones)|boletin|informe academico',
      vence: _Vence.nunca,
    ),
    _Tipo(
      'Certificado de estudio',
      Categoria.estudios,
      r'certificado de estudios?|constancia de estudios?',
      vence: _Vence.nunca,
    ),
    // Pensión
    _Tipo('Historia laboral', Categoria.pension, r'historia laboral', vence: _Vence.nunca),
    _Tipo(
      'Certificado de pensión',
      Categoria.pension,
      r'colpensiones|fondo de pensiones|pensiones y cesantias|porvenir|colfondos|skandia',
      vence: _Vence.nunca,
    ),
    // Hogar
    _Tipo(
      'Recibo de la luz',
      Categoria.hogar,
      r'energia electrica|\bkwh\b|\benel\b|codensa|electricaribe|afinia|\bair-e\b|celsia|\benergia\b',
      vence: _Vence.nunca,
      requiere: _recibo,
    ),
    _Tipo(
      'Recibo del agua',
      Categoria.hogar,
      r'acueducto|alcantarillado',
      vence: _Vence.nunca,
      requiere: _recibo,
    ),
    _Tipo(
      'Recibo del gas',
      Categoria.hogar,
      r'gas natural|\bvanti\b|gases de|\bgas\b',
      vence: _Vence.nunca,
      requiere: _recibo,
    ),
    _Tipo(
      'Factura de internet',
      Categoria.hogar,
      r'\binternet\b|telefonia|fibra optica',
      vence: _Vence.nunca,
      requiere: _recibo,
    ),
    _Tipo(
      'Contrato de arrendamiento',
      Categoria.hogar,
      r'contrato de arrendamiento|arrendatario',
      vence: _Vence.nunca,
    ),
    _Tipo('Escritura', Categoria.hogar, r'escritura publica', vence: _Vence.nunca),
    _Tipo(
      'Certificado de tradición y libertad',
      Categoria.hogar,
      r'tradicion y libertad|matricula inmobiliaria',
      vence: _Vence.nunca,
    ),
    // Otros
    _Tipo(
      'Certificado laboral',
      Categoria.otro,
      r'certificado laboral|certificacion laboral|labora en|presta sus servicios',
      vence: _Vence.nunca,
      numero: _Numero.identidad,
    ),
    _Tipo('Contrato de trabajo', Categoria.otro, r'contrato (?:individual )?de trabajo', vence: _Vence.nunca),
    _Tipo(
      'Certificado bancario',
      Categoria.otro,
      r'certificacion bancaria|certificado bancario',
      vence: _Vence.nunca,
    ),
    _Tipo(
      'Certificado de antecedentes',
      Categoria.otro,
      r'antecedentes (?:judiciales|disciplinarios|fiscales)|procuraduria|contraloria',
      vence: _Vence.nunca,
      numero: _Numero.identidad,
    ),
  ];

  /// Entiende el [texto] completo del documento. Con las [lineas] de la
  /// primera página (y su tamaño), propone un título si no reconoce el tipo.
  static DatosLeidos entender(String texto, {List<LineaLeida> lineas = const []}) {
    if (texto.trim().isEmpty) return const DatosLeidos();
    final normal = Formato.normalizar(texto);
    final tipo = _tipoDe(normal);
    final fechas = _fechas(normal);
    final numero = _numero(texto, normal, tipo?.numero ?? _Numero.general);
    final vence = _vencimiento(normal, fechas, tipo?.vence ?? _Vence.siLoDice);
    if (tipo == null) {
      return DatosLeidos(nombre: _titulo(lineas), numero: numero, venceEn: vence);
    }
    final placa = tipo.numero == _Numero.placa ? numero : null;
    return DatosLeidos(
      nombre: placa == null ? tipo.nombre : '${tipo.nombre} · $placa',
      categoria: tipo.categoria,
      numero: numero,
      venceEn: vence,
      reconocido: true,
    );
  }

  /// El número principal del documento (para "Pregúntale" y el detalle).
  static String? numero(String texto) {
    final normal = Formato.normalizar(texto);
    return _numero(texto, normal, _tipoDe(normal)?.numero ?? _Numero.general);
  }

  // ── Tipo ───────────────────────────────────────────────────────────────

  static _Tipo? _tipoDe(String normal) {
    _Tipo? mejor;
    var donde = -1;
    for (final t in _tipos) {
      final m = RegExp(t.patron).firstMatch(normal);
      if (m == null) continue;
      if (t.requiere != null && !RegExp(t.requiere!).hasMatch(normal)) continue;
      if (mejor == null || m.start < donde) {
        mejor = t;
        donde = m.start;
      }
    }
    return mejor;
  }

  // ── Número ─────────────────────────────────────────────────────────────

  /// "Número", "NUIP", "No.", "N°"… (como palabra: el "no" de "teléfono" no cuenta).
  static const _antesDelNumero = r'\b(?:numero|nuip|no\.?|n°|nº|nro\.?|num\.?)\s*:?\s*';
  static final _cifraConPuntos = RegExp(r'\b\d{1,3}(?:\.\d{3}){2,3}\b');

  static String? _numero(String original, String normal, _Numero cual) {
    switch (cual) {
      case _Numero.identidad:
        final tras = RegExp('$_antesDelNumero(\\d{1,3}(?:[.,]?\\d{3}){1,3})\\b').firstMatch(normal);
        if (tras != null) return tras.group(1);
        final conPuntos = _cifraConPuntos.firstMatch(normal);
        if (conPuntos != null) return conPuntos.group(0);
        return RegExp(r'\b\d{6,10}\b').firstMatch(normal)?.group(0) ?? _general(normal);
      case _Numero.pasaporte:
        return RegExp(r'\b[A-Z]{1,2}\d{6,8}\b').firstMatch(original.toUpperCase())?.group(0) ??
            _general(normal);
      case _Numero.nit:
        final nit = RegExp(r'\b\d{1,3}(?:\.?\d{3}){2,3}\s?-\s?\d\b').firstMatch(normal);
        return nit?.group(0)?.replaceAll(' ', '') ?? _general(normal);
      case _Numero.placa:
        final mayusculas = original.toUpperCase();
        // Primero la que va después de "placa"; si no, la primera que aparezca.
        final tras = RegExp(r'PLACA[^A-Z0-9]{0,12}([A-Z]{3})\s?-?\s?(\d{2}[A-Z0-9])\b')
            .firstMatch(mayusculas);
        final m = tras ?? RegExp(r'\b([A-Z]{3})\s?-?\s?(\d{3}|\d{2}[A-Z])\b').firstMatch(mayusculas);
        return m == null ? null : '${m.group(1)}${m.group(2)}';
      case _Numero.general:
        return _general(normal);
    }
  }

  /// Después de "Número", "NIT", "No." o "Referencia", o la primera cifra
  /// de 6 o más caracteres.
  static String? _general(String normal) {
    final tras = RegExp(
      r'\b(?:numero|nit|no\.|referencia(?: de pago)?)\s*:?\s*([a-z0-9][a-z0-9.\- ]{4,}[0-9])',
    ).firstMatch(normal);
    if (tras != null) return tras.group(1)!.trim().toUpperCase();
    return RegExp(r'\b[0-9][0-9.\-]{4,}[0-9]\b').firstMatch(normal)?.group(0);
  }

  // ── Fechas ─────────────────────────────────────────────────────────────

  static const _meses = {
    'ene': 1,
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'abr': 4,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'aug': 8,
    'sep': 9,
    'set': 9,
    'oct': 10,
    'nov': 11,
    'dic': 12,
    'dec': 12,
  };

  static final _formatos = <(RegExp, DateTime? Function(Match))>[
    // 15/10/2026, 15-10-2026, 15.10.2026
    (
      RegExp(r'\b(\d{1,2})\s?[/\-.]\s?(\d{1,2})\s?[/\-.]\s?(\d{4})\b'),
      (m) => _fecha(m.group(3)!, m.group(2)!, m.group(1)!),
    ),
    // 2026/10/15, 2026-10-15
    (
      RegExp(r'\b(\d{4})\s?[/\-.]\s?(\d{1,2})\s?[/\-.]\s?(\d{1,2})\b'),
      (m) => _fecha(m.group(1)!, m.group(2)!, m.group(3)!),
    ),
    // 15 de octubre de 2026, 15 OCT 2026, 15-OCT-2026, 15 OCT/OCT 2030
    (
      RegExp(
        r'\b(\d{1,2})(?:\s*de)?[\s\-/.]*(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic|jan|apr|aug|dec)'
        r'[a-z]*\.?(?:\s*/\s*[a-z]{3,}\.?)?(?:\s*del?)?[\s\-/.,]*(\d{4})\b',
      ),
      (m) => _fecha(m.group(3)!, '${_meses[m.group(2)!]}', m.group(1)!),
    ),
    // 15 10 2026 (casillas separadas, como en los formularios)
    (RegExp(r'\b(\d{2})\s(\d{2})\s(\d{4})\b'), (m) => _fecha(m.group(3)!, m.group(2)!, m.group(1)!)),
  ];

  static DateTime? _fecha(String anio, String mes, String dia) {
    final a = int.parse(anio), m = int.parse(mes), d = int.parse(dia);
    if (a < 1900 || a > 2100 || m < 1 || m > 12 || d < 1) return null;
    final f = DateTime(a, m, d);
    return f.month == m && f.day == d ? f : null; // descarta el 31 de febrero
  }

  static List<_Fecha> _fechas(String normal) {
    final todas = <_Fecha>[];
    for (final (patron, leer) in _formatos) {
      for (final m in patron.allMatches(normal)) {
        final f = leer(m);
        if (f == null) continue;
        if (todas.any((o) => m.start < o.fin && o.inicio < m.end)) continue; // ya estaba
        todas.add(_Fecha(f, m.start, m.end));
      }
    }
    return todas..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  static final _diceVence = RegExp(
    r'venc|vence|vigencia|vigente|valid[oa]s?\b|hasta|expira|expiracion|expiry|caduc|\bvto\b',
  );
  static final _diceOtraCosa = RegExp(
    r'expedi|nacimiento|\bnaci|emision|emitid|desde|pago|corte|elaboracion|generad|impres|grado|ingreso|afiliacion|birth|issue',
  );

  /// La fecha de vencimiento: la que el texto marca como tal ("vence",
  /// "válido hasta"…). Si no lo dice y el tipo se vence, la más lejana que no
  /// sea de nacimiento, expedición, pago…
  static DateTime? _vencimiento(String normal, List<_Fecha> fechas, _Vence vence) {
    if (vence == _Vence.nunca || fechas.isEmpty) return null;
    final marcadas = <_Fecha>[];
    final libres = <_Fecha>[];
    var anterior = 0;
    for (final f in fechas) {
      // Lo que dice justo antes de la fecha (sin pasar por la fecha anterior).
      final desde = (f.inicio - 50).clamp(anterior, f.inicio);
      final antes = normal.substring(desde, f.inicio);
      final si = _diceVence.allMatches(antes).lastOrNull;
      final no = _diceOtraCosa.allMatches(antes).lastOrNull;
      if (si != null && (no == null || si.end > no.end)) {
        marcadas.add(f);
      } else if (no == null) {
        libres.add(f);
      }
      anterior = f.fin;
    }
    DateTime? masLejana(List<_Fecha> l) =>
        l.isEmpty ? null : l.map((f) => f.fecha).reduce((a, b) => a.isAfter(b) ? a : b);
    return masLejana(marcadas) ?? (vence == _Vence.laMasLejana ? masLejana(libres) : null);
  }

  // ── Título ─────────────────────────────────────────────────────────────

  /// Siglas que se dejan en mayúscula al volver "normal" un título.
  static const _siglas = {
    'eps',
    'ips',
    'arl',
    'rut',
    'nit',
    'soat',
    'dian',
    'icfes',
    'sena',
    'sas',
    'runt',
    'simit',
    'sisben',
    'ltda',
  };

  /// El renglón de letra más grande en la parte de arriba de la página, si
  /// se nota que es un título.
  static String? _titulo(List<LineaLeida> lineas) {
    bool sirve(LineaLeida l) {
      final t = l.texto.trim();
      final letras = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').allMatches(t).length;
      final cifras = RegExp(r'\d').allMatches(t).length;
      return t.length <= 48 && letras >= 4 && cifras * 3 < letras && !t.contains('@') && !t.contains('www');
    }

    final candidatas = lineas.where(sirve).toList();
    if (candidatas.length < 2) return null;
    final altos = [for (final l in lineas) l.caja.height]..sort();
    final mediana = altos[altos.length ~/ 2];
    final maximo = candidatas.map((l) => l.caja.height).reduce((a, b) => a > b ? a : b);
    if (maximo < mediana * 1.3) return null; // ninguna se destaca: no hay título claro
    final grandes = candidatas.where((l) => l.caja.height >= maximo * 0.85).toList()
      ..sort((a, b) => a.caja.top.compareTo(b.caja.top));
    return _comoNombre(grandes.first.texto);
  }

  /// "CERTIFICADO DE AFILIACIÓN EPS" → "Certificado de afiliación EPS".
  static String _comoNombre(String titulo) {
    final t = titulo.trim().replaceAll(RegExp(r'\s+'), ' ');
    final todoMayuscula = t == t.toUpperCase();
    final palabras = [
      for (final p in t.split(' '))
        if (_siglas.contains(Formato.normalizar(p).replaceAll('.', '')))
          p.toUpperCase()
        else if (todoMayuscula)
          p.toLowerCase()
        else
          p,
    ];
    final frase = palabras.join(' ');
    return frase.isEmpty ? frase : frase[0].toUpperCase() + frase.substring(1);
  }
}
