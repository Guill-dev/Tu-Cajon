import 'package:flutter/widgets.dart';

import '../core/theme/app_colors.dart';
import 'models/categoria.dart';
import 'models/documento.dart';
import 'models/perfil.dart';

/// Datos de ejemplo del prototipo (Marta y Mamá).
///
/// Solo se cargan en modo desarrollo o en la versión web de vista previa.
/// Una instalación real empieza con el cajón vacío. Las fechas se calculan
/// desde [hoy] para que "Vence en 18 días" siempre sea cierto.
abstract final class DatosEjemplo {
  static const nombreUsuario = 'Marta';

  /// Colores que se ofrecen al crear un perfil.
  static const coloresPerfil = <(Color, String)>[
    (Color(0xFF5160EC), 'Azul violeta'),
    (Color(0xFFE0584C), 'Coral'),
    (Color(0xFF2E9468), 'Verde'),
    (Color(0xFFB9770A), 'Mostaza'),
    (Color(0xFF8A5CD6), 'Morado'),
  ];

  /// El perfil del dueño del celular (existe siempre, también sin ejemplos).
  static Perfil perfilPropio(String nombreUsuario) => Perfil(
    id: Perfil.idPropio,
    nombre: 'Tú',
    inicial: inicialDe(nombreUsuario),
    color: AppColors.primario,
    esPropio: true,
  );

  static const perfilMama = Perfil(id: 'mama', nombre: 'Mamá', inicial: 'C', color: Color(0xFFE0584C));

  static String inicialDe(String nombre) {
    final t = nombre.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  static List<Documento> documentos(DateTime hoy) {
    DateTime hace(int dias) => hoy.subtract(Duration(days: dias));
    DateTime en(int dias) => hoy.add(Duration(days: dias));
    Documento doc(
      String id,
      String perfil,
      String nombre,
      Categoria cat, {
      int paginas = 1,
      int kb = 480,
      int guardadoHace = 40,
      DateTime? vence,
      String texto = '',
    }) => Documento(
      id: id,
      perfilId: perfil,
      nombre: nombre,
      categoria: cat,
      paginas: paginas,
      tamanoBytes: kb * 1024,
      guardadoEn: hace(guardadoHace),
      venceEn: vence,
      textoExtraido: texto,
    );

    const yo = Perfil.idPropio;
    return [
      doc(
        'cedula',
        yo,
        'Cédula de ciudadanía',
        Categoria.identidad,
        paginas: 2,
        guardadoHace: 41,
        texto: 'República de Colombia. Cédula de ciudadanía. Número 52.348.910',
      ),
      doc(
        'rut',
        yo,
        'RUT',
        Categoria.impuestos,
        paginas: 3,
        kb: 1230,
        guardadoHace: 90,
        texto: 'Registro Único Tributario. NIT 52348910-1',
      ),
      doc(
        'registro',
        yo,
        'Registro civil de nacimiento',
        Categoria.identidad,
        guardadoHace: 120,
        texto: 'Registro civil de nacimiento. Indicativo serial 12345678',
      ),
      doc(
        'licencia',
        yo,
        'Licencia de conducción',
        Categoria.vehiculo,
        paginas: 2,
        guardadoHace: 200,
        vence: en(18),
        texto: 'Licencia de conducción. Número 52348910. Categoría B1',
      ),
      doc(
        'eps',
        yo,
        'Certificado de la EPS',
        Categoria.salud,
        guardadoHace: 62,
        texto: 'Certificado de afiliación a la EPS. Estado activo',
      ),
      doc(
        'pasaporte',
        yo,
        'Pasaporte',
        Categoria.identidad,
        guardadoHace: 300,
        vence: en(145),
        texto: 'Pasaporte. República de Colombia. Número AB1234567',
      ),
      doc(
        'diploma',
        yo,
        'Diploma de bachiller',
        Categoria.estudios,
        guardadoHace: 400,
        texto: 'Diploma de bachiller académico',
      ),
      doc(
        'luz',
        yo,
        'Recibo de la luz · agosto',
        Categoria.hogar,
        paginas: 2,
        kb: 610,
        guardadoHace: 30,
        texto: 'Factura de energía. Referencia de pago 998877',
      ),
      doc(
        'mama-cedula',
        'mama',
        'Cédula de ciudadanía',
        Categoria.identidad,
        paginas: 2,
        guardadoHace: 60,
        texto: 'Cédula de ciudadanía. Número 41.765.203',
      ),
      doc('mama-vacunas', 'mama', 'Carné de vacunación', Categoria.salud, guardadoHace: 20),
      doc(
        'mama-pension',
        'mama',
        'Certificado de pensión',
        Categoria.pension,
        paginas: 2,
        guardadoHace: 330,
        texto: 'Certificado de pensión. Colpensiones',
      ),
      doc('mama-agua', 'mama', 'Recibo del agua · agosto', Categoria.hogar, guardadoHace: 25),
    ];
  }
}
