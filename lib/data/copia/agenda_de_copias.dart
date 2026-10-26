/// Quien despierta a la app a la hora de la próxima copia, aunque esté
/// cerrada (en el celular, WorkManager de Android: ver
/// `copia_en_segundo_plano.dart`).
abstract interface class AgendaDeCopias {
  /// Programa la copia para [cuando] (si ya pasó, apenas se pueda). Con
  /// [soloWifi], espera a tener Wi-Fi. Reemplaza lo que hubiera programado.
  Future<void> programar(DateTime cuando, {required bool soloWifi});

  /// Ya no hay copias programadas (a mano, o la cuenta se desconectó).
  Future<void> cancelar();
}

/// No programa nada (pruebas y vista web): anota lo último que se pidió.
class AgendaSimulada implements AgendaDeCopias {
  /// La copia programada (`null` si no hay ninguna).
  DateTime? programada;
  bool? soloWifi;

  @override
  Future<void> programar(DateTime cuando, {required bool soloWifi}) async {
    programada = cuando;
    this.soloWifi = soloWifi;
  }

  @override
  Future<void> cancelar() async {
    programada = null;
    soloWifi = null;
  }
}
