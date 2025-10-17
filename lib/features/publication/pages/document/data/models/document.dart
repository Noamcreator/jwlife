import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/jworg_uri.dart';
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
  List<Map<String, dynamic>> blockRanges = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> inputFields = [];
  List<Map<String, dynamic>> bookmarks = [];

  List<Map<String, dynamic>> extractedNotes = [];

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

  Future<void> changePageAt(int? startBlockIdentifier, int? endBlockIdentifier) async {
    if (isBibleChapter()) {
      History.insertBibleChapter(displayTitle, publication, bookNumber!, chapterNumber!, startBlockIdentifier, endBlockIdentifier);
    }
    else {
      if (!hasAlreadyBeenRead) {
        await fetchMedias();
      }
      History.insertDocument(title, publication, mepsDocumentId, startBlockIdentifier, endBlockIdentifier);
    }

    if(!hasAlreadyBeenRead) {
      await loadUserdata();
    }
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
            AND m.CategoryType != 9
            AND dm.DocumentId = ?;
    ''', [documentId]);

      List<Multimedia> medias = response.map((e) => Multimedia.fromMap(e)).toList();

      // Modification de la fonction de tri ici
      medias.sort((a, b) {
        final aBegin = a.beginParagraphOrdinal;
        final bBegin = b.beginParagraphOrdinal;

        // 1. Gérer les nulls en premier
        if (aBegin == null && bBegin != null) {
          return -1; // 'a' vient avant 'b'
        }
        if (aBegin != null && bBegin == null) {
          return 1; // 'a' vient après 'b'
        }

        // 2. Si les deux sont null, trier par MultimediaId
        if (aBegin == null && bBegin == null) {
          // Supposant que MultimediaId est une propriété de type int ou comparable
          return a.id.compareTo(b.id);
        }

        // 3. Sinon (si les deux sont non-null), trier par BeginParagraphOrdinal
        // L'ordre par défaut est ascendant
        return aBegin!.compareTo(bBegin!);
      });

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
        JwLifeApp.userdata.getBlockRangesFromChapterNumber(bookNumber!, chapterNumberBible!, mepsLanguageId),
        JwLifeApp.userdata.getNotesFromChapterNumber(bookNumber!, chapterNumberBible!, mepsLanguageId),
        JwLifeApp.userdata.getBookmarksFromChapterNumber(bookNumber!, chapterNumberBible!),
      ]);

      blockRanges = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
      notes = results[1].map((item) => Map<String, dynamic>.from(item)).toList();
      bookmarks = results[2].map((item) => Map<String, dynamic>.from(item)).toList();
    }
    else {
      results = await Future.wait([
        JwLifeApp.userdata.getBlockRangesFromDocumentId(mepsDocumentId, mepsLanguageId),
        JwLifeApp.userdata.getNotesFromDocumentId(mepsDocumentId, mepsLanguageId),
        JwLifeApp.userdata.getInputFieldsFromDocumentId(mepsDocumentId),
        JwLifeApp.userdata.getBookmarksFromDocumentId(mepsDocumentId, mepsLanguageId),
      ]);

      blockRanges = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
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

  void share(bool isBible, {int? id}) {
    String uri;

    if (isBible) {
      // Vérifie que les propriétés nécessaires sont bien définies
      if (!isBibleChapter()) {
        throw Exception('bookNumber et chapterNumberBible doivent être définis.');
      }

      final int bookNum = bookNumber!;
      final int chapterNum = chapterNumberBible!;
      final int verseNum = id ?? 0;

      final String chapterStr = chapterNum.toString().padLeft(3, '0');
      final String verseStr = verseNum.toString().padLeft(3, '0');
      final String bookStr = bookNum.toString().padLeft(2, '0');

      final String bibleParam = id != null ? '$bookNum$chapterStr$verseStr' : '$bookStr${chapterStr}000-$bookStr${chapterStr}999';

      uri = JwOrgUri.bibleChapter(
          wtlocale: publication.mepsLanguage.symbol,
          pub: publication.keySymbol,
          bible: bibleParam
      ).toString();
    }
    else {
      uri = JwOrgUri.document(
          wtlocale: publication.mepsLanguage.symbol,
          docid: mepsDocumentId,
          par: id.toString()
      ).toString();
    }

    SharePlus.instance.share(
      ShareParams(
        title: title,
        uri: Uri.tryParse(uri),
      ),
    );
  }

  String getDisplayTitle() {
    return isBibleChapter() ? '$displayTitle $chapterNumber' : displayTitle.isNotEmpty ? displayTitle.trim() : title;
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

  Future<void> addBlockRange(List<dynamic> blockRangeParagraphs, int styleIndex, int colorIndex, String uuid) async {
    for(dynamic blockRange in blockRangeParagraphs) {
      blockRanges.add({
        'UserMarkGuid': uuid,
        'ColorIndex': colorIndex,
        'StyleIndex': styleIndex,
        'BlockType': blockRange['blockType'],
        'Identifier': int.parse(blockRange['identifier'].toString()),
        'StartToken': blockRange['startToken'],
        'EndToken': blockRange['endToken']
      });
    }

    await JwLifeApp.userdata.addBlockRangesToDocument(publication, this, blockRangeParagraphs, styleIndex, colorIndex, uuid);
  }

  Future<void> removeBlockRange(String uuid) async {
    blockRanges.removeWhere((blockRange) => blockRange['UserMarkGuid'] == uuid);
    await JwLifeApp.userdata.removeBlockRangeWithGuid(uuid);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> changeBlockRangeStyle(String uuid, int styleIndex, int colorIndex) async {
    blockRanges.where((blockRange) => blockRange['UserMarkGuid'] == uuid).forEach((blockRange) {
      blockRange['ColorIndex'] = colorIndex;
      blockRange['StyleIndex'] = styleIndex;
    });

    notes.where((note) => note['UserMarkGuid'] == uuid).forEach((note) {
      note['ColorIndex'] = colorIndex;
      note['StyleIndex'] = styleIndex;
    });

    await JwLifeApp.userdata.changeBlockRangeStyleWithGuid(uuid, styleIndex, colorIndex);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> addNoteWithUserMarkGuid(int blockType, int identifier, String title, String uuid, String? userMarkGuid, int styleIndex, int colorIndex) async {
    notes.add({
      'Guid': uuid,
      'Title': title,
      'Content': '',
      'BlockType': blockType,
      'BlockIdentifier': identifier,
      'UserMarkGuid': userMarkGuid,
      'ColorIndex': colorIndex,
      'StyleIndex': styleIndex,
    });
    await JwLifeApp.userdata.addNoteToDocId(publication, this, blockType, identifier, title, uuid, userMarkGuid);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> removeNote(String noteGuid) async {
    notes.removeWhere((note) => note['Guid'] == noteGuid);
    extractedNotes.removeWhere((note) => note['Guid'] == noteGuid);
    await JwLifeApp.userdata.removeNoteWithGuid(noteGuid);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> updateNote(String noteGuid, String title, String content) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['Title'] = title;
      note['Content'] = content;
    });

    extractedNotes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['Title'] = title;
      note['Content'] = content;
    });

    await JwLifeApp.userdata.updateNoteWithGuid(noteGuid, title, content);
  }

  Future<void> changeNoteUserMark(String noteGuid, String userMarkGuid, int styleIndex, int colorIndex) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['UserMarkGuid'] = userMarkGuid;
      note['StyleIndex'] = styleIndex;
      note['ColorIndex'] = colorIndex;
    });

    extractedNotes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['UserMarkGuid'] = userMarkGuid;
      note['StyleIndex'] = styleIndex;
      note['ColorIndex'] = colorIndex;
    });

    await JwLifeApp.userdata.changeNoteUserMark(noteGuid, userMarkGuid);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> changeNoteColor(String noteGuid, int styleIndex, int colorIndex) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['ColorIndex'] = colorIndex;
      note['StyleIndex'] = styleIndex;

      blockRanges.where((blockRange) => blockRange['UserMarkGuid'] == note['UserMarkGuid']).forEach((blockRange) {
        blockRange['ColorIndex'] = colorIndex;
        blockRange['StyleIndex'] = styleIndex;
      });
    });

    extractedNotes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['ColorIndex'] = colorIndex;
      note['StyleIndex'] = styleIndex;
    });

    await JwLifeApp.userdata.updateNoteColorWithGuid(noteGuid, colorIndex);

    // Actualiser la page des notes
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }

  Future<void> addTagToNote(String noteGuid, int tagId) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = '${note['TagsId']},$tagId' : note['TagsId'] = '$tagId' : note['TagsId'] = '$tagId';
    });

    extractedNotes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = '${note['TagsId']},$tagId' : note['TagsId'] = '$tagId' : note['TagsId'] = '$tagId';
    });

    await JwLifeApp.userdata.addTagToNoteWithGuid(noteGuid, tagId);
  }

  Future<void> removeTagToNote(String noteGuid, int tagId) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = note['TagsId'].toString().replaceAll('$tagId', '') : note['TagsId'] = '' : note['TagsId'] = '';
    });

    extractedNotes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = note['TagsId'].toString().replaceAll('$tagId', '') : note['TagsId'] = '' : note['TagsId'] = '';
    });

    await JwLifeApp.userdata.removeTagFromNoteWithGuid(noteGuid, tagId);
  }

  Future<void> updateOrInsertInputFieldValue(String tag, String value) async {
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

    await JwLifeApp.userdata.updateOrInsertInputField(this, tag, value);
  }
}
