class Location {
  final int? bookNumber;
  final int? chapterNumber;
  final int? mepsDocumentId;
  final int? track;
  final int? issueTagNumber;
  final String? keySymbol;
  final int? mepsLanguageId;
  final int type;
  final String? title;

  Location({
    this.bookNumber,
    this.chapterNumber,
    this.mepsDocumentId,
    this.track,
    this.issueTagNumber = 0,
    this.keySymbol,
    this.mepsLanguageId,
    required this.type,
    this.title,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      bookNumber: map['BookNumber'],
      chapterNumber: map['ChapterNumber'],
      mepsDocumentId: map['DocumentId'],
      track: map['Track'],
      issueTagNumber: map['IssueTagNumber'],
      keySymbol: map['KeySymbol'],
      mepsLanguageId: map['MepsLanguage'],
      type: map['Type'] ?? 0,
      title: map['Title'],
    );
  }
}
