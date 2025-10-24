// bible_chapter_controller.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';

import '../../../core/jworg_uri.dart';
import '../../../core/utils/common_ui.dart';

// Classe pour encapsuler les données d'un livre
class BibleBookModel {
  final Map<String, dynamic> bookInfo;
  List<dynamic>? chapters;
  String? overviewHtml;
  String? profileHtml;
  bool isLoading;
  bool isOverview;

  BibleBookModel(this.bookInfo)
      : isLoading = true,
        isOverview = false;
}

class BibleChapterController {
  final Publication bible;
  final int initialBookId;

  // Variables d'état
  bool _isInitialLoading = true;
  List<BibleBookModel> _booksData = [];
  int _currentIndex = 0;

  // Getters pour l'accès public
  bool get isInitialLoading => _isInitialLoading;
  List<BibleBookModel> get booksData => _booksData;
  int get currentIndex => _currentIndex;
  BibleBookModel? get currentBook => (_booksData.isNotEmpty) ? _booksData[_currentIndex] : null;

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
    File mepsFile = await getMepsUnitDatabaseFile();
    try {
      Database database = bible.documentsManager!.database;

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
      ''', [bible.mepsLanguage.id]);

      await database.execute("DETACH DATABASE meps");

      _booksData = results.map((book) => BibleBookModel(book)).toList();

      _currentIndex = _booksData.indexWhere((bookData) => bookData.bookInfo['BibleBookId'] == initialBookId);
      if (_currentIndex == -1) _currentIndex = 0;

    } catch (e) {
      debugPrint('Erreur lors de la récupération des livres: $e');
      _booksData = [];
      rethrow; // Propager l'erreur pour la gérer dans initialize
    }
  }

  Future<void> _loadBookData(int bookIndex) async {
    if (bookIndex < 0 || bookIndex >= _booksData.length) return;

    BibleBookModel bookData = _booksData[bookIndex];

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

  String getBookTitle() {
    return currentBook?.bookInfo['StandardBookName'] ?? '';
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