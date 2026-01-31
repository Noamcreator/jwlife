import 'package:sqflite/sqflite.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../core/bible_clues_info.dart';
import '../../core/utils/files_helper.dart';
import '../../core/utils/utils_database.dart';
import '../models/meps_language.dart';

class Mepsunit {
  static Future<void> loadBibleCluesInfo(String mepsLanguageSymbol) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      final mepsUnit = await openReadOnlyDatabase(mepsFile.path);

      try {
        final result = await mepsUnit.rawQuery("""
          SELECT
            BibleCluesInfoId,
            ChapterVerseSeparator, 
            Separator, 
            RangeSeparator, 
            NonconsecutiveChapterListSeparator, 
            SuperscriptionTextFull, 
            SuperscriptionTextAbbreviation
          FROM BibleCluesInfo
          INNER JOIN Language ON BibleCluesInfo.LanguageId = Language.LanguageId
          WHERE BibleInfoId = 2 AND Language.Symbol = '$mepsLanguageSymbol'
        """);

        final result2 = await mepsUnit.rawQuery("""
          SELECT DISTINCT 
            BibleBookName.*,
            BibleBookInfo.IsSingleChapter,
            BibleBookInfo.HasSuperscriptions
          FROM BibleBookName
          INNER JOIN BibleBookInfo ON BibleBookName.BookNumber = BibleBookInfo.BookNumber
          WHERE BibleBookName.BibleCluesInfoId = ${result.first['BibleCluesInfoId']};
        """);

        List<BibleBookName> bibleBookNames = result2.map((book) => BibleBookName.fromJson(book)).toList();
        JwLifeApp.bibleCluesInfo = BibleCluesInfo.fromJson(result.first, bibleBookNames);
      }
      finally {
        await mepsUnit.close();
      }
    }
  }
}