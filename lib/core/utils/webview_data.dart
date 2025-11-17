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
  late bool isReadingMode;
  late bool isPreparingMode;

  late String webappPath;

  late List<String> biblesSet;

  // Méthode privée pour charger le CSS
  Future<void> init(bool isDark) async {
    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
    fontSize = await getFontSize();
    styleIndex = await getStyleIndex();
    colorIndex = await getColorIndex();
    isFullScreenMode = await getFullscreenMode();
    isReadingMode = await getReadingMode();
    isPreparingMode = await getPreparingMode();

    Directory filesDirectory = await getAppFilesDirectory();
    webappPath = '${filesDirectory.path}/webapp_assets';

    biblesSet = await getBiblesSet();
  }

  void updateTheme(bool isDark) {
    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeTheme(isDark);
        }
        else if (state is DailyTextPageState) {
          state.changeTheme(isDark);
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

  void updateReadingMode(bool value) {
    isReadingMode = value;

    if(value) {
      isPreparingMode = !value;
    }

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeReadingMode(value);

          if(value) {
            state.changePreparingMode(!value);
          }
        }
        else if (state is DailyTextPageState) {
          state.changeReadingMode(value);

          if(value) {
            state.changePreparingMode(!value);
          }
        }
      }
    }
  }

  void updatePreparingMode(bool value) {
    isPreparingMode = value;

    if(value) {
      isReadingMode = !value;
    }

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changePreparingMode(value);

          if(value) {
            state.changeReadingMode(!value);
          }
        }
        else if (state is DailyTextPageState) {
          state.changePreparingMode(value);

          if(value) {
            state.changeReadingMode(!value);
          }
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