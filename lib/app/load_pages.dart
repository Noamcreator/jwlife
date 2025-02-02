/*
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwlife/realm/catalog.dart';
import 'package:jwlife/realm/realm_library.dart';
import 'package:jwlife/utils/directory_helper.dart';

class RealmMedias {
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
}
*/