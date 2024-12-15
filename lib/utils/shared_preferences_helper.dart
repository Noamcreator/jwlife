import 'package:shared_preferences/shared_preferences.dart';

import '../jwlife.dart';
import '../meps/language.dart';

int LANGUAGE_ID = 0;
int LANGUAGE_CODE = 1;
int LANGUAGE_VERNACULAR = 2;
int LANGUAGE_LOCALE = 3;

/* CATALOG DATE */
Future<String> getCatalogDate() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('catalog_date') == true) {
    return prefs.getString('catalog_date')!;
  }
  return '';
}

Future<void> setCatalogDate(String catalogDate) async {
  print('catalogDate: $catalogDate');
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('catalog_date', catalogDate);
}

/* CATALOG DATE */
Future<String> getLibraryDate() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('library_date') == true) {
    return prefs.getString('library_date')!;
  }
  return '';
}

Future<void> setLibraryDate(String libraryDate) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('library_date', libraryDate);
}


/* LIBRARY LANGUAGE */
Future<String> getLibraryLanguage(int index) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('library_language') == true) {
    return prefs.getStringList('library_language')![index];
  }
  return '';
}

Future<void> setLibraryLanguage(Map<String, dynamic> selectedLanguage) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setStringList('library_language', [selectedLanguage['LanguageId'].toString(), selectedLanguage['Symbol'], selectedLanguage['VernacularName'], selectedLanguage['PrimaryIetfCode']]);

  JwLifeApp.currentLanguage = Language(id: selectedLanguage['LanguageId'], symbol: selectedLanguage['Symbol'], vernacular: selectedLanguage['VernacularName'], primaryIetfCode: selectedLanguage['PrimaryIetfCode']);
}


Future<void> setLibraryLanguageDebug(int id, String code, String vernacular, String locale) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setStringList('library_language', [id.toString(), code, vernacular, locale]);
}

/* HOME PAGE ARTICLE NUMBER */
Future<String> getLastArticle() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('last_article_number') == true) {
    return prefs.getString('last_article_number')!;
  }
  return '';
}

Future<void> setLastArticle(int lastArticle) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('last_article_number', lastArticle.toString());
}

/* FONT SIZE PUBLICATION */
Future<double> getFontSize() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('font_size') == true) {
    return prefs.getDouble('font_size')!;
  }
  return 18;
}

Future<void> setFontSize(double fontSize) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setDouble('font_size', fontSize);
}

/* HIGHLIGHT */
Future<int> getLastHighlightColorIndex() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('last_highlight_color_index') == true) {
    return prefs.getInt('last_highlight_color_index')!;
  }
  return 1;
}

Future<void> setLastHighlightColor(int lastColorIndex) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setInt('last_highlight_color_index', lastColorIndex);
}