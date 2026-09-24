import 'nube.dart';

/// En la vista web, la nube de prueba vive en memoria.
class NubeDePrueba extends NubeEnMemoria {
  NubeDePrueba() : super(cuenta: 'Modo de prueba');
}
