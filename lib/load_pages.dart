import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwlife/realm/catalog.dart';
import 'package:jwlife/utils/directory_helper.dart';
import 'package:realm/realm.dart';

import 'jwlife.dart';

class LoadPages {
  static List<MediaItem> latestAudiosVideos = [];
  static List<MediaItem> teachingToolboxVideos = [];

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
    teachingToolboxVideos.clear();
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    // Rechercher la catégorie avec la clé 'TeachingToolbox' et la langue correspondante
    final teachingToolbox = JwLifeApp.library.all<Category>().query("key == 'TeachingToolbox'").query("language == '$languageSymbol'").first;

    for (String mediaKey in teachingToolbox.media) {
      MediaItem mediaItem = JwLifeApp.library.all<MediaItem>().query("naturalKey == '$mediaKey'").first;
      teachingToolboxVideos.add(mediaItem);
    }
  }

  static Future<void> loadLatestVideos() async {
    latestAudiosVideos.clear();
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    // Rechercher la catégorie avec la clé 'LatestAudioVideo' et la langue correspondante
    final latestAudioVideoCategory = JwLifeApp.library.all<Category>().query("key == 'LatestAudioVideo'").query("language == '$languageSymbol'").first;

    for (String mediaKey in latestAudioVideoCategory.media) {
      MediaItem mediaItem = JwLifeApp.library.all<MediaItem>().query("naturalKey == '$mediaKey'").first;
      latestAudiosVideos.add(mediaItem);
    }
  }
}
