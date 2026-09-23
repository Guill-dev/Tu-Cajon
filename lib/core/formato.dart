/// Textos de fechas, tamaños y búsqueda en español (sin depender de `intl`).
abstract final class Formato {
  static const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// "12 de agosto de 2026".
  static String fechaLarga(DateTime f) => '${f.day} de ${meses[f.month - 1]} de ${f.year}';

  /// "10 de octubre" (sin año).
  static String diaMes(DateTime f) => '${f.day} de ${meses[f.month - 1]}';

  /// "OCT".
  static String mesCorto(DateTime f) => meses[f.month - 1].substring(0, 3).toUpperCase();

  /// "480 KB", "1,2 MB".
  static String tamano(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  /// Días enteros entre dos fechas, contando por calendario (ignora la hora).
  static int diasEntre(DateTime desde, DateTime hasta) {
    final a = DateTime(desde.year, desde.month, desde.day);
    final b = DateTime(hasta.year, hasta.month, hasta.day);
    return (b.difference(a).inHours / 24).round();
  }

  /// Minúsculas y sin tildes, para comparar búsquedas ("Cédula" == "cedula").
  static String normalizar(String s) {
    const conTilde = 'áéíóúüñàèìòù';
    const sinTilde = 'aeiouunaeiou';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = conTilde.indexOf(ch);
      b.write(i >= 0 ? sinTilde[i] : ch);
    }
    return b.toString();
  }

  /// Palabras útiles de un texto para buscar (normalizadas, de 3+ letras).
  static List<String> palabras(String s) =>
      normalizar(s).split(RegExp(r'[^a-z0-9]+')).where((p) => p.length >= 3).toList();
}
