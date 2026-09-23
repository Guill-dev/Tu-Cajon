import '../repositorio/cajon_repositorio.dart';
import '../repositorio/memoria_repositorio.dart';

/// En la web no hay SQLite nativo: la vista previa usa datos en memoria.
Future<CajonRepositorio> abrirRepositorio() async => MemoriaCajonRepositorio();
