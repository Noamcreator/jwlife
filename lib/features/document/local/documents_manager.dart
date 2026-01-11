import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
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
  List<Bookmark> bookmarks = [];
  bool _isInitializing = false;
  bool initialized = false;
  bool bibleDocumentsInitialized = false;

  DocumentsManager({required this.publication, this.initMepsDocumentId, this.initBookNumber, this.initChapterNumber});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData({bool fromMenu = false}) async {
    if (initialized || _isInitializing) return;

    _isInitializing = true;
    try {
      // 1. Ouverture de la base de données
      database = await openReadOnlyDatabase(publication.databasePath!);

      if(!publication.isBible() || !fromMenu) {
        // 2. Chargement des documents pour la Bible
        await fetchDocuments();
      }

      bookmarks = await JwLifeApp.userdata.getBookmarksFromPub(publication);
      
      initialized = true;
    } 
    catch (e) {
      printTime('Error initializing database: $e');
    } 
    finally {
      _isInitializing = false;
    }
  }

  // Méthode privée pour initialiser la base de données spécifique à la Bible
  Future<void> initializeBibleDocuments() async {
    if (bibleDocumentsInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      await fetchDocuments();
      
      bibleDocumentsInitialized = true;
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

  int getIndexFromBookMepsDocumentIdAndChapterNumber(int mepsDocumentId, int chapterNumber) {
    return documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId && element.chapterNumberBible == chapterNumber);
  }

  void addBookmark(Bookmark bookmark) {
    bookmarks.add(bookmark);
  }

  void removeBookmark(Bookmark bookmark) {
    bookmarks.remove(bookmark);
  }

  List<Bookmark> getBookmarksFromCurrentDocument() {
    Document currentDocument = getCurrentDocument();
    bool isBibleChapter = currentDocument.isBibleChapter();

    if (isBibleChapter) {
      return bookmarks.where((bookmark) => bookmark.location.bookNumber == currentDocument.bookNumber && bookmark.location.chapterNumber == currentDocument.chapterNumberBible).toList();
    }
    return bookmarks.where((bookmark) => bookmark.location.mepsDocumentId == currentDocument.mepsDocumentId).toList();
  }
}