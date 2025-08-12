import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
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
import 'package:sqflite/sqflite.dart';

import '../../../data/models/userdata/bookmark.dart';

class LocalChapterBiblePage extends StatefulWidget {
  final Publication bible;
  final int book;
  final List<Audio> audios;

  const LocalChapterBiblePage({super.key, required this.bible, required this.book, required this.audios});

  @override
  _LocalChapterBiblePageState createState() => _LocalChapterBiblePageState();
}

class _LocalChapterBiblePageState extends State<LocalChapterBiblePage> {
  bool _isLoading = true;
  bool _isOverview = false;
  bool _isLoadingOverview = false;
  String _overviewHtml = '';

  late PageController _pageController;
  late List<Map<String, dynamic>> _books; // Liste de tous les livres
  int _currentIndex = 1;
  late List<dynamic> _chapters;

  @override
  void initState() {
    super.initState();
    _fetchBooks(); // Nouvelle méthode pour récupérer tous les livres
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

      setState(() {
        _books = results;
        _currentIndex = results.indexWhere((book) => book['BibleBookId'] == widget.book);
      });

      _pageController = PageController(initialPage: _currentIndex);

      _fetchBookPage(); // Charge les chapitres du livre actuel
    }
    catch (e) {
      throw Exception('Erreur lors de la récupération des livres: $e');
    }
  }

  Future<void> _fetchBookPage() async {
    setState(() {
      _isLoadingOverview = true;
    });

    try {
      Database database = widget.bible.documentsManager!.database;

      List<Map<String, dynamic>> results2 = await database.rawQuery('''
        SELECT
          BibleChapter.ChapterNumber,
          Document.MepsDocumentId
        FROM BibleChapter
        INNER JOIN BibleBook ON BibleChapter.BookNumber = BibleBook.BibleBookId
        INNER JOIN Document ON BibleBook.BookDocumentId = Document.DocumentId
        WHERE BookNumber = ?
      ''', [_currentIndex+1]);

      Map<String, dynamic> book = _books[_currentIndex];

      dynamic contentBlob;
      if (book['OverviewContent'] != null) {
        contentBlob = book['OverviewContent'] as Uint8List;

      }
      else {
        contentBlob = book['OutlineContent'] as Uint8List;
      }

      final decodedHtml = decodeBlobContent(
        contentBlob,
        widget.bible.hash!,
      );

      String htmlContent = createHtmlContent(
        decodedHtml,
        '''jwac docClass-115 ms-ROMAN ml-F dir-ltr pub-${widget.bible.keySymbol} layout-reading layout-sidebar''',
        widget.bible,
        false
      );

      setState(() {
        _overviewHtml = htmlContent;
        _chapters = results2;
        _isLoadingOverview = false;
        _isLoading = false;
      });
    }
    catch (e) {
      throw Exception(
          'Erreur lors de l\'initialisation de la base de données: $e');
    }
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
              _isLoading ? '' : _books[_currentIndex]['StandardBookName'] ?? '',
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
                icon: Icon(_isOverview ? JwIcons.grid_squares : JwIcons.outline),
                onPressed: () {
                  setState(() {
                    _isOverview = !_isOverview;
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
                      showPageBibleChapter(context, widget.bible, bookmark.location.bookNumber!, bookmark.location.chapterNumber!, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier, audios: widget.audios);
                    }
                    else if(bookmark.location.mepsDocumentId != null) {
                      showPageDocument(context, widget.bible, bookmark.location.mepsDocumentId!, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier, audios: widget.audios);
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
                      //showPage(context, PublicationMenu(publication: widget.publication, publicationLanguage: value));
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
                  widget.bible.shareLink();
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Stack(
        children: [
          if (_books[_currentIndex]['HasCommentary'] == 1)
            Positioned(
              top: 0, // Aligner l'image en haut de l'écran
              left: 0,
              right: 0,
              child: Image.file(
                File('${widget.bible.path}/${_books[_currentIndex]['FilePath']}'),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          if (_books[_currentIndex]['HasCommentary'] == 1)
            Positioned(
              top: 150, // Aligner l'image en haut de l'écran
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55), // Fond semi-transparent
                ),
                child: Text(
                  _books[_currentIndex]['BookDisplayTitle'] ?? '',
                  style: const TextStyle(fontSize: 25, color: Colors.white), // Texte blanc pour contraster avec le fond
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Column(
            children: [
              if (_books[_currentIndex]['HasCommentary'] == 1) const SizedBox(height: 200), // Décalage pour éviter que le contenu chevauche l'image
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _books.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _fetchBookPage();
                    });
                  },
                  itemBuilder: (context, index) {
                    return _isOverview
                        ? _buildOutlineView()
                        : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                      scrollDirection: Axis.vertical,
                      child: _buildChapterGrid(_chapters),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineView() {
    return _isLoadingOverview ? const Center(child: CircularProgressIndicator()) : InAppWebView(
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
        data: _overviewHtml,
        mimeType: 'text/html',
        baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'),
      )
    );
  }

  Widget _buildChapterGrid(List<dynamic> chapters) {
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
            childAspectRatio: 1.0, // Adjust according to your UI design
          ),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return _buildChapterContainer(chapter);
          },
        ),
        if (_books[_currentIndex]['Title'] != null)
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
                  showPageDocument(context, widget.bible, _books[_currentIndex]['MepsDocumentId'], audios: widget.audios);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      const Icon(JwIcons.information_circle, color: Colors.white, size: 24.0),
                      const SizedBox(width: 8),
                      Text(
                        _books[_currentIndex]['Title'],
                        style: const TextStyle(fontSize: 20.0, color: Colors.white),
                      )
                    ],
                  )
                )
            ),
          ),
        if (_books[_currentIndex]['HasCommentary'] == 1)
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
                  //showPage(context, PageLocalDocumentView(publication: widget.bible, mepsDocumentId: _books[_currentIndex]['MepsDocumentId']));
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

  Widget _buildChapterContainer(dynamic chapter) {
    return InkWell(
      onTap: () {
        showPageBibleChapter(context, widget.bible, _books[_currentIndex]['BibleBookId'], chapter['ChapterNumber'], audios: widget.audios);
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
}