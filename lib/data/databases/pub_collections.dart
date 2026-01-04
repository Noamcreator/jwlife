import 'dart:io';

import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/document/local/dated_text_manager.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/utils_database.dart';
import '../../core/utils/utils_pub.dart';
import '../../features/document/local/documents_manager.dart';

class PubCollections {
  late Database _database;

  Future<void> init() async {
    final pubCollections = await getPubCollectionsDatabaseFile();
    _database = await openDatabase(
        pubCollections.path,
        version: 3,
        onCreate: (db, version) async {
          await createDbPubCollection(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if(oldVersion == 1 && newVersion == 2) {
            // Ajout de la colonne HeadingSearch
            await addColumnSafe(db, 'Publication', 'HeadingSearch', 'INTEGER DEFAULT 0');

            // Ajout de la colonne IsSingleDocument
            await addColumnSafe(db, 'Publication', 'IsSingleDocument', 'INTEGER DEFAULT 0');
          }
          if(oldVersion == 2 && newVersion == 3) {
            // Création de la table Document
            await db.execute("""
              CREATE TABLE IF NOT EXISTS "AvailableBibleBook" (
                "AvailableBibleBookId"	INTEGER NOT NULL,
                "PublicationId"	INTEGER,
                "Book"	INTEGER,
                PRIMARY KEY("AvailableBibleBookId" AUTOINCREMENT),
                FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
              );
            """);

            // Création de la table DatedText
            await db.execute("""
              CREATE TABLE IF NOT EXISTS "DatedText" (
                "DatedTextId"	INTEGER NOT NULL,
                "PublicationId"	INTEGER,
                "Start"	INTEGER NOT NULL,
                "End"	INTEGER NOT NULL,
                "Class"	INTEGER NOT NULL,
                PRIMARY KEY("DatedTextId" AUTOINCREMENT),
                FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
              );
            """);

            // Ajouter les index
            await db.execute("CREATE UNIQUE INDEX AvailableBibleBook_UserKey ON AvailableBibleBook(Book, PublicationId);");
            await db.execute("CREATE UNIQUE INDEX DatedText_UserKey ON DatedText(Start, End, Class, PublicationId);");
            await db.execute("CREATE UNIQUE INDEX Document_UserKey ON Document (PublicationId, MepsDocumentId);");
            await db.execute("CREATE INDEX IX_DatedText_PublicationId ON DatedText(PublicationId);");
            await db.execute("CREATE INDEX IX_Document_LanguageIndex_MepsDocumentId_PublicationId ON Document (LanguageIndex, MepsDocumentId, PublicationId);");
            await db.execute("CREATE INDEX IX_Image_Signature ON Image (Signature);");
            await db.execute("CREATE INDEX IX_Publication_Path_PublicationId_Hash_Timestamp ON Publication (Path, PublicationId, Hash, Timestamp);");
            await db.execute("CREATE INDEX IX_Publication_KeySymbol_MepsLanguageId_IssueTagNumber_PublicationId ON Publication (KeySymbol, MepsLanguageId, IssueTagNumber, PublicationId);");
            await db.execute("CREATE INDEX IX_Publication_MepsLanguageId_PublicationType_IssueTagNumber ON Publication (MepsLanguageId, PublicationType, IssueTagNumber);");
            await db.execute("CREATE INDEX IX_Publication_PublicationCategorySymbol_PublicationType_MepsLanguageId ON Publication (PublicationCategorySymbol, PublicationType, MepsLanguageId);");
            await db.execute("CREATE INDEX IX_Publication_PublicationType ON Publication (PublicationType);");
            await db.execute("CREATE UNIQUE INDEX Image_UserKey ON Image(PublicationId, Path);");
            await db.execute("CREATE UNIQUE INDEX PublicationAttribute_UserKey ON PublicationAttribute(PublicationId, Attribute);");
            await db.execute("CREATE UNIQUE INDEX PublicationIssueAttribute_UserKey ON PublicationIssueAttribute(PublicationId, Attribute);");
            await db.execute("CREATE UNIQUE INDEX PublicationIssueProperty_UserKey ON PublicationIssueProperty(PublicationId);");
            await db.execute("CREATE UNIQUE INDEX Publication_UserKey ON Publication(KeySymbol, MepsLanguageId, IssueTagNumber);");
          }
        }
    );
    await fetchDownloadPublications();
  }

  Future<void> fetchDownloadPublications() async {
    final mepsFile = await getMepsUnitDatabaseFile();

    printTime('fetchDownloadPublications start');

    await attachDatabases(_database, {'meps': mepsFile.path});

    try {
      final result = await _database.rawQuery('''
        WITH ImageData AS (
           SELECT 
               PublicationId,
               MAX(CASE WHEN Type = 't' AND Width = 270 AND Height = 270 THEN Path WHEN Type = 't' AND Width = 100 AND Height = 100 THEN Path ELSE NULL END) AS ImageSqr,
               MAX(CASE  WHEN Type = 'lsr' AND Width = 1200 AND Height = 600 THEN Path END) AS ImageLsr
           FROM Image
           WHERE 
               (Type = 't' AND ( (Width = 270 AND Height = 270) OR (Width = 100 AND Height = 100) ))
               OR (Type = 'lsr' AND Width = 1200 AND Height = 600)
           GROUP BY PublicationId
        )
        SELECT DISTINCT 
            p.*,
            GROUP_CONCAT(DISTINCT pa.Attribute) AS AttributeTypes,
            pip.Title AS IssueTitle,
            pip.CoverTitle,
            pip.UndatedSymbol,
            img.ImageSqr,
            img.ImageLsr,
            l.Symbol AS LanguageSymbol,
            l.VernacularName AS LanguageVernacularName,
            l.PrimaryIetfCode AS LanguagePrimaryIetfCode,
            l.IsSignLanguage AS IsSignLanguage,
            s.InternalName AS ScriptInternalName,
            s.DisplayName AS ScriptDisplayName,
            s.IsBidirectional AS IsBidirectional,
            s.IsRTL AS IsRTL,
            s.IsCharacterSpaced AS IsCharacterSpaced,
            s.IsCharacterBreakable AS IsCharacterBreakable,
            s.SupportsCodeNames AS SupportsCodeNames,
            s.HasSystemDigits AS HasSystemDigits,
            fallback.PrimaryIetfCode AS FallbackPrimaryIetfCode
        FROM Publication p
        LEFT JOIN PublicationAttribute pa ON pa.PublicationId = p.PublicationId
        LEFT JOIN PublicationIssueProperty pip ON pip.PublicationId = p.PublicationId
        INNER JOIN meps.Language l ON p.MepsLanguageId = l.LanguageId
        INNER JOIN meps.Script s ON l.ScriptId = s.ScriptId
        LEFT JOIN meps.Language fallback ON l.PrimaryFallbackLanguageId = fallback.LanguageId
        LEFT JOIN ImageData img ON img.PublicationId = p.PublicationId
        GROUP BY p.PublicationId;
      ''');

      // On consomme pleinement les résultats avant de détacher
      result.map((row) => Publication.fromJson(row)).toList();
    }
    finally {
      await detachDatabases(_database, ['meps']);
    }

    printTime('fetchDownloadPublications end');
  }

  Future<Publication?> getBibleBookFromAvailable(int bookNumber, String keySymbol, int mepsLanguageId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT 
        p.KeySymbol,
        p.IssueTagNumber,
        p.MepsLanguageId
      FROM Publication p
      INNER JOIN AvailableBibleBook a ON p.PublicationId = a.PublicationId
      WHERE a.Book = ? AND p.KeySymbol = ? AND p.MepsLanguageId = ?
      LIMIT 1
    ''', [bookNumber, keySymbol, mepsLanguageId]);

    if (result.isNotEmpty) {
      return PublicationRepository().getPublicationWithMepsLanguageId(result.first['KeySymbol'], result.first['IssueTagNumber'], result.first['MepsLanguageId']);
    }
    return null;
  }

  Future<Publication?> getDatedTextFromAvailable(int start, int end, String keySymbol, int mepsLanguageId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT 
        p.KeySymbol,
        p.IssueTagNumber,
        p.MepsLanguageId
      FROM Publication p
      INNER JOIN DatedText d ON p.PublicationId = d.PublicationId
      WHERE d.Start = ? AND d.End = ? AND p.KeySymbol = ? AND p.MepsLanguageId = ?
      LIMIT 1
    ''', [start, end, keySymbol, mepsLanguageId]);

    if (result.isNotEmpty) {
      return PublicationRepository().getPublicationWithMepsLanguageId(result.first['KeySymbol'], result.first['IssueTagNumber'], result.first['MepsLanguageId']);
    }
    return null;
  }

  Future<Publication?> getDocumentFromAvailable(int mepsDocId, int mepsLanguageId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT 
        p.KeySymbol,
        p.IssueTagNumber,
        d.LanguageIndex
      FROM Publication p
      INNER JOIN Document d ON p.PublicationId = d.PublicationId
      WHERE d.MepsDocumentId = ? AND p.MepsLanguageId = ?
      LIMIT 1
    ''', [mepsDocId, mepsLanguageId]);

    if (result.isNotEmpty) {
      return PublicationRepository().getPublicationWithMepsLanguageId(result.first['KeySymbol'], result.first['IssueTagNumber'], result.first['LanguageIndex']);
    }
    return null;
  }

  Future<List<Publication>> getBiblesBookFromAvailable(int bookNumber) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT p.KeySymbol
        FROM Publication p
        INNER JOIN AvailableBibleBook a ON p.PublicationId = a.PublicationId
        WHERE a.Book = ?
      ''', [bookNumber]);

    if (result.isNotEmpty) {
      // On extrait tous les KeySymbols trouvés
      List<String> symbols = result.map((row) => row['KeySymbol'] as String).toList();
      
      // On filtre la liste globale pour ne garder que les correspondances
      return PublicationRepository()
          .getAllBibles()
          .where((b) => symbols.contains(b.keySymbol))
          .toList();
    }
    return [];
  }

  Future<List<Publication>> getDatedTextsFromAvailable(int start, int end) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT p.KeySymbol
        FROM Publication p
        INNER JOIN DatedText d ON p.PublicationId = d.PublicationId
        WHERE d.Start = ? AND d.End = ?
      ''', [start, end]); // Suppression de keySymbol ici

    if (result.isNotEmpty) {
      List<String> symbols = result.map((row) => row['KeySymbol'] as String).toList();

      return PublicationRepository()
          .getAllDownloadedPublications()
          .where((p) => symbols.contains(p.keySymbol))
          .toList();
    }
    return [];
  }

  Future<List<Publication>> getDocumentsFromAvailable(int mepsDocId) async {
    List<Map<String, dynamic>> result = await _database.rawQuery('''
        SELECT 
          p.KeySymbol,
          p.IssueTagNumber
        FROM Publication p
        INNER JOIN Document d ON p.PublicationId = d.PublicationId
        WHERE d.MepsDocumentId = ?
      ''', [mepsDocId]);

    if (result.isNotEmpty) {
      // On crée un Set de clés uniques "SYMBOL-ISSUETAG" pour une recherche rapide O(1)
      final Set<String> targetKeys = result.map((row) {
        final symbol = row['KeySymbol'] as String;
        final issueTag = row['IssueTagNumber'] ?? 0; // Gère le cas null
        return "$symbol-$issueTag";
      }).toSet();

      return PublicationRepository()
          .getAllDownloadedPublications()
          .where((p) {
            // On compare la clé composite de l'objet Publication avec notre Set
            return targetKeys.contains("${p.keySymbol}-${p.issueTagNumber}");
          })
          .toList();
    }
    return [];
  }

  Future<Publication?> insertPublicationFromManifest(dynamic manifestData, Publication? publication, String path, {bool reOpenDocumentsManager = false, bool reOpenDatedTextManager = false}) async {
    try {
      dynamic pub = manifestData['publication'];
      String timeStamp = manifestData['timestamp'];
      int languageId = pub['language'];
      String symbol = pub['symbol'];
      int year = pub['year'] is String ? int.parse(pub['year']) : pub['year'];
      int issueTagNum = pub['issueId'];

      String keySymbol = '';

      if(publication != null) {
        keySymbol = publication.keySymbol;
      }
      else {
         keySymbol = pub['undatedSymbol'] ?? symbol;
      }

      // Préparation de la base de données de publication
      Database publicationDb = await openDatabase("$path/${pub['fileName']}", version: manifestData['schemaVersion'], readOnly: true);

      // Vérification de l'existence des tables Topics et VerseCommentary
      bool hasTopicsTable = await checkIfTableExists(publicationDb, 'Topic') && (await publicationDb.rawQuery("SELECT COUNT(*) FROM Topic")).first['COUNT(*)'] as int > 0;
      bool hasHeadingSearch = await checkIfTableExists(publicationDb, 'Heading') && (await publicationDb.rawQuery("SELECT COUNT(*) FROM Heading")).first['COUNT(*)'] as int > 0;
      bool hasVerseCommentaryTable = await checkIfTableExists(publicationDb, 'VerseCommentary') && (await publicationDb.rawQuery("SELECT COUNT(*) FROM VerseCommentary")).first['COUNT(*)'] as int > 0;

      String description = '';
      bool hasDocumentMetadataTable = await checkIfTableExists(publicationDb, 'DocumentMetadata');

      if(hasDocumentMetadataTable) {
        final documentMetadataDescription = await publicationDb.query(
          'DocumentMetadata',
          columns: ['Value'],
          where: 'MetadataKey = ? AND DocumentId = ?',
          whereArgs: ['WEB:OnSiteAdDescription', 0],
        );
        description = documentMetadataDescription.isNotEmpty ? documentMetadataDescription.first['Value'] as String : '';
      }
      else {
        description = await fetchPublicationDescription(publication, symbol: keySymbol, issueTagNumber: issueTagNum, mepsLanguage: 'F');
      }

      String hashPublication = getPublicationHash(languageId, symbol, year, issueTagNum);

      Map<String, dynamic> pubDb = {
        'MepsLanguageId': languageId,
        'PublicationType': pub['publicationType'],
        'PublicationCategorySymbol': pub['categories'].first,
        'Title': pub['title'],
        'ShortTitle': pub['shortTitle'],
        'DisplayTitle': pub['displayTitle'],
        'UndatedReferenceTitle': pub['undatedReferenceTitle'],
        'Description': description,
        'Symbol': pub['symbol'],
        'KeySymbol': keySymbol,
        'UniqueEnglishSymbol': pub['uniqueEnglishSymbol'],
        'SchemaVersion': pub['schemaVersion'],
        'Year': year,
        'IssueTagNumber': issueTagNum,
        'RootSymbol': pub['rootSymbol'],
        'RootYear': pub['rootYear'] is String ? int.parse(pub['rootYear']) : pub['rootYear'],
        'Hash': hashPublication,
        'Timestamp': timeStamp,
        'Path': path,
        'DatabasePath': "$path/${pub['fileName']}",
        'ExpandedSize': manifestData['expandedSize'],
        'MepsBuildNumber': manifestData['mepsBuildNumber'],
        'TopicSearch': hasTopicsTable ? 1 : 0,
        'VerseCommentary': hasVerseCommentaryTable ? 1 : 0,
        'HeadingSearch': hasHeadingSearch ? 1 : 0,
        'IsSingleDocument': 0,
      };

      int publicationId;

      if (publication != null && publication.isDownloadedNotifier.value) {
        // Cas : MISE À JOUR
        publicationId = publication.id;
        pubDb['PublicationId'] = publicationId;

        await _database.transaction((txn) async {
          // Mise à jour de la publication principale
          await txn.update(
            'Publication', 
            pubDb, 
            where: 'PublicationId = ?', 
            whereArgs: [publicationId],
          );

          // Suppression groupée des anciennes données liées
          final tables = [
            'AvailableBibleBook', 'DatedText', 'Document', 
            'Image', 'PublicationAttribute', 'PublicationIssueAttribute', 
            'PublicationIssueProperty', 'Publication'
          ];

          for (var table in tables) {
            await txn.delete(table, where: 'PublicationId = ?', whereArgs: [publicationId]);
          }
        });
      } 
      else {
        // Cas : INSERTION (si publication est null OU n'est pas encore téléchargée)
        publicationId = await _database.insert('Publication', pubDb);
        pubDb['PublicationId'] = publicationId;
      }

      // Utilisation de batch pour des insertions groupées
      final batch = _database.batch();

      // Insertion des images
      dynamic images = pub['images'];
      List<Map<String, dynamic>> imagesDb = [];
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          Map<String, dynamic> imageDb = {
            'PublicationId': publicationId,
            'Type': image['type'],
            'Attribute': image['attribute'],
            'Path': "$path/${image['fileName']}",
            'Width': image['width'],
            'Height': image['height'],
            'Signature': image['signature'].split(':').first,
          };
          imagesDb.add(imageDb);
          batch.insert('Image', imageDb);
        }
      }

      // Insertion des attributs
      dynamic attributes = pub['attributes'];
      if (attributes != null && attributes.isNotEmpty) {
        for (var attribute in attributes) {
          batch.insert('PublicationAttribute', {'PublicationId': publicationId, 'Attribute': attribute});
        }
      }

      // Insertion des attributs de numéro de publication
      dynamic issueAttributes = pub['issueAttributes'];
      if (issueAttributes != null && issueAttributes.isNotEmpty) {
        for (var issueAttribute in issueAttributes) {
          batch.insert('PublicationIssueAttribute', {'PublicationId': publicationId, 'Attribute': issueAttribute});
        }
      }

      // Insertion des propriétés de numéro de publication
      dynamic issueProperties = pub['issueProperties'];
      if (issueProperties != null && issueProperties.isNotEmpty) {
        String title = issueProperties['title'] ?? '';
        String undatedTitle = issueProperties['undatedTitle'] ?? '';
        String coverTitle = issueProperties['coverTitle'] ?? '';
        String symbol = issueProperties['symbol'] ?? '';
        String undatedSymbol = issueProperties['undatedSymbol'] ?? '';
        if(title.isNotEmpty && undatedTitle.isNotEmpty && coverTitle.isNotEmpty && symbol.isNotEmpty && undatedSymbol.isNotEmpty) {
          batch.insert('PublicationIssueProperty', {
            'PublicationId': publicationId,
            'Title': title,
            'UndatedTitle': undatedTitle,
            'CoverTitle': coverTitle,
            'Symbol': symbol,
            'UndatedSymbol': undatedSymbol,
          });
        }
      }

      bool hasPublicationViewItemDocument = await checkIfTableExists(publicationDb, 'PublicationViewItemDocument');
      bool hasDocumentTable = await checkIfTableExists(publicationDb, 'Document');
      bool hasDatedTextTable = await checkIfTableExists(publicationDb, 'DatedText');
      bool hasBibleBookTable = await checkIfTableExists(publicationDb, 'BibleBook');

      if (hasPublicationViewItemDocument) {
        // On exécute la requête directement sur publicationDb
        final List<Map<String, dynamic>> result = await publicationDb.rawQuery(
          'SELECT COUNT(*) FROM PublicationViewItemDocument'
        );

        // Sqflite.firstIntValue est l'utilitaire idéal pour extraire le chiffre du COUNT
        final int count = Sqflite.firstIntValue(result) ?? 0;

        // Si un seul document est trouvé, on met à jour la variable pubDb
        if (count == 1) {
          pubDb['IsSingleDocument'] = 1;
        }
      }
      if(hasDocumentTable) {
        // Insertion des documents
        final documents = await publicationDb.query('Document', columns: ['MepsDocumentId', 'MepsLanguageIndex']);
        for (var document in documents) {
          batch.insert('Document', {
            'LanguageIndex': document['MepsLanguageIndex'],
            'MepsDocumentId': document['MepsDocumentId'],
            'PublicationId': publicationId
          });
        }
      }

      if (hasDatedTextTable) {
          final List<Map<String, dynamic>> datedTexts = await publicationDb.rawQuery('''
            SELECT 
              DT.FirstDateOffset, 
              DT.LastDateOffset,
              D.Class 
            FROM DatedText DT
            INNER JOIN Document D ON DT.DocumentId = D.DocumentId
          ''');

          // 2. Insertion en batch
          for (var datedText in datedTexts) {
            batch.insert('DatedText', {
              'Start': datedText['FirstDateOffset'],
              'End': datedText['LastDateOffset'],
              'Class': datedText['Class'],
              'PublicationId': publicationId
            });
          }
        }

      if(hasBibleBookTable) {
        // Insertion des bibles
        final bibles = await publicationDb.query('BibleBook', columns: ['BibleBookId']);
        for (var bible in bibles) {
          batch.insert('AvailableBibleBook', {
            'Book': bible['BibleBookId'],
            'PublicationId': publicationId
          });
        }
      }

      // Exécution du batch
      await batch.commit();
      await publicationDb.close();

      // Récupération des informations de langue si la publication n'est pas fournie
      if (publication == null) {
        File mepsFile = await getMepsUnitDatabaseFile();
        if (await mepsFile.exists()) {
          Database db = await openReadOnlyDatabase(mepsFile.path);
          List<Map<String, dynamic>> result = await db.rawQuery("SELECT Symbol, VernacularName, PrimaryIetfCode FROM Language WHERE LanguageId = $languageId");
          if (result.isNotEmpty) {
            pubDb['LanguageSymbol'] = result[0]['Symbol'];
            pubDb['LanguageVernacularName'] = result[0]['VernacularName'];
            pubDb['LanguagePrimaryIetfCode'] = result[0]['PrimaryIetfCode'];
          }
          await db.close();
        }
      }
      else {
        // Utilisation des données de publication existantes
        pubDb['LanguageSymbol'] = publication.mepsLanguage.symbol;
        pubDb['LanguageVernacularName'] = publication.mepsLanguage.vernacular;
        pubDb['LanguagePrimaryIetfCode'] = publication.mepsLanguage.primaryIetfCode;
      }

      // Gestion des images de couverture
      var imageSqr = imagesDb.where((element) => element['Type'] == 't').toList()..sort((a, b) => b['Width'].compareTo(a['Width']) != 0 ? b['Width'].compareTo(a['Width']) : b['Height'].compareTo(a['Height']));
      pubDb['ImageSqr'] = imageSqr.isNotEmpty ? imageSqr.first['Path'] : null;

      var imageLsr = imagesDb.where((element) => element['Type'] == 'lsr' && element['Width'] == 1200 && element['Height'] == 600).toList();
      pubDb['ImageLsr'] = imageLsr.isNotEmpty ? imageLsr.first['Path'] : null;

      Publication finalPub = Publication.fromJson(pubDb, updateValue: true);

      if(reOpenDocumentsManager) {
        finalPub.documentsManager ??= DocumentsManager(publication: finalPub);
        await finalPub.documentsManager!.initializeDatabaseAndData();
      }
      else if (reOpenDatedTextManager) {
        finalPub.datedTextManager ??= DatedTextManager(publication: finalPub);
        await finalPub.datedTextManager!.initializeDatabaseAndData();
      }

      return finalPub;
    }
    catch (e) {
      print("Erreur lors de l'insertion ou de la mise à jour de la publication : $e");
      return null;
    }
  }

  Future<void> deletePublication(Publication publication) async {
    await _database.transaction((txn) async {
      final List<Map<String, dynamic>> results = await txn.query(
        'Publication',
        columns: ['PublicationId'],
        where: 'KeySymbol = ? AND IssueTagNumber = ? AND MepsLanguageId = ?',
        whereArgs: [publication.keySymbol, publication.issueTagNumber, publication.mepsLanguage.id],
      );

      if (results.isEmpty) return;

      int publicationId = results.first['PublicationId'] as int;

      // Utilisation d'un batch pour regrouper les suppressions
      final batch = txn.batch();
      
      final tables = [
        'AvailableBibleBook', 'DatedText', 'Document', 
        'Image', 'PublicationAttribute', 'PublicationIssueAttribute', 
        'PublicationIssueProperty', 'Publication'
      ];

      for (var table in tables) {
        batch.delete(table, where: 'PublicationId = ?', whereArgs: [publicationId]);
      }

      await batch.commit(noResult: true); // noResult: true accélère encore l'exécution
    });
  }

  Future<void> createDbPubCollection(Database db) async {
    return await db.transaction((txn) async {
      // Création de la table Document
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "AvailableBibleBook" (
          "AvailableBibleBookId"	INTEGER NOT NULL,
          "PublicationId"	INTEGER,
          "Book"	INTEGER,
          PRIMARY KEY("AvailableBibleBookId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table DatedText
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "DatedText" (
          "DatedTextId"	INTEGER NOT NULL,
          "PublicationId"	INTEGER,
          "Start"	INTEGER NOT NULL,
          "End"	INTEGER NOT NULL,
          "Class"	INTEGER NOT NULL,
          PRIMARY KEY("DatedTextId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table Document
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Document" (
          "LanguageIndex" INTEGER NOT NULL,
          "MepsDocumentId" INTEGER NOT NULL,
          "PublicationId" INTEGER,
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table Image
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Image" (
          "ImageId" INTEGER NOT NULL,
          "PublicationId" INTEGER,
          "Type" TEXT NOT NULL,
          "Attribute" TEXT NOT NULL,
          "Path" TEXT,
          "Width" INTEGER,
          "Height" INTEGER,
          "Signature" TEXT,
          PRIMARY KEY("ImageId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table Publication
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "Publication" (
          "PublicationId" INTEGER NOT NULL,
          "MepsLanguageId" INTEGER,
          "PublicationType" TEXT,
          "PublicationCategorySymbol" TEXT,
          "Title" TEXT,
          "ShortTitle" TEXT,
          "DisplayTitle" TEXT,
          "UndatedReferenceTitle" TEXT,
          "Description" TEXT,
          "Symbol" TEXT NOT NULL,
          "KeySymbol" TEXT,
          "UniqueEnglishSymbol" TEXT NOT NULL,
          "Year" INTEGER,
          "SchemaVersion" INTEGER,
          "IssueTagNumber" INTEGER NOT NULL DEFAULT 0,
          "RootSymbol" TEXT,
          "RootYear" INTEGER,
          "Hash" TEXT,
          "Timestamp" TEXT,
          "Path" TEXT NOT NULL UNIQUE,
          "DatabasePath" TEXT NOT NULL,
          "ExpandedSize" INTEGER,
          "MepsBuildNumber" INTEGER DEFAULT 0,
          "TopicSearch" INTEGER DEFAULT 0,
          "VerseCommentary" INTEGER DEFAULT 0,
          "HeadingSearch" INTEGER DEFAULT 0,
          "IsSingleDocument" INTEGER DEFAULT 0,
          PRIMARY KEY("PublicationId" AUTOINCREMENT)
        );
      """);

      // Création de la table PublicationAttribute
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PublicationAttribute" (
          "PublicationAttributeId" INTEGER NOT NULL,
          "PublicationId" INTEGER,
          "Attribute" TEXT,
          PRIMARY KEY("PublicationAttributeId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table PublicationIssueAttribute
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PublicationIssueAttribute" (
          "PublicationIssueAttributeId" INTEGER NOT NULL,
          "PublicationId" INTEGER,
          "Attribute" TEXT,
          PRIMARY KEY("PublicationIssueAttributeId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Création de la table PublicationIssueProperty
      await txn.execute("""
        CREATE TABLE IF NOT EXISTS "PublicationIssueProperty" (
          "PublicationIssuePropertyId" INTEGER NOT NULL,
          "PublicationId" INTEGER,
          "Title" TEXT,
          "UndatedTitle" TEXT,
          "CoverTitle" TEXT,
          "Symbol" TEXT,
          "UndatedSymbol" TEXT,
          PRIMARY KEY("PublicationIssuePropertyId" AUTOINCREMENT),
          FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
        );
      """);

      // Ajouter les index
      await txn.execute("CREATE UNIQUE INDEX AvailableBibleBook_UserKey ON AvailableBibleBook(Book, PublicationId);");
      await txn.execute("CREATE UNIQUE INDEX DatedText_UserKey ON DatedText(Start, End, Class, PublicationId);");
      await txn.execute("CREATE UNIQUE INDEX Document_UserKey ON Document (PublicationId, MepsDocumentId);");
      await txn.execute("CREATE INDEX IX_DatedText_PublicationId ON DatedText(PublicationId);");
      await txn.execute("CREATE INDEX IX_Document_LanguageIndex_MepsDocumentId_PublicationId ON Document (LanguageIndex, MepsDocumentId, PublicationId);");
      await txn.execute("CREATE INDEX IX_Image_Signature ON Image (Signature);");
      await txn.execute("CREATE INDEX IX_Publication_Path_PublicationId_Hash_Timestamp ON Publication (Path, PublicationId, Hash, Timestamp);");
      await txn.execute("CREATE INDEX IX_Publication_KeySymbol_MepsLanguageId_IssueTagNumber_PublicationId ON Publication (KeySymbol, MepsLanguageId, IssueTagNumber, PublicationId);");
      await txn.execute("CREATE INDEX IX_Publication_MepsLanguageId_PublicationType_IssueTagNumber ON Publication (MepsLanguageId, PublicationType, IssueTagNumber);");
      await txn.execute("CREATE INDEX IX_Publication_PublicationCategorySymbol_PublicationType_MepsLanguageId ON Publication (PublicationCategorySymbol, PublicationType, MepsLanguageId);");
      await txn.execute("CREATE INDEX IX_Publication_PublicationType ON Publication (PublicationType);");
      await txn.execute("CREATE UNIQUE INDEX Image_UserKey ON Image(PublicationId, Path);");
      await txn.execute("CREATE UNIQUE INDEX PublicationAttribute_UserKey ON PublicationAttribute(PublicationId, Attribute);");
      await txn.execute("CREATE UNIQUE INDEX PublicationIssueAttribute_UserKey ON PublicationIssueAttribute(PublicationId, Attribute);");
      await txn.execute("CREATE UNIQUE INDEX PublicationIssueProperty_UserKey ON PublicationIssueProperty(PublicationId);");
      await txn.execute("CREATE UNIQUE INDEX Publication_UserKey ON Publication(KeySymbol, MepsLanguageId, IssueTagNumber);");
    });
  }
}
