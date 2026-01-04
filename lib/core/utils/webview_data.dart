import 'dart:io';

import '../../app/services/global_key_service.dart';
import '../../data/models/publication.dart';
import '../../features/document/local/document_page.dart';
import '../../features/home/pages/daily_text_page.dart';
import '../shared_preferences/shared_preferences_utils.dart';
import 'directory_helper.dart';

class WebViewSettings {
  late String theme;
  late String backgroundColor;
  late String cssCode;
  late double fontSize;
  late int colorIndex;
  late int styleIndex;
  late bool isFullScreenMode;
  late bool isReadingMode;
  late bool isBlockingHorizontallyMode;
  late bool versesInParallel;

  late bool isFuriganaActive;
  late bool isPinyinActive;
  late bool isYaleActive;

  late String webappPath;

  late List<String> biblesSet;

  // Méthode privée pour charger le CSS
  Future<void> init(bool isDark) async {
    final sharedPreferences = AppSharedPreferences.instance;
    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
    fontSize = sharedPreferences.getFontSize();
    styleIndex = sharedPreferences.getStyleIndex();
    colorIndex = sharedPreferences.getColorIndex();
    isFullScreenMode = sharedPreferences.getFullscreenMode();
    isReadingMode = sharedPreferences.getReadingMode();
    isBlockingHorizontallyMode = sharedPreferences.getBlockingHorizontallyMode();
    versesInParallel = sharedPreferences.getVersesInParallel();

    isFuriganaActive = sharedPreferences.getFuriganaActive();
    isPinyinActive = sharedPreferences.getPinyinActive();
    isYaleActive = sharedPreferences.getYaleActive();

    Directory filesDirectory = await getAppFilesDirectory();
    webappPath = '${filesDirectory.path}/webapp_assets';

    biblesSet = sharedPreferences.getBiblesSet();
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

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeReadingMode(value);
        }
        else if (state is DailyTextPageState) {
          state.changeReadingMode(value);
        }
      }
    }
  }

  void updatePreparingMode(bool value) {
    isBlockingHorizontallyMode = value;

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changePreparingMode(value);
        }
        else if (state is DailyTextPageState) {
          state.changePreparingMode(value);
        }
      }
    }
  }

  void updatePronunciationGuide(bool value, String type) {
    if(type == 'furigana') {
      isFuriganaActive = value;
    }
    else if(type == 'pinyin') {
      isPinyinActive = value;
    }
    else {
      isYaleActive = value;
    }

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changePronunciationGuideMode(value);
        }
        else if (state is DailyTextPageState) {
          state.changePronunciationGuideMode(value);
        }
      }
    }
  }

  void addBibleToBibleSet(Publication bible) {
    biblesSet.add(bible.getKey());
    AppSharedPreferences.instance.addBibleSet(bible.getKey());
  }

  void removeBibleFromBibleSet(Publication bible) {
    biblesSet.remove(bible.getKey());
    AppSharedPreferences.instance.removeBibleFromSet(bible.getKey());
  }

  void updateBiblesSet(List<Publication> newBiblesList) async {
    final newKeysList = newBiblesList.map((bible) => bible.getKey()).toList();
    biblesSet = newKeysList;
    await AppSharedPreferences.instance.setBiblesSet(biblesSet);
  }

  Future<void> updateVersesInParallel(bool finalVersesInParallel) async {
    versesInParallel = finalVersesInParallel;
    await AppSharedPreferences.instance.setVersesInParallel(finalVersesInParallel);
  }
}