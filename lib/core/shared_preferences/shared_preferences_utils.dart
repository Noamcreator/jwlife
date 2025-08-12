import 'package:flutter/material.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/app_localizations.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/meps_language.dart';

/* THEME */
Future<String> getTheme() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(SharedPreferencesKeys.theme.key) ?? SharedPreferencesKeys.theme.defaultValue;
}

Future<void> setTheme(String theme) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(SharedPreferencesKeys.theme.key, theme);
}

/// Extension pour convertir une couleur en chaîne hexadécimale
extension ColorHexString on Color {
  String toHex() => '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
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

/// Récupère la couleur primaire
Future<Color> getPrimaryColor(ThemeMode theme) async {
  final prefs = await SharedPreferences.getInstance();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  final colors = prefs.getStringList(SharedPreferencesKeys.primaryColor.key);
  if (colors != null && colors.length > index) {
    try {
      return colors[index].fromHex();
    } catch (e) {
      debugPrint('Erreur conversion couleur : $e');
    }
  }
  return index == ThemeMode.dark.index ? _defaultPrimaryDark : _defaultPrimaryLight;
}

/// Sauvegarde une couleur primaire
Future<void> setPrimaryColor(ThemeMode theme, Color color) async {
  final prefs = await SharedPreferences.getInstance();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark ? ThemeMode.dark.index : ThemeMode.light.index;

  List<String> colors = prefs.getStringList(SharedPreferencesKeys.primaryColor.key) ?? [
    _defaultPrimaryLight.toHex(),
    _defaultPrimaryDark.toHex(),
    '#FF646496'
  ];

  while (colors.length < 3) {
    colors.add('#FF646496');
  }
  colors[index] = color.toHex();
  await prefs.setStringList(SharedPreferencesKeys.primaryColor.key, colors);
}

/* LOCALE */
Future<String> getLocale() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(SharedPreferencesKeys.locale.key)) {
    return prefs.getString(SharedPreferencesKeys.locale.key) ?? SharedPreferencesKeys.locale.defaultValue;
  }
  Locale deviceLocale = WidgetsBinding.instance.window.locales.first;
  if (AppLocalizations.supportedLocales.contains(Locale(deviceLocale.languageCode))) {
    return deviceLocale.languageCode;
  }
  return SharedPreferencesKeys.locale.defaultValue;
}

Future<void> setLocale(String locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(SharedPreferencesKeys.locale.key, locale);
}

/* CATALOG REVISION */
Future<int> getLastCatalogRevision() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(SharedPreferencesKeys.lastCatalogRevision.key) ?? SharedPreferencesKeys.lastCatalogRevision.defaultValue;
}

Future<void> setNewCatalogRevision(int catalogRevision) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(SharedPreferencesKeys.lastCatalogRevision.key, catalogRevision);
}

/* LIBRARY LANGUAGE */
Future<List<String>> getLibraryLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(SharedPreferencesKeys.libraryLanguage.key) ?? List<String>.from(SharedPreferencesKeys.libraryLanguage.defaultValue);
}

Future<void> setLibraryLanguage(Map<String, dynamic> selectedLanguage) async {
  JwLifeSettings().currentLanguage = MepsLanguage.fromJson(selectedLanguage);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(SharedPreferencesKeys.libraryLanguage.key, [
    JwLifeSettings().currentLanguage.id.toString(),
    JwLifeSettings().currentLanguage.symbol,
    JwLifeSettings().currentLanguage.vernacular,
    JwLifeSettings().currentLanguage.primaryIetfCode,
    JwLifeSettings().currentLanguage.isSignLanguage ? '1' : '0',
    JwLifeSettings().currentLanguage.internalScriptName,
    JwLifeSettings().currentLanguage.displayScriptName,
    JwLifeSettings().currentLanguage.isBidirectional ? '1' : '0',
    JwLifeSettings().currentLanguage.isRtl ? '1' : '0',
    JwLifeSettings().currentLanguage.isCharacterSpaced ? '1' : '0',
    JwLifeSettings().currentLanguage.isCharacterBreakable ? '1' : '0',
    JwLifeSettings().currentLanguage.hasSystemDigits ? '1' : '0',
    JwLifeSettings().currentLanguage.rsConf,
    JwLifeSettings().currentLanguage.lib,
  ]);
}

/* WEB APP FOLDER */
Future<bool> getWebAppDownload() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(SharedPreferencesKeys.webAppDownload.key) ?? SharedPreferencesKeys.webAppDownload.defaultValue;
}

Future<void> setWebAppDownload(bool download) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(SharedPreferencesKeys.webAppDownload.key, download);
}

/* FONT SIZE PUBLICATION */
Future<double> getFontSize() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(SharedPreferencesKeys.fontSize.key) ?? SharedPreferencesKeys.fontSize.defaultValue;
}

Future<void> setFontSize(double fontSize) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(SharedPreferencesKeys.fontSize.key, fontSize);
}

/* FULLSCREEN PUBLICATION */
Future<bool> getFullscreen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(SharedPreferencesKeys.fullscreen.key) ?? SharedPreferencesKeys.fullscreen.defaultValue;
}

Future<void> setFullscreen(bool fullscreen) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(SharedPreferencesKeys.fullscreen.key, fullscreen);
}

/* HIGHLIGHT */
Future<int> getLastHighlightColorIndex() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(SharedPreferencesKeys.lastHighlightColorIndex.key) ?? SharedPreferencesKeys.lastHighlightColorIndex.defaultValue;
}

Future<void> setLastHighlightColor(int lastColorIndex) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(SharedPreferencesKeys.lastHighlightColorIndex.key, lastColorIndex);
}
