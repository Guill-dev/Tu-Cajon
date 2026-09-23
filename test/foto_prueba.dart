import 'dart:convert';
import 'dart:typed_data';

/// Una foto JPEG real de 1×1 píxel, para probar sin cámara.
final fotoPrueba = Uint8List.fromList(
  base64Decode(
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////'
    '////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAA'
    'AAAAAAAAAAAAAP/aAAgBAQABPxA=',
  ),
);
