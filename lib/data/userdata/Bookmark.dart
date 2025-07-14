class Bookmark {
  final int slot;
  final String title;
  final String snippet;
  final int blockType;
  final int? blockIdentifier;
  final int? bookNumber;
  final int? chapterNumber;
  final int? mepsDocumentId;

  Bookmark({
    required this.slot,
    required this.title,
    required this.snippet,
    required this.blockType,
    this.blockIdentifier,
    this.bookNumber,
    this.chapterNumber,
    this.mepsDocumentId,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      slot: map['Slot'] ?? 0,
      title: map['Title'] ?? '',
      snippet: map['Snippet'] ?? '',
      blockType: map['BlockType'] ?? 1,
      blockIdentifier: map['BlockIdentifier'],
      bookNumber: map['BookNumber'],
      chapterNumber: map['ChapterNumber'],
      mepsDocumentId: map['DocumentId'],
    );
  }
}
