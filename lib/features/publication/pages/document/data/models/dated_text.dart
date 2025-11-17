import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../../app/services/global_key_service.dart';
import '../../../../../../app/services/settings_service.dart';

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

  List<Map<String, dynamic>> blockRanges = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> bookmarks = [];

  List<Map<String, dynamic>> extractedNotes = [];

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
    History.insertDocument(getTitle(), publication, mepsDocumentId, null, null);
    hasAlreadyBeenRead = true;
  }

  Future<void> loadUserdata() async {
    List<List<Map<String, dynamic>>> results;
    results = await Future.wait([
      JwLifeApp.userdata.getBlockRangesFromDocumentId(mepsDocumentId, mepsLanguageId),
      JwLifeApp.userdata.getNotesFromDocumentId(mepsDocumentId, mepsLanguageId),
      JwLifeApp.userdata.getBookmarksFromDocumentId(mepsDocumentId, mepsLanguageId),
    ]);

    blockRanges = results[0].map((item) => Map<String, dynamic>.from(item)).toList();
    notes = results[1].map((item) => Map<String, dynamic>.from(item)).toList();
    bookmarks = results[2].map((item) => Map<String, dynamic>.from(item)).toList();
  }


  void share({int? id}) {
    String uri = JwOrgUri.dailyText(
        wtlocale: publication.mepsLanguage.symbol,
        date: firstDateOffset.toString()
    ).toString();

    SharePlus.instance.share(
      ShareParams(
        title: getTitle(),
        uri: Uri.tryParse(uri),
      ),
    );
  }

  String getTitle() {
    String dateString = firstDateOffset.toString();

    // Parse la date depuis le format aaaammjj
    DateTime parsedDate = DateTime.parse(dateString);

    // Formatte au format souhaité : "1 janvier 2025"
    String formattedDate = DateFormat("d MMMM y", JwLifeSettings().locale.languageCode).format(parsedDate);

    return formattedDate;
  }

  DateTime getDate() {
    return DateTime.parse(firstDateOffset.toString());
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

    await JwLifeApp.userdata.addBlockRangesToDocument(publication, null, blockRangeParagraphs, styleIndex, colorIndex, uuid, datedText: this);
  }

  Future<void> removeBlockRange(String uuid) async {
    blockRanges.removeWhere((blockRange) => blockRange['UserMarkGuid'] == uuid);
    await JwLifeApp.userdata.removeBlockRangeWithGuid(uuid);
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
    await JwLifeApp.userdata.addNoteToDocId(publication, null, blockType, identifier, title, uuid, userMarkGuid, datedText: this);

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

    await JwLifeApp.userdata.addTagToNoteWithGuid(noteGuid, tagId);
  }

  Future<void> removeTagToNote(String noteGuid, int tagId) async {
    notes.where((note) => note['Guid'] == noteGuid).forEach((note) {
      note['TagsId'] != null ? note['TagsId'] != '' ? note['TagsId'] = note['TagsId'].toString().replaceAll('$tagId', '') : note['TagsId'] = '' : note['TagsId'] = '';
    });

    await JwLifeApp.userdata.removeTagFromNoteWithGuid(noteGuid, tagId);
  }
}
