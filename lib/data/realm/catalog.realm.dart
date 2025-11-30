part of 'catalog.dart';

class RealmImages extends _RealmImages with RealmEntity, RealmObjectBase, RealmObject {
  RealmImages({
    String? squareImageUrl,
    String? squareFullSizeImageUrl,
    String? wideImageUrl,
    String? wideFullSizeImageUrl,
    String? extraWideImageUrl,
    String? extraWideFullSizeImageUrl,
  }) {
    RealmObjectBase.set(this, 'SquareImageUrl', squareImageUrl);
    RealmObjectBase.set(this, 'SquareFullSizeImageUrl', squareFullSizeImageUrl);
    RealmObjectBase.set(this, 'WideImageUrl', wideImageUrl);
    RealmObjectBase.set(this, 'WideFullSizeImageUrl', wideFullSizeImageUrl);
    RealmObjectBase.set(this, 'ExtraWideImageUrl', extraWideImageUrl);
    RealmObjectBase.set(this, 'ExtraWideFullSizeImageUrl', extraWideFullSizeImageUrl);
  }

  RealmImages._();

  @override
  String? get squareImageUrl => RealmObjectBase.get<String>(this, 'SquareImageUrl') as String?;
  @override
  set squareImageUrl(String? value) => RealmObjectBase.set(this, 'SquareImageUrl', value);

  @override
  String? get squareFullSizeImageUrl => RealmObjectBase.get<String>(this, 'SquareFullSizeImageUrl') as String?;
  @override
  set squareFullSizeImageUrl(String? value) => RealmObjectBase.set(this, 'SquareFullSizeImageUrl', value);

  @override
  String? get wideImageUrl => RealmObjectBase.get<String>(this, 'WideImageUrl') as String?;
  @override
  set wideImageUrl(String? value) => RealmObjectBase.set(this, 'WideImageUrl', value);

  @override
  String? get wideFullSizeImageUrl => RealmObjectBase.get<String>(this, 'WideFullSizeImageUrl') as String?;
  @override
  set wideFullSizeImageUrl(String? value) => RealmObjectBase.set(this, 'WideFullSizeImageUrl', value);

  @override
  String? get extraWideImageUrl => RealmObjectBase.get<String>(this, 'ExtraWideImageUrl') as String?;
  @override
  set extraWideImageUrl(String? value) => RealmObjectBase.set(this, 'ExtraWideImageUrl', value);

  @override
  String? get extraWideFullSizeImageUrl => RealmObjectBase.get<String>(this, 'ExtraWideFullSizeImageUrl') as String?;
  @override
  set extraWideFullSizeImageUrl(String? value) => RealmObjectBase.set(this, 'ExtraWideFullSizeImageUrl', value);

  @override
  Stream<RealmObjectChanges<RealmImages>> get changes => RealmObjectBase.getChanges<RealmImages>(this);

  @override
  Stream<RealmObjectChanges<RealmImages>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<RealmImages>(this, keyPaths);

  @override
  RealmImages freeze() => RealmObjectBase.freezeObject<RealmImages>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'SquareImageUrl': squareImageUrl.toEJson(),
      'SquareFullSizeImageUrl': squareFullSizeImageUrl.toEJson(),
      'WideImageUrl': wideImageUrl.toEJson(),
      'WideFullSizeImageUrl': wideFullSizeImageUrl.toEJson(),
      'ExtraWideImageUrl': extraWideImageUrl.toEJson(),
      'ExtraWideFullSizeImageUrl': extraWideFullSizeImageUrl.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmImages value) => value.toEJson();
  static RealmImages _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return RealmImages(
      squareImageUrl: fromEJson(ejson['SquareImageUrl']),
      squareFullSizeImageUrl: fromEJson(ejson['SquareFullSizeImageUrl']),
      wideImageUrl: fromEJson(ejson['WideImageUrl']),
      wideFullSizeImageUrl: fromEJson(ejson['WideFullSizeImageUrl']),
      extraWideImageUrl: fromEJson(ejson['ExtraWideImageUrl']),
      extraWideFullSizeImageUrl: fromEJson(ejson['ExtraWideFullSizeImageUrl']),
    );
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmImages._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      RealmImages,
      'Images',
      [
        SchemaProperty('SquareImageUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('SquareFullSizeImageUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('WideImageUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('WideFullSizeImageUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('ExtraWideImageUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('ExtraWideFullSizeImageUrl', RealmPropertyType.string, optional: true),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmMediaItem extends _RealmMediaItem with RealmEntity, RealmObjectBase, RealmObject {
  RealmMediaItem(
    String? compoundKey,
    double duration,
    DateTime firstPublished,
    bool isConventionRelease, {
    int? documentId,
    int? issueDate,
    String? languageAgnosticNaturalKey,
    String? languageSymbol,
    String? naturalKey,
    Iterable<String> checksums = const [],
    RealmImages? images,
    String? type,
    String? remoteType,
    String? primaryCategory,
    String? pubSymbol,
    String? title,
    int? track,
  }) {
    RealmObjectBase.set(this, 'CompoundKey', compoundKey);
    RealmObjectBase.set(this, 'DocumentId', documentId);
    RealmObjectBase.set(this, 'Duration', duration);
    RealmObjectBase.set(this, 'FirstPublished', firstPublished);
    RealmObjectBase.set(this, 'IsConventionRelease', isConventionRelease);
    RealmObjectBase.set(this, 'IssueDate', issueDate);
    RealmObjectBase.set(this, 'LanguageAgnosticNaturalKey', languageAgnosticNaturalKey);
    RealmObjectBase.set(this, 'LanguageSymbol', languageSymbol);
    RealmObjectBase.set(this, 'NaturalKey', naturalKey);
    RealmObjectBase.set<RealmList<String>>(this, 'Checksums', RealmList<String>(checksums));
    RealmObjectBase.set(this, 'Images', images);
    RealmObjectBase.set(this, 'Type', type);
    RealmObjectBase.set(this, 'RemoteType', remoteType);
    RealmObjectBase.set(this, 'PrimaryCategory', primaryCategory);
    RealmObjectBase.set(this, 'PubSymbol', pubSymbol);
    RealmObjectBase.set(this, 'Title', title);
    RealmObjectBase.set(this, 'Track', track);
  }

  RealmMediaItem._();

  @override
  String? get compoundKey => RealmObjectBase.get<String>(this, 'CompoundKey') as String?;
  @override
  set compoundKey(String? value) => RealmObjectBase.set(this, 'CompoundKey', value);

  @override
  int? get documentId => RealmObjectBase.get<int>(this, 'DocumentId') as int?;
  @override
  set documentId(int? value) => RealmObjectBase.set(this, 'DocumentId', value);

  @override
  double get duration => RealmObjectBase.get<double>(this, 'Duration') as double;
  @override
  set duration(double value) => RealmObjectBase.set(this, 'Duration', value);

  @override
  DateTime get firstPublished => RealmObjectBase.get<DateTime>(this, 'FirstPublished') as DateTime;
  @override
  set firstPublished(DateTime value) => RealmObjectBase.set(this, 'FirstPublished', value);

  @override
  bool get isConventionRelease => RealmObjectBase.get<bool>(this, 'IsConventionRelease') as bool;
  @override
  set isConventionRelease(bool value) => RealmObjectBase.set(this, 'IsConventionRelease', value);

  @override
  int? get issueDate => RealmObjectBase.get<int>(this, 'IssueDate') as int?;
  @override
  set issueDate(int? value) => RealmObjectBase.set(this, 'IssueDate', value);

  @override
  String? get languageAgnosticNaturalKey => RealmObjectBase.get<String>(this, 'LanguageAgnosticNaturalKey') as String?;
  @override
  set languageAgnosticNaturalKey(String? value) => RealmObjectBase.set(this, 'LanguageAgnosticNaturalKey', value);

  @override
  String? get languageSymbol => RealmObjectBase.get<String>(this, 'LanguageSymbol') as String?;
  @override
  set languageSymbol(String? value) => RealmObjectBase.set(this, 'LanguageSymbol', value);

  @override
  String? get naturalKey => RealmObjectBase.get<String>(this, 'NaturalKey') as String?;
  @override
  set naturalKey(String? value) => RealmObjectBase.set(this, 'NaturalKey', value);

  @override
  RealmList<String> get checksums => RealmObjectBase.get<String>(this, 'Checksums') as RealmList<String>;
  @override
  set checksums(covariant RealmList<String> value) => throw RealmUnsupportedSetError();

  @override
  RealmImages? get images => RealmObjectBase.get<RealmImages>(this, 'Images') as RealmImages?;
  @override
  set images(covariant RealmImages? value) => RealmObjectBase.set(this, 'Images', value);

  @override
  String? get type => RealmObjectBase.get<String>(this, 'Type') as String?;
  @override
  set type(String? value) => RealmObjectBase.set(this, 'Type', value);

  @override
  String? get remoteType => RealmObjectBase.get<String>(this, 'RemoteType') as String?;
  @override
  set remoteType(String? value) => RealmObjectBase.set(this, 'RemoteType', value);

  @override
  String? get primaryCategory => RealmObjectBase.get<String>(this, 'PrimaryCategory') as String?;
  @override
  set primaryCategory(String? value) => RealmObjectBase.set(this, 'PrimaryCategory', value);

  @override
  String? get pubSymbol => RealmObjectBase.get<String>(this, 'PubSymbol') as String?;
  @override
  set pubSymbol(String? value) => RealmObjectBase.set(this, 'PubSymbol', value);

  @override
  String? get title => RealmObjectBase.get<String>(this, 'Title') as String?;
  @override
  set title(String? value) => RealmObjectBase.set(this, 'Title', value);

  @override
  int? get track => RealmObjectBase.get<int>(this, 'Track') as int?;
  @override
  set track(int? value) => RealmObjectBase.set(this, 'Track', value);

  @override
  Stream<RealmObjectChanges<RealmMediaItem>> get changes => RealmObjectBase.getChanges<RealmMediaItem>(this);

  @override
  Stream<RealmObjectChanges<RealmMediaItem>> changesFor([List<String>? keyPaths]) => RealmObjectBase.getChangesFor<RealmMediaItem>(this, keyPaths);

  @override
  RealmMediaItem freeze() => RealmObjectBase.freezeObject<RealmMediaItem>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'CompoundKey': compoundKey.toEJson(),
      'DocumentId': documentId.toEJson(),
      'Duration': duration.toEJson(),
      'FirstPublished': firstPublished.toEJson(),
      'IsConventionRelease': isConventionRelease.toEJson(),
      'IssueDate': issueDate.toEJson(),
      'LanguageAgnosticNaturalKey': languageAgnosticNaturalKey.toEJson(),
      'LanguageSymbol': languageSymbol.toEJson(),
      'NaturalKey': naturalKey.toEJson(),
      'Checksums': checksums.toEJson(),
      'Images': images.toEJson(),
      'Type': type.toEJson(),
      'RemoteType': remoteType.toEJson(),
      'PrimaryCategory': primaryCategory.toEJson(),
      'PubSymbol': pubSymbol.toEJson(),
      'Title': title.toEJson(),
      'Track': track.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmMediaItem value) => value.toEJson();
  static RealmMediaItem _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'CompoundKey': EJsonValue compoundKey,
        'Duration': EJsonValue duration,
        'FirstPublished': EJsonValue firstPublished,
        'IsConventionRelease': EJsonValue isConventionRelease,
      } =>
        RealmMediaItem(
          fromEJson(ejson['CompoundKey']),
          fromEJson(duration),
          fromEJson(firstPublished),
          fromEJson(isConventionRelease),
          documentId: fromEJson(ejson['DocumentId']),
          issueDate: fromEJson(ejson['IssueDate']),
          languageAgnosticNaturalKey: fromEJson(ejson['LanguageAgnosticNaturalKey']),
          languageSymbol: fromEJson(ejson['LanguageSymbol']),
          naturalKey: fromEJson(ejson['NaturalKey']),
          checksums: fromEJson(ejson['Checksums']),
          images: fromEJson(ejson['Images']),
          type: fromEJson(ejson['Type']),
          remoteType: fromEJson(ejson['RemoteType']),
          primaryCategory: fromEJson(ejson['PrimaryCategory']),
          pubSymbol: fromEJson(ejson['PubSymbol']),
          title: fromEJson(ejson['Title']),
          track: fromEJson(ejson['Track']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmMediaItem._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, RealmMediaItem, 'MediaItem', [
      SchemaProperty('CompoundKey', RealmPropertyType.string, optional: true, primaryKey: true),
      SchemaProperty('DocumentId', RealmPropertyType.int, optional: true),
      SchemaProperty('Duration', RealmPropertyType.double),
      SchemaProperty('FirstPublished', RealmPropertyType.timestamp),
      SchemaProperty('IsConventionRelease', RealmPropertyType.bool),
      SchemaProperty('IssueDate', RealmPropertyType.int, optional: true),
      SchemaProperty('LanguageAgnosticNaturalKey', RealmPropertyType.string, optional: true),
      SchemaProperty('LanguageSymbol', RealmPropertyType.string, optional: true),
      SchemaProperty('NaturalKey', RealmPropertyType.string, optional: true),
      SchemaProperty('Checksums', RealmPropertyType.string, collectionType: RealmCollectionType.list),
      SchemaProperty('Images', RealmPropertyType.object, optional: true, linkTarget: 'Images'),
      SchemaProperty('Type', RealmPropertyType.string, optional: true),
      SchemaProperty('RemoteType', RealmPropertyType.string, optional: true),
      SchemaProperty('PrimaryCategory', RealmPropertyType.string, optional: true),
      SchemaProperty('PubSymbol', RealmPropertyType.string, optional: true),
      SchemaProperty('Title', RealmPropertyType.string, optional: true),
      SchemaProperty('Track', RealmPropertyType.int, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmLanguage extends _RealmLanguage with RealmEntity, RealmObjectBase, RealmObject {
  RealmLanguage(
    String? symbol, {
    String? locale,
    String? vernacular,
    String? name,
    bool? isLanguagePair,
    bool? isSignLanguage,
    bool? isRtl,
    String? eTag,
    String? lastModified,
  }) {
    RealmObjectBase.set(this, 'Symbol', symbol);
    RealmObjectBase.set(this, 'Locale', locale);
    RealmObjectBase.set(this, 'Vernacular', vernacular);
    RealmObjectBase.set(this, 'Name', name);
    RealmObjectBase.set(this, 'IsLanguagePair', isLanguagePair);
    RealmObjectBase.set(this, 'IsSignLanguage', isSignLanguage);
    RealmObjectBase.set(this, 'IsRtl', isRtl);
    RealmObjectBase.set(this, 'ETag', eTag);
    RealmObjectBase.set(this, 'LastModified', lastModified);
  }

  RealmLanguage._();

  @override
  String? get symbol => RealmObjectBase.get<String>(this, 'Symbol') as String?;
  @override
  set symbol(String? value) => RealmObjectBase.set(this, 'Symbol', value);

  @override
  String? get locale => RealmObjectBase.get<String>(this, 'Locale') as String?;
  @override
  set locale(String? value) => RealmObjectBase.set(this, 'Locale', value);

  @override
  String? get vernacular => RealmObjectBase.get<String>(this, 'Vernacular') as String?;
  @override
  set vernacular(String? value) => RealmObjectBase.set(this, 'Vernacular', value);

  @override
  String? get name => RealmObjectBase.get<String>(this, 'Name') as String?;
  @override
  set name(String? value) => RealmObjectBase.set(this, 'Name', value);

  @override
  bool? get isLanguagePair => RealmObjectBase.get<bool>(this, 'IsLanguagePair') as bool?;
  @override
  set isLanguagePair(bool? value) => RealmObjectBase.set(this, 'IsLanguagePair', value);

  @override
  bool? get isSignLanguage => RealmObjectBase.get<bool>(this, 'IsSignLanguage') as bool?;
  @override
  set isSignLanguage(bool? value) => RealmObjectBase.set(this, 'IsSignLanguage', value);

  @override
  bool? get isRtl => RealmObjectBase.get<bool>(this, 'IsRtl') as bool?;
  @override
  set isRtl(bool? value) => RealmObjectBase.set(this, 'IsRtl', value);

  @override
  String? get eTag => RealmObjectBase.get<String>(this, 'ETag') as String?;
  @override
  set eTag(String? value) => RealmObjectBase.set(this, 'ETag', value);

  @override
  String? get lastModified => RealmObjectBase.get<String>(this, 'LastModified') as String?;
  @override
  set lastModified(String? value) => RealmObjectBase.set(this, 'LastModified', value);

  @override
  Stream<RealmObjectChanges<RealmLanguage>> get changes => RealmObjectBase.getChanges<RealmLanguage>(this);

  @override
  Stream<RealmObjectChanges<RealmLanguage>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<RealmLanguage>(this, keyPaths);

  @override
  RealmLanguage freeze() => RealmObjectBase.freezeObject<RealmLanguage>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'Symbol': symbol.toEJson(),
      'Locale': locale.toEJson(),
      'Vernacular': vernacular.toEJson(),
      'Name': name.toEJson(),
      'IsLanguagePair': isLanguagePair.toEJson(),
      'IsSignLanguage': isSignLanguage.toEJson(),
      'IsRtl': isRtl.toEJson(),
      'ETag': eTag.toEJson(),
      'LastModified': lastModified.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmLanguage value) => value.toEJson();
  static RealmLanguage _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'Symbol': EJsonValue Symbol} => RealmLanguage(
        fromEJson(ejson['Symbol']),
        locale: fromEJson(ejson['Locale']),
        vernacular: fromEJson(ejson['Vernacular']),
        name: fromEJson(ejson['Name']),
        isLanguagePair: fromEJson(ejson['IsLanguagePair']),
        isSignLanguage: fromEJson(ejson['IsSignLanguage']),
        isRtl: fromEJson(ejson['IsRtl']),
        eTag: fromEJson(ejson['ETag']),
        lastModified: fromEJson(ejson['LastModified']),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmLanguage._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      RealmLanguage,
      'Language',
      [
        SchemaProperty('Symbol', RealmPropertyType.string, optional: true, primaryKey: true),
        SchemaProperty('Locale', RealmPropertyType.string, optional: true),
        SchemaProperty('Vernacular', RealmPropertyType.string, optional: true),
        SchemaProperty('Name', RealmPropertyType.string, optional: true),
        SchemaProperty('IsLanguagePair', RealmPropertyType.bool, optional: true),
        SchemaProperty('IsSignLanguage', RealmPropertyType.bool, optional: true),
        SchemaProperty('IsRtl', RealmPropertyType.bool, optional: true),
        SchemaProperty('ETag', RealmPropertyType.string, optional: true),
        SchemaProperty('LastModified', RealmPropertyType.string, optional: true),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmCategory extends _RealmCategory with RealmEntity, RealmObjectBase, RealmObject {
  RealmCategory({
    String? key,
    String? name,
    String? type,
    RealmImages? images,
    Iterable<String> media = const [],
    Iterable<RealmCategory> subCategories = const [],
    String? languageSymbol,
  }) {
    RealmObjectBase.set(this, 'Key', key);
    RealmObjectBase.set(this, 'Name', name);
    RealmObjectBase.set(this, 'Type', type);
    RealmObjectBase.set(this, 'Images', images);
    RealmObjectBase.set<RealmList<String>>(this, 'Media', RealmList<String>(media));
    RealmObjectBase.set<RealmList<RealmCategory>>(this, 'Subcategories', RealmList<RealmCategory>(subCategories));
    RealmObjectBase.set(this, 'LanguageSymbol', languageSymbol);
  }

  RealmCategory._();

  @override
  String? get key => RealmObjectBase.get<String>(this, 'Key') as String?;
  @override
  set key(String? value) => RealmObjectBase.set(this, 'Key', value);

  @override
  String? get type => RealmObjectBase.get<String>(this, 'Type') as String?;
  @override
  set type(String? value) => RealmObjectBase.set(this, 'Type', value);
  
  @override
  String? get name => RealmObjectBase.get<String>(this, 'Name') as String?;
  @override
  set name(String? value) => RealmObjectBase.set(this, 'Name', value);

  @override
  RealmImages? get images => RealmObjectBase.get<RealmImages>(this, 'Images') as RealmImages?;
  @override
  set images(covariant RealmImages? value) => RealmObjectBase.set(this, 'Images', value);

  @override
  RealmList<String> get media => RealmObjectBase.get<String>(this, 'Media') as RealmList<String>;
  @override
  set media(covariant RealmList<String> value) => throw RealmUnsupportedSetError();

  @override
  RealmList<RealmCategory> get subCategories => RealmObjectBase.get<RealmCategory>(this, 'Subcategories') as RealmList<RealmCategory>;
  @override
  set subCategories(covariant RealmList<RealmCategory> value) => throw RealmUnsupportedSetError();

  @override
  String? get languageSymbol => RealmObjectBase.get<String>(this, 'LanguageSymbol') as String?;
  @override
  set languageSymbol(String? value) => RealmObjectBase.set(this, 'LanguageSymbol', value);

  @override
  Stream<RealmObjectChanges<RealmCategory>> get changes => RealmObjectBase.getChanges<RealmCategory>(this);

  @override
  Stream<RealmObjectChanges<RealmCategory>> changesFor([List<String>? keyPaths]) => RealmObjectBase.getChangesFor<RealmCategory>(this, keyPaths);

  @override
  RealmCategory freeze() => RealmObjectBase.freezeObject<RealmCategory>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'Key': key.toEJson(),
      'Type': type.toEJson(),
      'Name': name.toEJson(),
      'Images': images.toEJson(),
      'Media': media.toEJson(),
      'Subcategories': subCategories.toEJson(),
      'LanguageSymbol': languageSymbol.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmCategory value) => value.toEJson();
  static RealmCategory _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return RealmCategory(
      key: fromEJson(ejson['Key']),
      type: fromEJson(ejson['Type']),
      name: fromEJson(ejson['Name']),
      images: fromEJson(ejson['Images']),
      media: fromEJson(ejson['Media']),
      subCategories: fromEJson(ejson['Subcategories']),
      languageSymbol: fromEJson(ejson['LanguageSymbol']),
    );
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmCategory._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, RealmCategory, 'Category', [
      SchemaProperty('Key', RealmPropertyType.string, optional: true),
      SchemaProperty('Type', RealmPropertyType.string, optional: true),
      SchemaProperty('Name', RealmPropertyType.string, optional: true),
      SchemaProperty('Images', RealmPropertyType.object, optional: true, linkTarget: 'Images'),
      SchemaProperty('Media', RealmPropertyType.string, collectionType: RealmCollectionType.list),
      SchemaProperty('Subcategories', RealmPropertyType.object, linkTarget: 'Category', collectionType: RealmCollectionType.list),
      SchemaProperty('LanguageSymbol', RealmPropertyType.string, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
