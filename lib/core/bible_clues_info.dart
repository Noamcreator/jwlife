import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:sqflite/sqflite.dart';

class BibleCluesInfo {
  final String chapterVerseSeparator;
  final String separator;
  final String rangeSeparator;
  final String nonConsecutiveRangeSeparator;
  final String superscriptionFullText;
  final String superscriptionAbbreviationText;
  final List<BibleBookName> bibleBookNames;

  // Constructeur pour initialiser la liste de livres de la Bible et les séparateurs
  BibleCluesInfo({
    required this.bibleBookNames,
    this.chapterVerseSeparator = ':',
    this.separator = ',',
    this.rangeSeparator = '-',
    this.nonConsecutiveRangeSeparator = ';',
    this.superscriptionFullText = 'superscription',
    this.superscriptionAbbreviationText = 'Sup',
  });

  // Méthode pour désérialiser le JSON
  factory BibleCluesInfo.fromJson(Map<String, dynamic> json, List<BibleBookName> bibleBookNames) {
    return BibleCluesInfo(
      bibleBookNames: bibleBookNames,
      chapterVerseSeparator: json['ChapterVerseSeparator'] ?? ':',
      separator: json['Separator'] ?? ',',
      rangeSeparator: json['RangeSeparator'] ?? '-',
      nonConsecutiveRangeSeparator: json['NonconsecutiveChapterListSeparator'] ?? ';',
      superscriptionFullText: json['SuperscriptionTextFull'] ?? 'superscription',
      superscriptionAbbreviationText: json['SuperscriptionTextAbbreviation'] ?? 'Sup',
    );
  }

  BibleBookName? getBook(String bookName) {
    // Cherche le livre correspondant dans BibleCluesInfo
    return bibleBookNames.firstWhereOrNull(
            (b) => b.standardBookName.toLowerCase() == bookName.toLowerCase() ||
            b.standardBookAbbreviation.toLowerCase() == bookName.toLowerCase() ||
            b.officialBookAbbreviation.toLowerCase() == bookName.toLowerCase() ||
            b.standardSingularBookName.toLowerCase() == bookName.toLowerCase() ||
            b.standardSingularBookAbbreviation.toLowerCase() == bookName.toLowerCase() ||
            b.officialSingularBookAbbreviation.toLowerCase() == bookName.toLowerCase() ||
            b.standardPluralBookName.toLowerCase() == bookName.toLowerCase() ||
            b.standardPluralBookAbbreviation.toLowerCase() == bookName.toLowerCase() ||
            b.officialPluralBookAbbreviation.toLowerCase() == bookName.toLowerCase()
    );
  }

  String getVerse(int book, int chapter, int verse, {String? localeCode, String type = 'standardBookName'}) {
    return getVerses(book, chapter, verse, book, chapter, verse, type: type);
  }

  String getVerses(int book1, int chapter1, int verse1, int book2, int chapter2, int verse2, {String type = 'standardBookName'}) {
    // Récupération des infos des livres
    BibleBookName bookName1 = bibleBookNames.elementAt(book1 - 1);
    String name1 = type == 'standardBookName' ? bookName1.standardBookName : type == 'standardBookAbbreviation' ? bookName1.standardBookAbbreviation : bookName1.standardBookName;

    // Déterminer si on doit afficher le chapitre pour le livre 1
    // On ne l'affiche pas si c'est un livre à chapitre unique (isSingleChapter == true)
    bool showChapter1 = !(bookName1.isSingleChapter);

    // Formatage des chiffres
    final String formattedChapter1 = formatNumber(chapter1, format: '0');
    final String formattedChapter2 = formatNumber(chapter2, format: '0');

    String formatVerseText(int v) {
      if (v == 0) return superscriptionFullText;
      return formatNumber(v, format: '0');
    }

    String formattedVerse1Text = formatVerseText(verse1);
    String formattedVerse2Text = formatVerseText(verse2);

    // Helper pour construire la partie "Chapitre:Verset" ou juste "Verset"
    String buildRef(bool showChap, String chap, String verse) {
      return showChap ? '$chap$chapterVerseSeparator$verse' : verse;
    }

    // CAS 1 : Livres différents
    if (book1 != book2) {
      BibleBookName bookName2 = bibleBookNames.elementAt(book2 - 1);
      String name2 = type == 'standardBookName' ? bookName2.standardBookName : type == 'standardBookAbbreviation' ? bookName2.standardBookAbbreviation : bookName2.standardBookName;
      bool showChapter2 = !(bookName2.isSingleChapter);

      String ref1 = buildRef(showChapter1, formattedChapter1, formattedVerse1Text);
      String ref2 = buildRef(showChapter2, formattedChapter2, formattedVerse2Text);

      return '$name1 $ref1 $nonConsecutiveRangeSeparator $name2 $ref2';
    }

    // CAS 2 : Même livre, chapitres différents
    else if (chapter1 != chapter2) {
      return '$name1 $formattedChapter1$chapterVerseSeparator$formattedVerse1Text $nonConsecutiveRangeSeparator $formattedChapter2$chapterVerseSeparator$formattedVerse2Text';
    }

    // CAS 3 : Même livre, même chapitre, versets différents
    else if (verse1 != verse2) {
      String refBase = showChapter1 ? '$name1 $formattedChapter1$chapterVerseSeparator$formattedVerse1Text' : '$name1 $formattedVerse1Text';

      String sep = (verse2 - verse1).abs() == 1 ? '$separator ' : rangeSeparator;
      return '$refBase$sep$formattedVerse2Text';
    }

    // CAS 4 : Tout est identique (un seul verset)
    return '$name1 ${buildRef(showChapter1, formattedChapter1, formattedVerse1Text)}';
  }

  Future<Map<String, Map<String, int>>> getBibleVerseId(int book1, int chapter1, int verse1, {int? book2, int? chapter2, int? verse2}) async {
    final File mepsFile = await getMepsUnitDatabaseFile();
    final Database db = await openReadOnlyDatabase(mepsFile.path);

    // On prépare la structure demandée
    final Map<String, Map<String, int>> bibleSegments = {
      'NWT': {'start': 0, 'end': 0},
      'NWTR': {'start': 0, 'end': 0},
    };

    final int endBook = book2 ?? book1;
    final int endChapter = chapter2 ?? chapter1;
    final int endVerse = verse2 ?? verse1;

    try {
      // On récupère uniquement le premier chapitre et le dernier chapitre de la plage
      final List<Map<String, dynamic>> rangeData = await db.rawQuery("""
      SELECT 
        bi.Name, br.BookNumber, br.ChapterNumber, br.FirstBibleVerseId, br.FirstOrdinal,
        (SELECT COUNT(*) FROM BibleSuperscriptionLocation bsl 
         WHERE bsl.BookNumber = br.BookNumber AND bsl.ChapterNumber = br.ChapterNumber) as HasSup
      FROM BibleRange br
      INNER JOIN BibleInfo bi ON br.BibleInfoId = bi.BibleInfoId
      WHERE bi.Name IN ('NWTR', 'NWT') 
      AND ((br.BookNumber = ? AND br.ChapterNumber = ?) OR (br.BookNumber = ? AND br.ChapterNumber = ?))
    """, [book1, chapter1, endBook, endChapter]);

      for (var type in ['NWT', 'NWTR']) {
        final typeChapters = rangeData.where((e) => e['Name'] == type).toList();
        if (typeChapters.isEmpty) continue;

        // On trouve le chapitre de départ et celui de fin dans les résultats
        final startData = typeChapters.firstWhere((e) => e['BookNumber'] == book1 && e['ChapterNumber'] == chapter1);
        final endData = typeChapters.firstWhere((e) => e['BookNumber'] == endBook && e['ChapterNumber'] == endChapter);

        // Calcul ID de début
        int startId = startData['FirstBibleVerseId'] + (verse1 - startData['FirstOrdinal']);
        if (startData['HasSup'] > 0 && verse1 != 0) startId++;

        // Calcul ID de fin
        int endId = endData['FirstBibleVerseId'] + (endVerse - endData['FirstOrdinal']);
        if (endData['HasSup'] > 0 && endVerse != 0) endId++;

        bibleSegments[type] = {
          'start': startId,
          'end': endId,
        };
      }
    } finally {
      await db.close();
    }

    return bibleSegments;
  }
}

class BibleBookName {
  final int bookNumber;
  final String standardBookName;
  final String standardBookAbbreviation;
  final String officialBookAbbreviation;
  final String standardSingularBookName;
  final String standardSingularBookAbbreviation;
  final String officialSingularBookAbbreviation;
  final String standardPluralBookName;
  final String standardPluralBookAbbreviation;
  final String officialPluralBookAbbreviation;
  final bool isSingleChapter;
  final bool hasSuperscriptions;

  BibleBookName({
    required this.bookNumber,
    required this.standardBookName,
    required this.standardBookAbbreviation,
    required this.officialBookAbbreviation,
    required this.standardSingularBookName,
    required this.standardSingularBookAbbreviation,
    required this.officialSingularBookAbbreviation,
    required this.standardPluralBookName,
    required this.standardPluralBookAbbreviation,
    required this.officialPluralBookAbbreviation,
    required this.isSingleChapter,
    required this.hasSuperscriptions,
  });

  // Méthode pour désérialiser un BibleBookName à partir du JSON
  factory BibleBookName.fromJson(Map<String, dynamic> json) {
    return BibleBookName(
      bookNumber: json['BookNumber'],
      standardBookName: json['StandardBookName'],
      standardBookAbbreviation: json['StandardBookAbbreviation'],
      officialBookAbbreviation: json['OfficialBookAbbreviation'],
      standardSingularBookName: json['StandardSingularBookName'],
      standardSingularBookAbbreviation: json['StandardSingularBookAbbreviation'],
      officialSingularBookAbbreviation: json['OfficialSingularBookAbbreviation'],
      standardPluralBookName: json['StandardPluralBookName'],
      standardPluralBookAbbreviation: json['StandardPluralBookAbbreviation'],
      officialPluralBookAbbreviation: json['OfficialPluralBookAbbreviation'],
      isSingleChapter: json['IsSingleChapter'] == 1,
      hasSuperscriptions: json['HasSuperscriptions'] == 1
    );
  }
}
