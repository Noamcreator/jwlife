import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/qr_code_dialog.dart';
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
        title: !hasCommentary ? _controller.getBookTitle() ?? widget.bookName : "",
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
                  title: currentBook?.bookInfo['BookName'],
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
              String title = currentBook?.bookInfo['BookName'];
              showQrCodeDialog(context, title, uri.toString());
            },
          ),
        ],
      ),
      body: bodyContent ?? const Center(child: CircularProgressIndicator()),
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
    final double topCompensation = hasCommentary ? _kHeaderImageHeight : 0;

    if (bookData.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (hasCommentary) SizedBox(height: topCompensation),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChapterGridContent(bookData),
                      _buildBookLinks(bookData, context),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height - topCompensation - 40,
                        child: _buildHtmlView(bookData.overviewHtml ?? ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets partagés ---
  Widget _buildBookPageContent(BibleBook bookData, {bool isLargeScreen = false}) {
    final hasCommentary = bookData.bookInfo['HasCommentary'] == 1;
    final double topCompensation = hasCommentary ? _kHeaderImageHeight : 0;

    return Stack(
      children: [
        Column(
          children: [
            if (hasCommentary && !isLargeScreen) SizedBox(height: topCompensation),
            Expanded(
              child: bookData.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : bookData.isOverview
                  ? _buildHtmlView(bookData.overviewHtml ?? '')
                  : SingleChildScrollView(
                padding: hasCommentary ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: hasCommentary ? const EdgeInsets.symmetric(horizontal: 16.0) : EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChapterGridContent(bookData),
                      _buildBookLinks(bookData, context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasCommentary && !isLargeScreen)
          _buildBookHeader(bookData, withTextOverlay: true, isPositioned: true),
      ],
    );
  }

  Widget _buildBookHeader(BibleBook bookData, {bool withTextOverlay = false, bool isPositioned = false}) {
    final imageContent = Stack(
      children: [
        Image.file(
          File('${widget.bible.path}/${bookData.bookInfo['FilePath']}'),
          width: double.infinity,
          height: _kHeaderImageHeight,
          fit: BoxFit.cover,
        ),
        if (withTextOverlay)
          Positioned(
            top: _kHeaderImageHeight - 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
              ),
              child: Text(
                bookData.bookInfo['BookDisplayTitle'] ?? '',
                style: const TextStyle(fontSize: 25, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    if (isPositioned) {
      return Positioned(top: 0, left: 0, right: 0, child: imageContent);
    }
    return imageContent;
  }

  Widget _buildHtmlView(String html) {
    if (html.isEmpty) {
      return Center(child: Text(i18n().message_no_content));
    }

    return InAppWebView(
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
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
        )
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
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: kSpacing,
            mainAxisSpacing: kSpacing,
            childAspectRatio: 1.0,
          ),
          itemCount: bookData.chapters!.length,
          itemBuilder: (context, index) {
            final chapter = bookData.chapters![index];
            return _buildChapterContainer(bookData, chapter);
          },
        );
      },
    );
  }

  Widget _buildChapterContainer(BibleBook bookData, dynamic chapter) {
    return InkWell(
      onTap: () => _controller.onTapChapter(chapter['ChapterNumber']),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF757575)),
        child: Center(
          child: Text(
            chapter['ChapterNumber'].toString(),
            style: const TextStyle(fontSize: 20.0, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBookLinks(BibleBook bookData, BuildContext context) {
    return Column(
      children: [
        if (bookData.bookInfo['Title'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF757575),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                ),
                onPressed: () {
                  showPageDocument(widget.bible, bookData.bookInfo['MepsDocumentId']);
                },
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        const Icon(JwIcons.information_circle, color: Colors.white, size: 24.0),
                        const SizedBox(width: 8),
                        Text(
                          bookData.bookInfo['Title'],
                          style: const TextStyle(fontSize: 20.0, color: Colors.white),
                        )
                      ],
                    )
                )
            ),
          ),
        if (bookData.profileHtml != null && bookData.profileHtml!.isNotEmpty && bookData.bookInfo['Title'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF757575),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: SizedBox(
                        width: 300,
                        height: 400,
                        child: Column(
                          children: [
                            Expanded(child: _buildHtmlView(bookData.profileHtml!)),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(i18n().action_close_upper),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        Icon(JwIcons.information_circle, color: Colors.white, size: 24.0),
                        SizedBox(width: 8),
                        Text('Profile', style: TextStyle(fontSize: 20.0, color: Colors.white))
                      ],
                    )
                )
            ),
          ),
        if (bookData.bookInfo['HasCommentary'] == 1)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF757575),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                ),
                onPressed: () {
                  showPage(BibleBookMediasView(bible: widget.bible, bibleBook: bookData));
                },
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        const Icon(JwIcons.image_stack, color: Colors.white, size: 24.0),
                        const SizedBox(width: 8),
                        Text(i18n().label_media_gallery, style: const TextStyle(fontSize: 20.0, color: Colors.white))
                      ],
                    )
                )
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }
}