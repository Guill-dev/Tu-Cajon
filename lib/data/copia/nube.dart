import 'dart:typed_data';

/// Un archivo guardado en la nube.
class ArchivoEnNube {
  const ArchivoEnNube({required this.nombre, required this.bytes, required this.modificado});

  final String nombre;
  final int bytes;
  final DateTime modificado;
}

/// Lo que puede salir mal al hablar con la nube, con el mensaje para la persona.
sealed class ProblemaNube implements Exception {
  const ProblemaNube(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class SinConexion extends ProblemaNube {
  const SinConexion() : super('No hay internet. La copia se hará sola cuando vuelva la conexión.');
}

class NubeLlena extends ProblemaNube {
  const NubeLlena() : super('Tu Google Drive está lleno. Libera espacio para que la copia siga al día.');
}

/// Google quitó el permiso (se revocó, o cambió la contraseña de la cuenta).
class PermisoPerdido extends ProblemaNube {
  const PermisoPerdido() : super('Google pidió conectar la cuenta de nuevo.');
}

/// La persona cerró el selector de cuentas sin elegir ninguna.
class ConexionCancelada extends ProblemaNube {
  const ConexionCancelada() : super('No se conectó ninguna cuenta.');
}

/// Dónde vive la copia de seguridad. Hoy: [NubeEnMemoria] (pruebas) y
/// `NubeDePrueba` (una carpeta dentro del mismo celular). Cuando se
/// configure Google, se agrega la de Google Drive con esta misma forma: una
/// carpeta oculta de la app en el Drive de la persona, que la app no usa
/// para ver ningún otro archivo.
abstract interface class Nube {
  /// `true` mientras no sea Google Drive de verdad.
  bool get deprueba;

  /// Abre el selector de cuentas. Devuelve la cuenta (el correo) o lanza
  /// [ConexionCancelada].
  Future<String> conectar();

  Future<void> desconectar();

  Future<List<ArchivoEnNube>> listar();

  /// Crea el archivo o lo reemplaza si ya existe.
  Future<void> subir(String nombre, Uint8List datos);

  Future<Uint8List> bajar(String nombre);

  Future<void> borrar(String nombre);
}

/// En memoria, para pruebas. Puede simular que falla o que se cancela.
class NubeEnMemoria implements Nube {
  NubeEnMemoria({this.cuenta = 'marta@gmail.com', DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final String cuenta;
  final DateTime Function() _reloj;
  final Map<String, (Uint8List, DateTime)> archivos = {};

  /// Si no es `null`, la próxima operación falla con esto.
  ProblemaNube? fallarCon;

  /// Si la persona "cierra" el selector de cuentas.
  bool cancelarConexion = false;

  /// Nombres de lo que se ha subido, en orden (para revisar en pruebas).
  final List<String> subidos = [];

  bool conectada = false;

  void _revisar() {
    final f = fallarCon;
    if (f != null) {
      fallarCon = null;
      throw f;
    }
  }

  @override
  bool get deprueba => true;

  @override
  Future<String> conectar() async {
    if (cancelarConexion) throw const ConexionCancelada();
    _revisar();
    conectada = true;
    return cuenta;
  }

  @override
  Future<void> desconectar() async => conectada = false;

  @override
  Future<List<ArchivoEnNube>> listar() async {
    _revisar();
    return [
      for (final MapEntry(key: nombre, value: (datos, fecha)) in archivos.entries)
        ArchivoEnNube(nombre: nombre, bytes: datos.length, modificado: fecha),
    ];
  }

  @override
  Future<void> subir(String nombre, Uint8List datos) async {
    _revisar();
    archivos[nombre] = (Uint8List.fromList(datos), _reloj());
    subidos.add(nombre);
  }

  @override
  Future<Uint8List> bajar(String nombre) async {
    _revisar();
    final a = archivos[nombre];
    if (a == null) throw StateError('No existe $nombre en la nube');
    return a.$1;
  }

  @override
  Future<void> borrar(String nombre) async {
    _revisar();
    archivos.remove(nombre);
  }
}
