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

Future<void> showPageDocument(BuildContext context, Publication publication, int mepsDocumentId, {int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  return showPage(context, DocumentPage(
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

Future<void> showPageBibleChapter(BuildContext context, Publication bible, int book, int chapter, {int? firstVerse, int? lastVerse, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  return showPage(context, DocumentPage.bible(
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


Future<void> showPageDailyText(BuildContext context, Publication publication, {DateTime? date}) async {
  final GlobalKey<DailyTextPageState> dailyTextKey = GlobalKey<DailyTextPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(dailyTextKey);

  return showPage(context, DailyTextPage(key: dailyTextKey, publication: publication, date: date));
}

Future<void> showPage(BuildContext context, Widget page) async {
  GlobalKeyService.jwLifePageKey.currentState!.addPageToTab(page);

  final isFullscreenPage = page is VideoPlayerPage ||
      page is FullScreenImagePage ||
      page is ImagePage ||
      page is DocumentPage ||
      page is DailyTextPage ||
      page is FullAudioView;

  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarDisable(isFullscreenPage);

  final isResizeToAvoidBottomInset = page is NotePage;

  GlobalKeyService.jwLifePageKey.currentState!.toggleResizeToAvoidBottomInset(isResizeToAvoidBottomInset);

  await Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      transitionDuration: const Duration(milliseconds: 0),
      reverseTransitionDuration: const Duration(milliseconds: 0),
    ),
  );

  print('showPage: ${page.runtimeType}');

  GlobalKeyService.jwLifePageKey.currentState!.removePageFromTab();
}

/*
Future<void> showPage(BuildContext context, Widget page) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animation d'entrée : fade + slide up
        final enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        );
        final enterOffset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return FadeTransition(
              opacity: enterOpacity,
              child: SlideTransition(
                position: enterOffset,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

 */

void showBottomMessageWithActionState(ScaffoldMessengerState messenger, bool isDark, String message, SnackBarAction? action) {
  messenger.clearSnackBars();
  final isAudioPlayerWidget = GlobalKeyService.jwLifePageKey.currentState!.audioWidgetVisible;
  final bottomPadding = GlobalKeyService.jwLifePageKey.currentState!.navBarIsDisable[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex] ? (isAudioPlayerWidget ? 140.0 : 70.0) : 0.0;

  final controller = messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 1),
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );

  Future.delayed(Duration(seconds: 2), () {
    controller.close(); // force la fermeture
  });
}

void showBottomMessageWithAction(BuildContext context, String message, SnackBarAction? action) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  final isAudioPlayerWidget = GlobalKeyService.jwLifePageKey.currentState!.audioWidgetVisible;
  final bottomPadding = GlobalKeyService.jwLifePageKey.currentState!.navBarIsDisable[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex] ? (isAudioPlayerWidget ? 140.0 : 80.0) : 0.0;
  final horizontalMargin = 10.0; // marge à gauche/droite
  final bottomMargin = bottomPadding + 10.0; // décalage du bas

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldFeatureController controller = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 1),
      content: Text(
        message,
        style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // coins arrondis pour flotter
      ),
      margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, bottomMargin),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );

  Future.delayed(Duration(seconds: 2), () {
    controller.close(); // force la fermeture
  });
}

void showBottomMessage(BuildContext context, String message) {
  showBottomMessageWithAction(context, message, null);
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