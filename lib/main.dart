import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
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
    runApp(TuCajonApp(repo: repo));
  } catch (e, pila) {
    // Si la base no abre, se avisa en pantalla en vez de quedarse congelada.
    debugPrint('No se pudo abrir la base de datos: $e\n$pila');
    runApp(ErrorAperturaApp(detalle: '$e', onReintentar: _arrancar));
  }
}
