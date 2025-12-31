import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/theme.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import '../../core/constants.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../data/models/meps_language.dart';

class JwLifeSettings {
  static final JwLifeSettings instance = JwLifeSettings._internal();
  JwLifeSettings._internal();

  ThemeMode themeMode = ThemeMode.system;
  String pageTransition = 'default';
  ThemeData lightData = AppTheme.getLightTheme(Constants.defaultLightPrimaryColor);
  ThemeData darkData = AppTheme.getDarkTheme(Constants.defaultDarkPrimaryColor);
  List<MapEntry<Locale, String>> appLocalesMeps = [];
  Locale locale = Locale(AppSharedPreferences.instance.getLocale());
  WebViewData webViewData = WebViewData();
  Color lightPrimaryColor = Constants.defaultLightPrimaryColor;
  Color darkPrimaryColor = Constants.defaultDarkPrimaryColor;
  Color bibleColor = Constants.defaultBibleColor;

  bool notificationDownload = false;

  // --- NOTIFIERS DE LANGUES ---
  final libraryLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());
  final dailyTextLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());
  final articlesLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());
  final workshipLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());
  final teachingToolboxLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());
  final latestLanguage = ValueNotifier<MepsLanguage>(_defaultMeps());

  final lookupBible = ValueNotifier<String>('');

  Future<void> init() async {
    final sharedPreferences = AppSharedPreferences.instance;

    // ... (Ton code d'initialisation existant pour thèmes et couleurs)
    final theme = sharedPreferences.getTheme();
    final pageTrans = sharedPreferences.getPageTransition();
    final themeMod = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
    final lightColor = sharedPreferences.getPrimaryColor(ThemeMode.light);
    final darkColor = sharedPreferences.getPrimaryColor(ThemeMode.dark);

    lightPrimaryColor = lightColor;
    darkPrimaryColor = darkColor;
    bibleColor = sharedPreferences.getBibleColor();
    locale = Locale(sharedPreferences.getLocale());
    themeMode = themeMod;
    pageTransition = pageTrans;
    lightData = AppTheme.getLightTheme(lightColor);
    darkData = AppTheme.getDarkTheme(darkColor);

    // --- INITIALISATION DES LANGUES ---
    libraryLanguage.value = _mapListToMeps(await sharedPreferences.getLibraryLanguage());
    dailyTextLanguage.value = _mapListToMeps(await sharedPreferences.getDailyTextLanguage());
    articlesLanguage.value = _mapListToMeps(await sharedPreferences.getArticlesLanguage());
    workshipLanguage.value = _mapListToMeps(await sharedPreferences.getWorkshipLanguage());
    teachingToolboxLanguage.value = _mapListToMeps(await sharedPreferences.getTeachingToolboxLanguage());
    latestLanguage.value = _mapListToMeps(await sharedPreferences.getLatestLanguage());

    notificationDownload = sharedPreferences.getDownloadNotification();
    lookupBible.value = sharedPreferences.getLookUpBible();
  }

  /// Convertit la liste stockée en SharedPreferences vers l'objet modèle
  MepsLanguage _mapListToMeps(List<String> data) {
    if (data.length < 15) return _defaultMeps(); // Sécurité
    return MepsLanguage(
      id: int.parse(data[0]),
      symbol: data[1],
      vernacular: data[2],
      primaryIetfCode: data[3],
      isSignLanguage: data[4] == '1',
      internalScriptName: data[5],
      displayScriptName: data[6],
      isBidirectional: data[7] == '1',
      isRtl: data[8] == '1',
      isCharacterSpaced: data[9] == '1',
      isCharacterBreakable: data[10] == '1',
      hasSystemDigits: data[11] == '1',
      fallbackPrimaryIetfCode: data[12],
      rsConf: data[13],
      lib: data[14],
    );
  }

  /// Valeur par défaut (English) pour éviter les erreurs d'initialisation
  static MepsLanguage _defaultMeps() {
    return MepsLanguage(
      id: 0,
      symbol: 'E',
      vernacular: 'English',
      primaryIetfCode: 'en',
      isSignLanguage: false,
      internalScriptName: 'ROMAN',
      displayScriptName: 'Roman',
      isBidirectional: false,
      isRtl: false,
      isCharacterSpaced: false,
      isCharacterBreakable: false,
      hasSystemDigits: false,
      fallbackPrimaryIetfCode: 'en',
      rsConf: 'r1',
      lib: 'lp-e',
    );
  }
}