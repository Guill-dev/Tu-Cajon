import '../../core/formato.dart';
import '../../data/models/documento.dart';
import '../../data/models/perfil.dart';
import '../../data/repositorio/cajon_repositorio.dart';

/// Enlace que puede llevar una respuesta de la IA.
sealed class Cta {
  const Cta(this.etiqueta);

  final String etiqueta;
}

class AbrirDocumento extends Cta {
  const AbrirDocumento(this.documentoId) : super('Ver el documento');

  final String documentoId;
}

class VerAvisos extends Cta {
  const VerAvisos() : super('Ver el aviso');
}

class Mensaje {
  const Mensaje.usuario(this.texto) : esIa = false, cta = null;

  const Mensaje.ia(this.texto, {this.cta}) : esIa = true;

  final String texto;
  final bool esIa;
  final Cta? cta;
}

/// "IA" local de Tu Cajón: busca en los documentos del celular con el
/// índice de texto completo y arma la respuesta con reglas simples.
///
/// Aquí se conectará después un modelo de lenguaje local; la pantalla solo
/// necesita [responder].
class AsistenteLocal {
  AsistenteLocal(this.repo);

  final CajonRepositorio repo;

  /// Palabras que no ayudan a encontrar el documento.
  static const _vacias = {
    'cual',
    'cuales',
    'cuando',
    'como',
    'donde',
    'que',
    'quien',
    'mis',
    'del',
    'los',
    'las',
    'una',
    'uno',
    'por',
    'para',
    'con',
    'tengo',
    'esta',
    'este',
    'numero',
    'num',
    'vence',
    'vencimiento',
    'caduca',
    'fecha',
    'dame',
    'dime',
    'muestra',
    'busca',
    'buscar',
    'documento',
    'papel',
  };

  Future<Mensaje> responder(String pregunta, {DateTime? hoy}) async {
    final ahora = hoy ?? DateTime.now();
    final q = Formato.normalizar(pregunta);
    final palabras = Formato.palabras(pregunta).where((p) => !_vacias.contains(p)).toList();
    if (palabras.isEmpty) return _noEncontrado;

    final docs = await repo.buscar(palabras.join(' '));
    if (docs.isEmpty) return _noEncontrado;
    // "Mi cédula": si hay varias coincidencias, gana la del perfil propio.
    final d = docs.firstWhere((x) => x.perfilId == Perfil.idPropio, orElse: () => docs.first);

    if (q.contains('vence') || q.contains('vencimiento') || q.contains('caduca')) {
      if (d.venceEn == null) {
        return Mensaje.ia('“${d.nombre}” no tiene fecha de vencimiento guardada.', cta: AbrirDocumento(d.id));
      }
      final dias = d.diasParaVencer(ahora)!;
      final cuando = switch (dias) {
        < 0 => 'ya se venció',
        0 => 'vence hoy',
        1 => 'vence mañana',
        _ => 'faltan $dias días',
      };
      return Mensaje.ia(
        '“${d.nombre}” vence el ${Formato.fechaLarga(d.venceEn!)}: $cuando.',
        cta: const VerAvisos(),
      );
    }

    if (q.contains('numero') || q.contains('#')) {
      final numero = _numeroEn(d.textoExtraido);
      if (numero != null) {
        return Mensaje.ia(
          'El número de “${d.nombre}” es $numero. Lo encontré en la carpeta ${d.categoria.etiqueta}.',
          cta: AbrirDocumento(d.id),
        );
      }
      return Mensaje.ia(
        'Tengo “${d.nombre}” guardado, pero no pude leer su número. Ábrelo para verlo.',
        cta: AbrirDocumento(d.id),
      );
    }

    return Mensaje.ia(
      'Encontré “${d.nombre}” en la carpeta ${d.categoria.etiqueta}. ${_resumen(d, ahora)}',
      cta: AbrirDocumento(d.id),
    );
  }

  static const _noEncontrado = Mensaje.ia(
    'No encontré ese dato en tus documentos guardados. Prueba preguntando por tu pasaporte, tu licencia o tu cédula.',
  );

  /// El primer "número" del texto: después de "Número", o una cifra larga.
  static String? _numeroEn(String texto) {
    final tras = RegExp(
      r'(?:n[uú]mero|nit|no\.)\s*:?\s*([A-Z0-9][A-Z0-9.\- ]{4,}[0-9])',
      caseSensitive: false,
    ).firstMatch(texto);
    if (tras != null) return tras.group(1)!.trim();
    return RegExp(r'\b[0-9][0-9.\-]{5,}[0-9]\b').firstMatch(texto)?.group(0);
  }

  static String _resumen(Documento d, DateTime hoy) {
    final e = d.etiqueta(hoy);
    return e == null ? 'Guardado el ${d.guardadoTexto}.' : '${e.texto}.';
  }
}
