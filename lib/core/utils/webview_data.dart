import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';

class WebViewData {
  late String theme;
  late String backgroundColor;
  //late String dialogBackgroundColor;
  late String cssCode;
  late double fontSize;

  // Méthode privée pour charger le CSS
  Future<void> init() async {
    ThemeMode themeMode = JwLifeApp.settings.themeMode;
    bool isDark;
    if (themeMode == ThemeMode.dark) {
      isDark = true;
    } else if (themeMode == ThemeMode.light) {
      isDark = false;
    } else {
      // Mode system: Vérifiez le mode du système
      isDark = WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    }

    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
    //dialogBackgroundColor = isDark ? '#1d1d1d' : '#f7f7f5';
    fontSize = await getFontSize();
  }

  void update(ThemeMode themeMode) {
    bool isDark;
    if (themeMode == ThemeMode.dark) {
      isDark = true;
    } else if (themeMode == ThemeMode.light) {
      isDark = false;
    } else {
      // Mode system: Vérifiez le mode du système
      isDark = WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    }

    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
    //dialogBackgroundColor = isDark ? '#1d1d1d' : '#f7f7f5';
  }

  void updateFontSize(double size) {
    fontSize = size;
  }
}