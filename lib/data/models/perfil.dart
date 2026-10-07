import 'dart:typed_data';
import 'dart:ui';

enum TipoPerfil { persona, mascota }

/// Un cajón dentro del cajón: el tuyo, el de Mamá, el de la mascota…
class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    required this.inicial,
    required this.color,
    this.tipo = TipoPerfil.persona,
    this.esPropio = false,
    this.documentos = 0,
    this.foto,
  });

  /// Id fijo del perfil del dueño del celular.
  static const idPropio = 'yo';

  final String id;

  /// Cómo aparece en su tarjeta ("Tú", "Mamá").
  final String nombre;
  final String inicial;
  final Color color;
  final TipoPerfil tipo;

  /// `true` solo para el perfil del dueño del celular.
  final bool esPropio;

  /// Cuántos documentos tiene guardados (lo llena el repositorio).
  final int documentos;

  /// Su foto (JPEG cuadrado, pequeño), o `null` para mostrar la inicial
  /// sobre su [color].
  final Uint8List? foto;

  Perfil copyWith({
    String? nombre,
    String? inicial,
    Color? color,
    TipoPerfil? tipo,
    Uint8List? foto,
    bool quitarFoto = false,
    int? documentos,
  }) => Perfil(
    id: id,
    nombre: nombre ?? this.nombre,
    inicial: inicial ?? this.inicial,
    color: color ?? this.color,
    tipo: tipo ?? this.tipo,
    esPropio: esPropio,
    documentos: documentos ?? this.documentos,
    foto: quitarFoto ? null : (foto ?? this.foto),
  );
}
