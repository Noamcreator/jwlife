import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';

import '../../app/services/global_key_service.dart';
import '../../data/models/audio.dart';
import '../../data/models/publication.dart';
import '../../features/image_page.dart';
import '../api.dart';

Future<void> showPageDocument(BuildContext context, Publication publication, int mepsDocumentId, {int? startParagraphId, int? endParagraphId, String? textTag, List<Audio>? audios, List<String>? wordsSelected}) async {
  List<Audio>? pubAudios = audios;
  if(audios == null) {
    pubAudios = await Api.getPubAudio(keySymbol: publication.keySymbol, issueTagNumber: publication.issueTagNumber, languageSymbol: publication.mepsLanguage.symbol);
  }

  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  return showPage(context, DocumentPage(
      key: documentPageKey,
      publication: publication,
      mepsDocumentId: mepsDocumentId,
      startParagraphId: startParagraphId,
      endParagraphId: endParagraphId,
      textTag: textTag,
      audios: pubAudios ?? [],
      wordsSelected: wordsSelected ?? []
    )
  );
}

Future<void> showPageBibleChapter(BuildContext context, Publication bible, int book, int chapter, {int? firstVerse, int? lastVerse, List<Audio>? audios, List<String>? wordsSelected}) async {
  List<Audio>? pubAudios = audios;
  if(audios == null) {
    pubAudios = await Api.getPubAudio(keySymbol: bible.keySymbol, issueTagNumber: bible.issueTagNumber, languageSymbol: bible.mepsLanguage.symbol);
  }

  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(documentPageKey);

  return showPage(context, DocumentPage.bible(
      key: documentPageKey,
      bible: bible,
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
      audios: pubAudios ?? [],
      wordsSelected: wordsSelected ?? []
  )
  );
}

Future<void> showPage(BuildContext context, Widget page) async {
  GlobalKeyService.jwLifePageKey.currentState!.addPageToTab(page);

  final isFullscreenPage = page is VideoPlayerPage ||
      page is FullScreenImagePage ||
      page is ImagePage ||
      page is DocumentPage ||
      page is DailyTextPage;

  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarDisable(isFullscreenPage);

  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      barrierColor: null,
      fullscreenDialog: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => page,
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
  final controller = messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 1),
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      margin: GlobalKeyService.jwLifePageKey.currentState!.navBarIsDisable[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex] ? const EdgeInsets.only(bottom: 60) : null,
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
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 1),
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      //margin: const EdgeInsets.only(bottom: 60),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );
}

/*
void showBottomMessage(BuildContext context, String message) {
  if(FirebaseAuth.instance.currentUser != null) { // si l'utilisateur n'est pas connecté, ne pas afficher le message
    showBottomMessageWithAction(context, message, null);
  }
}

 */

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