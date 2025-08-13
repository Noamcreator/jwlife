import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/pages/document/data/models/dated_text.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/utils/utils.dart';
import '../data/models/document.dart';

class DocumentsManager {
  Publication publication;
  int mepsDocumentId;
  int? bookNumber;
  int? chapterNumber;
  late Database database;
  int selectedDocumentIndex = -1;
  List<Document> documents = [];

  int selectedDatedTextIndex = -1;
  List<DatedText> datedTexts = [];
  String html = '';

  DocumentsManager({required this.publication, required this.mepsDocumentId, this.bookNumber, this.chapterNumber});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData() async {
    try {
      database = await openDatabase(publication.databasePath!);
      await fetchDocuments();
    }
    catch (e) {
      printTime('Error initializing database: $e');
    }
  }

  Future<void> fetchDocuments() async {
    try {
      List<Map<String, dynamic>> result = [];
      if (publication.category.id == 1) {
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
            ) AS DisplayTitle,
            BibleChapter.BookNumber,
            BibleChapter.ChapterNumber,
            BibleChapter.Content AS ChapterContent,
            BibleChapter.PreContent,
            BibleChapter.PostContent,
            BibleChapter.FirstVerseId,
            BibleChapter.LastVerseId
          FROM Document
          LEFT JOIN BibleChapter 
              ON Document.Type = 2 
              AND BibleChapter.BookNumber = Document.ChapterNumber
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
      if (mepsDocumentId != -1) {
        if(bookNumber != null && chapterNumber != null) {
          selectedDocumentIndex = documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);
        }
        else {
          selectedDocumentIndex = documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
        }
      }
    }
    catch (e) {
      printTime('Error fetching all documents: $e');
    }
  }

  Document getCurrentDocument() => documents[selectedDocumentIndex];

  Document getPreviousDocument() => documents[selectedDocumentIndex - 1];

  Document getNextDocument() => documents[selectedDocumentIndex + 1];

  Document getDocumentAt(int index) => documents[index];

  Document getDocumentFromMepsDocumentId(int mepsDocumentId) {
    return documents.firstWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }

  int getIndexFromMepsDocumentId(int mepsDocumentId) {
    return documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }
}