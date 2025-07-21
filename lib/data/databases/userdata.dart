import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/startup/copy_assets.dart';
import 'package:jwlife/core/assets.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../../features/publication/views/document/data/models/document.dart';
import '../models/userdata/congregation.dart';
import '../models/userdata/location.dart';

class Userdata {
  int schemaVersion = 14;
  late Database _database;
  List<Publication> favorites = [];
  List<Tag> tags = [];
  List<Map<String, dynamic>> notes = [];

  Future<void> init() async {
    File userdataFile = await getUserdataFile();
    if (await userdataFile.exists()) {
      _database = await openDatabase(userdataFile.path, version: schemaVersion);
      await getFavorites();
      getTags();
      //await getNotes();
    }
  }

  String get formattedTimestamp => DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(DateTime.now().toUtc());

  Future<void> reload_db() async {
    await _database.close();
    await init();
  }

  void clearData() {
    favorites.clear();
    tags.clear();
    notes.clear();
  }

  Future<void> getFavorites() async {
    favorites = [];
    try {
      File catalogFile = await getCatalogFile();
      File mepsFile = await getMepsFile();

      if (catalogFile.existsSync() && mepsFile.existsSync()) {
        final catalog = await openReadOnlyDatabase(catalogFile.path);

        try {
          await catalog.transaction((txn) async {
            await txn.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
            await txn.execute("ATTACH DATABASE '${_database.path}' AS userdata");

            final result = await txn.rawQuery('''
            SELECT DISTINCT
              p.*,
              meps.Language.Symbol AS LanguageSymbol,
              meps.Language.VernacularName AS LanguageVernacularName,
              meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
              pa.LastModified,
              pa.ExpandedSize,
              pa.SchemaVersion,
              (SELECT ia.NameFragment
               FROM ImageAsset ia
               JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
               WHERE paim.PublicationAssetId = pa.Id 
                 AND (ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600))
               ORDER BY ia.Width DESC
               LIMIT 1) AS ImageSqr,
              (SELECT ia.NameFragment
               FROM ImageAsset ia
               JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
               WHERE paim.PublicationAssetId = pa.Id 
                 AND ia.NameFragment LIKE '%_lsr-%'
               ORDER BY ia.Width DESC
               LIMIT 1) AS ImageLsr
            FROM Publication p
            LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
            LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
            JOIN userdata.Location loc ON loc.KeySymbol = p.KeySymbol AND loc.MepsLanguage = p.MepsLanguageId AND loc.IssueTagNumber = p.IssueTagNumber
            JOIN userdata.TagMap tg ON tg.LocationId = loc.LocationId
            JOIN userdata.Tag ON tg.TagId = userdata.Tag.TagId
            WHERE userdata.Tag.Name = 'Favorite' AND userdata.Tag.Type = 0
            ORDER BY tg.Position ASC
          ''');

            if (result.isNotEmpty) {
              favorites = result.map((row) => Publication.fromJson(row, isFavorite: true)).toList();
            }
          });
        } finally {
          await catalog.execute("DETACH DATABASE meps");
          await catalog.execute("DETACH DATABASE userdata");
          await catalog.close();
        }
      }
    } catch (e) {
      printTime('Erreur: $e');
      throw Exception('Échec de chargement des favoris.');
    }
  }

  Future<void> addPubFavorite(Publication publication) async {
    try {
      int locationId = await insertLocation(null, null, null, publication.issueTagNumber, publication.keySymbol, publication.mepsLanguage.id, type: 1);

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

      favorites.add(publication);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to insert into TagMap and Location.');
    }
  }

  Future<void> removePubFavorite(Publication publication) async {
    try {
      // Récupère les informations nécessaires du Map publication
      int issueTagNumber = publication.issueTagNumber;
      String keySymbol = publication.keySymbol;
      int mepsLanguageId = publication.mepsLanguage.id;

      // Récupère l'LocationId correspondant dans la table Location
      var locationResult = await _database.rawQuery('''
        SELECT LocationId FROM Location
        WHERE IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ?
      ''', [issueTagNumber, keySymbol, mepsLanguageId]);

      // Vérifie si l'LocationId existe
      if (locationResult.isNotEmpty) {
        int? locationId = locationResult.first['LocationId'] as int?;

        // Supprime de la table TagMap pour ce LocationId
        await _database.rawDelete('''
          DELETE FROM TagMap
          WHERE LocationId = ?
        ''', [locationId]);

        // Supprime de la table Location
        await _database.rawDelete('''
          DELETE FROM Location
          WHERE LocationId = ?
        ''', [locationId]);
      }

      favorites.removeWhere((publication) => publication.keySymbol == keySymbol && publication.issueTagNumber == issueTagNumber && publication.mepsLanguage.id == mepsLanguageId);
    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove from TagMap and Location.');
    }
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
        return null;
      }

      // Insère le tag
      int tagId = await _database.insert('Tag', {
        'Type': type ?? 1,
        'Name': name
      });

      Tag tag = Tag.fromMap({'TagId': tagId, 'Type': type ?? 1, 'Name': name});
      tags.add(tag);
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
    catch (e) {
      printTime('Erreur lors de la mise à jour du tag : $e');
      return null;
    }
  }

  Future<bool> deleteTag(Tag tag) async {
    try {
      int count = await _database.delete(
        'Tag',
        where: 'TagId = ? AND Type = ?',
        whereArgs: [tag.id, tag.type],
      );

      // Mise à jour de la liste locale `tags`
      tags.removeWhere((t) => t.id == tag.id);

      return count > 0;
    }
    catch (e) {
      printTime('Erreur lors de la suppression du tag : $e');
      return false;
    }
  }

  Future<int> insertLocationWithDocument(Publication publication, Document document) async {
    int locationId = await insertLocation(document.mepsDocumentId, document.bookNumber, document.chapterNumber!, publication.issueTagNumber, publication.keySymbol, publication.mepsLanguage.id);
    return locationId;
  }

  Future<int> insertLocation(int? mepsDocumentId, int? bookNumber, int? chapterNumber, int? issueTagNumber, String? keySymbol, int? mepsLanguageId, {int type = 0}) async {
    try {
      // Définir les critères de recherche en fonction du type de document
      Map<String, dynamic> whereClause;
      if (bookNumber != null && chapterNumber != null) {
        whereClause = {
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': type
        };
      }
      else {
        whereClause = {
          'DocumentId': mepsDocumentId,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': type,
        };
      }

      // Vérifie si l'entrée existe déjà
      final List<Map<String, dynamic>> existing = await _database.query(
        'Location',
        columns: ['LocationId'],
        where: whereClause.keys.map((k) => '$k = ?').join(' AND '),
        whereArgs: whereClause.values.toList(),
      );

      if (existing.isNotEmpty) {
        return existing.first['LocationId'] as int;
      }

      // Sinon, insère la nouvelle entrée
      final locationId = await _database.insert('Location', whereClause);
      return locationId;
    }
    catch (e) {
      printTime('Erreur lors de insertLocation: $e');
      throw Exception('Échec de l\'insertion ou de la récupération de la Location');
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
      final int locationId = await insertLocationWithDocument(document.publication, document);

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

  Future<List<Map<String, dynamic>>> getHighlightsFromChapterNumber(int bookId, int chapterId, int mepsLang) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> highlights = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.UserMarkGuid
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.MepsLanguage = ?
            ''', [bookId, chapterId, mepsLang]
      );

      return highlights;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load highlights for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getHighlightsFromDocId(int docId, int mepsLang) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> highlights = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex, UserMark.UserMarkGuid
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?
            ''', [docId, mepsLang]
      );

      return highlights;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load highlights for the given DocumentId and MepsLanguage.');
    }
  }

  void removeHighlightWithGuid(String userMarkGuid) async {
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

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove highlight with UserMarkGuid.');
    }
  }

  Future<void> changeColorHighlightWithGuid(String userMarkGuid, int color) async {
    try {
      await _database.rawUpdate('''
      UPDATE UserMark 
      SET ColorIndex = ? 
      WHERE UserMarkGuid = ?
    ''', [color, userMarkGuid]);

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to change color for highlight with UserMarkGuid.');
    }
  }

  Future<void> addHighlightToDoc(Publication publication, Document document, List<dynamic> highlightsParagraphs, int colorIndex, String uuid) async {
    try {
      // Étape 1 : Obtenir ou insérer le LocationId via insertLocation
      final locationId = await insertLocationWithDocument(publication, document);

      // Étape 2 : Insérer dans la table UserMark
      final userMarkId = await _database.insert('UserMark', {
        'ColorIndex': colorIndex,
        'LocationId': locationId,
        'StyleIndex': 0, // Valeur par défaut
        'UserMarkGuid': uuid,
        'Version': 1,
      });

      // Étape 3 : Insérer dans la table BlockRange
      for(Map<String, dynamic> highlight in highlightsParagraphs) {
        await _database.insert('BlockRange', {
          'UserMarkId': userMarkId,
          'BlockType': highlight['blockType'],
          'Identifier': int.parse(highlight['identifier'].toString()),
          'StartToken': highlight['startToken'],
          'EndToken': highlight['endToken']
        });
      }

    } catch (e) {
      printTime('Erreur dans addHighlightToDoc: $e');
      throw Exception('Échec de l\'ajout du surlignage pour ce document.');
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

  Future<void> getNotes() async {
    File catalogFile = await getCatalogFile();

    if (await catalogFile.exists()) {
      await _database.execute("ATTACH DATABASE '${catalogFile.path}' AS catalog");

      List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT DISTINCT
             Note.NoteId,
             Note.Title,
             Note.Content,
             COALESCE(UserMark.ColorIndex, 0) AS ColorIndex,
             Note.Guid,
             Note.Created,
             Note.LastModified,
             COALESCE(catalog.Publication.ShortTitle, '') AS ShortTitle,
             COALESCE(Location.DocumentId, '') AS DocumentId,
             COALESCE(Location.IssueTagNumber, 0) AS IssueTagNumber,
             COALESCE(Location.KeySymbol, '') AS KeySymbol,
             COALESCE(Location.MepsLanguage, 0) AS MepsLanguage,
             (SELECT catalog.ImageAsset.NameFragment
               FROM catalog.ImageAsset
               JOIN catalog.PublicationAssetImageMap ON ImageAsset.Id = catalog.PublicationAssetImageMap.ImageAssetId
               JOIN catalog.Publication ON catalog.Publication.KeySymbol = Location.KeySymbol 
                  AND catalog.Publication.MepsLanguageId = Location.MepsLanguage 
                  AND catalog.Publication.IssueTagNumber = Location.IssueTagNumber
               JOIN catalog.PublicationAsset ON catalog.PublicationAsset.PublicationId = catalog.Publication.Id
               WHERE catalog.PublicationAssetImageMap.PublicationAssetId = catalog.PublicationAsset.Id 
                 AND (catalog.ImageAsset.NameFragment LIKE '%_sqr-%' OR (catalog.ImageAsset.Width = 600 AND catalog.ImageAsset.Height = 600))
               ORDER BY catalog.ImageAsset.Width DESC
               LIMIT 1) AS ImageSqr,
             COALESCE(catalog.Publication.PublicationTypeId, 0) AS PublicationTypeId,
             GROUP_CONCAT(Tag.TagId) AS CategoriesId,
             GROUP_CONCAT(Tag.Name) AS CategoriesName
      FROM Note
      LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
      LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
      LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
      LEFT JOIN Location ON Note.LocationId = Location.LocationId
      LEFT JOIN catalog.Publication ON catalog.Publication.KeySymbol = Location.KeySymbol 
          AND catalog.Publication.MepsLanguageId = Location.MepsLanguage 
          AND catalog.Publication.IssueTagNumber = Location.IssueTagNumber
      GROUP BY Note.NoteId
      ORDER BY Note.LastModified DESC;
''');

      await _database.execute("DETACH DATABASE catalog");

      notes = result;
    }
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
          GROUP_CONCAT(Tag.TagId) AS CategoriesId,
          GROUP_CONCAT(Tag.Name) AS CategoriesName
        FROM Location
        INNER JOIN Note ON Location.LocationId = Note.LocationId
        LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
        LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
        LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
        WHERE Location.DocumentId = ? 
          AND Location.MepsLanguage = ?
        GROUP BY Note.NoteId
        ORDER BY Note.BlockIdentifier ASC
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
          GROUP_CONCAT(Tag.TagId) AS CategoriesId,
          GROUP_CONCAT(Tag.Name) AS CategoriesName
        FROM Location
        INNER JOIN Note ON Location.LocationId = Note.LocationId
        LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
        LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
        LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
        WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.MepsLanguage = ?
        GROUP BY Note.NoteId
        ORDER BY Note.BlockIdentifier ASC
    ''', [bookId, chapterId, mepsLang]);

      return notesData;

    } catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> addNoteToDocId(Document document, int blockType, int identifier, String title, String uuid, String? userMarkGuid) async {
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
      locationId ??= await insertLocationWithDocument(document.publication, document);

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

  void removeNoteWithGuid(String noteGuid) async {
    try {
      await _database.rawDelete('''
      DELETE FROM Note WHERE Guid = ?
    ''', [noteGuid]);

    }
    catch (e) {
      printTime('Error: $e');
      throw Exception('Failed to remove note with Guid.');
    }
  }

  Future<Map<String, dynamic>> addNote(String title, String content, int? colorIndex, List<int> categoryIds, int? mepsDocumentId, int? bookNumber, int? chapterNumber, int? issueTagNumber, String? keySymbol, int? mepsLanguageId, {int blockType = 0, int? blockIdentifier}) async {
    try {
      final int locationId = await insertLocation(mepsDocumentId, bookNumber, chapterNumber, issueTagNumber, keySymbol, mepsLanguageId);

      int? userMarkId;
      if (colorIndex != null) {
        final userMarkGuid = Uuid().v4(); // Generates a version 4 UUID

        // Insérer une nouvelle entrée dans la table UserMark avec un LocationId valide
        userMarkId = await _database.insert('UserMark', {
          'ColorIndex': colorIndex,  // Insérer le ColorIndex
          'LocationId': locationId,  // Associer à un LocationId valide
          'StyleIndex': 0,  // Insérer un StyleIndex valide
          'UserMarkGuid': userMarkGuid,  // Générer un GUID unique
          'Version': 1,  // Insérer une version valide
        });
      }

      final guidNote = Uuid().v4(); // Generates a version 4 UUID

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

      final note = await _database.query('Note', where: 'NoteId = ?', whereArgs: [noteId]);
      return note.first;
    }
    catch (e) {
      printTime('Erreur lors de l\'ajout de la note : $e');
      return {};
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
      throw Exception('Failed to change color for highlight with UserMarkGuid.');
    }
  }

  Future<Map<String, dynamic>> updateNote(
      Map<String, dynamic> note,
      String title,
      String content,{
      int? colorIndex,
      List<int>? categoryIds}
      ) async {
    try {
      int noteId = note['NoteId'];
      int? userMarkId = note['UserMarkId'];

      if (userMarkId != null) {
        await _database.update(
          'UserMark',
          {'ColorIndex': colorIndex ?? 0},
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
      note['Title'] = title;
      note['Content'] = content;
      note['ColorIndex'] = colorIndex;
      note['LastModified'] = lastModified;

      return note;
    }
    catch (e) {
      printTime('Erreur lors de la mise à jour de la note : $e');
      return {};
    }
  }

  Future<bool> deleteNote(Map<String, dynamic> note) async {
    try {
      int noteId = note['NoteId'];
      int? userMarkId = note['UserMarkId'];

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

      // Supprimer l'entrée associée dans la table UserMark si elle existe
      if (userMarkId != null) {
        await _database.delete(
          'UserMark',
          where: 'UserMarkId = ?',
          whereArgs: [userMarkId],
        );
      }

      printTime('Note supprimée avec succès');
      return true;

    } catch (e) {
      printTime('Erreur lors de la suppression de la note : $e');
      return false;
    }
  }


  Future<List<Map<String, dynamic>>> getNotesByCategory(int categoryId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT Note.NoteId,
           Note.Title,
           Note.Content,
           UserMark.ColorIndex,
           Note.Guid,
           Note.Created,
           Note.LastModified,
           GROUP_CONCAT(Tag.TagId) AS CategoriesId,
           GROUP_CONCAT(Tag.Name) AS CategoriesName
    FROM Note
    LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
    LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
    LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
    WHERE Note.NoteId IN (SELECT Note.NoteId FROM Note LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
    WHERE TagMap.TagId = ?)
    GROUP BY Note.NoteId
  ''', [categoryId]);

    return result;
  }

  Map<String, dynamic> getNoteById(int noteId) {
    return notes.firstWhere((note) => note['NoteId'] == noteId);
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
      printTime('Fichier de sauvegarde prêt et partagé : $filePath');
    } catch (e, stackTrace) {
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
        return iosInfo.name ?? 'iOS Device'; // Nom de l'appareil iOS
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

    favorites = [];
    tags = [];
    notes = [];
    _database = await openDatabase(userdataDbPath, version: schemaVersion);
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

