import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/webview/webview_javascript.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/document/local/dated_text_manager.dart';
import 'package:jwlife/features/document/local/documents_manager.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:jwlife/features/document/local/document_page.dart';
import 'package:jwlife/features/image/pages/full_screen_image_page.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';
import 'package:jwlife/features/video/video_player_page.dart';

import '../../app/services/global_key_service.dart';
import '../../data/models/publication.dart';
import '../../features/audio/audio_player_widget.dart';
import '../../features/personal/pages/playlist_player.dart';
import '../../i18n/i18n.dart';

Future<void> showPageDocument(Publication publication, int mepsDocumentId, {int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(documentPageKey);

  if(publication.documentsManager != null) {
      publication.documentsManager!.selectedDocumentId = publication.documentsManager!.documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }
  else {
    publication.documentsManager = DocumentsManager(publication: publication, initMepsDocumentId: mepsDocumentId);
    await publication.documentsManager!.initializeDatabaseAndData();

    publication.wordsSuggestionsModel = WordsSuggestionsModel(publication);
  }

  String htmlContent = createReaderHtmlShell(
    publication,
    publication.documentsManager!.selectedDocumentId,
    publication.documentsManager!.documents.length - 1,
    startParagraphId: startParagraphId,
    endParagraphId: endParagraphId,
    textTag: textTag,
    wordsSelected: wordsSelected ?? []
  );

  await showPage(DocumentPage(
      key: documentPageKey,
      publication: publication,
      mepsDocumentId: mepsDocumentId,
      startBlockIdentifierId: startParagraphId,
      endBlockIdentifierId: endParagraphId,
      textTag: textTag,
      wordsSelected: wordsSelected ?? [],
      htmlContent: htmlContent,
    )
  );
}

Future<void> showPageBibleChapter(Publication bible, int bookNumber, int chapterNumber, {int? lastBookNumber, int? lastChapterNumber, int? firstVerse, int? lastVerse, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(documentPageKey);

  if(bible.documentsManager != null) {
    bible.documentsManager!.initBookNumber = bookNumber;
    bible.documentsManager!.initChapterNumber = chapterNumber;
    bible.documentsManager!.selectedDocumentId = bible.documentsManager!.documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);
  }
  else {
    bible.documentsManager = DocumentsManager(publication: bible, initBookNumber: bookNumber, initChapterNumber: chapterNumber);
    await bible.documentsManager!.initializeDatabaseAndData();
    bible.documentsManager!.selectedDocumentId = bible.documentsManager!.documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);

    bible.wordsSuggestionsModel = WordsSuggestionsModel(bible);
  }

  String htmlContent = createReaderHtmlShell(
    bible,
    bible.documentsManager!.selectedDocumentId,
    bible.documentsManager!.documents.length - 1,
    bookNumber: bookNumber,
    chapterNumber: chapterNumber,
    lastBookNumber: lastBookNumber,
    lastChapterNumber: lastChapterNumber,
    startVerseId: firstVerse,
    endVerseId: lastVerse,
    wordsSelected: wordsSelected ?? []
  );

  await showPage(DocumentPage.bible(
      key: documentPageKey,
      bible: bible,
      bookNumber: bookNumber,
      chapterNumber: chapterNumber,
      lastBookNumber: lastBookNumber,
      lastChapterNumber: lastChapterNumber,
      firstVerseNumber: firstVerse,
      lastVerseNumber: lastVerse,
      wordsSelected: wordsSelected ?? [],
      htmlContent: htmlContent,
    )
  );
}

Future<void> showPageDailyText(Publication publication, {DateTime? date}) async {
  final GlobalKey<DailyTextPageState> dailyTextKey = GlobalKey<DailyTextPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(dailyTextKey);

  if(publication.datedTextManager != null) {
    int index = convertDateTimeToIntDate(date ?? DateTime.now());
    publication.datedTextManager!.selectedDatedTextId = publication.datedTextManager!.datedTexts.indexWhere((element) => element.firstDateOffset == index);
  }
  else {
    publication.datedTextManager = DatedTextManager(publication: publication, initDateTime: date ?? DateTime.now());
    await publication.datedTextManager!.initializeDatabaseAndData();
  }

  String htmlContent = createReaderHtmlShell(
      publication,
      publication.datedTextManager!.selectedDatedTextId,
      publication.datedTextManager!.datedTexts.length - 1
  );

  await showPage(DailyTextPage(key: dailyTextKey, publication: publication, date: date, htmlContent: htmlContent));
}

Future<void> showPage(Widget page) async {
  GlobalKeyService.jwLifePageKey.currentState!.addPageToTab(page);

  final isTransparentFullscreenPage = page is VideoPlayerPage || page is PlaylistPlayerPage || page is FullScreenImagePage || page is FullAudioView;

  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarTransparent(isTransparentFullscreenPage);

  final isControlsVisible = GlobalKeyService.jwLifePageKey.currentState!.controlsVisible.value;

  if(page is VideoPlayerPage || page is PlaylistPlayerPage) {
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
  }
  else if (page is NotePage) {
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false, hideSystemUi: false);
  }
  else {
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(true);
  }

  final isBottomTransition = page is FullAudioView || page is NotePage || JwLifeSettings.instance.pageTransition == 'bottom';
  final isRightTransition = JwLifeSettings.instance.pageTransition == 'right';

  await GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (!isBottomTransition && !isRightTransition) {
            return child; // Pas d'animation !
          }

          // Déterminer le point de départ de la transition
          final beginOffset = isBottomTransition ? const Offset(0.0, 1.0) : const Offset(1.0, 0.0); // Vient de la droite si false

          // La courbe de l'animation
          final curve = isBottomTransition ? Curves.easeOutCubic : Curves.easeOutQuart;

          // La transition de glissement
          return SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: beginOffset,  // Point de départ
                end: Offset.zero,    // Point d'arrivée (centre de l'écran)
              ).chain(CurveTween(curve: curve)),
            ),
            child: child
          );
        },
        opaque: false,
        transitionDuration: !isBottomTransition && !isRightTransition ? const Duration(milliseconds: 0) : const Duration(milliseconds: 350),
        reverseTransitionDuration: !isBottomTransition && !isRightTransition ? const Duration(milliseconds: 0) : const Duration(milliseconds: 350),
      )
  );

  GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(isControlsVisible);

  print('showPage: ${page.runtimeType}');

  GlobalKeyService.jwLifePageKey.currentState!.removePageFromTab();
}

void showBottomMessageWithAction(String message, SnackBarAction? action) {
  final pageState = GlobalKeyService.jwLifePageKey.currentState;
  final context = pageState!.getCurrentState().context;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isAudioPlayerVisible = pageState.audioWidgetVisible.value;
  final isNoteWidgetVisible = pageState.noteWidgetVisible.value;
  final dynamicPadding = (isAudioPlayerVisible ? kAudioWidgetHeight : 0) + (isNoteWidgetVisible ? kNoteHeight : 0);
  final finalBottomPadding = dynamicPadding + kBottomNavigationBarHeight;

  final messenger = ScaffoldMessenger.of(context);

  // 1) Nettoyer toute la file (actuel + en file d'attente)
  messenger.clearSnackBars();
  // (Alternative agressive si tu veux éviter l’animation : messenger.removeCurrentSnackBar();)

  messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(10, 0, 10, finalBottomPadding + 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? const Color(0xFFf1f1f1) : const Color(0xFF3c3c3c),
      content: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.black : Colors.white,
          fontSize: 15,
        ),
      ),
    ),
  );

  Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
    messenger.removeCurrentSnackBar();
  });
}

void showBottomMessage(String message) {
  showBottomMessageWithAction(message, null);
}

Future<void> showErrorDialog(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text(i18n().action_ok),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}