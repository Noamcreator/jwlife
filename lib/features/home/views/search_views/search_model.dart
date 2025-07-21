import 'dart:convert';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/BibleCluesInfo.dart';
import '../../../../core/utils/utils.dart';
import '../../../../data/databases/publication.dart';
import '../../../publication/views/document/local/documents_manager.dart';

class SearchModel {
  String query;

  SearchModel({required this.query});

  List<Map<String, dynamic>> allSearch = [];
  List<Map<String, dynamic>> publications = [];
  List<Map<String, dynamic>> videos = [];
  List<Map<String, dynamic>> audios = [];
  List<Map<String, dynamic>> bible = [];
  List<Map<String, dynamic>> verses = [];
  List<Map<String, dynamic>> images = [];

  void clear() {
    allSearch = [];
    publications = [];
    videos = [];
    audios = [];
    bible = [];
    verses = [];
    images = [];
  }

  Future<void> fetchOnActiveTab(int index) async {
    switch (index) {
      case 0:
        await _fetchData('all');
        break;
      case 1:
        await _fetchData('publications');
        break;
      case 2:
        await _fetchData('videos');
        break;
      case 3:
        await _fetchData('audios');
        break;
      case 4:
        await _fetchData('verses');
        break;
      case 5:
        await fetchVerses();
      case 6:
        await fetchImages();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchData(String path) async {
    final queryParams = {'q': query};
    final url = Uri.https(
      'b.jw-cdn.org',
      '/apis/search/results/${JwLifeSettings().currentLanguage.symbol}/$path',
      queryParams,
    );

    try {
      final headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      final response = await Api.httpGetWithHeadersUri(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final results = (data['results'] as List).map<Map<String, dynamic>>((item) {
          return {
            'title': item['title'] ?? '',
            'type': item['type'] ?? '',
            'label': item['label'] ?? '',
            'snippet': item['snippet'] ?? '',
            'context': item['context'] ?? '',
            'lank': item['lank'] ?? '',
            'imageUrl': item['image'] != null ? item['image']['url'] : '',
            'links': item['links'] ?? [],
            'layout': item['layout'] ?? [],
            'results': item['results'] ?? [],
          };
        }).toList();

        switch (path) {
          case 'all':
            allSearch = results;
            break;
          case 'publications':
            publications = results;
            break;
          case 'videos':
            videos = results;
            break;
          case 'audio':
            audios = results;
            break;
          case 'bible':
            bible = results;
            break;
        }

        return results;
      } else {
        printTime('Erreur de requête HTTP: ${response.statusCode}');
      }
    }
    catch (e) {
      printTime('Erreur lors de la récupération des données de l\'API: $e');
    }

    return [];
  }

  // Les méthodes publiques qui renvoient directement les résultats en cache si disponibles
  Future<List<Map<String, dynamic>>> fetchAllSearch() async {
    if (allSearch.isNotEmpty) return allSearch;
    return await _fetchData('all');
  }

  Future<List<Map<String, dynamic>>> fetchPublications() async {
    if (publications.isNotEmpty) return publications;
    return await _fetchData('publications');
  }

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    if (videos.isNotEmpty) return videos;
    return await _fetchData('videos');
  }

  Future<List<Map<String, dynamic>>> fetchAudios() async {
    if (audios.isNotEmpty) return audios;
    return await _fetchData('audio');
  }

  Future<List<Map<String, dynamic>>> fetchBible() async {
    if (bible.isNotEmpty) return bible;
    return await _fetchData('bible');
  }

  Future<List<Map<String, dynamic>>?> fetchVerses() async {
    if (verses.isNotEmpty) return verses;

    int? verseId = await getVerse(query);
    if (verseId == null) return null;

    List<Future<List<Map<String, dynamic>>>> futures = [];

    for (Publication publication in PublicationRepository().getPublicationsFromLanguage(JwLifeSettings().currentLanguage)) {
      futures.add(_fetchVerseFromPublication(publication, verseId));
    }

    // Exécute toutes les recherches en parallèle
    final results = await Future.wait(futures);

    // Aplatit la liste et retire les résultats vides
    final allVerses = results.expand((e) => e).toList();

    verses = allVerses;
    return allVerses;
  }

  Future<List<Map<String, dynamic>>> _fetchVerseFromPublication(Publication publication, int verseId) async {
    DocumentsManager? documentsManager = publication.documentsManager;
    Database db = documentsManager != null ? documentsManager.database : await openDatabase(publication.databasePath!);

    Future<bool> tableExists(String name) async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [name],
      );
      return result.isNotEmpty;
    }

    // Vérifie la table BibleCitation
    final bibleCitationTable = await tableExists("BibleCitation");
    if (!bibleCitationTable) {
      if (documentsManager == null) await db.close();
      return [];
    }

    final hasDocumentMultimedia = await tableExists("DocumentMultimedia");
    final hasMultimedia = await tableExists("Multimedia");

    List<Map<String, dynamic>> results = [];

    try {
      if (hasDocumentMultimedia && hasMultimedia) {
        results = await db.rawQuery('''
        SELECT 
          bc.*,
          d.Title AS DocumentTitle,
          d.Content,
          d.MepsDocumentId,
          p.Title AS PublicationTitle,
          p.Symbol,
          p.Year,
          p.MepsLanguageIndex,
          p.IssueTagNumber,
          dp.BeginPosition,
          dp.EndPosition,
          m.FilePath
        FROM BibleCitation bc
        LEFT JOIN Document d ON bc.DocumentId = d.DocumentId
        LEFT JOIN Publication p ON d.PublicationId = p.PublicationId
        LEFT JOIN DocumentParagraph dp ON dp.DocumentId = bc.DocumentId AND dp.ParagraphIndex = bc.ParagraphOrdinal
        LEFT JOIN (
          SELECT dm.DocumentId, m.FilePath
          FROM DocumentMultimedia dm
          JOIN Multimedia m ON m.MultimediaId = dm.MultimediaId
          WHERE m.CategoryType = 9
          GROUP BY dm.DocumentId
        ) m ON m.DocumentId = bc.DocumentId
        WHERE ? BETWEEN bc.FirstBibleVerseId AND bc.LastBibleVerseId
      ''', [verseId]);
      } else {
        results = await db.rawQuery('''
        SELECT 
          bc.*,
          d.Title AS DocumentTitle,
          d.Content,
          d.MepsDocumentId,
          p.Title AS PublicationTitle,
          p.Symbol,
          p.Year,
          p.MepsLanguageIndex,
          p.IssueTagNumber,
          dp.BeginPosition,
          dp.EndPosition
        FROM BibleCitation bc
        LEFT JOIN Document d ON bc.DocumentId = d.DocumentId
        LEFT JOIN Publication p ON d.PublicationId = p.PublicationId
        LEFT JOIN DocumentParagraph dp ON dp.DocumentId = bc.DocumentId AND dp.ParagraphIndex = bc.ParagraphOrdinal
        WHERE ? BETWEEN bc.FirstBibleVerseId AND bc.LastBibleVerseId
      ''', [verseId]);
      }
    } catch (e) {
      // Log error if needed
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> fetchImages() async {
    if (images.isNotEmpty) return images;

    final List<Future<List<Map<String, dynamic>>>> futures = [];

    for (Publication pub in PublicationRepository().getPublicationsFromLanguage(JwLifeSettings().currentLanguage)) {
      futures.add(_fetchImagesFromPublication(pub, query));
    }

    final results = await Future.wait(futures);

    final allImages = results.expand((r) => r).toList();
    images = allImages;

    return allImages;
  }

  Future<List<Map<String, dynamic>>> _fetchImagesFromPublication(Publication pub, String query) async {
    DocumentsManager? documentsManager = pub.documentsManager;
    Database db = documentsManager != null
        ? documentsManager.database
        : await openDatabase(pub.databasePath!);

    Future<bool> tableExists(Database db, String name) async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [name],
      );
      return result.isNotEmpty;
    }

    List<Map<String, dynamic>> results = [];

    try {
      final hasDocMultimedia = await tableExists(db, 'DocumentMultimedia');
      final hasMultimedia = await tableExists(db, 'Multimedia');

      if (hasDocMultimedia && hasMultimedia) {
        results = await db.rawQuery('''
        SELECT d.Title AS DocumentTitle,
               d.Content,
               d.MepsDocumentId,
               p.Title AS PublicationTitle,
               p.Symbol,
               p.Year,
               p.MepsLanguageIndex,
               p.IssueTagNumber,
               dm.BeginParagraphOrdinal, dm.EndParagraphOrdinal,
               m.FilePath, m.Label, m.Caption
        FROM DocumentMultimedia dm
        JOIN Document d ON dm.DocumentId = d.DocumentId
        LEFT JOIN Publication p ON d.PublicationId = p.PublicationId
        JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId
        WHERE (m.Label LIKE '%' || ? || '%' OR m.Caption LIKE '%' || ? || '%')
          AND m.MimeType = 'image/jpeg'
      ''', [query, query]);
      }
    } catch (e) {
      printTime('Error reading database ${pub.databasePath}: $e');
    } finally {
      if (documentsManager == null) await db.close();
    }

    return results;
  }

  Future<int?> getVerse(String reference) async {
    final regex = RegExp(r'^([\w\s]+)\s+(\d+):(\d+)$', caseSensitive: false);
    final match = regex.firstMatch(reference.trim().toLowerCase());

    if (match == null) {
      return null;
    }

    String bookNameInput = match.group(1)!.trim();
    int chapterNumber = int.parse(match.group(2)!);
    int verseNumber = int.parse(match.group(3)!);

    // Trouve le bookNumber correspondant au nom du livre
    List<BibleBookName> books = JwLifeApp.bibleCluesInfo.bibleBookNames;

    BibleBookName? matchedBook = books.firstWhere(
          (book) =>
      book.standardBookName.toLowerCase() == bookNameInput ||
          book.standardBookAbbreviation.toLowerCase() == bookNameInput ||
          book.officialBookAbbreviation.toLowerCase() == bookNameInput ||
          book.standardSingularBookName.toLowerCase() == bookNameInput ||
          book.standardSingularBookAbbreviation.toLowerCase() == bookNameInput ||
          book.officialSingularBookAbbreviation.toLowerCase() == bookNameInput,
      orElse: () => throw Exception("Livre biblique introuvable : $bookNameInput"),
    );

    int bookNumber = matchedBook.bookNumber;

    // Ouvre la base de données
    Database bibleDatabase = await openDatabase(
      PublicationRepository().getAllBibles().first.databasePath!,
    );

    // Récupère le BibleVerseId
    final List<Map<String, Object?>> result = await bibleDatabase.rawQuery('''
    SELECT BibleChapter.FirstVerseId + (? - 1) AS BibleVerseId
    FROM BibleChapter
    WHERE BookNumber = ? AND ChapterNumber = ?
  ''', [verseNumber, bookNumber, chapterNumber]);

    if (result.isEmpty) {
      return null;
    }

    return result.first['BibleVerseId'] as int;
  }
}
