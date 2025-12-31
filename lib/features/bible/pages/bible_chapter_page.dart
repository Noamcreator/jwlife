import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/dialog/qr_code_dialog.dart';
import '../models/bible_chapter_model.dart';
import 'bible_book_medias_page.dart';

const double _kMinTwoColumnWidth = 800;
const double _kHeaderImageHeight = 210.0;

class BibleChapterPage extends StatefulWidget {
  final Publication bible;
  final int book;
  final String bookName;

  const BibleChapterPage({super.key, required this.bible, required this.book, this.bookName = ''});

  @override
  _BibleChapterPageState createState() => _BibleChapterPageState();
}

class _BibleChapterPageState extends State<BibleChapterPage> {
  late final BibleChapterController _controller;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _controller = BibleChapterController(bible: widget.bible, initialBookId: widget.book);

    // Configuration du callback AVANT l'initialisation
    _controller.onStateChanged = () {
      if (mounted) {
        setState(() {});
      }
    };

    // Lancer l'initialisation après que le callback soit configuré
    _controller.initialize();
    _pageController = PageController(initialPage: 0);
  }

  void _updatePageController() {
    if (_controller.booksData.isNotEmpty && _pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage != _controller.currentIndex) {
        // Utiliser jumpToPage pour éviter les animations
        _pageController.jumpToPage(_controller.currentIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBook = _controller.currentBook;
    final textDirection = widget.bible.mepsLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr;

    // Synchroniser le PageController après que l'état soit disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePageController();
    });

    final hasCommentary = currentBook?.bookInfo['HasCommentary'] == 1;
    final isLargeScreen = MediaQuery.of(context).size.width > _kMinTwoColumnWidth;

    Widget? bodyContent;
    if(currentBook != null) {
      // --- Logique pour le body ---
      if (isLargeScreen) {
        bodyContent = Stack(
          children: [
            if (hasCommentary) _buildBookHeader(currentBook),
            _buildTwoColumnLayout(currentBook),
          ],
        );
      }
      else {
        bodyContent = _buildMobileLayout();
      }
    }

    return AppPage(
      extendBodyBehindAppBar: hasCommentary,
      appBar: JwLifeAppBar(
        backgroundColor: hasCommentary ? Colors.transparent : null,
        iconsColor: hasCommentary ? Colors.white : null,
        title: !hasCommentary ? widget.bookName : "",
        subTitle: !hasCommentary ? widget.bible.shortTitle : null,
        actions: [
          IconTextButton(
            text: "Rechercher",
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: (anchorContext) {},
          ),
          if (!isLargeScreen)
            IconTextButton(
              text: "Aperçu",
              icon: Icon(currentBook?.isOverview ?? false ? JwIcons.grid_squares : JwIcons.outline),
              onPressed: (anchorContext) {_controller.toggleOverview(); },
            ),
          IconTextButton(
            text: i18n().action_bookmarks,
            icon: Icon(JwIcons.bookmark),
            onPressed: (anchorContext) async {
              Bookmark? bookmark = await showBookmarkDialog(context, widget.bible);
              if (bookmark != null) {
                if(bookmark.location.bookNumber!= null && bookmark.location.chapterNumber != null) {
                  showPageBibleChapter(widget.bible, bookmark.location.bookNumber!, bookmark.location.chapterNumber!, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier);
                }
                else if(bookmark.location.mepsDocumentId != null) {
                  showPageDocument(widget.bible, bookmark.location.mepsDocumentId!, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier);
                }
              }
            },
          ),
          IconTextButton(
            text: i18n().action_languages,
            icon: Icon(JwIcons.language),
            onPressed: (anchorContext) {
              showLanguagePubDialog(context, null).then((bible) async {
                if (bible != null) {
                  String bibleKey = bible.getKey();
                  JwLifeSettings.instance.lookupBible.value = bibleKey;
                }
              });
            },
          ),
          IconTextButton(
            text: i18n().action_history,
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (anchorContext) {
              History.showHistoryDialog(context);
            },
          ),
          IconTextButton(
            text: i18n().action_open_in_share,
            icon: Icon(JwIcons.share),
            onPressed: (anchorContext) {
              SharePlus.instance.share(
                ShareParams(
                  title: widget.bookName,
                  uri: Uri.tryParse(_controller.getShareUri()),
                ),
              );
            },
          ),
          IconTextButton(
            text: i18n().action_qr_code,
            icon: Icon(JwIcons.qr_code),
            onPressed: (anchorContext) {
              Uri? uri = Uri.tryParse(_controller.getShareUri());
              showQrCodeDialog(context, widget.bookName, uri.toString());
            },
          ),
        ],
      ),
      body: Directionality(textDirection: textDirection, child: bodyContent ?? getLoadingWidget(Theme.of(context).primaryColor)),
    );
  }

  // --- Layout Mobile ---
  Widget _buildMobileLayout() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _controller.booksData.length,
      onPageChanged: _controller.onPageChanged,
      itemBuilder: (context, index) {
        return _buildBookPageContent(_controller.booksData[index], isLargeScreen: false);
      },
    );
  }

  // --- Layout Grand Écran ---
  Widget _buildTwoColumnLayout(BibleBook bookData) {
    final hasCommentary = bookData.bookInfo['HasCommentary'] == 1;

    if (bookData.isLoading) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }

    return Column(
      children: [
        // Header fixe en haut si commentaire
        if (hasCommentary) _buildBookHeader(bookData, withTextOverlay: true),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne GAUCHE : Grille et Liens
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChapterGridContent(bookData),
                        const SizedBox(height: 24),
                        _buildBookLinks(bookData, context),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Colonne DROITE : Vue HTML
                Expanded(
                  flex: 1,
                  child: _buildHtmlView(bookData.overviewHtml!.isNotEmpty ? bookData.overviewHtml! : bookData.profileHtml ?? ''),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Widgets partagés ---
  Widget _buildBookPageContent(BibleBook bookData, {bool isLargeScreen = false}) {
    if (bookData.isLoading) return getLoadingWidget(Theme.of(context).primaryColor);

    // Cas 1 : Grand Écran (Layout deux colonnes)
    if (isLargeScreen) return _buildTwoColumnLayout(bookData);

    // Cas 2 : Mobile - Affichage de l'Overview (HTML)
    if (bookData.isOverview) {
      return Column(
        children: [
          // On garde le header même en mode overview si disponible
          if (bookData.bookInfo['HasCommentary'] == 1)
            _buildBookHeader(bookData, withTextOverlay: true),
          Expanded(
            child: _buildHtmlView(bookData.overviewHtml!.isNotEmpty ? bookData.overviewHtml! : bookData.profileHtml ?? ''),
          ),
        ],
      );
    }

    // Cas 3 : Mobile - Affichage Normal (Grille + Liens)
    return CustomScrollView(
      slivers: [
        if (bookData.bookInfo['HasCommentary'] == 1)
          SliverToBoxAdapter(
            child: _buildBookHeader(bookData, withTextOverlay: true),
          ),

        SliverPadding(
          // On met le top à 0.0 pour supprimer l'espace sous le header
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _buildChapterGridContent(bookData),
                const SizedBox(height: 24),
                _buildBookLinks(bookData, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookHeader(BibleBook bookData, {bool withTextOverlay = false}) {
    return Stack(
      children: [
        Image.file(
          File('${widget.bible.path}/${bookData.bookInfo['FilePath']}'),
          width: double.infinity,
          height: _kHeaderImageHeight,
          fit: BoxFit.cover,
          cacheWidth: 1220,
        ),
        if (withTextOverlay)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              color: Colors.black.withOpacity(0.55),
              child: Text(
                bookData.bookInfo['BookDisplayTitle'] ?? '',
                style: const TextStyle(fontSize: 21, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBookLinks(BibleBook bookData, BuildContext context) {
    return FutureBuilder<String>(
      future: i18nLocale(widget.bible.mepsLanguage.getSafeLocale()).then((l) => l.label_media_gallery),
      builder: (context, snapshot) {
        final mediaLabel = snapshot.data ?? "...";

        return Column(
          children: [
            // 1. Bouton Information Livre
            if (bookData.bookInfo['Title'] != null)
              _buildMepsButton(
                label: bookData.bookInfo['Title'],
                icon: JwIcons.information_circle,
                onPressed: () => showPageDocument(widget.bible, bookData.bookInfo['MepsDocumentId']),
              ),

            // 2. Bouton Profile
            if (bookData.profileHtml != null && bookData.profileHtml!.isNotEmpty && bookData.overviewHtml!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: _buildMepsButton(
                  label: 'Profile',
                  icon: JwIcons.information_circle,
                  onPressed: () => _showProfileDialog(context, bookData.profileHtml!),
                ),
              ),

            // 3. Bouton Galerie Média
            if (bookData.bookInfo['HasCommentary'] == 1)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: _buildMepsButton(
                  label: mediaLabel,
                  icon: JwIcons.image_stack,
                  onPressed: () => showPage(BibleBookMediasView(bible: widget.bible, bibleBook: bookData)),
                ),
              ),
          ],
        );
      },
    );
  }

// Helper pour les boutons uniformes
  Widget _buildMepsButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF757575),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24.0),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChapterGridContent(BibleBook bookData) {
    if (bookData.chapters == null || bookData.chapters!.isEmpty) {
      return const Center(child: Text('Chapitres non disponibles.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 60).floor().clamp(1, 12);

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(), // Important pour laisser le parent scroller
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: kSpacing,
            mainAxisSpacing: kSpacing,
            childAspectRatio: 1.0,
          ),
          itemCount: bookData.chapters!.length,
          itemBuilder: (context, index) => _buildChapterContainer(bookData, bookData.chapters![index]),
        );
      },
    );
  }

  Widget _buildChapterContainer(BibleBook bookData, dynamic chapter) {
    return Material(
      color: const Color(0xFF757575),
      child: InkWell(
        onTap: () => _controller.onTapChapter(chapter['ChapterNumber']),
        child: Center(
          child: Text(
            formatNumber(chapter['ChapterNumber'], localeCode: widget.bible.mepsLanguage.primaryIetfCode),
            style: const TextStyle(fontSize: 20.0, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, String htmlContent) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Expanded(child: _buildHtmlView(htmlContent)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(i18n().action_close_upper),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlView(String html) {
    if (html.isEmpty) return Center(child: Text(i18n().message_no_content));

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: true,
      ),
      gestureRecognizers: Set()

        ..add(

          Factory<VerticalDragGestureRecognizer>(

                () => VerticalDragGestureRecognizer()..dragStartBehavior = DragStartBehavior.start,

          ),

        ),
      initialData: InAppWebViewInitialData(
          data: html,
          mimeType: 'text/html',
          baseUrl: WebUri('file://${JwLifeSettings.instance.webViewData.webappPath}/')
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }
}