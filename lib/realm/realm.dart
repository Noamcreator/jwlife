import 'dart:convert';
import 'dart:io';
import 'package:realm/realm.dart';

import 'catalog.dart';

class RealmMediaHandler {
  static Future<void> convertMediaJsonToRealm(var bodyBytes) async {
    final decodedData = GZipCodec().decode(bodyBytes);
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    Realm realm = Realm(config);

    // Convertir les données en chaîne JSON
    String jsonString = utf8.decode(decodedData);
    List<dynamic> jsonList = LineSplitter.split(jsonString)
        .map((line) => json.decode(line))
        .toList();

    String languageCode = '';
    Set<String> existingLanguageSymbols = Set.from(realm.all<Language>().map((lang) => lang.symbol));
    Set<String> existingMediaItemKeys = Set.from(realm.all<MediaItem>().map((item) => item.naturalKey));
    Map<String, Set<String>> existingCategoryKeysByLanguage = {};

    // Initialiser un ensemble pour chaque langue
    for (var lang in realm.all<Category>()) {
      // Utiliser une chaîne vide si lang.language est null
      String langKey = lang.language ?? '';
      if (lang.key != null) { // Vérifiez si lang.key n'est pas null
        existingCategoryKeysByLanguage.putIfAbsent(langKey, () => {}).add(lang.key!); // Utilisez ! pour indiquer que key n'est pas null
      }
    }

    List<Language> languagesToAdd = [];
    List<Category> categoriesToAdd = [];
    List<MediaItem> mediaItemsToAdd = [];

    for (var json in jsonList) {
      if (json['type'] == 'language') {
        var data = json['o'];
        languageCode = data['code'];

        // Ajouter la langue si elle n'existe pas déjà
        if (!existingLanguageSymbols.contains(languageCode)) {
          var language = Language(
              data['code'],
              locale: data['locale'],
              vernacular: data['vernacular'],
              name: data['name'],
              isSignLanguage: data['isSignLanguage'],
              isRtl: data['isRTL'],
              eTag: ""
          );
          languagesToAdd.add(language);
          existingLanguageSymbols.add(languageCode);
        }
      }

      if (json['type'] == 'category') {
        Map<String, dynamic> data = json['o'];

        // Supprimer la catégorie existante si elle est déjà dans la base de données pour éviter les doublons
        var existingCategory = realm.all<Category>().query("key == '${data['key']}' AND language == '$languageCode'").firstOrNull;
        if (existingCategory != null) {
          realm.write(() {
            realm.delete(existingCategory);
          });
        }

        // Ajouter ou recréer la catégorie avec les nouvelles données
        var category = Category(
            key: data['key'],
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
                    }).whereType<Category>().toList()
                        : [],
                    persistedImages: subCategoryData.containsKey('images') ? Images(
                      squareImageUrl: subCategoryData['images'].containsKey('sqr') ? subCategoryData['images']['sqr']['lg'] : null,
                      squareFullSizeImageUrl: subCategoryData['images'].containsKey('sqr') ? subCategoryData['images']['sqr']['xl'] : null,
                      wideImageUrl: subCategoryData['images'].containsKey('lsr') ? subCategoryData['images']['lsr']['md'] : null,
                      wideFullSizeImageUrl: subCategoryData['images'].containsKey('lsr') ? subCategoryData['images']['lsr']['xl'] : null,
                      extraWideFullSizeImageUrl: subCategoryData['images'].containsKey('pnr') ? subCategoryData['images']['pnr']['lg'] : null,
                    ) : null,
                    language: languageCode
                );
              }
              return null;
            }).whereType<Category>().toList()
                : [],
            persistedImages: data.containsKey('images') ? await getImage(data['images']) : null,
            language: languageCode
        );

        categoriesToAdd.add(category);
        existingCategoryKeysByLanguage.putIfAbsent(languageCode, () => {}).add(data['key']!);
      }

      if (json['type'] == 'media-item') {
        Map<String, dynamic> data = json['o'];

        // Vérifier si le media-item existe déjà
        if (!existingMediaItemKeys.contains(data['naturalKey'])) {
          var mediaItem = MediaItem(
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

          mediaItemsToAdd.add(mediaItem);
          existingMediaItemKeys.add(data['naturalKey']);
        }
      }
    }

    // Écriture groupée dans la base de données
    realm.write(() {
      realm.addAll(languagesToAdd);
      realm.addAll(categoriesToAdd);
      realm.addAll(mediaItemsToAdd);
    });

    realm.close();
  }

  static Future<Images> getImage(Map<String, dynamic> images) async {
    return Images(
      squareImageUrl: images.containsKey('sqr') ? images['sqr']['lg'] : null,
      squareFullSizeImageUrl: images.containsKey('sqr') ? images['sqr']['xl'] : null,
      wideImageUrl: images.containsKey('lsr') ? images['lsr']['md'] : null,
      wideFullSizeImageUrl: images.containsKey('lsr') ? images['lsr']['xl'] : null,
      extraWideFullSizeImageUrl: images.containsKey('pnr') ? images['pnr']['lg'] : null,
    );
  }
}
