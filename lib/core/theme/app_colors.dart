import 'package:flutter/material.dart';

/// Los colores que cambian entre el modo de día y el de noche.
///
/// Las dos paletas cumplen contraste AA para los textos sobre sus fondos.
/// En la de noche el acento es más claro y lo que va encima de él
/// ([sobrePrimario]) es oscuro, como pide Material para el modo oscuro.
class Paleta {
  const Paleta({
    required this.deNoche,
    required this.fondo,
    required this.superficie,
    required this.superficieSuave,
    required this.fondoPreview,
    required this.sombraSuelo,
    required this.texto,
    required this.titulo,
    required this.tituloSuave,
    required this.textoSecundario,
    required this.textoTerciario,
    required this.placeholder,
    required this.primario,
    required this.sobrePrimario,
    required this.primarioOscuro,
    required this.primarioSuave,
    required this.primarioTextoSuave,
    required this.pulso,
    required this.amarillo,
    required this.borde,
    required this.bordeInput,
    required this.bordeChip,
    required this.bordePunteado,
    required this.bordeAzul,
    required this.divisor,
    required this.tirador,
    required this.deshabilitadoFondo,
    required this.deshabilitadoTexto,
    required this.switchApagado,
    required this.verde,
    required this.verdeOscuro,
    required this.verdeTexto,
    required this.verdeTextoSuave,
    required this.verdeSuave,
    required this.ambar,
    required this.ambarSuave,
    required this.ambarBorde,
    required this.rojo,
    required this.rojoSuave,
    required this.sobreRojo,
    required this.calmaFondo,
    required this.toast,
    required this.scrim,
  });

  /// La de noche.
  final bool deNoche;

  // Fondos
  final Color fondo;
  final Color superficie;
  final Color superficieSuave;
  final Color fondoPreview;
  final Color sombraSuelo;

  // Texto
  final Color texto;
  final Color titulo;
  final Color tituloSuave;
  final Color textoSecundario;
  final Color textoTerciario;
  final Color placeholder;

  // Marca
  final Color primario;

  /// Texto e íconos encima del [primario] (botones, chips elegidos…).
  final Color sobrePrimario;
  final Color primarioOscuro;
  final Color primarioSuave;
  final Color primarioTextoSuave;
  final Color pulso;
  final Color amarillo;

  // Bordes
  final Color borde;
  final Color bordeInput;
  final Color bordeChip;
  final Color bordePunteado;
  final Color bordeAzul;
  final Color divisor;
  final Color tirador;

  // Deshabilitado
  final Color deshabilitadoFondo;
  final Color deshabilitadoTexto;
  final Color switchApagado;

  // WhatsApp / éxito
  final Color verde;
  final Color verdeOscuro;
  final Color verdeTexto;
  final Color verdeTextoSuave;
  final Color verdeSuave;

  // Aviso / IA
  final Color ambar;
  final Color ambarSuave;
  final Color ambarBorde;

  // Peligro
  final Color rojo;
  final Color rojoSuave;

  /// Texto encima del [rojo] (botón de borrar, globito de avisos).
  final Color sobreRojo;

  final Color calmaFondo;
  final Color toast;
  final Color scrim;

  /// Día (estilo v3: azul claro, tarjetas blancas, acento azul-violeta y
  /// amarillo suave).
  static const dia = Paleta(
    deNoche: false,
    fondo: Color(0xFFEEF2FB), // azul muy claro de toda la app
    superficie: Color(0xFFFFFFFF),
    superficieSuave: Color(0xFFF3F5FC),
    fondoPreview: Color(0xFFE3E8F6),
    sombraSuelo: Color(0xFFDCE2F2),
    texto: Color(0xFF1B1E33),
    titulo: Color(0xFF1B1E33),
    tituloSuave: Color(0xFF7A819B), // primera línea de los títulos en dos tonos
    textoSecundario: Color(0xFF646A82),
    textoTerciario: Color(0xFF4E546B),
    placeholder: Color(0xFF7A819B),
    primario: Color(0xFF5160EC), // azul-violeta
    sobrePrimario: Color(0xFFFFFFFF),
    primarioOscuro: Color(0xFF3F4DD6),
    primarioSuave: Color(0xFFE6E9FD),
    primarioTextoSuave: Color(0xFF3F4A9E),
    pulso: Color(0xFFAEB6FA),
    amarillo: Color(0xFFFCE38A), // botones destacados (como la campana de la referencia)
    borde: Color(0xFFE3E8F4),
    bordeInput: Color(0xFFD5DBEC),
    bordeChip: Color(0xFFDDE2F0),
    bordePunteado: Color(0xFFB4BCD8),
    bordeAzul: Color(0xFFCBD1FA),
    divisor: Color(0xFFEEF1F8),
    tirador: Color(0xFFD8DDEB),
    deshabilitadoFondo: Color(0xFFDFE3EF),
    deshabilitadoTexto: Color(0xFF626880),
    switchApagado: Color(0xFFC5CBDD),
    verde: Color(0xFF1D7A4C),
    verdeOscuro: Color(0xFF1B6B44),
    verdeTexto: Color(0xFF16603B),
    verdeTextoSuave: Color(0xFF2E4A3B),
    verdeSuave: Color(0xFFE1F5EA),
    ambar: Color(0xFF8A5A00),
    ambarSuave: Color(0xFFFFF4D6),
    ambarBorde: Color(0xFFF7E1A6),
    rojo: Color(0xFFC43D33),
    rojoSuave: Color(0xFFFDE8E6),
    sobreRojo: Color(0xFFFFFFFF),
    calmaFondo: Color(0xFFEEF0F6),
    toast: Color(0xFF1B1E33),
    scrim: Color(0x801B1E33),
  );

  /// Noche: azul marino profundo (el mismo de la cámara), tarjetas un poco
  /// más claras y el acento azul-violeta aclarado para que se lea.
  static const noche = Paleta(
    deNoche: true,
    fondo: Color(0xFF0F1220),
    superficie: Color(0xFF1A1E31),
    superficieSuave: Color(0xFF222740),
    fondoPreview: Color(0xFF232843),
    sombraSuelo: Color(0xFF080A13),
    texto: Color(0xFFE9EBF7),
    titulo: Color(0xFFF3F4FB),
    tituloSuave: Color(0xFF8E95B2),
    textoSecundario: Color(0xFFA9AFC8),
    textoTerciario: Color(0xFFBDC2D7),
    placeholder: Color(0xFF8189A7),
    primario: Color(0xFF8D98FF),
    sobrePrimario: Color(0xFF101430),
    primarioOscuro: Color(0xFFB7BEFF),
    primarioSuave: Color(0xFF272D57),
    primarioTextoSuave: Color(0xFFBDC3FF),
    pulso: Color(0xFF4B56B8),
    amarillo: Color(0xFF4A3D14),
    borde: Color(0xFF2A2F4A),
    bordeInput: Color(0xFF363C5B),
    bordeChip: Color(0xFF30354F),
    bordePunteado: Color(0xFF4F5677),
    bordeAzul: Color(0xFF3E4790),
    divisor: Color(0xFF272B42),
    tirador: Color(0xFF3B405C),
    deshabilitadoFondo: Color(0xFF262A3F),
    deshabilitadoTexto: Color(0xFF8C92AB),
    switchApagado: Color(0xFF454A64),
    verde: Color(0xFF1F7D4E),
    verdeOscuro: Color(0xFF8FE0B4),
    verdeTexto: Color(0xFF8FE0B4),
    verdeTextoSuave: Color(0xFFB6DCC8),
    verdeSuave: Color(0xFF15382A),
    ambar: Color(0xFFF5C75B),
    ambarSuave: Color(0xFF392E12),
    ambarBorde: Color(0xFF5C4B1E),
    rojo: Color(0xFFFF7B72),
    rojoSuave: Color(0xFF3F1F24),
    sobreRojo: Color(0xFF2A0D0B),
    calmaFondo: Color(0xFF262A3D),
    toast: Color(0xFF30365A),
    scrim: Color(0x99000000),
  );
}

/// Paleta de Tu Cajón. Los colores que dependen del modo (día o noche) salen
/// de la [Paleta] en uso; la cambia `TemaDelCelular` cuando el celular pasa
/// de día a noche. Los de la cámara y los dibujos son los mismos siempre.
abstract final class AppColors {
  /// La paleta en uso. Quien la cambia debe volver a dibujar la app.
  static Paleta paleta = Paleta.dia;

  /// ¿Está en modo de noche?
  static bool get deNoche => paleta.deNoche;

  // Fondos
  static Color get fondo => paleta.fondo;
  static Color get superficie => paleta.superficie;
  static Color get superficieSuave => paleta.superficieSuave;
  static Color get fondoPreview => paleta.fondoPreview;
  static Color get sombraSuelo => paleta.sombraSuelo;
  static const fondoCamara = Color(0xFF14162A);

  // Texto
  static Color get texto => paleta.texto;
  static Color get titulo => paleta.titulo;
  static Color get tituloSuave => paleta.tituloSuave;
  static Color get textoSecundario => paleta.textoSecundario;
  static Color get textoTerciario => paleta.textoTerciario;
  static Color get placeholder => paleta.placeholder;

  // Marca
  static Color get primario => paleta.primario;
  static Color get sobrePrimario => paleta.sobrePrimario;
  static Color get primarioOscuro => paleta.primarioOscuro;
  static Color get primarioSuave => paleta.primarioSuave;
  static Color get primarioTextoSuave => paleta.primarioTextoSuave;
  static Color get pulso => paleta.pulso;
  static Color get amarillo => paleta.amarillo;

  // Bordes (casi no se usan: el estilo va con sombras)
  static Color get borde => paleta.borde;
  static Color get bordeTarjeta => paleta.borde;
  static Color get bordeInput => paleta.bordeInput;
  static Color get bordeChip => paleta.bordeChip;
  static Color get bordePunteado => paleta.bordePunteado;
  static Color get bordeAzul => paleta.bordeAzul;
  static Color get divisor => paleta.divisor;
  static Color get tirador => paleta.tirador;

  // Deshabilitado
  static Color get deshabilitadoFondo => paleta.deshabilitadoFondo;
  static Color get deshabilitadoTexto => paleta.deshabilitadoTexto;
  static Color get switchApagado => paleta.switchApagado;

  // WhatsApp / éxito
  static Color get verde => paleta.verde;
  static Color get verdeOscuro => paleta.verdeOscuro;
  static Color get verdeTexto => paleta.verdeTexto;
  static Color get verdeTextoSuave => paleta.verdeTextoSuave;
  static Color get verdeSuave => paleta.verdeSuave;
  static const verdeToast = Color(0xFF8FE0B4);

  // Aviso / IA
  static Color get ambar => paleta.ambar;
  static Color get ambarSuave => paleta.ambarSuave;
  static Color get ambarBorde => paleta.ambarBorde;

  // Peligro
  static Color get rojo => paleta.rojo;
  static Color get rojoSuave => paleta.rojoSuave;
  static Color get sobreRojo => paleta.sobreRojo;

  // Neutro "calmado"
  static Color get calmaFondo => paleta.calmaFondo;

  // Toast
  static Color get toast => paleta.toast;

  // Scrim de las hojas inferiores
  static Color get scrim => paleta.scrim;

  // Cámara (siempre oscura)
  static const camaraMarco = Color(0xFFA7B0FF);
  static const camaraDetectado = Color(0xFFC4CAFF);
  static const camaraMesa = Color(0xFF3A3552);
  static const camaraTextoSuave = Color(0xFFB9BDD0);
  static const camaraFlash = Color(0xFFFCE38A);
  static const camaraEtiqueta = Color(0xFFE6E8F5);
  static const camaraTerminarOff = Color(0xFF9CA1B8);
  static const camaraEliminar = Color(0xFFFF9A92); // rojo claro, legible sobre el fondo oscuro
  /// El acento de día, para lo que se ve igual en cualquier modo (la
  /// cámara, el color de las notificaciones).
  static const camaraPrimario = Color(0xFF5160EC);

  // Documento de identidad dibujado (es un papel: igual de día y de noche)
  static const idFondo = Color(0xFFE8ECF8);
  static const idBorde = Color(0xFFD3D9EC);
  static const idFoto = Color(0xFFC8D0EA);
  static const idLinea = Color(0xFFBAC3E0);
  static const idBarras = Color(0xFF9DA7C8);
}
