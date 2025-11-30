import 'package:realm/realm.dart';

part 'catalog.realm.dart';

// ------------------- IMAGES -------------------

@RealmModel()
class _RealmImages {
  String? squareImageUrl;
  String? squareFullSizeImageUrl;
  String? wideImageUrl;
  String? wideFullSizeImageUrl;
  String? extraWideImageUrl;
  String? extraWideFullSizeImageUrl;
}

// ------------------- MEDIA -------------------

@RealmModel()
class _RealmMediaItem {
  @PrimaryKey()
  String? compoundKey;
  int? documentId;
  late double duration;
  late DateTime firstPublished;
  late bool isConventionRelease;
  int? issueDate;
  String? languageAgnosticNaturalKey;
  String? languageSymbol;
  String? naturalKey;
  late final List<String> checksums;
  _RealmImages? images;
  String? type;
  String? remoteType;
  String? primaryCategory;
  String? pubSymbol;
  String? title;
  int? track;
}

// ------------------- LANGUAGE -------------------

@RealmModel()
class _RealmLanguage {
  @PrimaryKey()
  String? symbol;
  String? locale;
  String? vernacular;
  String? name;
  bool? isLanguagePair;
  bool? isSignLanguage;
  bool? isRtl;
  String? eTag;
  String? lastModified;
}

// ------------------- CATEGORY -------------------

@RealmModel()
class _RealmCategory {
  String? key;
  String? name;
  String? type;
  _RealmImages? images;
  late final List<String> media;
  late final List<_RealmCategory> subCategories;
  String? languageSymbol;
}
