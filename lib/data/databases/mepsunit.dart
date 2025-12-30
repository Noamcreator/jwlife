import 'package:sqflite/sqflite.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../core/bible_clues_info.dart';
import '../../core/utils/files_helper.dart';
import '../../core/utils/utils_database.dart';

class Mepsunit {
  static Future<void> loadBibleCluesInfo() async {
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
          WHERE BibleInfoId = 2 AND LanguageId = ${JwLifeSettings.instance.currentLanguage.value.id}
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

  static Future<int?> getMepsLanguageIdFromSymbol(String mepsLanguageSymbol) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      final mepsUnit = await openReadOnlyDatabase(mepsFile.path);

      try {
        final result = await mepsUnit.rawQuery('''
          SELECT LanguageId
          FROM Language
          WHERE Symbol = ?
        ''', [mepsLanguageSymbol]);

        if(result.isEmpty) {
          return null;
        }

        return result.first['LanguageId'] as int;
      }
      finally {
        await mepsUnit.close();
      }
    }
    return null;
  }

  static Future<String?> getMepsLanguageSymbolFromId(int mepsLanguageId) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      final mepsUnit = await openReadOnlyDatabase(mepsFile.path);

      try {
        final result = await mepsUnit.rawQuery('''
          SELECT Symbol
          FROM Language
          WHERE LanguageId = ?
        ''', [mepsLanguageId]);

        if(result.isEmpty) {
          return null;
        }

        return result.first['Symbol'] as String;
      }
      finally {
        await mepsUnit.close();
      }
    }
    return null;
  }
}