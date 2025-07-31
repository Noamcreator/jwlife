import 'dart:io';

import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/utils_pub.dart';

class PubCollections {
  late Database _database;

  Future<void> init() async {
    final pubCollections = await getPubCollectionsFile();
    _database = await openDatabase(pubCollections.path, version: 1);
    await fetchDownloadPublications();
  }

  Future<void> fetchDownloadPublications() async {
    final mepsFile = await getMepsFile();

    printTime('fetchDownloadPublications start');

    await _database.transaction((txn) async {
      await txn.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

      final result = await txn.rawQuery('''
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
          pa.Attribute,
          pip.Title AS IssueTitle,
          pip.CoverTitle,
          pip.UndatedSymbol,
          img.ImageSqr,
          img.ImageLsr,
          l.Symbol AS LanguageSymbol,
          l.VernacularName AS LanguageVernacularName,
          l.PrimaryIetfCode AS LanguagePrimaryIetfCode,
          l.IsSignLanguage AS IsSignLanguage
      FROM Publication p
      LEFT JOIN PublicationAttribute pa ON pa.PublicationId = p.PublicationId
      LEFT JOIN PublicationIssueProperty pip ON pip.PublicationId = p.PublicationId
      INNER JOIN meps.Language l ON p.MepsLanguageId = l.LanguageId
      LEFT JOIN ImageData img ON img.PublicationId = p.PublicationId;
    ''');

      // On consomme pleinement les résultats avant de détacher
      result.map((row) => Publication.fromJson(row)).toList();
    });

    printTime('fetchDownloadPublications end');

    await _database.execute("DETACH DATABASE meps");
  }

  Future<void> open() async {
    if(!_database.isOpen) {
      File pubCollections = await getPubCollectionsFile();
      _database = await openDatabase(pubCollections.path, version: 1);
    }
  }

  Future<Publication> insertPublicationFromManifest(dynamic manifestData, String path, {Publication? publication}) async {
    await open();

    dynamic pub = manifestData['publication'];

    int languageId = pub['language'];
    String symbol = pub['symbol'];
    int year = pub['year'] is String ? int.parse(pub['year']) : pub['year'];
    int issueTagNum = pub['issueId'];

    Future<String> descriptionFuture = extractPublicationDescription(publication, symbol: symbol, issueTagNumber: issueTagNum, mepsLanguage: 'F');

    Database publicationDb = await openDatabase("$path/${pub['fileName']}", version: manifestData['schemaVersion']);

    bool hasTopicsTable = false;
    bool hasVerseCommentaryTable = false;

    if(await tableExists(publicationDb, 'sqlite_stat1')) {
      // Vérifier si la table Topic existe et n'est pas vide
      List<Map<String, dynamic>> topicExists = await publicationDb.rawQuery("""
      SELECT stat
      FROM sqlite_stat1
      WHERE tbl = 'Topic'
  """);

      // Vérifier si la table Topic existe et n'est pas vide
      List<Map<String, dynamic>> verseCommentaryExists = await publicationDb.rawQuery("""
      SELECT stat
      FROM sqlite_stat1
      WHERE tbl = 'VerseCommentary'
  """);

      hasTopicsTable = topicExists.isNotEmpty;
      hasVerseCommentaryTable = verseCommentaryExists.isNotEmpty;
    }

    String hashPublication = getPublicationHash(languageId, symbol, year, issueTagNum);
    String description = await descriptionFuture;

    Map<String, dynamic> pubDb = {
      'MepsLanguageId': languageId,
      'PublicationType': pub['publicationType'],
      'PublicationCategorySymbol': pub['categories'].first,
      'Title': pub['title'],
      'ShortTitle': pub['shortTitle'],
      'DisplayTitle': pub['displayTitle'],
      'UndatedReferenceTitle': pub['undatedReferenceTitle'],
      'Description': description,
      'Symbol': symbol,
      'KeySymbol': pub['uniqueSymbol'] ?? symbol,
      'UniqueEnglishSymbol': pub['uniqueEnglishSymbol'],
      'SchemaVersion': pub['schemaVersion'],
      'Year': year,
      'IssueTagNumber': issueTagNum,
      'RootSymbol': pub['rootSymbol'],
      'RootYear': pub['rootYear'] is String ? int.parse(pub['rootYear']) : pub['rootYear'],
      'Hash': hashPublication,
      'Timestamp': pub['timestamp'],
      'Path': path,
      'DatabasePath': "$path/${pub['fileName']}",
      'ExpandedSize': manifestData['expandedSize'],
      'MepsBuildNumber': manifestData['mepsBuildNumber'],
      'TopicSearch': hasTopicsTable ? 1 : 0,
      'VerseCommentary': hasVerseCommentaryTable ? 1 : 0,
    };

    int publicationId = await _database.insert('Publication', pubDb);

    dynamic images = pub['images'];

    List<Map<String, dynamic>> imagesDb = [];
    if(images != null && images.isNotEmpty) {
      for(var image in images) {
        Map<String, dynamic> imageDb ={
          'PublicationId': publicationId,
          'Type': image['type'],
          'Attribute': image['attribute'],
          'Path': "$path/${image['fileName']}",
          'Width': image['width'],
          'Height': image['height'],
          'Signature': image['signature'].split(':').first,
        };
        imagesDb.add(imageDb);
        _database.insert('Image', imageDb);
      }
    }

    dynamic attributes = pub['attributes'];
    if(attributes != null && attributes.isNotEmpty) {
      for(var attribute in attributes) {
        Map<String, dynamic> attributeDb ={
          'PublicationId': publicationId,
          'Attribute': attribute,
        };
        _database.insert('PublicationAttribute', attributeDb);

        pubDb['Attribute'] = attribute;
      }
    }

    dynamic issueAttributes = pub['issueAttributes'];
    if(issueAttributes != null && issueAttributes.isNotEmpty) {
      for(var issueAttribute in issueAttributes) {
        Map<String, dynamic> issueAttributeDb ={
          'PublicationId': publicationId,
          'Attribute': issueAttribute,
        };
        _database.insert('PublicationIssueAttribute', issueAttributeDb);
      }
    }

    dynamic issueProperties = pub['issueProperties'];
    if (issueProperties != null && issueProperties.isNotEmpty) {
      // Vérifie si tous les champs sont vides
      if (issueProperties['title'] != '' ||
          issueProperties['undatedTitle'] != '' ||
          issueProperties['coverTitle'] != '' ||
          issueProperties['symbol'] != '' ||
          issueProperties['undatedSymbol'] != '') {
        Map<String, dynamic> issuePropertiesDb = {
          'PublicationId': publicationId,
          'Title': issueProperties['title'],
          'UndatedTitle': issueProperties['undatedTitle'],
          'CoverTitle': issueProperties['coverTitle'],
          'Symbol': issueProperties['symbol'],
          'UndatedSymbol': issueProperties['undatedSymbol'],
        };
        _database.insert('PublicationIssueProperty', issuePropertiesDb);

        pubDb['IssueTitle'] = issueProperties['title'];
        pubDb['CoverTitle'] = issueProperties['coverTitle'];
      }
    }

    // Search Database content
    List<Map<String, dynamic>> documentList = await publicationDb.query(
        'Document',
        columns: ['MepsDocumentId', 'MepsLanguageIndex']
    );
    if(documentList.isNotEmpty) {
      for(var document in documentList) {
        Map<String, dynamic> documentDb = {
          'LanguageIndex': document['MepsLanguageIndex'],
          'MepsDocumentId': document['MepsDocumentId'],
          'PublicationId': publicationId
        };
        _database.insert('Document', documentDb);
      }
    }

    await publicationDb.close();

    if(publication == null) {
      File mepsFile = await getMepsFile();
      if (await mepsFile.exists()) {
        Database db = await openDatabase(mepsFile.path);
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
      pubDb['LanguageSymbol'] = publication.mepsLanguage.symbol;
      pubDb['LanguageVernacularName'] = publication.mepsLanguage.vernacular;
      pubDb['LanguagePrimaryIetfCode'] = publication.mepsLanguage.primaryIetfCode;
    }

    var imageSqr = imagesDb
        .where((element) => element['Type'] == 't')
        .toList()
        ..sort((a, b) {
        // Trier par largeur et hauteur en ordre décroissant
        int widthComparison = b['Width'].compareTo(a['Width']);
        if (widthComparison != 0) {
          return widthComparison;
        }
        return b['Height'].compareTo(a['Height']);
      });

    if (imageSqr.isNotEmpty) {
      pubDb['ImageSqr'] = imageSqr.first['Path'];  // Récupérer le chemin de l'image
    }
    else {
      pubDb['ImageSqr'] = null;  // Aucune image trouvée
    }

    // Récupérer l'image de type 'lsr' avec les dimensions spécifiques
    var imageLsr = imagesDb.where((element) => element['Type'] == 'lsr' && element['Width'] == 1200 && element['Height'] == 600).toList();

    // Si une image est trouvée, on récupère son chemin
    if (imageLsr.isNotEmpty) {
      pubDb['ImageLsr'] = imageLsr.first['Path'];  // Récupérer le chemin de l'image
    }
    else {
      pubDb['ImageLsr'] = null;  // Aucune image trouvée
    }

    return Publication.fromJson(pubDb);
  }

  Future<void> deletePublication(Publication publication) async {
    await open(); // Assure-toi que la base est ouverte

    await _database.transaction((txn) async {
      // 1. Récupérer l'ID de la publication à supprimer
      final List<Map<String, dynamic>> results = await txn.query(
        'Publication',
        columns: ['PublicationId'],
        where: 'Symbol = ? AND IssueTagNumber = ? AND MepsLanguageId = ?',
        whereArgs: [publication.symbol, publication.issueTagNumber, publication.mepsLanguage.id],
      );

      if (results.isEmpty) {
        // La publication n'existe pas, rien à faire
        return;
      }

      int publicationId = results.first['PublicationId'] as int;

      // 2. Supprimer les enregistrements liés dans les autres tables
      await txn.delete('Document', where: 'PublicationId = ?', whereArgs: [publicationId]);
      await txn.delete('Image', where: 'PublicationId = ?', whereArgs: [publicationId]);
      await txn.delete('PublicationAttribute', where: 'PublicationId = ?', whereArgs: [publicationId]);
      await txn.delete('PublicationIssueAttribute', where: 'PublicationId = ?', whereArgs: [publicationId]);
      await txn.delete('PublicationIssueProperty', where: 'PublicationId = ?', whereArgs: [publicationId]);

      // 3. Supprimer la publication elle-même
      await txn.delete('Publication', where: 'PublicationId = ?', whereArgs: [publicationId]);
    });
  }


  Future<void> createDbPubCollection(Database db) async {
    return await db.transaction((txn) async {
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
    });
  }

  Future<Publication?> getDocumentFromMepsDocumentId(int mepsDocId, int currentLanguageId) async {
    await open();

    List<Map<String, dynamic>> result = await _database.rawQuery('''
      SELECT 
        p.Symbol,
        p.IssueTagNumber,
        p.MepsLanguageId
      FROM Publication p
      LEFT JOIN Document d ON p.PublicationId = d.PublicationId
      WHERE d.MepsDocumentId = ? AND p.MepsLanguageId = ?
      LIMIT 1
    ''', [mepsDocId, currentLanguageId]);

    if (result.isNotEmpty) {
      return PublicationRepository().getPublicationWithSymbol(result.first['Symbol'], result.first['IssueTagNumber'], result.first['MepsLanguageId']);
    }
    return null;
  }
}
