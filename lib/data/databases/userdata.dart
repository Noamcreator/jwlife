import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/startup/copy_assets.dart';
import 'package:jwlife/core/assets.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/publication/pages/document/data/models/dated_text.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:path_provider/path_provider.dart';
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
import '../models/userdata/location.dart';
import '../models/userdata/note.dart';
import '../models/userdata/playlist.dart';
import '../models/userdata/playlistItem.dart';
import '../realm/catalog.dart';

import 'package:image/image.dart' as img;

class Userdata {
  int schemaVersion = 14;
  late Database _database;
  List<dynamic> favorites = [];
  List<Tag> tags = [];

  Future<void> init() async {
    File userdataFile = await getUserdataDatabaseFile();
    if (await userdataFile.exists()) {
      _database = await openDatabase(userdataFile.path, version: schemaVersion);
      await getFavorites();
      getTags();
    }
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
    for (int i = 0; i < 7; i++) {
      GlobalKeyService.jwLifePageKey.currentState!.returnToFirstPage(i);
    }
  }

  Future<void> getFavorites() async {
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
          final match = allPublications.firstWhereOrNull((p) => p.symbol == row['KeySymbol'] && p.issueTagNumber == row['IssueTagNumber'] && p.mepsLanguage.id == row['MepsLanguage']);

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
        locationId = await insertLocation(null, null, null, null, object.issueTagNumber, object.symbol, object.mepsLanguage.id, type: 1);
      }
      else if (object is Document) {
        bool isBibleChapter = object.isBibleChapter();
        locationId = await insertLocation(object.bookNumber, object.chapterNumber, isBibleChapter ? null : object.mepsDocumentId, null, object.publication.issueTagNumber, object.publication.symbol, object.publication.mepsLanguage.id, type: 0);
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
          keySymbol: object.symbol,
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
          keySymbol: object.publication.symbol,
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
        ''', [i, item.issueTagNumber, item.symbol, item.mepsLanguage.id, 1]);
      }
      else if (item is Document) {
        bool isBibleChapter = item.isBibleChapter();
        batch.rawInsert('''
          INSERT INTO TagMap (TagId, LocationId, Position)
          SELECT Tag.TagId, Location.LocationId, ?
          FROM Tag
          JOIN Location ON Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.DocumentId = ? AND Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND Location.Type = ?
          WHERE Tag.Type = 0
        ''', [i, item.bookNumber, item.chapterNumber, isBibleChapter ? null : item.mepsDocumentId, item.publication.issueTagNumber, item.publication.symbol, item.publication.mepsLanguage.id, 0]);
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

  Future<void> getTags() async {
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

      Tag tag = Tag.fromMap({'TagId': tagId, 'Type': type ?? 1, 'Name': name});
      if (tag.type != 2) {
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
      int count = await _database.delete(
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

      // Mise à jour de la liste locale `tags`
      if (tag.type == 1) {
        tags.removeWhere((t) => t.id == tag.id);
      }
      else if(tag.type == 2) {
        items?.forEach((item) {
          deletePlaylistItem(item);
        });
      }

      return count > 0;
    }
    catch (e) {
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
      Map<String, dynamic> whereClause = {};

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
      if (mepsLanguageId != null) whereClause['MepsLanguage'] = mepsLanguageId;

      whereClause['Type'] = type;

      final whereKeys = whereClause.keys.toList();
      final whereString = whereKeys.map((k) => '$k = ?').join(' AND ');
      final whereValues = whereKeys.map((k) => whereClause[k]).toList();

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

      final locationId = await dbExecutor.insert('Location', whereClause);
      return locationId;
    } catch (e) {
      printTime('Erreur lors de insertLocation: $e');
      throw Exception('Échec de l\'insertion ou de la récupération de la Location');
    }
  }

  Future<List<Map<String, dynamic>>> getInputFields(String query) async {
    try {
      final likeQuery = '%$query%';
      final result = await _database.rawQuery('''
      SELECT InputField.TextTag, InputField.Value, Location.*
      FROM InputField
      LEFT JOIN Location ON InputField.LocationId = Location.LocationId
      WHERE InputField.Value LIKE ?
    ''', [likeQuery]);

      return result;
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load input fields for the given query.');
    }
  }

  Future<List<Map<String, dynamic>>> getInputFieldsFromDocId(int docId, int mepsLang) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> inputFieldsData = await _database.rawQuery('''
          SELECT TextTag, Value
          FROM InputField
          LEFT JOIN Location ON InputField.LocationId = Location.LocationId
          WHERE Location.DocumentId = ?
          ''', [docId]
      );

      return inputFieldsData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
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

  Future<List<Map<String, dynamic>>> getBlockRangesFromChapterNumber(int bookId, int chapterId, int mepsLanguage) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> blockRanges = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.StyleIndex, UserMark.StyleIndex, UserMark.UserMarkGuid
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.MepsLanguage = ?
            ''', [bookId, chapterId, mepsLanguage]
      );

      return blockRanges;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load block ranges for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getBlockRangesFromDocumentId(int documentId, int mepsLanguage) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> blockRanges = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.StyleIndex, UserMark.StyleIndex, UserMark.UserMarkGuid
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?
            ''', [documentId, mepsLanguage]
      );

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

  Future<void> changeBlockRangeStyleWithGuid(String userMarkGuid, int style, int color) async {
    try {
      await _database.rawUpdate('''
        UPDATE UserMark 
        SET ColorIndex = ?, StyleIndex = ?
        WHERE UserMarkGuid = ?
      ''', [color, style, userMarkGuid]);

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

    } catch (e) {
      printTime('Erreur dans addBlockRangeToDocument: $e');
      throw Exception('Échec de l\'ajout du surlignage pour ce webview.');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarksFromDocId(int docId, int mepsLang) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> inputFieldsData = await _database.rawQuery('''
          SELECT Slot, BlockType, BlockIdentifier
          FROM Bookmark
          LEFT JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Location.DocumentId = ?
          ''', [docId]
      );

      return inputFieldsData;

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarksFromChapterNumber(int bookNumber, int chapterNumber, int mepsLang) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> inputFieldsData = await _database.rawQuery('''
          SELECT Slot, BlockType, BlockIdentifier
          FROM Bookmark
          LEFT JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Location.BookNumber = ? AND Location.ChapterNumber = ?
          ''', [bookNumber, chapterNumber]
      );

      return inputFieldsData;

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Note>> getNotes({int? limit, String? query}) async {
    final params = <dynamic>[];
    String whereClause = '';
    if (query != null && query.trim().isNotEmpty) {
      whereClause = 'WHERE (N.Title LIKE ? OR N.Content LIKE ?)';
      final likeQuery = '%${query.trim()}%';
      params.addAll([likeQuery, likeQuery]);
    }

    String limitClause = '';
    if (limit != null) {
      limitClause = 'LIMIT ?';
      params.add(limit);
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
  ''';

    final result = await _database.rawQuery(sql, params);
    return result.map((note) => Note.fromMap(note)).toList();
  }

  Future<List<Map<String, dynamic>>> getNotesFromDocId(int docId, int mepsLang) async {
    try {
      // Une seule requête optimisée avec JOIN direct
      List<Map<String, dynamic>> notesData = await _database.rawQuery('''
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
        WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?
        GROUP BY Note.NoteId
    ''', [docId, mepsLang]);

      return notesData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getNotesFromChapterNumber(int bookId, int chapterId, int mepsLang) async {
    try {
      // Une seule requête optimisée avec JOIN direct
      List<Map<String, dynamic>> notesData = await _database.rawQuery('''
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
        WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.MepsLanguage = ?
        GROUP BY Note.NoteId
    ''', [bookId, chapterId, mepsLang]);

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
    // Get timestamp
    String datetime = formattedTimestamp;

    try {
      await _database.rawUpdate('''
      UPDATE Note 
      SET Title = ?, Content = ?, LastModified = ?
      WHERE Guid = ?
    ''', [title, content, datetime, guid]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to update note with Guid.');
    }
  }

  Future<void> changeNoteUserMark(String noteGuid, String userMarkGuid) async {
    final String datetime = formattedTimestamp;

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
      ''', [userMarkId, datetime, noteGuid]);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change UserMark for note.');
    }
  }

  Future<void> updateNoteColorWithGuid(String guid, int colorIndex) async {
    String datetime = formattedTimestamp;

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
    ''', [datetime, guid]);
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change color for note with Guid.');
    }
  }

  Future<void> addTagToNoteWithGuid(String guid, int tagId) async {
    String datetime = formattedTimestamp;

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
    ''', [datetime, noteId]);

      // Insérer le nouveau TagMap avec la position calculée
      await _database.rawInsert('''
      INSERT INTO TagMap (NoteId, TagId, Position)
      VALUES (?, ?, ?)
    ''', [noteId, tagId, newPosition]);
    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to add tag to note with Guid $guid.');
    }
  }

  Future<void> removeTagFromNoteWithGuid(String guid, int tagId) async {
    String datetime = formattedTimestamp;

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
    ''', [datetime, noteId]);
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
        L.MepsLanguage
      FROM Note N
      LEFT JOIN Location L ON L.LocationId = N.LocationId
      LEFT JOIN TagMap TM ON N.NoteId = TM.NoteId
      LEFT JOIN Tag T ON TM.TagId = T.TagId
      LEFT JOIN UserMark UM ON N.UserMarkId = UM.UserMarkId
      WHERE EXISTS (
          SELECT 1
          FROM TagMap tm2
          WHERE tm2.NoteId = N.NoteId
            AND tm2.TagId = ?
      )
      GROUP BY N.NoteId
      ORDER BY N.LastModified DESC;
    ''', [tagId]);

    return result.map((map) => Note.fromMap(map)).toList();
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
      String? newTitle = bookNumber != null && chapterNumber != null ? (blockIdentifier != null ? "$title:$blockIdentifier" : title) : null;

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
        'Title': newTitle ?? title,
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

    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT 
        Tag.TagId, 
        Tag.Name,
        PlaylistItem.ThumbnailFilePath
      FROM Tag
      LEFT JOIN TagMap ON Tag.TagId = TagMap.TagId AND TagMap.Position = 0
      LEFT JOIN PlaylistItem ON TagMap.PlaylistItemId = PlaylistItem.PlaylistItemId
      WHERE Tag.Type = 2
      $limitClause
    ''');

    return result.map((playlist) => Playlist.fromMap(playlist)).toList();
  }

  Future<List<PlaylistItem>> getPlaylistItemByPlaylistId(int playlistId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT PlaylistItem.*, TagMap.Position, Location.*, IndependentMedia.*, PlaylistItemIndependentMediaMap.DurationTicks, PlaylistItemLocationMap.BaseDurationTicks
      FROM PlaylistItem
      INNER JOIN TagMap ON PlaylistItem.PlaylistItemId = TagMap.PlaylistItemId
      INNER JOIN Tag ON TagMap.TagId = Tag.TagId
      LEFT JOIN PlaylistItemLocationMap ON PlaylistItem.PlaylistItemId = PlaylistItemLocationMap.PlaylistItemId
      LEFT JOIN Location ON PlaylistItemLocationMap.LocationId = Location.LocationId
      LEFT JOIN PlaylistItemIndependentMediaMap ON PlaylistItem.PlaylistItemId = PlaylistItemIndependentMediaMap.PlaylistItemId
      LEFT JOIN IndependentMedia ON PlaylistItemIndependentMediaMap.IndependentMediaId = IndependentMedia.IndependentMediaId
      WHERE Tag.TagId = ?
    ''', [playlistId]);

    return result.map((map) => PlaylistItem.fromMap(map)).toList();
  }

  Future<void> deletePlaylistItem(PlaylistItem playlistItem) async {
    final id = playlistItem.playlistItemId;

    // Récupérer les IndependentMediaId associés
    final independentMediaMaps = await _database.query(
      'PlaylistItemIndependentMediaMap',
      columns: ['IndependentMediaId'],
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // Supprimer les liaisons dans PlaylistItemIndependentMediaMap
    await _database.delete(
      'PlaylistItemIndependentMediaMap',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // Supprimer les IndependentMediaMap liés
    for (var row in independentMediaMaps) {
      final independentMediaId = row['IndependentMediaId'];
      if (independentMediaId != null) {
        await _database.delete(
          'IndependentMedia',
          where: 'IndependentMediaId = ?',
          whereArgs: [independentMediaId],
        );
      }
    }

    // Supprimer les TagMap liés au PlaylistItem
    await _database.delete(
      'TagMap',
      where: 'PlaylistItemId = ?',
      whereArgs: [id],
    );

    // Enfin, supprimer le PlaylistItem
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


  Future<String> insertThumbnailInPlaylist(String path) async {
    Directory userdataDir = await getAppUserDataDirectory();
    Uuid uuid = Uuid();

    img.Image thumbnail;
    if(path.isNotEmpty) {
      Uint8List imageBytes;
      if(path.startsWith('https')) {
        http.Response response = await http.get(Uri.parse(path));
        imageBytes = response.bodyBytes;
      }
      else {
        // Charger l'image pour traitement thumbnail
        imageBytes = await File(path).readAsBytes();
      }
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception("Impossible de décoder l'image source");
      }

      // Redimensionner à 250x250 (tu peux changer la méthode si tu veux garder le ratio)
      thumbnail = resizeAndCropCenter(originalImage, 250);
    }
    else {
      String thumbnailPath = '${userdataDir.path}/default_thumbnail.png';
      File file = File(thumbnailPath);

      // Lire les bytes du fichier
      Uint8List bytes = await file.readAsBytes();

      // Décoder l'image
      img.Image? defaultThumbnail = img.decodeImage(bytes);

      // Optionnel : si tu veux forcer la taille 250x250, resize ou crop après.
      if (defaultThumbnail != null) {
        thumbnail = img.copyResize(defaultThumbnail, width: 250, height: 250);
      }
      else {
        throw Exception("Impossible de décoder l'image source");
      }
    }

    // Sauvegarder le thumbnail
    String thumbnailName = uuid.v4();
    String thumbnailPath = '${userdataDir.path}/$thumbnailName';
    File thumbnailFile = File(thumbnailPath);
    await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail));

    String hash = await sha256hashOfFile(thumbnailPath);

    await _database.insert(
      'IndependentMedia',
      {
        'OriginalFilename': path.split('/').last.split('.').first,
        'FilePath': thumbnailName,
        'MimeType': 'image/jpeg',
        'Hash': hash,
      },
    );

    return thumbnailName;
  }

  Future<int> insertImageInPlaylist(Playlist playlist, String filepath) async {
    String thumbnailName = await insertThumbnailInPlaylist(filepath);
    File imageFile = File(filepath);
    Directory userdataDir = await getAppUserDataDirectory();
    Uuid uuid = Uuid();

    // Générer nom pour image originale copiée
    String imageName = '${uuid.v4()}.jpg';

    // Copier l'image originale dans userdata
    String imagePath = '${userdataDir.path}/$imageName';
    await imageFile.copy(imagePath);

    String hash = await sha256hashOfFile(imagePath);

    // Créer IndependentMedia (il manque la hash, à générer si tu veux)
    IndependentMedia independentMedia = IndependentMedia(
      originalFileName: imageFile.path.split('/').last,
      filePath: imageName,
      mimeType: 'image/jpeg',
      hash: hash, // À générer si besoin
    );

    PlaylistItem playlistItem = PlaylistItem(
      playlistItemId: -1,
      label: imageFile.path.split('/').last,
      thumbnailFilePath: thumbnailName,
      independentMedia: independentMedia
    );

    return insertPlaylistItem(playlistItem, playlist: playlist);
  }

  Future<int> insertMediaItemInPlaylist(Playlist playlist, Media media) async {
    String thumbnailName = await insertThumbnailInPlaylist(media.networkImageSqr ?? media.networkImageLsr ?? '');

    PlaylistItem playlistItem = PlaylistItem(
        playlistItemId: -1,
        label: media.title,
        thumbnailFilePath: thumbnailName,
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

  Future<int> insertPlaylistItem(PlaylistItem playlistItem, {required Playlist playlist, MediaItem? mediaItem}) async {
    return await _database.transaction<int>((txn) async {
      // 1️⃣ Insérer (ou ignorer si existe) IndependentMedia
      int? independentMediaId;
      if (playlistItem.independentMedia != null) {
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

      // 2️⃣ Insérer PlaylistItem
      final playlistItemId = await txn.insert(
        'PlaylistItem',
        {
          'Label': playlistItem.label ?? '',
          'StartTrimOffsetTicks': playlistItem.startTrimOffsetTicks,
          'EndTrimOffsetTicks': playlistItem.endTrimOffsetTicks,
          'Accuracy': playlistItem.accuracy,
          'EndAction': playlistItem.endAction,
          'ThumbnailFilePath': playlistItem.thumbnailFilePath,
        },
      );

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
              'MajorMultimediaType': playlistItem.location!.type == 2 ? 0 : 2, // adapter si besoin
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

    playlistItem.thumbnailFilePath = thumbnailFile.path;

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

  Future<void> updateLastModifiedDate() async {
    try {
      await _database.rawUpdate(
        'UPDATE LastModified SET LastModified = ?',
        [formattedTimestamp],
      );
      printTime('LastMod updated to $formattedTimestamp ✅');
    }
    catch (e) {
      printTime('Error: $e ⚠️');
    }
  }

  Future<String> getLastModifiedDate() async {
    DateTime currentTimestamp = DateTime.now().toUtc();
    String formattedTimestamp = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(currentTimestamp);

    try {
      List<Map<String, dynamic>> result = await _database.rawQuery(
        'SELECT LastModified FROM LastModified',
      );
      return result.first['LastModified'] ?? formattedTimestamp;
    }
    catch (e) {
      printTime('Error: $e ⚠️');
    }
    return formattedTimestamp;
  }

  Future<void> importPlaylistFromFile(File file) async {
    try {
      // 1) (Re)création du dossier user data
      final Directory userDataDir = await getAppUserDataDirectory();
      if (!await userDataDir.exists()) {
        await userDataDir.create(recursive: true);
      }

      // 2) Dézipper l'archive
      final List<int> bytes = await file.readAsBytes();
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      File? jwplaylistDb;

      for (final ArchiveFile archiveFile in archive) {
        final newFile = File('${userDataDir.path}/${archiveFile.name}');
        if (archiveFile.isFile) {
          if (archiveFile.name == 'userData.db') {
            Directory tempDir = await getAppTemp();
            jwplaylistDb = File('${tempDir.path}/jwplaylist.db');
            await jwplaylistDb.create(recursive: true);
            await jwplaylistDb.writeAsBytes(archiveFile.content as List<int>);
          }
          else if(archiveFile.name != 'manifest.json') {
            await newFile.create(recursive: true);
            await newFile.writeAsBytes(archiveFile.content as List<int>);
          }
        }
        else {
          await Directory(newFile.path).create(recursive: true);
        }
      }

      // 3) Si on a une base à importer : fusion "replace"
      if (jwplaylistDb != null) {
        // Ouvre la base principale
        await _database.transaction((txn) async {
          try {
            // ATTACH la base importée
            await txn.execute("ATTACH DATABASE ? AS jwplaylist;", [jwplaylistDb!.path]);

            // Tables à copier
            final tablesToCopy = [
              'IndependentMedia',
              'PlaylistItem',
              'PlaylistItemIndependentMediaMap',
              'PlaylistItemLocationMap',
              'PlaylistItemMarker',
              'PlaylistItemMarkerBibleVerseMap',
              'PlaylistItemMarkerParagraphMap',
              'Tag',
              'TagMap'
            ];

            final whereClauses = tablesToCopy.map((table) => "name LIKE '$table'").join(' OR ');

            // Récupère les tables "main" à copier
            final List<Map<String, Object?>> tables = await txn.rawQuery('''
            SELECT name
            FROM main.sqlite_master
            WHERE type = 'table'
            AND ($whereClauses);
          ''');

            for (final row in tables) {
              final String table = row['name'] as String;
              printTime('Importing $table...');

              // Vérifie que la table existe aussi dans la DB importée
              final List<Map<String, Object?>> existsInImp = await txn.rawQuery(
                  "SELECT name FROM jwplaylist.sqlite_master WHERE type='table' AND name=?;",
                  [table]
              );
              if (existsInImp.isEmpty) continue;

              // Colonnes dans la DB principale "main"
              final List<Map<String, Object?>> colsInfoMain = await txn.rawQuery(
                  "PRAGMA main.table_info('$table');"
              );
              if (colsInfoMain.isEmpty) continue;
              final List<String> colNamesMain = colsInfoMain.map((c) => c['name'] as String).toList(growable: false);

              // Colonnes dans la DB attachée "jwplaylist"
              final List<Map<String, Object?>> colsInfoImp = await txn.rawQuery(
                  "PRAGMA jwplaylist.table_info('$table');"
              );
              if (colsInfoImp.isEmpty) continue;
              final Set<String> colNamesImp = colsInfoImp.map((c) => c['name'] as String).toSet();

              // Intersection des colonnes présentes dans les deux tables
              final List<String> commonCols = colNamesMain.where((c) => colNamesImp.contains(c)).toList(growable: false);

              if (commonCols.isEmpty) continue;

              // ✅ CORRECTION : On garde TOUTES les colonnes communes
              final String colsIdent = commonCols.join(", ");
              final String colsSelect = commonCols.map((c) => "jwplaylist.$table.$c").join(", ");

              final String sql = """
              INSERT OR REPLACE INTO $table ($colsIdent)
              SELECT $colsSelect FROM jwplaylist.$table;
            """;

              printTime(sql);

              await txn.execute(sql);
            }

            // ✅ DETACH dans un try-catch séparé pour éviter les blocages
          } catch (e) {
            printTime('Error during import: $e');
            rethrow;
          } finally {
            // ✅ DETACH optionnel - SQLite se charge du nettoyage automatiquement
            try {
              await txn.execute("DETACH DATABASE jwplaylist;");
              printTime('Database detached successfully');
            } catch (detachError) {
              // ✅ Ce n'est pas grave - SQLite détachera automatiquement à la fermeture
              printTime('Info: Database will be auto-detached (${detachError.toString().split('(')[0].trim()})');
            }
          }
        });

        // ✅ AMÉLIORATION : Nettoyer le fichier temporaire
        try {
          if (await jwplaylistDb.exists()) {
            await jwplaylistDb.delete();
          }
        } catch (cleanupError) {
          printTime('Warning: Could not cleanup temp file: $cleanupError');
        }
      }
    }
    catch (e, st) {
      printTime('Error: $e ⚠️');
      printTime('Stack trace: $st');
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
      final tempDir = await getTemporaryDirectory();
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

    await userDataDir.create(recursive: true);

    String userdataDbPath = '${userDataDir.path}/userData.db';
    await CopyAssets.copyFileFromAssetsToDirectory(Assets.userDataUserData, userdataDbPath);
    await CopyAssets.copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png');

    await reload_db();
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

