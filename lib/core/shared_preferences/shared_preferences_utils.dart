import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/meps_language.dart';
import '../../i18n/localization.dart';
import '../constants.dart';
import 'shared_preferences_keys.dart'; // Assurez-vous d'importer vos clés

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

class AppSharedPreferences {
  // 1. Instance statique (singleton)
  static final AppSharedPreferences instance = AppSharedPreferences._internal();

  // 2. Variable pour stocker l'instance de SharedPreferences
  late final SharedPreferences _sp;

  // 3. Constructeur privé pour le singleton
  AppSharedPreferences._internal();

  /// 5. Méthode d'initialisation asynchrone.
  /// Doit être appelée au démarrage de l'application (ex: dans main()).
  Future<void> initialize() async {
    _sp = await SharedPreferences.getInstance();
  }

  // --- THÈME ---

  String getTheme() {
    return _sp.getString(SharedPreferencesKeys.theme.key) ?? SharedPreferencesKeys.theme.defaultValue;
  }

  Future<void> setTheme(String theme) async {
    await _sp.setString(SharedPreferencesKeys.theme.key, theme);
  }

  // --- COULEUR PRIMAIRE ---

  Color getPrimaryColor(ThemeMode theme) {
    final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
        ? ThemeMode.dark.index
        : ThemeMode.light.index;

    final colors = _sp.getStringList(SharedPreferencesKeys.primaryColor.key);
    if (colors != null && colors.length > index) {
      try {
        return colors[index].fromHex();
      } catch (e) {
        debugPrint('Erreur conversion couleur : $e');
      }
    }
    return index == ThemeMode.dark.index ? Constants.defaultDarkPrimaryColor : Constants.defaultLightPrimaryColor;
  }

  Future<void> setPrimaryColor(ThemeMode theme, Color color) async {
    final index = WidgetsBinding.instance.window.platformBrightness == Brightness.dark
        ? ThemeMode.dark.index
        : ThemeMode.light.index;

    List<String> colors = _sp.getStringList(SharedPreferencesKeys.primaryColor.key) ?? [
      Constants.defaultLightPrimaryColor.toHex(),
      Constants.defaultDarkPrimaryColor.toHex(),
      '#FF646496'
    ];

    while (colors.length < 3) {
      colors.add('#FF646496');
    }
    colors[index] = color.toHex();
    await _sp.setStringList(SharedPreferencesKeys.primaryColor.key, colors);
  }

  // --- COULEUR BIBLE ---

  Color getBibleColor() {
    final color = _sp.getString(SharedPreferencesKeys.bibleColor.key);
    if (color != null) {
      try {
        return color.fromHex();
      } catch (e) {
        debugPrint('Erreur conversion couleur : $e');
      }
    }
    return Constants.defaultBibleColor;
  }

  Future<void> setBibleColor(Color color) async {
    await _sp.setString(SharedPreferencesKeys.bibleColor.key, color.toHex());
  }

  // --- LOCALE ---

  String getLocale() {
    if (_sp.containsKey(SharedPreferencesKeys.locale.key)) {
      return _sp.getString(SharedPreferencesKeys.locale.key) ?? SharedPreferencesKeys.locale.defaultValue;
    }
    Locale deviceLocale = WidgetsBinding.instance.window.locales.first;
    if (AppLocalizations.supportedLocales.contains(Locale(deviceLocale.languageCode))) {
      return deviceLocale.languageCode;
    }
    return SharedPreferencesKeys.locale.defaultValue;
  }

  Future<void> setLocale(String locale) async {
    await _sp.setString(SharedPreferencesKeys.locale.key, locale);
  }

  // --- CATALOG REVISION ---

  int getLastCatalogRevision() {
    return _sp.getInt(SharedPreferencesKeys.lastCatalogRevision.key) ?? SharedPreferencesKeys.lastCatalogRevision.defaultValue;
  }

  Future<void> setNewCatalogRevision(int catalogRevision) async {
    await _sp.setInt(SharedPreferencesKeys.lastCatalogRevision.key, catalogRevision);
  }

  String getLastMepsTimestamp() {
    return _sp.getString(SharedPreferencesKeys.lastMepsTimestamp.key) ?? SharedPreferencesKeys.lastMepsTimestamp.defaultValue;
  }

  Future<void> setNewMepsTimestamp(String lastMepsTimestamp) async {
    await _sp.setString(SharedPreferencesKeys.lastMepsTimestamp.key, lastMepsTimestamp);
  }

  // --- LIBRARY LANGUAGE ---

  List<String> getLibraryLanguage() {
    return _sp.getStringList(SharedPreferencesKeys.libraryLanguage.key) ?? List<String>.from(SharedPreferencesKeys.libraryLanguage.defaultValue);
  }

  Future<void> setLibraryLanguage(dynamic selectedLanguage) async {
    if(selectedLanguage is Map<String, dynamic>) {
      // Attention: Assurez-vous que JwLifeSettings est initialisé si vous l'utilisez ici.
      // Dans le contexte de cette classe, il peut être préférable de passer directement l'objet MepsLanguage
      // ou de gérer l'instance JwLifeSettings en dehors.
      JwLifeSettings.instance.currentLanguage.value = MepsLanguage.fromJson(selectedLanguage);
    }

    await _sp.setStringList(SharedPreferencesKeys.libraryLanguage.key, [
      JwLifeSettings.instance.currentLanguage.value.id.toString(),
      JwLifeSettings.instance.currentLanguage.value.symbol,
      JwLifeSettings.instance.currentLanguage.value.vernacular,
      JwLifeSettings.instance.currentLanguage.value.primaryIetfCode,
      JwLifeSettings.instance.currentLanguage.value.isSignLanguage ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.internalScriptName,
      JwLifeSettings.instance.currentLanguage.value.displayScriptName,
      JwLifeSettings.instance.currentLanguage.value.isBidirectional ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.isRtl ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.isCharacterSpaced ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.isCharacterBreakable ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.hasSystemDigits ? '1' : '0',
      JwLifeSettings.instance.currentLanguage.value.rsConf,
      JwLifeSettings.instance.currentLanguage.value.lib,
    ]);
  }

  // --- WEB APP FOLDER ---

  String getWebAppVersion() {
    return _sp.getString(SharedPreferencesKeys.webAppDownloadVersion.key) ?? SharedPreferencesKeys.webAppDownloadVersion.defaultValue;
  }

  Future<void> setWebAppVersion(String webappVersion) async {
    await _sp.setString(SharedPreferencesKeys.webAppDownloadVersion.key, webappVersion);
  }

  // --- FONT SIZE PUBLICATION ---

  double getFontSize() {
    return _sp.getDouble(SharedPreferencesKeys.fontSize.key) ?? SharedPreferencesKeys.fontSize.defaultValue;
  }

  Future<void> setFontSize(double fontSize) async {
    await _sp.setDouble(SharedPreferencesKeys.fontSize.key, fontSize);
  }

  // --- FULLSCREEN PUBLICATION ---

  bool getFullscreenMode() {
    return _sp.getBool(SharedPreferencesKeys.fullscreenMode.key) ?? SharedPreferencesKeys.fullscreenMode.defaultValue;
  }

  Future<void> setFullscreenMode(bool fullscreen) async {
    await _sp.setBool(SharedPreferencesKeys.fullscreenMode.key, fullscreen);
  }

  // --- READING MODE PUBLICATION ---

  bool getReadingMode() {
    return _sp.getBool(SharedPreferencesKeys.readingMode.key) ?? SharedPreferencesKeys.readingMode.defaultValue;
  }

  Future<void> setReadingMode(bool reading) async {
    await _sp.setBool(SharedPreferencesKeys.readingMode.key, reading);
  }

  // --- BLOCKING HORIZONTALLY MODE PUBLICATION ---

  bool getBlockingHorizontallyMode() {
    return _sp.getBool(SharedPreferencesKeys.blockingHorizontallyMode.key) ?? SharedPreferencesKeys.blockingHorizontallyMode.defaultValue;
  }

  Future<void> setBlockingHorizontallyMode(bool blocking) async {
    await _sp.setBool(SharedPreferencesKeys.blockingHorizontallyMode.key, blocking);
  }

  // --- WEBVIEW STYLE ---

  int getStyleIndex() {
    return _sp.getInt(SharedPreferencesKeys.styleIndex.key) ?? SharedPreferencesKeys.styleIndex.defaultValue;
  }

  Future<void> setStyleIndex(int styleIndex) async {
    await _sp.setInt(SharedPreferencesKeys.styleIndex.key, styleIndex);
  }

  int getColorIndex() {
    return _sp.getInt(SharedPreferencesKeys.colorIndex.key) ?? SharedPreferencesKeys.colorIndex.defaultValue;
  }

  Future<void> setColorIndex(int colorIndex) async {
    await _sp.setInt(SharedPreferencesKeys.colorIndex.key, colorIndex);
  }

  String getLookUpBible() {
    return _sp.getString(SharedPreferencesKeys.lookupBible.key) ?? SharedPreferencesKeys.lookupBible.defaultValue;
  }

  Future<void> setLookUpBible(String lookupBible) async {
    await _sp.setString(SharedPreferencesKeys.lookupBible.key, lookupBible);
  }

  List<String> getBiblesSet() {
    return _sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? List<String>.from(SharedPreferencesKeys.biblesSet.defaultValue);
  }

  Future<void> addBibleSet(String bible) async {
    final existingBibles = _sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? [];

    if (!existingBibles.contains(bible)) {
      existingBibles.add(bible);
      await _sp.setStringList(SharedPreferencesKeys.biblesSet.key, existingBibles);
    }
  }

  Future<void> removeBibleFromSet(String bible) async {
    final existingBibles = _sp.getStringList(SharedPreferencesKeys.biblesSet.key) ?? [];

    if (existingBibles.remove(bible)) {
      await _sp.setStringList(SharedPreferencesKeys.biblesSet.key, existingBibles);
    }
  }

  Future<void> setBiblesSet(List<String> biblesSet) async {
    await _sp.setStringList(SharedPreferencesKeys.biblesSet.key, biblesSet);
  }


  // --- Rappels et notifications ---

  bool getDailyTextNotification() {
    return _sp.getBool(SharedPreferencesKeys.dailyTextNotification.key) ?? SharedPreferencesKeys.dailyTextNotification.defaultValue;
  }

  Future<void> setDailyTextNotification(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.dailyTextNotification.key, active);
  }

  DateTime getDailyTextNotificationTime() {
    String timeString = _sp.getString(SharedPreferencesKeys.dailyTextNotificationTime.key) ?? SharedPreferencesKeys.dailyTextNotificationTime.defaultValue;

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
    String formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await _sp.setString(SharedPreferencesKeys.dailyTextNotificationTime.key, formattedTime);
  }

  bool getBibleReadingNotification() {
    return _sp.getBool(SharedPreferencesKeys.bibleReadingNotification.key) ?? SharedPreferencesKeys.bibleReadingNotification.defaultValue;
  }

  Future<void> setBibleReadingNotification(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.bibleReadingNotification.key, active);
  }

  DateTime getBibleReadingNotificationTime() {
    String timeString = _sp.getString(SharedPreferencesKeys.bibleReadingNotificationTime.key) ?? SharedPreferencesKeys.bibleReadingNotificationTime.defaultValue;

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
    String formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await _sp.setString(SharedPreferencesKeys.bibleReadingNotificationTime.key, formattedTime);
  }

  bool getDownloadNotification() {
    return _sp.getBool(SharedPreferencesKeys.downloadNotification.key) ?? SharedPreferencesKeys.downloadNotification.defaultValue;
  }

  Future<void> setDownloadNotification(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.downloadNotification.key, active);
  }
}