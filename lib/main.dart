import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/copia/llaves_de_copia.dart';
import 'core/copia/red.dart';
import 'data/copia/copia_de_seguridad.dart';
import 'data/copia/nube_de_prueba.dart';
import 'data/db/conexion.dart';
import 'features/error/error_apertura.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app está diseñada para celular en vertical.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await _arrancar();
}

Future<void> _arrancar() async {
  try {
    // Abre la base de datos cifrada (en web: datos de ejemplo en memoria).
    final repo = await abrirRepositorio();
    // Mientras no esté conectada con Google Drive, la copia se prueba en una
    // carpeta dentro del mismo celular (NubeDePrueba).
    final copia = CopiaDeSeguridad(
      repo: repo,
      nube: NubeDePrueba(),
      llaves: LlavesDeCopia.paraEstaPlataforma(),
      red: Red.paraEstaPlataforma(),
    );
    runApp(TuCajonApp(repo: repo, copia: copia));
  } catch (e, pila) {
    // Si la base no abre, se avisa en pantalla en vez de quedarse congelada.
    debugPrint('No se pudo abrir la base de datos: $e\n$pila');
    runApp(ErrorAperturaApp(detalle: '$e', onReintentar: _arrancar));
  }
}
