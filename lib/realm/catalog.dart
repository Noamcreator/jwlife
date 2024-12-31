import 'package:realm/realm.dart';

part 'catalog.realm.dart';

@RealmModel()
class _Category {
  String? key;
  String? localizedName;
  String? type;
  late List<String> media;
  late List<_Category> subcategories;
  _Images? persistedImages;
  String? language;
}

@RealmModel()
class _Images {
  String? squareImageUrl;
  String? squareFullSizeImageUrl;
  String? wideImageUrl;
  String? wideFullSizeImageUrl;
  String? extraWideImageUrl;
  String? extraWideFullSizeImageUrl;
  String? pathCache;
}

@RealmModel()
class _Language {
  @PrimaryKey()
  String? symbol;
  String? locale;
  String? vernacular;
  String? name;
  bool? isSignLanguage;
  bool? isRtl;
  String? eTag;
  String? lastModified;
}

@RealmModel()
class _MediaItem {
  @PrimaryKey()
  String? compoundKey;
  String? naturalKey;
  String? languageAgnosticNaturalKey;
  String? type;
  String? primaryCategory;
  String? title;
  String? firstPublished;
  late List<String> checksums;
  double? duration;
  String? pubSymbol;
  String? languageSymbol;
  _Images? realmImages;
  int? documentId;
  int? issueDate;
  int? track;
  bool? isConventionRelease;
}