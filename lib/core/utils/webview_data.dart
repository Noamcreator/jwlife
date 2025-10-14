import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/publication.dart';
import '../../features/home/pages/daily_text_page.dart';
import '../../features/publication/pages/document/local/document_page.dart';
import '../shared_preferences/shared_preferences_utils.dart';
import 'directory_helper.dart';

class WebViewData {
  late String theme;
  late String backgroundColor;
  late String cssCode;
  late double fontSize;
  late int colorIndex;
  late int styleIndex;
  late bool isFullScreenMode;

  late String webappPath;

  late HeadlessInAppWebView headlessWebView;

  late List<String> biblesSet;

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
    fontSize = await getFontSize();
    styleIndex = await getStyleIndex();
    colorIndex = await getColorIndex();
    isFullScreenMode = await getFullscreen();

    Directory filesDirectory = await getAppFilesDirectory();
    webappPath = '${filesDirectory.path}/webapp_assets';

    biblesSet = await getBiblesSet();

    headlessWebView = HeadlessInAppWebView();
    headlessWebView.run();
  }

  void updateTheme(ThemeMode themeMode) {
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

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeTheme(themeMode);
        }
        else if (state is DailyTextPageState) {
          state.changeTheme(themeMode);
        }
      }
    }
  }

  void updateFontSize(double size) {
    fontSize = size;
  }

  void updateStyleAndColorIndex(int styleIndex, int colorIndex) {
    this.styleIndex = styleIndex;
    this.colorIndex = colorIndex;

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeStyleAndColorIndex(styleIndex, colorIndex);
        }
        else if (state is DailyTextPageState) {
          state.changeStyleAndColorIndex(styleIndex, colorIndex);
        }
      }
    }
  }

  void updateFullscreen(bool value) {
    isFullScreenMode = value;

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeFullScreenMode(value);
        }
        else if (state is DailyTextPageState) {
          state.changeFullScreenMode(value);
        }
      }
    }
  }

  void addBibleToBibleSet(Publication bible) {
    biblesSet.add(bible.getKey());
    addBibleSet(bible.getKey());
  }

  void removeBibleFromBibleSet(Publication bible) {
    biblesSet.remove(bible.getKey());
    removeBibleFromSet(bible.getKey());
  }

  void updateBiblesSet(List<Publication> newBiblesList) async {
    final newKeysList = newBiblesList.map((bible) => bible.getKey()).toList();
    biblesSet = newKeysList;
    await setBiblesSet(biblesSet);
  }
}