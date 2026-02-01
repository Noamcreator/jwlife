import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
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

  // --- PAGE TRANSITION ----

  String getPageTransition() {
    return _sp.getString(SharedPreferencesKeys.pageTransition.key) ?? SharedPreferencesKeys.pageTransition.defaultValue;
  }

  Future<void> setPageTransition(String pageTransition) async {
    await _sp.setString(SharedPreferencesKeys.pageTransition.key, pageTransition);
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
    if (AppLocalizations.supportedLocales.contains(deviceLocale)) {
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

  // Récupère n'importe quelle langue (Library, Meetings, etc.)
  Future<List<String>> _getLanguageByKey(PrefKey pref) async {
    // 1. Tenter de récupérer la valeur actuelle
    List<String>? currentData = _sp.getStringList(pref.key);

    // 2. Vérifier si les données existent et sont valides (longueur 15)
    if (currentData == null || currentData.length != 15) {
      // Si corrompu ou absent, on cherche en DB
      dynamic mepsData = await _fetchMepsLanguageFromDb();

      if (mepsData != null) {
        await _setLanguageByKey(pref, mepsData);
        return _sp.getStringList(pref.key) ?? List<String>.from(pref.defaultValue);
      }
    }

    return currentData ?? List<String>.from(pref.defaultValue);
  }

// Sauvegarde n'importe quelle langue
  Future<void> _setLanguageByKey(PrefKey pref, dynamic selectedLanguage) async {
    MepsLanguage lang;
    if (selectedLanguage is Map<String, dynamic>) {
      lang = MepsLanguage.fromJson(selectedLanguage);
    }
    else if (selectedLanguage is MepsLanguage) {
      lang = selectedLanguage;
    }
    else {
      return;
    }

    if (pref.key == SharedPreferencesKeys.libraryLanguage.key) {
      JwLifeSettings.instance.libraryLanguage.value = lang;
    }
    else if (pref.key == SharedPreferencesKeys.dailyTextLanguage.key) {
      JwLifeSettings.instance.dailyTextLanguage.value = lang;
    }
    else if (pref.key == SharedPreferencesKeys.articlesLanguage.key) {
      JwLifeSettings.instance.articlesLanguage.value = lang;
    }
    else if (pref.key == SharedPreferencesKeys.workshipLanguage.key) {
      JwLifeSettings.instance.workshipLanguage.value = lang;
    }
    else if (pref.key == SharedPreferencesKeys.teachingToolboxLanguage.key) {
      JwLifeSettings.instance.teachingToolboxLanguage.value = lang;
    }
    else if (pref.key == SharedPreferencesKeys.latestLanguage.key) {
      JwLifeSettings.instance.latestLanguage.value = lang;
    }

    await _sp.setStringList(pref.key, [
      lang.id.toString(),
      lang.symbol,
      lang.vernacular,
      lang.primaryIetfCode,
      lang.isSignLanguage ? '1' : '0',
      lang.internalScriptName,
      lang.displayScriptName,
      lang.isBidirectional ? '1' : '0',
      lang.isRtl ? '1' : '0',
      lang.isCharacterSpaced ? '1' : '0',
      lang.isCharacterBreakable ? '1' : '0',
      lang.hasSystemDigits ? '1' : '0',
      lang.fallbackPrimaryIetfCode,
      lang.rsConf,
      lang.lib,
    ]);
  }

// Fonction SQL privée pour éviter la répétition
  Future<dynamic> _fetchMepsLanguageFromDb() async {
    File mepsFile = await getMepsUnitDatabaseFile();
    Database mepsDb = await openReadOnlyDatabase(mepsFile.path);

    Locale systemLocale = ui.PlatformDispatcher.instance.locale;

    List<Map<String, dynamic>> results = await mepsDb.rawQuery("""
      SELECT L.*, S.InternalName AS ScriptInternalName, S.DisplayName AS ScriptDisplayName,
             S.IsBidirectional, S.IsRTL, S.IsCharacterSpaced, S.IsCharacterBreakable,
             S.SupportsCodeNames, S.HasSystemDigits, F.PrimaryIetfCode AS FallbackPrimaryIetfCode
      FROM Language AS L
      INNER JOIN Script AS S ON L.ScriptId = S.ScriptId
      LEFT JOIN Language AS F ON L.PrimaryFallbackLanguageId = F.LanguageId
      WHERE L.PrimaryIetfCode = ?
      LIMIT 1;
    """, [systemLocale.languageCode]);

    return results.isNotEmpty ? results.first : null;
  }

  // Pour la bibliothèque
  Future<List<String>> getLibraryLanguage() => _getLanguageByKey(SharedPreferencesKeys.libraryLanguage);
  Future<void> setLibraryLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.libraryLanguage, language);

  // Pour le texte du jour
  Future<List<String>> getDailyTextLanguage() => _getLanguageByKey(SharedPreferencesKeys.dailyTextLanguage);
  Future<void> setDailyTextLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.dailyTextLanguage, language);

  // Pour les articles
  Future<List<String>> getArticlesLanguage() => _getLanguageByKey(SharedPreferencesKeys.articlesLanguage);
  Future<void> setArticlesLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.articlesLanguage, language);

  // Pour les réunions et les assemblées
  Future<List<String>> getWorkshipLanguage() => _getLanguageByKey(SharedPreferencesKeys.workshipLanguage);
  Future<void> setWorkshipLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.workshipLanguage, language);

  // Pour la boîte à outils d'enseignement
  Future<List<String>> getTeachingToolboxLanguage() => _getLanguageByKey(SharedPreferencesKeys.teachingToolboxLanguage);
  Future<void> setTeachingToolboxLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.teachingToolboxLanguage, language);

  // Pour les derniers publications/médias
  Future<List<String>> getLatestLanguage() => _getLanguageByKey(SharedPreferencesKeys.latestLanguage);
  Future<void> setLatestLanguage(dynamic language) => _setLanguageByKey(SharedPreferencesKeys.latestLanguage, language);

  // -- MENU --
  bool getShowPublicationDescription() => _sp.getBool(SharedPreferencesKeys.showPublicationDescription.key) ?? SharedPreferencesKeys.showPublicationDescription.defaultValue;
  void setShowPublicationDescription(bool value) => _sp.setBool(SharedPreferencesKeys.showPublicationDescription.key, value);

  bool getShowDocumentDescription() => _sp.getBool(SharedPreferencesKeys.showDocumentDescription.key) ?? SharedPreferencesKeys.showDocumentDescription.defaultValue;
  void setShowDocumentDescription(bool value) => _sp.setBool(SharedPreferencesKeys.showDocumentDescription.key, value);

  bool getAutoOpenSingleDocument() => _sp.getBool(SharedPreferencesKeys.autoOpenSingleDocument.key) ?? SharedPreferencesKeys.autoOpenSingleDocument.defaultValue;
  void setAutoOpenSingleDocument(bool value) => _sp.setBool(SharedPreferencesKeys.autoOpenSingleDocument.key, value);

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

  bool getVersesInParallel() {
    return _sp.getBool(SharedPreferencesKeys.versesInParallel.key) ?? SharedPreferencesKeys.versesInParallel.defaultValue;
  }

  Future<void> setVersesInParallel(bool versesInParallel) async {
    await _sp.setBool(SharedPreferencesKeys.versesInParallel.key, versesInParallel);
  }

  // --- PRONUNCIATION GUIDE ---

  bool getFuriganaActive() {
    return _sp.getBool(SharedPreferencesKeys.furiganaActive.key) ?? SharedPreferencesKeys.furiganaActive.defaultValue;
  }

  Future<void> setFuriganaActive(bool furigana) async {
    await _sp.setBool(SharedPreferencesKeys.furiganaActive.key, furigana);
  }

  bool getPinyinActive() {
    return _sp.getBool(SharedPreferencesKeys.pinyinActive.key) ?? SharedPreferencesKeys.pinyinActive.defaultValue;
  }

  Future<void> setPinyinActive(bool pinyin) async {
    await _sp.setBool(SharedPreferencesKeys.pinyinActive.key, pinyin);
  }

  bool getYaleActive() {
    return _sp.getBool(SharedPreferencesKeys.yaleActive.key) ?? SharedPreferencesKeys.yaleActive.defaultValue;
  }

  Future<void> setYaleActive(bool yale) async {
    await _sp.setBool(SharedPreferencesKeys.yaleActive.key, yale);
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

  // --- Play and download ---
  bool getStreamUsingCellularData() {
    return _sp.getBool(SharedPreferencesKeys.streamUsingCellularData.key) ?? SharedPreferencesKeys.streamUsingCellularData.defaultValue;
  }

  Future<void> setStreamUsingCellularData(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.streamUsingCellularData.key, active);
  }

  bool getDownloadUsingCellularData() {
    return _sp.getBool(SharedPreferencesKeys.downloadUsingCellularData.key) ?? SharedPreferencesKeys.downloadUsingCellularData.defaultValue;
  }

  Future<void> setDownloadUsingCellularData(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.downloadUsingCellularData.key, active);
  }

  bool getOfflineMode() {
    return _sp.getBool(SharedPreferencesKeys.offlineMode.key) ?? SharedPreferencesKeys.offlineMode.defaultValue;
  }

  Future<void> setOfflineMode(bool active) async {
    await _sp.setBool(SharedPreferencesKeys.offlineMode.key, active);
  }

 // --- Playlists ---

  int getPlaylistStartupAction() {
    return _sp.getInt(SharedPreferencesKeys.playlistStartupAction.key) ?? SharedPreferencesKeys.playlistStartupAction.defaultValue;
  }

  Future<void> setPlaylistStartupAction(int action) async {
    await _sp.setInt(SharedPreferencesKeys.playlistStartupAction.key, action);
  }

  int getPlaylistEndAction() {
    return _sp.getInt(SharedPreferencesKeys.playlistEndAction.key) ?? SharedPreferencesKeys.playlistEndAction.defaultValue;
  }

  Future<void> setPlaylistEndAction(int action) async {
    await _sp.setInt(SharedPreferencesKeys.playlistEndAction.key, action);
  }
}