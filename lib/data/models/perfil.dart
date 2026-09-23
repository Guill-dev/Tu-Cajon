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
}
