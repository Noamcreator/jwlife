import 'dart:io';

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
    return bibleBookNames.firstWhere(
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

  String getVerse(int book, int chapter, int verse, {String? localeCode, bool isAbbreviation = false}) {
    return getVerses(book, chapter, verse, book, chapter, verse, isAbbreviation: isAbbreviation, localeCode: localeCode);
  }

  String getVerses(int book1, int chapter1, int verse1, int book2, int chapter2, int verse2, {String? localeCode, bool isAbbreviation = false}) {
    // Formatage des chiffres pour la locale (format '0' pour les entiers)
    final String formattedChapter1 = formatNumber(chapter1, format: '0', localeCode: localeCode);
    final String formattedChapter2 = formatNumber(chapter2, format: '0', localeCode: localeCode);

    // Formatage du verset 1 (sauf s'il est égal à 0)
    String formattedVerse1Text;
    if (verse1 == 0) {
      formattedVerse1Text = superscriptionFullText;
    } else {
      formattedVerse1Text = formatNumber(verse1, format: '0', localeCode: localeCode);
    }

    // Formatage du verset 2 (sauf s'il est égal à 0)
    String formattedVerse2Text;
    if (verse2 == 0) {
      formattedVerse2Text = superscriptionFullText;
    } else {
      formattedVerse2Text = formatNumber(verse2, format: '0', localeCode: localeCode);
    }

    BibleBookName bookName = bibleBookNames.elementAt(book1 - 1);
    String bibleBookName = isAbbreviation ? bookName.officialBookAbbreviation : bookName.standardBookName;

    // CAS 1 : Livres différents
    if (book1 != book2) {
      BibleBookName bookName2 = bibleBookNames.elementAt(book2 - 1);
      String bibleBookName2 = isAbbreviation ? bookName2.officialBookAbbreviation : bookName2.standardBookName;

      return '$bibleBookName $formattedChapter1$chapterVerseSeparator$formattedVerse1Text $nonConsecutiveRangeSeparator $bibleBookName2 $formattedChapter2$chapterVerseSeparator$formattedVerse2Text';
    }

    // CAS 2 : Même livre, chapitres différents
    else if (chapter1 != chapter2) {
      return '$bibleBookName $formattedChapter1$chapterVerseSeparator$formattedVerse1Text $nonConsecutiveRangeSeparator $formattedChapter2$chapterVerseSeparator$formattedVerse2Text';
    }

    // CAS 3 : Même livre, même chapitre, versets différents
    else if (verse1 != verse2) {
      if ((verse2 - verse1).abs() == 1) {
        return '$bibleBookName $formattedChapter1$chapterVerseSeparator$formattedVerse1Text$separator $formattedVerse2Text';
      }
      // Si l'écart est supérieur à 1 (ex: 20-25)
      return '$bibleBookName $formattedChapter1$chapterVerseSeparator$formattedVerse1Text$rangeSeparator$formattedVerse2Text';
    }

    // CAS 4 : Tout est identique (un seul verset)
    return '$bibleBookName $formattedChapter1$chapterVerseSeparator$formattedVerse1Text';
  }

  Future<int?> getBibleVerseId(int book, int chapter, int verse) async {
    File mepsFile = await getMepsUnitDatabaseFile();

    try {
      Database db = await openReadOnlyDatabase(mepsFile.path);
      List<Map<String, dynamic>> result = await db.rawQuery("""
      SELECT 
        FirstBibleVerseId + (? - 1) +
        CASE 
          WHEN EXISTS (
            SELECT 1 FROM BibleSuperscriptionLocation
            WHERE BookNumber = ? AND ChapterNumber = ?
          ) AND ? > 1 THEN 1 ELSE 0
        END AS VerseId
      FROM BibleRange
      INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
      WHERE BibleInfo.Name = ? AND BookNumber = ? AND ChapterNumber = ?;
      """, [verse, book, chapter, verse, 'NWTR', book, chapter]);

      return result.first['VerseId'] as int;
    }
    catch (e) {
      print('Error opening database: $e');
    }
    return null;
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
    );
  }
}
