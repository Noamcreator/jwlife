import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/meps_language.dart';

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

/// Extension pour convertir une couleur en chaîne hexadécimale
extension ColorHexString on Color {
  String toHex() {
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

/// Extension pour créer une couleur à partir d'une chaîne hexadécimale
extension HexStringColor on String {
  Color fromHex() {
    final hex = replaceFirst('#', '').toUpperCase();
    if (hex.isEmpty || (hex.length != 6 && hex.length != 8)) {
      throw FormatException('Invalid hex color string: $this');
    }

    final normalizedHex = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.parse('0x$normalizedHex'));
  }
}

/// Couleurs par défaut
const Color _defaultPrimaryLight = Color(0xFF646496);
final Color _defaultPrimaryDark = Color.lerp(_defaultPrimaryLight, Colors.white, 0.3)!;

/// Clé pour SharedPreferences
const String _primaryColorKey = 'primary_color';

/// Récupère la couleur primaire en fonction du thème actuel
Future<Color> getPrimaryColor(ThemeMode theme) async {
  final prefs = await SharedPreferences.getInstance();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  if (prefs.containsKey(_primaryColorKey)) {
    final colors = prefs.getStringList(_primaryColorKey)!;
    if (colors.length > index) {
      try {
        return colors[index].fromHex();
      } catch (e) {
        debugPrint('Erreur lors de la conversion de la couleur : $e');
      }
    }
  }

  return index == ThemeMode.dark.index ? _defaultPrimaryDark : _defaultPrimaryLight;
}

/// Sauvegarde une couleur primaire pour un thème donné
Future<void> setPrimaryColor(ThemeMode theme, Color color) async {
  final prefs = await SharedPreferences.getInstance();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  List<String> colors = prefs.getStringList(_primaryColorKey) ?? [
    _defaultPrimaryLight.toHex(),
    _defaultPrimaryDark.toHex(),
    '#FF646496' // Optionnel : une couleur par défaut pour ThemeMode.system
  ];

  // Assure que la liste a au moins 3 éléments
  while (colors.length < 3) {
    colors.add('#FF646496');
  }

  colors[index] = color.toHex();

  await prefs.setStringList(_primaryColorKey, colors);
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
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('catalog_date', catalogDate);
}

/* LIBRARY LANGUAGE */
Future<List<String>?> getLibraryLanguage() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('library_language') == true && prefs.getStringList('library_language') != null) {
    return prefs.getStringList('library_language');
  }
  return ['0', 'E', 'English', 'en', '0', 'ROMAN', 'Roman', '0', '0', '0', '0', '1', 'r1', 'lp-e'];
}

Future<void> setLibraryLanguage(Map<String, dynamic> selectedLanguage) async {
  JwLifeSettings().currentLanguage = MepsLanguage.fromJson(selectedLanguage);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setStringList('library_language', [
    JwLifeSettings().currentLanguage.id.toString(),
    JwLifeSettings().currentLanguage.symbol,
    JwLifeSettings().currentLanguage.vernacular,
    JwLifeSettings().currentLanguage.primaryIetfCode,
    JwLifeSettings().currentLanguage.isSignLanguage == true ? '1' : '0',
    JwLifeSettings().currentLanguage.internalScriptName,
    JwLifeSettings().currentLanguage.displayScriptName,
    JwLifeSettings().currentLanguage.isBidirectional == true ? '1' : '0',
    JwLifeSettings().currentLanguage.isRtl == true ? '1' : '0',
    JwLifeSettings().currentLanguage.isCharacterSpaced == true ? '1' : '0',
    JwLifeSettings().currentLanguage.isCharacterBreakable == true ? '1' : '0',
    JwLifeSettings().currentLanguage.hasSystemDigits == true ? '1' : '0',
    JwLifeSettings().currentLanguage.rsConf,
    JwLifeSettings().currentLanguage.lib,
  ]);
}

/* WEB APP FOLDER */
Future<bool> getWebAppDownload() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('webapp_download') == true) {
    return prefs.getBool('webapp_download')!;
  }
  return false;
}

Future<void> setWebAppDownload(bool download) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('webapp_download', download);
}

/* FONT SIZE PUBLICATION */
Future<double> getFontSize() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('font_size') == true) {
    return prefs.getDouble('font_size')!;
  }
  return 20;
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
