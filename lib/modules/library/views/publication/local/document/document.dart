import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/modules/library/views/publication/local/document/multimedia.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

class Document {
  Database database;
  Publication publication;
  int documentId;
  int mepsDocumentId;
  int mepsLanguageId;
  String classType;
  int type;
  int? sectionNumber;
  int? chapterNumber;
  String title;
  String displayTitle;
  String? titleRich;
  String tocTitle;
  String? tocTitleRich;
  String? contextTitle;
  String? contextTitleRich;
  String? featureTitle;
  String? featureTitleRich;
  String? subtitle;
  String? subtitleRich;
  String? featureSubtitle;
  String? featureSubtitleRich;
  Uint8List? content;
  String htmlContent;
  int? firstFootnoteId;
  int? lastFootnoteId;
  int? firstBibleCitationId;
  int? lastBibleCitationId;
  int paragraphCount;
  bool hasMediaLinks;
  bool hasLinks;
  int? firstPageNumber;
  int? lastPageNumber;
  int contentLength;
  String? preferredPresentation;
  String? contentReworkedDate;
  bool hasPrononciationGuide;

  /* Bible fields */
  int? bookNumber;
  int? chapterNumberBible;
  Uint8List? chapterContent;
  Uint8List? preContent;
  Uint8List? postContent;
  int? firstVerseId;
  int? lastVerseId;

  List<Multimedia> multimedias;
  List<Map<String, dynamic>> svgs = [];
  List<Map<String, dynamic>> inputFields = [];
  List<Map<String, dynamic>> highlights = [];
  List<Map<String, dynamic>> bookmarks = [];

  int scrollPosition = 0;

  bool hasAlreadyBeenRead = false;

  Document({
    required this.database,
    required this.publication,
    required this.documentId,
    required this.mepsDocumentId,
    required this.mepsLanguageId,
    this.classType = '0',
    this.type = 0,
    this.sectionNumber,
    this.chapterNumber,
    this.title = '',
    this.displayTitle = '',
    this.titleRich,
    this.tocTitle = '',
    this.tocTitleRich,
    this.contextTitle,
    this.contextTitleRich,
    this.featureTitle,
    this.featureTitleRich,
    this.subtitle,
    this.subtitleRich,
    this.featureSubtitle,
    this.featureSubtitleRich,
    this.content,
    this.htmlContent = '',
    this.firstFootnoteId,
    this.lastFootnoteId,
    this.firstBibleCitationId,
    this.lastBibleCitationId,
    this.paragraphCount = 0,
    this.hasMediaLinks = false,
    this.hasLinks = false,
    this.firstPageNumber,
    this.lastPageNumber,
    this.contentLength = 0,
    this.preferredPresentation,
    this.contentReworkedDate,
    this.hasPrononciationGuide = false,
    this.multimedias = const [],
    this.bookNumber,
    this.chapterNumberBible,
    this.chapterContent,
    this.preContent,
    this.postContent,
    this.firstVerseId,
    this.lastVerseId,
  });

  factory Document.fromMap(Database database, Publication publication, Map<String, dynamic> map) {
    return Document(
      database: database,
      publication: publication,
      documentId: map['DocumentId'] ?? 0,
      mepsDocumentId: map['MepsDocumentId'] ?? 0,
      mepsLanguageId: map['MepsLanguageIndex'] ?? 0,
      classType: map['Class'] ?? '0',
      type: map['Type'] ?? 0,
      sectionNumber: map['SectionNumber'],
      chapterNumber: map['ChapterNumber'],
      title: map['Title'],
      displayTitle: map['DisplayTitle'] ?? '',
      titleRich: map['TitleRich'],
      tocTitle: map['TocTitle'],
      tocTitleRich: map['TocTitleRich'],
      contextTitle: map['ContextTitle'],
      contextTitleRich: map['ContextTitleRich'],
      featureTitle: map['FeatureTitle'],
      featureTitleRich: map['FeatureTitleRich'],
      subtitle: map['Subtitle'],
      subtitleRich: map['SubtitleRich'],
      featureSubtitle: map['FeatureSubtitle'],
      featureSubtitleRich: map['FeatureSubtitleRich'],
      content: map['Content'],
      //htmlContent: ,
      firstFootnoteId: map['FirstFootnoteId'],
      lastFootnoteId: map['LastFootnoteId'],
      firstBibleCitationId: map['FirstBibleCitationId'],
      lastBibleCitationId: map['LastBibleCitationId'],
      paragraphCount: map['ParagraphCount'] ?? 0,
      hasMediaLinks: map['HasMediaLinks'] == 1 ? true : false,
      hasLinks: map['HasLinks'] == 1 ? true : false,
      firstPageNumber: map['FirstPageNumber'],
      lastPageNumber: map['LastPageNumber'],
      contentLength: map['ContentLength'] ?? 0,
      preferredPresentation: map['PreferredPresentation'],
      contentReworkedDate: map['ContentReworkedDate'],
      hasPrononciationGuide: map['HasPrononciationGuide'] == 1 ? true : false,

      /* Bible fields */
      bookNumber: map['BookNumber'],
      chapterNumberBible: map['ChapterNumber'],
      chapterContent: map['ChapterContent'],
      preContent: map['PreContent'],
      postContent: map['PostContent'],
      firstVerseId: map['FirstVerseId'],
      lastVerseId: map['LastVerseId'],
    );
  }

  Future<void> changePageAt(DocumentsManager? documentsManager, Function loadingDatabaseFunction) async {
    if (type == 2) {
      if (!hasAlreadyBeenRead) {
        List<Uint8List>? contentBlob = await _getChapterContent();

        String decodedHtml = "";
        for(dynamic content in contentBlob!) {
          decodedHtml += decodeBlobContent(
            content,
            publication.hash,
          );
        }

        htmlContent = createHtmlContent(
            decodedHtml,
            '''jwac docClass-$classType docId-$mepsDocumentId ms-ROMAN ml-${publication.mepsLanguage.symbol} dir-ltr pub-${publication.keySymbol} layout-reading layout-sidebar''',
            publication,
            true
        );

        loadingDatabaseFunction();

        if (documentsManager != null) {
          History.insertBibleChapter("$displayTitle $chapterNumber", publication, bookNumber!, chapterNumber!);
        }
      }
      else {
        loadingDatabaseFunction();
      }
    }
    else {
      if (!hasAlreadyBeenRead) {
        htmlContent = createHtmlContent(
            decodeBlobContent(content!, publication.hash),
            '''jwac docClass-$classType docId-$mepsDocumentId ms-ROMAN ml-${publication.mepsLanguage.symbol} dir-ltr pub-${publication.keySymbol} layout-reading layout-sidebar''',
            publication,
            true
        );

        loadingDatabaseFunction();

        await fetchMedias();
        await fetchSvgs();


        if (documentsManager != null) {
          History.insertDocument(title, publication, mepsDocumentId);
        }
      }
      else {
        loadingDatabaseFunction();
      }

      await loadUserdata();
    }

    // On charge les pages de gauche et de droite
   if (documentsManager != null) {
     int index = documentsManager.documentIndex;
     if (index > 0) {
       await documentsManager.getPreviousDocument().changePageAt(null, loadingDatabaseFunction);
     }
     if (index < documentsManager.documents.length - 1) {
       await documentsManager.getNextDocument().changePageAt(null, loadingDatabaseFunction);
     }
   }

    hasAlreadyBeenRead = true;
  }

  Future<void> fetchMedias() async {
    try {
      // Récupérer les données de la base
      List<Map<String, dynamic>> response = await database.rawQuery('''
    SELECT 
    Multimedia.*
  FROM Document
  INNER JOIN DocumentMultimedia ON Document.DocumentId = DocumentMultimedia.DocumentId
  INNER JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
  WHERE Document.DocumentId = ? AND (Multimedia.CategoryType = 8 OR Multimedia.CategoryType = 15 OR Multimedia.CategoryType = 26 OR Multimedia.MimeType = 'video/mp4');
    ''', [documentId]);

      multimedias = response.map((e) => Multimedia.fromMap(e)).toList();
    }
    catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchSvgs() async {
    try {
      // Récupérer les données de la base
      List<Map<String, dynamic>> response = await database.rawQuery('''
  SELECT Multimedia.*
  FROM Document
  INNER JOIN DocumentMultimedia ON Document.DocumentId = DocumentMultimedia.DocumentId
  INNER JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
  WHERE Document.DocumentId = ? AND Multimedia.MimeType = 'image/svg+xml'
''', [documentId]);

      svgs = response;
    }
    catch (e) {
      print('Error: $e');
    }
  }

  Future<void> loadUserdata() async {
    inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(mepsDocumentId, mepsLanguageId);
    highlights = await JwLifeApp.userdata.getHighlightsFromDocId(mepsDocumentId, mepsLanguageId);
    bookmarks = await JwLifeApp.userdata.getBookmarksFromDocId(mepsDocumentId, mepsLanguageId);
  }

  Future<WebResourceResponse?> getImagePathFromDatabase(String url) async {
    // Mettre l'URL en minuscule
    List<Map<String, dynamic>> result = await database.rawQuery(
        'SELECT FilePath, MimeType FROM Multimedia WHERE LOWER(FilePath) = ?', [url]
    );

    // Si une correspondance est trouvée, retourne le chemin
    if (result.isNotEmpty) {
      final imageData = await File('${publication.path}/${result.first['FilePath']}').readAsBytes();
      final mimeType = result.first['MimeType'];
      return WebResourceResponse(
        contentType: mimeType,
        data: imageData,
      );
    }
    return null;
  }

  Future<List<Uint8List>?> _getChapterContent() async {
    List<Uint8List> content = [];

    void addToContent(dynamic data) {
      if (data != null) {
        content.add(data);
      }
    }

    addToContent(preContent);
    addToContent(chapterContent);
    addToContent(postContent);

    return content;
  }

  void share({String? paragraphId}) {
    // Créer une base d'URL pour la publication.
    final baseUrl = 'https://www.jw.org/finder';

    // Ajouter les paramètres de la requête en utilisant une méthode sûre.
    final url = Uri.parse(baseUrl).replace(queryParameters: {
      'srcid': 'jwlshare',
      'wtlocale': publication.mepsLanguage.symbol,
      'prefer': 'lang',
      'docid': mepsDocumentId.toString(),
      if (paragraphId != null) 'par': paragraphId, // Inclure le paragraphe si défini
    }).toString();

    // Partager le lien construit.
    Share.share(url);
  }
}
