import 'dart:io';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/api/wikipedia_api.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/bible_clues_info.dart';
import '../../../../core/utils/files_helper.dart';
import '../../../../core/utils/utils.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/models/userdata/input_field.dart';
import '../../../publication/pages/document/local/documents_manager.dart';

class SearchModel {
  String query;

  SearchModel({required this.query});

  List<WikipediaArticle> wikipediaArticles = [];

  List<Map<String, dynamic>> allSearch = [];
  List<Map<String, dynamic>> publications = [];
  List<Map<String, dynamic>> videos = [];
  List<Map<String, dynamic>> audios = [];
  List<Map<String, dynamic>> bible = [];
  List<Map<String, dynamic>> verses = [];
  List<Map<String, dynamic>> images = [];

  List<Note> notes = [];
  List<InputField> inputFields = [];

  void clear() {
    wikipediaArticles = [];
    allSearch = [];
    publications = [];
    videos = [];
    audios = [];
    bible = [];
    verses = [];
    images = [];
    notes = [];
    inputFields = [];
  }

  Future<List<Map<String, dynamic>>> _fetchData(String path) async {
    final queryParams = {'q': query};
    final url = Uri.https(
      'b.jw-cdn.org',
      '/apis/search/results/${JwLifeSettings().currentLanguage.symbol}/$path',
      queryParams,
    );

    printTime('url: $url');

    try {
      final headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      final response = await Api.httpGetWithHeadersUri(url, headers: headers);

      if (response.statusCode == 200) {
        final results = (response.data['results'] as List).map<Map<String, dynamic>>((item) {
          return {
            'title': item['title'] ?? '',
            'type': item['type'] ?? '',
            'subtype': item['subtype'] ?? '',
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

  Future<List<WikipediaArticle>> fetchWikipedia() async {
    if (wikipediaArticles.isNotEmpty) return wikipediaArticles;
    return await WikipediaApi.getWikipediaSummary(query);
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
          p.KeySymbol,
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
      }
      else {
        results = await db.rawQuery('''
        SELECT 
          bc.*,
          d.Title AS DocumentTitle,
          d.Content,
          d.MepsDocumentId,
          p.Title AS PublicationTitle,
          p.KeySymbol,
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

      if (documentsManager == null) await db.close();
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
    Database db = documentsManager != null ? documentsManager.database : await openDatabase(pub.databasePath!);

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
               p.UndatedSymbol AS KeySymbol,
               p.Year,
               p.MepsLanguageIndex,
               p.IssueTagNumber,
               dm.BeginParagraphOrdinal, dm.EndParagraphOrdinal,
               m.FilePath, m.Label, m.Caption
        FROM DocumentMultimedia dm
        JOIN Document d ON dm.DocumentId = d.DocumentId
        LEFT JOIN Publication p ON d.PublicationId = p.PublicationId
        JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId
        WHERE (m.Label LIKE '%' || ? || '%' OR m.Caption LIKE '%' || ? || '%') AND m.MimeType = 'image/jpeg'
      ''', [query, query]);
      }
    } catch (e) {
      printTime('Error reading database ${pub.databasePath}: $e');
    }
    finally {
      if (documentsManager == null) await db.close();
    }

    return results;
  }

  Future<int?> getVerse(String reference) async {
    final regex = RegExp(r'^(.+)\s+(\d+):(\d+)', caseSensitive: false);
    final match = regex.firstMatch(reference.trim());

    if (match == null) {
      return null;
    }

    String bookNameInput = match.group(1)!.trim().toLowerCase();
    int chapter1 = int.parse(match.group(2)!);
    int verse1 = int.parse(match.group(3)!);

    // Trouve le bookNumber correspondant au nom du livre
    List<BibleBookName> books = JwLifeApp.bibleCluesInfo.bibleBookNames;

    BibleBookName? matchedBook;

    for (final book in books) {
      if (book.standardBookName.toLowerCase() == bookNameInput ||
          book.standardBookAbbreviation.toLowerCase() == bookNameInput ||
          book.officialBookAbbreviation.toLowerCase() == bookNameInput ||
          book.standardSingularBookName.toLowerCase() == bookNameInput ||
          book.standardSingularBookAbbreviation.toLowerCase() == bookNameInput ||
          book.officialSingularBookAbbreviation.toLowerCase() == bookNameInput) {
        matchedBook = book;
        break; // Sort de la boucle dès qu'une correspondance est trouvée
      }
    }

    if (matchedBook == null) {
      return null; // Retourne null si le livre n'est pas trouvé
    }

    int book1 = matchedBook.bookNumber;

    int book2 = book1;
    int chapter2 = chapter1;
    int verse2 = verse1;

    String bibleInfoName = 'NWTR';

    File mepsFile = await getMepsUnitDatabaseFile();

    try {
      Database db = await openDatabase(mepsFile.path);
      List<Map<String, dynamic>> versesIds = await db.rawQuery("""
      SELECT
      (
        SELECT
          FirstBibleVerseId +
        CASE
            WHEN EXISTS (
                SELECT 1 FROM BibleSuperscriptionLocation
                WHERE BookNumber = ? AND ChapterNumber = ?
            ) THEN
                CASE
                    WHEN ? = 0 OR ? = 1 THEN 0
                    ELSE (? - FirstOrdinal) + 1
                END
            ELSE (? - FirstOrdinal)
        END
        FROM BibleRange
        INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
        WHERE BibleInfo.Name = ? AND BookNumber = ? AND ChapterNumber = ?
      ) AS FirstVerseId,
      
      (
        SELECT 
          FirstBibleVerseId + (? - FirstOrdinal) + 
          CASE 
            WHEN EXISTS (
              SELECT 1 FROM BibleSuperscriptionLocation
              WHERE BookNumber = ? AND ChapterNumber = ?
            ) AND ? > 0 THEN 1 ELSE 0
          END
        FROM BibleRange
        INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
        WHERE BibleInfo.Name = ? AND BookNumber = ? AND ChapterNumber = ?
      ) AS LastVerseId;
      """, [book1, chapter1, verse1, verse1, verse1, verse1, bibleInfoName, book1, chapter1, verse2, book2, chapter2, verse2, bibleInfoName, book2, chapter2]);

      db.close();

      if (versesIds.isEmpty) {
        return null;
      }

      return versesIds.first['FirstVerseId'] as int;
    }
    catch (e) {
      printTime('Error reading database ${mepsFile.path}: $e');
    }

    return -1;
  }

  Future<List<Note>> fetchNotes() async {
    if (notes.isNotEmpty) return notes;
    return await JwLifeApp.userdata.getNotes(query: query);
  }

  Future<List<InputField>> fetchInputFields() async {
    if (inputFields.isNotEmpty) return inputFields;
    return await JwLifeApp.userdata.getInputFields(query);
  }
}
