import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';

import '../../app/services/global_key_service.dart';
import '../../data/models/publication.dart';
import '../../features/audio/audio_player_widget.dart';
import '../../features/personal/pages/playlist_player.dart';
import '../../i18n/i18n.dart';

Future<void> showPageDocument(Publication publication, int mepsDocumentId, {int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(documentPageKey);

  await showPage(DocumentPage(
      key: documentPageKey,
      publication: publication,
      mepsDocumentId: mepsDocumentId,
      startBlockIdentifierId: startParagraphId,
      endBlockIdentifierId: endParagraphId,
      textTag: textTag,
      wordsSelected: wordsSelected ?? []
    )
  );
}

Future<void> showPageBibleChapter(Publication bible, int book, int chapter, {int? lastBookNumber, int? lastChapterNumber, int? firstVerse, int? lastVerse, List<String>? wordsSelected}) async {
  final GlobalKey<DocumentPageState> documentPageKey = GlobalKey<DocumentPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(documentPageKey);

  await showPage(DocumentPage.bible(
      key: documentPageKey,
      bible: bible,
      bookNumber: book,
      chapterNumber: chapter,
      lastBookNumber: lastBookNumber,
      lastChapterNumber: lastChapterNumber,
      firstVerseNumber: firstVerse,
      lastVerseNumber: lastVerse,
      wordsSelected: wordsSelected ?? []
    )
  );
}

Future<void> showPageDailyText(Publication publication, {DateTime? date}) async {
  final GlobalKey<DailyTextPageState> dailyTextKey = GlobalKey<DailyTextPageState>();
  GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value].add(dailyTextKey);

  await showPage(DailyTextPage(key: dailyTextKey, publication: publication, date: date));
}

Future<void> showPage(Widget page) async {
  GlobalKeyService.jwLifePageKey.currentState!.addPageToTab(page);

  final isTransparentFullscreenPage = page is VideoPlayerPage || page is PlaylistPlayerPage || page is FullScreenImagePage || page is FullAudioView;

  GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarTransparent(isTransparentFullscreenPage);

  final isResizeToAvoidBottomInset = page is NotePage;

  final isControlsVisible = GlobalKeyService.jwLifePageKey.currentState!.controlsVisible.value;

  if(page is VideoPlayerPage || page is PlaylistPlayerPage) {
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
  }
  else {
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(isResizeToAvoidBottomInset ? false : true);
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