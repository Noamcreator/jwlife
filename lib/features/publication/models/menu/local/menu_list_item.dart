class ListItem {
  final String title;
  final String mediumTitle;
  final String largeTitle;
  final String displayTitle;
  final String subTitle;
  final String imageFilePath;
  final String? dataType;
  final int mepsDocumentId;
  final bool isTitle; // Pour savoir si c'est un titre avec des sous-éléments
  final bool isBibleBooks;
  final int? groupId;
  final int? bibleBookId;
  final bool? hasCommentary;
  final bool showImage;
  final List<ListItem> subItems; // Liste des sous-éléments (si applicable)

  ListItem({
    this.title = '',
    this.mediumTitle = '',
    this.largeTitle = '',
    this.displayTitle = '',
    this.subTitle = '',
    this.imageFilePath = '',
    this.dataType,
    this.mepsDocumentId = -1,
    this.isTitle = false,
    this.isBibleBooks = false,
    this.groupId,
    this.hasCommentary,
    this.bibleBookId,
    this.showImage = true,
    this.subItems = const [],
  });
}