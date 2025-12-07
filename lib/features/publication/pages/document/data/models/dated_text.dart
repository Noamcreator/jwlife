import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../../app/services/global_key_service.dart';
import '../../../../../../app/services/settings_service.dart';
import '../../../../../../data/controller/block_ranges_controller.dart';
import '../../../../../../data/models/userdata/block_range.dart';

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

  List<Map<String, dynamic>> blockRanges = [];
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
    List<dynamic> results;
    final context = GlobalKeyService.jwLifePageKey.currentContext!;

    List<BlockRange> blockRanges = context.read<BlockRangesController>().blockRanges;

    results = await Future.wait([
      JwLifeApp.userdata.getBlockRangesFromDocumentId(mepsDocumentId, mepsLanguageId),
      JwLifeApp.userdata.getBookmarksFromDocumentId(mepsDocumentId, mepsLanguageId),
    ]);

    blockRanges = results[0];
    bookmarks = results[1];

    context.read<BlockRangesController>().loadBlockRanges(blockRanges);
  }

  String share({int? id, hide = false}) {
    String uri = JwOrgUri.dailyText(
        wtlocale: publication.mepsLanguage.symbol,
        date: firstDateOffset.toString()
    ).toString();

    if(!hide) {
      SharePlus.instance.share(
        ShareParams(
          title: getTitle(),
          uri: Uri.tryParse(uri),
        ),
      );
    }

    return uri;
  }

  String getTitle() {
    String dateString = firstDateOffset.toString();

    // Parse la date depuis le format aaaammjj
    DateTime parsedDate = DateTime.parse(dateString);

    // Formatte au format souhaité : "1 janvier 2025"
    String formattedDate = DateFormat("d MMMM y", JwLifeSettings.instance.locale.languageCode).format(parsedDate);

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
}
