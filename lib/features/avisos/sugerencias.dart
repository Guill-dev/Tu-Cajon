import '../../core/formato.dart';
import '../../data/models/categoria.dart';
import '../../data/models/documento.dart';

enum TipoSugerencia { vencido, renovar, actualizar, agregar }

/// Una tarjeta de "Sugerencias para ti".
class Sugerencia {
  const Sugerencia({
    required this.clave,
    required this.tipo,
    required this.etiqueta,
    required this.titulo,
    required this.texto,
    required this.resumen,
    this.documento,
  });

  /// Identifica la sugerencia al descartarla. Incluye la fecha de
  /// vencimiento: si el documento se renueva, la sugerencia vuelve a salir.
  final String clave;
  final TipoSugerencia tipo;
  final Documento? documento;

  /// "LICENCIA DE CONDUCCIÓN".
  final String etiqueta;
  final String titulo;
  final String texto;

  /// Frase corta para la tarjeta amarilla de "Mi cajón".
  final String resumen;
}

/// Reglas de las sugerencias. Por ahora son reglas sobre las fechas de los
/// documentos; el día que haya un modelo de IA local, se reemplaza esta
/// función y las pantallas siguen igual.
List<Sugerencia> calcularSugerencias(List<Documento> docs, Set<String> descartadas, DateTime hoy) {
  final lista = <Sugerencia>[];

  for (final d in docs) {
    final dias = d.diasParaVencer(hoy);
    final etiqueta = d.nombre.toUpperCase();
    if (dias != null && dias < 0) {
      lista.add(
        Sugerencia(
          clave: 'vencido:${d.id}:${d.venceEn!.toIso8601String()}',
          tipo: TipoSugerencia.vencido,
          documento: d,
          etiqueta: etiqueta,
          titulo: 'Ya se venció',
          texto:
              'Venció el ${Formato.fechaLarga(d.venceEn!)}. Cuando tengas el nuevo, escanéalo para reemplazarlo.',
          resumen: '“${d.nombre}” ya se venció. Toca para ver qué hacer.',
        ),
      );
    } else if (dias != null && dias <= 60) {
      final esLicencia = d.categoria == Categoria.vehiculo;
      final cuando = dias == 0 ? 'hoy' : (dias == 1 ? 'mañana' : 'en $dias días');
      lista.add(
        Sugerencia(
          clave: 'renovar:${d.id}:${d.venceEn!.toIso8601String()}',
          tipo: TipoSugerencia.renovar,
          documento: d,
          etiqueta: etiqueta,
          titulo: 'Renueva a tiempo',
          texto: esLicencia
              ? 'Para renovar la licencia te piden el examen médico en un centro de reconocimiento de conductores y estar al día con las multas. Si pides la cita esta semana, alcanzas antes del ${Formato.diaMes(d.venceEn!)}.'
              : 'Vence el ${Formato.diaMes(d.venceEn!)}. Revisa con tiempo qué te piden para la renovación.',
          resumen: '“${d.nombre}” vence $cuando. Mira qué necesitas para la renovación.',
        ),
      );
    } else if (dias == null && d.esCertificado && d.mesesGuardado(hoy) >= 1) {
      final meses = d.mesesGuardado(hoy);
      final tiempo = meses == 1 ? '1 mes' : '$meses meses';
      lista.add(
        Sugerencia(
          clave: 'actualizar:${d.id}',
          tipo: TipoSugerencia.actualizar,
          documento: d,
          etiqueta: etiqueta,
          titulo: 'Este certificado ya tiene $tiempo',
          texto: 'En muchos trámites lo piden reciente, de menos de 30 días. Descarga uno nuevo y reemplázalo aquí.',
          resumen: '“${d.nombre}” tiene $tiempo. En muchos trámites lo piden reciente.',
        ),
      );
    }
  }

  final tieneBancario = docs.any((d) => Formato.normalizar(d.nombre).contains('bancari'));
  if (!tieneBancario) {
    lista.add(
      const Sugerencia(
        clave: 'agregar:bancario',
        tipo: TipoSugerencia.agregar,
        etiqueta: 'PARA TU CAJÓN',
        titulo: 'Papeles que te podrían pedir pronto',
        texto: 'Muchas personas también guardan su certificado bancario y el carné de vacunas. Son de los que más se piden por WhatsApp.',
        resumen: 'Guarda tu certificado bancario: es de los que más se piden.',
      ),
    );
  }

  lista.sort((a, b) => a.tipo.index.compareTo(b.tipo.index));
  return lista.where((s) => !descartadas.contains(s.clave)).toList();
}
