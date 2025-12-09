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
  Locale locale = const Locale('en');
  WebViewData webViewData = WebViewData();
  Color lightPrimaryColor = Constants.defaultLightPrimaryColor;
  Color darkPrimaryColor = Constants.defaultDarkPrimaryColor;
  Color bibleColor = Constants.defaultBibleColor;

  bool notificationDownload = false;
  final currentLanguage = ValueNotifier<MepsLanguage>(MepsLanguage(
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
  ));

  final lookupBible = ValueNotifier<String>('');

  Future<void> init() async {
    final sharedPreferences = AppSharedPreferences.instance;
    final theme = sharedPreferences.getTheme();
    final pageTrans = sharedPreferences.getPageTransition();
    final themeMod = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;

    final lightColor = sharedPreferences.getPrimaryColor(ThemeMode.light);
    final darkColor = sharedPreferences.getPrimaryColor(ThemeMode.dark);
    lightPrimaryColor = lightColor;
    darkPrimaryColor = darkColor;

    final bibleColor = sharedPreferences.getBibleColor();
    this.bibleColor = bibleColor;

    final localeCode = sharedPreferences.getLocale();
    locale = Locale(localeCode);

    themeMode = themeMod;
    pageTransition = pageTrans;
    lightData = AppTheme.getLightTheme(lightColor);
    darkData = AppTheme.getDarkTheme(darkColor);
    
    List<String> libraryLanguage = await sharedPreferences.getLibraryLanguage();
    currentLanguage.value = MepsLanguage(
      id: int.parse(libraryLanguage[0]),
      symbol: libraryLanguage[1],
      vernacular: libraryLanguage[2],
      primaryIetfCode: libraryLanguage[3],
      isSignLanguage: libraryLanguage[4] == '1' ? true : false,
      internalScriptName: libraryLanguage[5],
      displayScriptName: libraryLanguage[6],
      isBidirectional: libraryLanguage[7] == '1' ? true : false,
      isRtl: libraryLanguage[8] == '1' ? true : false,
      isCharacterSpaced: libraryLanguage[9] == '1' ? true : false,
      isCharacterBreakable: libraryLanguage[10] == '1' ? true : false,
      hasSystemDigits: libraryLanguage[11] == '1' ? true : false,
      fallbackPrimaryIetfCode: libraryLanguage[12],
      rsConf: libraryLanguage[13],
      lib: libraryLanguage[14],
    );

    notificationDownload = sharedPreferences.getDownloadNotification();

    lookupBible.value = sharedPreferences.getLookUpBible();
  }
}
