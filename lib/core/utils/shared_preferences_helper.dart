import 'package:flutter/material.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/jwlife_app.dart';
import '../../data/meps/language.dart';

int LANGUAGE_ID = 0;
int LANGUAGE_CODE = 1;
int LANGUAGE_VERNACULAR = 2;
int LANGUAGE_LOCALE = 3;

/* CATALOG DATE */
Future<String> getTheme() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('theme') == true) {
    return prefs.getString('theme')!;
  }
  return 'system';
}

Future<void> setTheme(String theme) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('theme', theme);
}

// Extension pour convertir une couleur en chaîne hexadécimale
extension ColorHexString on Color {
  String toHex() {
    return '#${this.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

// Extension pour créer une couleur à partir d'une chaîne hexadécimale
extension HexStringColor on String {
  Color fromHex() {
    return Color(int.parse(this.replaceFirst('#', '0xFF')));
  }
}

/* PRIMARY COLOR */
Future<Color> getPrimaryColor(ThemeMode theme) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  // Si la clé 'primary_color' existe, on récupère la couleur correspondant à l'index
  if (prefs.containsKey('primary_color')) {
    List<String> colors = prefs.getStringList('primary_color')!;
    if (colors.isNotEmpty && colors.length > index) {
      return colors[index].fromHex();
    }
  }

  // Valeurs par défaut
  Color primaryColorLight = Color(0xFF295568);
  Color primaryColorDark = Color.lerp(primaryColorLight, Colors.white, 0.3)!;

  return WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? primaryColorDark
      : primaryColorLight;
}

Future<void> setPrimaryColor(ThemeMode theme, Color color) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  // Récupérer la liste des couleurs existantes ou en créer une nouvelle
  List<String> colors = prefs.getStringList('primary_color') ?? ['', '', ''];

  // Mettre à jour la couleur correspondante à l'index
  colors[index] = color.toHex();

  // Sauvegarder la liste mise à jour
  await prefs.setStringList('primary_color', colors);
}

Future<String> getLocale() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('locale') == true) {
    return prefs.getString('locale')!;
  }

  // récupérer la langue de l'appareil
  Locale deviceLocale = WidgetsBinding.instance.window.locales.first;
  if (AppLocalizations.supportedLocales.contains(Locale(deviceLocale.languageCode))) {
    return deviceLocale.languageCode;
  }
  return 'en';
}

Future<void> setLocale(String locale) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('locale', locale);
}

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

/* LIBRARY DATE */
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

  JwLifeApp.settings.currentLanguage = MepsLanguage.fromJson(selectedLanguage);
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

/* FULLSCREEN PUBLICATION */
Future<bool> getFullscreen() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('fullscreen') == true) {
    return prefs.getBool('fullscreen')!;
  }
  return true;
}

Future<void> setFullscreen(bool fullscreen) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('fullscreen', fullscreen);
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