import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../app/services/settings_service.dart';
import 'html_template_service.dart';

String createReaderHtmlShell(
    Publication publication,
    int firstIndex,
    int maxIndex,
    {int? bookNumber,
      int? chapterNumber,
      int? lastBookNumber,
      int? lastChapterNumber,
      int? startParagraphId,
      int? endParagraphId,
      int? startVerseId,
      int? endVerseId,
      String? textTag,
      List<String> wordsSelected = const []
    }) {

  final webViewData = JwLifeSettings.instance.webViewData;
  final fontSize = webViewData.fontSize;
  bool isDarkMode = webViewData.theme == 'cc-theme--dark';
  String direction = publication.mepsLanguage.isRtl ? 'rtl' : 'ltr';
  bool isFullscreenMode = webViewData.isFullScreenMode;
  bool isReadingMode = webViewData.isReadingMode;
  bool isBlockingHorizontallyMode = webViewData.isBlockingHorizontallyMode;
  bool audioPlayerVisible = GlobalKeyService.jwLifePageKey.currentState?.audioWidgetVisible.value ?? false;

  final lightPrimaryColor = toHex(JwLifeSettings.instance.lightPrimaryColor);
  final darkPrimaryColor = toHex(JwLifeSettings.instance.darkPrimaryColor);

  // Récupérez le template (déjà en mémoire)
  String html = HtmlTemplateService().getReaderTemplate();

  // Remplacez les placeholders
  final replacements = {
    '{{PUBLICATION_SHORT_TITLE}}': publication.getShortTitle(),
    '{{PUBLICATION_PATH}}': publication.path ?? '',
    '{{FONT_SIZE}}': fontSize.toString(),
    '{{BOTTOM_NAVBAR_HEIGHT}}': (kBottomNavigationBarHeight-1).toString(),
    '{{THEME}}': webViewData.theme,
    '{{DIRECTION}}': direction,
    '{{CURRENT_INDEX}}': firstIndex.toString(),
    '{{MAX_INDEX}}': maxIndex.toString(),
    '{{IS_DARK}}': isDarkMode.toString(),
    '{{LIGHT_PRIMARY_COLOR}}': lightPrimaryColor,
    '{{DARK_PRIMARY_COLOR}}': darkPrimaryColor,
    '{{IS_FULLSCREEN}}': isFullscreenMode.toString(),
    '{{IS_READING_MODE}}': isReadingMode.toString(),
    '{{IS_BLOCKING}}': isBlockingHorizontallyMode.toString(),
    '{{AUDIO_VISIBLE}}': audioPlayerVisible.toString(),
    '{{START_PARAGRAPH_ID}}': startParagraphId?.toString() ?? 'null',
    '{{END_PARAGRAPH_ID}}': endParagraphId?.toString() ?? 'null',
    '{{START_VERSE_ID}}': startVerseId?.toString() ?? 'null',
    '{{END_VERSE_ID}}': endVerseId?.toString() ?? 'null',
    '{{BOOK_NUMBER}}': bookNumber?.toString() ?? 'null',
    '{{CHAPTER_NUMBER}}': chapterNumber?.toString() ?? 'null',
    '{{LAST_BOOK_NUMBER}}': lastBookNumber?.toString() ?? 'null',
    '{{LAST_CHAPTER_NUMBER}}': lastChapterNumber?.toString() ?? 'null',
    '{{TEXT_TAG}}': textTag ?? '',
    '{{WORDS_SELECTED}}': jsonEncode(wordsSelected),
    '{{COLOR_INDEX}}': webViewData.colorIndex.toString(),
    '{{STYLE_INDEX}}': webViewData.styleIndex.toString(),
    '{{IS_RTL}}': publication.mepsLanguage.isRtl.toString(),
    '{{IS_DEBUG_MODE}}': kDebugMode.toString(),
  };

  replacements.forEach((key, value) {
    html = html.replaceAll(key, value);
  });

  return html;
}