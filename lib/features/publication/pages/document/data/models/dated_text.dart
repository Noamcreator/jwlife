import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../../app/services/settings_service.dart';
import '../../../../../../core/utils/utils.dart';
import 'multimedia.dart';

class DatedText {
  Database database;
  Publication publication;
  int datedTextId;
  int documentId;
  String link;
  int firstDateOffset;
  int lastDateOffset;
  int mepsDocumentId;
  int mepsLanguageId;
  String classType;
  Uint8List? content;
  String htmlContent;

  List<Map<String, dynamic>> highlights = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> bookmarks = [];

  bool hasAlreadyBeenRead = false;

  DatedText({
    required this.database,
    required this.publication,
    required this.datedTextId,
    required this.documentId,
    required this.link,
    required this.firstDateOffset,
    required this.lastDateOffset,
    required this.mepsDocumentId,
    required this.mepsLanguageId,
    this.classType = '0',
    this.content,
    this.htmlContent = '',
  });

  factory DatedText.fromMap(Database database, Publication publication, Map<String, dynamic> map) {
    return DatedText(
      database: database,
      publication: publication,
      datedTextId: map['DatedTextId'] ?? 0,
      documentId: map['DocumentId'] ?? 0,
      link: map['Link'] ?? '',
      firstDateOffset: map['FirstDateOffset'] ?? 0,
      lastDateOffset: map['LastDateOffset'] ?? 0,
      mepsDocumentId: map['MepsDocumentId'] ?? 0,
      mepsLanguageId: map['MepsLanguageIndex'] ?? 0,
      classType: map['Class'] ?? '0',
      content: map['Content'],
    );
  }

  Future<void> changePageAt() async {
    if(!hasAlreadyBeenRead) {
      await loadUserdata();
    }
    History.insertDocument(getTitle(), publication, mepsDocumentId);
    hasAlreadyBeenRead = true;
  }

  Future<void> loadUserdata() async {
    List<List<Map<String, dynamic>>> results;
    results = await Future.wait([
      JwLifeApp.userdata.getHighlightsFromDocId(mepsDocumentId, mepsLanguageId),
      JwLifeApp.userdata.getNotesFromDocId(mepsDocumentId, mepsLanguageId),
      JwLifeApp.userdata.getBookmarksFromDocId(mepsDocumentId, mepsLanguageId),
    ]);

    highlights = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
    notes = results[1].map((item) => Map<String, dynamic>.from(item)).toList();
    bookmarks = results[2].map((item) => Map<String, dynamic>.from(item)).toList();
  }


  void share({String? id}) {
    // Base de l'URL
    final baseUrl = 'https://www.jw.org/finder';

    late Uri uri;

    uri = Uri.parse(baseUrl).replace(queryParameters: {
      'srcid': 'jwlshare',
      'wtlocale': publication.mepsLanguage.symbol,
      'prefer': 'lang',
      'docid': mepsDocumentId.toString(),
      if (id != null) 'par': id,
    });

    SharePlus.instance.share(
      ShareParams(
        title: getTitle(),
        uri: uri,
      ),
    );
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

    JwLifeApp.userdata.addHighlightToDoc(publication, null, highlightsParagraphs, color, uuid, datedText: this);
  }

  String getTitle() {
    String dateString = firstDateOffset.toString();

    // Parse la date depuis le format aaaammjj
    DateTime parsedDate = DateTime.parse(dateString);

    // Formatte au format souhaité : "1 janvier 2025"
    String formattedDate = DateFormat("d MMMM y", JwLifeSettings().locale.toString()).format(parsedDate);

    return formattedDate;
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
    JwLifeApp.userdata.addNoteToDocId(publication, null, blockType, identifier, title, uuid, userMarkGuid, datedText: this);
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
}
