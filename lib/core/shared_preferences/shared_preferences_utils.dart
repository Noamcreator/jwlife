import 'package:flutter/material.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/app_localizations.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/meps_language.dart';

/// Récupère l’instance SharedPreferences (singleton)
Future<SharedPreferences> _getSP() async => SharedPreferences.getInstance();

/* THEME */
Future<String> getTheme() async {
  final sp = await _getSP();
  return sp.getString(SharedPreferencesKeys.theme.key) ?? SharedPreferencesKeys.theme.defaultValue;
}

Future<void> setTheme(String theme) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.theme.key, theme);
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
  final sp = await _getSP();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
      ? ThemeMode.dark.index
      : ThemeMode.light.index;

  final colors = sp.getStringList(SharedPreferencesKeys.primaryColor.key);
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
  final sp = await _getSP();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark ? ThemeMode.dark.index : ThemeMode.light.index;

  List<String> colors = sp.getStringList(SharedPreferencesKeys.primaryColor.key) ?? [
    _defaultPrimaryLight.toHex(),
    _defaultPrimaryDark.toHex(),
    '#FF646496'
  ];

  while (colors.length < 3) {
    colors.add('#FF646496');
  }
  colors[index] = color.toHex();
  await sp.setStringList(SharedPreferencesKeys.primaryColor.key, colors);
}

/* LOCALE */
Future<String> getLocale() async {
  final sp = await _getSP();
  if (sp.containsKey(SharedPreferencesKeys.locale.key)) {
    return sp.getString(SharedPreferencesKeys.locale.key) ?? SharedPreferencesKeys.locale.defaultValue;
  }
  Locale deviceLocale = WidgetsBinding.instance.window.locales.first;
  if (AppLocalizations.supportedLocales.contains(Locale(deviceLocale.languageCode))) {
    return deviceLocale.languageCode;
  }
  return SharedPreferencesKeys.locale.defaultValue;
}

Future<void> setLocale(String locale) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.locale.key, locale);
}

/* CATALOG REVISION */
Future<int> getLastCatalogRevision() async {
  final sp = await _getSP();
  return sp.getInt(SharedPreferencesKeys.lastCatalogRevision.key) ?? SharedPreferencesKeys.lastCatalogRevision.defaultValue;
}

Future<void> setNewCatalogRevision(int catalogRevision) async {
  final sp = await _getSP();
  await sp.setInt(SharedPreferencesKeys.lastCatalogRevision.key, catalogRevision);
}

Future<String> getLastMepsTimestamp() async {
  final sp = await _getSP();
  return sp.getString(SharedPreferencesKeys.lastMepsTimestamp.key) ?? SharedPreferencesKeys.lastMepsTimestamp.defaultValue;
}

Future<void> setNewMepsTimestamp(String lastMepsTimestamp) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.lastMepsTimestamp.key, lastMepsTimestamp);
}

/* LIBRARY LANGUAGE */
Future<List<String>> getLibraryLanguage() async {
  final sp = await _getSP();
  return sp.getStringList(SharedPreferencesKeys.libraryLanguage.key) ?? List<String>.from(SharedPreferencesKeys.libraryLanguage.defaultValue);
}

Future<void> setLibraryLanguage(Map<String, dynamic> selectedLanguage) async {
  JwLifeSettings().currentLanguage = MepsLanguage.fromJson(selectedLanguage);
  final sp = await _getSP();
  await sp.setStringList(SharedPreferencesKeys.libraryLanguage.key, [
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
Future<String> getWebAppVersion() async {
  final sp = await _getSP();
  return sp.getString(SharedPreferencesKeys.webAppDownloadVersion.key) ?? SharedPreferencesKeys.webAppDownloadVersion.defaultValue;
}

Future<void> setWebAppVersion(String webappVersion) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.webAppDownloadVersion.key, webappVersion);
}

/* FONT SIZE PUBLICATION */
Future<double> getFontSize() async {
  final sp = await _getSP();
  return sp.getDouble(SharedPreferencesKeys.fontSize.key) ?? SharedPreferencesKeys.fontSize.defaultValue;
}

Future<void> setFontSize(double fontSize) async {
  final sp = await _getSP();
  await sp.setDouble(SharedPreferencesKeys.fontSize.key, fontSize);
}

/* FULLSCREEN PUBLICATION */
Future<bool> getFullscreen() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.fullscreen.key) ?? SharedPreferencesKeys.fullscreen.defaultValue;
}

Future<void> setFullscreen(bool fullscreen) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.fullscreen.key, fullscreen);
}

/* HIGHLIGHT */
Future<int> getLastHighlightColorIndex() async {
  final sp = await _getSP();
  return sp.getInt(SharedPreferencesKeys.lastHighlightColorIndex.key) ?? SharedPreferencesKeys.lastHighlightColorIndex.defaultValue;
}

Future<void> setLastHighlightColor(int lastColorIndex) async {
  final sp = await _getSP();
  await sp.setInt(SharedPreferencesKeys.lastHighlightColorIndex.key, lastColorIndex);
}
