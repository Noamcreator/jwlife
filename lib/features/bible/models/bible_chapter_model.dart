import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/bible_book.dart';
import 'package:jwlife/data/models/bible_chapter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import '../../document/local/documents_manager.dart';

class BibleChapterController {
  final Publication bible;
  final int initialBookId;

  bool _isInitialLoading = true;
  List<BibleBook> _books = [];
  int _currentIndex = 0;

  bool get isInitialLoading => _isInitialLoading;
  List<BibleBook> get booksData => _books;
  int get currentIndex => _currentIndex;
  BibleBook? get currentBook => (_books.isNotEmpty) ? _books[_currentIndex] : null;

  VoidCallback? onStateChanged;

  bool _isMepsAttached = false;

  BibleChapterController({required this.bible, required this.initialBookId});

  void _notifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStateChanged?.call();
    });
  }

  Future<void> initialize() async {
    try {
      await _fetchBooks();
      if (_books.isNotEmpty) {
        // Charge le premier livre affiché
        await _loadBookData(_currentIndex);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation: $e');
    } finally {
      _isInitialLoading = false;
      _notifyListeners();
    }
  }

  Future<void> _fetchBooks() async {
    try {
      if (bible.documentsManager == null) {
        bible.documentsManager = DocumentsManager(publication: bible);
        await bible.documentsManager!.initializeDatabaseAndData();
      }

      final database = bible.documentsManager!.database;

      // 1. Vérification de la structure de la base pour les colonnes optionnelles
      final resultsStructure = await Future.wait([
        checkIfTableExists(database, 'Multimedia'),
        checkIfTableExists(database, 'DocumentMultimedia'),
        getColumnsForTable(database, 'BibleBook'),
      ]);

      final bool multimediaExists = resultsStructure[0] as bool;
      final bool docMultimediaExists = resultsStructure[1] as bool;
      final List<String> columns = resultsStructure[2] as List<String>;

      final bool hasOutline = columns.contains('OutlineDocumentId');
      final bool hasOverview = columns.contains('OverviewDocumentId');

      // 2. Construction de la requête SQL
      String selectFields = 'BibleBook.*, d1.Title AS IntroTitle, d1.MepsDocumentId AS IntroMepsDocumentId, dTitle.Title AS BookName';
      String joins = '''
        LEFT JOIN Document d1 ON BibleBook.IntroDocumentId = d1.DocumentId
        LEFT JOIN Document dTitle ON BibleBook.BookDocumentId = dTitle.DocumentId
      ''';

      if (hasOutline) {
        selectFields += ', d2.Content AS OutlineContent';
        joins += ' LEFT JOIN Document d2 ON BibleBook.OutlineDocumentId = d2.DocumentId';
      } else {
        selectFields += ', NULL AS OutlineContent';
      }

      if (hasOverview) {
        selectFields += ', d3.Content AS OverviewContent';
        joins += ' LEFT JOIN Document d3 ON BibleBook.OverviewDocumentId = d3.DocumentId';
      } else {
        selectFields += ', NULL AS OverviewContent';
      }

      String multimediaSubquery = 'NULL AS FilePath';
      if (multimediaExists && docMultimediaExists) {
        multimediaSubquery = '''
        (SELECT M.FilePath 
         FROM DocumentMultimedia DM
         JOIN Multimedia M ON DM.MultimediaId = M.MultimediaId 
         WHERE DM.DocumentId = BibleBook.IntroDocumentId 
         AND M.CategoryType = 13
         LIMIT 1) AS FilePath''';
      }

      final String finalQuery = 'SELECT $selectFields, $multimediaSubquery FROM BibleBook $joins';
      final List<Map<String, dynamic>> results = await database.rawQuery(finalQuery);

      _books = results.map((map) {
        final book = BibleBook.fromMap(map);
        
        final dynamic overviewBlob = map['OverviewContent'] ?? map['OutlineContent'];
        final dynamic profileBlob = map['Profile'];
        
        book.overviewHtml = _decodeHtml(overviewBlob);
        book.profileHtml = _decodeHtml(profileBlob);
        
        return book;
      }).toList();

      // 4. Déterminer l'index du livre sélectionné au départ
      _currentIndex = _books.indexWhere((book) => book.bookNumber == initialBookId);
      if (_currentIndex == -1) _currentIndex = 0;

    } catch (e) {
      debugPrint('Erreur lors de la récupération des livres: $e');
      rethrow;
    }
  }

  Future<void> _loadBookData(int bookIndex) async {
    if (bookIndex < 0 || bookIndex >= _books.length) return;

    BibleBook bookData = _books[bookIndex];
    if (!bookData.isLoading && bookData.chapters.isNotEmpty) return;

    bookData.isLoading = true;
    _notifyListeners();

    Database database = bible.documentsManager!.database;

    try {
      // 1. On n'attache que si ce n'est pas déjà fait
      if (!_isMepsAttached) {
        File mepsFile = await getMepsUnitDatabaseFile();
        await attachDatabases(database, {'meps': mepsFile.path});
        _isMepsAttached = true;
      }

      List<Map<String, dynamic>> chaptersResults = await database.rawQuery('''
        SELECT 
          br.ChapterNumber,
          CASE WHEN bc.ChapterNumber IS NOT NULL THEN 1 ELSE 0 END AS IsExist
        FROM meps.BibleRange br
        INNER JOIN meps.BibleInfo bi ON bi.BibleInfoId = br.BibleInfoId
        LEFT JOIN BibleChapter bc ON bc.ChapterNumber = br.ChapterNumber AND bc.BookNumber = br.BookNumber
        INNER JOIN BibleBook bb ON bb.BibleBookId = br.BookNumber
        INNER JOIN Publication p ON p.PublicationId = bb.PublicationId
        WHERE br.BookNumber = ? 
          AND bi.Name = p.BibleVersionForCitations 
          AND br.ChapterNumber IS NOT NULL
        ORDER BY br.ChapterNumber ASC
      ''', [bookData.bookNumber]);

      bookData.chapters = chaptersResults.map((map) => BibleChapter.fromMap(map)).toList(); 
    } 
    catch (e) {
      debugPrint('Erreur lors du chargement des données du livre: $e');
      bookData.chapters = [];
    } 
    finally {
      bookData.isLoading = false;
      bool otherLoading = _books.any((b) => b.isLoading);
      if (!otherLoading && _isMepsAttached) {
        try {
          await detachDatabases(database, ['meps']);
          _isMepsAttached = false;
        } catch (e) {
          debugPrint('Erreur lors du detach: $e');
        }
      }
      
      _notifyListeners();
    }
  }

  String? _decodeHtml(dynamic blob) {
    if (blob == null) return null;
    final decoded = decodeBlobContent(blob as Uint8List, bible.hash!);
    return createHtmlContent(decoded, 'jwac layout-reading', '');
  }

  void onPageChanged(int index) {
    _currentIndex = index;
    _loadBookData(index);
    _notifyListeners();
  }

  void toggleOverview() {
    currentBook?.isOverview = !(currentBook?.isOverview ?? false);
    _notifyListeners();
  }

  String getShareUri() {
    return JwOrgUri.bibleBook(
      wtlocale: bible.mepsLanguage.symbol,
      pub: bible.keySymbol,
      book: currentBook?.bookNumber ?? 0
    ).toString();
  }

  void onTapChapter(BibleChapter chapter) {
    showPageBibleChapter(bible, currentBook!.bookNumber, chapter.number);
  }

  void dispose() => onStateChanged = null;
}