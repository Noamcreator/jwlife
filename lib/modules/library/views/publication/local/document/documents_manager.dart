import 'dart:typed_data';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';
import 'package:jwlife/modules/library/views/publication/local/document/multimedia.dart';
import 'package:sqflite/sqflite.dart';

class DocumentsManager {
  Publication publication;
  int mepsDocumentId;
  int? bookNumber;
  int? chapterNumber;
  late Database database;
  int documentIndex = 0;
  List<Document> documents = [];

  DocumentsManager({required this.publication, required this.mepsDocumentId, this.bookNumber, this.chapterNumber});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData() async {
    try {
      database = await openDatabase(publication.databasePath);
      await fetchDocuments();
    }
    catch (e) {
      print('Error initializing database: $e');
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
          documentIndex = documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);
        }
        else {
          documentIndex = documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
        }
      }
    }
    catch (e) {
      print('Error fetching all documents: $e');
    }
  }

  Document getCurrentDocument() => documents[documentIndex];

  Document getPreviousDocument() => documents[documentIndex - 1];

  Document getNextDocument() => documents[documentIndex + 1];

  Document getDocumentAt(int index) => documents[index];

  Document getDocumentFromMepsDocumentId(int mepsDocumentId) {
    return documents.firstWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }

  int getIndexFromMepsDocumentId(int mepsDocumentId) {
    return documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }
}
