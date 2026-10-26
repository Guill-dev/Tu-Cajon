import 'dart:math' as math;

/// Cada cuánto se hace sola la copia de seguridad. Cuenta desde la fecha y
/// hora en que se eligió: si fue el martes a las 8:30 p. m. y es semanal,
/// cada martes a las 8:30 p. m.
enum FrecuenciaCopia {
  diaria('Cada día'),
  semanal('Cada semana'),
  mensual('Cada mes'),

  /// Solo cuando la persona toca "Hacer copia ahora".
  manual('A mano');

  const FrecuenciaCopia(this.etiqueta);

  final String etiqueta;

  /// Para leerla de los ajustes (sin ajuste: cada día).
  static FrecuenciaCopia deTexto(String? texto) =>
      values.firstWhere((f) => f.name == texto, orElse: () => FrecuenciaCopia.diaria);

  /// La vez número [n] contando desde [desde] (la vez 0 es [desde]). Un mes
  /// que no tiene ese día usa su último día (el 31 en febrero → el 28 o 29).
  DateTime vez(DateTime desde, int n) {
    switch (this) {
      case FrecuenciaCopia.diaria:
        return DateTime(desde.year, desde.month, desde.day + n, desde.hour, desde.minute);
      case FrecuenciaCopia.semanal:
        return DateTime(desde.year, desde.month, desde.day + 7 * n, desde.hour, desde.minute);
      case FrecuenciaCopia.mensual:
        final mes = desde.month - 1 + n;
        final anio = desde.year + mes ~/ 12;
        final m = mes % 12 + 1;
        final dias = DateTime(anio, m + 1, 0).day;
        return DateTime(anio, m, math.min(desde.day, dias), desde.hour, desde.minute);
      case FrecuenciaCopia.manual:
        throw StateError('A mano no tiene fechas');
    }
  }

  /// Cuántas veces cabrían, más o menos, entre [desde] y [ahora] (para no
  /// contar de una en una desde el principio).
  int _aproximado(DateTime desde, DateTime ahora) {
    final dias = ahora.difference(desde).inDays;
    return switch (this) {
      FrecuenciaCopia.diaria => dias,
      FrecuenciaCopia.semanal => dias ~/ 7,
      FrecuenciaCopia.mensual => (ahora.year - desde.year) * 12 + ahora.month - desde.month,
      FrecuenciaCopia.manual => 0,
    };
  }

  /// La última vez que le tocó hasta [ahora] (incluida); `null` si todavía
  /// no le ha tocado ninguna.
  DateTime? ultimaVez(DateTime desde, DateTime ahora) {
    if (this == FrecuenciaCopia.manual || ahora.isBefore(desde)) return null;
    var n = math.max(0, _aproximado(desde, ahora) - 1);
    while (!vez(desde, n + 1).isAfter(ahora)) {
      n++;
    }
    while (n > 0 && vez(desde, n).isAfter(ahora)) {
      n--;
    }
    return vez(desde, n);
  }

  /// La próxima vez después de [ahora].
  DateTime? siguienteVez(DateTime desde, DateTime ahora) {
    if (this == FrecuenciaCopia.manual) return null;
    if (ahora.isBefore(desde)) return desde;
    var n = math.max(0, _aproximado(desde, ahora) - 1);
    while (!vez(desde, n).isAfter(ahora)) {
      n++;
    }
    return vez(desde, n);
  }
}
