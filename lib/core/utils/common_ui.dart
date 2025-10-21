import 'package:flutter/material.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';

import '../../app/services/global_key_service.dart';
import '../../data/models/publication.dart';
import '../../features/audio/audio_player_widget.dart';
import '../../features/image/image_page.dart';

Future<void> showPageDocument(Publication publication, int mepsDocumentId, {int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  await showPage(DocumentPage(
      key: documentPageKey,
      publication: publication,
      mepsDocumentId: mepsDocumentId,
      startParagraphId: startParagraphId,
      endParagraphId: endParagraphId,
      textTag: textTag,
      wordsSelected: wordsSelected ?? []
    )
  );
}

Future<void> showPageBibleChapter(Publication bible, int book, int chapter, {int? firstVerse, int? lastVerse, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  await showPage(DocumentPage.bible(
      key: documentPageKey,
      bible: bible,
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
      wordsSelected: wordsSelected ?? []
    )
  );
}

Future<void> showPageDailyText(Publication publication, {DateTime? date}) async {
  final GlobalKey<DailyTextPageState> dailyTextKey = GlobalKey<DailyTextPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(dailyTextKey);

  await showPage(DailyTextPage(key: dailyTextKey, publication: publication, date: date));
}

Future<void> showPage(Widget page) async {
  GlobalKeyService.jwLifePageKey.currentState!.addPageToTab(page);

  final isWebViewFullscreenPage = page is DocumentPage || page is DailyTextPage;

  final isTransparentFullscreenPage = page is VideoPlayerPage ||
      page is FullScreenImagePage ||
      page is ImagePage ||
      page is FullAudioView;

  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarDisable(isWebViewFullscreenPage);
  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarTransparent(isTransparentFullscreenPage);

  final isResizeToAvoidBottomInset = page is NotePage;

  GlobalKeyService.jwLifePageKey.currentState!.toggleResizeToAvoidBottomInset(isResizeToAvoidBottomInset);

  final isControlsVisible = GlobalKeyService.jwLifePageKey.currentState!.controlsVisible.value;

  if(page is VideoPlayerPage) {
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
  }
  else {
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(true);
  }

  await GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // On wrap le WebView dans un RepaintBoundary pour isoler la redessination
          return SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOutCubic)),
            ),
            child: RepaintBoundary(
              child: child, // ici 'child' est ton WebView
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
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
  final isAudioPlayerVisible = pageState.audioWidgetVisible;
  final bottomPadding = isAudioPlayerVisible ? 130.0 : 55.0;

  final messenger = ScaffoldMessenger.of(context);

  // 1) Nettoyer toute la file (actuel + en file d'attente)
  messenger.clearSnackBars();
  // (Alternative agressive si tu veux éviter l’animation : messenger.removeCurrentSnackBar();)

  messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding + 10),
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

Future<void> showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}