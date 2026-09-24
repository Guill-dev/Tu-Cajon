import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../models/categoria.dart';
import '../models/contenido_cajon.dart';
import '../models/documento.dart';
import '../models/perfil.dart';
import 'cifrado_copia.dart';

/// El índice de la copia: todos los datos del cajón (perfiles, documentos,
/// fechas…) y en qué archivo de la nube están los archivos de cada documento.
/// Va en JSON, cifrado como todo lo demás.
///
/// En [contenido], el `archivo` de cada documento es el nombre de su
/// archivo en la nube (o `null` si no tiene).
class IndiceCopia {
  const IndiceCopia(this.contenido);

  final ContenidoCajon contenido;

  static const version = 1;

  int get documentos => contenido.documentos.length;

  /// El índice de [c], con [archivos]: id del documento → nombre en la nube.
  factory IndiceCopia.de(ContenidoCajon c, Map<String, String> archivos) => IndiceCopia(
    ContenidoCajon(
      nombre: c.nombre,
      perfiles: c.perfiles,
      documentos: [
        for (final d in c.documentos)
          Documento(
            id: d.id,
            perfilId: d.perfilId,
            nombre: d.nombre,
            categoria: d.categoria,
            guardadoEn: d.guardadoEn,
            paginas: d.paginas,
            tamanoBytes: d.tamanoBytes,
            venceEn: d.venceEn,
            archivo: archivos[d.id],
            textoExtraido: d.textoExtraido,
          ),
      ],
      descartadas: c.descartadas,
    ),
  );

  Uint8List aBytes() {
    final c = contenido;
    return utf8.encode(
      jsonEncode({
        'version': version,
        'nombre': c.nombre,
        'perfiles': [
          for (final p in c.perfiles)
            {
              'id': p.id,
              'nombre': p.nombre,
              'inicial': p.inicial,
              'color': p.color.toARGB32(),
              'tipo': p.tipo.name,
              'propio': p.esPropio,
            },
        ],
        'documentos': [
          for (final d in c.documentos)
            {
              'id': d.id,
              'perfil': d.perfilId,
              'nombre': d.nombre,
              'categoria': d.categoria.name,
              'guardado': d.guardadoEn.millisecondsSinceEpoch,
              'paginas': d.paginas,
              'bytes': d.tamanoBytes,
              'vence': d.venceEn?.millisecondsSinceEpoch,
              'archivo': d.archivo,
              'texto': d.textoExtraido,
            },
        ],
        'descartadas': c.descartadas.toList()..sort(),
      }),
    );
  }

  /// Lanza [CopiaIlegible] si no es un índice de Tu Cajón que se entienda.
  factory IndiceCopia.deBytes(Uint8List bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if ((j['version'] as int) > version) throw const CopiaIlegible();
      return IndiceCopia(
        ContenidoCajon(
          nombre: j['nombre'] as String,
          perfiles: [
            for (final p in (j['perfiles'] as List).cast<Map<String, dynamic>>())
              Perfil(
                id: p['id'] as String,
                nombre: p['nombre'] as String,
                inicial: p['inicial'] as String,
                color: Color(p['color'] as int),
                tipo: TipoPerfil.values.asNameMap()[p['tipo']] ?? TipoPerfil.persona,
                esPropio: p['propio'] as bool,
              ),
          ],
          documentos: [
            for (final d in (j['documentos'] as List).cast<Map<String, dynamic>>())
              Documento(
                id: d['id'] as String,
                perfilId: d['perfil'] as String,
                nombre: d['nombre'] as String,
                categoria: Categoria.values.asNameMap()[d['categoria']] ?? Categoria.otro,
                guardadoEn: DateTime.fromMillisecondsSinceEpoch(d['guardado'] as int),
                paginas: d['paginas'] as int,
                tamanoBytes: d['bytes'] as int,
                venceEn: d['vence'] == null ? null : DateTime.fromMillisecondsSinceEpoch(d['vence'] as int),
                archivo: d['archivo'] as String?,
                textoExtraido: d['texto'] as String? ?? '',
              ),
          ],
          descartadas: {...(j['descartadas'] as List).cast<String>()},
        ),
      );
    } on CopiaIlegible {
      rethrow;
    } catch (_) {
      throw const CopiaIlegible();
    }
  }
}
