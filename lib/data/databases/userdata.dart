import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:audio_info/audio_info.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/app/startup/copy_assets.dart';
import 'package:jwlife/core/assets.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/publication/pages/document/data/models/dated_text.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart' as uuid;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/utils/utils_video.dart';
import '../../features/publication/pages/document/data/models/document.dart';
import '../models/audio.dart';
import '../models/media.dart';
import '../models/userdata/congregation.dart';
import '../models/userdata/independentMedia.dart';
import '../models/userdata/inputField.dart';
import '../models/userdata/location.dart';
import '../models/userdata/note.dart';
import '../models/userdata/playlist.dart';
import '../models/userdata/playlistItem.dart';

import 'package:image/image.dart' as img;

class Userdata {
  int schemaVersion = 14;
  late Database _database;
  List<dynamic> favorites = [];
  List<Tag> tags = [];

  Future<void> init() async {
    File userdataFile = await getUserdataDatabaseFile();

    _database = await openDatabase(userdataFile.path, version: schemaVersion, onCreate: (db, version) async {
      await createDbUserdata(db);
    });

    await fetchFavorites();
    fetchTags();
  }

  String get formattedTimestamp => DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(DateTime.now().toUtc());

  Future<void> reload_db() async {
    await _database.close();
    await init();

    // vérifier si les nouvelles tables sont présentes
    if(!await tableExists(_database, "Congregation")) {
      await _database.execute('''
        CREATE TABLE "Congregation" (
          "CongregationId"	INTEGER NOT NULL,
          "Guid"	TEXT NOT NULL,
          "Name"	TEXT NOT NULL,
          "Address"	TEXT,
          "LanguageCode"	TEXT NOT NULL,
          "Latitude"	REAL NOT NULL,
          "Longitude"	REAL NOT NULL,
          "WeekendWeekday"	INTEGER,
          "WeekendTime"	TEXT,
          "MidweekWeekday"	INTEGER,
          "MidweekTime"	TEXT,
          PRIMARY KEY("CongregationId")
        );
      ''');
    }

    // Vider les notes, les blockRanges, les bookmarks des documents et datedTexts
    for(Publication publication in PublicationRepository().getAllPublications()) {
      if(publication.documentsManager != null) {
        for(Document document in publication.documentsManager!.documents) {
          document.notes.clear();
          document.extractedNotes.clear();
          document.blockRanges.clear();
          document.bookmarks.clear();
          document.hasAlreadyBeenRead = false;
        }
      }
      else if(publication.datedTextManager != null) {
        for(DatedText datedText in publication.datedTextManager!.datedTexts) {
          datedText.notes.clear();
          datedText.extractedNotes.clear();
          datedText.blockRanges.clear();
          datedText.bookmarks.clear();
          datedText.hasAlreadyBeenRead = false;
        }
      }
    }

    // Retourner à la racine dans tous les onglets
    for (int i = 0; i < 6; i++) {
      GlobalKeyService.jwLifePageKey.currentState?.returnToFirstPage(i);
    }
  }

  Future<void> fetchFavorites() async {
    favorites = [];

    try {
      final mepsFile = await getMepsUnitDatabaseFile();

      if (!mepsFile.existsSync()) return;

      await _database.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

      final userResults = await _database.rawQuery('''
        SELECT DISTINCT
          meps.Language.Symbol AS LanguageSymbol,
          meps.Language.VernacularName AS LanguageVernacularName,
          meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
          loc.BookNumber,
          loc.ChapterNumber,
          loc.DocumentId,
          loc.Track,
          loc.IssueTagNumber,
          loc.KeySymbol,
          loc.MepsLanguage,
          loc.Type
        FROM Location loc
        INNER JOIN meps.Language ON loc.MepsLanguage = meps.Language.LanguageId
        LEFT JOIN TagMap tm ON tm.LocationId = loc.LocationId
        LEFT JOIN Tag tag ON tm.TagId = tag.TagId
        WHERE tag.Type = 0
        ORDER BY tm.Position
      ''');

      await _database.execute("DETACH DATABASE meps");

      final allPublications = PublicationRepository().getAllPublications();

      // Préparer la liste à la bonne taille avec des valeurs null
      final List<dynamic> orderedFavorites = List.filled(userResults.length, null);
      final List<Map<String, Object?>> publicationsToLoad = [];

      for (int i = 0; i < userResults.length; i++) {
        final row = userResults[i];
        final type = row['Type'] as int?;

        if (type == 0) {
          //final match = allPublications.firstWhereOrNull((p) => p.symbol == row['KeySymbol'] && p.issueTagNumber == row['IssueTagNumber'] && p.mepsLanguage.id == row['MepsLanguage']);

          // TODO: Implémenter le chargement des documents en favoris
        }
        else if (type == 1) {
          final match = allPublications.firstWhereOrNull((p) => p.keySymbol == row['KeySymbol'] && p.issueTagNumber == row['IssueTagNumber'] && p.mepsLanguage.id == row['MepsLanguage']);

          if (match != null) {
            match.isFavoriteNotifier.value = true;
            orderedFavorites[i] = match;
          }
          else {
            // Stocker avec l’index pour réinsertion ordonnée
            publicationsToLoad.add({...row, 'index': i});
          }
        }
        else if (type == 2) {
          final mediaItem = getMediaItem(
              row['KeySymbol'] as String?,
              row['Track'] as int?,
              row['DocumentId'] as int?,
              row['IssueTagNumber'] as int?,
              row['MepsLanguage'],
              isVideo: false
          );

          orderedFavorites[i] = Audio.fromJson(mediaItem: mediaItem);
        }
        else if (type == 3) {
          final mediaItem = getMediaItem(
              row['KeySymbol'] as String?,
              row['Track'] as int?,
              row['DocumentId'] as int?,
              row['IssueTagNumber'] as int?,
              row['MepsLanguage'],
              isVideo: true
          );

          orderedFavorites[i] = Video.fromJson(mediaItem: mediaItem);
        }
        else {
          orderedFavorites[i] = row; // fallback brut
        }
      }

      // Charger les publications manquantes via catalog
      if (publicationsToLoad.isNotEmpty) {
        final catalogFile = await getCatalogDatabaseFile();

        if (catalogFile.existsSync()) {
          final catalog = await openReadOnlyDatabase(catalogFile.path);

          try {
            await catalog.transaction((txn) async {
              await txn.execute("ATTACH DATABASE '${_database.path}' AS userdata");

              final conditions = publicationsToLoad.map((row) =>
              "(p.KeySymbol = ? AND p.IssueTagNumber = ? AND p.MepsLanguageId = ?)"
              ).join(" OR ");

              final args = publicationsToLoad.expand((row) => [
                row['KeySymbol'], row['IssueTagNumber'], row['MepsLanguage']
              ]).toList();

              final result = await txn.rawQuery('''
                SELECT DISTINCT
                  p.*,
                  pa.LastModified, 
                  pa.CatalogedOn,
                  pa.Size,
                  pa.ExpandedSize,
                  pa.SchemaVersion,
                  pam.PublicationAttributeId,
                  (SELECT ia.NameFragment 
                   FROM PublicationAssetImageMap paim 
                   JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
                   WHERE paim.PublicationAssetId = pa.Id  AND (ia.Width = 270 AND ia.Height = 270)
                   LIMIT 1) AS ImageSqr
                  FROM Publication p
                  INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
                  LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
                WHERE $conditions
              ''', args);

              for (final pubRow in publicationsToLoad) {
                final index = pubRow['index'] as int;

                final match = result.firstWhereOrNull((dbRow) =>
                dbRow['KeySymbol'] == pubRow['KeySymbol'] &&
                    dbRow['IssueTagNumber'] == pubRow['IssueTagNumber'] &&
                    dbRow['MepsLanguageId'] == pubRow['MepsLanguage']
                );

                orderedFavorites[index] = match != null ? Publication.fromJson(match, isFavorite: true) : pubRow; // fallback brut
              }

              await txn.execute("DETACH DATABASE userdata");
            });

            await catalog.close();
          } catch (e) {
            printTime('Erreur: $e');
            throw Exception('Échec de chargement des favoris.');
          }
        } else {
          // Si aucun catalog, fallback brut à l’indice d’origine
          for (final pubRow in publicationsToLoad) {
            final index = pubRow['index'] as int;
            orderedFavorites[index] = pubRow;
          }
        }
      }

      // Supprimer les valeurs null si jamais une ligne a échoué sans fallback
      favorites = orderedFavorites.whereType<dynamic>().toList();
    } catch (e) {
      printTime("Erreur finale: $e");
    }
  }

  Future<int?> _getLocationId({
    int? bookNumber,
    int? chapterNumber,
    int? mepsDocumentId,
    int? track,
    int? issueTagNumber,
    String? keySymbol,
    int? mepsLanguageId,
    required int type,
  }) async {
    try {
      Map<String, dynamic> whereClause = {};

      if (bookNumber != null && chapterNumber != null) {
        whereClause['BookNumber'] = bookNumber;
        whereClause['ChapterNumber'] = chapterNumber;
      } else {
        if (mepsDocumentId != null) whereClause['DocumentId'] = mepsDocumentId;
        if (track != null) whereClause['Track'] = track;
      }

      if (issueTagNumber != null) whereClause['IssueTagNumber'] = issueTagNumber;
      if (keySymbol != null) whereClause['KeySymbol'] = keySymbol;
      if (mepsLanguageId != null) whereClause['MepsLanguage'] = mepsLanguageId;
      whereClause['Type'] = type;

      final whereKeys = whereClause.keys.toList();
      final whereString = whereKeys.map((k) => '$k = ?').join(' AND ');
      final whereValues = whereKeys.map((k) => whereClause[k]).toList();

      final result = await _database.query(
        'Location',
        columns: ['LocationId'],
        where: whereString,
        whereArgs: whereValues,
      );

      if (result.isNotEmpty) {
        return result.first['LocationId'] as int;
      }

      return null;
    } catch (e) {
      printTime('Erreur dans _getLocationId: $e');
      return null;
    }
  }


  Future<void> addInFavorite(dynamic object) async {
    try {
      int? locationId;
      if (object is Publication) {
        locationId = await insertLocation(null, null, null, null, object.issueTagNumber, object.keySymbol, object.mepsLanguage.id, type: 1);
      }
      else if (object is Document) {
        bool isBibleChapter = object.isBibleChapter();
        locationId = await insertLocation(object.bookNumber, object.chapterNumber, isBibleChapter ? null : object.mepsDocumentId, null, object.publication.issueTagNumber, object.publication.keySymbol, object.publication.mepsLanguage.id, type: 0);
      }
      else if (object is Audio) {
        locationId = await insertLocation(null, null, null, object.track, object.issueTagNumber, object.keySymbol, 3, type: 2);
        //TODO changer pour avoir le bon mepsLanguage ID
      }
      else if (object is Video) {
        locationId = await insertLocation(null, null, null, object.track, object.issueTagNumber, object.keySymbol, 3, type: 3);
      }
      else {
        return;
      }

      // Récupère la position maximale pour ce LocationId
      var maxPositionResult = await _database.rawQuery('''
      SELECT MAX(Position) as maxPosition FROM TagMap WHERE LocationId = ?
    ''', [locationId]);

      int maxPosition = maxPositionResult.first['maxPosition'] != null
          ? maxPositionResult.first['maxPosition'] as int : -1;

      int position = maxPosition + 1;

      // Vérifie si le TagId et la Position existent déjà
      while (true) {
        var checkExistsResult = await _database.rawQuery('''
        SELECT COUNT(*) as count FROM TagMap WHERE TagId = ? AND Position = ?
      ''', [1, position]); // Remplace 1 par la valeur appropriée pour TagId

        int count = checkExistsResult.first['count'] as int;
        if (count == 0) {
          break; // Trouvé une position unique
        }
        position++; // Incrémente la position pour essayer la suivante
      }

      // Insère dans la table TagMap avec la nouvelle position unique
      await _database.rawInsert('''
      INSERT INTO TagMap (TagMapId, LocationId, TagId, Position)
      VALUES (NULL, ?, 1, ?)
    ''', [locationId, position]);

      favorites.add(object);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to insert into TagMap and Location.');
    }
  }

  Future<void> removeAFavorite(dynamic object) async {
    try {
      int? locationId;

      if (object is Publication) {
        // Pour Publication
        locationId = await _getLocationId(
          issueTagNumber: object.issueTagNumber,
          keySymbol: object.keySymbol,
          mepsLanguageId: object.mepsLanguage.id,
          type: 1,
        );
      }
      else if (object is Document) {
        bool isBibleChapter = object.isBibleChapter();
        locationId = await _getLocationId(
          bookNumber: isBibleChapter ? object.bookNumber : null,
          chapterNumber: isBibleChapter ? object.chapterNumber : null,
          mepsDocumentId: isBibleChapter ? null : object.mepsDocumentId,
          issueTagNumber: object.publication.issueTagNumber,
          keySymbol: object.publication.keySymbol,
          mepsLanguageId: object.publication.mepsLanguage.id,
          type: 0,
        );
      }
      else if (object is Media) {
        locationId = await _getLocationId(
          track: object.track,
          issueTagNumber: object.issueTagNumber,
          keySymbol: object.keySymbol,
          mepsLanguageId: 3, // TODO: ajuster dynamiquement
          type: object is Audio ? 2 : 3,
        );
      }
      else if (object is Map<String, dynamic>) {
        // Pour les cas inconnus (Map brute)
        locationId = await _getLocationId(
          track: object['Track'],
          issueTagNumber: object['IssueTagNumber'],
          keySymbol: object['KeySymbol'],
          mepsLanguageId: object['MepsLanguage'],
          type: object['Type'],
        );
      }
      else {
        throw Exception('Type non reconnu pour suppression');
      }

      // Supprime les entrées associées
      if (locationId != null) {
        await _database.rawDelete('DELETE FROM TagMap WHERE LocationId = ?', [locationId]);
        await _database.rawDelete('DELETE FROM Location WHERE LocationId = ?', [locationId]);
      }

      // Supprimer de la mémoire locale favorites
      favorites.removeWhere((item) {
        if (object is Publication && item is Publication) {
          return item.keySymbol == object.keySymbol &&
              item.issueTagNumber == object.issueTagNumber &&
              item.mepsLanguage.id == object.mepsLanguage.id;
        }
        else if (object is Media && item is Media) {
          return item.keySymbol == object.keySymbol &&
              item.issueTagNumber == object.issueTagNumber &&
              item.track == object.track;
        }
        else if (object is Map && item is Map) {
          return item['KeySymbol'] == object['KeySymbol'] &&
              item['IssueTagNumber'] == object['IssueTagNumber'] &&
              item['MepsLanguage'] == object['MepsLanguage'];
        }
        return false;
      });
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove favorite from database.');
    }
  }

  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= favorites.length ||
        newIndex < 0 || newIndex >= favorites.length) {
      throw Exception('Invalid index');
    }

    if (oldIndex == newIndex) return;

    // Réordonner la liste en mémoire
    final Object movedItem = favorites.removeAt(oldIndex);
    favorites.insert(newIndex, movedItem);

    final batch = _database.batch();

    // Supprimer tous les favoris liés à Tag.Type = 0
    batch.rawDelete('''
    DELETE FROM TagMap
    WHERE TagId IN (
      SELECT TagId FROM Tag WHERE Type = 0
    )
  ''');

    for (int i = 0; i < favorites.length; i++) {
      final item = favorites[i];

      if (item is Publication) {
        batch.rawInsert('''
        INSERT INTO TagMap (TagId, LocationId, Position)
        SELECT Tag.TagId, Location.LocationId, ?
        FROM Tag
        JOIN Location ON Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
        WHERE Tag.Type = 0
        ''', [i, item.issueTagNumber, item.keySymbol, item.mepsLanguage.id, 1]);
      }
      else if (item is Document) {
        bool isBibleChapter = item.isBibleChapter();
        batch.rawInsert('''
          INSERT INTO TagMap (TagId, LocationId, Position)
          SELECT Tag.TagId, Location.LocationId, ?
          FROM Tag
          JOIN Location ON Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.DocumentId = ? AND Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
          WHERE Tag.Type = 0
        ''', [i, item.bookNumber, item.chapterNumber, isBibleChapter ? null : item.mepsDocumentId, item.publication.issueTagNumber, item.publication.keySymbol, item.publication.mepsLanguage.id, 0]);
      }
      else if (item is Audio) {
        batch.rawInsert('''
        INSERT INTO TagMap (TagId, LocationId, Position)
        SELECT Tag.TagId, Location.LocationId, ?
        FROM Tag
        JOIN Location ON Location.Track = ? AND Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
        WHERE Tag.Type = 0
        ''', [i, item.track, item.issueTagNumber ?? 0, item.keySymbol, 3, 2]);
      }
      else if (item is Video) {
        batch.rawInsert('''
        INSERT INTO TagMap (TagId, LocationId, Position)
        SELECT Tag.TagId, Location.LocationId, ?
        FROM Tag
        JOIN Location ON Location.Track = ? AND Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
        WHERE Tag.Type = 0
        ''', [i, item.track, item.issueTagNumber ?? 0, item.keySymbol, 3, 3]);
      }
      else {
        printTime('Unknown item type: $item');

        final track = item['Track'];
        final issueTagNumber = item['IssueTagNumber'];
        final keySymbol = item['KeySymbol'];
        final mepsLanguage = item['MepsLanguage'];
        final type = item['Type'];

        if (track == null) {
          batch.rawInsert('''
            INSERT INTO TagMap (TagId, LocationId, Position)
            SELECT Tag.TagId, Location.LocationId, ?
            FROM Tag
            JOIN Location ON Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
            WHERE Tag.Type = 0
          ''', [i, issueTagNumber, keySymbol, mepsLanguage, type]);
        }
        else {
          batch.rawInsert('''
            INSERT INTO TagMap (TagId, LocationId, Position)
            SELECT Tag.TagId, Location.LocationId, ?
            FROM Tag
            JOIN Location ON Location.Track = ? AND Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
            WHERE Tag.Type = 0
          ''', [i, track, issueTagNumber, keySymbol, mepsLanguage, type]);
        }
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> fetchTags() async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT DISTINCT 
        Tag.TagId, 
        Tag.Name
      FROM Tag
      WHERE Tag.Type = 1 --- '1' pour les tags de type "Categorie" pour les notes
    ''');

    tags = result.map((tag) => Tag.fromMap(tag, type: 1)).toList();
  }

  Future<Tag?> addTag(String name, int? type) async {
    try {
      // Vérifie si un tag avec le même nom et type existe déjà
      List<Map<String, dynamic>> existing = await _database.query(
        'Tag',
        where: 'Name = ? AND Type = ?',
        whereArgs: [name, type ?? 1],
      );

      if (existing.isNotEmpty) {
        // Le tag existe déjà, retourne null ou l'instance existante si tu préfères
        printTime('Tag déjà existant avec le nom "$name" et type ${type ?? 1}');

        BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;

        await showJwDialog(
          context: context,
          titleText: 'Catégorie déjà existante',
          contentText: 'La Catégorie "$name" existe déjà.',
          buttonAxisAlignment: MainAxisAlignment.end,
          buttons: [
            JwDialogButton(
              label: 'OK',
            ),
          ],
        );

        return null;
      }

      // Insère le tag
      int tagId = await _database.insert('Tag', {
        'Type': type ?? 1,
        'Name': name
      });

      Tag tag;
      if (type == 2) {
         tag = Playlist.fromMap({'TagId': tagId, 'Type': type ?? 2, 'Name': name});
      }
      else {
        tag = Tag.fromMap({'TagId': tagId, 'Type': type ?? 1, 'Name': name});
        tags.add(tag);
      }

      return tag;
    }
    catch (e) {
      printTime('Erreur lors de l\'ajout du tag : $e');
      return null;
    }
  }

  Future<Tag?> updateTag(Tag tag, String name) async {
    try {
      // Mise à jour dans la base de données
      await _database.update(
        'Tag',
        {'Name': name},
        where: 'TagId = ? AND Type = ?',
        whereArgs: [tag.id, tag.type],
      );

      // Mise à jour dans la liste locale `tags`
      if (tag.type == 1) {
        final index = tags.indexWhere((t) => t.id == tag.id && t.type == tag.type);
        if (index != -1) {
          tags[index] = Tag(id: tag.id, name: name, type: tag.type);
          return tags[index];
        }
        else {
          printTime('Tag non trouvé dans la liste locale.');
          return null;
        }
      }
      else if(tag.type == 2) {
        tag.name = name;
        return tag;
      }
      else {
        return tag;
      }
    }
    catch (e) {
      printTime('Erreur lors de la mise à jour du tag : $e');
      return null;
    }
  }

  Future<bool> deleteTag(Tag tag, {List<PlaylistItem>? items}) async {
    try {
      int count = 0;

      // Mise à jour de la liste locale `tags`
      if (tag.type == 1) {
        count = await _database.delete(
          'Tag',
          where: 'TagId = ? AND Type = ?',
          whereArgs: [tag.id, tag.type],
        );

        // On enlève aussi les associations dans les TagMap
        await _database.delete(
          'TagMap',
          where: 'TagId = ?',
          whereArgs: [tag.id],
        );

        tags.removeWhere((t) => t.id == tag.id);
      }
      else if (tag.type == 2) {
        items ??= await getPlaylistItemByPlaylistId(tag.id);

        // On attend que tous les PlaylistItem soient supprimés
        for (var item in items) {
          deletePlaylistItem(item);
        }

        count = await _database.delete(
          'Tag',
          where: 'TagId = ? AND Type = ?',
          whereArgs: [tag.id, tag.type],
        );
      }

      return count > 0;
    } catch (e) {
      printTime('Erreur lors de la suppression du tag : $e');
      return false;
    }
  }

  Future<int?> insertLocationWithDocument(Publication publication, Document? document, {DatedText? datedText, bool language = true}) async {
    int mepsDocumentId = document?.mepsDocumentId ?? datedText!.mepsDocumentId;
    int? locationId = await insertLocation(document?.bookNumber, document?.chapterNumber, mepsDocumentId, null, publication.issueTagNumber, publication.keySymbol, language ? publication.mepsLanguage.id : null);
    return locationId;
  }

  Future<int?> insertLocation(
      int? bookNumber,
      int? chapterNumber,
      int? mepsDocumentId,
      int? track,
      int? issueTagNumber,
      String? keySymbol,
      int? mepsLanguageId, {
        int type = 0,
        Transaction? transaction,
      }) async {
    if (bookNumber == null && chapterNumber == null && mepsDocumentId == null && track == null && issueTagNumber == null && keySymbol == null && mepsLanguageId == null) return null;

    try {
      Map<String, dynamic> insertValues = {}; // Utiliser ce Map pour l'INSERT

      // 1. Définir les valeurs pour l'INSERT
      if (bookNumber != null && chapterNumber != null) {
        insertValues.addAll({
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
        });
      } else {
        if (mepsDocumentId != null) insertValues['DocumentId'] = mepsDocumentId;
        if (track != null) insertValues['track'] = track;
      }

      if (issueTagNumber != null) insertValues['IssueTagNumber'] = issueTagNumber;
      if (keySymbol != null) insertValues['KeySymbol'] = keySymbol;
      // Laisser mepsLanguageId dans insertValues s'il est non-null, sinon il sera null (par défaut)
      if (mepsLanguageId != null) insertValues['MepsLanguage'] = mepsLanguageId;

      insertValues['Type'] = type;

      // 2. Construire la clause WHERE pour la recherche (SELECT)
      // Elle doit être basée sur les mêmes valeurs, mais gérée différemment pour NULL

      final List<String> whereClauses = [];
      final List<dynamic> whereArgs = [];

      // Ajouter toutes les conditions de recherche standard
      insertValues.forEach((key, value) {
        // Pour les valeurs non-null, utiliser l'égalité standard
        if (value != null) {
          whereClauses.add('$key = ?');
          whereArgs.add(value);
        }
        else {
          if (key == 'MepsLanguage' && mepsLanguageId == null) {
            whereClauses.add('$key IS NULL');
          }

        }
      });

      // Pour une construction de WHERE plus robuste, il est mieux de la reconstruire
      // explicitement en gérant le cas MepsLanguage = NULL.

      final Map<String, dynamic> whereClause = {};

      if (bookNumber != null && chapterNumber != null) {
        whereClause.addAll({
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
        });
      } else {
        if (mepsDocumentId != null) whereClause['DocumentId'] = mepsDocumentId;
        if (track != null) whereClause['track'] = track;
      }

      if (issueTagNumber != null) whereClause['IssueTagNumber'] = issueTagNumber;
      if (keySymbol != null) whereClause['KeySymbol'] = keySymbol;

      // Gestion de MepsLanguage :
      if (mepsLanguageId != null) {
        whereClause['MepsLanguage'] = mepsLanguageId;
      }

      whereClause['Type'] = type;

      final List<String> finalWhereClauses = [];
      final List<dynamic> finalWhereValues = [];

      whereClause.forEach((key, value) {
        finalWhereClauses.add('$key = ?');
        finalWhereValues.add(value);
      });

      // Ajoutez la condition IS NULL pour MepsLanguage si l'ID est null
      if (mepsLanguageId == null) {
        finalWhereClauses.add('MepsLanguage IS NULL');
      }

      final whereString = finalWhereClauses.join(' AND ');
      final whereValues = finalWhereValues;

      // Choisir le bon objet pour requête
      final dbExecutor = transaction ?? _database;

      final List<Map<String, dynamic>> existing = await dbExecutor.query(
        'Location',
        columns: ['LocationId'],
        where: whereString,
        whereArgs: whereValues,
      );

      printTime('Existing location count: $existing');

      if (existing.isNotEmpty) {
        return existing.first['LocationId'] as int;
      }

      if (mepsLanguageId != null) {
        insertValues['MepsLanguage'] = mepsLanguageId;
      } else {
        // Si l'ID est null, l'insertion sans la clé est implicitement NULL
        // selon l'implémentation de `insert`, ou vous pouvez forcer :
        insertValues['MepsLanguage'] = null; // SQLite gère bien l'insertion de null
      }

      final locationId = await dbExecutor.insert('Location', insertValues);
      return locationId;
    } catch (e) {
      printTime('Erreur lors de insertLocation: $e');
      throw Exception('Échec de l\'insertion ou de la récupération de la Location');
    }
  }

  Future<List<InputField>> getInputFields(String query) async {
    try {
      final likeQuery = '%$query%';
      final result = await _database.rawQuery('''
      SELECT InputField.TextTag, InputField.Value, Location.*
      FROM InputField
      LEFT JOIN Location ON InputField.LocationId = Location.LocationId
      WHERE InputField.Value LIKE ?
    ''', [likeQuery]);

      return result.map((note) => InputField.fromMap(note)).toList();
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load input fields for the given query.');
    }
  }

  Future<List<Map<String, dynamic>>> getInputFieldsFromDocumentId(int documentId) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> inputFieldsData = await _database.rawQuery('''
          SELECT TextTag, Value
          FROM InputField
          LEFT JOIN Location ON InputField.LocationId = Location.LocationId
          WHERE Location.DocumentId = ?
          ''', [documentId]
      );

      return inputFieldsData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId.');
    }
  }

  Future<void> updateOrInsertInputField(Document document, String tag, String value) async {
    try {
      // Étape 1 : Obtenir ou insérer le LocationId via insertLocation
      final int? locationId = await insertLocationWithDocument(document.publication, document, language: false);

      // Étape 2 : Insérer ou mettre à jour l'entrée InputField
      await _database.rawInsert('''
      INSERT INTO InputField (LocationId, TextTag, Value)
      VALUES (?, ?, ?)
      ON CONFLICT(LocationId, TextTag) DO UPDATE SET
        Value = excluded.Value
    ''', [locationId, tag, value]);
    } catch (e) {
      printTime('Erreur dans updateOrInsertInputField: $e');
      throw Exception('Échec lors de l\'insertion ou la mise à jour d\'un InputField : ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getBlockRangesFromChapterNumber(int bookId, int chapterId, String keySymbol, int mepsLanguageId, {int? startVerse, int? endVerse}) async {
    try {
      List<dynamic> arguments = [bookId, chapterId, keySymbol, mepsLanguageId];
      String whereClause = 'WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ?';

      // 1. Ajouter le filtre de début de verset (Identifier >= startVerse)
      if (startVerse != null) {
        whereClause += ' AND BlockRange.Identifier >= ?';
        arguments.add(startVerse);
      }

      // 2. Ajouter le filtre de fin de verset (Identifier <= endVerse)
      if (endVerse != null) {
        whereClause += ' AND BlockRange.Identifier <= ?';
        arguments.add(endVerse);
      }

      // La requête SQL complète avec la clause WHERE construite dynamiquement
      String sqlQuery = '''
          SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.StyleIndex, UserMark.UserMarkGuid
          FROM Location
          LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
          LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
          $whereClause
    ''';

      List<Map<String, dynamic>> blockRanges = await _database.rawQuery(sqlQuery, arguments);

      return blockRanges;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load block ranges for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getBlockRangesFromDocumentId(int documentId, int mepsLanguageId, {int? startParagraph, int? endParagraph}) async {
    try {
      List<dynamic> arguments = [documentId, mepsLanguageId];
      String whereClause = 'WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?';

      // 1. Ajouter le filtre de début de paragraphe (Identifier >= startParagraph)
      if (startParagraph != null) {
        whereClause += ' AND BlockRange.Identifier >= ?';
        arguments.add(startParagraph);
      }

      // 2. Ajouter le filtre de fin de paragraphe (Identifier <= endParagraph)
      if (endParagraph != null) {
        whereClause += ' AND BlockRange.Identifier <= ?';
        arguments.add(endParagraph);
      }

      // La requête SQL complète avec la clause WHERE construite
      String sqlQuery = '''
          SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.StyleIndex, UserMark.UserMarkGuid
          FROM Location
          LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
          LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
          $whereClause
    ''';

      List<Map<String, dynamic>> blockRanges = await _database.rawQuery(sqlQuery, arguments);

      return blockRanges;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load block ranges for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> removeBlockRangeWithGuid(String userMarkGuid) async {
    try {
      // Supprimer d'abord les BlockRange associés
      await _database.rawDelete('''
        DELETE FROM BlockRange WHERE UserMarkId IN (
          SELECT UserMarkId FROM UserMark WHERE UserMarkGuid = ?
        )
      ''', [userMarkGuid]);

      // Ensuite supprimer l'UserMark
      await _database.rawDelete('''
        DELETE FROM UserMark WHERE UserMarkGuid = ?
      ''', [userMarkGuid]);

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove highlight with UserMarkGuid.');
    }
  }

  Future<void> changeBlockRangeStyleWithGuid(String userMarkGuid, int styleIndex, int colorIndex) async {
    try {
      await _database.rawUpdate('''
        UPDATE UserMark 
        SET ColorIndex = ?, StyleIndex = ?
        WHERE UserMarkGuid = ?
      ''', [colorIndex, styleIndex, userMarkGuid]);

      // on enregistre dans la base de donnée les nouveau highlight
      if(JwLifeSettings().webViewData.styleIndex != styleIndex || JwLifeSettings().webViewData.colorIndex != colorIndex) {
        JwLifeSettings().webViewData.updateStyleAndColorIndex(styleIndex, colorIndex);
        setStyleIndex(styleIndex);
        setColorIndex(colorIndex);
      }

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change style for block range with UserMarkGuid.');
    }
  }

  Future<void> addBlockRangesToDocument(Publication publication, Document? document, List<dynamic> blockRangesParagraphs, int styleIndex, int colorIndex, String uuid, {DatedText? datedText}) async {
    try {
      // Étape 1 : Obtenir ou insérer le LocationId via insertLocation
      final locationId = await insertLocationWithDocument(publication, document, datedText: datedText);

      printTime('locationId: $locationId');

      // Étape 2 : Insérer dans la table UserMark
      final userMarkId = await _database.insert('UserMark', {
        'ColorIndex': colorIndex,
        'LocationId': locationId,
        'StyleIndex': styleIndex,
        'UserMarkGuid': uuid,
        'Version': 1,
      });

      // Étape 3 : Insérer dans la table BlockRange
      for(Map<String, dynamic> blockRange in blockRangesParagraphs) {
        await _database.insert('BlockRange', {
          'UserMarkId': userMarkId,
          'BlockType': blockRange['blockType'],
          'Identifier': int.parse(blockRange['identifier'].toString()),
          'StartToken': blockRange['startToken'],
          'EndToken': blockRange['endToken']
        });
      }

      // on enregistre dans la base de donnée les nouveau highlight
      if(JwLifeSettings().webViewData.styleIndex != styleIndex || JwLifeSettings().webViewData.colorIndex != colorIndex) {
        JwLifeSettings().webViewData.updateStyleAndColorIndex(styleIndex, colorIndex);
        setStyleIndex(styleIndex);
        setColorIndex(colorIndex);
      }

    } catch (e) {
      printTime('Erreur dans addBlockRangeToDocument: $e');
      throw Exception('Échec de l\'ajout du surlignage pour ce webview.');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarksFromDocumentId(int documentId, int mepsLanguageId) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> bookmarksData = await _database.rawQuery('''
          SELECT Slot, BlockType, BlockIdentifier
          FROM Bookmark
          LEFT JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Location.DocumentId = ?
          ''', [documentId]
      );

      return bookmarksData;

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarksFromChapterNumber(int bookNumber, int chapterNumber, String keySymbol) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> inputFieldsData = await _database.rawQuery('''
          SELECT Slot, BlockType, BlockIdentifier
          FROM Bookmark
          LEFT JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.KeySymbol = ?
          ''', [bookNumber, chapterNumber, keySymbol]
      );

      return inputFieldsData;

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Note>> getNotes({int? limit, int? offset, String? query}) async {
    final params = <dynamic>[];
    String whereClause = '';
    if (query != null && query.trim().isNotEmpty) {
      whereClause = 'WHERE (N.Title LIKE ? OR N.Content LIKE ?)';
      final likeQuery = '%${query.trim()}%';
      params.addAll([likeQuery, likeQuery]);
    }

    String limitClause = '';
    // Assurez-vous d'avoir une limite si vous utilisez le décalage, mais aussi pour le cas général
    if (limit != null) {
      limitClause = 'LIMIT ?';
      params.add(limit);
    }

    String offsetClause = '';
    if (offset != null) {
      // La clause OFFSET vient après la clause LIMIT
      offsetClause = 'OFFSET ?';
      params.add(offset);
    }

    final sql = '''
      SELECT 
        N.NoteId,
        N.Guid,
        N.Title,
        N.Content,
        N.BlockType,
        N.BlockIdentifier,
        N.LastModified,
        N.Created,
        UM.UserMarkId,
        UM.ColorIndex,
        UM.UserMarkGuid,
        GROUP_CONCAT(DISTINCT T.TagId) AS TagsId,
        L.LocationId,
        L.BookNumber,
        L.ChapterNumber,
        L.DocumentId,
        L.IssueTagNumber,
        L.KeySymbol,
        L.MepsLanguage
      FROM Note N
      LEFT JOIN Location L ON L.LocationId = N.LocationId
      LEFT JOIN TagMap TM ON N.NoteId = TM.NoteId
      LEFT JOIN Tag T ON TM.TagId = T.TagId
      LEFT JOIN UserMark UM ON N.UserMarkId = UM.UserMarkId
      $whereClause
      GROUP BY N.NoteId
      ORDER BY N.LastModified DESC
      $limitClause
      $offsetClause
    ''';

    final result = await _database.rawQuery(sql, params);
    return result.map((note) => Note.fromMap(note)).toList();
  }

  Future<List<Map<String, dynamic>>> getNotesFromDocumentId(int documentId, int mepsLanguageId, {int? startParagraph, int? endParagraph}) async {
    try {
      List<dynamic> arguments = [documentId, mepsLanguageId];
      String whereClause = 'WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?';

      // 1. Ajouter le filtre de début de paragraphe (Identifier >= startParagraph)
      if (startParagraph != null) {
        whereClause += ' AND Note.BlockIdentifier >= ?';
        arguments.add(startParagraph);
      }

      // 2. Ajouter le filtre de fin de paragraphe (Identifier <= endParagraph)
      if (endParagraph != null) {
        whereClause += ' AND Note.BlockIdentifier <= ?';
        arguments.add(endParagraph);
      }

      // La requête SQL complète avec la clause WHERE construite
      String sqlQuery = '''
      SELECT 
        Note.Guid,
        Note.Title,
        Note.Content,
        Note.BlockType,
        Note.BlockIdentifier,
        UserMark.ColorIndex,
        UserMark.UserMarkGuid,
        GROUP_CONCAT(Tag.TagId) AS TagsId
      FROM Location
      INNER JOIN Note ON Location.LocationId = Note.LocationId
      LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
      LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
      LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
      $whereClause
      GROUP BY Note.NoteId
    ''';

      List<Map<String, dynamic>> notesData = await _database.rawQuery(sqlQuery, arguments);

      return notesData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getNotesFromChapterNumber(int bookId, int chapterId, String keySymbol, int mepsLanguageId, {int? startVerse, int? endVerse}) async {
    try {
      List<dynamic> arguments = [bookId, chapterId, keySymbol, mepsLanguageId];
      String whereClause = 'WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ?';

      // 1. Ajouter le filtre de début de verset si 'startVerse' est fourni
      if (startVerse != null) {
        whereClause += ' AND Note.BlockIdentifier >= ?';
        arguments.add(startVerse);
      }

      // 2. Ajouter le filtre de fin de verset si 'endVerse' est fourni
      if (endVerse != null) {
        whereClause += ' AND Note.BlockIdentifier <= ?';
        arguments.add(endVerse);
      }

      String sqlQuery = '''
      SELECT 
        Note.Guid,
        Note.Title,
        Note.Content,
        Note.BlockIdentifier,
        Note.BlockType,
        UserMark.ColorIndex,
        UserMark.UserMarkGuid,
        GROUP_CONCAT(Tag.TagId) AS TagsId
      FROM Location
      INNER JOIN Note ON Location.LocationId = Note.LocationId
      LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
      LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
      LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
      $whereClause
      GROUP BY Note.NoteId
    ''';

      List<Map<String, dynamic>> notesData = await _database.rawQuery(sqlQuery, arguments);

      return notesData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> addNoteToDocId(Publication publication, Document? document, int blockType, int identifier, String title, String uuid, String? userMarkGuid, {DatedText? datedText}) async {
    try {
      int? userMarkId;
      int? locationId;

      // Récupérer UserMark si userMarkGuid est fourni
      if (userMarkGuid != null) {
        final userMarkResults = await _database.query(
          'UserMark',
          where: 'UserMarkGuid = ?',
          whereArgs: [userMarkGuid],
        );

        if (userMarkResults.isNotEmpty) {
          final userMark = userMarkResults.first;
          userMarkId = userMark['UserMarkId'] as int?;
          locationId = userMark['LocationId'] as int?;
        }
      }

      // Si on n’a pas encore de locationId, on l’obtient via insertLocation
      locationId ??= await insertLocationWithDocument(publication, document, datedText: datedText);

      final timestamp = DateTime.now().toIso8601String();

      // Insérer dans la table Note
      await _database.insert('Note', {
        'Guid': uuid,
        'UserMarkId': userMarkId,
        'LocationId': locationId,
        'Title': title,
        'Content': '',
        'LastModified': timestamp,
        'Created': timestamp,
        'BlockType': blockType,
        'BlockIdentifier': identifier,
      });

    } catch (e, stackTrace) {
      printTime('Error in addNoteToDocId: $e');
      printTime('Stack trace: $stackTrace');
      throw Exception('Failed to add note for the given DocumentId and BlockIdentifier.');
    }
  }

  Future<void> removeNoteWithGuid(String noteGuid) async {
    try {
      await _database.rawDelete('''
        DELETE FROM TagMap WHERE NoteId IN (SELECT NoteId FROM Note WHERE Guid = ?)
      ''', [noteGuid]);

      await _database.rawDelete('''
      DELETE FROM Note WHERE Guid = ?
    ''', [noteGuid]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove note with Guid.');
    }
  }

  Future<Note?> addNote(String title, String content, int? colorIndex, List<int> categoryIds, int? mepsDocumentId, int? bookNumber, int? chapterNumber, int? issueTagNumber, String? keySymbol, int? mepsLanguageId, {int blockType = 0, int? blockIdentifier}) async {
    try {
      int? locationId = await insertLocation(bookNumber, chapterNumber, mepsDocumentId, null, issueTagNumber, keySymbol, mepsLanguageId);

      int? userMarkId;
      if (colorIndex != null && locationId != null) {
        final userMarkGuid = uuid.Uuid().v4(); // Generates a version 4 UUID

        // Insérer une nouvelle entrée dans la table UserMark avec un LocationId valide
        userMarkId = await _database.insert('UserMark', {
          'ColorIndex': colorIndex,  // Insérer le ColorIndex
          'LocationId': locationId,  // Associer à un LocationId valide
          'StyleIndex': 0,  // Insérer un StyleIndex valide
          'UserMarkGuid': userMarkGuid,  // Générer un GUID unique
          'Version': 1,  // Insérer une version valide
        });
      }

      final guidNote = uuid.Uuid().v4(); // Generates a version 4 UUID

      // Insérer la nouvelle note dans la table Note, en liant UserMarkId
      int noteId = await _database.insert('Note', {
        'Guid': guidNote, // Générer un GUID unique pour la note
        'UserMarkId': userMarkId, // Lier la note à l'entrée UserMark
        'LocationId': locationId, // Lier la note à un LocationId valide
        'Title': title,
        'Content': content,
        'LastModified': DateTime.now().toIso8601String(),
        'Created': DateTime.now().toIso8601String(),
        'BlockType': blockType,
        'BlockIdentifier': blockIdentifier,
      });

      // Ajouter les catégories associées à la note dans la table TagMap avec une position unique pour chaque catégorie
      for (int categoryId in categoryIds) {
        // Regarder le plus grand position pour cette category
        final maxPositionResult = await _database.query(
          'TagMap',
          where: 'TagId = ?',
          whereArgs: [categoryId],
          orderBy: 'Position DESC',
          limit: 1,
        );

        // Vérifier si un résultat existe pour cette catégorie
        int newPosition = 0;  // Si aucune position n'existe, commencer à 0
        if (maxPositionResult.isNotEmpty) {
          // Convertir 'Position' en int avant d'incrémenter
          newPosition = (maxPositionResult.first['Position'] as int) + 1;
        }

        // Insérer le TagMap avec la nouvelle position
        await _database.insert('TagMap', {
          'NoteId': noteId,  // Utiliser seulement NoteId
          'TagId': categoryId,
          'Position': newPosition,  // Incrémenter la position pour chaque TagId
        });
      }

      Note newNote = Note.fromMap({
        'NoteId': noteId,
        'Guid': guidNote,
        'Title': title,
        'Content': content,
        'LastModified': DateTime.now().toIso8601String(),
        'Created': DateTime.now().toIso8601String(),
        'TagsId': categoryIds,
        'BlockType': blockType,
        'BlockIdentifier': blockIdentifier
      });
      return newNote;
    }
    catch (e) {
      printTime('Erreur lors de l\'ajout de la note : $e');
      return null;
    }
  }

  Future<void> updateNoteWithGuid(String guid, String title, String content) async {
    try {
      await _database.rawUpdate('''
      UPDATE Note 
      SET Title = ?, Content = ?, LastModified = ?
      WHERE Guid = ?
    ''', [title, content, formattedTimestamp, guid]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to update note with Guid.');
    }
  }

  Future<void> changeNoteUserMark(String noteGuid, String userMarkGuid) async {
    try {
      // Récupérer l'ID du UserMark
      List<Map<String, dynamic>> userMarkResult = await _database.rawQuery('''
        SELECT UserMarkId FROM UserMark WHERE UserMarkGuid = ?
      ''', [userMarkGuid]);

      if (userMarkResult.isEmpty) {
        throw Exception('UserMarkGuid not found');
      }

      final int userMarkId = userMarkResult.first['UserMarkId'];

      // Mise à jour de la note avec le UserMark et LastModified
      await _database.rawUpdate('''
        UPDATE Note
        SET UserMarkId = ?, LastModified = ?
        WHERE Guid = ?
      ''', [userMarkId, formattedTimestamp, noteGuid]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change UserMark for note.');
    }
  }

  Future<void> updateNoteColorWithGuid(String guid, int colorIndex) async {
    try {
      await _database.rawUpdate('''
        UPDATE UserMark
        SET ColorIndex = ?
        WHERE UserMarkId = (
          SELECT UserMarkId FROM Note WHERE Guid = ?
        )
      ''', [colorIndex, guid]);

      await _database.rawUpdate('''
        UPDATE Note
        SET LastModified = ?
        WHERE Guid = ?
      ''', [formattedTimestamp, guid]);
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change color for note with Guid.');
    }
  }

  Future<void> addTagToNoteWithGuid(String guid, int tagId) async {
    try {
      // Récupérer le NoteId depuis le Guid
      final noteIdResult = await _database.rawQuery('''
        SELECT NoteId FROM Note WHERE Guid = ?
      ''', [guid]);

      if (noteIdResult.isEmpty) {
        throw Exception('Note avec le Guid $guid introuvable.');
      }

      final noteId = noteIdResult.first['NoteId'] as int;

      // Récupérer la position max actuelle pour ce TagId
      final positionResult = await _database.rawQuery('''
        SELECT MAX(Position) as maxPosition FROM TagMap WHERE TagId = ?
      ''', [tagId]);

      final maxPosition = positionResult.first['maxPosition'] as int? ?? -1;
      final newPosition = maxPosition + 1;

      // Mettre à jour la date de modification de la note
      await _database.rawUpdate('''
        UPDATE Note 
        SET LastModified = ?
        WHERE NoteId = ?
      ''', [formattedTimestamp, noteId]);

      // Insérer le nouveau TagMap avec la position calculée
      await _database.rawInsert('''
        INSERT INTO TagMap (NoteId, TagId, Position)
        VALUES (?, ?, ?)
      ''', [noteId, tagId, newPosition]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to add tag to note with Guid $guid.');
    }
  }

  Future<void> removeTagFromNoteWithGuid(String guid, int tagId) async {
    try {
      // Récupérer le NoteId depuis le Guid
      final noteIdResult = await _database.rawQuery('''
        SELECT NoteId FROM Note WHERE Guid = ?
      ''', [guid]);

      if (noteIdResult.isEmpty) {
        throw Exception('Note avec le Guid $guid introuvable.');
      }

      final noteId = noteIdResult.first['NoteId'] as int;

      // Supprimer l'association dans TagMap
      await _database.rawDelete('''
        DELETE FROM TagMap
        WHERE NoteId = ? AND TagId = ?
      ''', [noteId, tagId]);

      // Mettre à jour la date de modification de la note
      await _database.rawUpdate('''
        UPDATE Note 
        SET LastModified = ?
        WHERE NoteId = ?
      ''', [formattedTimestamp, noteId]);
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove tag from note with Guid $guid.');
    }
  }

  Future<Note> updateNote(Note note, String title, String content, {int? colorIndex, List<int>? tagsId}) async {
    try {
      int noteId = note.noteId;
      int? userMarkId = note.userMarkId;

      if (userMarkId != null) {
        await _database.update(
          'UserMark',
          {'ColorIndex': colorIndex ?? note.colorIndex},
          where: 'UserMarkId = ?',
          whereArgs: [userMarkId],
        );
      }

      // Mettre à jour l'entrée dans la table Note avec le nouvel title et content
      String lastModified = DateTime.now().toIso8601String();
      await _database.update(
        'Note',
        {
          'Title': title,
          'Content': content,
          'LastModified': lastModified,
        },
        where: 'NoteId = ?',
        whereArgs: [noteId],
      );

      // Mettre à jour et retourner l'objet note
      note.title = title;
      note.content = content;
      note.colorIndex = colorIndex ?? note.colorIndex;
      note.lastModified = lastModified;

      return note;
    }
    catch (e) {
      printTime('Erreur lors de la mise à jour de la note : $e');
      return note;
    }
  }

  Future<bool> deleteNote(Note note) async {
    try {
      int noteId = note.noteId;

      // Supprimer d'abord les entrées associées dans la table TagMap
      await _database.delete(
        'TagMap',
        where: 'NoteId = ?',
        whereArgs: [noteId],
      );

      // Supprimer ensuite l'entrée correspondante dans la table Note
      await _database.delete(
        'Note',
        where: 'NoteId = ?',
        whereArgs: [noteId],
      );

      printTime('Note supprimée avec succès');
      return true;

    } catch (e) {
      printTime('Erreur lors de la suppression de la note : $e');
      return false;
    }
  }


  Future<List<Note>> getNotesByTag(int tagId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT 
      N.NoteId,
      N.Guid,
      N.Title,
      N.Content,
      N.BlockType,
      N.BlockIdentifier,
      N.LastModified,
      N.Created,
      UM.UserMarkId,
      UM.ColorIndex,
      UM.UserMarkGuid,
      GROUP_CONCAT(DISTINCT T.TagId) AS TagsId,
      L.LocationId,
      L.BookNumber,
      L.ChapterNumber,
      L.DocumentId,
      L.IssueTagNumber,
      L.KeySymbol,
      L.MepsLanguage,
      TM_Pos.Position -- Colonne Position ajoutée pour le tri
    FROM Note N
    
    -- 1. INNER JOIN : Filtre les notes par tagId et récupère la Position pour le tri
    INNER JOIN TagMap TM_Pos 
      ON N.NoteId = TM_Pos.NoteId AND TM_Pos.TagId = ?
    
    -- 2. LEFT JOINs : Récupère les autres données (Location, tous les tags, UserMark)
    LEFT JOIN Location L ON L.LocationId = N.LocationId
    LEFT JOIN TagMap TM ON N.NoteId = TM.NoteId 
    LEFT JOIN Tag T ON TM.TagId = T.TagId
    LEFT JOIN UserMark UM ON N.UserMarkId = UM.UserMarkId
    
    -- Toutes les colonnes non agrégées doivent être dans le GROUP BY
    GROUP BY 
      N.NoteId, N.Guid, N.Title, N.Content, N.BlockType, N.BlockIdentifier, 
      N.LastModified, N.Created, UM.UserMarkId, UM.ColorIndex,
      UM.UserMarkGuid, L.LocationId, L.BookNumber, L.ChapterNumber,
      L.DocumentId, L.IssueTagNumber, L.KeySymbol, L.MepsLanguage,
      TM_Pos.Position
      
    -- 3. ORDER BY : Utilise la colonne Position maintenant accessible
    ORDER BY TM_Pos.Position ASC;
  ''', [tagId]); // Le paramètre est passé à TM_Pos.TagId = ?

    for(Map<String, dynamic> map in result) {
      print(map["Title"]);
    }

    // Le reste du code Dart est correct pour le mapping
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> reorderNotesInTag(int tagId, List<int> noteIdsInNewOrder) async {
    print(tagId);
    print(noteIdsInNewOrder);

    await _database.transaction((txn) async {
      // --- 1. Dégager toutes les positions pour éviter les conflits UNIQUE ---
      for (int i = 0; i < noteIdsInNewOrder.length; i++) {
        final int noteId = noteIdsInNewOrder[i];

        // Attribuer une position temporaire négative (ex: -1, -2, -3...)
        // Ce Position Id temporaire doit aussi être UNIQUE pour éviter une autre violation.
        final int tempPosition = -(i + 1);

        final Map<String, dynamic> tempValues = {
          'Position': tempPosition,
        };

        await txn.update(
          'TagMap',
          tempValues,
          where: 'TagId = ? AND NoteId = ?',
          whereArgs: [tagId, noteId],
        );
      }

      // --- 2. Ranger toutes les positions à leur valeur finale correcte ---
      for (int i = 0; i < noteIdsInNewOrder.length; i++) {
        final int noteId = noteIdsInNewOrder[i];
        final int newPosition = i;

        final Map<String, dynamic> finalValues = {
          'Position': newPosition,
        };

        // Exécution de la mise à jour sur la table TagMap
        await txn.update(
          'TagMap',
          finalValues,
          where: 'TagId = ? AND NoteId = ?',
          whereArgs: [tagId, noteId],
        );
      }
    });
  }

  Future<List<Bookmark>> getBookmarksFromPub(Publication publication) async {
    try {
      final bookmarks = await _database.rawQuery('''
      SELECT DISTINCT 
        Bookmark.Slot,
        Bookmark.Title,
        Bookmark.Snippet,
        Bookmark.BlockType,
        Bookmark.BlockIdentifier,
        LocationTarget.BookNumber,
        LocationTarget.ChapterNumber,
        LocationTarget.DocumentId
      FROM Bookmark
      JOIN Location AS PublicationLocation 
        ON Bookmark.PublicationLocationId = PublicationLocation.LocationId
      JOIN Location AS LocationTarget 
        ON Bookmark.LocationId = LocationTarget.LocationId
      WHERE 
        PublicationLocation.KeySymbol = ? AND 
        PublicationLocation.IssueTagNumber = ? AND 
        PublicationLocation.MepsLanguage = ? AND 
        PublicationLocation.Type = 1
    ''', [
        publication.keySymbol,
        publication.issueTagNumber,
        publication.mepsLanguage.id
      ]);

      return bookmarks.map((map) => Bookmark.fromMap(map)).toList();
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load bookmarks for the given publication.');
    }
  }

  Future<Bookmark?> addBookmark(
      Publication publication,
      int? mepsDocumentId,
      int? bookNumber,
      int? chapterNumber,
      String title,
      String snippet,
      int slot,
      int blockType,
      int? blockIdentifier,
      ) async {
    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    int mepsLanguageId = publication.mepsLanguage.id;

    try {
      int locationId;
      int publicationLocationId;

      if (bookNumber != null && chapterNumber != null) {
        Map<String, dynamic> location = {
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
          'Title': title
        };

        // Vérifie si l'entrée existe déjà
        final List<Map<String, dynamic>> existing = await _database.query(
          'Location',
          columns: ['LocationId'],
          where: 'BookNumber = ? AND ChapterNumber = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0',
          whereArgs: [
            bookNumber,
            chapterNumber,
            issueTagNumber,
            keySymbol,
            mepsLanguageId
          ],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          locationId = existing.first['LocationId'] as int;
        }
        else {
          locationId = await _database.insert('Location', location);
        }
      }
      else {
        Map<String, dynamic> location = {
          'DocumentId': mepsDocumentId,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
        };

        final List<Map<String, dynamic>> existing = await _database.query(
          'Location',
          columns: ['LocationId'],
          where: 'DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0',
          whereArgs: [
            mepsDocumentId,
            issueTagNumber,
            keySymbol,
            mepsLanguageId
          ],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          locationId = existing.first['LocationId'] as int;
        }
        else {
          locationId = await _database.insert('Location', location);
        }
      }

      // Vérifier si publicationLocationId existe déjà
      List<Map<String, dynamic>> existingPubLocation = await _database.query(
        'Location',
        columns: ['LocationId'],
        where:
        'IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 1',
        whereArgs: [issueTagNumber, keySymbol, mepsLanguageId],
        limit: 1,
      );

      if (existingPubLocation.isNotEmpty) {
        publicationLocationId = existingPubLocation.first['LocationId'];
      }
      else {
        publicationLocationId = await _database.insert('Location', {
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 1,
          'Title': ""
        });
      }

      await _database.insert('Bookmark', {
        'LocationId': locationId,
        'PublicationLocationId': publicationLocationId,
        'Slot': slot,
        'Title': title,
        'Snippet': snippet,
        'BlockType': blockType,
        'BlockIdentifier': blockIdentifier,
      });

      return Bookmark(
        slot: slot,
        title: title,
        snippet: snippet,
        blockType: blockType,
        blockIdentifier: blockIdentifier,
        location: Location(
            bookNumber: bookNumber,
            chapterNumber: chapterNumber,
            mepsDocumentId: mepsDocumentId,
            issueTagNumber: issueTagNumber,
            keySymbol: keySymbol,
            mepsLanguageId: publication.mepsLanguage.id,
            type: 0
        ),
      );
    } catch (e) {
      printTime('Erreur lors de l\'ajout du bookmark : $e');
      return null;
    }
  }


  Future<Bookmark?> updateBookmark(
      Publication publication,
      int slot,
      int? mepsDocumentId,
      int? bookNumber,
      int? chapterNumber,
      String title,
      String snippet,
      int blockType,
      int? blockIdentifier,
      ) async {
    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    int mepsLanguageId = publication.mepsLanguage.id;

    try {
      // 1. Rechercher le signet via les infos de publication + slot
      List<Map<String, dynamic>> existingBookmark = await _database.rawQuery('''
      SELECT Bookmark.BookmarkId
      FROM Bookmark
      JOIN Location ON Bookmark.LocationId = Location.LocationId
      WHERE 
        Bookmark.Slot = ? AND
        Location.IssueTagNumber = ? AND
        Location.KeySymbol = ? AND
        Location.MepsLanguage = ? AND
        Location.Type = 0
      LIMIT 1
    ''', [slot, issueTagNumber, keySymbol, mepsLanguageId]);

      if (existingBookmark.isEmpty) {
        printTime('Aucun signet trouvé pour cette publication et ce slot.');
        return null;
      }

      final int bookmarkId = existingBookmark.first['BookmarkId'];

      // 2. Générer le nouveau titre (comme dans addBookmark)
      String? newTitle = (bookNumber != null && chapterNumber != null)
          ? (blockIdentifier != null ? "$title:$blockIdentifier" : title)
          : null;

      int locationId;

      // 3. Gérer la nouvelle Location à utiliser (comme dans addBookmark)
      if (bookNumber != null && chapterNumber != null) {
        Map<String, dynamic> location = {
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
          'Title': title,
        };

        final List<Map<String, dynamic>> existing = await _database.query(
          'Location',
          columns: ['LocationId'],
          where:
          'BookNumber = ? AND ChapterNumber = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0',
          whereArgs: [
            bookNumber,
            chapterNumber,
            issueTagNumber,
            keySymbol,
            mepsLanguageId
          ],
          limit: 1,
        );

        locationId = existing.isNotEmpty
            ? existing.first['LocationId'] as int
            : await _database.insert('Location', location);
      } else {
        Map<String, dynamic> location = {
          'DocumentId': mepsDocumentId,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
        };

        final List<Map<String, dynamic>> existing = await _database.query(
          'Location',
          columns: ['LocationId'],
          where:
          'DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0',
          whereArgs: [
            mepsDocumentId,
            issueTagNumber,
            keySymbol,
            mepsLanguageId
          ],
          limit: 1,
        );

        locationId = existing.isNotEmpty
            ? existing.first['LocationId'] as int
            : await _database.insert('Location', location);
      }

      // 4. Vérifier ou créer PublicationLocationId
      final existingPubLocation = await _database.query(
        'Location',
        columns: ['LocationId'],
        where:
        'IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 1',
        whereArgs: [issueTagNumber, keySymbol, mepsLanguageId],
        limit: 1,
      );

      final publicationLocationId = existingPubLocation.isNotEmpty
          ? existingPubLocation.first['LocationId'] as int
          : await _database.insert('Location', {
        'IssueTagNumber': issueTagNumber,
        'KeySymbol': keySymbol,
        'MepsLanguage': mepsLanguageId,
        'Type': 1,
        'Title': ""
      });

      // 5. Mettre à jour le signet
      await _database.update(
        'Bookmark',
        {
          'LocationId': locationId,
          'PublicationLocationId': publicationLocationId,
          'Title': newTitle ?? title,
          'Snippet': snippet,
          'BlockType': blockType,
          'BlockIdentifier': blockIdentifier,
        },
        where: 'BookmarkId = ?',
        whereArgs: [bookmarkId],
      );

      // 6. Retourner le nouveau Bookmark
      return Bookmark(
        slot: slot,
        title: title,
        snippet: snippet,
        blockType: blockType,
        blockIdentifier: blockIdentifier,
        location: Location(
          bookNumber: bookNumber,
          chapterNumber: chapterNumber,
          mepsDocumentId: mepsDocumentId,
          issueTagNumber: issueTagNumber,
          keySymbol: keySymbol,
          mepsLanguageId: mepsLanguageId,
          type: 0,
        ),
      );
    } catch (e) {
      printTime('Erreur lors de la mise à jour du bookmark : $e');
      return null;
    }
  }

  Future<bool> removeBookmark(Publication publication, Bookmark bookmark) async {
    try {
      List<Map<String, dynamic>> locationResult = [];

      if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
        locationResult = await _database.rawQuery(
            '''
              SELECT Location.LocationId
              FROM Location
              LEFT JOIN Bookmark ON Location.LocationId = Bookmark.LocationId
              WHERE BookNumber = ? AND ChapterNumber = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0
              LIMIT 1
          ''',
            [
              bookmark.location.bookNumber,
              bookmark.location.chapterNumber,
              publication.issueTagNumber,
              publication.keySymbol,
              publication.mepsLanguage.id,
            ]
        );
      }
      else if(bookmark.location.mepsDocumentId != null) {
        locationResult = await _database.rawQuery(
            '''
            SELECT Location.LocationId
            FROM Location
            LEFT JOIN Bookmark ON Location.LocationId = Bookmark.LocationId
            WHERE DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0
            LIMIT 1
          ''',
            [
              bookmark.location.mepsDocumentId,
              publication.issueTagNumber,
              publication.keySymbol,
              publication.mepsLanguage.id,
            ]
        );
      }

      printTime('locationResult: $locationResult');

      if (locationResult.isEmpty) {
        printTime('Aucun emplacement trouvé pour ce signet.');
        return false;
      }

      int locationId = locationResult.first['LocationId'];

      // Supprimer le signet correspondant
      int deletedCount = await _database.delete(
        'Bookmark',
        where: 'LocationId = ? AND Slot = ?',
        whereArgs: [locationId, bookmark.slot],
      );

      if (deletedCount > 0) {
        printTime('Bookmark supprimé avec succès.');
        return true;
      }
      else {
        printTime('Aucun signet correspondant trouvé.');
        return false;
      }
    } catch (e) {
      printTime('Erreur lors de la suppression du bookmark : $e');
      return false;
    }
  }

  Future<List<Playlist>> getPlaylists({int? limit}) async {
    String limitClause = '';
    if (limit != null) {
      limitClause = 'LIMIT $limit';
    }

    // Utilisation d'une CTE pour trouver le PlaylistItemId associé à la Position minimale (0, 1, etc.) pour chaque TagId
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    WITH MinPositionMap AS (
      SELECT 
        TagId, 
        PlaylistItemId, 
        Position
      FROM TagMap
      -- Utilisation d'une fonction fenêtre pour classer les éléments TagMap par position dans chaque groupe de TagId
      WHERE Position = (
        SELECT MIN(Position) 
        FROM TagMap AS TM_Inner 
        WHERE TM_Inner.TagId = TagMap.TagId
      )
    )
    SELECT 
      Tag.TagId, 
      Tag.Name,
      PlaylistItem.ThumbnailFilePath
    FROM Tag
    LEFT JOIN MinPositionMap ON Tag.TagId = MinPositionMap.TagId
    LEFT JOIN PlaylistItem ON MinPositionMap.PlaylistItemId = PlaylistItem.PlaylistItemId
    WHERE Tag.Type = 2
    $limitClause
  ''');

    return result.map((playlist) => Playlist.fromMap(playlist)).toList();
  }

  Future<List<PlaylistItem>> getPlaylistItemByPlaylistId(int playlistId, {Database? database}) async {
    Database db = database ?? _database;
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        PlaylistItem.*,
        TagMap.Position,
        Location.*,
        IndependentMedia.*,
        PlaylistItemIndependentMediaMap.DurationTicks,
        PlaylistItemLocationMap.MajorMultimediaType,
        PlaylistItemLocationMap.BaseDurationTicks,
    
        -- Colonnes du thumbnail (jointure supplémentaire)
        ThumbnailMedia.OriginalFileName AS ThumbnailOriginalFileName,
        ThumbnailMedia.FilePath AS ThumbnailFilePath,
        ThumbnailMedia.MimeType AS ThumbnailMimeType,
        ThumbnailMedia.Hash AS ThumbnailHash
    
      FROM PlaylistItem
      INNER JOIN TagMap 
        ON PlaylistItem.PlaylistItemId = TagMap.PlaylistItemId
      INNER JOIN Tag 
        ON TagMap.TagId = Tag.TagId
      LEFT JOIN PlaylistItemLocationMap 
        ON PlaylistItem.PlaylistItemId = PlaylistItemLocationMap.PlaylistItemId
      LEFT JOIN Location 
        ON PlaylistItemLocationMap.LocationId = Location.LocationId
      LEFT JOIN PlaylistItemIndependentMediaMap 
        ON PlaylistItem.PlaylistItemId = PlaylistItemIndependentMediaMap.PlaylistItemId
      LEFT JOIN IndependentMedia 
        ON PlaylistItemIndependentMediaMap.IndependentMediaId = IndependentMedia.IndependentMediaId
    
      -- Jointure pour récupérer le thumbnail
      LEFT JOIN IndependentMedia AS ThumbnailMedia ON PlaylistItem.ThumbnailFilePath = ThumbnailMedia.FilePath
    
      WHERE Tag.TagId = ?
      ORDER BY TagMap.Position ASC;
    ''', [playlistId]);

    return result.map((map) => PlaylistItem.fromMap(map)).toList();
  }

  Future<void> reorderPlaylistItemInPlaylist(int playlistId, List<int> playlistItemIdsInNewOrder) async {
    print(playlistId);
    print(playlistItemIdsInNewOrder);

    await _database.transaction((txn) async {
      // --- 1. Dégager toutes les positions pour éviter les conflits UNIQUE ---
      for (int i = 0; i < playlistItemIdsInNewOrder.length; i++) {
        final int noteId = playlistItemIdsInNewOrder[i];

        // Attribuer une position temporaire négative (ex: -1, -2, -3...)
        // Ce Position Id temporaire doit aussi être UNIQUE pour éviter une autre violation.
        final int tempPosition = -(i + 1);

        final Map<String, dynamic> tempValues = {
          'Position': tempPosition,
        };

        await txn.update(
          'TagMap',
          tempValues,
          where: 'TagId = ? AND PlaylistItemId = ?',
          whereArgs: [playlistId, noteId],
        );
      }

      // --- 2. Ranger toutes les positions à leur valeur finale correcte ---
      for (int i = 0; i < playlistItemIdsInNewOrder.length; i++) {
        final int noteId = playlistItemIdsInNewOrder[i];
        final int newPosition = i;

        final Map<String, dynamic> finalValues = {
          'Position': newPosition,
        };

        // Exécution de la mise à jour sur la table TagMap
        await txn.update(
          'TagMap',
          finalValues,
          where: 'TagId = ? AND PlaylistItemId = ?',
          whereArgs: [playlistId, noteId],
        );
      }
    });
  }

  Future<bool> _isIndependentMediaUsedElsewhere({
    required String filePath,
    required int excludedPlaylistItemId}) async {

    // Le média peut être soit le média principal, soit le thumbnail d'un autre item.
    final List<Map<String, Object?>> results = await _database.rawQuery('''
      SELECT
        PlaylistItemId
      FROM
        PlaylistItem
      WHERE
        ThumbnailFilePath = ?
        AND PlaylistItemId != ?
  
      UNION ALL
  
      SELECT
        T1.PlaylistItemId
      FROM
        PlaylistItemIndependentMediaMap AS T1
      LEFT JOIN
        IndependentMedia AS T2
        ON T1.IndependentMediaId = T2.IndependentMediaId
      WHERE
        T2.FilePath = ?
        AND T1.PlaylistItemId != ?
  
      LIMIT 1;
    ''', [
      // Paramètres pour la première partie (Thumbnail)
      filePath,
      excludedPlaylistItemId,
      // Paramètres pour la deuxième partie (IndependentMedia)
      filePath,
      excludedPlaylistItemId
    ]);

    return results.isNotEmpty;
  }

  Future<void> deletePlaylistItem(PlaylistItem playlistItem) async {
    final id = playlistItem.playlistItemId;

    // 1. Supprimer les liaisons dans PlaylistItemIndependentMediaMap
    await _database.delete(
      'PlaylistItemIndependentMediaMap',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // 2. Gestion du média principal (IndependentMedia)
    if (playlistItem.independentMedia != null && !playlistItem.independentMedia!.isNull()) {
      final media = playlistItem.independentMedia!;

      // VÉRIFICATION : Est-ce que ce média est utilisé par un autre PlaylistItem ?
      final isUsedElsewhere = await _isIndependentMediaUsedElsewhere(
        filePath: media.filePath!,
        excludedPlaylistItemId: id, // id est non null ici
      );

      if (!isUsedElsewhere) {
        // S'il n'est utilisé nulle part ailleurs, on le supprime de la DB et du système de fichiers
        await _database.delete(
          'IndependentMedia',
          where: 'Hash = ? AND FilePath = ?',
          whereArgs: [media.hash, media.filePath],
        );

        // Supprimer le fichier
        media.removeMediaFile();
      }
    }

    // 3. Supprimer les liaisons dans PlaylistItemLocationMap
    await _database.delete(
      'PlaylistItemLocationMap',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // 4. Gestion de la vignette (thumbnail)
    if (playlistItem.thumbnail != null && !playlistItem.thumbnail!.isNull()) {
      final thumbnail = playlistItem.thumbnail!;

      // VÉRIFICATION : Est-ce que ce thumbnail est utilisé par un autre PlaylistItem ?
      final isUsedElsewhere = await _isIndependentMediaUsedElsewhere(
        filePath: thumbnail.filePath!,
        excludedPlaylistItemId: id, // id est non null ici
      );

      if (!isUsedElsewhere) {
        // S'il n'est utilisé nulle part ailleurs, on le supprime de la DB et du système de fichiers
        await _database.delete(
          'IndependentMedia',
          where: 'Hash = ? AND FilePath = ?',
          whereArgs: [thumbnail.hash, thumbnail.filePath],
        );

        // Supprimer le fichier
        thumbnail.removeMediaFile();
      }
    }

    // 5. Supprimer les TagMap liés au PlaylistItem
    await _database.delete(
      'TagMap',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // 6. Enfin, supprimer le PlaylistItem
    await _database.delete(
      'PlaylistItem',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );
  }

  Future<void> renamePlaylistItem(PlaylistItem item, String name) async {
    // Met à jour la base
    await _database.update(
      'PlaylistItem',
      {'Label': name},
      where: 'PlaylistItemId = ?',
      whereArgs: [item.playlistItemId],
    );

    // Met à jour l'objet en mémoire
    item.label = name;
  }


  Future<IndependentMedia> insertThumbnailInPlaylist(String filePath) async {
    String mimeType = lookupMimeType(filePath) ?? 'image/jpeg';
    final Directory userDataDir = await getAppUserDataDirectory();
    final Uuid uuid = Uuid();
    late img.Image thumbnail;

    final String nameWithoutExtension = path.basenameWithoutExtension(filePath);


    Uint8List? imageBytes;

    // --- Si le fichier existe ou est distant ---
    if (filePath.isNotEmpty) {
      // Charger les bytes selon la source
      if (filePath.startsWith('https')) {
        final http.Response response = await http.get(Uri.parse(filePath));
        imageBytes = response.bodyBytes;
      }
      else {
        imageBytes = await File(filePath).readAsBytes();
      }

      // --- Si c’est une image classique ---
      if (mimeType.startsWith('image/')) {
        final img.Image? originalImage = img.decodeImage(imageBytes);
        if (originalImage == null) throw Exception("Impossible de décoder l'image source");
        thumbnail = resizeAndCropCenter(originalImage, 250);
      }

      // --- Si c’est un audio ou vidéo → lire la vignette depuis les métadonnées ---
      else if (mimeType.startsWith('audio/') || mimeType.startsWith('video/')) {
        Uint8List? embeddedPicture = await AudioInfo.getAudioImage(filePath);

        if (embeddedPicture != null) {
          // Image d’album trouvée
          final img.Image? cover = img.decodeImage(embeddedPicture);
          //mimeType = metadata.pictures.first.mimetype;

          if (cover == null) throw Exception("Impossible de décoder l'image d'album");
          thumbnail = resizeAndCropCenter(cover, 250);
        }
        else {
          // Pas d’image → fallback par défaut
          final defaultPath = '${userDataDir.path}/default_thumbnail.png';
          final defaultBytes = await File(defaultPath).readAsBytes();
          final img.Image? defaultImage = img.decodeImage(defaultBytes);
          thumbnail = img.copyResize(defaultImage!, width: 250, height: 250);
        }
      }

      // --- Sinon (autre type de fichier) ---
      else {
        final defaultPath = '${userDataDir.path}/default_thumbnail.png';
        final defaultBytes = await File(defaultPath).readAsBytes();
        final img.Image? defaultImage = img.decodeImage(defaultBytes);
        thumbnail = img.copyResize(defaultImage!, width: 250, height: 250);
      }
    }

    // --- Si path est vide : miniature par défaut ---
    else {
      final defaultPath = '${userDataDir.path}/default_thumbnail.png';
      final defaultBytes = await File(defaultPath).readAsBytes();
      final img.Image? defaultImage = img.decodeImage(defaultBytes);
      if (defaultImage == null) throw Exception("Impossible de décoder l'image par défaut");
      thumbnail = img.copyResize(defaultImage, width: 250, height: 250);
    }

    // --- Sauvegarde du thumbnail ---
    final String thumbnailName = uuid.v4();
    final String thumbnailPath = '${userDataDir.path}/$thumbnailName';
    final File thumbnailFile = File(thumbnailPath);

    // ✅ Écrit réellement le fichier
    await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail));

    // --- Calcul du hash ---
    final String hash = await sha256hashOfFile(thumbnailPath);

    // --- Insertion dans la base ---
    await _database.insert(
      'IndependentMedia',
      {
        'OriginalFilename': nameWithoutExtension,
        'FilePath': thumbnailName,
        'MimeType': 'image/jpeg',
        'Hash': hash,
      },
    );

    // --- Retour ---
    return IndependentMedia(
      originalFileName: nameWithoutExtension,
      filePath: thumbnailName,
      mimeType: 'image/jpeg',
      hash: hash,
    );
  }

  Future<int> insertIndependentMediaInPlaylist(Playlist playlist, String filepath) async {
    printTime('FILE PATH : $filepath');
    // Type MIME et extension
    final String mimeType = lookupMimeType(filepath) ?? 'image/jpeg';
    final String fileExtension = filepath.split('.').last;

    // Miniature
    final IndependentMedia thumbnail = await insertThumbnailInPlaylist(filepath);

    // Fichier d’origine et dossier utilisateur
    final File originalFile = File(filepath);
    final Directory userDataDir = await getAppUserDataDirectory();

    // Copie du fichier avec nom unique
    final String independentMediaName = '${Uuid().v4()}.$fileExtension';
    final String independentMediaPath = '${userDataDir.path}/$independentMediaName';
    await originalFile.copy(independentMediaPath);

    // Hash du fichier
    final String hash = await sha256hashOfFile(independentMediaPath);

    // Création de l’objet IndependentMedia
    final IndependentMedia independentMedia = IndependentMedia(
      originalFileName: originalFile.uri.pathSegments.last,
      filePath: independentMediaName,
      mimeType: mimeType,
      hash: hash,
    );

    // Durée par défaut (images = 4s)
    int durationTicks = 40000000;

    // Si audio ou vidéo → récupérer la durée réelle
    if (mimeType.startsWith('audio/')) {
      AudioData? audioInfo = await AudioInfo.getAudioInfo(filepath);
      if(audioInfo == null) return -1;
      print(audioInfo.duration);

      durationTicks = int.parse(audioInfo.duration) * 10000;
    }
    else if(mimeType.startsWith('video/')) {
      VideoData? videoInfo = await FlutterVideoInfo().getVideoInfo(filepath);
      if (videoInfo == null || videoInfo.duration == null) return -1;

      durationTicks = (videoInfo.duration! * 10000).toInt();
    }

    // Création de l’élément de playlist
    final PlaylistItem playlistItem = PlaylistItem(
      playlistItemId: -1,
      label: originalFile.uri.pathSegments.last,
      thumbnail: thumbnail,
      independentMedia: independentMedia,
      durationTicks: durationTicks,
    );

    // Insertion dans la playlist
    return insertPlaylistItem(playlistItem, playlist: playlist);
  }

  Future<int> insertMediaItemInPlaylist(Playlist playlist, Media media) async {
    IndependentMedia thumbnail = await insertThumbnailInPlaylist(media.networkImageSqr ?? media.networkImageLsr ?? '');

    PlaylistItem playlistItem = PlaylistItem(
        playlistItemId: -1,
        label: media.title,
        thumbnail: thumbnail,
        majorMultimediaType: media is Video ? 2 : 0,
        baseDurationTicks: durationSecondsToTicks(media.duration),
        location: Location(
          keySymbol: media.keySymbol,
          track: media.track,
          mepsDocumentId: media.documentId,
          issueTagNumber: media.issueTagNumber,
          mepsLanguageId: 3,
          type: media is Audio ? 2 : 3,
        ),
        independentMedia: null,
    );

    return insertPlaylistItem(playlistItem, playlist: playlist);
  }

  Future<int> insertPlaylistItem(PlaylistItem playlistItem, {required Playlist playlist, Database? db}) async {
    Database database = db ?? _database;
    return await database.transaction<int>((txn) async {
      // 1️⃣ Insérer thumbnail(ou ignorer si existe) IndependentMedia
      if (playlistItem.thumbnail != null) {
        if(!playlistItem.thumbnail!.isNull()) {
          // Vérifier si le média existe déjà par hash ou FilePath
          final existingMedia = await txn.query(
            'IndependentMedia',
            where: 'Hash = ? AND FilePath = ?',
            whereArgs: [playlistItem.thumbnail!.hash, playlistItem.thumbnail!.filePath],
            limit: 1,
          );

          if (existingMedia.isNotEmpty) {
            existingMedia.first['IndependentMediaId'] as int;
          }
          else {
            await txn.insert(
              'IndependentMedia',
              {
                'OriginalFilename': playlistItem.thumbnail!.originalFileName,
                'FilePath': playlistItem.thumbnail!.filePath,
                'MimeType': playlistItem.thumbnail!.mimeType,
                'Hash': playlistItem.thumbnail!.hash,
              },
            );
          }
        }
      }

      // 2️⃣ Insérer PlaylistItem
      final playlistItemId = await txn.insert(
        'PlaylistItem',
        {
          'Label': playlistItem.label ?? '',
          'StartTrimOffsetTicks': playlistItem.startTrimOffsetTicks,
          'EndTrimOffsetTicks': playlistItem.endTrimOffsetTicks,
          'Accuracy': playlistItem.accuracy,
          'EndAction': playlistItem.endAction,
          'ThumbnailFilePath': playlistItem.thumbnail!.filePath,
        },
      );

      int? independentMediaId;
      if (playlistItem.independentMedia != null) {
        if(!playlistItem.independentMedia!.isNull()) {
          // Vérifier si le média existe déjà par hash ou FilePath
          final existingMedia = await txn.query(
            'IndependentMedia',
            where: 'Hash = ? AND FilePath = ?',
            whereArgs: [playlistItem.independentMedia!.hash, playlistItem.independentMedia!.filePath],
            limit: 1,
          );

          if (existingMedia.isNotEmpty) {
            independentMediaId = existingMedia.first['IndependentMediaId'] as int;
          }
          else {
            independentMediaId = await txn.insert(
              'IndependentMedia',
              {
                'OriginalFilename': playlistItem.independentMedia!.originalFileName,
                'FilePath': playlistItem.independentMedia!.filePath,
                'MimeType': playlistItem.independentMedia!.mimeType,
                'Hash': playlistItem.independentMedia!.hash,
              },
            );
          }
        }
      }

      // Récupérer la dernière position
      final maxPositionResult = await txn.query(
        'TagMap',
        where: 'TagId = ?',
        whereArgs: [playlist.id],
        orderBy: 'Position DESC',
        limit: 1,
      );

      // Vérifier si un résultat existe pour cette catégorie
      int newPosition = 0;  // Si aucune position n'existe, commencer à 0
      if (maxPositionResult.isNotEmpty) {
        // Convertir 'Position' en int avant d'incrémenter
        newPosition = (maxPositionResult.first['Position'] as int) + 1;
      }

      // 3️⃣ Insérer TagMap (position dans playlist)
      await txn.insert(
        'TagMap',
        {
          'PlaylistItemId': playlistItemId,
          'TagId': playlist.id,
          'Position': newPosition,
        },
      );

      // 4️⃣ Lier IndependentMedia (si inséré ou existant)
      if (independentMediaId != null) {
        await txn.insert(
          'PlaylistItemIndependentMediaMap',
          {
            'PlaylistItemId': playlistItemId,
            'IndependentMediaId': independentMediaId,
            'DurationTicks': playlistItem.durationTicks ?? 40000000,
          },
        );
      }

      // 5️⃣ Lier Location si présente
      if (playlistItem.location != null) {
        int? locationId = await insertLocation(null, null,
            playlistItem.location!.mepsDocumentId,
            playlistItem.location!.track,
            playlistItem.location!.issueTagNumber,
            playlistItem.location!.keySymbol,
            playlistItem.location!.mepsLanguageId,
            type: playlistItem.location!.type,
            transaction: txn
        );
        if (locationId != null && locationId != -1) {
          await txn.insert(
            'PlaylistItemLocationMap',
            {
              'PlaylistItemId': playlistItemId,
              'LocationId': locationId,
              'MajorMultimediaType': playlistItem.majorMultimediaType, // adapter si besoin
              'BaseDurationTicks': playlistItem.baseDurationTicks ?? 0,
            },
          );
        }
      }

      return playlistItemId;
    });
  }

  Future<PlaylistItem> updateEndActionPlaylistItem(PlaylistItem playlistItem, int endAction) async {
    await _database.update(
      'PlaylistItem',
      {'EndAction': endAction},
      where: 'PlaylistItemId = ?',
      whereArgs: [playlistItem.playlistItemId],
    );

    playlistItem.endAction = endAction;

    return playlistItem;
  }

  Future<void> updatePositionPlaylistItem(Playlist playlist, PlaylistItem playlistItem, int position) async {
    final rowsAffected = await _database.update(
      'TagMap',
      {'Position': position},
      where: 'TagId = ? AND PlaylistItemId = ?',
      whereArgs: [playlist.id, playlistItem.playlistItemId],
    );

    playlistItem.position = position;

    if (rowsAffected == 0) {
      throw Exception('Update failed: TagMap entry not found for TagId=${playlist.id} and PlaylistItemId=${playlistItem.playlistItemId}.');
    }
  }

  Future<PlaylistItem> updateThumbnailPlaylistItem(PlaylistItem playlistItem, File thumbnailFile) async {
    await _database.update(
      'PlaylistItem',
      {'ThumbnailFilePath': thumbnailFile.path},
      where: 'PlaylistItemId = ?',
      whereArgs: [playlistItem.playlistItemId],
    );

    playlistItem.thumbnail!.filePath = thumbnailFile.path;

    return playlistItem;
  }

  /// TOUTES LES FONCTIONALITÉS EN PLUS DE JW LIFE DANS LE MEME USERDATA QUE JW LIBRARY

  Future<List<Congregation>> getCongregations() async {
    final List<Map<String, dynamic>> maps = await _database.query('Congregation');
    return maps.map((map) => Congregation.fromMap(map)).toList();
  }

  Future<int> insertCongregation(Congregation congregation) async {
    printTime("insertCongregation");
    return await _database.insert(
      'Congregation',
      congregation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCongregation(String guid, Congregation congregation) async {
    return await _database.update(
      'Congregation',
      congregation.toMap(),
      where: 'Guid = ?',
      whereArgs: [guid],
    );
  }

  Future<int> deleteCongregation(String guid) async {
    return await _database.delete(
      'Congregation',
      where: 'Guid = ?',
      whereArgs: [guid],
    );
  }

  Future<String> getLastModifiedDate() async {
    try {
      List<Map<String, dynamic>> result = await _database.rawQuery(
        'SELECT LastModified FROM LastModified',
      );
      return result.first['LastModified'];
    }
    catch (e) {
      printTime('Error: $e ⚠️');
    }
    return formattedTimestamp;
  }

  /// Cherche un nom de playlist unique en ajoutant un suffixe (2), (3), etc. si nécessaire.
  Future<String> _getUniquePlaylistName(String baseName) async {
    String uniqueName = baseName;
    int counter = 1;

    // Chercher les playlists existantes avec un nom similaire
    // On suppose que la base de données _database est initialisée et accessible ici.
    List<Map<String, Object?>> existingNames = await _database.rawQuery('''
      SELECT Name 
      FROM Tag 
      WHERE Type = 2 AND Name LIKE ?
    ''', ['$baseName%']); // Commence par le nom de base

    // Stocker tous les noms exacts ou numérotés existants pour la vérification
    Set<String> takenNames = existingNames.map((row) => row['Name'] as String).toSet();

    // Boucle pour trouver un nom non utilisé (ex: "Ma Playlist", "Ma Playlist (2)", etc.)
    while (takenNames.contains(uniqueName)) {
      counter++;
      uniqueName = '$baseName ($counter)';
    }

    return uniqueName;
  }

  Future<Playlist?> importPlaylistFromFile(File file) async {
    Playlist? playlist;
    try {
      // 1) (Re)création du dossier user data
      final Directory userDataDir = await getAppUserDataDirectory();
      if (!await userDataDir.exists()) {
        await userDataDir.create(recursive: true);
      }

      // 2) Dézipper l'archive
      final List<int> bytes = await file.readAsBytes();
      // La classe ZipDecoder() doit être importée d'un package comme 'archive'
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      File? jwPlaylistDbFile;

      for (final ArchiveFile archiveFile in archive) {
        final newFile = File('${userDataDir.path}/${archiveFile.name}');
        if (archiveFile.isFile) {
          if (archiveFile.name == 'userData.db') {
            final Directory tempDir = await getAppCacheDirectory();
            jwPlaylistDbFile = File('${tempDir.path}/userData.db');
            await jwPlaylistDbFile.create(recursive: true);
            await jwPlaylistDbFile.writeAsBytes(archiveFile.content as List<int>);
          } else if (archiveFile.name != 'manifest.json') {
            await newFile.create(recursive: true);
            await newFile.writeAsBytes(archiveFile.content as List<int>);
          }
        } else {
          await Directory(newFile.path).create(recursive: true);
        }
      }

      // 3) Si on a une base à importer : fusion "replace"
      if (jwPlaylistDbFile != null) {
        final Database jwPlaylistDb = await openDatabase(jwPlaylistDbFile.path);

        // Chercher la première playlist
        final List<Map<String, Object?>> firstPlaylistResult = await jwPlaylistDb.rawQuery('''
          SELECT TagId, Name 
          FROM Tag 
          ORDER BY TagId ASC 
          LIMIT 1
        ''');

        if (firstPlaylistResult.isEmpty) {
          await jwPlaylistDb.close();
          return playlist;
        }

        final int? playlistItemId = firstPlaylistResult.first['TagId'] as int?;
        final String? playlistName = firstPlaylistResult.first['Name'] as String?;

        if (playlistItemId == null || playlistName == null) {
          await jwPlaylistDb.close();
          return playlist;
        }

        final List<PlaylistItem> playlistItems = await getPlaylistItemByPlaylistId(playlistItemId, database: jwPlaylistDb);

        await jwPlaylistDb.close();

        try {
          // 🔹 1. Vérification et renommage de la playlist si nécessaire pour obtenir un nom unique
          final String finalPlaylistName = await _getUniquePlaylistName(playlistName);

          // 🔹 2. Insertion directe du Tag sans transaction avec le nom unique
          final int tagId = await _database.rawInsert('''
            INSERT INTO Tag (Type, Name)
            VALUES (?, ?)
          ''', [2, finalPlaylistName]); // Utiliser le nom unique ici

          playlist = Playlist(
            id: tagId,
            type: 2,
            name: finalPlaylistName,
          );

          for (final PlaylistItem playlistItem in playlistItems) {
            await insertPlaylistItem(playlistItem, playlist: playlist);
          }

          printTime('✅ Playlist "$finalPlaylistName" importée avec succès.');
        }
        catch (e) {
          printTime('Error during import insert: $e');
          rethrow;
        }

        // 4) Nettoyage du fichier temporaire
        try {
          if (await jwPlaylistDbFile.exists()) {
            await jwPlaylistDbFile.delete();
          }
        }
        catch (cleanupError) {
          printTime('⚠️ Warning: Could not cleanup temp file: $cleanupError');
        }
      }
    }
    catch (e, st) {
      // ✅ Bloc manquant — capture de toute erreur globale
      printTime('❌ Error while importing playlist: $e');
      printTime('Stack trace: $st');
    }

    return playlist;
  }

  Future<File?> exportPlaylistToFile(Playlist playlist, {List<PlaylistItem>? items}) async {
    // 1. Charger les éléments si non fournis
    items ??= await getPlaylistItemByPlaylistId(playlist.id);

    // 2. Créer un répertoire temporaire propre
    final appCache = await getAppCacheDirectory();
    final tempDir = Directory(path.join(appCache.path, 'playlist'));

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    // 3. Copier la base modèle vers le répertoire
    final dbPath = path.join(tempDir.path, 'userData.db');

    Database? db;
    try {
      db = await openDatabase(dbPath, version: schemaVersion, onCreate: (db, version) async {
        await createDbUserdata(db);
      });

      // 4. Créer le Tag (Playlist)
      final int tagId = await db.rawInsert(
        'INSERT INTO Tag (Type, Name) VALUES (?, ?)',
        [2, playlist.name],
      );

      final Playlist newPlaylist = Playlist(
        id: tagId,
        type: 2,
        name: playlist.name,
      );

      // 5. Insérer les éléments
      for (final PlaylistItem playlistItem in items) {
        await insertPlaylistItem(playlistItem, playlist: newPlaylist, db: db);

        // --- Copier les fichiers associés ---
        final IndependentMedia thumbnail = playlistItem.thumbnail!;
        final IndependentMedia? independentMedia = playlistItem.independentMedia;

        final File thumbnailSourceFile = await thumbnail.getMediaFile();
        final String thumbnailDestPath = path.join(tempDir.path, path.basename(thumbnailSourceFile.path));

        try {
          await thumbnailSourceFile.copy(thumbnailDestPath);
        } catch (e) {
          printTime('⚠️ Erreur copie thumbnail: $e');
        }

        if (independentMedia != null) {
          try {
            final File mediaFile = await independentMedia.getMediaFile();
            final String mediaDestPath = path.join(tempDir.path, path.basename(mediaFile.path));
            await mediaFile.copy(mediaDestPath);
          }
          catch (e) {
            printTime('⚠️ Erreur copie média: $e');
          }
        }
      }

      await db.close();

      // 6. Création de l’archive ZIP (.jwlplaylist)
      final Archive archive = Archive();
      final String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String deviceName = await _getDeviceName();
      final String fileName = '${playlist.name}.jwlplaylist';

      final DateTime currentTimestamp = DateTime.now().toUtc();
      final String formattedTimestamp = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(currentTimestamp);

      final File userDataFile = File(dbPath);

      printTime('Calcul du hash...');
      final String hash = await sha256hashOfFile(userDataFile.path);
      printTime('Hash calculé : $hash');

      // Ajouter tous les fichiers du répertoire
      final List<FileSystemEntity> files = tempDir.listSync(recursive: true);
      for (var entity in files) {
        if (entity is File) {
          final String baseName = path.basename(entity.path);
          if (!baseName.endsWith('manifest.json')) {
            try {
              final List<int> fileBytes = await entity.readAsBytes();
              archive.addFile(ArchiveFile(baseName, fileBytes.length, fileBytes));
            } catch (e) {
              printTime('⚠️ Erreur lecture fichier $baseName : $e');
            }
          }
        }
      }

      final int version = await _database.getVersion();

      // Manifest JSON
      final Map<String, dynamic> manifestData = {
        "name": fileName,
        "creationDate": currentDate,
        "version": 1,
        "type": 1,
        "userDataBackup": {
          "lastModifiedDate": formattedTimestamp,
          "deviceName": deviceName,
          "databaseName": "userData.db",
          "hash": hash,
          "schemaVersion": version,
        }
      };

      final String manifestJson = jsonEncode(manifestData);
      archive.addFile(ArchiveFile('manifest.json', manifestJson.length, utf8.encode(manifestJson)));

      // Encodage ZIP
      final Uint8List bytes = Uint8List.fromList(
        ZipEncoder().encode(archive, level: DeflateLevel.defaultCompression),
      );

      // Sauvegarde finale du .jwlplaylist
      final File outputFile = File(path.join(appCache.path, fileName));
      await outputFile.writeAsBytes(bytes);

      printTime('✅ Export terminé avec succès : ${outputFile.path}');
      return outputFile;
    }
    catch (e) {
      printTime('❌ Erreur lors de l’export : $e');

      // Nettoyage en cas d’échec
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
    finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  Future<bool> importBackup(File file) async {
    try {
      Directory userDataDir = await getAppUserDataDirectory();
      if (await userDataDir.exists()) {
        await userDataDir.delete(recursive: true);
      }
      await userDataDir.create(recursive: true);

      List<int> bytes = file.readAsBytesSync();
      Archive archive = ZipDecoder().decodeBytes(bytes);
      for (ArchiveFile archiveFile in archive) {
        File newFile = File('${userDataDir.path}/${archiveFile.name}');
        await newFile.writeAsBytes(archiveFile.content);
      }

      File userDataFile = File('${userDataDir.path}/userData.db');
      if (await userDataFile.exists()) {
        printTime('Importation du fichier UserData');
        await reload_db();
        return true;
      }
    }
    catch (e) {
      printTime('Erreur lors du traitement du fichier UserData : $e');
      return false;
    }
    return false;
  }

  Future<File?> exportBackup() async {
    printTime('Début de l\'exportation...');

    // Vérifier que la base de données est ouverte
    if (!_database.isOpen) {
      printTime('Erreur : Base de données non ouverte');
      return null;
    }

    // Demander la permission de stockage
    PermissionStatus status = await Permission.manageExternalStorage.request();

    if (!status.isGranted) {
      printTime('Permission de stockage non accordée.');
      return null;
    }

    try {
      Directory userDataDir = await getAppUserDataDirectory();
      if (!await userDataDir.exists()) {
        printTime('Le répertoire de données utilisateur n\'existe pas.');
        return null;
      }

      // Créer un répertoire temporaire pour la sauvegarde
      final tempDir = await getAppCacheDirectory();
      final tempBackupDir = Directory('${tempDir.path}/backup_${DateTime.now().millisecondsSinceEpoch}');
      await tempBackupDir.create();

      Archive archive = Archive();
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String deviceName = await _getDeviceName();
      String fileName = 'UserdataBackup_${currentDate}_$deviceName.jwlibrary';

      String lastModifiedDate = await getLastModifiedDate();
      printTime('LastModifiedDate: $lastModifiedDate');
      File userDataFile = File('${userDataDir.path}/userData.db');

      // Calculer le hash de la copie propre
      printTime('Calcul du hash...');
      String hash = await sha256hashOfFile(userDataFile.path);
      printTime('Hash calculé : $hash');

      // Ajouter la base de données propre à l'archive
      printTime('Ajout de la DB à l\'archive...');
      List<int> dbBytes = await userDataFile.readAsBytes();
      archive.addFile(ArchiveFile('userData.db', dbBytes.length, dbBytes));
      printTime('DB ajoutée à l\'archive (${dbBytes.length} bytes)');

      // Ajouter les autres fichiers du répertoire (sauf manifest.json et la DB originale)
      List<FileSystemEntity> files = userDataDir.listSync(recursive: true);
      for (var fileEntity in files) {
        if (fileEntity is File) {
          String filePath = fileEntity.path;
          String fileName = path.basename(filePath);

          // Ignorer manifest.json et userData.db (on utilise la copie propre)
          if (!fileName.endsWith('manifest.json') && !fileName.startsWith('userData.db')) {
            try {
              List<int> fileBytes = await File(filePath).readAsBytes();
              archive.addFile(ArchiveFile(fileName, fileBytes.length, fileBytes));
            } catch (e) {
              printTime('Erreur lors de la lecture du fichier $filePath : $e');
            }
          }
        }
      }

      int version = await _database.getVersion();

      Map<String, dynamic> manifestData = {
        "name": fileName,
        "creationDate": currentDate,
        "version": 1,
        "type": 0,
        "userDataBackup": {
          "lastModifiedDate": lastModifiedDate,
          "deviceName": deviceName,
          "databaseName": "userData.db",
          "hash": hash,
          "schemaVersion": version,
        }
      };
      String manifestJson = jsonEncode(manifestData);
      archive.addFile(ArchiveFile('manifest.json', manifestJson.length, utf8.encode(manifestJson)));

      Uint8List bytes = Uint8List.fromList(ZipEncoder().encode(archive, level: DeflateLevel.defaultCompression));

      // Enregistrer le fichier final
      final filePath = '${tempDir.path}/$fileName';
      final outputFile = File(filePath);
      await outputFile.writeAsBytes(bytes);

      // Nettoyer le répertoire temporaire de sauvegarde
      await tempBackupDir.delete(recursive: true);

      return outputFile;
    }
    catch (e, stackTrace) {
      printTime('Erreur lors de l\'exportation de la sauvegarde : $e');
      printTime('Stack trace : $stackTrace');
    }
    return null;
  }

  Future<String> _getDeviceName() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer}_${androidInfo.model}'; // Nom du modèle de l'appareil Android
      }
      else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name; // Nom de l'appareil iOS
      }
      else {
        return '';
      }
    }
    catch (e) {
      return '';
    }
  }

  Future<void> deleteBackup() async {
    await _database.close();
    Directory userDataDir = await getAppUserDataDirectory();
    if (await userDataDir.exists()) {
      await userDataDir.delete(recursive: true);
    }

    await CopyAssets.copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png');

    await reload_db();
  }

  Future<void> createDbUserdata(Database db) async {
    return await db.transaction((txn) async {

      // --- 1. Création de TOUTES les tables (Un appel par table) ---

      // Table BlockRange
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "BlockRange" (
          "BlockRangeId"  INTEGER NOT NULL,
          "BlockType" INTEGER NOT NULL,
          "Identifier"  INTEGER NOT NULL,
          "StartToken"  INTEGER,
          "EndToken"  INTEGER,
          "UserMarkId"  INTEGER NOT NULL,
          PRIMARY KEY("BlockRangeId"),
          FOREIGN KEY("UserMarkId") REFERENCES "UserMark"("UserMarkId"),
          CHECK("BlockType" BETWEEN 1 AND 2)
        );
      """);

      // Table Bookmark
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Bookmark" (
          "BookmarkId"  INTEGER NOT NULL,
          "LocationId"  INTEGER NOT NULL,
          "PublicationLocationId" INTEGER NOT NULL,
          "Slot"  INTEGER NOT NULL,
          "Title" TEXT NOT NULL,
          "Snippet" TEXT,
          "BlockType" INTEGER NOT NULL DEFAULT 0,
          "BlockIdentifier" INTEGER,
          PRIMARY KEY("BookmarkId"),
          CONSTRAINT "PublicationLocationId_Slot" UNIQUE("PublicationLocationId","Slot"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId"),
          FOREIGN KEY("PublicationLocationId") REFERENCES "Location"("LocationId"),
          CHECK(("BlockType" = 0 AND "BlockIdentifier" IS NULL) OR (("BlockType" BETWEEN 1 AND 2) AND "BlockIdentifier" IS NOT NULL))
        );
      """);

      // Table Congregation
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Congregation" (
          "CongregationId"  INTEGER NOT NULL,
          "Guid"  TEXT NOT NULL,
          "Name"  TEXT NOT NULL,
          "Address" TEXT,
          "LanguageCode"  TEXT NOT NULL,
          "Latitude"  REAL NOT NULL,
          "Longitude" REAL NOT NULL,
          "WeekendWeekday"  INTEGER,
          "WeekendTime" TEXT,
          "MidweekWeekday"  INTEGER,
          "MidweekTime" TEXT,
          PRIMARY KEY("CongregationId")
        );
      """);

      // Table IndependentMedia
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "IndependentMedia" (
          "IndependentMediaId"  INTEGER NOT NULL,
          "OriginalFilename"  TEXT NOT NULL,
          "FilePath"  TEXT NOT NULL UNIQUE,
          "MimeType"  TEXT NOT NULL,
          "Hash"  TEXT NOT NULL,
          PRIMARY KEY("IndependentMediaId"),
          CHECK(length("OriginalFilename") > 0),
          CHECK(length("FilePath") > 0),
          CHECK(length("MimeType") > 0),
          CHECK(length("Hash") > 0)
        );
      """);

      // Table InputField
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "InputField" (
          "LocationId"  INTEGER NOT NULL,
          "TextTag" TEXT NOT NULL,
          "Value" TEXT NOT NULL,
          CONSTRAINT "LocationId_TextTag" PRIMARY KEY("LocationId","TextTag"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId")
        );
      """);

      // Table LastModified (CRITIQUE pour les triggers)
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "LastModified" (
          "LastModified"  TEXT NOT NULL
        );
      """);

      // Table Location
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Location" (
          "LocationId"  INTEGER NOT NULL,
          "BookNumber"  INTEGER,
          "ChapterNumber" INTEGER,
          "DocumentId"  INTEGER,
          "Track" INTEGER,
          "IssueTagNumber"  INTEGER NOT NULL DEFAULT 0,
          "KeySymbol" TEXT,
          "MepsLanguage"  INTEGER,
          "Type"  INTEGER NOT NULL,
          "Title" TEXT,
          UNIQUE("BookNumber","ChapterNumber","KeySymbol","MepsLanguage","Type"),
          UNIQUE("KeySymbol","IssueTagNumber","MepsLanguage","DocumentId","Track","Type"),
          PRIMARY KEY("LocationId"),
          CHECK(("Type" = 0 AND (("DocumentId" IS NOT NULL AND "DocumentId" != 0) OR ("Track" IS NOT NULL AND (("KeySymbol" IS NOT NULL AND (length("KeySymbol") > 0)) OR ("DocumentId" IS NOT NULL AND "DocumentId" != 0))) OR ("BookNumber" IS NOT NULL AND "BookNumber" != 0 AND "KeySymbol" IS NOT NULL AND (length("KeySymbol") > 0) AND ("ChapterNumber" IS NULL OR "ChapterNumber" = 0)) OR ("ChapterNumber" IS NOT NULL AND "ChapterNumber" != 0 AND "BookNumber" IS NOT NULL AND "BookNumber" != 0 AND "KeySymbol" IS NOT NULL AND (length("KeySymbol") > 0)))) OR "Type" != 0),
          CHECK(("Type" = 1 AND ("BookNumber" IS NULL OR "BookNumber" = 0) AND ("ChapterNumber" IS NULL OR "ChapterNumber" = 0) AND ("DocumentId" IS NULL OR "DocumentId" = 0) AND "KeySymbol" IS NOT NULL AND (length("KeySymbol") > 0) AND "Track" IS NULL) OR "Type" != 1),
          CHECK(("Type" IN (2, 3) AND ("BookNumber" IS NULL OR "BookNumber" = 0) AND ("ChapterNumber" IS NULL OR "ChapterNumber" = 0)) OR "Type" NOT IN (2, 3))
        );
      """);

      // Table Note
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Note" (
          "NoteId"  INTEGER NOT NULL,
          "Guid"  TEXT NOT NULL UNIQUE,
          "UserMarkId"  INTEGER,
          "LocationId"  INTEGER,
          "Title" TEXT,
          "Content" TEXT,
          "LastModified"  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
          "Created" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
          "BlockType" INTEGER NOT NULL DEFAULT 0,
          "BlockIdentifier" INTEGER,
          PRIMARY KEY("NoteId"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId"),
          FOREIGN KEY("UserMarkId") REFERENCES "UserMark"("UserMarkId"),
          CHECK(("BlockType" = 0 AND "BlockIdentifier" IS NULL) OR (("BlockType" BETWEEN 1 AND 2) AND "BlockIdentifier" IS NOT NULL))
        );
      """);

      // Table PlaylistItemAccuracy
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemAccuracy" (
          "PlaylistItemAccuracyId"  INTEGER NOT NULL,
          "Description" TEXT NOT NULL UNIQUE,
          PRIMARY KEY("PlaylistItemAccuracyId")
        );
      """);

      // Table PlaylistItem
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItem" (
          "PlaylistItemId"  INTEGER NOT NULL,
          "Label" TEXT NOT NULL,
          "StartTrimOffsetTicks"  INTEGER,
          "EndTrimOffsetTicks"  INTEGER,
          "Accuracy"  INTEGER NOT NULL,
          "EndAction" INTEGER NOT NULL,
          "ThumbnailFilePath" TEXT,
          PRIMARY KEY("PlaylistItemId"),
          FOREIGN KEY("Accuracy") REFERENCES "PlaylistItemAccuracy"("PlaylistItemAccuracyId"),
          FOREIGN KEY("ThumbnailFilePath") REFERENCES "IndependentMedia"("FilePath"),
          CHECK(length("Label") > 0),
          CHECK("EndAction" IN (0, 1, 2, 3))
        );
      """);

      // Table PlaylistItemIndependentMediaMap
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemIndependentMediaMap" (
          "PlaylistItemId"  INTEGER NOT NULL,
          "IndependentMediaId"  INTEGER NOT NULL,
          "DurationTicks" INTEGER NOT NULL,
          PRIMARY KEY("PlaylistItemId","IndependentMediaId"),
          FOREIGN KEY("IndependentMediaId") REFERENCES "IndependentMedia"("IndependentMediaId"),
          FOREIGN KEY("PlaylistItemId") REFERENCES "PlaylistItem"("PlaylistItemId")
        ) WITHOUT ROWID;
      """);

      // Table PlaylistItemLocationMap
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemLocationMap" (
          "PlaylistItemId"  INTEGER NOT NULL,
          "LocationId"  INTEGER NOT NULL,
          "MajorMultimediaType" INTEGER NOT NULL,
          "BaseDurationTicks" INTEGER,
          PRIMARY KEY("PlaylistItemId","LocationId"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId"),
          FOREIGN KEY("PlaylistItemId") REFERENCES "PlaylistItem"("PlaylistItemId")
        ) WITHOUT ROWID;
      """);

      // Table PlaylistItemMarker
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemMarker" (
          "PlaylistItemMarkerId"  INTEGER NOT NULL,
          "PlaylistItemId"  INTEGER NOT NULL,
          "Label" TEXT NOT NULL,
          "StartTimeTicks"  INTEGER NOT NULL,
          "DurationTicks" INTEGER NOT NULL,
          "EndTransitionDurationTicks"  INTEGER NOT NULL,
          UNIQUE("PlaylistItemId","StartTimeTicks"),
          PRIMARY KEY("PlaylistItemMarkerId"),
          FOREIGN KEY("PlaylistItemId") REFERENCES "PlaylistItem"("PlaylistItemId")
        );
      """);

      // Table PlaylistItemMarkerBibleVerseMap
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemMarkerBibleVerseMap" (
          "PlaylistItemMarkerId"  INTEGER NOT NULL,
          "VerseId" INTEGER NOT NULL,
          PRIMARY KEY("PlaylistItemMarkerId","VerseId"),
          FOREIGN KEY("PlaylistItemMarkerId") REFERENCES "PlaylistItemMarker"("PlaylistItemMarkerId")
        ) WITHOUT ROWID;
      """);

      // Table PlaylistItemMarkerParagraphMap
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PlaylistItemMarkerParagraphMap" (
          "PlaylistItemMarkerId"  INTEGER NOT NULL,
          "MepsDocumentId"  INTEGER NOT NULL,
          "ParagraphIndex"  INTEGER NOT NULL,
          "MarkerIndexWithinParagraph"  INTEGER NOT NULL,
          PRIMARY KEY("PlaylistItemMarkerId","MepsDocumentId","ParagraphIndex","MarkerIndexWithinParagraph"),
          FOREIGN KEY("PlaylistItemMarkerId") REFERENCES "PlaylistItemMarker"("PlaylistItemMarkerId")
        ) WITHOUT ROWID;
      """);

      // Table Tag
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Tag" (
          "TagId" INTEGER NOT NULL,
          "Type"  INTEGER NOT NULL,
          "Name"  TEXT NOT NULL,
          PRIMARY KEY("TagId"),
          UNIQUE("Type","Name"),
          CHECK(length("Name") > 0),
          CHECK("Type" IN (0, 1, 2))
        );
      """);

      // Table TagMap
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "TagMap" (
          "TagMapId"  INTEGER NOT NULL,
          "PlaylistItemId"  INTEGER,
          "LocationId"  INTEGER,
          "NoteId"  INTEGER,
          "TagId" INTEGER NOT NULL,
          "Position"  INTEGER NOT NULL,
          CONSTRAINT "TagId_LocationId" UNIQUE("TagId","LocationId"),
          CONSTRAINT "TagId_NoteId" UNIQUE("TagId","NoteId"),
          CONSTRAINT "TagId_PlaylistItemId" UNIQUE("TagId","PlaylistItemId"),
          CONSTRAINT "TagId_Position" UNIQUE("TagId","Position"),
          PRIMARY KEY("TagMapId"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId"),
          FOREIGN KEY("NoteId") REFERENCES "Note"("NoteId"),
          FOREIGN KEY("PlaylistItemId") REFERENCES "PlaylistItem"("PlaylistItemId"),
          FOREIGN KEY("TagId") REFERENCES "Tag"("TagId"),
          CHECK(("NoteId" IS NULL AND "LocationId" IS NULL AND "PlaylistItemId" IS NOT NULL) OR ("LocationId" IS NULL AND "PlaylistItemId" IS NULL AND "NoteId" IS NOT NULL) OR ("PlaylistItemId" IS NULL AND "NoteId" IS NULL AND "LocationId" IS NOT NULL))
      );
      """);

      // Table UserMark
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "UserMark" (
          "UserMarkId"  INTEGER NOT NULL,
          "ColorIndex"  INTEGER NOT NULL,
          "LocationId"  INTEGER NOT NULL,
          "StyleIndex"  INTEGER NOT NULL,
          "UserMarkGuid"  TEXT NOT NULL UNIQUE,
          "Version" INTEGER NOT NULL,
          PRIMARY KEY("UserMarkId"),
          FOREIGN KEY("LocationId") REFERENCES "Location"("LocationId")
        );
      """);

      // Table android_metadata
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "android_metadata" (
          "locale"  TEXT
        );
      """);

      // --- 2. Insertion des données initiales (Un appel par bloc d'insertions logiques) ---
      // Insert LastModified
      await txn.execute("""
        INSERT INTO "LastModified" ("LastModified") VALUES (?);
      """, [formattedTimestamp]);

      // Insert PlaylistItemAccuracy, Tag, android_metadata
      await txn.execute("""
        INSERT INTO "PlaylistItemAccuracy" ("PlaylistItemAccuracyId", "Description") VALUES (1, 'Accurate'), (2, 'NeedsUserVerification');
      """);

      await txn.execute("""
        INSERT INTO "Tag" ("TagId", "Type", "Name") VALUES (1, 0, 'Favorite');
      """);

      final systemLocale = PlatformDispatcher.instance.locale.toLanguageTag().replaceAll('-', '_');
      printTime('systeme Locale : ${systemLocale}');
      await txn.execute("""
        UPDATE "android_metadata" SET "locale" = ?;
      """, [systemLocale]);


      // --- 3. Création des index (Un appel par index) ---

      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_BlockRange_UserMarkId" ON "BlockRange" ("UserMarkId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_Location_KeySymbol_MepsLanguage_BookNumber_ChapterNumber" ON "Location" ("KeySymbol", "MepsLanguage", "BookNumber", "ChapterNumber"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_Location_MepsLanguage_DocumentId" ON "Location" ("MepsLanguage", "DocumentId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_Note_LastModified_LocationId" ON "Note" ("LastModified", "LocationId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_Note_LocationId_BlockIdentifier" ON "Note" ("LocationId", "BlockIdentifier"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_PlaylistItemIndependentMediaMap_IndependentMediaId" ON "PlaylistItemIndependentMediaMap" ("IndependentMediaId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_PlaylistItemLocationMap_LocationId" ON "PlaylistItemLocationMap" ("LocationId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_PlaylistItem_ThumbnailFilePath" ON "PlaylistItem" ("ThumbnailFilePath"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_TagMap_LocationId_TagId_Position" ON "TagMap" ("LocationId", "TagId", "Position"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_TagMap_NoteId_TagId_Position" ON "TagMap" ("NoteId", "TagId", "Position"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_TagMap_PlaylistItemId_TagId_Position" ON "TagMap" ("PlaylistItemId", "TagId", "Position"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_TagMap_TagId" ON "TagMap" ("TagId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_Tag_Name_Type_TagId" ON "Tag" ("Name", "Type", "TagId"); """);
      await txn.execute(""" CREATE INDEX IF NOT EXISTS "IX_UserMark_LocationId" ON "UserMark" ("LocationId"); """);

      // --- 4. Création des triggers (Un appel par trigger) ---

      await txn.execute(""" CREATE TRIGGER TR_Raise_Error_Before_Delete_LastModified BEFORE DELETE ON LastModified BEGIN SELECT RAISE (FAIL, 'DELETE FROM LastModified not allowed'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Raise_Error_Before_Insert_LastModified BEFORE INSERT ON LastModified BEGIN SELECT RAISE (FAIL, 'INSERT INTO LastModified not allowed'); END; """);

      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_BlockRange DELETE ON BlockRange BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_Bookmark DELETE ON Bookmark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_IndependentMedia DELETE ON IndependentMedia BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_InputField DELETE ON InputField BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_Note DELETE ON Note BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_PlaylistItem DELETE ON PlaylistItem BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_Tag DELETE ON Tag BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_TagMap DELETE ON TagMap BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Delete_UserMark DELETE ON UserMark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);

      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_BlockRange INSERT ON BlockRange BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_Bookmark INSERT ON Bookmark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_IndependentMedia INSERT ON IndependentMedia BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_InputField INSERT ON InputField BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_Note INSERT ON Note BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_PlaylistItem INSERT ON PlaylistItem BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_Tag INSERT ON Tag BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_TagMap INSERT ON TagMap BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Insert_UserMark INSERT ON UserMark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);

      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_BlockRange UPDATE ON BlockRange BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_Bookmark UPDATE ON Bookmark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_IndependentMedia UPDATE ON IndependentMedia BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_InputField UPDATE ON InputField BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_Note UPDATE ON Note BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_PlaylistItem UPDATE ON PlaylistItem BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_Tag UPDATE ON Tag BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_TagMap UPDATE ON TagMap BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
      await txn.execute(""" CREATE TRIGGER TR_Update_LastModified_Update_UserMark UPDATE ON UserMark BEGIN UPDATE LastModified SET LastModified = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'); END; """);
    });
  }
}

class BackupInfo {
  final String deviceName;
  final DateTime lastModified;

  BackupInfo({
    required this.deviceName,
    required this.lastModified,
  });
}

Future<BackupInfo?> getBackupInfo(File file) async {
  try {
    List<int> bytes = file.readAsBytesSync();
    Archive archive = ZipDecoder().decodeBytes(bytes);

    // Cherche le fichier manifest.json
    ArchiveFile? manifestFile = archive.files.firstWhereOrNull((f) => f.name == 'manifest.json');

    if (manifestFile == null) return null;

    String manifestJson = utf8.decode(manifestFile.content as List<int>);
    Map<String, dynamic> manifestData = jsonDecode(manifestJson);

    String deviceName = manifestData['userDataBackup']['deviceName'];
    DateTime lastModified = DateTime.parse(
      manifestData['userDataBackup']['lastModifiedDate'],
    );

    return BackupInfo(
      deviceName: deviceName,
      lastModified: lastModified,
    );
  } catch (e) {
    return null;
  }
}

