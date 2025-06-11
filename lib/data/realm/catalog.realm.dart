// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class Category extends _Category
    with RealmEntity, RealmObjectBase, RealmObject {
  Category({
    String? key,
    String? localizedName,
    String? type,
    Iterable<String> media = const [],
    Iterable<Category> subcategories = const [],
    Images? persistedImages,
    String? language,
  }) {
    RealmObjectBase.set(this, 'key', key);
    RealmObjectBase.set(this, 'localizedName', localizedName);
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set<RealmList<String>>(
      this,
      'media',
      RealmList<String>(media),
    );
    RealmObjectBase.set<RealmList<Category>>(
      this,
      'subcategories',
      RealmList<Category>(subcategories),
    );
    RealmObjectBase.set(this, 'persistedImages', persistedImages);
    RealmObjectBase.set(this, 'language', language);
  }

  Category._();

  @override
  String? get key => RealmObjectBase.get<String>(this, 'key') as String?;
  @override
  set key(String? value) => RealmObjectBase.set(this, 'key', value);

  @override
  String? get localizedName =>
      RealmObjectBase.get<String>(this, 'localizedName') as String?;
  @override
  set localizedName(String? value) =>
      RealmObjectBase.set(this, 'localizedName', value);

  @override
  String? get type => RealmObjectBase.get<String>(this, 'type') as String?;
  @override
  set type(String? value) => RealmObjectBase.set(this, 'type', value);

  @override
  RealmList<String> get media =>
      RealmObjectBase.get<String>(this, 'media') as RealmList<String>;
  @override
  set media(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmList<Category> get subcategories =>
      RealmObjectBase.get<Category>(this, 'subcategories')
          as RealmList<Category>;
  @override
  set subcategories(covariant RealmList<Category> value) =>
      throw RealmUnsupportedSetError();

  @override
  Images? get persistedImages =>
      RealmObjectBase.get<Images>(this, 'persistedImages') as Images?;
  @override
  set persistedImages(covariant Images? value) =>
      RealmObjectBase.set(this, 'persistedImages', value);

  @override
  String? get language =>
      RealmObjectBase.get<String>(this, 'language') as String?;
  @override
  set language(String? value) => RealmObjectBase.set(this, 'language', value);

  @override
  Stream<RealmObjectChanges<Category>> get changes =>
      RealmObjectBase.getChanges<Category>(this);

  @override
  Stream<RealmObjectChanges<Category>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Category>(this, keyPaths);

  @override
  Category freeze() => RealmObjectBase.freezeObject<Category>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'key': key.toEJson(),
      'localizedName': localizedName.toEJson(),
      'type': type.toEJson(),
      'media': media.toEJson(),
      'subcategories': subcategories.toEJson(),
      'persistedImages': persistedImages.toEJson(),
      'language': language.toEJson(),
    };
  }

  static EJsonValue _toEJson(Category value) => value.toEJson();
  static Category _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return Category(
      key: fromEJson(ejson['key']),
      localizedName: fromEJson(ejson['localizedName']),
      type: fromEJson(ejson['type']),
      media: fromEJson(ejson['media']),
      subcategories: fromEJson(ejson['subcategories']),
      persistedImages: fromEJson(ejson['persistedImages']),
      language: fromEJson(ejson['language']),
    );
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Category._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Category, 'Category', [
      SchemaProperty('key', RealmPropertyType.string, optional: true),
      SchemaProperty('localizedName', RealmPropertyType.string, optional: true),
      SchemaProperty('type', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'media',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty(
        'subcategories',
        RealmPropertyType.object,
        linkTarget: 'Category',
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty(
        'persistedImages',
        RealmPropertyType.object,
        optional: true,
        linkTarget: 'Images',
      ),
      SchemaProperty('language', RealmPropertyType.string, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class Images extends _Images with RealmEntity, RealmObjectBase, RealmObject {
  Images({
    String? squareImageUrl,
    String? squareFullSizeImageUrl,
    String? wideImageUrl,
    String? wideFullSizeImageUrl,
    String? extraWideImageUrl,
    String? extraWideFullSizeImageUrl,
    String? pathCache,
  }) {
    RealmObjectBase.set(this, 'squareImageUrl', squareImageUrl);
    RealmObjectBase.set(this, 'squareFullSizeImageUrl', squareFullSizeImageUrl);
    RealmObjectBase.set(this, 'wideImageUrl', wideImageUrl);
    RealmObjectBase.set(this, 'wideFullSizeImageUrl', wideFullSizeImageUrl);
    RealmObjectBase.set(this, 'extraWideImageUrl', extraWideImageUrl);
    RealmObjectBase.set(
      this,
      'extraWideFullSizeImageUrl',
      extraWideFullSizeImageUrl,
    );
    RealmObjectBase.set(this, 'pathCache', pathCache);
  }

  Images._();

  @override
  String? get squareImageUrl =>
      RealmObjectBase.get<String>(this, 'squareImageUrl') as String?;
  @override
  set squareImageUrl(String? value) =>
      RealmObjectBase.set(this, 'squareImageUrl', value);

  @override
  String? get squareFullSizeImageUrl =>
      RealmObjectBase.get<String>(this, 'squareFullSizeImageUrl') as String?;
  @override
  set squareFullSizeImageUrl(String? value) =>
      RealmObjectBase.set(this, 'squareFullSizeImageUrl', value);

  @override
  String? get wideImageUrl =>
      RealmObjectBase.get<String>(this, 'wideImageUrl') as String?;
  @override
  set wideImageUrl(String? value) =>
      RealmObjectBase.set(this, 'wideImageUrl', value);

  @override
  String? get wideFullSizeImageUrl =>
      RealmObjectBase.get<String>(this, 'wideFullSizeImageUrl') as String?;
  @override
  set wideFullSizeImageUrl(String? value) =>
      RealmObjectBase.set(this, 'wideFullSizeImageUrl', value);

  @override
  String? get extraWideImageUrl =>
      RealmObjectBase.get<String>(this, 'extraWideImageUrl') as String?;
  @override
  set extraWideImageUrl(String? value) =>
      RealmObjectBase.set(this, 'extraWideImageUrl', value);

  @override
  String? get extraWideFullSizeImageUrl =>
      RealmObjectBase.get<String>(this, 'extraWideFullSizeImageUrl') as String?;
  @override
  set extraWideFullSizeImageUrl(String? value) =>
      RealmObjectBase.set(this, 'extraWideFullSizeImageUrl', value);

  @override
  String? get pathCache =>
      RealmObjectBase.get<String>(this, 'pathCache') as String?;
  @override
  set pathCache(String? value) => RealmObjectBase.set(this, 'pathCache', value);

  @override
  Stream<RealmObjectChanges<Images>> get changes =>
      RealmObjectBase.getChanges<Images>(this);

  @override
  Stream<RealmObjectChanges<Images>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Images>(this, keyPaths);

  @override
  Images freeze() => RealmObjectBase.freezeObject<Images>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'squareImageUrl': squareImageUrl.toEJson(),
      'squareFullSizeImageUrl': squareFullSizeImageUrl.toEJson(),
      'wideImageUrl': wideImageUrl.toEJson(),
      'wideFullSizeImageUrl': wideFullSizeImageUrl.toEJson(),
      'extraWideImageUrl': extraWideImageUrl.toEJson(),
      'extraWideFullSizeImageUrl': extraWideFullSizeImageUrl.toEJson(),
      'pathCache': pathCache.toEJson(),
    };
  }

  static EJsonValue _toEJson(Images value) => value.toEJson();
  static Images _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return Images(
      squareImageUrl: fromEJson(ejson['squareImageUrl']),
      squareFullSizeImageUrl: fromEJson(ejson['squareFullSizeImageUrl']),
      wideImageUrl: fromEJson(ejson['wideImageUrl']),
      wideFullSizeImageUrl: fromEJson(ejson['wideFullSizeImageUrl']),
      extraWideImageUrl: fromEJson(ejson['extraWideImageUrl']),
      extraWideFullSizeImageUrl: fromEJson(ejson['extraWideFullSizeImageUrl']),
      pathCache: fromEJson(ejson['pathCache']),
    );
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Images._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Images, 'Images', [
      SchemaProperty(
        'squareImageUrl',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'squareFullSizeImageUrl',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty('wideImageUrl', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'wideFullSizeImageUrl',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'extraWideImageUrl',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'extraWideFullSizeImageUrl',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty('pathCache', RealmPropertyType.string, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class Language extends _Language
    with RealmEntity, RealmObjectBase, RealmObject {
  Language(
    String? symbol, {
    String? locale,
    String? vernacular,
    String? name,
    bool? isSignLanguage,
    bool? isRtl,
    String? eTag,
    String? lastModified,
  }) {
    RealmObjectBase.set(this, 'symbol', symbol);
    RealmObjectBase.set(this, 'locale', locale);
    RealmObjectBase.set(this, 'vernacular', vernacular);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'isSignLanguage', isSignLanguage);
    RealmObjectBase.set(this, 'isRtl', isRtl);
    RealmObjectBase.set(this, 'eTag', eTag);
    RealmObjectBase.set(this, 'lastModified', lastModified);
  }

  Language._();

  @override
  String? get symbol => RealmObjectBase.get<String>(this, 'symbol') as String?;
  @override
  set symbol(String? value) => RealmObjectBase.set(this, 'symbol', value);

  @override
  String? get locale => RealmObjectBase.get<String>(this, 'locale') as String?;
  @override
  set locale(String? value) => RealmObjectBase.set(this, 'locale', value);

  @override
  String? get vernacular =>
      RealmObjectBase.get<String>(this, 'vernacular') as String?;
  @override
  set vernacular(String? value) =>
      RealmObjectBase.set(this, 'vernacular', value);

  @override
  String? get name => RealmObjectBase.get<String>(this, 'name') as String?;
  @override
  set name(String? value) => RealmObjectBase.set(this, 'name', value);

  @override
  bool? get isSignLanguage =>
      RealmObjectBase.get<bool>(this, 'isSignLanguage') as bool?;
  @override
  set isSignLanguage(bool? value) =>
      RealmObjectBase.set(this, 'isSignLanguage', value);

  @override
  bool? get isRtl => RealmObjectBase.get<bool>(this, 'isRtl') as bool?;
  @override
  set isRtl(bool? value) => RealmObjectBase.set(this, 'isRtl', value);

  @override
  String? get eTag => RealmObjectBase.get<String>(this, 'eTag') as String?;
  @override
  set eTag(String? value) => RealmObjectBase.set(this, 'eTag', value);

  @override
  String? get lastModified =>
      RealmObjectBase.get<String>(this, 'lastModified') as String?;
  @override
  set lastModified(String? value) =>
      RealmObjectBase.set(this, 'lastModified', value);

  @override
  Stream<RealmObjectChanges<Language>> get changes =>
      RealmObjectBase.getChanges<Language>(this);

  @override
  Stream<RealmObjectChanges<Language>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Language>(this, keyPaths);

  @override
  Language freeze() => RealmObjectBase.freezeObject<Language>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'symbol': symbol.toEJson(),
      'locale': locale.toEJson(),
      'vernacular': vernacular.toEJson(),
      'name': name.toEJson(),
      'isSignLanguage': isSignLanguage.toEJson(),
      'isRtl': isRtl.toEJson(),
      'eTag': eTag.toEJson(),
      'lastModified': lastModified.toEJson(),
    };
  }

  static EJsonValue _toEJson(Language value) => value.toEJson();
  static Language _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'symbol': EJsonValue symbol} => Language(
        fromEJson(ejson['symbol']),
        locale: fromEJson(ejson['locale']),
        vernacular: fromEJson(ejson['vernacular']),
        name: fromEJson(ejson['name']),
        isSignLanguage: fromEJson(ejson['isSignLanguage']),
        isRtl: fromEJson(ejson['isRtl']),
        eTag: fromEJson(ejson['eTag']),
        lastModified: fromEJson(ejson['lastModified']),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Language._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Language, 'Language', [
      SchemaProperty(
        'symbol',
        RealmPropertyType.string,
        optional: true,
        primaryKey: true,
      ),
      SchemaProperty('locale', RealmPropertyType.string, optional: true),
      SchemaProperty('vernacular', RealmPropertyType.string, optional: true),
      SchemaProperty('name', RealmPropertyType.string, optional: true),
      SchemaProperty('isSignLanguage', RealmPropertyType.bool, optional: true),
      SchemaProperty('isRtl', RealmPropertyType.bool, optional: true),
      SchemaProperty('eTag', RealmPropertyType.string, optional: true),
      SchemaProperty('lastModified', RealmPropertyType.string, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class MediaItem extends _MediaItem
    with RealmEntity, RealmObjectBase, RealmObject {
  MediaItem(
    String? compoundKey, {
    String? naturalKey,
    String? languageAgnosticNaturalKey,
    String? type,
    String? primaryCategory,
    String? title,
    String? firstPublished,
    Iterable<String> checksums = const [],
    double? duration,
    String? pubSymbol,
    String? languageSymbol,
    Images? realmImages,
    int? documentId,
    int? issueDate,
    int? track,
    bool? isConventionRelease,
  }) {
    RealmObjectBase.set(this, 'compoundKey', compoundKey);
    RealmObjectBase.set(this, 'naturalKey', naturalKey);
    RealmObjectBase.set(
      this,
      'languageAgnosticNaturalKey',
      languageAgnosticNaturalKey,
    );
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set(this, 'primaryCategory', primaryCategory);
    RealmObjectBase.set(this, 'title', title);
    RealmObjectBase.set(this, 'firstPublished', firstPublished);
    RealmObjectBase.set<RealmList<String>>(
      this,
      'checksums',
      RealmList<String>(checksums),
    );
    RealmObjectBase.set(this, 'duration', duration);
    RealmObjectBase.set(this, 'pubSymbol', pubSymbol);
    RealmObjectBase.set(this, 'languageSymbol', languageSymbol);
    RealmObjectBase.set(this, 'realmImages', realmImages);
    RealmObjectBase.set(this, 'documentId', documentId);
    RealmObjectBase.set(this, 'issueDate', issueDate);
    RealmObjectBase.set(this, 'track', track);
    RealmObjectBase.set(this, 'isConventionRelease', isConventionRelease);
  }

  MediaItem._();

  @override
  String? get compoundKey =>
      RealmObjectBase.get<String>(this, 'compoundKey') as String?;
  @override
  set compoundKey(String? value) =>
      RealmObjectBase.set(this, 'compoundKey', value);

  @override
  String? get naturalKey =>
      RealmObjectBase.get<String>(this, 'naturalKey') as String?;
  @override
  set naturalKey(String? value) =>
      RealmObjectBase.set(this, 'naturalKey', value);

  @override
  String? get languageAgnosticNaturalKey =>
      RealmObjectBase.get<String>(this, 'languageAgnosticNaturalKey')
          as String?;
  @override
  set languageAgnosticNaturalKey(String? value) =>
      RealmObjectBase.set(this, 'languageAgnosticNaturalKey', value);

  @override
  String? get type => RealmObjectBase.get<String>(this, 'type') as String?;
  @override
  set type(String? value) => RealmObjectBase.set(this, 'type', value);

  @override
  String? get primaryCategory =>
      RealmObjectBase.get<String>(this, 'primaryCategory') as String?;
  @override
  set primaryCategory(String? value) =>
      RealmObjectBase.set(this, 'primaryCategory', value);

  @override
  String? get title => RealmObjectBase.get<String>(this, 'title') as String?;
  @override
  set title(String? value) => RealmObjectBase.set(this, 'title', value);

  @override
  String? get firstPublished =>
      RealmObjectBase.get<String>(this, 'firstPublished') as String?;
  @override
  set firstPublished(String? value) =>
      RealmObjectBase.set(this, 'firstPublished', value);

  @override
  RealmList<String> get checksums =>
      RealmObjectBase.get<String>(this, 'checksums') as RealmList<String>;
  @override
  set checksums(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  double? get duration =>
      RealmObjectBase.get<double>(this, 'duration') as double?;
  @override
  set duration(double? value) => RealmObjectBase.set(this, 'duration', value);

  @override
  String? get pubSymbol =>
      RealmObjectBase.get<String>(this, 'pubSymbol') as String?;
  @override
  set pubSymbol(String? value) => RealmObjectBase.set(this, 'pubSymbol', value);

  @override
  String? get languageSymbol =>
      RealmObjectBase.get<String>(this, 'languageSymbol') as String?;
  @override
  set languageSymbol(String? value) =>
      RealmObjectBase.set(this, 'languageSymbol', value);

  @override
  Images? get realmImages =>
      RealmObjectBase.get<Images>(this, 'realmImages') as Images?;
  @override
  set realmImages(covariant Images? value) =>
      RealmObjectBase.set(this, 'realmImages', value);

  @override
  int? get documentId => RealmObjectBase.get<int>(this, 'documentId') as int?;
  @override
  set documentId(int? value) => RealmObjectBase.set(this, 'documentId', value);

  @override
  int? get issueDate => RealmObjectBase.get<int>(this, 'issueDate') as int?;
  @override
  set issueDate(int? value) => RealmObjectBase.set(this, 'issueDate', value);

  @override
  int? get track => RealmObjectBase.get<int>(this, 'track') as int?;
  @override
  set track(int? value) => RealmObjectBase.set(this, 'track', value);

  @override
  bool? get isConventionRelease =>
      RealmObjectBase.get<bool>(this, 'isConventionRelease') as bool?;
  @override
  set isConventionRelease(bool? value) =>
      RealmObjectBase.set(this, 'isConventionRelease', value);

  @override
  Stream<RealmObjectChanges<MediaItem>> get changes =>
      RealmObjectBase.getChanges<MediaItem>(this);

  @override
  Stream<RealmObjectChanges<MediaItem>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<MediaItem>(this, keyPaths);

  @override
  MediaItem freeze() => RealmObjectBase.freezeObject<MediaItem>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'compoundKey': compoundKey.toEJson(),
      'naturalKey': naturalKey.toEJson(),
      'languageAgnosticNaturalKey': languageAgnosticNaturalKey.toEJson(),
      'type': type.toEJson(),
      'primaryCategory': primaryCategory.toEJson(),
      'title': title.toEJson(),
      'firstPublished': firstPublished.toEJson(),
      'checksums': checksums.toEJson(),
      'duration': duration.toEJson(),
      'pubSymbol': pubSymbol.toEJson(),
      'languageSymbol': languageSymbol.toEJson(),
      'realmImages': realmImages.toEJson(),
      'documentId': documentId.toEJson(),
      'issueDate': issueDate.toEJson(),
      'track': track.toEJson(),
      'isConventionRelease': isConventionRelease.toEJson(),
    };
  }

  static EJsonValue _toEJson(MediaItem value) => value.toEJson();
  static MediaItem _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'compoundKey': EJsonValue compoundKey} => MediaItem(
        fromEJson(ejson['compoundKey']),
        naturalKey: fromEJson(ejson['naturalKey']),
        languageAgnosticNaturalKey: fromEJson(
          ejson['languageAgnosticNaturalKey'],
        ),
        type: fromEJson(ejson['type']),
        primaryCategory: fromEJson(ejson['primaryCategory']),
        title: fromEJson(ejson['title']),
        firstPublished: fromEJson(ejson['firstPublished']),
        checksums: fromEJson(ejson['checksums']),
        duration: fromEJson(ejson['duration']),
        pubSymbol: fromEJson(ejson['pubSymbol']),
        languageSymbol: fromEJson(ejson['languageSymbol']),
        realmImages: fromEJson(ejson['realmImages']),
        documentId: fromEJson(ejson['documentId']),
        issueDate: fromEJson(ejson['issueDate']),
        track: fromEJson(ejson['track']),
        isConventionRelease: fromEJson(ejson['isConventionRelease']),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(MediaItem._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, MediaItem, 'MediaItem', [
      SchemaProperty(
        'compoundKey',
        RealmPropertyType.string,
        optional: true,
        primaryKey: true,
      ),
      SchemaProperty('naturalKey', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'languageAgnosticNaturalKey',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty('type', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'primaryCategory',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty('title', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'firstPublished',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'checksums',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty('duration', RealmPropertyType.double, optional: true),
      SchemaProperty('pubSymbol', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'languageSymbol',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'realmImages',
        RealmPropertyType.object,
        optional: true,
        linkTarget: 'Images',
      ),
      SchemaProperty('documentId', RealmPropertyType.int, optional: true),
      SchemaProperty('issueDate', RealmPropertyType.int, optional: true),
      SchemaProperty('track', RealmPropertyType.int, optional: true),
      SchemaProperty(
        'isConventionRelease',
        RealmPropertyType.bool,
        optional: true,
      ),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
