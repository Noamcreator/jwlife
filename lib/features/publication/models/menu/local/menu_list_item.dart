class ListItem {
  final String title;
  final String mediumTitle;
  final String largeTitle;
  final String displayTitle;
  final String subTitle;
  final String imageFilePath;
  final String description;
  final String? dataType;
  final int mepsDocumentId;
  final bool isTitle;
  final bool isBibleBooks;
  final int? groupId;
  final int? bibleBookNumber;
  final bool? hasCommentary;
  final bool showImage;
  final bool isBookExist;
  final List<ListItem> subItems;

  ListItem({
    this.title = '',
    this.mediumTitle = '',
    this.largeTitle = '',
    this.displayTitle = '',
    this.subTitle = '',
    this.imageFilePath = '',
    this.description = '',
    this.dataType,
    this.mepsDocumentId = -1,
    this.isTitle = false,
    this.isBibleBooks = false,
    this.groupId,
    this.hasCommentary,
    this.bibleBookNumber,
    this.showImage = true,
    this.isBookExist = false,
    this.subItems = const [],
  });
}