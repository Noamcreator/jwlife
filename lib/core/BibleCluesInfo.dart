class BibleCluesInfo {
  final String chapterVerseSeparator;
  final String separator;
  final String rangeSeparator;
  final String nonConsecutiveRangeSeparator;
  final List<BibleBookName> bibleBookNames;

  // Constructeur pour initialiser la liste de livres de la Bible et les séparateurs
  BibleCluesInfo({
    required this.bibleBookNames,
    this.chapterVerseSeparator = ':',
    this.separator = ',',
    this.rangeSeparator = '-',
    this.nonConsecutiveRangeSeparator = ';',
  });

  // Méthode pour désérialiser le JSON
  factory BibleCluesInfo.fromJson(Map<String, dynamic> json, List<BibleBookName> bibleBookNames) {
    return BibleCluesInfo(
      bibleBookNames: bibleBookNames,
      chapterVerseSeparator: json['ChapterVerseSeparator'] ?? ':',
      separator: json['Separator'] ?? ',',
      rangeSeparator: json['RangeSeparator'] ?? '-',
      nonConsecutiveRangeSeparator: json['NonconsecutiveChapterListSeparator'] ?? ';',
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

  String getVerse(int book, int chapter, int verse) {
    return getVerses(book, chapter, verse, book, chapter, verse);
  }

  String getVerses(int book1, int chapter1, int verse1, int book2, int chapter2, int verse2) {
    BibleBookName bookName = bibleBookNames.elementAt(book1 - 1);
    if (book1 != book2) {
      BibleBookName bookName2 = bibleBookNames.elementAt(book2 - 1);
      return '${bookName.standardBookName} $chapter1$chapterVerseSeparator$verse1 $nonConsecutiveRangeSeparator ${bookName2.standardBookName} $chapter2$chapterVerseSeparator$verse2';
    }
    else if (chapter1 != chapter2) {
      return '${bookName.standardBookName} $chapter1$chapterVerseSeparator$verse1 $nonConsecutiveRangeSeparator $chapter2$chapterVerseSeparator$verse2';
    }
    else if (verse1 != verse2) {
      if (verse1 != verse2 - 1 || verse2 != verse1 - 1) {
        return '${bookName.standardBookName} $chapter1$chapterVerseSeparator$verse1$rangeSeparator$verse2';
      }
      return '${bookName.standardBookName} $chapter1$chapterVerseSeparator$verse1 $separator $verse2';
    }
    return '${bookName.standardBookName} $chapter1$chapterVerseSeparator$verse1';
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
