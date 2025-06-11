import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/startup/copy_assets.dart';
import 'package:jwlife/core/assets.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class Userdata {
  late Database _database;
  List<Publication> favorites = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> notes = [];

  Future<void> init() async {
    File userdataFile = await getUserdataFile();
    if (await userdataFile.exists()) {
      _database = await openDatabase(userdataFile.path, version: 1);
      await getFavorites();
      getCategories();
      //await getNotes();
    }
  }

  Future<void> reload_db() async {
    await _database.close();
    await init();
  }

  void clearData() {
    favorites.clear();
    categories.clear();
    notes.clear();
  }

  Future<void> getFavorites() async {
    favorites = [];
    try {
      File catalogFile = await getCatalogFile();
      File mepsFile = await getMepsFile();

      if (catalogFile.existsSync() && mepsFile.existsSync()) {
        Database catalog = await openReadOnlyDatabase(catalogFile.path);

        await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
        await catalog.execute("ATTACH DATABASE '${_database.path}' AS userdata");

        final List<Map<String, dynamic>> result = await catalog.rawQuery('''
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

        await catalog.execute("DETACH DATABASE meps");
        await catalog.execute("DETACH DATABASE userdata");

        await catalog.close();

        if (result.isNotEmpty) {
          favorites = result.map((row) => Publication.fromJson(row)).toList();
        }
      }
    }
    catch (e) {
      print('Erreur: $e');
      throw Exception('Échec de chargement des favoris.');
    }
  }

  bool isPubFavorite(Publication publication) {
    return favorites.any((p) => p.keySymbol == publication.keySymbol && p.mepsLanguage.symbol == publication.mepsLanguage.symbol && p.issueTagNumber == publication.issueTagNumber);
  }


  Future<void> addPubFavorite(Publication publication) async {
    try {
      // Récupère les informations nécessaires du Map publication
      String keySymbol = publication.keySymbol;
      int issueTagNumber = publication.issueTagNumber;
      int mepsLanguageId = publication.mepsLanguage.id;

      // Vérifie si la publication existe déjà dans TagMap
      var existsResult = await _database.rawQuery('''
      SELECT COUNT(*) as count FROM TagMap
      JOIN Location ON TagMap.LocationId = Location.LocationId
      WHERE Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND TagMap.TagId = ?
    ''', [issueTagNumber, keySymbol, mepsLanguageId, 1]); // Remplacez 1 par la valeur appropriée pour TagId

      int existsCount = existsResult.first['count'] as int;
      if (existsCount > 0) {
        print('Publication already exists in favorites.');
        return; // Si la publication existe déjà, on ne fait rien
      }

      // Insère dans la table Location et récupère l'LocationId
      int locationId = await _database.rawInsert(''' 
      INSERT INTO Location (LocationId, IssueTagNumber, KeySymbol, MepsLanguage, Type)
      VALUES (NULL, ?, ?, ?, 1)
    ''', [issueTagNumber, keySymbol, mepsLanguageId]);

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

      Publication? pub = await PubCatalog.searchPub(keySymbol, issueTagNumber, mepsLanguageId);

      if (pub == null) {
        favorites.add(publication);
      }
      else {
        favorites.add(pub);
      }
    }
    catch (e) {
      print('Error: $e');
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
      print('Error: $e');
      throw Exception('Failed to remove from TagMap and Location.');
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
      print('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> updateOrInsertInputField(Publication publication, int docId, String textTag, String value) async {
    try {
      // Step 1: Retrieve LocationId, if it exists
      final result = await _database.rawQuery('''
      SELECT LocationId FROM Location 
      WHERE DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ?
    ''', [docId, publication.issueTagNumber, publication.keySymbol]);

      int? locationId = result.isNotEmpty ? result.first['LocationId'] as int? : null;

      // Step 2: Insert into Location if no LocationId exists
      locationId ??= await _database.rawInsert(''' 
        INSERT INTO Location (DocumentId, IssueTagNumber, KeySymbol, Type)
        VALUES (?, ?, ?, 0)
      ''', [docId, publication.issueTagNumber, publication.keySymbol]);

      // Step 3: Insert or update the InputField
      await _database.rawInsert('''
      INSERT INTO InputField (LocationId, TextTag, Value)
      VALUES (?, ?, ?)
      ON CONFLICT(LocationId, TextTag) DO UPDATE SET
        Value = excluded.Value
    ''', [locationId, textTag, value]);
    } catch (e) {
      // Log detailed error for debugging
      print('Error in updateOrInsertInputField: $e');
      throw Exception('Failed to update or insert InputField: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getHighlightsFromChapterNumber(int bookId, int chapterId, int mepsLang) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> highlights = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.BookNumber = ? AND Location.ChapterNumber = ? AND Location.MepsLanguage = ?
            ''', [bookId, chapterId, mepsLang]
      );

      return highlights;

    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load highlights for the given DocumentId and MepsLanguage.');
    }
  }

  Future<List<Map<String, dynamic>>> getHighlightsFromDocId(int docId, int mepsLang) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> highlights = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex
            FROM Location
            LEFT JOIN UserMark ON Location.LocationId = UserMark.LocationId
            LEFT JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
            WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?
            ''', [docId, mepsLang]
      );

      return highlights;

    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load highlights for the given DocumentId and MepsLanguage.');
    }
  }

  void addHightlightsToDocId(Map<String, dynamic> publication, int docId, int paragraphIndex, int colorIndex, int startToken, int endToken) async {
    try {
      // Step 1: Insert into Location table, include Type
      final locationId = await _database.insert('Location', {
        'DocumentId': docId,
        'IssueTagNumber': publication['IssueTagNumber'] ?? 0,
        'KeySymbol': publication['KeySymbol'] ?? '',
        'MepsLanguage': publication['MepsLanguageId'] ?? 0,
        'Type': 0,
      });

      // Step 2: Generate a unique UserMarkGuid
      final userMarkGuid = Uuid().v4(); // Generates a version 4 UUID

      // Step 3: Insert into UserMark table using the new LocationId
      final userMarkId = await _database.insert('UserMark', {
        'ColorIndex': colorIndex,
        'LocationId': locationId, // Now using the newly created LocationId
        'StyleIndex': 0,          // Assuming a default value
        'UserMarkGuid': userMarkGuid, // Using the generated UserMarkGuid
        'Version': 1,
      });

      // Step 4: Insert into BlockRange table
      await _database.insert('BlockRange', {
        'BlockType': 1, // Assuming BlockType is always 1 for highlights
        'Identifier': paragraphIndex,
        'StartToken': startToken,
        'EndToken': endToken,
        'UserMarkId': userMarkId,
      });

    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to add highlights for the given DocumentId and ParagraphIndex.');
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
      print('Error: $e');
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
      print('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> getCategories() async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT Tag.TagId AS TagId,
        Tag.Name
        FROM Tag
        WHERE Tag.Type = 1
    ''');

    categories = result;
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
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> locationData = await _database.rawQuery('''
          SELECT Location.LocationId AS LocationId
          FROM Location
          WHERE Location.DocumentId = ? AND Location.MepsLanguage = ?
          ''', [docId, mepsLang]
      );

      if (locationData.isEmpty) {
        return [];
      }
      else {
        int locationId = locationData.first['LocationId'];

        print('locationId: $locationId');

        // Retrieve the notes associated with the LocationId
        List<Map<String, dynamic>> notesData = await _database.rawQuery('''
           SELECT Note.NoteId,
           Note.Guid,
           Note.UserMarkId,
           Note.LocationId,
           Note.Title,
           Note.Content,
           Note.LastModified,
           Note.Created,
           Note.BlockType,
           Note.BlockIdentifier,
           UserMark.ColorIndex,
           GROUP_CONCAT(Tag.TagId) AS CategoriesId,
           GROUP_CONCAT(Tag.Name) AS CategoriesName
              FROM Note
              LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
              LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
              LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
              LEFT JOIN Location ON Note.LocationId = Location.LocationId
              WHERE Note.LocationId = ?
              GROUP BY Note.NoteId
              ORDER BY Note.BlockIdentifier ASC
          ''', [locationId]
        );

        return notesData;
      }

    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<Map<String, dynamic>> addNote(
      String title,
      String content,
      int? colorIndex,
      List<int> categoryIds,
      int? mepsDocumentId,
      int? issueTagNumber,
      String? keySymbol,
      int? mepsLanguageId,
      {int blockType = 0, int? blockIdentifier}
      ) async {
    try {
      int? locationId;
      if (mepsDocumentId != null && issueTagNumber != null && keySymbol != null && mepsLanguageId != null) {
        // Insérer une nouvelle entrée dans la table UserMark avec un LocationId valide
        locationId = await _database.insert('Location', {
          'DocumentId': mepsDocumentId,  // Associer à un DocumentId valide
          'IssueTagNumber': issueTagNumber,  // Associer à un IssueTagNumber valide
          'KeySymbol': keySymbol,  // Associer à une KeySymbol valide
          'MepsLanguage': mepsLanguageId,  // Associer à un MepsLanguageId valide
          'Type': 0,  // Insérer un Type valide
        });
      }

      int? userMarkId;
      if (locationId != null && colorIndex != null) {
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
      print('Erreur lors de l\'ajout de la note : $e');
      return {};
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
      print('Erreur lors de la mise à jour de la note : $e');
      return {};
    }
  }

  Future<bool> deleteNote(Map<String, dynamic> note) async {
    try {
      int noteId = note['NoteId'];
      int? userMarkId = note['UserMarkId'];
      int? locationId = note['LocationId'];

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

      print('Note supprimée avec succès');
      return true;

    } catch (e) {
      print('Erreur lors de la suppression de la note : $e');
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

  getNoteById(int noteId) {
    return notes.firstWhere((note) => note['NoteId'] == noteId);
  }

  Future<Map<String, dynamic>> addCategory(String name, int type) async {
    try {
      // Insérer une nouvelle entrée dans la table UserMark avec un LocationId valide
      int categoryId = await _database.insert('Tag', {
        'Type': type,  // Insérer un Type valide
        'Name': name
      });
      // Mettre à jour la liste des notes locales après ajout
      await getCategories();

      // Retourner la nouvelle note ajoutée
      var category = categories.firstWhere((note) => note['TagId'] == categoryId);
      print('Nouvelle categorie ajoutée : $category');
      return category;

    }
    catch (e) {
      print('Erreur lors de l\'ajout de la note : $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> updateCategory(Map<String, dynamic> category, String name) async {
    try {
      await _database.update(
        'Tag',
        {'Name': name},
        where: 'TagId = ?',
        whereArgs: [category['TagId']],
      );

      // Mettre à jour la liste locale après modification
      await getCategories();

      return categories.firstWhere((cat) => cat['TagId'] == category['TagId']);
    }
    catch (e) {
      print('Erreur lors de la mise à jour du tag : $e');
      return {};
    }
  }

  Future<bool> deleteCategory(Map<String, dynamic> tag) async {
    try {
      int count = await _database.delete(
        'Tag',
        where: 'TagId = ?',
        whereArgs: [tag['TagId']],
      );

      // Mettre à jour la liste locale après suppression
      await getCategories();

      return count > 0;
    }
    catch (e) {
      print('Erreur lors de la suppression du tag : $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarksFromPub(Publication publication) async {
    try {
      // Retrieve the unique LocationId
      List<Map<String, dynamic>> bookmarks = await _database.rawQuery('''
          SELECT DISTINCT 
            Bookmark.Slot,
            Bookmark.Title,
            Bookmark.Snippet,
            Bookmark.BlockType,
            Bookmark.BlockIdentifier,
            Location.BookNumber,
            Location.ChapterNumber,
            Location.DocumentId
          FROM Bookmark
          JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Location.KeySymbol = ? AND Location.IssueTagNumber = ? AND Location.MepsLanguage = ?
          ''', [publication.keySymbol, publication.issueTagNumber, publication.mepsLanguage.id]
      );

      return bookmarks;
    }
    catch (e) {
      print('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<Map<String, dynamic>> addBookmark(
      Publication publication,
      int? mepsDocumentId,
      int? bookNumber,
      int? chapterNumber,
      String title,
      String snippet,
      int slot,
      int blockType,
      int? blockIdentifier) async {
    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    int mepsLanguageId = publication.mepsLanguage.id;

    try {
      int? locationId = -1;

      if(mepsDocumentId != null) {
         locationId = await _database.insert('Location', {
          'DocumentId': mepsDocumentId,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
        });
      }
      else if(bookNumber != null && chapterNumber != null) {
        locationId = await _database.insert('Location', {
          'BookNumber': bookNumber,
          'ChapterNumber': chapterNumber,
          'IssueTagNumber': issueTagNumber,
          'KeySymbol': keySymbol,
          'MepsLanguage': mepsLanguageId,
          'Type': 0,
          'Title': blockIdentifier != null ? "$title:$blockIdentifier": title
        });
      }

      // Vérifier si publicationLocationId existe déjà
      List<Map<String, dynamic>> existingLocation = await _database.query(
        'Location',
        columns: ['LocationId'],
        where: 'IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 1',
        whereArgs: [issueTagNumber, keySymbol, mepsLanguageId],
        limit: 1,
      );

      int publicationLocationId;
      if (existingLocation.isNotEmpty) {
        publicationLocationId = existingLocation.first['LocationId'];
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

      int bookmarkId = await _database.insert('Bookmark', {
        'LocationId': locationId,
        'PublicationLocationId': publicationLocationId,
        'Slot': slot,
        'Title': title,
        'Snippet': snippet,
        'BlockType': blockType,
        'BlockIdentifier': blockIdentifier,
      });


      // Récupérer et retourner le signet mis à jour avec une requête raw
      List<Map<String, dynamic>> result = await _database.rawQuery(
        '''
          SELECT 
            Bookmark.Slot,
            Bookmark.Title,
            Bookmark.Snippet,
            Bookmark.BlockType,
            Bookmark.BlockIdentifier,
            Location.DocumentId
          FROM Bookmark
            JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Bookmark.BookmarkId = ?
          LIMIT 1
        ''',
        [bookmarkId], // Paramètre pour la condition WHERE
      );

      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      print('Erreur lors de l\'ajout du bookmark : $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> updateBookmark(
      Publication publication,
      int slot,
      int mepsDocumentId,
      String title,
      String snippet,
      int blockType,
      int? blockIdentifier) async {

    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    int mepsLanguageId = publication.mepsLanguage.id;

    try {
      // Vérifier si un signet existe pour cette publication et ce slot
      List<Map<String, dynamic>> existingBookmark = await _database.query(
        'Bookmark',
        where: 'Slot = ? AND PublicationLocationId IN ('
            'SELECT LocationId FROM Location '
            'WHERE IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 1)',
        whereArgs: [slot, issueTagNumber, keySymbol, mepsLanguageId],
        limit: 1,
      );

      print('existingBookmark: $existingBookmark');

      if (existingBookmark.isNotEmpty) {
        // Mettre à jour le signet existant
        await _database.update(
          'Bookmark',
          {
            'Title': title,
            'Snippet': snippet,
            'BlockType': blockType,
            'BlockIdentifier': blockIdentifier,
          },
          where: 'BookmarkId = ?',
          whereArgs: [existingBookmark.first['BookmarkId']],
        );

        await _database.update(
          'Location',
          {
            'DocumentId': mepsDocumentId
          },
          where: 'LocationId = ?',
          whereArgs: [existingBookmark.first['LocationId']],
        );
      }

      // Récupérer et retourner le signet mis à jour avec une requête raw
      List<Map<String, dynamic>> result = await _database.rawQuery(
        '''
          SELECT 
            Bookmark.Slot,
            Bookmark.Title,
            Bookmark.Snippet,
            Bookmark.BlockType,
            Bookmark.BlockIdentifier,
            Location.DocumentId
          FROM Bookmark
            JOIN Location ON Bookmark.LocationId = Location.LocationId
          WHERE Bookmark.BookmarkId = ?
          LIMIT 1
        ''',
        [existingBookmark.first['BookmarkId']], // Paramètre pour la condition WHERE
      );

      print('result: ${result.first}');

      return result.isNotEmpty ? result.first : {};

    } catch (e) {
      print('Erreur lors de la mise à jour du bookmark : $e');
      return {};
    }
  }

  Future<bool> removeBookmark(Publication publication, dynamic bookmark) async {
    try {
      // Trouver l'ID de la location associée
      List<Map<String, dynamic>> locationResult = await _database.rawQuery(
          '''
            SELECT Location.LocationId
            FROM Location
            JOIN Bookmark ON Location.LocationId = Bookmark.LocationId
            WHERE DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ? AND MepsLanguage = ? AND Type = 0 
            LIMIT 1
          ''',
          [
            bookmark['DocumentId'],
            publication.issueTagNumber,
            publication.keySymbol,
            publication.mepsLanguage.id,
          ]
      );

      print('locationResult: $locationResult');

      if (locationResult.isEmpty) {
        print('Aucun emplacement trouvé pour ce signet.');
        return false;
      }

      int locationId = locationResult.first['LocationId'];

      // On vérifie que il n'y qu'un seul signet dans cette location si non on ne supprime pas le Location
      List<Map<String, dynamic>> bookmarkResult = await _database.query(
        'Bookmark',
        columns: ['BookmarkId'],
        where: 'LocationId = ?',
        whereArgs: [locationId],
      );

      print('bookmarkResult: $bookmarkResult');

      if (bookmarkResult.length == 1) {
        await _database.delete(
          'Location',
          where: 'LocationId = ?',
          whereArgs: [locationId],
        );
      }

      // Supprimer le signet correspondant
      int deletedCount = await _database.delete(
        'Bookmark',
        where: 'LocationId = ? AND Slot = ?',
        whereArgs: [locationId, bookmark['Slot']],
      );

      if (deletedCount > 0) {
        print('Bookmark supprimé avec succès.');
        return true;
      }
      else {
        print('Aucun signet correspondant trouvé.');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la suppression du bookmark : $e');
      return false;
    }
  }

  Future<void> updateLastModified(String timeStamp) async {
    try {
      await _database.rawUpdate(
        'UPDATE LastModified SET LastModified = ?',
        [timeStamp],
      );

      _database.close();
      print('LastMod updated to $timeStamp ✅');
    }
    catch (e) {
      print('Error: $e ⚠️');
    }
  }

  Future<void> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        PlatformFile file = result.files.first;

        try {
          Directory userDataDir = await getAppUserDataDirectory();
          if (await userDataDir.exists()) {
            await userDataDir.delete(recursive: true);
          }
          await userDataDir.create(recursive: true);

          List<int> bytes = File(file.path!).readAsBytesSync();
          Archive archive = ZipDecoder().decodeBytes(bytes);
          for (ArchiveFile archiveFile in archive) {
            File newFile = File('${userDataDir.path}/${archiveFile.name}');
            await newFile.writeAsBytes(archiveFile.content);
          }

          File userDataFile = File('${userDataDir.path}/userData.db');
          if (await userDataFile.exists()) {
            print('Importation du fichier UserData');
            await reload_db();
          }
        } catch (e) {
          print('Erreur lors du traitement du fichier UserData : $e');
        }
      }
    } catch (e) {
      print('Erreur lors de l\'importation du fichier UserData : $e');
    }
  }

  Future<void> exportBackup() async {
    // Demander la permission de stockage
    PermissionStatus status = await Permission.manageExternalStorage.request();

    if (!status.isGranted) {
      print('Permission de stockage non accordée.');
      return;
    }

    try {
      //await closeDatabase();

      Directory userDataDir = await getAppUserDataDirectory();
      if (!await userDataDir.exists()) {
        print('Le répertoire de données utilisateur n\'existe pas.');
        return;
      }

      Archive archive = Archive();

      DateTime currentTimestamp = DateTime.now().toUtc();
      String formattedTimestamp = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(currentTimestamp);
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String deviceName = await _getDeviceName();
      String fileName = 'UserdataBackup_${currentDate}_$deviceName.jwlibrary';

      String hash = await sha256hashOfFile('${userDataDir.path}/userData.db');

      List<FileSystemEntity> files = userDataDir.listSync(recursive: true);
      for (var fileEntity in files) {
        if (fileEntity is File) {
          String filePath = fileEntity.path;
          if (!filePath.endsWith('manifest.json')) {
            try {
              List<int> fileBytes = await File(filePath).readAsBytes();
              archive.addFile(ArchiveFile(path.basename(filePath), fileBytes.length, fileBytes));
            } catch (e) {
              print('Erreur lors de la lecture du fichier $filePath : $e');
            }
          }
        }
      }

      Map<String, dynamic> manifestData = {
        "name": fileName,
        "creationDate": currentDate,
        "version": 1,
        "type": 0,
        "userDataBackup": {
          "lastModifiedDate": formattedTimestamp,
          "deviceName": deviceName,
          "databaseName": "userData.db",
          "hash": hash,
          "schemaVersion": 14
        }
      };
      String manifestJson = jsonEncode(manifestData);
      archive.addFile(ArchiveFile('manifest.json', manifestJson.length, utf8.encode(manifestJson)));

      Uint8List bytes = Uint8List.fromList(ZipEncoder().encode(archive, level: DeflateLevel.bestSpeed)!);

      // Enregistrer le fichier temporairement
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final outputFile = File(filePath);
      await outputFile.writeAsBytes(bytes);

      // Partager le fichier
      await Share.shareXFiles([XFile(filePath)], text: 'Voici une sauvegarde de mes données.');

      print('Fichier de sauvegarde prêt et partagé : $filePath');
    } catch (e) {
      print('Erreur lors de l\'exportation de la sauvegarde : $e');
    } finally {
      await reload_db();
    }
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
    await closeDatabase();
    Directory userDataDir = await getAppUserDataDirectory();
    if (await userDataDir.exists()) {
      await userDataDir.delete(recursive: true);
    }
    await userDataDir.create(recursive: true);

    // supprimer tous les éléments du dossier userDataDir
    List<FileSystemEntity> entities = await userDataDir.list().toList();
    for (FileSystemEntity entity in entities) {
      await entity.delete(recursive: true);
    }

    await CopyAssets.copyFileFromAssetsToDirectory(Assets.userDataUserData, '${userDataDir.path}/userData.db');
    await CopyAssets.copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png');
    await reload_db();
  }

  Future<void> closeDatabase() async {
    // Implémentation spécifique selon ton gestionnaire de base (Realm, SQLite, etc.)
    await _database.close(); // Exemple pour SQLite
  }
}
