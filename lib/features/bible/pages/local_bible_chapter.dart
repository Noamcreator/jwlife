import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/services/settings_service.dart';
import '../../../data/models/userdata/bookmark.dart';

class LocalChapterBiblePage extends StatefulWidget {
  final Publication bible;
  final int book;

  const LocalChapterBiblePage({super.key, required this.bible, required this.book});

  @override
  _LocalChapterBiblePageState createState() => _LocalChapterBiblePageState();
}

class BookData {
  final Map<String, dynamic> bookInfo;
  List<dynamic>? chapters;
  String? overviewHtml;
  String? profileHtml;
  bool isLoading;
  bool isOverview;

  BookData(this.bookInfo) : isLoading = true, isOverview = false;
}

class _LocalChapterBiblePageState extends State<LocalChapterBiblePage> {
  bool _isInitialLoading = true;
  late PageController _pageController;
  late List<BookData> _booksData;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    File mepsFile = await getMepsUnitDatabaseFile();
    try {
      Database database = widget.bible.documentsManager!.database;

      await database.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

      List<Map<String, dynamic>> results = await database.rawQuery('''
      SELECT 
        BibleBook.*,
        meps.BibleBookName.StandardBookName,
        d1.*,
        d2.Content AS OutlineContent,
        d3.Content AS OverviewContent,
        (SELECT Multimedia.FilePath 
         FROM DocumentMultimedia
         JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId 
         WHERE DocumentMultimedia.DocumentId = BibleBook.IntroDocumentId 
         AND Multimedia.CategoryType = 13
         LIMIT 1) AS FilePath
        FROM BibleBook
        INNER JOIN meps.BibleBookName ON BibleBook.BibleBookId = meps.BibleBookName.BookNumber
        INNER JOIN meps.BibleCluesInfo ON meps.BibleBookName.BibleCluesInfoId = meps.BibleCluesInfo.BibleCluesInfoId
        INNER JOIN Document d1 ON BibleBook.IntroDocumentId = d1.DocumentId
        LEFT JOIN Document d2 ON BibleBook.OutlineDocumentId = d2.DocumentId
        LEFT JOIN Document d3 ON BibleBook.OverviewDocumentId = d3.DocumentId
        WHERE meps.BibleCluesInfo.LanguageId = ?
      ''', [widget.bible.mepsLanguage.id]);

      await database.execute("DETACH DATABASE meps");

      // Créer les BookData pour chaque livre
      _booksData = results.map((book) => BookData(book)).toList();

      // Trouver l'index du livre actuel
      _currentIndex = _booksData.indexWhere((bookData) => bookData.bookInfo['BibleBookId'] == widget.book);
      if (_currentIndex == -1) _currentIndex = 0;

      _pageController = PageController(initialPage: _currentIndex);

      setState(() {
        _isInitialLoading = false;
      });

      // Charger les données du livre actuel
      await _loadBookData(_currentIndex);

    } catch (e) {
      throw Exception('Erreur lors de la récupération des livres: $e');
    }
  }

  Future<void> _loadBookData(int bookIndex) async {
    if (bookIndex < 0 || bookIndex >= _booksData.length) return;

    BookData bookData = _booksData[bookIndex];

    // Si les données sont déjà chargées, pas besoin de les recharger
    if (!bookData.isLoading) return;

    try {
      Database database = widget.bible.documentsManager!.database;

      // Charger les chapitres
      List<Map<String, dynamic>> chaptersResults = await database.rawQuery('''
        SELECT
          BibleChapter.ChapterNumber,
          Document.MepsDocumentId
        FROM BibleChapter
        INNER JOIN BibleBook ON BibleChapter.BookNumber = BibleBook.BibleBookId
        INNER JOIN Document ON BibleBook.BookDocumentId = Document.DocumentId
        WHERE BookNumber = ?
      ''', [bookData.bookInfo['BibleBookId']]);

      // Générer le HTML de l'aperçu
      String overviewHtml = '';
      dynamic contentBlob;
      if (bookData.bookInfo['OverviewContent'] != null) {
        contentBlob = bookData.bookInfo['OverviewContent'] as Uint8List;
      } else {
        contentBlob = bookData.bookInfo['OutlineContent'] as Uint8List;
      }

      if (contentBlob != null) {
        final decodedHtml = decodeBlobContent(
          contentBlob,
          widget.bible.hash!,
        );

        overviewHtml = createHtmlContent(
            decodedHtml,
            '''jwac docClass-115 ms-ROMAN ml-F dir-ltr pub-${widget.bible.keySymbol} layout-reading layout-sidebar''',
            ''
        );
      }

      String profileHtml = '';
      dynamic contentBlobProfile;
      if (bookData.bookInfo['Profile'] != null) {
        contentBlobProfile = bookData.bookInfo['Profile'] as Uint8List;
      } else {
        contentBlobProfile = bookData.bookInfo['Profile'] as Uint8List;
      }

      if (contentBlobProfile != null) {
        final decodedHtml = decodeBlobContent(
          contentBlobProfile,
          widget.bible.hash!,
        );

        profileHtml = createHtmlContent(
            decodedHtml,
            '''jwac docClass-115 ms-ROMAN ml-F dir-ltr pub-${widget.bible.keySymbol} layout-reading layout-sidebar''',
            ''
        );
      }

      // Mettre à jour les données du livre
      bookData.chapters = chaptersResults;
      bookData.overviewHtml = overviewHtml;
      bookData.profileHtml = profileHtml;
      bookData.isLoading = false;

      // Mettre à jour l'UI si c'est le livre actuellement affiché
      if (bookIndex == _currentIndex) {
        setState(() {});
      }

    } catch (e) {
      bookData.isLoading = false;
      throw Exception('Erreur lors du chargement des données du livre: $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Charger les données du nouveau livre si nécessaire
    _loadBookData(index);

    // Précharger les livres adjacents
    if (index > 0) _loadBookData(index - 1);
    if (index < _booksData.length - 1) _loadBookData(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isInitialLoading ? '' : _booksData[_currentIndex].bookInfo['StandardBookName'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              widget.bible.shortTitle,
              style: textStyleSubtitle,
            ),
          ],
        ),
        actions: [
          ResponsiveAppBarActions(
            allActions: [
              IconTextButton(
                text: "Rechercher",
                icon: Icon(JwIcons.magnifying_glass),
                onPressed: () {
                  // Action de recherche
                },
              ),
              IconTextButton(
                text: "Aperçu",
                icon: Icon(_isInitialLoading ? JwIcons.outline :
                (_booksData[_currentIndex].isOverview ? JwIcons.grid_squares : JwIcons.outline)),
                onPressed: _isInitialLoading ? null : () {
                  setState(() {
                    _booksData[_currentIndex].isOverview = !_booksData[_currentIndex].isOverview;
                  });
                },
              ),
              IconTextButton(
                text: "Marque-pages",
                icon: Icon(JwIcons.bookmark),
                onPressed: () async {
                  Bookmark? bookmark = await showBookmarkDialog(context, widget.bible);
                  if (bookmark != null) {
                    if(bookmark.location.bookNumber!= null && bookmark.location.chapterNumber != null) {
                      showPageBibleChapter(context, widget.bible, bookmark.location.bookNumber!, bookmark.location.chapterNumber!, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier);
                    }
                    else if(bookmark.location.mepsDocumentId != null) {
                      showPageDocument(context, widget.bible, bookmark.location.mepsDocumentId!, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier);
                    }
                  }
                },
              ),
              IconTextButton(
                text: "Langues",
                icon: Icon(JwIcons.language),
                onPressed: () async {
                  LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: widget.bible);
                  showDialog(
                    context: context,
                    builder: (context) => languageDialog,
                  ).then((value) {
                    if (value != null) {
                      //showPage(context, PublicationMenu(publication: widget.bible, publicationLanguage: value));
                    }
                  });
                },
              ),
              IconTextButton(
                text: "Historique",
                icon: const Icon(JwIcons.arrow_circular_left_clock),
                onPressed: () {
                  History.showHistoryDialog(context);
                },
              ),
              IconTextButton(
                text: "Envoyer le lien",
                icon: Icon(JwIcons.share),
                onPressed: () {
                  String uri = JwOrgUri.bibleBook(
                      wtlocale: widget.bible.mepsLanguage.symbol,
                      pub: widget.bible.symbol,
                      book: _booksData[_currentIndex].bookInfo['BibleBookId']
                  ).toString();

                  SharePlus.instance.share(
                    ShareParams(
                      title: _booksData[_currentIndex].bookInfo['StandardBookName'],
                      uri: Uri.tryParse(uri),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
        controller: _pageController,
        itemCount: _booksData.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return _buildBookPage(_booksData[index]);
        },
      ),
    );
  }

  Widget _buildBookPage(BookData bookData) {
    return Stack(
      children: [
        if (bookData.bookInfo['HasCommentary'] == 1)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.file(
              File('${widget.bible.path}/${bookData.bookInfo['FilePath']}'),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        if (bookData.bookInfo['HasCommentary'] == 1)
          Positioned(
            top: 150,
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
        Column(
          children: [
            if (bookData.bookInfo['HasCommentary'] == 1) const SizedBox(height: 200),
            Expanded(
              child: bookData.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : bookData.isOverview
                  ? _buildHtmlView(bookData.overviewHtml!)
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                scrollDirection: Axis.vertical,
                child: _buildChapterGrid(bookData),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHtmlView(String html) {
    if (html.isEmpty) {
      return const Center(child: Text('Aucun aperçu disponible'));
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
            baseUrl: WebUri('file://${JwLifeSettings().webViewData.webappPath}/')
        )
    );
  }

  Widget _buildChapterGrid(BookData bookData) {
    if (bookData.chapters == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1.0,
            ),
            itemCount: bookData.chapters!.length,
            itemBuilder: (context, index) {
              final chapter = bookData.chapters![index];
              return _buildChapterContainer(bookData, chapter);
            },
          ),
          if (bookData.bookInfo['Title'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF757575),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  onPressed: () {
                    showPageDocument(context, widget.bible, bookData.bookInfo['MepsDocumentId']);
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
          if (bookData.bookInfo['Title'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF757575),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
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
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Aperçu du livre',
                                ),
                              ),
                              Expanded(
                                child: _buildHtmlView(bookData.profileHtml!),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Fermer'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          const Icon(JwIcons.information_circle, color: Colors.white, size: 24.0),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: const TextStyle(fontSize: 20.0, color: Colors.white),
                          )
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  onPressed: () {
                    //showPage(context, PageLocalDocumentView(publication: widget.bible, mepsDocumentId: bookData.bookInfo['MepsDocumentId']));
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          const Icon(JwIcons.image_stack, color: Colors.white, size: 24.0),
                          const SizedBox(width: 8),
                          Text(
                            'Galerie multimédia',
                            style: const TextStyle(fontSize: 20.0, color: Colors.white),
                          )
                        ],
                      )
                  )
              ),
            ),
        ]
    );
  }

  Widget _buildChapterContainer(BookData bookData, dynamic chapter) {
    return InkWell(
      onTap: () {
        showPageBibleChapter(context, widget.bible, bookData.bookInfo['BibleBookId'], chapter['ChapterNumber']);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF757575),
        ),
        child: Center(
          child: Text(
            chapter['ChapterNumber'].toString(),
            style: const TextStyle(fontSize: 20.0, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}