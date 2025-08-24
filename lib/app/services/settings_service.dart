import 'package:flutter/material.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../data/models/meps_language.dart';

class JwLifeSettings {
  // Singleton
  static final JwLifeSettings _instance = JwLifeSettings._internal();
  factory JwLifeSettings() => _instance;
  JwLifeSettings._internal();

  ThemeMode themeMode = ThemeMode.system;
  ThemeData lightData = AppTheme.getLightTheme(const Color(0xFF646496));
  ThemeData darkData = AppTheme.getDarkTheme(Color.lerp(const Color(0xFF646496), Colors.white, 0.3)!);
  Locale locale = const Locale('en');
  late MepsLanguage currentLanguage;
  WebViewData webViewData = WebViewData();
  Color lightPrimaryColor = const Color(0xFF646496);
  Color darkPrimaryColor = Color.lerp(const Color(0xFF646496), Colors.white, 0.3)!;

  Future<void> init() async {
    final theme = await getTheme();
    final themeMod = theme == 'dark'
        ? ThemeMode.dark
        : theme == 'light'
        ? ThemeMode.light
        : ThemeMode.system;

    final lightColor = await getPrimaryColor(ThemeMode.light);
    final darkColor = await getPrimaryColor(ThemeMode.dark);
    lightPrimaryColor = lightColor;
    darkPrimaryColor = darkColor;

    final localeCode = await getLocale();
    locale = Locale(localeCode);

    themeMode = themeMod;
    lightData = AppTheme.getLightTheme(lightColor);
    darkData = AppTheme.getDarkTheme(darkColor);
    
    List<String> libraryLanguage = await getLibraryLanguage();
    currentLanguage = MepsLanguage(
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
      rsConf: libraryLanguage[12],
      lib: libraryLanguage[13],
    );
  }
}
