// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_datos.dart';

// ignore_for_file: type=lint
class $PerfilesTable extends Perfiles with TableInfo<$PerfilesTable, PerfilFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PerfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inicialMeta = const VerificationMeta('inicial');
  @override
  late final GeneratedColumn<String> inicial = GeneratedColumn<String>(
    'inicial',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TipoPerfil, String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TipoPerfil>($PerfilesTable.$convertertipo);
  static const VerificationMeta _esPropioMeta = const VerificationMeta('esPropio');
  @override
  late final GeneratedColumn<bool> esPropio = GeneratedColumn<bool>(
    'es_propio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("es_propio" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta('creadoEn');
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, inicial, color, tipo, esPropio, creadoEn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'perfiles';
  @override
  VerificationContext validateIntegrity(Insertable<PerfilFila> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(_nombreMeta, nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta));
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('inicial')) {
      context.handle(_inicialMeta, inicial.isAcceptableOrUnknown(data['inicial']!, _inicialMeta));
    } else if (isInserting) {
      context.missing(_inicialMeta);
    }
    if (data.containsKey('color')) {
      context.handle(_colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('es_propio')) {
      context.handle(_esPropioMeta, esPropio.isAcceptableOrUnknown(data['es_propio']!, _esPropioMeta));
    }
    if (data.containsKey('creado_en')) {
      context.handle(_creadoEnMeta, creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PerfilFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PerfilFila(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      nombre: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}nombre'])!,
      inicial: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}inicial'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      tipo: $PerfilesTable.$convertertipo.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tipo'])!,
      ),
      esPropio: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}es_propio'])!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $PerfilesTable createAlias(String alias) {
    return $PerfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TipoPerfil, String, String> $convertertipo = const EnumNameConverter<TipoPerfil>(
    TipoPerfil.values,
  );
}

class PerfilFila extends DataClass implements Insertable<PerfilFila> {
  final String id;
  final String nombre;
  final String inicial;

  /// Color en formato ARGB (0xFF5160EC).
  final int color;
  final TipoPerfil tipo;
  final bool esPropio;
  final DateTime creadoEn;
  const PerfilFila({
    required this.id,
    required this.nombre,
    required this.inicial,
    required this.color,
    required this.tipo,
    required this.esPropio,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['inicial'] = Variable<String>(inicial);
    map['color'] = Variable<int>(color);
    {
      map['tipo'] = Variable<String>($PerfilesTable.$convertertipo.toSql(tipo));
    }
    map['es_propio'] = Variable<bool>(esPropio);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  PerfilesCompanion toCompanion(bool nullToAbsent) {
    return PerfilesCompanion(
      id: Value(id),
      nombre: Value(nombre),
      inicial: Value(inicial),
      color: Value(color),
      tipo: Value(tipo),
      esPropio: Value(esPropio),
      creadoEn: Value(creadoEn),
    );
  }

  factory PerfilFila.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PerfilFila(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      inicial: serializer.fromJson<String>(json['inicial']),
      color: serializer.fromJson<int>(json['color']),
      tipo: $PerfilesTable.$convertertipo.fromJson(serializer.fromJson<String>(json['tipo'])),
      esPropio: serializer.fromJson<bool>(json['esPropio']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'inicial': serializer.toJson<String>(inicial),
      'color': serializer.toJson<int>(color),
      'tipo': serializer.toJson<String>($PerfilesTable.$convertertipo.toJson(tipo)),
      'esPropio': serializer.toJson<bool>(esPropio),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  PerfilFila copyWith({
    String? id,
    String? nombre,
    String? inicial,
    int? color,
    TipoPerfil? tipo,
    bool? esPropio,
    DateTime? creadoEn,
  }) => PerfilFila(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    inicial: inicial ?? this.inicial,
    color: color ?? this.color,
    tipo: tipo ?? this.tipo,
    esPropio: esPropio ?? this.esPropio,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  PerfilFila copyWithCompanion(PerfilesCompanion data) {
    return PerfilFila(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      inicial: data.inicial.present ? data.inicial.value : this.inicial,
      color: data.color.present ? data.color.value : this.color,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      esPropio: data.esPropio.present ? data.esPropio.value : this.esPropio,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PerfilFila(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('inicial: $inicial, ')
          ..write('color: $color, ')
          ..write('tipo: $tipo, ')
          ..write('esPropio: $esPropio, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, inicial, color, tipo, esPropio, creadoEn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PerfilFila &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.inicial == this.inicial &&
          other.color == this.color &&
          other.tipo == this.tipo &&
          other.esPropio == this.esPropio &&
          other.creadoEn == this.creadoEn);
}

class PerfilesCompanion extends UpdateCompanion<PerfilFila> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String> inicial;
  final Value<int> color;
  final Value<TipoPerfil> tipo;
  final Value<bool> esPropio;
  final Value<DateTime> creadoEn;
  final Value<int> rowid;
  const PerfilesCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.inicial = const Value.absent(),
    this.color = const Value.absent(),
    this.tipo = const Value.absent(),
    this.esPropio = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PerfilesCompanion.insert({
    required String id,
    required String nombre,
    required String inicial,
    required int color,
    required TipoPerfil tipo,
    this.esPropio = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       inicial = Value(inicial),
       color = Value(color),
       tipo = Value(tipo);
  static Insertable<PerfilFila> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? inicial,
    Expression<int>? color,
    Expression<String>? tipo,
    Expression<bool>? esPropio,
    Expression<DateTime>? creadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (inicial != null) 'inicial': inicial,
      if (color != null) 'color': color,
      if (tipo != null) 'tipo': tipo,
      if (esPropio != null) 'es_propio': esPropio,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PerfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String>? inicial,
    Value<int>? color,
    Value<TipoPerfil>? tipo,
    Value<bool>? esPropio,
    Value<DateTime>? creadoEn,
    Value<int>? rowid,
  }) {
    return PerfilesCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      inicial: inicial ?? this.inicial,
      color: color ?? this.color,
      tipo: tipo ?? this.tipo,
      esPropio: esPropio ?? this.esPropio,
      creadoEn: creadoEn ?? this.creadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (inicial.present) {
      map['inicial'] = Variable<String>(inicial.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>($PerfilesTable.$convertertipo.toSql(tipo.value));
    }
    if (esPropio.present) {
      map['es_propio'] = Variable<bool>(esPropio.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PerfilesCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('inicial: $inicial, ')
          ..write('color: $color, ')
          ..write('tipo: $tipo, ')
          ..write('esPropio: $esPropio, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentosTable extends Documentos with TableInfo<$DocumentosTable, DocumentoFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _perfilIdMeta = const VerificationMeta('perfilId');
  @override
  late final GeneratedColumn<String> perfilId = GeneratedColumn<String>(
    'perfil_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES perfiles (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Categoria, String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Categoria>($DocumentosTable.$convertercategoria);
  static const VerificationMeta _paginasMeta = const VerificationMeta('paginas');
  @override
  late final GeneratedColumn<int> paginas = GeneratedColumn<int>(
    'paginas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _tamanoBytesMeta = const VerificationMeta('tamanoBytes');
  @override
  late final GeneratedColumn<int> tamanoBytes = GeneratedColumn<int>(
    'tamano_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _guardadoEnMeta = const VerificationMeta('guardadoEn');
  @override
  late final GeneratedColumn<DateTime> guardadoEn = GeneratedColumn<DateTime>(
    'guardado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _venceEnMeta = const VerificationMeta('venceEn');
  @override
  late final GeneratedColumn<DateTime> venceEn = GeneratedColumn<DateTime>(
    'vence_en',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivoMeta = const VerificationMeta('archivo');
  @override
  late final GeneratedColumn<String> archivo = GeneratedColumn<String>(
    'archivo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textoExtraidoMeta = const VerificationMeta('textoExtraido');
  @override
  late final GeneratedColumn<String> textoExtraido = GeneratedColumn<String>(
    'texto_extraido',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    perfilId,
    nombre,
    categoria,
    paginas,
    tamanoBytes,
    guardadoEn,
    venceEn,
    archivo,
    textoExtraido,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documentos';
  @override
  VerificationContext validateIntegrity(Insertable<DocumentoFila> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('perfil_id')) {
      context.handle(_perfilIdMeta, perfilId.isAcceptableOrUnknown(data['perfil_id']!, _perfilIdMeta));
    } else if (isInserting) {
      context.missing(_perfilIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(_nombreMeta, nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta));
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('paginas')) {
      context.handle(_paginasMeta, paginas.isAcceptableOrUnknown(data['paginas']!, _paginasMeta));
    }
    if (data.containsKey('tamano_bytes')) {
      context.handle(
        _tamanoBytesMeta,
        tamanoBytes.isAcceptableOrUnknown(data['tamano_bytes']!, _tamanoBytesMeta),
      );
    }
    if (data.containsKey('guardado_en')) {
      context.handle(
        _guardadoEnMeta,
        guardadoEn.isAcceptableOrUnknown(data['guardado_en']!, _guardadoEnMeta),
      );
    } else if (isInserting) {
      context.missing(_guardadoEnMeta);
    }
    if (data.containsKey('vence_en')) {
      context.handle(_venceEnMeta, venceEn.isAcceptableOrUnknown(data['vence_en']!, _venceEnMeta));
    }
    if (data.containsKey('archivo')) {
      context.handle(_archivoMeta, archivo.isAcceptableOrUnknown(data['archivo']!, _archivoMeta));
    }
    if (data.containsKey('texto_extraido')) {
      context.handle(
        _textoExtraidoMeta,
        textoExtraido.isAcceptableOrUnknown(data['texto_extraido']!, _textoExtraidoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentoFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentoFila(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      perfilId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}perfil_id'])!,
      nombre: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}nombre'])!,
      categoria: $DocumentosTable.$convertercategoria.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}categoria'])!,
      ),
      paginas: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}paginas'])!,
      tamanoBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tamano_bytes'],
      )!,
      guardadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}guardado_en'],
      )!,
      venceEn: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}vence_en']),
      archivo: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}archivo']),
      textoExtraido: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}texto_extraido'],
      )!,
    );
  }

  @override
  $DocumentosTable createAlias(String alias) {
    return $DocumentosTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Categoria, String, String> $convertercategoria =
      const EnumNameConverter<Categoria>(Categoria.values);
}

class DocumentoFila extends DataClass implements Insertable<DocumentoFila> {
  final String id;

  /// Si se borra el perfil, se borran sus documentos.
  final String perfilId;
  final String nombre;
  final Categoria categoria;
  final int paginas;
  final int tamanoBytes;
  final DateTime guardadoEn;
  final DateTime? venceEn;

  /// Ruta relativa del archivo cifrado (null mientras la cámara es simulada).
  final String? archivo;

  /// Texto leído del documento; alimenta la búsqueda y "Pregúntale".
  final String textoExtraido;
  const DocumentoFila({
    required this.id,
    required this.perfilId,
    required this.nombre,
    required this.categoria,
    required this.paginas,
    required this.tamanoBytes,
    required this.guardadoEn,
    this.venceEn,
    this.archivo,
    required this.textoExtraido,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['perfil_id'] = Variable<String>(perfilId);
    map['nombre'] = Variable<String>(nombre);
    {
      map['categoria'] = Variable<String>($DocumentosTable.$convertercategoria.toSql(categoria));
    }
    map['paginas'] = Variable<int>(paginas);
    map['tamano_bytes'] = Variable<int>(tamanoBytes);
    map['guardado_en'] = Variable<DateTime>(guardadoEn);
    if (!nullToAbsent || venceEn != null) {
      map['vence_en'] = Variable<DateTime>(venceEn);
    }
    if (!nullToAbsent || archivo != null) {
      map['archivo'] = Variable<String>(archivo);
    }
    map['texto_extraido'] = Variable<String>(textoExtraido);
    return map;
  }

  DocumentosCompanion toCompanion(bool nullToAbsent) {
    return DocumentosCompanion(
      id: Value(id),
      perfilId: Value(perfilId),
      nombre: Value(nombre),
      categoria: Value(categoria),
      paginas: Value(paginas),
      tamanoBytes: Value(tamanoBytes),
      guardadoEn: Value(guardadoEn),
      venceEn: venceEn == null && nullToAbsent ? const Value.absent() : Value(venceEn),
      archivo: archivo == null && nullToAbsent ? const Value.absent() : Value(archivo),
      textoExtraido: Value(textoExtraido),
    );
  }

  factory DocumentoFila.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentoFila(
      id: serializer.fromJson<String>(json['id']),
      perfilId: serializer.fromJson<String>(json['perfilId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      categoria: $DocumentosTable.$convertercategoria.fromJson(
        serializer.fromJson<String>(json['categoria']),
      ),
      paginas: serializer.fromJson<int>(json['paginas']),
      tamanoBytes: serializer.fromJson<int>(json['tamanoBytes']),
      guardadoEn: serializer.fromJson<DateTime>(json['guardadoEn']),
      venceEn: serializer.fromJson<DateTime?>(json['venceEn']),
      archivo: serializer.fromJson<String?>(json['archivo']),
      textoExtraido: serializer.fromJson<String>(json['textoExtraido']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'perfilId': serializer.toJson<String>(perfilId),
      'nombre': serializer.toJson<String>(nombre),
      'categoria': serializer.toJson<String>($DocumentosTable.$convertercategoria.toJson(categoria)),
      'paginas': serializer.toJson<int>(paginas),
      'tamanoBytes': serializer.toJson<int>(tamanoBytes),
      'guardadoEn': serializer.toJson<DateTime>(guardadoEn),
      'venceEn': serializer.toJson<DateTime?>(venceEn),
      'archivo': serializer.toJson<String?>(archivo),
      'textoExtraido': serializer.toJson<String>(textoExtraido),
    };
  }

  DocumentoFila copyWith({
    String? id,
    String? perfilId,
    String? nombre,
    Categoria? categoria,
    int? paginas,
    int? tamanoBytes,
    DateTime? guardadoEn,
    Value<DateTime?> venceEn = const Value.absent(),
    Value<String?> archivo = const Value.absent(),
    String? textoExtraido,
  }) => DocumentoFila(
    id: id ?? this.id,
    perfilId: perfilId ?? this.perfilId,
    nombre: nombre ?? this.nombre,
    categoria: categoria ?? this.categoria,
    paginas: paginas ?? this.paginas,
    tamanoBytes: tamanoBytes ?? this.tamanoBytes,
    guardadoEn: guardadoEn ?? this.guardadoEn,
    venceEn: venceEn.present ? venceEn.value : this.venceEn,
    archivo: archivo.present ? archivo.value : this.archivo,
    textoExtraido: textoExtraido ?? this.textoExtraido,
  );
  DocumentoFila copyWithCompanion(DocumentosCompanion data) {
    return DocumentoFila(
      id: data.id.present ? data.id.value : this.id,
      perfilId: data.perfilId.present ? data.perfilId.value : this.perfilId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      paginas: data.paginas.present ? data.paginas.value : this.paginas,
      tamanoBytes: data.tamanoBytes.present ? data.tamanoBytes.value : this.tamanoBytes,
      guardadoEn: data.guardadoEn.present ? data.guardadoEn.value : this.guardadoEn,
      venceEn: data.venceEn.present ? data.venceEn.value : this.venceEn,
      archivo: data.archivo.present ? data.archivo.value : this.archivo,
      textoExtraido: data.textoExtraido.present ? data.textoExtraido.value : this.textoExtraido,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentoFila(')
          ..write('id: $id, ')
          ..write('perfilId: $perfilId, ')
          ..write('nombre: $nombre, ')
          ..write('categoria: $categoria, ')
          ..write('paginas: $paginas, ')
          ..write('tamanoBytes: $tamanoBytes, ')
          ..write('guardadoEn: $guardadoEn, ')
          ..write('venceEn: $venceEn, ')
          ..write('archivo: $archivo, ')
          ..write('textoExtraido: $textoExtraido')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    perfilId,
    nombre,
    categoria,
    paginas,
    tamanoBytes,
    guardadoEn,
    venceEn,
    archivo,
    textoExtraido,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentoFila &&
          other.id == this.id &&
          other.perfilId == this.perfilId &&
          other.nombre == this.nombre &&
          other.categoria == this.categoria &&
          other.paginas == this.paginas &&
          other.tamanoBytes == this.tamanoBytes &&
          other.guardadoEn == this.guardadoEn &&
          other.venceEn == this.venceEn &&
          other.archivo == this.archivo &&
          other.textoExtraido == this.textoExtraido);
}

class DocumentosCompanion extends UpdateCompanion<DocumentoFila> {
  final Value<String> id;
  final Value<String> perfilId;
  final Value<String> nombre;
  final Value<Categoria> categoria;
  final Value<int> paginas;
  final Value<int> tamanoBytes;
  final Value<DateTime> guardadoEn;
  final Value<DateTime?> venceEn;
  final Value<String?> archivo;
  final Value<String> textoExtraido;
  final Value<int> rowid;
  const DocumentosCompanion({
    this.id = const Value.absent(),
    this.perfilId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.categoria = const Value.absent(),
    this.paginas = const Value.absent(),
    this.tamanoBytes = const Value.absent(),
    this.guardadoEn = const Value.absent(),
    this.venceEn = const Value.absent(),
    this.archivo = const Value.absent(),
    this.textoExtraido = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentosCompanion.insert({
    required String id,
    required String perfilId,
    required String nombre,
    required Categoria categoria,
    this.paginas = const Value.absent(),
    this.tamanoBytes = const Value.absent(),
    required DateTime guardadoEn,
    this.venceEn = const Value.absent(),
    this.archivo = const Value.absent(),
    this.textoExtraido = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       perfilId = Value(perfilId),
       nombre = Value(nombre),
       categoria = Value(categoria),
       guardadoEn = Value(guardadoEn);
  static Insertable<DocumentoFila> custom({
    Expression<String>? id,
    Expression<String>? perfilId,
    Expression<String>? nombre,
    Expression<String>? categoria,
    Expression<int>? paginas,
    Expression<int>? tamanoBytes,
    Expression<DateTime>? guardadoEn,
    Expression<DateTime>? venceEn,
    Expression<String>? archivo,
    Expression<String>? textoExtraido,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (perfilId != null) 'perfil_id': perfilId,
      if (nombre != null) 'nombre': nombre,
      if (categoria != null) 'categoria': categoria,
      if (paginas != null) 'paginas': paginas,
      if (tamanoBytes != null) 'tamano_bytes': tamanoBytes,
      if (guardadoEn != null) 'guardado_en': guardadoEn,
      if (venceEn != null) 'vence_en': venceEn,
      if (archivo != null) 'archivo': archivo,
      if (textoExtraido != null) 'texto_extraido': textoExtraido,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentosCompanion copyWith({
    Value<String>? id,
    Value<String>? perfilId,
    Value<String>? nombre,
    Value<Categoria>? categoria,
    Value<int>? paginas,
    Value<int>? tamanoBytes,
    Value<DateTime>? guardadoEn,
    Value<DateTime?>? venceEn,
    Value<String?>? archivo,
    Value<String>? textoExtraido,
    Value<int>? rowid,
  }) {
    return DocumentosCompanion(
      id: id ?? this.id,
      perfilId: perfilId ?? this.perfilId,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      paginas: paginas ?? this.paginas,
      tamanoBytes: tamanoBytes ?? this.tamanoBytes,
      guardadoEn: guardadoEn ?? this.guardadoEn,
      venceEn: venceEn ?? this.venceEn,
      archivo: archivo ?? this.archivo,
      textoExtraido: textoExtraido ?? this.textoExtraido,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (perfilId.present) {
      map['perfil_id'] = Variable<String>(perfilId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>($DocumentosTable.$convertercategoria.toSql(categoria.value));
    }
    if (paginas.present) {
      map['paginas'] = Variable<int>(paginas.value);
    }
    if (tamanoBytes.present) {
      map['tamano_bytes'] = Variable<int>(tamanoBytes.value);
    }
    if (guardadoEn.present) {
      map['guardado_en'] = Variable<DateTime>(guardadoEn.value);
    }
    if (venceEn.present) {
      map['vence_en'] = Variable<DateTime>(venceEn.value);
    }
    if (archivo.present) {
      map['archivo'] = Variable<String>(archivo.value);
    }
    if (textoExtraido.present) {
      map['texto_extraido'] = Variable<String>(textoExtraido.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentosCompanion(')
          ..write('id: $id, ')
          ..write('perfilId: $perfilId, ')
          ..write('nombre: $nombre, ')
          ..write('categoria: $categoria, ')
          ..write('paginas: $paginas, ')
          ..write('tamanoBytes: $tamanoBytes, ')
          ..write('guardadoEn: $guardadoEn, ')
          ..write('venceEn: $venceEn, ')
          ..write('archivo: $archivo, ')
          ..write('textoExtraido: $textoExtraido, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AjustesTable extends Ajustes with TableInfo<$AjustesTable, AjusteFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AjustesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
    'clave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [clave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ajustes';
  @override
  VerificationContext validateIntegrity(Insertable<AjusteFila> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clave')) {
      context.handle(_claveMeta, clave.isAcceptableOrUnknown(data['clave']!, _claveMeta));
    } else if (isInserting) {
      context.missing(_claveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(_valorMeta, valor.isAcceptableOrUnknown(data['valor']!, _valorMeta));
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clave};
  @override
  AjusteFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AjusteFila(
      clave: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}clave'])!,
      valor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}valor'])!,
    );
  }

  @override
  $AjustesTable createAlias(String alias) {
    return $AjustesTable(attachedDatabase, alias);
  }
}

class AjusteFila extends DataClass implements Insertable<AjusteFila> {
  final String clave;
  final String valor;
  const AjusteFila({required this.clave, required this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clave'] = Variable<String>(clave);
    map['valor'] = Variable<String>(valor);
    return map;
  }

  AjustesCompanion toCompanion(bool nullToAbsent) {
    return AjustesCompanion(clave: Value(clave), valor: Value(valor));
  }

  factory AjusteFila.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AjusteFila(
      clave: serializer.fromJson<String>(json['clave']),
      valor: serializer.fromJson<String>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clave': serializer.toJson<String>(clave),
      'valor': serializer.toJson<String>(valor),
    };
  }

  AjusteFila copyWith({String? clave, String? valor}) =>
      AjusteFila(clave: clave ?? this.clave, valor: valor ?? this.valor);
  AjusteFila copyWithCompanion(AjustesCompanion data) {
    return AjusteFila(
      clave: data.clave.present ? data.clave.value : this.clave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AjusteFila(')
          ..write('clave: $clave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AjusteFila && other.clave == this.clave && other.valor == this.valor);
}

class AjustesCompanion extends UpdateCompanion<AjusteFila> {
  final Value<String> clave;
  final Value<String> valor;
  final Value<int> rowid;
  const AjustesCompanion({
    this.clave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AjustesCompanion.insert({required String clave, required String valor, this.rowid = const Value.absent()})
    : clave = Value(clave),
      valor = Value(valor);
  static Insertable<AjusteFila> custom({
    Expression<String>? clave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clave != null) 'clave': clave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AjustesCompanion copyWith({Value<String>? clave, Value<String>? valor, Value<int>? rowid}) {
    return AjustesCompanion(
      clave: clave ?? this.clave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AjustesCompanion(')
          ..write('clave: $clave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SugerenciasDescartadasTable extends SugerenciasDescartadas
    with TableInfo<$SugerenciasDescartadasTable, SugerenciaDescartadaFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SugerenciasDescartadasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
    'clave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descartadaEnMeta = const VerificationMeta('descartadaEn');
  @override
  late final GeneratedColumn<DateTime> descartadaEn = GeneratedColumn<DateTime>(
    'descartada_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [clave, descartadaEn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sugerencias_descartadas';
  @override
  VerificationContext validateIntegrity(
    Insertable<SugerenciaDescartadaFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clave')) {
      context.handle(_claveMeta, clave.isAcceptableOrUnknown(data['clave']!, _claveMeta));
    } else if (isInserting) {
      context.missing(_claveMeta);
    }
    if (data.containsKey('descartada_en')) {
      context.handle(
        _descartadaEnMeta,
        descartadaEn.isAcceptableOrUnknown(data['descartada_en']!, _descartadaEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clave};
  @override
  SugerenciaDescartadaFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SugerenciaDescartadaFila(
      clave: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}clave'])!,
      descartadaEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}descartada_en'],
      )!,
    );
  }

  @override
  $SugerenciasDescartadasTable createAlias(String alias) {
    return $SugerenciasDescartadasTable(attachedDatabase, alias);
  }
}

class SugerenciaDescartadaFila extends DataClass implements Insertable<SugerenciaDescartadaFila> {
  final String clave;
  final DateTime descartadaEn;
  const SugerenciaDescartadaFila({required this.clave, required this.descartadaEn});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clave'] = Variable<String>(clave);
    map['descartada_en'] = Variable<DateTime>(descartadaEn);
    return map;
  }

  SugerenciasDescartadasCompanion toCompanion(bool nullToAbsent) {
    return SugerenciasDescartadasCompanion(clave: Value(clave), descartadaEn: Value(descartadaEn));
  }

  factory SugerenciaDescartadaFila.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SugerenciaDescartadaFila(
      clave: serializer.fromJson<String>(json['clave']),
      descartadaEn: serializer.fromJson<DateTime>(json['descartadaEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clave': serializer.toJson<String>(clave),
      'descartadaEn': serializer.toJson<DateTime>(descartadaEn),
    };
  }

  SugerenciaDescartadaFila copyWith({String? clave, DateTime? descartadaEn}) =>
      SugerenciaDescartadaFila(clave: clave ?? this.clave, descartadaEn: descartadaEn ?? this.descartadaEn);
  SugerenciaDescartadaFila copyWithCompanion(SugerenciasDescartadasCompanion data) {
    return SugerenciaDescartadaFila(
      clave: data.clave.present ? data.clave.value : this.clave,
      descartadaEn: data.descartadaEn.present ? data.descartadaEn.value : this.descartadaEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SugerenciaDescartadaFila(')
          ..write('clave: $clave, ')
          ..write('descartadaEn: $descartadaEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clave, descartadaEn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SugerenciaDescartadaFila &&
          other.clave == this.clave &&
          other.descartadaEn == this.descartadaEn);
}

class SugerenciasDescartadasCompanion extends UpdateCompanion<SugerenciaDescartadaFila> {
  final Value<String> clave;
  final Value<DateTime> descartadaEn;
  final Value<int> rowid;
  const SugerenciasDescartadasCompanion({
    this.clave = const Value.absent(),
    this.descartadaEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SugerenciasDescartadasCompanion.insert({
    required String clave,
    this.descartadaEn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clave = Value(clave);
  static Insertable<SugerenciaDescartadaFila> custom({
    Expression<String>? clave,
    Expression<DateTime>? descartadaEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clave != null) 'clave': clave,
      if (descartadaEn != null) 'descartada_en': descartadaEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SugerenciasDescartadasCompanion copyWith({
    Value<String>? clave,
    Value<DateTime>? descartadaEn,
    Value<int>? rowid,
  }) {
    return SugerenciasDescartadasCompanion(
      clave: clave ?? this.clave,
      descartadaEn: descartadaEn ?? this.descartadaEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (descartadaEn.present) {
      map['descartada_en'] = Variable<DateTime>(descartadaEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SugerenciasDescartadasCompanion(')
          ..write('clave: $clave, ')
          ..write('descartadaEn: $descartadaEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BaseDatos extends GeneratedDatabase {
  _$BaseDatos(QueryExecutor e) : super(e);
  $BaseDatosManager get managers => $BaseDatosManager(this);
  late final $PerfilesTable perfiles = $PerfilesTable(this);
  late final $DocumentosTable documentos = $DocumentosTable(this);
  late final $AjustesTable ajustes = $AjustesTable(this);
  late final $SugerenciasDescartadasTable sugerenciasDescartadas = $SugerenciasDescartadasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [perfiles, documentos, ajustes, sugerenciasDescartadas];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('perfiles', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('documentos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PerfilesTableCreateCompanionBuilder = PerfilesCompanion Function({
  required String id,
  required String nombre,
  required String inicial,
  required int color,
  required TipoPerfil tipo,
  Value<bool> esPropio,
  Value<DateTime> creadoEn,
  Value<int> rowid,
});
typedef $$PerfilesTableUpdateCompanionBuilder = PerfilesCompanion Function({
  Value<String> id,
  Value<String> nombre,
  Value<String> inicial,
  Value<int> color,
  Value<TipoPerfil> tipo,
  Value<bool> esPropio,
  Value<DateTime> creadoEn,
  Value<int> rowid,
});

final class $$PerfilesTableReferences extends BaseReferences<_$BaseDatos, $PerfilesTable, PerfilFila> {
  $$PerfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DocumentosTable, List<DocumentoFila>> _documentosRefsTable(_$BaseDatos db) =>
      MultiTypedResultKey.fromTable(db.documentos, aliasName: 'perfiles__id__documentos__perfil_id');

  $$DocumentosTableProcessedTableManager get documentosRefs {
    final manager = $$DocumentosTableTableManager(
      $_db,
      $_db.documentos,
    ).filter((f) => f.perfilId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentosRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PerfilesTableFilterComposer extends Composer<_$BaseDatos, $PerfilesTable> {
  $$PerfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inicial =>
      $composableBuilder(column: $table.inicial, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TipoPerfil, TipoPerfil, String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get esPropio =>
      $composableBuilder(column: $table.esPropio, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => ColumnFilters(column));

  Expression<bool> documentosRefs(Expression<bool> Function($$DocumentosTableFilterComposer f) f) {
    final $$DocumentosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentos,
      getReferencedColumn: (t) => t.perfilId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$DocumentosTableFilterComposer(
            $db: $db,
            $table: $db.documentos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PerfilesTableOrderingComposer extends Composer<_$BaseDatos, $PerfilesTable> {
  $$PerfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inicial =>
      $composableBuilder(column: $table.inicial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get esPropio =>
      $composableBuilder(column: $table.esPropio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => ColumnOrderings(column));
}

class $$PerfilesTableAnnotationComposer extends Composer<_$BaseDatos, $PerfilesTable> {
  $$PerfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get inicial =>
      $composableBuilder(column: $table.inicial, builder: (column) => column);

  GeneratedColumn<int> get color => $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TipoPerfil, String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<bool> get esPropio =>
      $composableBuilder(column: $table.esPropio, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  Expression<T> documentosRefs<T extends Object>(
    Expression<T> Function($$DocumentosTableAnnotationComposer a) f,
  ) {
    final $$DocumentosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentos,
      getReferencedColumn: (t) => t.perfilId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$DocumentosTableAnnotationComposer(
            $db: $db,
            $table: $db.documentos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PerfilesTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $PerfilesTable,
          PerfilFila,
          $$PerfilesTableFilterComposer,
          $$PerfilesTableOrderingComposer,
          $$PerfilesTableAnnotationComposer,
          $$PerfilesTableCreateCompanionBuilder,
          $$PerfilesTableUpdateCompanionBuilder,
          (PerfilFila, $$PerfilesTableReferences),
          PerfilFila,
          PrefetchHooks Function({bool documentosRefs})
        > {
  $$PerfilesTableTableManager(_$BaseDatos db, $PerfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PerfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PerfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PerfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> inicial = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<TipoPerfil> tipo = const Value.absent(),
                Value<bool> esPropio = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerfilesCompanion(
                id: id,
                nombre: nombre,
                inicial: inicial,
                color: color,
                tipo: tipo,
                esPropio: esPropio,
                creadoEn: creadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required String inicial,
                required int color,
                required TipoPerfil tipo,
                Value<bool> esPropio = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerfilesCompanion.insert(
                id: id,
                nombre: nombre,
                inicial: inicial,
                color: color,
                tipo: tipo,
                esPropio: esPropio,
                creadoEn: creadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<$PerfilesTable, PerfilFila>(table), $$PerfilesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({documentosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (documentosRefs) db.documentos],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (documentosRefs)
                    await $_getPrefetchedData<PerfilFila, $PerfilesTable, DocumentoFila>(
                      currentTable: table,
                      referencedTable: $$PerfilesTableReferences._documentosRefsTable(db),
                      managerFromTypedResult: (p0) => $$PerfilesTableReferences(db, table, p0).documentosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.perfilId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PerfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $PerfilesTable,
      PerfilFila,
      $$PerfilesTableFilterComposer,
      $$PerfilesTableOrderingComposer,
      $$PerfilesTableAnnotationComposer,
      $$PerfilesTableCreateCompanionBuilder,
      $$PerfilesTableUpdateCompanionBuilder,
      (PerfilFila, $$PerfilesTableReferences),
      PerfilFila,
      PrefetchHooks Function({bool documentosRefs})
    >;
typedef $$DocumentosTableCreateCompanionBuilder = DocumentosCompanion Function({
  required String id,
  required String perfilId,
  required String nombre,
  required Categoria categoria,
  Value<int> paginas,
  Value<int> tamanoBytes,
  required DateTime guardadoEn,
  Value<DateTime?> venceEn,
  Value<String?> archivo,
  Value<String> textoExtraido,
  Value<int> rowid,
});
typedef $$DocumentosTableUpdateCompanionBuilder = DocumentosCompanion Function({
  Value<String> id,
  Value<String> perfilId,
  Value<String> nombre,
  Value<Categoria> categoria,
  Value<int> paginas,
  Value<int> tamanoBytes,
  Value<DateTime> guardadoEn,
  Value<DateTime?> venceEn,
  Value<String?> archivo,
  Value<String> textoExtraido,
  Value<int> rowid,
});

final class $$DocumentosTableReferences extends BaseReferences<_$BaseDatos, $DocumentosTable, DocumentoFila> {
  $$DocumentosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PerfilesTable _perfilIdTable(_$BaseDatos db) =>
      db.perfiles.createAlias('documentos__perfil_id__perfiles__id');

  $$PerfilesTableProcessedTableManager get perfilId {
    final $_column = $_itemColumn<String>('perfil_id')!;

    final manager = $$PerfilesTableTableManager($_db, $_db.perfiles).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_perfilIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DocumentosTableFilterComposer extends Composer<_$BaseDatos, $DocumentosTable> {
  $$DocumentosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Categoria, Categoria, String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get paginas =>
      $composableBuilder(column: $table.paginas, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tamanoBytes =>
      $composableBuilder(column: $table.tamanoBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get guardadoEn =>
      $composableBuilder(column: $table.guardadoEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get venceEn =>
      $composableBuilder(column: $table.venceEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get archivo =>
      $composableBuilder(column: $table.archivo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textoExtraido =>
      $composableBuilder(column: $table.textoExtraido, builder: (column) => ColumnFilters(column));

  $$PerfilesTableFilterComposer get perfilId {
    final $$PerfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.perfilId,
      referencedTable: $db.perfiles,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PerfilesTableFilterComposer(
            $db: $db,
            $table: $db.perfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentosTableOrderingComposer extends Composer<_$BaseDatos, $DocumentosTable> {
  $$DocumentosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paginas =>
      $composableBuilder(column: $table.paginas, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tamanoBytes =>
      $composableBuilder(column: $table.tamanoBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get guardadoEn =>
      $composableBuilder(column: $table.guardadoEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get venceEn =>
      $composableBuilder(column: $table.venceEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get archivo =>
      $composableBuilder(column: $table.archivo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textoExtraido =>
      $composableBuilder(column: $table.textoExtraido, builder: (column) => ColumnOrderings(column));

  $$PerfilesTableOrderingComposer get perfilId {
    final $$PerfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.perfilId,
      referencedTable: $db.perfiles,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PerfilesTableOrderingComposer(
            $db: $db,
            $table: $db.perfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentosTableAnnotationComposer extends Composer<_$BaseDatos, $DocumentosTable> {
  $$DocumentosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Categoria, String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get paginas => $composableBuilder(column: $table.paginas, builder: (column) => column);

  GeneratedColumn<int> get tamanoBytes =>
      $composableBuilder(column: $table.tamanoBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get guardadoEn =>
      $composableBuilder(column: $table.guardadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get venceEn =>
      $composableBuilder(column: $table.venceEn, builder: (column) => column);

  GeneratedColumn<String> get archivo =>
      $composableBuilder(column: $table.archivo, builder: (column) => column);

  GeneratedColumn<String> get textoExtraido =>
      $composableBuilder(column: $table.textoExtraido, builder: (column) => column);

  $$PerfilesTableAnnotationComposer get perfilId {
    final $$PerfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.perfilId,
      referencedTable: $db.perfiles,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PerfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.perfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentosTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $DocumentosTable,
          DocumentoFila,
          $$DocumentosTableFilterComposer,
          $$DocumentosTableOrderingComposer,
          $$DocumentosTableAnnotationComposer,
          $$DocumentosTableCreateCompanionBuilder,
          $$DocumentosTableUpdateCompanionBuilder,
          (DocumentoFila, $$DocumentosTableReferences),
          DocumentoFila,
          PrefetchHooks Function({bool perfilId})
        > {
  $$DocumentosTableTableManager(_$BaseDatos db, $DocumentosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DocumentosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DocumentosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$DocumentosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> perfilId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<Categoria> categoria = const Value.absent(),
                Value<int> paginas = const Value.absent(),
                Value<int> tamanoBytes = const Value.absent(),
                Value<DateTime> guardadoEn = const Value.absent(),
                Value<DateTime?> venceEn = const Value.absent(),
                Value<String?> archivo = const Value.absent(),
                Value<String> textoExtraido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentosCompanion(
                id: id,
                perfilId: perfilId,
                nombre: nombre,
                categoria: categoria,
                paginas: paginas,
                tamanoBytes: tamanoBytes,
                guardadoEn: guardadoEn,
                venceEn: venceEn,
                archivo: archivo,
                textoExtraido: textoExtraido,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String perfilId,
                required String nombre,
                required Categoria categoria,
                Value<int> paginas = const Value.absent(),
                Value<int> tamanoBytes = const Value.absent(),
                required DateTime guardadoEn,
                Value<DateTime?> venceEn = const Value.absent(),
                Value<String?> archivo = const Value.absent(),
                Value<String> textoExtraido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentosCompanion.insert(
                id: id,
                perfilId: perfilId,
                nombre: nombre,
                categoria: categoria,
                paginas: paginas,
                tamanoBytes: tamanoBytes,
                guardadoEn: guardadoEn,
                venceEn: venceEn,
                archivo: archivo,
                textoExtraido: textoExtraido,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentosTable, DocumentoFila>(table),
                  $$DocumentosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({perfilId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (perfilId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.perfilId,
                        referencedTable: $$DocumentosTableReferences._perfilIdTable(db),
                        referencedColumn: $$DocumentosTableReferences._perfilIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentosTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $DocumentosTable,
      DocumentoFila,
      $$DocumentosTableFilterComposer,
      $$DocumentosTableOrderingComposer,
      $$DocumentosTableAnnotationComposer,
      $$DocumentosTableCreateCompanionBuilder,
      $$DocumentosTableUpdateCompanionBuilder,
      (DocumentoFila, $$DocumentosTableReferences),
      DocumentoFila,
      PrefetchHooks Function({bool perfilId})
    >;
typedef $$AjustesTableCreateCompanionBuilder = AjustesCompanion Function({
  required String clave,
  required String valor,
  Value<int> rowid,
});
typedef $$AjustesTableUpdateCompanionBuilder = AjustesCompanion Function({
  Value<String> clave,
  Value<String> valor,
  Value<int> rowid,
});

class $$AjustesTableFilterComposer extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => ColumnFilters(column));
}

class $$AjustesTableOrderingComposer extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => ColumnOrderings(column));
}

class $$AjustesTableAnnotationComposer extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clave => $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<String> get valor => $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$AjustesTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $AjustesTable,
          AjusteFila,
          $$AjustesTableFilterComposer,
          $$AjustesTableOrderingComposer,
          $$AjustesTableAnnotationComposer,
          $$AjustesTableCreateCompanionBuilder,
          $$AjustesTableUpdateCompanionBuilder,
          (AjusteFila, BaseReferences<_$BaseDatos, $AjustesTable, AjusteFila>),
          AjusteFila,
          PrefetchHooks Function()
        > {
  $$AjustesTableTableManager(_$BaseDatos db, $AjustesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AjustesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AjustesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AjustesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clave = const Value.absent(),
            Value<String> valor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AjustesCompanion(clave: clave, valor: valor, rowid: rowid),
          createCompanionCallback: ({
            required String clave,
            required String valor,
            Value<int> rowid = const Value.absent(),
          }) => AjustesCompanion.insert(clave: clave, valor: valor, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AjustesTable, AjusteFila>(table),
                  BaseReferences<_$BaseDatos, $AjustesTable, AjusteFila>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AjustesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $AjustesTable,
      AjusteFila,
      $$AjustesTableFilterComposer,
      $$AjustesTableOrderingComposer,
      $$AjustesTableAnnotationComposer,
      $$AjustesTableCreateCompanionBuilder,
      $$AjustesTableUpdateCompanionBuilder,
      (AjusteFila, BaseReferences<_$BaseDatos, $AjustesTable, AjusteFila>),
      AjusteFila,
      PrefetchHooks Function()
    >;
typedef $$SugerenciasDescartadasTableCreateCompanionBuilder = SugerenciasDescartadasCompanion Function({
  required String clave,
  Value<DateTime> descartadaEn,
  Value<int> rowid,
});
typedef $$SugerenciasDescartadasTableUpdateCompanionBuilder = SugerenciasDescartadasCompanion Function({
  Value<String> clave,
  Value<DateTime> descartadaEn,
  Value<int> rowid,
});

class $$SugerenciasDescartadasTableFilterComposer
    extends Composer<_$BaseDatos, $SugerenciasDescartadasTable> {
  $$SugerenciasDescartadasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get descartadaEn =>
      $composableBuilder(column: $table.descartadaEn, builder: (column) => ColumnFilters(column));
}

class $$SugerenciasDescartadasTableOrderingComposer
    extends Composer<_$BaseDatos, $SugerenciasDescartadasTable> {
  $$SugerenciasDescartadasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get descartadaEn =>
      $composableBuilder(column: $table.descartadaEn, builder: (column) => ColumnOrderings(column));
}

class $$SugerenciasDescartadasTableAnnotationComposer
    extends Composer<_$BaseDatos, $SugerenciasDescartadasTable> {
  $$SugerenciasDescartadasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clave => $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<DateTime> get descartadaEn =>
      $composableBuilder(column: $table.descartadaEn, builder: (column) => column);
}

class $$SugerenciasDescartadasTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $SugerenciasDescartadasTable,
          SugerenciaDescartadaFila,
          $$SugerenciasDescartadasTableFilterComposer,
          $$SugerenciasDescartadasTableOrderingComposer,
          $$SugerenciasDescartadasTableAnnotationComposer,
          $$SugerenciasDescartadasTableCreateCompanionBuilder,
          $$SugerenciasDescartadasTableUpdateCompanionBuilder,
          (
            SugerenciaDescartadaFila,
            BaseReferences<_$BaseDatos, $SugerenciasDescartadasTable, SugerenciaDescartadaFila>,
          ),
          SugerenciaDescartadaFila,
          PrefetchHooks Function()
        > {
  $$SugerenciasDescartadasTableTableManager(_$BaseDatos db, $SugerenciasDescartadasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SugerenciasDescartadasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SugerenciasDescartadasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SugerenciasDescartadasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clave = const Value.absent(),
            Value<DateTime> descartadaEn = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SugerenciasDescartadasCompanion(clave: clave, descartadaEn: descartadaEn, rowid: rowid),
          createCompanionCallback:
              ({
                required String clave,
                Value<DateTime> descartadaEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SugerenciasDescartadasCompanion.insert(
                clave: clave,
                descartadaEn: descartadaEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SugerenciasDescartadasTable, SugerenciaDescartadaFila>(table),
                  BaseReferences<_$BaseDatos, $SugerenciasDescartadasTable, SugerenciaDescartadaFila>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SugerenciasDescartadasTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $SugerenciasDescartadasTable,
      SugerenciaDescartadaFila,
      $$SugerenciasDescartadasTableFilterComposer,
      $$SugerenciasDescartadasTableOrderingComposer,
      $$SugerenciasDescartadasTableAnnotationComposer,
      $$SugerenciasDescartadasTableCreateCompanionBuilder,
      $$SugerenciasDescartadasTableUpdateCompanionBuilder,
      (
        SugerenciaDescartadaFila,
        BaseReferences<_$BaseDatos, $SugerenciasDescartadasTable, SugerenciaDescartadaFila>,
      ),
      SugerenciaDescartadaFila,
      PrefetchHooks Function()
    >;

class $BaseDatosManager {
  final _$BaseDatos _db;
  $BaseDatosManager(this._db);
  $$PerfilesTableTableManager get perfiles => $$PerfilesTableTableManager(_db, _db.perfiles);
  $$DocumentosTableTableManager get documentos => $$DocumentosTableTableManager(_db, _db.documentos);
  $$AjustesTableTableManager get ajustes => $$AjustesTableTableManager(_db, _db.ajustes);
  $$SugerenciasDescartadasTableTableManager get sugerenciasDescartadas =>
      $$SugerenciasDescartadasTableTableManager(_db, _db.sugerenciasDescartadas);
}
