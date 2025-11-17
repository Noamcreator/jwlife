import 'package:flutter/material.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/meps_language.dart';
import '../../i18n/localization.dart';
import '../constants.dart';

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
  return index == ThemeMode.dark.index ? Constants.defaultDarkPrimaryColor : Constants.defaultLightPrimaryColor;
}

/// Sauvegarde une couleur primaire
Future<void> setPrimaryColor(ThemeMode theme, Color color) async {
  final sp = await _getSP();
  final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark ? ThemeMode.dark.index : ThemeMode.light.index;

  List<String> colors = sp.getStringList(SharedPreferencesKeys.primaryColor.key) ?? [
    Constants.defaultLightPrimaryColor.toHex(),
    Constants.defaultDarkPrimaryColor.toHex(),
    '#FF646496'
  ];

  while (colors.length < 3) {
    colors.add('#FF646496');
  }
  colors[index] = color.toHex();
  await sp.setStringList(SharedPreferencesKeys.primaryColor.key, colors);
}

/// Récupère la couleur primaire
Future<Color> getBibleColor() async {
  final sp = await _getSP();

  final color = sp.getString(SharedPreferencesKeys.bibleColor.key);
  if (color != null) {
    try {
      return color.fromHex();
    }
    catch (e) {
      debugPrint('Erreur conversion couleur : $e');
    }
  }
  return Constants.defaultBibleColor;
}

/// Sauvegarde une couleur primaire
Future<void> setBibleColor(Color color) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.bibleColor.key, color.toHex());
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

Future<void> setLibraryLanguage(dynamic selectedLanguage) async {
  if(selectedLanguage is Map<String, dynamic>) {
    JwLifeSettings().currentLanguage = MepsLanguage.fromJson(selectedLanguage);
  }

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
Future<bool> getFullscreenMode() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.fullscreenMode.key) ?? SharedPreferencesKeys.fullscreenMode.defaultValue;
}

Future<void> setFullscreenMode(bool fullscreen) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.fullscreenMode.key, fullscreen);
}

/* READING MODE PUBLICATION */
Future<bool> getReadingMode() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.readingMode.key) ?? SharedPreferencesKeys.readingMode.defaultValue;
}

Future<void> setReadingMode(bool fullscreen) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.readingMode.key, fullscreen);
}

/* PREPARING MODE PUBLICATION */
Future<bool> getPreparingMode() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.preparingMode.key) ?? SharedPreferencesKeys.preparingMode.defaultValue;
}

Future<void> setPreparingMode(bool preparing) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.preparingMode.key, preparing);
}

/* WEBVIEW STYLE */
Future<int> getStyleIndex() async {
  final sp = await _getSP();
  return sp.getInt(SharedPreferencesKeys.styleIndex.key) ?? SharedPreferencesKeys.styleIndex.defaultValue;
}

Future<void> setStyleIndex(int styleIndex) async {
  final sp = await _getSP();
  await sp.setInt(SharedPreferencesKeys.styleIndex.key, styleIndex);
}

Future<int> getColorIndex() async {
  final sp = await _getSP();
  return sp.getInt(SharedPreferencesKeys.colorIndex.key) ?? SharedPreferencesKeys.colorIndex.defaultValue;
}

Future<void> setColorIndex(int colorIndex) async {
  final sp = await _getSP();
  await sp.setInt(SharedPreferencesKeys.colorIndex.key, colorIndex);
}

Future<String> getLookUpBible() async {
  final sp = await _getSP();
  return sp.getString(SharedPreferencesKeys.lookupBible.key) ?? SharedPreferencesKeys.lookupBible.defaultValue;
}

Future<void> setLookUpBible(String lookupBible) async {
  final sp = await _getSP();
  await sp.setString(SharedPreferencesKeys.lookupBible.key, lookupBible);
}

Future<List<String>> getBiblesSet() async {
  final sp = await _getSP();
  return sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? List<String>.from(SharedPreferencesKeys.biblesSet.defaultValue);
}

Future<void> addBibleSet(String bible) async {
  final sp = await _getSP();
  final existingBibles = sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? [];

  if (!existingBibles.contains(bible)) {
    existingBibles.add(bible);
    await sp.setStringList(SharedPreferencesKeys.biblesSet.key, existingBibles);
  }
}

Future<void> removeBibleFromSet(String bible) async {
  final sp = await _getSP();
  final existingBibles = sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? [];

  if (existingBibles.remove(bible)) {
    await sp.setStringList(SharedPreferencesKeys.biblesSet.key, existingBibles);
  }
}

Future<void> setBiblesSet(List<String> biblesSet) async {
  final sp = await _getSP();
  await sp.setStringList(SharedPreferencesKeys.biblesSet.key, biblesSet);
}


/* Rappeles et notifications */
Future<bool> getDailyTextNotification() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.dailyTextNotification.key) ?? SharedPreferencesKeys.dailyTextNotification.defaultValue;
}

Future<void> setDailyTextNotification(bool active) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.dailyTextNotification.key, active);
}

Future<DateTime> getDailyTextNotificationTime() async {
  final sp = await _getSP();
  String timeString = sp.getString(SharedPreferencesKeys.dailyTextNotificationTime.key) ?? SharedPreferencesKeys.dailyTextNotificationTime.defaultValue;

  // Sépare la chaîne en heures et minutes
  List<String> parts = timeString.split(':');
  int hour = int.parse(parts[0]);
  int minute = int.parse(parts[1]);

  // Crée un nouvel objet DateTime avec la date d'aujourd'hui et l'heure stockée
  return DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    hour,
    minute,
  );
}

Future<void> setDailyTextNotificationTime(DateTime time) async {
  final sp = await _getSP();
  String formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  await sp.setString(SharedPreferencesKeys.dailyTextNotificationTime.key, formattedTime);
}

Future<bool> getBibleReadingNotification() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.bibleReadingNotification.key) ?? SharedPreferencesKeys.bibleReadingNotification.defaultValue;
}

Future<void> setBibleReadingNotification(bool active) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.bibleReadingNotification.key, active);
}

Future<DateTime> getBibleReadingNotificationTime() async {
  final sp = await _getSP();
  String timeString = sp.getString(SharedPreferencesKeys.bibleReadingNotificationTime.key) ?? SharedPreferencesKeys.bibleReadingNotificationTime.defaultValue;

  // Sépare la chaîne en heures et minutes
  List<String> parts = timeString.split(':');
  int hour = int.parse(parts[0]);
  int minute = int.parse(parts[1]);

  // Crée un nouvel objet DateTime avec la date d'aujourd'hui et l'heure stockée
  return DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    hour,
    minute,
  );
}

Future<void> setBibleReadingNotificationTime(DateTime time) async {
  final sp = await _getSP();
  String formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  await sp.setString(SharedPreferencesKeys.bibleReadingNotificationTime.key, formattedTime);
}

Future<bool> getDownloadNotification() async {
  final sp = await _getSP();
  return sp.getBool(SharedPreferencesKeys.downloadNotification.key) ?? SharedPreferencesKeys.downloadNotification.defaultValue;
}

Future<void> setDownloadNotification(bool active) async {
  final sp = await _getSP();
  await sp.setBool(SharedPreferencesKeys.downloadNotification.key, active);
}