import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/files_helper.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../../i18n/i18n.dart';
import '../models/audio.dart';
import '../models/media.dart';
import '../models/publication.dart';

class History {
  late Database _database;

  Future<void> init() async {
    final historyFile = await getHistoryDatabaseFile();
    _database = await openDatabase(
        historyFile.path, 
        version: 3,
        onCreate: (db, version) async {
          await createDbHistory(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion == 2 && newVersion == 3) {
            await db.transaction((txn) async {
              // 1. Renommer l'ancienne table
              await txn.execute("ALTER TABLE History RENAME TO History_old;");

              // 2. Créer la nouvelle table avec le bon DEFAULT
              await txn.execute("""
                CREATE TABLE History (
                  "HistoryId" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                  "BookNumber" INTEGER,
                  "ChapterNumber" INTEGER,
                  "FirstDatedTextOffset" INTEGER,
                  "LastDatedTextOffset" INTEGER,
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
                  "LastVisited" TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                );
              """);

              // 3. Copier et convertir les données
              await txn.execute("""
                INSERT INTO History (
                  HistoryId, BookNumber, ChapterNumber, FirstDatedTextOffset, LastDatedTextOffset, 
                  DocumentId, StartBlockIdentifier, EndBlockIdentifier, Track, IssueTagNumber, 
                  KeySymbol, MepsLanguageId, DisplayTitle, Type, NavigationBottomBarIndex, 
                  ScrollPosition, VisitCount, LastVisited
                )
                SELECT 
                  HistoryId, BookNumber, ChapterNumber, FirstDatedTextOffset, LastDatedTextOffset, 
                  DocumentId, StartBlockIdentifier, EndBlockIdentifier, Track, IssueTagNumber, 
                  KeySymbol, MepsLanguageId, DisplayTitle, Type, NavigationBottomBarIndex, 
                  ScrollPosition, VisitCount, 
                  strftime('%Y-%m-%dT%H:%M:%SZ', LastVisited)
                FROM History_old;
              """);

              // 4. Supprimer l'ancienne table
              await txn.execute("DROP TABLE History_old;");
              
              // 5. Recréer ton Trigger (indispensable car lié à la table)
              await txn.execute("""
                CREATE TRIGGER IF NOT EXISTS tr_History_Update_All
                AFTER UPDATE ON History
                FOR EACH ROW
                BEGIN
                  UPDATE History 
                  SET 
                    LastVisited = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
                    VisitCount = CASE 
                      WHEN (
                        NEW.ScrollPosition IS NOT OLD.ScrollPosition AND
                        NEW.NavigationBottomBarIndex IS OLD.NavigationBottomBarIndex AND
                        NEW.DisplayTitle IS OLD.DisplayTitle AND
                        NEW.KeySymbol IS OLD.KeySymbol AND
                        NEW.ChapterNumber IS OLD.ChapterNumber AND
                        NEW.BookNumber IS OLD.BookNumber AND
                        NEW.StartBlockIdentifier IS OLD.StartBlockIdentifier AND
                        NEW.EndBlockIdentifier IS OLD.EndBlockIdentifier AND
                        NEW.DocumentId IS OLD.DocumentId AND
                        NEW.MepsLanguageId IS OLD.MepsLanguageId AND
                        NEW.Type IS OLD.Type AND
                        NEW.Track IS OLD.Track AND
                        NEW.IssueTagNumber IS OLD.IssueTagNumber AND
                        NEW.FirstDatedTextOffset IS OLD.FirstDatedTextOffset AND
                        NEW.LastDatedTextOffset IS OLD.LastDatedTextOffset
                      ) THEN OLD.VisitCount
                      ELSE OLD.VisitCount + 1
                    END
                  WHERE HistoryId = NEW.HistoryId;
                END;
              """);
            });
          }
        }
    );
  }

  Future<void> deleteAllHistory() async {
    await _database.delete("History");
  }

  Future<List<Map<String, dynamic>>> loadAllHistory(int? bottomBarIndex) async {
    File mepsUnitFile = await getMepsUnitDatabaseFile();
    
    // Assure-toi que les bases sont bien attachées avant la requête
    await attachDatabases(_database, {
      'catalog': CatalogDb.instance.database.path, 
      'meps': mepsUnitFile.path
    });

    // Gestion dynamique de la clause WHERE et des arguments
    String whereClause = '';
    List<dynamic> arguments = [];
    
    if (bottomBarIndex != null) {
      whereClause = 'WHERE History.NavigationBottomBarIndex = ?';
      arguments.add(bottomBarIndex);
    }

    final result = await _database.rawQuery('''
      SELECT 
        History.*,
        cat.ShortTitle AS PublicationTitle,
        cat.IssueTitle AS PublicationIssueTitle,
        cat.PublicationTypeId,
        lang.Symbol AS LanguageSymbol,
        lang.VernacularName AS LanguageVernacularName,
        lang.IsSignLanguage AS IsSignLanguage,
        scr.IsRTL AS IsRTL
      FROM History
      LEFT JOIN meps.Language lang 
        ON lang.LanguageId = History.MepsLanguageId
      LEFT JOIN catalog.Publication cat 
        ON cat.MepsLanguageId = History.MepsLanguageId 
        AND cat.KeySymbol = History.KeySymbol
        AND cat.IssueTagNumber = History.IssueTagNumber
      LEFT JOIN meps.Script scr 
        ON scr.ScriptId = lang.ScriptId
      $whereClause
      ORDER BY History.LastVisited DESC
    ''', arguments);

    // Note : détacher 'catalog' et 'meps' si nécessaire
    await detachDatabases(_database, ['catalog', 'meps']);

    return result;
  }

  Future<List<Map<String, dynamic>>> getMostUsedLanguages() async {
    final result = await _database.rawQuery('''
       SELECT MepsLanguageId, COUNT(*) AS Occurrences
       FROM History
       GROUP BY MepsLanguageId
       ORDER BY Occurrences DESC
       LIMIT 5;
    ''');

    return result;
  }

  Future<void> insertDocument(String displayTitle, Publication pub, int docId, int? startParagraphId, int? endParagraphId) async {
    List<Map<String, dynamic>> existing = await _database.query(
      "History",
      where: "DocumentId = ? AND MepsLanguageId = ? AND Type = ?",
      whereArgs: [docId, pub.mepsLanguage.id, "document"],
    );

    if (existing.isNotEmpty) {
      await _database.update(
        "History",
        {
          "DisplayTitle": displayTitle,
          "StartBlockIdentifier": startParagraphId,
          "EndBlockIdentifier": endParagraphId,
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await _database.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": docId,
        "StartBlockIdentifier": startParagraphId,
        "EndBlockIdentifier": endParagraphId,
        "KeySymbol": pub.keySymbol,
        "IssueTagNumber": pub.issueTagNumber,
        "MepsLanguageId": pub.mepsLanguage.id,
        "Type": "document",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value
      });
    }
  }

  Future<void> insertBibleChapter(String displayTitle, Publication bible, int bibleBook, int bibleChapter, int? startVerse, int? endVerse) async {
    List<Map<String, dynamic>> existing = await _database.query(
      "History",
      where: "KeySymbol = ? AND BookNumber = ? AND ChapterNumber = ? AND MepsLanguageId = ? AND Type = ?",
      whereArgs: [bible.keySymbol, bibleBook, bibleChapter, bible.mepsLanguage.id, "chapter"],
    );

    String lastDisplayTitle = startVerse == null && endVerse == null ? displayTitle : JwLifeApp.bibleCluesInfo.getVerses(bibleBook, bibleChapter, startVerse ?? 0, bibleBook, bibleChapter, endVerse ?? 0);

    if (existing.isNotEmpty) {
      await _database.update(
        "History",
        {
          "DisplayTitle": lastDisplayTitle,
          "StartBlockIdentifier": startVerse,
          "EndBlockIdentifier": endVerse,
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await _database.insert("History", {
        "DisplayTitle": lastDisplayTitle,
        "BookNumber": bibleBook,
        "ChapterNumber": bibleChapter,
        "StartBlockIdentifier": startVerse,
        "EndBlockIdentifier": endVerse,
        "KeySymbol": bible.keySymbol,
        "MepsLanguageId": bible.mepsLanguage.id,
        "Type": "chapter",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value
      });
    }
  }

  Future<void> insertDatedText(String displayTitle, Publication pub, int firstDatedTextOffset, int lastDatedTextOffset) async {
    List<Map<String, dynamic>> existing = await _database.query(
      "History",
      where: "FirstDatedTextOffset = ? AND LastDatedTextOffset = ? AND KeySymbol = ? AND MepsLanguageId = ? AND Type = ?",
      whereArgs: [firstDatedTextOffset, lastDatedTextOffset, pub.keySymbol, pub.mepsLanguage.id, "datedText"],
    );

    if (existing.isNotEmpty) {
      await _database.update(
        "History",
        {
          "DisplayTitle": displayTitle,
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await _database.insert("History", {
        "DisplayTitle": displayTitle,
        "FirstDatedTextOffset": firstDatedTextOffset,
        "LastDatedTextOffset": lastDatedTextOffset,
        "KeySymbol": pub.keySymbol,
        "IssueTagNumber": pub.issueTagNumber,
        "MepsLanguageId": pub.mepsLanguage.id,
        "Type": "datedText",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value
      });
    }
  }

  Future<void> insertVideo(Video video) async {
    String? keySymbol = video.keySymbol;
    int? track = video.track;
    int? documentId = video.documentId;
    int? issueTagNumber = video.issueTagNumber;
    String? displayTitle = video.title;
    int? mepsLanguageId = video.getMepsLanguageId();

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

    if (mepsLanguageId != null) {
      whereClause += " AND MepsLanguageId = ?";
      whereArgs.add(mepsLanguageId);
    }

    List<Map<String, dynamic>> existing = await _database.query(
      "History",
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (existing.isNotEmpty) {
      await _database.update(
        "History",
        {
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await _database.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": documentId,
        "KeySymbol": keySymbol,
        "Track": track,
        "IssueTagNumber": issueTagNumber ?? 0,
        "MepsLanguageId": mepsLanguageId,
        "Type": "video",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
      });
    }
  }
  
  Future<void> insertAudio(Audio audio) async {
    String? keySymbol = audio.keySymbol;
    int? track = audio.track;
    int? documentId = audio.documentId;
    int? issueTagNumber = audio.issueTagNumber;
    String? displayTitle = audio.title;
    int? mepsLanguageId = audio.getMepsLanguageId();

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

    if (mepsLanguageId != null) {
      whereClause += " AND MepsLanguageId = ?";
      whereArgs.add(mepsLanguageId);
    }


    List<Map<String, dynamic>> existing = await _database.query(
      "History",
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (existing.isNotEmpty) {
      await _database.update(
        "History",
        {
          "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value,
        },
        where: "HistoryId = ?",
        whereArgs: [existing.first["HistoryId"]],
      );
    }
    else {
      await _database.insert("History", {
        "DisplayTitle": displayTitle,
        "DocumentId": documentId,
        "KeySymbol": keySymbol,
        "Track": track,
        "IssueTagNumber": issueTagNumber ?? 0,
        "MepsLanguageId": mepsLanguageId,
        "Type": "audio",
        "NavigationBottomBarIndex": GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value
      });
    }
  }

  Future<List<dynamic>> searchUsedItems(List<dynamic> items, String sortType) async {
    File mepsDbFile = await getMepsUnitDatabaseFile();

    // On utilise tes fonctions personnalisées
    await attachDatabases(_database, {'meps': mepsDbFile.path});

    Map<int, int> visitsMap = {};

    for (var item in items) {
      int? langId;
      String symbol = (item is Publication) ? item.keySymbol : (item as Media).keySymbol ?? '';
      int issueTag = (item is Publication) ? item.issueTagNumber : (item as Media).issueTagNumber ?? 0;

      if (item is Publication) {
        // Pour les publications, l'ID est déjà là
        langId = item.mepsLanguage.id;
      } else if (item is Media) {
        // Pour les médias, on récupère l'ID via le symbole dans la base attachée
        final langResult = await _database.rawQuery(
            "SELECT LanguageId FROM meps.Language WHERE Symbol = ?",
            [item.mepsLanguage] // Le symbole (ex: 'F')
        );
        if (langResult.isNotEmpty) {
          langId = langResult.first['LanguageId'] as int;
        }
      }

      // On récupère le nombre de visites dans la table History
      if (langId != null) {
        final result = await _database.rawQuery('''
        SELECT SUM(VisitCount) as Total 
        FROM History 
        WHERE KeySymbol = ? AND IssueTagNumber = ? AND MepsLanguageId = ?
      ''', [symbol, issueTag, langId]);

        visitsMap[item.hashCode] = Sqflite.firstIntValue(result) ?? 0;
      } else {
        visitsMap[item.hashCode] = 0;
      }
    }

    await detachDatabases(_database, ['meps']);

    // On trie la liste originale
    items.sort((a, b) {
      int scoreA = visitsMap[a.hashCode] ?? 0;
      int scoreB = visitsMap[b.hashCode] ?? 0;

      if (sortType == 'frequently_used') {
        return scoreB.compareTo(scoreA); // Plus visités en premier
      } else {
        return scoreA.compareTo(scoreB); // Moins visités en premier
      }
    });

    return items;
  }

  Future<void> showHistoryDialog(BuildContext mainContext, {int? bottomBarIndex}) async {
    bool isDarkMode = Theme.of(mainContext).brightness == Brightness.dark;
    final Color dividerColor = isDarkMode ? Colors.black : const Color(0xFFf0f0f0);
    final Color hintColor = isDarkMode ? const Color(0xFFc5c5c5) : const Color(0xFF666666);
    final Color subtitleColor = isDarkMode ? const Color(0xFFbdbdbd) : const Color(0xFF626262);

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
                } 
                else {
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
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre avec séparation
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        child: Text(
                          i18n().action_history,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                    ),

                    Divider(color: dividerColor),

                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Icon(JwIcons.magnifying_glass, color: hintColor),
                            const SizedBox(width: 10),
                            // **Wrap the TextField in Expanded**
                            Expanded(
                              child: TextField( // <-- This is now constrained
                                controller: searchController,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  hintText: i18n().search_hint,
                                  hintStyle: TextStyle(color: hintColor, fontSize: 16),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                                onChanged: filterHistory,
                                onSubmitted: (value) => filterHistory(value),
                                onEditingComplete: () => filterHistory(searchController.text),
                              ),
                            ),
                          ],
                        )
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filteredHistory.length, // <== Utilisez la liste filtrée ici
                        separatorBuilder: (context, index) => Divider(color: dividerColor, height: 0),
                        itemBuilder: (context, index) {
                          var item = filteredHistory[index];
                          var pub = item["PublicationTitle"] == null && item['Type'] == 'document' ? PublicationRepository().getPublicationWithMepsLanguageId(item["KeySymbol"], item["IssueTagNumber"], item["MepsLanguageId"]) : null;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);

                              if (item["Type"] == "video") {
                                RealmMediaItem? mediaItem = getMediaItem(
                                  item["KeySymbol"],
                                  item["Track"],
                                  item["DocumentId"],
                                  item["IssueTagNumber"],
                                  item["MepsLanguageId"],
                                );
                                printTime("mediaItem: ${mediaItem!.title}");

                                Video video = Video.fromJson(mediaItem: mediaItem);
                                video.showPlayer(mainContext);
                              }
                              else if (item["Type"] == "audio") {
                                RealmMediaItem? mediaItem = getAudioItem(
                                  item["KeySymbol"],
                                  item["Track"],
                                  item["DocumentId"],
                                  item["IssueTagNumber"],
                                  item["MepsLanguageId"],
                                );

                                Audio audio = Audio.fromJson(mediaItem: mediaItem);
                                audio.showPlayer(mainContext);
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
                              else if (item["Type"] == "datedText") {
                                showDailyText(mainContext, item["FirstDatedTextOffset"], item["LastDatedTextOffset"], item["KeySymbol"], item["MepsLanguageId"]);
                              }
                            },
                            child: Directionality(
                              textDirection: item["IsRTL"] == 1 ? TextDirection.rtl : TextDirection.ltr,
                              child: Container(
                                padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item["DisplayTitle"] ?? "Sans titre",
                                            style: const TextStyle(fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            item["Type"] == "video"
                                                ? i18n().label_videos
                                                : item["Type"] == "audio"
                                                ? i18n().pub_type_audio_programs
                                                : (item["PublicationIssueTitle"] ?? item["PublicationTitle"] ?? pub?.getShortTitle() ?? item['KeySymbol'] ?? ''),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: subtitleColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Icon(
                                      getIcon(item, pub),
                                      color: isDarkMode ? Colors.white : Colors.black,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Séparation et boutons
                    Divider(color: dividerColor),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => deleteAllHistory().then((value) => Navigator.pop(context)),
                          child: Text(
                            i18n().action_clear.toUpperCase(),
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
                            i18n().action_close_upper,
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

  IconData getIcon(Map item, Publication? pub) {
    int? publicationTypeId = item['PublicationTypeId'] ?? pub?.category.id;
    // 1. Cas spécifique du document avec PublicationTypeId
    if (item["Type"] == 'document' && publicationTypeId != null) {
      try {
        return PublicationCategory.all
            .firstWhere((cat) => cat.id == publicationTypeId)
            .icon;
      } 
      catch (e) {
        return JwIcons.document; // Sécurité si l'ID n'est pas trouvé
      }
    }

    // 2. Autres types
    switch (item["Type"]) {
      case 'datedText':
        return JwIcons.calendar;
      case 'chapter':
        return JwIcons.bible;
      case 'video':
        return JwIcons.video;
      case 'audio':
        return JwIcons.music;
      default:
        return JwIcons.document;
    }
  }

  Future<void> createDbHistory(Database db) async {
    await db.transaction((txn) async {
      // 1. Création de la table avec le format de date par défaut correct
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "History" (
          "HistoryId" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          "BookNumber" INTEGER,
          "ChapterNumber" INTEGER,
          "FirstDatedTextOffset" INTEGER,
          "LastDatedTextOffset" INTEGER,
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
          "LastVisited" TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
        );
      """);

      // 2. UN SEUL Trigger pour tout gérer
      await txn.execute("""
        CREATE TRIGGER IF NOT EXISTS tr_History_Update_All
        AFTER UPDATE ON History
        FOR EACH ROW
        BEGIN
          UPDATE History 
          SET 
            -- Met à jour la date ISO systématiquement
            LastVisited = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
            
            -- Logique d'incrémentation :
            VisitCount = CASE 
              -- CONDITION D'EXCEPTION : On ne fait rien si SEUL le scroll a bougé
              -- (Tous les autres paramètres doivent être identiques à l'ancien record)
              WHEN (
                NEW.ScrollPosition IS NOT OLD.ScrollPosition AND
                NEW.NavigationBottomBarIndex IS OLD.NavigationBottomBarIndex AND
                NEW.DisplayTitle IS OLD.DisplayTitle AND
                NEW.KeySymbol IS OLD.KeySymbol AND
                NEW.ChapterNumber IS OLD.ChapterNumber AND
                NEW.BookNumber IS OLD.BookNumber AND
                NEW.StartBlockIdentifier IS OLD.StartBlockIdentifier AND
                NEW.EndBlockIdentifier IS OLD.EndBlockIdentifier AND
                NEW.DocumentId IS OLD.DocumentId AND
                NEW.MepsLanguageId IS OLD.MepsLanguageId AND
                NEW.Type IS OLD.Type AND
                NEW.Track IS OLD.Track AND
                NEW.IssueTagNumber IS OLD.IssueTagNumber AND
                NEW.FirstDatedTextOffset IS OLD.FirstDatedTextOffset AND
                NEW.LastDatedTextOffset IS OLD.LastDatedTextOffset
              ) THEN OLD.VisitCount

              -- TOUS LES AUTRES CAS : (+1)
              -- Inclut : changement d'onglet, changement de titre, ou même contenu réouvert (NEW == OLD)
              ELSE OLD.VisitCount + 1
            END
          WHERE HistoryId = NEW.HistoryId;
        END;
      """);
    });
  }
}