import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../app/services/settings_service.dart';
import '../shared_preferences/shared_preferences_utils.dart';
import 'directory_helper.dart';

class WebViewData {
  late String theme;
  late String backgroundColor;
  //late String dialogBackgroundColor;
  late String cssCode;
  late double fontSize;
  late int colorIndex;
  late bool isFullScreen;

  late String webappPath;

  late HeadlessInAppWebView headlessWebView;

  // Méthode privée pour charger le CSS
  Future<void> init() async {
    ThemeMode themeMode = JwLifeSettings().themeMode;
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
    colorIndex = await getLastHighlightColorIndex();
    isFullScreen = await getFullscreen();

    Directory webappViewDirectory = await getAppWebViewDirectory();
    webappPath = '${webappViewDirectory.path}/webapp';

    headlessWebView = HeadlessInAppWebView();
    headlessWebView.run();
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

  void updateColorIndex(int index) {
    colorIndex = index;
  }

  void updateFullscreen(bool value) {
    isFullScreen = value;
  }
}