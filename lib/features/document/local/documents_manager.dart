import 'package:jwlife/data/models/publication.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/utils/utils.dart';
import '../data/models/document.dart';

class DocumentsManager {
  Publication publication;
  int? initMepsDocumentId;
  int? initBookNumber;
  int? initChapterNumber;
  late Database database;
  int selectedDocumentId = -1;
  List<Document> documents = [];
  bool _isInitializing = false;
  bool initialized = false;

  DocumentsManager({required this.publication, this.initMepsDocumentId, this.initBookNumber, this.initChapterNumber});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData() async {
    if (initialized || _isInitializing) return;

    _isInitializing = true;
    try {
      // 1. Ouverture de la base de données
      database = await openReadOnlyDatabase(publication.databasePath!);

      // 2. Chargement des données
      await fetchDocuments(); 
      
      initialized = true;
    } 
    catch (e) {
      printTime('Error initializing database: $e');
    } 
    finally {
      _isInitializing = false;
    }
  }

  Future<void> fetchDocuments() async {
    bool isRtl = publication.mepsLanguage.isRtl;

    try {
      List<Map<String, dynamic>> result = [];
      if (publication.isBible()) {
        result = await database.rawQuery("""
          SELECT 
            Document.*,
            (
              SELECT Title
              FROM PublicationViewItem pvi
              JOIN PublicationViewSchema pvs
                ON pvi.SchemaType = pvs.SchemaType
              WHERE pvi.DefaultDocumentId = Document.DocumentId
                AND pvs.DataType = 'name'
              LIMIT 1
            ) AS DisplayTitle,
      
            BibleChapter.BookNumber,
            BibleChapter.ChapterNumber,
            BibleChapter.Content AS ChapterContent,
            BibleChapter.PreContent,
            BibleChapter.PostContent,
            BibleChapter.FirstVerseId,
            BibleChapter.LastVerseId
      
          FROM Document
          LEFT JOIN BibleBook ON Document.Type = 2 AND BibleBook.BookDocumentId = Document.DocumentId
          LEFT JOIN BibleChapter ON BibleChapter.BookNumber = BibleBook.BibleBookId
          WHERE Document.Class <> 118;
        """);
      }
      else {
        result = await database.rawQuery("""
          SELECT 
            Document.*, 
            (SELECT Title 
             FROM PublicationViewItem pvi 
             JOIN PublicationViewSchema pvs 
               ON pvi.SchemaType = pvs.SchemaType
             WHERE pvi.DefaultDocumentId = Document.DocumentId 
               AND pvs.DataType = 'name'
             LIMIT 1
            ) AS DisplayTitle
          FROM Document
        """);
      }

      documents = result.map((e) => Document.fromMap(database, publication, e)).toList();

      if (isRtl) {
        documents = documents.reversed.toList();
      }

      if (initMepsDocumentId != null) {
        if(initBookNumber != null && initChapterNumber != null) {
          selectedDocumentId = documents.indexWhere((element) => element.bookNumber == initBookNumber && element.chapterNumberBible == initChapterNumber);
        }
        else {
          selectedDocumentId = documents.indexWhere((element) => element.mepsDocumentId == initMepsDocumentId);
        }
      }
    }
    catch (e) {
      printTime('Error fetching all documents: $e');
    }
  }

  Document getCurrentDocument() => documents[selectedDocumentId];

  Document getDocumentAt(int index) => documents[index];

  Document getDocumentFromMepsDocumentId(int mepsDocumentId) {
    return documents.firstWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }

  int getIndexFromMepsDocumentId(int mepsDocumentId) {
    return documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }

  int getIndexFromBookNumberAndChapterNumber(int bookNumber, int chapterNumber) {
    return documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);
  }
}