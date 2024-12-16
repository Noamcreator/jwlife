import 'dart:io';
import 'dart:ui';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../utils/directory_helper.dart';
import '../utils/files_helper.dart';
import '../utils/utils_jwpub.dart';

class Userdata {
  late Database _database;
  List<Map<String, dynamic>> favorites = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> notes = [];

  Userdata();

  Future<void> init() async {
    File userdataFile = await getUserdataFile();
    if (await userdataFile.exists()) {
      _database = await openDatabase(userdataFile.path, version: 1);
      await load_db();
    }
  }

  Future<void> load_db() async {
    await getFavorites();
    getCategories();
    getNotes();
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
      List<Map<String, dynamic>> favoritesSymbolAndLanguageData = await _database.rawQuery('''
      SELECT DISTINCT Location.KeySymbol, Location.MepsLanguage, Location.Type
      FROM Tag
      JOIN TagMap ON Tag.TagId = TagMap.TagId
      JOIN Location ON TagMap.LocationId = Location.LocationId
      WHERE Tag.Name = 'Favorite' AND Tag.Type = 0
      ORDER BY TagMap.Position ASC
    ''');

      File catalogFile = await getCatalogFile();
      File mepsFile = await getMepsFile();
      File pubCollectionsFile = await getPubCollectionsFile();

      if (favoritesSymbolAndLanguageData.isNotEmpty && await catalogFile.exists() && await mepsFile.exists() && await pubCollectionsFile.exists()) {
        Database catalog = await openReadOnlyDatabase(catalogFile.path);
        await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
        await catalog.execute("ATTACH DATABASE '${pubCollectionsFile.path}' AS pub_collections");
        await catalog.execute("ATTACH DATABASE '${_database.path}' AS userdata");

        for (Map<String, dynamic> favorite in favoritesSymbolAndLanguageData) {
          int mepsLanguageId = favorite['MepsLanguage'];
          String keySymbol = favorite['KeySymbol'];

          if (favorite['Type'] == 1) {
            List<Map<String, dynamic>> result = await catalog.rawQuery('''
          SELECT DISTINCT
    p.Id AS PublicationId,
    p.MepsLanguageId,
    meps.Language.Symbol AS LanguageSymbol,
    p.PublicationTypeId,
    p.IssueTagNumber,
    p.Title,
    p.IssueTitle,
    p.ShortTitle,
    p.CoverTitle,
    p.KeySymbol,
    p.Symbol,
    p.Year,
    pa.CatalogedOn,
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
        LIMIT 1) AS ImageLsr,
    (SELECT CASE WHEN COUNT(pc.Symbol) > 0 THEN 1 ELSE 0 END
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId) AS isDownload,
    (SELECT pc.Path
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Path,
    (SELECT pc.DatabasePath
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS DatabasePath,
    (SELECT pc.Hash
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Hash,
    (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
        FROM userdata.TagMap tg
        JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
        WHERE userdata.Location.IssueTagNumber = p.IssueTagNumber 
        AND userdata.Location.KeySymbol = p.KeySymbol 
        AND userdata.Location.MepsLanguage = p.MepsLanguageId 
        AND tg.TagId = 1) AS isFavorite
          FROM
    Publication p
LEFT JOIN
    PublicationAsset pa ON p.Id = pa.PublicationId
LEFT JOIN
    PublicationRootKey prk ON p.PublicationRootKeyId = prk.Id
LEFT JOIN
    PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
LEFT JOIN
    ImageAsset ia ON paim.ImageAssetId = ia.Id
LEFT JOIN
    meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          WHERE 
            p.KeySymbol = ? AND pa.MepsLanguageId = ?
        ''', [keySymbol, mepsLanguageId]);

            if (result.isNotEmpty) {
              favorites.add(result.first);
            }
          }
        }

        await catalog.execute("DETACH DATABASE userdata");
        await catalog.execute("DETACH DATABASE pub_collections");
        await catalog.execute("DETACH DATABASE meps");
        await catalog.close();
      }
    }
    catch (e) {
      print('Erreur: $e');
      throw Exception('Échec de chargement des favoris.');
    }
  }

  Future<bool> isPubFavorite(Map<String, dynamic> publication) async {
    try {
      // Récupère les informations nécessaires du Map publication
      String keySymbol = publication['KeySymbol'];
      int issueTagNumber = publication['IssueTagNumber'];
      int mepsLanguageId = publication['MepsLanguageId'];

      // Vérifie si la publication existe déjà dans TagMap
      var existsResult = await _database.rawQuery('''
      SELECT COUNT(*) as count FROM TagMap
      JOIN Location ON TagMap.LocationId = Location.LocationId
      WHERE Location.IssueTagNumber = ? AND Location.KeySymbol = ? AND Location.MepsLanguage = ? AND TagMap.TagId = ?
    ''', [
        issueTagNumber,
        keySymbol,
        mepsLanguageId,
        1
      ]); // Remplacez 1 par la valeur appropriée pour TagId

      int existsCount = existsResult.first['count'] as int;
      if (existsCount > 0) {
        return true;
      }
      return false;
    }
    catch (e) {
      print('Error: $e');
      throw Exception('Échec de chargement des favoris.');
    }
  }


  Future<void> addPubFavorite(Map<String, dynamic> publication) async {
    try {
      // Récupère les informations nécessaires du Map publication
      String keySymbol = publication['KeySymbol'];
      int issueTagNumber = publication['IssueTagNumber'];
      int mepsLanguageId = publication['MepsLanguageId'];

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

      favorites.add(publication);
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to insert into TagMap and Location.');
    }
  }

  Future<void> removePubFavorite(Map<String, dynamic> publication) async {
    try {
      // Récupère les informations nécessaires du Map publication
      int issueTagNumber = publication['IssueTagNumber'];
      String keySymbol = publication['KeySymbol'];
      int mepsLanguageId = publication['MepsLanguageId'];

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

      favorites.remove(publication);
    } catch (e) {
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
          JOIN Location ON InputField.LocationId = Location.LocationId
          WHERE Location.DocumentId = ?
          ''', [docId]
      );

      print('inputFieldsData: $inputFieldsData');
      return inputFieldsData;

    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load notes for the given DocumentId and MepsLanguage.');
    }
  }

  Future<void> updateOrInsertInputField(
      Map<String, dynamic> publication,
      String textTag,
      int docId,
      String value) async {
    try {
      // Récupère les informations nécessaires du Map publication
      String keySymbol = publication['KeySymbol'];
      int issueTagNumber = publication['IssueTagNumber'];

      // Vérifier si l'entrée existe déjà dans InputField
      var result = await _database.rawQuery('''
      SELECT * FROM InputField
      INNER JOIN Location ON InputField.LocationId = Location.LocationId
      WHERE Location.DocumentId = ? AND InputField.TextTag = ?
    ''', [docId, textTag]);

      if (result.isNotEmpty) {
        // Si l'entrée existe, on la met à jour
        await _database.rawUpdate('''
        UPDATE InputField
        SET Value = ?
        WHERE LocationId = (
          SELECT LocationId FROM Location WHERE DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ?
        ) AND TextTag = ?
      ''', [value, docId, issueTagNumber, keySymbol, textTag]);
      }
      else {
        // Sinon, on l'insère
        await _database.rawInsert('''
        INSERT INTO InputField (LocationId, TextTag, Value)
        VALUES (
          (SELECT LocationId FROM Location WHERE DocumentId = ? AND IssueTagNumber = ? AND KeySymbol = ?),
          ?, ?
        )
      ''', [docId, issueTagNumber, keySymbol, textTag, value]);
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to update or insert InputField for the given DocumentId and TextTag.');
    }
  }

  Future<List<Map<String, dynamic>>> getHightlightsFromDocId(int docId, int mepsLang) async {
    try {
      // Joining Location, UserMark, and BlockRange tables to get all required data in one query
      List<Map<String, dynamic>> highlights = await _database.rawQuery('''
            SELECT BlockRange.BlockType, BlockRange.Identifier, BlockRange.StartToken, BlockRange.EndToken, UserMark.ColorIndex
            FROM Location
            JOIN UserMark ON Location.LocationId = UserMark.LocationId
            JOIN BlockRange ON UserMark.UserMarkId = BlockRange.UserMarkId
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

  Future<void> getCategories() async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT Tag.TagId AS TagId,
        Tag.Name AS TagName
        FROM Tag
        WHERE Tag.Type = 1
    ''');

    categories = result;
  }

  Future<void> getNotes() async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT Note.NoteId AS NoteId,
           Note.Title AS NoteTitle,
           Note.Content AS NoteContent,
           UserMark.ColorIndex AS NoteColorIndex,
           Note.Guid AS NoteGuid,
           Note.Created AS NoteCreated,
           Note.LastModified AS NoteLastModified,
           GROUP_CONCAT(Tag.TagId) AS CategoriesId,
           GROUP_CONCAT(Tag.Name) AS CategoriesName
    FROM Note
    LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId
    LEFT JOIN Tag ON TagMap.TagId = Tag.TagId
    LEFT JOIN UserMark ON Note.UserMarkId = UserMark.UserMarkId
    WHERE Note.NoteId IN (SELECT Note.NoteId FROM Note LEFT JOIN TagMap ON Note.NoteId = TagMap.NoteId)
    GROUP BY Note.NoteId
    ORDER BY Note.LastModified DESC
  ''');

    notes = result;
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
           SELECT Note.NoteId AS NoteId,
           Note.Guid AS NoteGuid,
           Note.UserMarkId AS UserMarkId,
           Note.LocationId AS LocationId,
           Note.Title AS NoteTitle,
           Note.Content AS NoteContent,
           Note.LastModified AS NoteLastModified,
           Note.Created AS NoteCreated,
           Note.BlockType AS BlockType,
           Note.BlockIdentifier AS BlockIdentifier,
           UserMark.ColorIndex AS NoteColorIndex,
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
      int colorIndex,
      List<int> categoryIds,
      int? mepsDocumentId,
      int? issueTagNumber,
      String? keySymbol,
      int? mepsLanguageId
      ) async {
    try {
      int? locationId = null;
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

      final userMarkGuid = Uuid().v4(); // Generates a version 4 UUID


      // Insérer une nouvelle entrée dans la table UserMark avec un LocationId valide
      int userMarkId = await _database.insert('UserMark', {
        'ColorIndex': colorIndex,  // Insérer le ColorIndex
        'LocationId': locationId,  // Associer à un LocationId valide
        'StyleIndex': 0,  // Insérer un StyleIndex valide
        'UserMarkGuid': userMarkGuid,  // Générer un GUID unique
        'Version': 1,  // Insérer une version valide
      });

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
        'BlockType': 0,
        'BlockIdentifier': null,
      });

      /*
      // Ajouter les catégories associées à la note dans la table TagMap avec une position unique pour chaque catégorie
      for (int categoryId in categoryIds) {
        await database.insert('TagMap', {
          'PlaylistItemId': null,
          'LocationId': null,  // Mettre LocationId à null
          'NoteId': noteId,  // Utiliser seulement NoteId
          'TagId': categoryId,
          'Position': 30,  // Incrémenter la position pour chaque TagId
        });
      }

       */

      // Mettre à jour la liste des notes locales après ajout
      await getNotes();

      // Retourner la nouvelle note ajoutée
      var note = getNoteById(noteId);
      print('Nouvelle note ajoutée : $note');
      return note;

    } catch (e) {
      print('Erreur lors de l\'ajout de la note : $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> updateNote(
      Map<String, dynamic> note,
      String title,
      String content,
      int colorIndex,
      List<int> categoryIds,
      ) async {
    try {
      int noteId = note['NoteId'];
      int userMarkId = note['UserMarkId'];

      await _database.update(
        'UserMark',
        {'ColorIndex': colorIndex},
        where: 'UserMarkId = ?',
        whereArgs: [userMarkId],
      );

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
      note['NoteTitle'] = title;
      note['NoteContent'] = content;
      note['NoteColorIndex'] = colorIndex;
      note['LastModified'] = lastModified;

      return note;
    } catch (e) {
      print('Erreur lors de la mise à jour de la note : $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getNotesByCategory(int categoryId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT Note.NoteId AS NoteId,
           Note.Title AS NoteTitle,
           Note.Content AS NoteContent,
           UserMark.ColorIndex AS NoteColorIndex,
           Note.Guid AS NoteGuid,
           Note.Created AS NoteCreated,
           Note.LastModified AS NoteLastModified,
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

  Future<Map<String, dynamic>> getMe() async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT Name,
           FirstName,
           Birthday,
           Adress,
           Gender,
           Job,
           KingdomHallId,
           GroupId,
           Role,
           BaptemDate,
           LastVisitDate,
           Pioneer,
           Anointed
    FROM Proclaimers
    WHERE Me = 1
  ''');

    for (Map<String, dynamic> proclaimer in result) {
      print('proclaimer: $proclaimer');
    }

    return result.first;
  }

  Future<List<Map<String, dynamic>>> getProclaimers(int kingdomHallId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
    SELECT Name,
           FirstName,
           Birthday,
           Adress,
           Gender,
           Job,
           KingdomHallId,
           GroupId,
           RoleId,
           BaptemDate,
           LastVisitDate,
           Pioneer,
           Anointed
    FROM Proclaimers
    WHERE Me = 0 AND KingdomHallId = ? 
  ''', [kingdomHallId]);

    return result;
  }

  getNoteById(int noteId) {
    return notes.firstWhere((note) => note['NoteId'] == noteId);
  }
}
