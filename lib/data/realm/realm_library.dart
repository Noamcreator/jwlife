import 'dart:convert';
import 'dart:io';
import 'package:jwlife/data/models/media.dart';
import 'package:realm/realm.dart';

import '../../app/services/settings_service.dart';
import '../models/audio.dart';
import '../models/video.dart';
import 'catalog.dart';

class RealmLibrary {
  static Realm realm = Realm(Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]));

  static List<Media> loadTeachingToolboxVideos() {
    // Code exists as is.
    List<Media> teachingToolboxVideos = [];
    String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    final items = realm.all<Category>()
        .query("key == 'TeachingToolbox' AND language == '$languageSymbol'")
        .expand((category) => category.media)
        .map((mediaKey) => realm.all<MediaItem>().query("naturalKey == '$mediaKey'").firstOrNull)
        .whereType<MediaItem>();

    for (final item in items) {
      if (item.type == 'VIDEO') {
        teachingToolboxVideos.add(Video.fromJson(mediaItem: item));
      } else if (item.type == 'AUDIO') {
        teachingToolboxVideos.add(Audio.fromJson(mediaItem: item));
      }
    }

    return teachingToolboxVideos;
  }

  static List<Media> loadLatestMedias() {
    // Code exists as is.
    List<Media> latestMedias = [];
    String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    final items = realm.all<Category>()
        .query("key == 'LatestAudioVideo' AND language == '$languageSymbol'")
        .expand((category) => category.media)
        .map((mediaKey) => realm.all<MediaItem>().query("naturalKey == '$mediaKey'").firstOrNull)
        .whereType<MediaItem>();

    for (final item in items) {
      if (item.type == 'VIDEO') {
        latestMedias.add(Video.fromJson(mediaItem: item));
      } else if (item.type == 'AUDIO') {
        latestMedias.add(Audio.fromJson(mediaItem: item));
      }
    }

    return latestMedias;
  }

  static Future<void> convertMediaJsonToRealm(var bodyBytes) async {
    final decodedData = GZipCodec().decode(bodyBytes);
    String jsonString = utf8.decode(decodedData);
    List<dynamic> jsonList = LineSplitter.split(jsonString)
        .map((line) => json.decode(line))
        .toList();

    String languageCode = '';

    // Use maps to manage existing and new items for efficient lookups
    Map<String, Language> existingLanguages = {for (var lang in realm.all<Language>())? lang.symbol: lang};
    Map<String, MediaItem> existingMediaItems = {for (var item in realm.all<MediaItem>())? item.naturalKey: item};
    Map<String, Category> existingCategories = {for (var cat in realm.all<Category>()) '${cat.key}_${cat.language ?? ''}': cat};

    List<Language> languagesToAdd = [];
    List<Category> categoriesToAddOrUpdate = [];
    List<MediaItem> mediaItemsToAddOrUpdate = [];

    // Separate media items and categories for bulk processing
    List<Map<String, dynamic>> categoryJsons = [];
    List<Map<String, dynamic>> mediaItemJsons = [];

    for (var json in jsonList) {
      if (json['type'] == 'language') {
        var data = json['o'];
        languageCode = data['code'];
        if (!existingLanguages.containsKey(languageCode)) {
          languagesToAdd.add(Language(
              data['code'],
              locale: data['locale'],
              vernacular: data['vernacular'],
              name: data['name'],
              isSignLanguage: data['isSignLanguage'],
              isRtl: data['isRTL'],
              eTag: ""
          ));
        }
      } else if (json['type'] == 'category') {
        categoryJsons.add(json['o']);
      } else if (json['type'] == 'media-item') {
        mediaItemJsons.add(json['o']);
      }
    }

    // Process categories
    for (var data in categoryJsons) {
      String categoryKey = data['key'];
      Category category = Category(
        key: categoryKey,
        localizedName: data['name'],
        type: data['type'],
        media: data.containsKey('media') ? List<String>.from(data['media']) : [],
        subcategories: data.containsKey('subcategories')
            ? (data['subcategories'] as List<dynamic>).map((subCategoryData) {
          if (subCategoryData is Map<String, dynamic>) {
            return Category(
                key: subCategoryData['key'],
                localizedName: subCategoryData['name'],
                type: subCategoryData['type'],
                media: subCategoryData.containsKey('media') ? List<String>.from(subCategoryData['media']) : [],
                subcategories: subCategoryData.containsKey('subcategories')
                    ? (subCategoryData['subcategories'] as List<dynamic>).map((subSubCategoryData) {
                  if (subSubCategoryData is Map<String, dynamic>) {
                    return Category(
                        key: subSubCategoryData['key'],
                        localizedName: subSubCategoryData['name'],
                        type: subSubCategoryData['type'],
                        media: subSubCategoryData.containsKey('media') ? List<String>.from(subSubCategoryData['media']) : [],
                        language: languageCode
                    );
                  }
                  return null;
                }).whereType<Category>().toList() : [],
                persistedImages: subCategoryData.containsKey('images') ? Images(
                  squareImageUrl: subCategoryData['images'].containsKey('sqr') ? subCategoryData['images']['sqr']['lg'] : null,
                  squareFullSizeImageUrl: subCategoryData['images'].containsKey('sqr') ? subCategoryData['images']['sqr']['xml'] : null,
                  wideImageUrl: subCategoryData['images'].containsKey('lsr') ? subCategoryData['images']['lsr']['md'] : null,
                  wideFullSizeImageUrl: subCategoryData['images'].containsKey('lsr') ? subCategoryData['images']['lsr']['xml'] : null,
                  extraWideFullSizeImageUrl: subCategoryData['images'].containsKey('pnr') ? subCategoryData['images']['pnr']['lg'] : null,
                ) : null,
                language: languageCode
            );
          }
          return null;
        }).whereType<Category>().toList()
            : [],
        persistedImages: data.containsKey('images') ? await getImage(data['images']) : null,
        language: languageCode,
      );
      categoriesToAddOrUpdate.add(category);
    }

    // Process media items
    for (var data in mediaItemJsons) {
      MediaItem mediaItem = MediaItem(
        data['naturalKey'],
        naturalKey: data['naturalKey'],
        languageAgnosticNaturalKey: data['languageAgnosticNaturalKey'],
        type: data['keyParts'].containsKey('formatCode') ? data['keyParts']['formatCode'] : null,
        primaryCategory: data['primaryCategory'],
        title: data['title'],
        firstPublished: data['firstPublished'],
        checksums: List<String>.from(data['checksums']),
        duration: data['duration'] is int ? data['duration'].toDouble() : data['duration'],
        pubSymbol: data['keyParts'].containsKey('pubSymbol') ? data['keyParts']['pubSymbol'] : null,
        languageSymbol: data['keyParts'].containsKey('languageCode') ? data['keyParts']['languageCode'] : null,
        realmImages: data.containsKey('images') ? await getImage(data['images']) : null,
        documentId: data['keyParts'].containsKey('docID') ? data['keyParts']['docID'] : null,
        issueDate: data['keyParts'].containsKey('issueDate') ? int.parse(data['keyParts']['issueDate']) : null,
        track: data['keyParts'].containsKey('track') ? data['keyParts']['track'] : null,
      );
      mediaItemsToAddOrUpdate.add(mediaItem);
    }

    // Consolidate database operations into a single transaction
    realm.write(() {
      // Step 1: Add new languages
      realm.addAll(languagesToAdd);

      // Step 2: Delete existing categories that will be replaced
      for (var category in categoriesToAddOrUpdate) {
        String mapKey = '${category.key}_${category.language ?? ''}';
        if (existingCategories.containsKey(mapKey)) {
          realm.delete(existingCategories[mapKey]!);
        }
      }

      // Step 3: Add new categories
      realm.addAll(categoriesToAddOrUpdate);

      // Step 4: Delete existing media items that will be replaced
      for (var mediaItem in mediaItemsToAddOrUpdate) {
        if (existingMediaItems.containsKey(mediaItem.naturalKey)) {
          realm.delete(existingMediaItems[mediaItem.naturalKey]!);
        }
      }

      // Step 5: Add new media items
      realm.addAll(mediaItemsToAddOrUpdate);
    });
  }

  static Future<Images> getImage(Map<String, dynamic> images) async {
    String? squareImageUrl = images.containsKey('sqr') ? images['sqr']['lg'] : null;
    squareImageUrl ??= images.containsKey('cvr') ? images['cvr']['lg'] : null;

    return Images(
      squareImageUrl: squareImageUrl,
      squareFullSizeImageUrl: images.containsKey('sqr') ? images['sqr']['xml'] : null,
      wideImageUrl: images.containsKey('lsr') ? images['lsr']['md'] : null,
      wideFullSizeImageUrl: images.containsKey('lsr') ? images['lsr']['xml'] : null,
      extraWideFullSizeImageUrl: images.containsKey('pnr') ? images['pnr']['lg'] : null,
    );
  }
}