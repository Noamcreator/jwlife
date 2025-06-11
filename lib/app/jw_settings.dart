import 'package:flutter/material.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/webview_data.dart';

import '../data/meps/language.dart';

class JwSettings {
  ThemeMode themeMode = ThemeMode.system;
  ThemeData lightData = AppTheme.getLightTheme(Color(0xFF295568));
  ThemeData darkData = AppTheme.getDarkTheme(Color.lerp(Color(0xFF295568), Colors.white, 0.3)!);
  Locale locale = Locale('en');
  MepsLanguage currentLanguage = MepsLanguage(id: 3, symbol: 'F', vernacular: 'Français', primaryIetfCode: 'fr', rsConf: 'r30', lib: 'lp-f');
  WebViewData webViewData = WebViewData();

  JwSettings() {
    loadFromSharedPreferences();
  }

  Future<void> loadFromSharedPreferences() async {
    // Récupère les préférences utilisateur (thème, couleur principale et langue)
    final theme = await getTheme();
    final themeMod = theme == 'dark'
        ? ThemeMode.dark
        : theme == 'light'
        ? ThemeMode.light
        : ThemeMode.system;
    final lightColor = await getPrimaryColor(ThemeMode.light);
    final darkColor = await getPrimaryColor(ThemeMode.dark);
    final localeCode = await getLocale();

    themeMode = themeMod;
    locale = Locale(localeCode);
    lightData = AppTheme.getLightTheme(lightColor);
    darkData = AppTheme.getDarkTheme(darkColor);
  }
}
