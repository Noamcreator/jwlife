import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/files_helper.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../models/audio.dart';
import '../models/publication.dart';

class History {
  static Future<void> createDbHistory(Database db) async {
    return await db.transaction((txn) async {
      await txn.execute("""
      CREATE TABLE IF NOT EXISTS "History" (
        "HistoryId" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "BookNumber" INTEGER,
        "ChapterNumber" INTEGER,
        "DocumentId" INTEGER,
        "StartBlockIdentifier" INTEGER,
        "EndBlockIdentifier" INTEGER,
        "Track" INTEGER,
        "IssueTagNumber" INTEGER DEFAULT 0,
        "KeySymbol" TEXT,
        "MepsLanguageId" INTEGER,
        "DisplayTitle" TEXT,
        "Type" TEXT,
        "NavigationBottomBarIndex" INTEGER DEFAULT 0,
        "ScrollPosition" INTEGER DEFAULT 0,
        "VisitCount" INTEGER DEFAULT 1,
        "LastVisited" TEXT DEFAULT CURRENT_TIMESTAMP
      );
      """);
    });
  }

  static Future<Database> getHistoryDb() async {
    File historyFile = await getHistoryDatabaseFile();
    return await openDatabase(historyFile.path);
  }

  static Future<void> deleteAllHistory() async {
    final db = await getHistoryDb();
    await db.delete("History");
    await db.close();
  }

  static Future<List<Map<String, dynamic>>> loadAllHistory(int? bottomBarIndex) async {
    final catalogFile = await getCatalogDatabaseFile();
    final db = await getHistoryDb();

    await attachDatabases(db, {'catalog': catalogFile.path});

    // Initialise la clause WHERE vide
    String whereClause = '';
    if (bottomBarIndex != null) {
      whereClause = 'WHERE NavigationBottomBarIndex = $bottomBarIndex';
    }

    final result = await db.rawQuery('''
      SELECT 
        History.*,
        catalog.Publication.ShortTitle AS PublicationTitle,
        catalog.Publication.IssueTitle AS PublicationIssueTitle,
        catalog.Publication.PublicationTypeId
      FROM History
      LEFT JOIN catalog.Publication 
        ON catalog.Publication.MepsLanguageId = History.MepsLanguageId 
        AND catalog.Publication.KeySymbol = History.KeySymbol
        AND catalog.Publication.IssueTagNumber = History.IssueTagNumber
      $whereClause
      ORDER BY LastVisited DESC
    ''');

    await detachDatabases(db, ['catalog']);
    await db.close();

    return result;
  }

  static Future<void> insertDocument(String displayTitle, Publication pub, int docId, int? startParagraphId, int? endParagraphId) async {
    final db = await getHistoryDb();

    List<Map<String, dynamic>> existing = await db.query(
      "History",
      where: "DocumentId = ? AND Type = ?",
      whereArgs: [docId, "document"],
    );

    if (existing.isNotEmpty) {
      await db.update(
        "History",
        {
          "DisplayTitle": displayTitle,
          "StartBlockIdentifier": startParagraphId,
          "EndBlockIdentifier": endParagraphId,
          "VisitCount": (existing.first["VisitCount"] ?? 0) + 1,
          "LastVisited": DateTime.now().toUtc().toIso8601String(),
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
          "ScrollPosition": 0
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await db.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": docId,
        "StartBlockIdentifier": startParagraphId,
        "EndBlockIdentifier": endParagraphId,
        "KeySymbol": pub.keySymbol,
        "IssueTagNumber": pub.issueTagNumber,
        "MepsLanguageId": pub.mepsLanguage.id,
        "Type": "document",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        "ScrollPosition": 0,
        "LastVisited": DateTime.now().toUtc().toIso8601String()
      });
    }

    await db.close();
  }

  static Future<void> insertBibleChapter(String displayTitle, Publication bible, int bibleBook, int bibleChapter, int? startVerse, int? endVerse) async {
    final db = await getHistoryDb();

    List<Map<String, dynamic>> existing = await db.query(
      "History",
      where: "KeySymbol = ? AND BookNumber = ? AND ChapterNumber = ? AND Type = ?",
      whereArgs: [bible.keySymbol, bibleBook, bibleChapter, "chapter"],
    );

    String lastDisplayTitle = startVerse == null && endVerse == null ? "$displayTitle $bibleChapter" : JwLifeApp.bibleCluesInfo.getVerses(bibleBook, bibleChapter, startVerse ?? 0, bibleBook, bibleChapter, endVerse ?? 0);

    if (existing.isNotEmpty) {
      await db.update(
        "History",
        {
          "DisplayTitle": lastDisplayTitle,
          "StartBlockIdentifier": startVerse,
          "EndBlockIdentifier": endVerse,
          "VisitCount": (existing.first["VisitCount"] ?? 0) + 1,
          "LastVisited": DateTime.now().toUtc().toIso8601String(),
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
          "ScrollPosition": 0
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await db.insert("History", {
        "DisplayTitle": lastDisplayTitle,
        "BookNumber": bibleBook,
        "ChapterNumber": bibleChapter,
        "StartBlockIdentifier": startVerse,
        "EndBlockIdentifier": endVerse,
        "KeySymbol": bible.keySymbol,
        "MepsLanguageId": bible.mepsLanguage.id,
        "Type": "chapter",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        "ScrollPosition": 0,
        "LastVisited": DateTime.now().toUtc().toIso8601String()
      });
    }

    await db.close();
  }

  static Future<void> insertVideo(MediaItem mediaItem) async {
    final db = await getHistoryDb();

    String? keySymbol = mediaItem.pubSymbol;
    int? track = mediaItem.track;
    int? documentId = mediaItem.documentId;
    int? issueTagNumber = mediaItem.issueDate;
    String? displayTitle = mediaItem.title;
    int mepsLanguageId = JwLifeSettings().currentLanguage.id;

    String whereClause = "Type = ?";
    List<dynamic> whereArgs = ["video"];

    if (keySymbol != null) {
      whereClause += " AND KeySymbol = ?";
      whereArgs.add(keySymbol);
    }

    if (track != null) {
      whereClause += " AND Track = ?";
      whereArgs.add(track);
    }

    if (documentId != null) {
      whereClause += " AND DocumentId = ?";
      whereArgs.add(documentId);
    }

    if (issueTagNumber != null) {
      whereClause += " AND IssueTagNumber = ?";
      whereArgs.add(issueTagNumber);
    }

    List<Map<String, dynamic>> existing = await db.query(
      "History",
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (existing.isNotEmpty) {
      await db.update(
        "History",
        {
          "VisitCount": (existing.first["VisitCount"] ?? 0) + 1,
          "LastVisited": DateTime.now().toUtc().toIso8601String(),
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await db.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": documentId,
        "KeySymbol": keySymbol,
        "Track": track,
        "IssueTagNumber": issueTagNumber ?? 0,
        "MepsLanguageId": mepsLanguageId,
        "Type": "video",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        "LastVisited": DateTime.now().toUtc().toIso8601String()
      });
    }

    await db.close();
  }

  static Future<void> insertAudioMediaItem(MediaItem mediaItem) async {
    final db = await getHistoryDb();

    String? keySymbol = mediaItem.pubSymbol;
    int? track = mediaItem.track;
    int? documentId = mediaItem.documentId;
    int? issueTagNumber = mediaItem.issueDate;
    String? displayTitle = mediaItem.title;
    int mepsLanguageId = JwLifeSettings().currentLanguage.id;

    String whereClause = "Type = ?";
    List<dynamic> whereArgs = ["audio"];

    if (keySymbol != null) {
      whereClause += " AND KeySymbol = ?";
      whereArgs.add(keySymbol);
    }

    if (track != null) {
      whereClause += " AND Track = ?";
      whereArgs.add(track);
    }

    if (documentId != null) {
      whereClause += " AND DocumentId = ?";
      whereArgs.add(documentId);
    }

    if (issueTagNumber != null) {
      whereClause += " AND IssueTagNumber = ?";
      whereArgs.add(issueTagNumber);
    }

    List<Map<String, dynamic>> existing = await db.query(
      "History",
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (existing.isNotEmpty) {
      await db.update(
        "History",
        {
          "VisitCount": (existing.first["VisitCount"] ?? 0) + 1,
          "LastVisited": DateTime.now().toUtc().toIso8601String(),
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await db.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": documentId,
        "KeySymbol": keySymbol,
        "Track": track,
        "IssueTagNumber": issueTagNumber ?? 0,
        "MepsLanguageId": mepsLanguageId,
        "Type": "audio",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        "LastVisited": DateTime.now().toUtc().toIso8601String()
      });
    }

    await db.close();
  }

  static Future<void> insertAudio(Audio audio) async {
    final db = await getHistoryDb();

    String? keySymbol = audio.keySymbol;
    int? track = audio.track;
    int? documentId = audio.documentId;
    int? issueTagNumber = audio.issueTagNumber;
    String? displayTitle = audio.title;
    int mepsLanguageId = JwLifeSettings().currentLanguage.id;

    String whereClause = "Type = ?";
    List<dynamic> whereArgs = ["audio"];

    if (keySymbol != null) {
      whereClause += " AND KeySymbol = ?";
      whereArgs.add(keySymbol);
    }

    if (track != null) {
      whereClause += " AND Track = ?";
      whereArgs.add(track);
    }

    if (documentId != null) {
      whereClause += " AND DocumentId = ?";
      whereArgs.add(documentId);
    }

    if (issueTagNumber != null) {
      whereClause += " AND IssueTagNumber = ?";
      whereArgs.add(issueTagNumber);
    }

    List<Map<String, dynamic>> existing = await db.query(
      "History",
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (existing.isNotEmpty) {
      await db.update(
        "History",
        {
          "VisitCount": (existing.first["VisitCount"] ?? 0) + 1,
          "LastVisited": DateTime.now().toUtc().toIso8601String(),
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await db.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": documentId,
        "KeySymbol": keySymbol,
        "Track": track,
        "IssueTagNumber": issueTagNumber ?? 0,
        "MepsLanguageId": mepsLanguageId,
        "Type": "audio",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex,
        "LastVisited": DateTime.now().toUtc().toIso8601String()
      });
    }

    await db.close();
  }


  static Future<void> showHistoryDialog(BuildContext mainContext, {int? bottomBarIndex}) async {
    bool isDarkMode = Theme.of(mainContext).brightness == Brightness.dark;

    // Variables d'état
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> allHistory = await loadAllHistory(bottomBarIndex);
    List<Map<String, dynamic>> filteredHistory = List.from(allHistory);

    showDialog(
      context: mainContext,
      builder: (context) {
        // Utilisez un StatefulWidget pour gérer l'état local du dialogue.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Fonction pour filtrer l'historique et mettre à jour l'état du dialogue
            void filterHistory(String query) {
              setState(() { // <== Appel crucial pour reconstruire le widget
                if (query.isEmpty) {
                  filteredHistory = List.from(allHistory);
                } else {
                  filteredHistory = allHistory.where((element) {
                    return element["DisplayTitle"]
                        .toString()
                        .toLowerCase()
                        .contains(query.toLowerCase());
                  }).toList();
                }
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre avec séparation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "Historique",
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),

                    Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),

                    // Champ de recherche
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Rechercher...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        prefixIcon: Icon(JwIcons.magnifying_glass),
                      ),
                      onEditingComplete: () {
                        filterHistory(searchController.text);
                      },
                      onChanged: (value) {
                        filterHistory(value);
                      },
                    ),

                    Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),

                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredHistory.length, // <== Utilisez la liste filtrée ici
                        separatorBuilder: (context, index) => Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),
                        itemBuilder: (context, index) {
                          var item = filteredHistory[index];
                          IconData icon = item["Type"] == 'webview' ? item['PublicationTypeId'] != null ? PublicationCategory.all.firstWhere(
                                  (category) => category.id == item['PublicationTypeId']).icon
                              : JwIcons.document : JwIcons.document;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);

                              if (item["Type"] == "video") {
                                MediaItem? mediaItem = getMediaItem(
                                  item["KeySymbol"],
                                  item["Track"],
                                  item["DocumentId"],
                                  item["IssueTagNumber"],
                                  item["MepsLanguageId"],
                                );
                                printTime("mediaItem: ${mediaItem!.title}");

                                showFullScreenVideo(mainContext, mediaItem);
                              }
                              else if (item["Type"] == "audio") {
                                MediaItem? mediaItem = getAudioItem(
                                  item["KeySymbol"],
                                  item["Track"],
                                  item["DocumentId"],
                                  item["IssueTagNumber"],
                                  item["MepsLanguageId"],
                                );
                                showAudioPlayer(mainContext, mediaItem!);
                              }
                              else if (item["Type"] == "chapter") {
                                printTime("item: $item");
                                showChapterView(
                                  mainContext,
                                  item["KeySymbol"],
                                  item["MepsLanguageId"],
                                  item["BookNumber"],
                                  item["ChapterNumber"],
                                  firstVerseNumber: item["StartBlockIdentifier"],
                                  lastVerseNumber: item["EndBlockIdentifier"],
                                );
                              }
                              else if (item["Type"] == "document") {
                                showDocumentView(mainContext, item["DocumentId"], item["MepsLanguageId"], startParagraphId: item["StartBlockIdentifier"], endParagraphId: item["EndBlockIdentifier"]);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    item["Type"] == "video"
                                        ? JwIcons.video
                                        : item["Type"] == "audio"
                                        ? JwIcons.music
                                        : icon,
                                    color: Theme.of(context).primaryColor,
                                    size: 25,
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item["DisplayTitle"] ?? "Sans titre",
                                          style: TextStyle(fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          item["Type"] == "video"
                                              ? "Vidéo"
                                              : item["Type"] == "audio"
                                              ? "Audio"
                                              : (item["PublicationIssueTitle"] ?? item["PublicationTitle"] ?? item['KeySymbol']),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Color(0xFFc0c0c0)
                                                : Color(0xFF5a5a5a),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Séparation et boutons
                    Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => deleteAllHistory().then((value) => Navigator.pop(context)),
                          child: Text(
                            "TOUT EFFACER",
                            style: TextStyle(
                                fontFamily: 'Roboto',
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "FERMER",
                            style: TextStyle(
                                fontFamily: 'Roboto',
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}