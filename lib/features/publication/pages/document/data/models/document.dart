import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../../core/utils/utils.dart';
import 'multimedia.dart';

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
  List<Map<String, dynamic>> highlights = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> inputFields = [];
  List<Map<String, dynamic>> bookmarks = [];

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

  Future<void> changePageAt() async {
    if (isBibleChapter()) {
      History.insertBibleChapter("$displayTitle $chapterNumber", publication, bookNumber!, chapterNumber!);
    }
    else {
      if (!hasAlreadyBeenRead) {
        await Future.wait([
          fetchMedias(),
          fetchSvgs(),
        ]);
      }
      History.insertDocument(title, publication, mepsDocumentId);
    }

    if(!hasAlreadyBeenRead) {
      await loadUserdata();
    }

    /*
    // On charge les pages de gauche et de droite
   if (documentsManager != null) {
     int index = documentsManager.documentIndex;
     if (index > 0) {
       await documentsManager.getPreviousDocument().changePageAt(null);
     }
     if (index < documentsManager.documents.length - 1) {
       await documentsManager.getNextDocument().changePageAt(null);
     }
   }

     */

    hasAlreadyBeenRead = true;
  }

  Future<void> fetchMedias() async {
    try {
      // Récupérer les données de la base
      List<Map<String, dynamic>> response = await database.rawQuery('''
            SELECT DISTINCT m.*, dm.BeginParagraphOrdinal, dm.EndParagraphOrdinal
            FROM Multimedia m
            JOIN DocumentMultimedia dm ON dm.MultimediaId = m.MultimediaId
            WHERE m.MimeType IN ('image/jpeg', 'video/mp4')
              AND m.CategoryType != 25
              AND dm.DocumentId = ?
              AND (dm.BeginParagraphOrdinal IS NOT NULL
                   OR dm.EndParagraphOrdinal IS NOT NULL);
      ''', [documentId]);

      List<Multimedia> medias = response.map((e) => Multimedia.fromMap(e)).toList();
      medias.sort((a, b) => a.beginParagraphOrdinal.compareTo(b.beginParagraphOrdinal));
      multimedias = medias;
    }
    catch (e) {
      printTime('Error: $e');
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
      printTime('Error: $e');
    }
  }

  Future<void> loadUserdata() async {
    List<List<Map<String, dynamic>>> results;
    if(isBibleChapter()) {
      results = await Future.wait([
        JwLifeApp.userdata.getHighlightsFromChapterNumber(bookNumber!, chapterNumberBible!, mepsLanguageId),
        JwLifeApp.userdata.getNotesFromChapterNumber(bookNumber!, chapterNumberBible!, mepsLanguageId),
        JwLifeApp.userdata.getBookmarksFromChapterNumber(bookNumber!, chapterNumberBible!, mepsLanguageId),
      ]);

      highlights = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
      notes = results[1].map((item) => Map<String, dynamic>.from(item)).toList();
      bookmarks = results[2].map((item) => Map<String, dynamic>.from(item)).toList();
    }
    else {
      results = await Future.wait([
        JwLifeApp.userdata.getHighlightsFromDocId(mepsDocumentId, mepsLanguageId),
        JwLifeApp.userdata.getNotesFromDocId(mepsDocumentId, mepsLanguageId),
        JwLifeApp.userdata.getInputFieldsFromDocId(mepsDocumentId, mepsLanguageId),
        JwLifeApp.userdata.getBookmarksFromDocId(mepsDocumentId, mepsLanguageId),
      ]);

      highlights = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
      notes = results[1].map((item) => Map<String, dynamic>.from(item)).toList();
      inputFields = results[2].map((item) => Map<String, dynamic>.from(item)).toList();
      bookmarks = results[3].map((item) => Map<String, dynamic>.from(item)).toList();
    }
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

  List<Uint8List> getChapterContent() {
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

  void share(bool isBible, {String? id}) {
    // Base de l'URL
    final baseUrl = 'https://www.jw.org/finder';

    late Uri uri;

    if (isBible) {
      // Vérifie que les propriétés nécessaires sont bien définies
      if (bookNumber == null || chapterNumberBible == null) {
        throw Exception('bookNumber et chapterNumberBible doivent être définis.');
      }

      final int bookNum = bookNumber!;
      final int chapterNum = chapterNumberBible!;
      final int verseNum = id != null ? int.tryParse(id) ?? 0 : 0;

      final String chapterStr = chapterNum.toString().padLeft(3, '0');
      final String verseStr = verseNum.toString().padLeft(3, '0');
      final String bookStr = bookNum.toString().padLeft(2, '0');

      final String bibleParam = id != null
          ? '$bookNum$chapterStr$verseStr'
          : '$bookStr${chapterStr}000-$bookStr${chapterStr}999';

      uri = Uri.parse(baseUrl).replace(queryParameters: {
        'srcid': 'jwlshare',
        'wtlocale': publication.mepsLanguage.symbol,
        'prefer': 'lang',
        'bible': bibleParam,
        'pub': publication.keySymbol,
      });
    }
    else {
      uri = Uri.parse(baseUrl).replace(queryParameters: {
        'srcid': 'jwlshare',
        'wtlocale': publication.mepsLanguage.symbol,
        'prefer': 'lang',
        'docid': mepsDocumentId.toString(),
        if (id != null) 'par': id,
      });
    }

    SharePlus.instance.share(
      ShareParams(
        title: title,
        uri: uri,
      ),
    );
  }


  bool isBibleChapter() {
    return bookNumber != null && chapterNumberBible != null;
  }

  void addBookmark(Bookmark bookmark) {
    bookmarks.add({
      'Slot': bookmark.slot,
      'BlockType': bookmark.blockType,
      'BlockIdentifier': bookmark.blockIdentifier
    });
  }

  void removeBookmark(Bookmark bookmark) {
    bookmarks.removeWhere((item) =>
    item['Slot'] == bookmark.slot &&
        item['BlockType'] == bookmark.blockType &&
        item['BlockIdentifier'] == bookmark.blockIdentifier
    );
  }

  void addHighlights(List<dynamic> highlightsParagraphs, int color, String uuid) {
    for(dynamic highlight in highlightsParagraphs) {
      highlights.add({
        'UserMarkGuid': uuid,
        'ColorIndex': color,
        'BlockType': highlight['blockType'],
        'Identifier': int.parse(highlight['identifier'].toString()),
        'StartToken': highlight['startToken'],
        'EndToken': highlight['endToken']
      });
    }

    JwLifeApp.userdata.addHighlightToDoc(publication, this, highlightsParagraphs, color, uuid);
  }


  void removeHighlight(String uuid) {
    highlights.removeWhere((highlight) => highlight['UserMarkGuid'] == uuid);
    JwLifeApp.userdata.removeHighlightWithGuid(uuid);
  }

  void changeHighlightColor(String uuid, int color) {
    highlights.where((highlight) => highlight['UserMarkGuid'] == uuid).forEach((highlight) {
      highlight['ColorIndex'] = color;
    });

    JwLifeApp.userdata.changeColorHighlightWithGuid(uuid, color);
  }

  void addNoteWithUserMarkGuid(int blockType, int identifier, String title, String uuid, String? userMarkGuid, int colorIndex) {
    notes.add({
      'Guid': uuid,
      'Title': title,
      'Content': '',
      'BlockType': blockType,
      'BlockIdentifier': identifier,
      'UserMarkGuid': userMarkGuid,
      'ColorIndex': colorIndex
    });
    JwLifeApp.userdata.addNoteToDocId(this, blockType, identifier, title, uuid, userMarkGuid);
  }

  void removeNote(String guid) {
    notes.removeWhere((note) => note['Guid'] == guid);
    JwLifeApp.userdata.removeNoteWithGuid(guid);
  }


  void updateNote(String uuid, String title, String content) {
    notes.where((note) => note['Guid'] == uuid).forEach((note) {
      note['Title'] = title;
      note['Content'] = content;
    });

    JwLifeApp.userdata.updateNoteWithGuid(uuid, title, content);
  }

  void addTagToNote(String uuid, int tagId) {
    notes.where((note) => note['Guid'] == uuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = '${note['TagsId']},$tagId' : note['TagsId'] = '$tagId' : note['TagsId'] = '$tagId';
    });

    JwLifeApp.userdata.addTagToNoteWithGuid(uuid, tagId);
  }

  void removeTagToNote(String uuid, int tagId) {
    notes.where((note) => note['Guid'] == uuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = note['TagsId'].toString().replaceAll('$tagId', '') : note['TagsId'] = '' : note['TagsId'] = '';
    });

    JwLifeApp.userdata.removeTagFromNoteWithGuid(uuid, tagId);
  }

  void updateOrInsertInputFieldValue(String tag, String value) {
    bool updated = false;

    for (var field in inputFields) {
      if (field['TextTag'] == tag) {
        field['Value'] = value;
        updated = true;
        break;
      }
    }

    if (!updated) {
      inputFields.add({'TextTag': tag, 'Value': value});
    }

    JwLifeApp.userdata.updateOrInsertInputField(this, tag, value);
  }
}
