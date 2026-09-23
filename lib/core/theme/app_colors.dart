import 'package:flutter/material.dart';

/// Paleta de Tu Cajón (estilo v3: azul claro, tarjetas blancas, acento
/// azul-violeta y amarillo suave). Los textos cumplen contraste AA sobre
/// blanco y sobre [fondo].
abstract final class AppColors {
  // Fondos
  static const fondo = Color(0xFFEEF2FB); // azul muy claro de toda la app
  static const superficie = Color(0xFFFFFFFF);
  static const superficieSuave = Color(0xFFF3F5FC);
  static const fondoPreview = Color(0xFFE3E8F6);
  static const fondoCamara = Color(0xFF14162A);
  static const sombraSuelo = Color(0xFFDCE2F2);

  // Texto
  static const texto = Color(0xFF1B1E33);
  static const titulo = Color(0xFF1B1E33);
  static const tituloSuave = Color(0xFF7A819B); // primera línea de los títulos en dos tonos
  static const textoSecundario = Color(0xFF646A82);
  static const textoTerciario = Color(0xFF4E546B);
  static const placeholder = Color(0xFF7A819B);

  // Marca
  static const primario = Color(0xFF5160EC); // azul-violeta
  static const primarioOscuro = Color(0xFF3F4DD6);
  static const primarioSuave = Color(0xFFE6E9FD);
  static const primarioTextoSuave = Color(0xFF3F4A9E);
  static const pulso = Color(0xFFAEB6FA);

  // Amarillo de los botones destacados (como la campana de la referencia)
  static const amarillo = Color(0xFFFCE38A);

  // Bordes (casi no se usan: el estilo va con sombras)
  static const borde = Color(0xFFE3E8F4);
  static const bordeTarjeta = Color(0xFFE3E8F4);
  static const bordeInput = Color(0xFFD5DBEC);
  static const bordeChip = Color(0xFFDDE2F0);
  static const bordePunteado = Color(0xFFB4BCD8);
  static const bordeAzul = Color(0xFFCBD1FA);
  static const divisor = Color(0xFFEEF1F8);
  static const tirador = Color(0xFFD8DDEB);

  // Deshabilitado
  static const deshabilitadoFondo = Color(0xFFDFE3EF);
  static const deshabilitadoTexto = Color(0xFF626880);
  static const switchApagado = Color(0xFFC5CBDD);

  // WhatsApp / éxito
  static const verde = Color(0xFF1D7A4C);
  static const verdeOscuro = Color(0xFF1B6B44);
  static const verdeTexto = Color(0xFF16603B);
  static const verdeTextoSuave = Color(0xFF2E4A3B);
  static const verdeSuave = Color(0xFFE1F5EA);
  static const verdeToast = Color(0xFF8FE0B4);

  // Aviso / IA
  static const ambar = Color(0xFF8A5A00);
  static const ambarSuave = Color(0xFFFFF4D6);
  static const ambarBorde = Color(0xFFF7E1A6);

  // Peligro
  static const rojo = Color(0xFFC43D33);

  // Neutro "calmado"
  static const calmaFondo = Color(0xFFEEF0F6);

  // Toast
  static const toast = Color(0xFF1B1E33);

  // Scrim de las hojas inferiores
  static const scrim = Color(0x801B1E33);

  // Cámara
  static const camaraMarco = Color(0xFFA7B0FF);
  static const camaraDetectado = Color(0xFFC4CAFF);
  static const camaraMesa = Color(0xFF3A3552);
  static const camaraTextoSuave = Color(0xFFB9BDD0);
  static const camaraFlash = Color(0xFFFCE38A);
  static const camaraEtiqueta = Color(0xFFE6E8F5);
  static const camaraTerminarOff = Color(0xFF9CA1B8);

  // Documento de identidad dibujado
  static const idFondo = Color(0xFFE8ECF8);
  static const idBorde = Color(0xFFD3D9EC);
  static const idFoto = Color(0xFFC8D0EA);
  static const idLinea = Color(0xFFBAC3E0);
  static const idBarras = Color(0xFF9DA7C8);
}
