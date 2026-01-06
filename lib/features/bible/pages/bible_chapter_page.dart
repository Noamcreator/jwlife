import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/core/webview/webview_utils.dart';
import 'package:jwlife/data/models/bible_book.dart';
import 'package:jwlife/data/models/bible_chapter.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';
import 'package:jwlife/features/publication/pages/local/publication_search_view.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/dialog/qr_code_dialog.dart';
import '../models/bible_chapter_model.dart';
import 'bible_book_medias_page.dart';

const double _kMinTwoColumnWidth = 800;

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

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = BibleChapterController(bible: widget.bible, initialBookId: widget.book);

    _controller.onStateChanged = () {
      if (mounted) {
        setState(() {});
      }
    };

    _controller.initialize();
    _pageController = PageController(initialPage: 0);
  }

  void _updatePageController() {
    if (_controller.booksData.isNotEmpty && _pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage != _controller.currentIndex) {
        _pageController.jumpToPage(_controller.currentIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBook = _controller.currentBook;
    final textDirection = widget.bible.mepsLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePageController();
    });

    final bool hasCommentary = currentBook?.hasCommentary ?? false;
    final isLargeScreen = MediaQuery.of(context).size.width > _kMinTwoColumnWidth;

    Widget? bodyContent;
    if (currentBook != null) {
      if (isLargeScreen) {
        bodyContent = _buildTwoColumnLayout(currentBook);
      } else {
        bodyContent = _buildMobileLayout();
      }
    }

    return AppPage(
      extendBodyBehindAppBar: hasCommentary,
      appBar: _isSearching
          ? AppBar(
          backgroundColor: hasCommentary ? Colors.transparent : null,
          leading: IconButton(icon: Icon(JwIcons.chevron_left, color: hasCommentary ? Colors.white : null), onPressed: () { setState(() { _isSearching = false; }); }),

          // BARRE DE RECHERCHE CORRIGÉE
          title: SearchFieldWidget(
            query: '',

            // onSearchTextChanged: Appel du modèle pour lancer la recherche (void)
            onSearchTextChanged: (text) {
              // Vérifie que wordsSuggestionsModel est initialisé lors du clic sur Rechercher
              widget.bible.wordsSuggestionsModel?.fetchSuggestions(text);
            },

            // onSuggestionTap: Utilisation de item.item.caption pour le mot suggéré
            onSuggestionTap: (item) async {
              // item.item est de type SuggestionItem (avec .caption pour le texte du mot)
              final String query = item.item!.query;
              showPage(PublicationSearchView(query: query, publication: widget.bible));
              setState(() { _isSearching = false; });
            },

            onSubmit: (text) async {
              setState(() { _isSearching = false; });
              showPage(PublicationSearchView(query: text, publication: widget.bible));
            },

            onTapOutside: (event) {
              setState(() { _isSearching = false; });
            },

            // suggestionsNotifier: Utilisation du ValueNotifier du modèle
            suggestionsNotifier: widget.bible.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([]),
          )
      ) : JwLifeAppBar(
        backgroundColor: hasCommentary ? Colors.transparent : null,
        iconsColor: hasCommentary ? Colors.white : null,
        title: !hasCommentary ? (currentBook?.bookName ?? widget.bookName) : '',
        subTitle: !hasCommentary ? widget.bible.shortTitle : null,
        actions: [
          IconTextButton(
            text: i18n().action_search,
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: (anchorContext) {
              // Initialisation du modèle lors du clic sur rechercher
              widget.bible.wordsSuggestionsModel ??= WordsSuggestionsModel(widget.bible);
              setState(() { _isSearching = true; });
            },
          ),
          if (!isLargeScreen)
            IconTextButton(
              text: 'Aperçu',
              icon: Icon(currentBook?.isOverview ?? false ? JwIcons.grid_squares : JwIcons.outline),
              onPressed: (anchorContext) {
                _controller.toggleOverview();
              },
            ),
          IconTextButton(
            text: i18n().action_bookmarks,
            icon: const Icon(JwIcons.bookmark),
            onPressed: (anchorContext) async {
              Bookmark? bookmark = await showBookmarkDialog(context, widget.bible);
              if (bookmark != null) {
                if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                  showPageBibleChapter(widget.bible, bookmark.location.bookNumber!, bookmark.location.chapterNumber!,
                      firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier);
                } else if (bookmark.location.mepsDocumentId != null) {
                  showPageDocument(widget.bible, bookmark.location.mepsDocumentId!,
                      startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier);
                }
              }
            },
          ),
          IconTextButton(
            text: i18n().action_languages,
            icon: const Icon(JwIcons.language),
            onPressed: (anchorContext) {
              // On met null pour la bible car on veut toutes les bibles et pas uniquement la bible qu'on a sélectionnée
              showLanguagePubDialog(context, null, bookNumber: currentBook?.bookNumber ?? widget.book).then((bibleLanguagePub) async {
                if (bibleLanguagePub != null) {
                  Navigator.of(context).pop();  
                  showBibleBookView(context, bibleLanguagePub.keySymbol, bibleLanguagePub.mepsLanguage.id, currentBook?.bookNumber ?? widget.book);
                }
              });
            },
          ),
          IconTextButton(
            text: i18n().action_history,
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (anchorContext) {
              JwLifeApp.history.showHistoryDialog(context);
            },
          ),
          IconTextButton(
            text: i18n().action_share,
            icon: const Icon(JwIcons.share),
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
            icon: const Icon(JwIcons.qr_code),
            onPressed: (anchorContext) {
              Uri? uri = Uri.tryParse(_controller.getShareUri());
              showQrCodeDialog(context, widget.bookName, uri.toString());
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: textDirection, 
        child: bodyContent ?? getLoadingWidget(Theme.of(context).primaryColor)
      ),
    );
  }

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

  Widget _buildBookPageContent(BibleBook bookData, {bool isLargeScreen = false}) {
    if (bookData.isLoading) return getLoadingWidget(Theme.of(context).primaryColor);

    final double dynamicHeight = (MediaQuery.of(context).size.height * 0.20).clamp(120.0, 250.0);

    if (isLargeScreen) return _buildTwoColumnLayout(bookData);

    if (bookData.isOverview) {
      return Column(
        children: [
          if (bookData.hasCommentary) _buildBookHeader(bookData, withTextOverlay: true, height: dynamicHeight),
          Expanded(
            child: _buildHtmlView((bookData.overviewHtml?.isNotEmpty ?? false) ? bookData.overviewHtml! : bookData.profileHtml ?? '', bookData),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        if (bookData.hasCommentary)
          SliverToBoxAdapter(
            child: _buildBookHeader(bookData, withTextOverlay: true, height: dynamicHeight),
          ),
        SliverPadding(
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

  Widget _buildTwoColumnLayout(BibleBook bookData) {
    final double dynamicHeight = (MediaQuery.of(context).size.height * 0.20).clamp(120.0, 250.0);

    return Column(
      children: [
        if (bookData.hasCommentary) _buildBookHeader(bookData, withTextOverlay: true, height: dynamicHeight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  flex: 1,
                  child: _buildHtmlView((bookData.overviewHtml?.isNotEmpty ?? false) ? bookData.overviewHtml! : bookData.profileHtml ?? '', bookData),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookHeader(BibleBook bookData, {bool withTextOverlay = false, required double height}) {
    return Stack(
      children: [
        if (bookData.imagePath != null)
          Image.file(
            File('${widget.bible.path}/${bookData.imagePath}'),
            width: double.infinity,
            height: height,
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
                bookData.bookDisplayTitle ?? '',
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
            if (bookData.introTitle != null)
              _buildMepsButton(
                label: bookData.introTitle!,
                icon: JwIcons.information_circle,
                onPressed: () => showPageDocument(widget.bible, bookData.introDocumentId!),
              ),
            if (bookData.profileHtml != null && bookData.profileHtml!.isNotEmpty && (bookData.overviewHtml?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: _buildMepsButton(
                  label: 'Profile',
                  icon: JwIcons.information_circle,
                  onPressed: () => _showProfileDialog(context, bookData),
                ),
              ),
            if (bookData.hasCommentary)
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
    if (bookData.chapters.isEmpty) {
      return const Center(child: Text('Chapitres non disponibles.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 60).floor().clamp(1, 12);

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: kSpacing,
            mainAxisSpacing: kSpacing,
            childAspectRatio: 1.0,
          ),
          itemCount: bookData.chapters.length,
          itemBuilder: (context, index) {
            final chapter = bookData.chapters[index];
            return _buildChapterContainer(bookData, chapter);
          },
        );
      },
    );
  }

  Widget _buildChapterContainer(BibleBook bookData, BibleChapter chapter) {
   final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isChapterExist = chapter.isChapterExist;

    final Color colorBackgroundChapterNoExist = isDark ? Color(0xFF303030) : Colors.transparent;
    final Color colorTextChapterNoExist = isDark ? Color(0xFF626262) : Color(0xFFA7A7A7);

    return Material(
      color: isChapterExist ? const Color(0xFF757575) : colorBackgroundChapterNoExist,
      child: InkWell(
        onTap: isChapterExist ? () => _controller.onTapChapter(chapter) : null,
        child: Center(
          child: Text(
            formatNumber(chapter.number, localeCode: widget.bible.mepsLanguage.primaryIetfCode),
            style: TextStyle(
              fontSize: 20.0,
              color: isChapterExist ? Colors.white : colorTextChapterNoExist,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, BibleBook bookData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Expanded(child: _buildHtmlView(bookData.profileHtml ?? '', bookData)),
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

  Widget _buildHtmlView(String html, BibleBook bookData) {
    if (html.isEmpty) return Center(child: Text(i18n().message_no_content));

    return InAppWebView(
      initialSettings: getWebViewSettings(),
      gestureRecognizers: Set()
        ..add(
          Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer()..dragStartBehavior = DragStartBehavior.start,
          ),
        ),
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        baseUrl: WebUri('file://${JwLifeSettings.instance.webViewSettings.webappPath}/')
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        WebUri uri = navigationAction.request.url!;
        String url = uri.uriValue.toString();

        if (url.startsWith('jwpub://c')) {
          try {
            final mainPart = uri.toString().replaceAll('jwpub://c/', '');
            final mainSegments = mainPart.split('/');
            if (mainSegments.length < 2) return NavigationActionPolicy.CANCEL;

            final langAndBook = mainSegments[0].split(':');
            final rangeChapterAndVerse = mainSegments[1].split('-');

            //final int bookDocId = int.parse(langAndBook[1]);
            //int bookNumber = 0;
            final String firstVerseRange = rangeChapterAndVerse[0];
            final String lastVerseRange = rangeChapterAndVerse[1];

            final int firstChapter = int.parse(firstVerseRange.split(':')[0]);
            final int lastChapter = int.parse(lastVerseRange.split(':')[0]);

            final int firstVerse = int.parse(firstVerseRange.split(':')[1]);
            final int lastVerse = int.parse(lastVerseRange.split(':')[1]);

            showChapterView(context, widget.bible.keySymbol, widget.bible.mepsLanguage.id, bookData.bookNumber, firstChapter, lastChapterNumber: lastChapter, firstVerseNumber: firstVerse, lastVerseNumber: lastVerse);
          } 
          catch (e) {
            print('Error: $e');
            return NavigationActionPolicy.CANCEL;
          }
        }
        
      }
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }
}