/// Íconos de trazo del prototipo (viewBox 0 0 24 24).
///
/// Cada valor es el atributo `d` de un `<path>`. Se dibujan con [TcIcon],
/// que les pone el color y el grosor de línea. Así los íconos son idénticos
/// a los del diseño y no dependen de ninguna librería de íconos.
abstract final class AppIcons {
  static const candado =
      'M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z M8 11V8a4 4 0 0 1 8 0v3';
  static const cajon =
      'M4 4h16a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z M3 12h18 M10 8h4 M10 16h4';
  static const atras = 'M15 5l-7 7 7 7';
  static const siguiente = 'M9 5l7 7-7 7';
  static const cerrar = 'M6 6l12 12 M18 6L6 18';
  static const mas = 'M12 5v14 M5 12h14';
  static const check = 'M5 12.5l4.5 4.5L19 7.5';
  static const buscar = 'M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z M20 20l-4-4';
  static const ajustes = 'M4 7h9 M17 7h3 M4 17h3 M11 17h9 M15 5v4 M9 15v4';
  static const campana = 'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z M10 20.5a2 2 0 0 0 4 0';
  static const whatsapp =
      'M12 3.5a8.5 8.5 0 0 0-7.4 12.7L3.5 20.5l4.4-1.1A8.5 8.5 0 1 0 12 3.5z M8.5 10.5h7 M8.5 13.5h4.5';
  static const destello =
      'M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z';
  static const destelloSolo = 'M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z';
  static const huella =
      'M3 12a9 9 0 0 1 15.5-6.2 M5.5 19c.6-1.8 1-4.2 1-7a5.5 5.5 0 0 1 .6-2.5 M9.5 6.9A5.5 5.5 0 0 1 17.5 12c0 1 0 2-.1 3 M12 11.5c0 3-.3 6.4-1.4 9.5 M9.2 12c0 2.4-.3 4.8-1 7 M14.8 14.5c-.1 2.2-.5 4.5-1.2 6.5 M20.6 9.5c.3 1.4.4 3.4.2 6';
  static const huellaBoton =
      'M3 12a9 9 0 0 1 15.5-6.2 M5.5 19c.6-1.8 1-4.2 1-7a5.5 5.5 0 0 1 .6-2.5 M9.5 6.9A5.5 5.5 0 0 1 17.5 12c0 1 0 2-.1 3 M12 11.5c0 3-.3 6.4-1.4 9.5 M20.6 9.5c.3 1.4.4 3.4.2 6';
  static const celular = 'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z M11 18h2';
  static const escudo = 'M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z M9 12l2 2 4-4';

  /// Nube con una flecha hacia arriba (copia de seguridad).
  static const nube =
      'M7 18.5h10.5a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.5 9.3 4.6 4.6 0 0 0 7 18.5z M12 15.5v-5 M9.8 12.5l2.2-2.2 2.2 2.2';

  /// Llave (código de emergencia).
  static const llave = 'M8 8.5a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M12 12.5h9 M18 12.5v3 M15.5 12.5v2';
  static const sinRegistro =
      'M12 4a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7z M5 20a7 7 0 0 1 10.5-6 M17 16l4 4 M21 16l-4 4';
  static const persona = 'M12 4a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7z M5 20a7 7 0 0 1 14 0';
  static const huellita =
      'M8 13a2 2 0 1 0 0-4a2 2 0 1 0 0 4z M16 13a2 2 0 1 0 0-4a2 2 0 1 0 0 4z M12 11a2 2 0 1 0 0-4a2 2 0 1 0 0 4z M9 18.5c-1.4 0-2.6-1.1-2.6-2.5c0-1.3.9-2.5 2.4-2.5c1 0 1.6.6 2.6.6s1.6-.6 2.6-.6c1.5 0 2.4 1.2 2.4 2.5c0 1.4-1.2 2.5-2.6 2.5c-1 0-1.7-.5-2.4-.5s-1.4.5-2.4.5z';
  static const camara =
      'M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z M12 9.5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7z';
  static const subirArchivo =
      'M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z M14 3v5h5 M12 17v-6 M9.5 13.5L12 11l2.5 2.5';
  static const flash = 'M13 3L5 14h6l-1 7 8-11h-6z';
  static const calendario =
      'M6 5h12a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z M4 10h16 M9 3v4 M15 3v4';
  static const reloj = 'M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0-17z M12 7.5V12l3 2';
  static const ojo =
      'M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6z';
  static const lapiz = 'M4 20l4.5-1L19 8.5 15.5 5 5 15.5z M13.5 7l3.5 3.5';
  static const reemplazar =
      'M20 11a8 8 0 0 0-14.3-4.9L4 8 M4 4v4h4 M4 13a8 8 0 0 0 14.3 4.9L20 16 M20 20v-4h-4';
  static const basura = 'M4 7h16 M9.5 7V4.5h5V7 M6 7l1 13h10l1-13 M10 11v5 M14 11v5';
  static const recortar = 'M6 2v14a2 2 0 0 0 2 2h14 M18 22V8a2 2 0 0 0-2-2H2';
  static const restablecer = 'M4 12a8 8 0 1 0 2.3-5.6 M4 4v4h4';
  static const arrastrar = 'M5 8h14 M5 12h14 M5 16h14';
  static const galeria =
      'M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z M3 16l5-5 4 4 3-3 6 6 M15.5 8a1.5 1.5 0 1 0 0 3a1.5 1.5 0 1 0 0-3z';
  static const compartir =
      'M18 3a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5z M6 9.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5z M18 16a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5z M8.2 10.8l7.6-4.3 M8.2 13.2l7.6 4.3';
  static const enviar = 'M4 12l16-8-6 8 6 8z';
  static const carro =
      'M5 11l1.8-4.5A2 2 0 0 1 8.7 5h6.6a2 2 0 0 1 1.9 1.5L19 11 M5 11h14a2 2 0 0 1 2 2v4H3v-4a2 2 0 0 1 2-2z M6 17v2 M18 17v2';

  // Compartir
  static const correo =
      'M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z M3.5 7.5l8.5 6 8.5-6';
  static const mensajes = 'M4 5h16v11H9l-5 4z';
  static const bluetooth = 'M7 7l10 10-5 4V3l5 4L7 17';
  static const carpeta = 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z';
  static const imprimir =
      'M7 9V4h10v5 M7 17H5a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-2 M7 14h10v6H7z';
  static const copiar = 'M9 9h10v11H9z M15 9V5a1 1 0 0 0-1-1H6a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3';
  static const cerca =
      'M12 10a2 2 0 1 0 0 4a2 2 0 1 0 0-4z M8.5 8.5a5 5 0 0 0 0 7 M15.5 8.5a5 5 0 0 1 0 7 M5.6 5.6a9 9 0 0 0 0 12.8 M18.4 5.6a9 9 0 0 1 0 12.8';
  static const masApps =
      'M5 10.7a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6z M12 10.7a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6z M19 10.7a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6z';

  // Categorías de documentos
  static const identidad =
      'M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z M9 9a2 2 0 1 0 0 4a2 2 0 1 0 0-4z M6 16.5a3 3 0 0 1 6 0 M14 10h4 M14 13.5h4';
  static const impuestos =
      'M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z M14 3v5h5 M9 13h6 M9 17h4';
  static const salud =
      'M12 20s-7-4.3-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.7-7 10-7 10z M12 9v5 M9.5 11.5h5';
  static const estudios = 'M2 9l10-5 10 5-10 5z M6 11v5c3 2 9 2 12 0v-5 M22 9v5';
  static const vehiculo =
      'M5 11l1.8-4.5A2 2 0 0 1 8.7 5h6.6a2 2 0 0 1 1.9 1.5L19 11 M5 11h14a2 2 0 0 1 2 2v4H3v-4a2 2 0 0 1 2-2z M6 17v2 M18 17v2 M7 14h.01 M17 14h.01';
  static const hogar = 'M4 11l8-7 8 7 M6 9.5V20h12V9.5 M10 20v-5h4v5';
  static const pension =
      'M5 3h14a1 1 0 0 1 1 1v9H4V4a1 1 0 0 1 1-1z M8 6h8 M8 9h5 M9 13l-2.5 7 3.5-2 3.5 2-2.5-7';
}
