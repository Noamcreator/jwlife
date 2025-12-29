import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';

import '../../../core/uri/jworg_uri.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils_database.dart';
import '../../document/local/documents_manager.dart';
import '../../publication/models/menu/local/words_suggestions_model.dart';

// Classe pour encapsuler les données d'un livre
class BibleBook {
  final Map<String, dynamic> bookInfo;
  List<dynamic>? chapters;
  String? overviewHtml;
  String? profileHtml;
  int? firstVerseId;
  int? lastVerseId;
  bool isLoading;
  bool isOverview;

  BibleBook(this.bookInfo)
      : isLoading = true,
        isOverview = false;
}

class BibleChapterController {
  final Publication bible;
  final int initialBookId;

  // Variables d'état
  bool _isInitialLoading = true;
  List<BibleBook> _booksData = [];
  int _currentIndex = 0;

  // Getters pour l'accès public
  bool get isInitialLoading => _isInitialLoading;
  List<BibleBook> get booksData => _booksData;
  int get currentIndex => _currentIndex;
  BibleBook? get currentBook => (_booksData.isNotEmpty) ? _booksData[_currentIndex] : null;

  // Callback pour notifier la page
  VoidCallback? onStateChanged;

  BibleChapterController({required this.bible, required this.initialBookId});

  void _notifyListeners() {
    // Utiliser WidgetsBinding pour s'assurer que la notification se fait après la frame actuelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStateChanged?.call();
    });
  }

  Future<void> initialize() async {
    try {
      // 1. Charger la liste de tous les livres
      await _fetchBooks();

      // 2. Charger les données spécifiques du livre initial
      if (_booksData.isNotEmpty) {
        await _loadBookData(_currentIndex);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation: $e');
    } finally {
      // 3. Toujours marquer l'initialisation comme terminée
      _isInitialLoading = false;
      _notifyListeners();
    }
  }

  // --- Logique de chargement des données ---

  Future<void> _fetchBooks() async {
    try {
      // 1. Initialisation sécurisée du manager
      if (bible.documentsManager == null) {
        bible.documentsManager = DocumentsManager(publication: bible, mepsDocumentId: -1);
        await bible.documentsManager!.initializeDatabaseAndData();
        bible.wordsSuggestionsModel ??= WordsSuggestionsModel(bible);
      }

      final database = bible.documentsManager!.database;

      // 2. Vérifications de structure en parallèle pour gagner du temps
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

      // 3. Construction de la requête SQL dynamique
      // On n'ajoute les JOIN que si les colonnes existent dans la table BibleBook
      String selectFields = 'BibleBook.*, d1.*';
      String joins = 'LEFT JOIN Document d1 ON BibleBook.IntroDocumentId = d1.DocumentId';

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

      // Gestion du chemin multimédia
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

      final String finalQuery = '''
      SELECT $selectFields, $multimediaSubquery
      FROM BibleBook
      $joins
    ''';

      // 4. Exécution et mapping
      final List<Map<String, dynamic>> results = await database.rawQuery(finalQuery);

      _booksData = results.map((book) => BibleBook(book)).toList();

      // 5. Gestion de l'index
      _currentIndex = _booksData.indexWhere(
              (book) => book.bookInfo['BibleBookId'] == initialBookId
      );

      if (_currentIndex == -1) _currentIndex = 0;

    } catch (e, stacktrace) {
      debugPrint('Erreur lors de la récupération des livres: $e');
      debugPrint(stacktrace.toString());
      _booksData = [];
      rethrow;
    }
  }

  Future<void> _loadBookData(int bookIndex) async {
    if (bookIndex < 0 || bookIndex >= _booksData.length) return;

    BibleBook bookData = _booksData[bookIndex];

    // Si le livre est déjà chargé, on sort
    if (!bookData.isLoading && bookData.chapters != null) return;

    // Marquer comme en chargement
    if (!bookData.isLoading) {
      bookData.isLoading = true;
      // Notifier immédiatement pour afficher le loader
      if (bookIndex == _currentIndex && !_isInitialLoading) {
        _notifyListeners();
      }
    }

    try {
      Database database = bible.documentsManager!.database;

      // Charger les chapitres
      List<Map<String, dynamic>> chaptersResults = await database.rawQuery('''
        SELECT
          BibleChapter.ChapterNumber,
          BibleChapter.FirstVerseId,
          BibleChapter.LastVerseId,
          Document.MepsDocumentId
        FROM BibleChapter
        INNER JOIN BibleBook ON BibleChapter.BookNumber = BibleBook.BibleBookId
        INNER JOIN Document ON BibleBook.BookDocumentId = Document.DocumentId
        WHERE BookNumber = ?
      ''', [bookData.bookInfo['BibleBookId']]);

      // Générer le HTML de l'aperçu
      String overviewHtml = _generateHtmlContent(
          bookData.bookInfo['OverviewContent'] ?? bookData.bookInfo['OutlineContent']
      );

      // Générer le HTML du profil
      String profileHtml = _generateHtmlContent(
          bookData.bookInfo['Profile']
      );

      // Mettre à jour les données du livre
      bookData.chapters = chaptersResults;
      bookData.overviewHtml = overviewHtml;
      bookData.profileHtml = profileHtml;

      bookData.firstVerseId = chaptersResults.first['FirstVerseId'];
      bookData.lastVerseId = chaptersResults.last['LastVerseId'];

    } catch (e) {
      debugPrint('Erreur lors du chargement des données du livre: $e');
      bookData.chapters = [];
      bookData.overviewHtml = '<h1>Erreur de chargement</h1><p>Impossible de charger le contenu du livre.</p>';
      bookData.profileHtml = '<h1>Erreur de chargement</h1>';
    } finally {
      // TOUJOURS mettre à jour l'état et notifier, même en cas d'erreur
      bookData.isLoading = false;
      // Notifier même si ce n'est pas le livre courant (pour le préchargement)
      _notifyListeners();
    }
  }

  String _generateHtmlContent(dynamic contentBlob) {
    if (contentBlob == null) return '';

    try {
      final decodedHtml = decodeBlobContent(
        contentBlob as Uint8List,
        bible.hash!,
      );

      return createHtmlContent(
          decodedHtml,
          '''jwac layout-reading layout-sidebar''',
          ''
      );
    } catch (e) {
      debugPrint('Erreur lors de la génération du HTML: $e');
      return '<p>Erreur de génération du contenu</p>';
    }
  }

  // --- Logique d'interaction UI ---

  void onPageChanged(int index) {
    if (index == _currentIndex) return; // Éviter les notifications inutiles

    _currentIndex = index;
    _notifyListeners();

    // Charger les données du nouveau livre si nécessaire (sans attendre)
    _loadBookData(index);

    // Précharger les livres adjacents en arrière-plan
    if (index > 0) _loadBookData(index - 1);
    if (index < _booksData.length - 1) _loadBookData(index + 1);
  }

  void toggleOverview() {
    if (currentBook != null) {
      currentBook!.isOverview = !currentBook!.isOverview;
      _notifyListeners();
    }
  }

  String getShareUri() {
    if (currentBook == null) return '';

    return JwOrgUri.bibleBook(
        wtlocale: bible.mepsLanguage.symbol,
        pub: bible.keySymbol,
        book: currentBook!.bookInfo['BibleBookId']
    ).toString();
  }

  void onTapChapter(int chapterNumber) {
    if (currentBook != null) {
      showPageBibleChapter(bible, currentBook!.bookInfo['BibleBookId'], chapterNumber);
    }
  }

  // Méthode pour nettoyer les ressources si nécessaire
  void dispose() {
    onStateChanged = null;
  }
}