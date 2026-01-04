class BibleChapter {
  final int number;
  final bool isChapterExist;

  BibleChapter({
    required this.number,
    required this.isChapterExist,
  });

  factory BibleChapter.fromMap(Map<String, dynamic> map) {
    return BibleChapter(
      number: map['ChapterNumber'] as int,
      isChapterExist: (map['IsExist'] as int) == 1, 
    );
  }
}