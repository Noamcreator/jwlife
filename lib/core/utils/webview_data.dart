import 'package:flutter/material.dart';

class WebViewData {
  late String theme;
  late String backgroundColor;
  late String cssCode;

  // Méthode privée pour charger le CSS
  Future<void> init(ThemeMode themeMode) async {
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
  }
}