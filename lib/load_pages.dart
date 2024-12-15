import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwlife/realm/catalog.dart';
import 'package:jwlife/utils/directory_helper.dart';
import 'package:realm/realm.dart';

import 'jwlife.dart';

class LoadPages {
  static List<String> latestAudiosVideos = [];
  static List<String> teachingToolboxVideos = [];

  static void downloadLanguageCategory(String languageCode, String audioCategoryKey) async
  {
    String apiCategories = "https://b.jw-cdn.org/apis/mediator/v1/categories/$languageCode/$audioCategoryKey?detailed=1&mediaLimit=0&clientType=www";
    try {
      final response = await http.get(Uri.parse(apiCategories));
      if (response.statusCode == 200) {
        final jsonFile = response.body;

        Directory languagesDir = await getLanguagesDirectory();
        Directory languageDir = Directory('${languagesDir.path}/$languageCode');
        if (!await languageDir.exists()) {
          await languageDir.create(recursive: true);
        }

        File file = File('${languageDir.path}/$audioCategoryKey.json');
        await file.writeAsString(jsonFile);
      } else {
        print('Failed to download language catalog $languageCode: ${response.statusCode}');
      }
    }
    catch (e) {
      print('Error updating language catalog $languageCode: $e');
    }
  }

  static Future<void> loadTeachingToolbox() async {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    Realm realm = Realm(config);
    // Rechercher la catégorie avec la clé 'LatestAudioVideo'
    final teachingToolbox = realm.all<Category>().query("key == 'TeachingToolbox'").query("language == '$languageSymbol'").first;
    teachingToolboxVideos = teachingToolbox.media;
  }

  static Future<void> loadLatestVideos() async {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    Realm realm = Realm(config);
    // Rechercher la catégorie avec la clé 'LatestAudioVideo'
    final latestAudioVideoCategory = realm.all<Category>().query("key == 'LatestAudioVideo'").query("language == '$languageSymbol'").first;
    latestAudiosVideos = latestAudioVideoCategory.media;
  }
}
