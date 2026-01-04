import 'package:jwlife/data/models/bible_chapter.dart';

class BibleBook {
  final int bookNumber;
  final String? bookName;
  final String? bookDisplayTitle;
  final String? imagePath;
  final String? introTitle;
  final int? introDocumentId;
  final bool hasCommentary;
  final int? firstVerseId;
  final int? lastVerseId;
  
  List<BibleChapter> chapters;
  String? overviewHtml;
  String? profileHtml;
  
  bool isLoading;
  bool isOverview;

  BibleBook({
    required this.bookNumber,
    this.bookName,
    this.bookDisplayTitle,
    this.introTitle,
    this.imagePath,
    this.introDocumentId,
    this.hasCommentary = false,
    this.firstVerseId,
    this.lastVerseId,
    this.chapters = const [],
    this.isLoading = true,
    this.isOverview = false,
  });

  factory BibleBook.fromMap(Map<String, dynamic> map) {
    return BibleBook(
      bookNumber: map['BibleBookId'] as int,
      bookName: map['BookName'] as String?,
      bookDisplayTitle: map['BookDisplayTitle'] as String?,
      introTitle: map['IntroTitle'] as String?,
      imagePath: map['FilePath'] as String?,
      introDocumentId: map['IntroMepsDocumentId'] as int?,
      hasCommentary: map['HasCommentary'] == 1,
      firstVerseId: map['FirstVerseId'] as int?,
      lastVerseId: map['LastVerseId'] as int?,
      chapters: [],
      isLoading: true,
      isOverview: false,
    );
  }
}