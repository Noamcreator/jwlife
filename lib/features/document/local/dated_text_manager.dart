
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/document/data/models/dated_text.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/utils/utils.dart';

class DatedTextManager {
  Publication publication;
  DateTime dateTime;
  late Database database;
  int selectedDatedTextIndex = -1;
  List<DatedText> datedTexts = [];
  String html = '';

  DatedTextManager({required this.publication, required this.dateTime});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData() async {
    try {
      database = await openReadOnlyDatabase(publication.databasePath!);
      await fetchDatedText();
    }
    catch (e) {
      printTime('Error initializing database: $e');
    }
  }

  Future<void> fetchDatedText() async {
    int dateInt = convertDateTimeToIntDate(dateTime);

    try {
      List<Map<String, dynamic>> result = await database.rawQuery("""
          SELECT 
            DatedText.DatedTextId,
            DatedText.DocumentId,
            DatedText.Link,
            DatedText.FirstDateOffset,
            DatedText.LastDateOffset,
            DatedText.Content,
            Document.MepsDocumentId,
            Document.MepsLanguageIndex,
            Document.Class,
            Document.HasPronunciationGuide
          FROM DatedText
          INNER JOIN Document ON Document.DocumentId = DatedText.DocumentId
        """);

      datedTexts = result.map((e) => DatedText.fromMap(database, publication, e)).toList();
      selectedDatedTextIndex = datedTexts.indexWhere((element) => element.firstDateOffset == dateInt);
    }
    catch (e) {
      printTime('Error fetching all documents: $e');
    }
  }

  DatedText getCurrentDatedText() => datedTexts[selectedDatedTextIndex];

  DatedText getPreviousDatedText() => datedTexts[selectedDatedTextIndex - 1];

  DatedText getNextDocument() => datedTexts[selectedDatedTextIndex + 1];

  DatedText getDatedTextAt(int index) => datedTexts[index];

  int getIndexFromMepsDocumentId(int mepsDocumentId) {
    return datedTexts.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }
}