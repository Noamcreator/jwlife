import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

import 'directory_helper.dart';
import 'files_helper.dart';


Future<Map<String, dynamic>?> jwPubIsDownloaded(dynamic pub) async {
  final pubCollectionsDbFile = await getPubCollectionsFile();
  final db = await openDatabase(pubCollectionsDbFile.path, version: 1, onCreate: (db, version) {
    return createDbPubCollection(db);
  });

  List<Map<String, dynamic>> result;
  if (pub['IssueTagNumber'] == 0) {
    // if db is not empty
    result = await db.query(
      'Publication',
      where: 'Symbol = ? AND MepsLanguageId = ?',
      whereArgs: [pub['Symbol'], pub['MepsLanguageId']],
    );
  }
  else {
    result = await db.query(
      'Publication',
      where: 'Symbol = ? AND IssueTagNumber = ? AND MepsLanguageId = ?',
      whereArgs: [pub['Symbol'], pub['IssueTagNumber'], pub['MepsLanguageId']],
    );
  }

  db.close();

  return result.isNotEmpty ? result.first : null;
}

Future<Map<String, dynamic>> downloadJwpubFile(dynamic pub, BuildContext context, {void Function()? update}) async {
  final queryParams = {
    'pub': pub['KeySymbol'],
    'issue': pub['IssueTagNumber'].toString(),
    'langwritten': pub['LanguageSymbol'],
    'fileformat': 'jwpub',
  };

  final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);

  try {
    final response = await Dio().getUri(url);

    if (response.statusCode == 200) {
      pub['inProgress'] = -1; // Réinitialiser la progression avant de commencer
      final data = response.data;

      // Extraire l'URL du fichier JWPUB
      final downloadUrl = data['files'][pub['LanguageSymbol']]['JWPUB'][0]['file']['url'];
      Dio dio = Dio();

      // Téléchargement dans un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/${pub["KeySymbol"]}_${pub["LanguageSymbol"]}';
      final tempFileIssuePath = pub['IssueTagNumber'] == 0 ? '$tempFilePath.jwpub' : '${tempDir.path}/${pub["KeySymbol"]}_${pub["LanguageSymbol"]}_${pub["IssueTagNumber"]}.jwpub';

      // Téléchargement avec suivi de la progression
      await dio.download(
        downloadUrl,
        tempFileIssuePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Calcul du pourcentage de progression
            double progress = (received / total);
            if(progress > 1) {
              pub['inProgress'] = -1;
            }
            else {
              pub['inProgress'] = progress;
            }
            update!();
          }
        },
      );

      final downloadedFile = File(tempFileIssuePath);
      Map<String, dynamic> jwpub = await jwpubUnzip(downloadedFile, context);
      pub['inProgress'] = null;
      update!();
      return jwpub;
    } else {
      throw Exception('Erreur lors de la récupération des données');
    }
  } catch (e) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Erreur'),
          content: Text('Échec de la récupération des données : $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    return {};
  }
}

Future<Map<String, dynamic>> jwpubUnzip(File file, BuildContext context) async {
  // Lecture du fichier téléchargé en mémoire
  final archiveBytes = await file.readAsBytes();
  final archive = ZipDecoder().decodeBytes(archiveBytes);

  // Créer le dossier de destination dans AppPublication
  final appDir = await getAppPublications();
  final destinationDirPath = '${appDir.path}/${file.path.split('/').last}';
  final destinationDir = Directory(destinationDirPath);
  await destinationDir.create(recursive: true);

  // Parcourir les fichiers dans l'archive .jwpub
  for (final file in archive) {
    if (file.isFile) {
      final filename = file.name;

      // Extraction du manifest.json directement
      if (filename == 'manifest.json') {
        final manifestFile = File('${destinationDir.path}/manifest.json');
        await manifestFile.writeAsBytes(file.content);
      }

      // Extraction du contenu du dossier "contents" qui est un zip
      if (filename == 'contents') {
        final contentsArchive = ZipDecoder().decodeBytes(file.content);

        // Extraire chaque fichier dans le dossier "contents" de destination
        for (final contentsFile in contentsArchive) {
          if (contentsFile.isFile) {
            final filePath = '${destinationDir.path}/${contentsFile.name}';
            final extractedFile = File(filePath);
            await extractedFile.create(recursive: true);
            await extractedFile.writeAsBytes(contentsFile.content);
          }
        }
      }
    }
  }

  // Supprimer le fichier temporaire
  await file.delete();
  print('Fichiers extraits dans : ${destinationDir.path}');

  File manifestFile = File('${destinationDir.path}/manifest.json'); // Utiliser + pour concaténer le chemin dans destinationDir
  final jsonString = await manifestFile.readAsString();
  final manifestData = json.decode(jsonString);

  File pubCollectionsDbFile = await getPubCollectionsFile();
  final db = await openDatabase(pubCollectionsDbFile.path, readOnly: false, version: 1, onCreate: (db, version) {
    return createDbPubCollection(db);
  });

  dynamic publication = manifestData['publication'];
  int languageId = publication['language'];
  String symbol = publication['symbol'];
  int year = publication['year'] is String ? int.parse(publication['year']) : publication['year'];
  int issueTagNum = publication['issueId'];
  String hashPublication = await getPublicationHash(languageId: languageId, symbol: symbol, year: year, issueTagNumber: issueTagNum);

  Map<String, dynamic> pubDb ={
    'MepsLanguageId': languageId,
    'PublicationType': publication['publicationType'],
    'PublicationCategorySymbol': publication['categories'].first,
    'Title': publication['title'],
    'ShortTitle': publication['shortTitle'],
    'DisplayTitle': publication['displayTitle'],
    'UndatedReferenceTitle': publication['undatedReferenceTitle'],
    'Symbol': symbol,
    'KeySymbol': publication['uniqueSymbol'],
    'UniqueEnglishSymbol': publication['uniqueEnglishSymbol'],
    'Year': year,
    'IssueTagNumber': issueTagNum,
    'RootSymbol': publication['rootSymbol'],
    'RootYear': publication['rootYear'] is String ? int.parse(publication['rootYear']) : publication['rootYear'],
    'Hash': hashPublication,
    'Timestamp': publication['timestamp'],
    'Path': destinationDir.path,
    'DatabasePath': "${destinationDir.path}/${publication['fileName']}",
    'ExpandedSize': manifestData['expandedSize'],
    'MepsBuildNumber': manifestData['mepsBuildNumber'],
  };

  int publicationId = await db.insert('Publication', pubDb);

  dynamic images = publication['images'];
  for(var image in images) {
    Map<String, dynamic> imageDb ={
      'PublicationId': publicationId,
      'Type': image['type'],
      'Attribute': image['attribute'],
      'Path': "${destinationDir.path}/${image['fileName']}",
      'Width': image['width'],
      'Height': image['height'],
      'Signature': image['signature'].split(':').first,
    };
    await db.insert('Image', imageDb);
  }

  dynamic attributes = publication['attributes'];
  if(attributes.isNotEmpty) {
    for(var attribute in attributes) {
      Map<String, dynamic> attributeDb ={
        'PublicationId': publicationId,
        'Attribute': attribute,
      };
      await db.insert('PublicationAttribute', attributeDb);
    }
  }

  dynamic issueAttributes = publication['issueAttributes'];
  if(issueAttributes.isNotEmpty) {
    for(var issueAttribute in issueAttributes) {
      Map<String, dynamic> issueAttributeDb ={
        'PublicationId': publicationId,
        'Attribute': issueAttribute,
      };
      await db.insert('PublicationIssueAttribute', issueAttributeDb);
    }
  }

  dynamic issueProperties = publication['issueProperties'];
  if (issueProperties.isNotEmpty) {
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
      await db.insert('PublicationIssueProperty', issuePropertiesDb);
    }
  }

  // Search Database content
  List<Map<String, dynamic>> documentList = await PublicationsCatalog.getAllDocumentFromPub(languageId, symbol, issueTagNum);
  if(documentList.isNotEmpty) {
    for(var document in documentList) {
      Map<String, dynamic> documentDb = {
        'LanguageIndex': document['MepsLanguageId'],
        'MepsDocumentId': document['MepsDocumentId'],
        'PublicationId': publicationId
      };
      await db.insert('Document', documentDb);
    }
  }

  // Search Database content
  List<Map<String, dynamic>> datedTextList = await PublicationsCatalog.getAllDatedTextFromPub(languageId, symbol, issueTagNum);
  if(documentList.isNotEmpty) {
    for(var datedText in datedTextList) {
      Map<String, dynamic> datedTextDb = {
        'PublicationId': publicationId,
        'Start': datedText['Start'],
        'End': datedText['End'],
        'Class': datedText['Class']
      };
      await db.insert('DatedText', datedTextDb);
    }
  }

  // Search Database content
  List<Map<String, dynamic>> availableBibleBookList = await PublicationsCatalog.getAllAvailableBibleBookFromPub(languageId, symbol, issueTagNum);
  if(documentList.isNotEmpty) {
    for(var availableBibleBook in availableBibleBookList) {
      Map<String, dynamic> availableBibleBookDb = {
        'PublicationId': publicationId,
        'Book': availableBibleBook['Book']
      };
      await db.insert('AvailableBibleBook', availableBibleBookDb);
    }
  }

  db.close();

  return pubDb;
}

Future<void> createDbPubCollection(Database db) async {
  return await db.transaction((txn) async {
    // Création de la table AvailableBibleBook
    await txn.execute("""
      CREATE TABLE IF NOT EXISTS "AvailableBibleBook" (
        "AvailableBibleBookId" INTEGER NOT NULL,
        "PublicationId" INTEGER,
        "Book" INTEGER,
        PRIMARY KEY("AvailableBibleBookId" AUTOINCREMENT),
        FOREIGN KEY("PublicationId") REFERENCES "Publication"("PublicationId")
      );
    """);

    // Création de la table DatedText
    await txn.execute("""
      CREATE TABLE IF NOT EXISTS "DatedText" (
        "DatedTextId" INTEGER NOT NULL,
        "PublicationId" INTEGER,
        "Start" INTEGER NOT NULL,
        "End" INTEGER NOT NULL,
        "Class" INTEGER NOT NULL,
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
        "Symbol" TEXT NOT NULL,
        "KeySymbol" TEXT,
        "UniqueEnglishSymbol" TEXT NOT NULL,
        "Year" INTEGER,
        "IssueTagNumber" INTEGER NOT NULL DEFAULT 0,
        "RootSymbol" TEXT,
        "RootYear" INTEGER,
        "Hash" TEXT,
        "Timestamp" TEXT,
        "Path" TEXT NOT NULL UNIQUE,
        "DatabasePath" TEXT NOT NULL,
        "ExpandedSize" INTEGER,
        "MepsBuildNumber" INTEGER DEFAULT 0,
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

Future<void> removeJwpubFile(dynamic pub) async {
  File pubCollectionsDbFile = await getPubCollectionsFile();
  final db = await openDatabase(pubCollectionsDbFile.path, version: 1);

  List<Map<String, dynamic>> result = await db.query(
    'Publication',
    where: 'Symbol = ? AND IssueTagNumber = ? AND MepsLanguageId = ?',
    whereArgs: [pub['Symbol'], pub['IssueTagNumber'], pub['MepsLanguageId']],
  );

  if (result.isEmpty) {
    await db.close();
    return;
  }

  Directory path = Directory(result.first['Path']);
  print('path: ${path.path}');
  if (await path.exists()) {
    try {
      await path.delete(recursive: true); // Deletes the directory and all its contents
    } catch (e) {
      print('Error while deleting directory ${path.path}: $e');
    }
  }
  else {
    print('Directory ${path.path} does not exist.');
  }

  await db.delete('Publication', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('AvailableBibleBook', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('DatedText', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('Document', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('Image', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('PublicationAttribute', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('PublicationIssueAttribute', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);
  await db.delete('PublicationIssueProperty', where: 'PublicationId = ?', whereArgs: [result.first['PublicationId']]);

  await db.close();
}

const xorKeyHex = "11cbb5587e32846d4c26790c633da289f66fe5842a3a585ce1bc3a294af5ada7";

/// Calcule le hash SHA-256 à partir des identifiants donnés
String computeSha256Hash(int languageId, String symbol, int year, int issueTagNumber) {
  final publicationCard = issueTagNumber == 0 ? "${languageId}_${symbol}_$year" : "${languageId}_${symbol}_${year}_$issueTagNumber";
  final bytes = utf8.encode(publicationCard);
  final sha256Bytes = sha256.convert(bytes).bytes;
  return sha256Bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Effectue l'opération XOR entre deux valeurs hexadécimales
String xorWithKey(String hashString, String keyHex) {
  final hashBytes = hexToBytes(hashString);
  final keyBytes = hexToBytes(keyHex);
  final xorResult = List<int>.generate(
      hashBytes.length, (index) => hashBytes[index] ^ keyBytes[index]);
  return bytesToHex(xorResult);
}

/// Décrypte et décompresse le contenu du blob
String decryptContent(Uint8List encryptedContent, Uint8List key, Uint8List iv) {
  final aesCipher = encrypt.Encrypter(encrypt.AES(
    encrypt.Key(key),
    mode: encrypt.AESMode.cbc,
  ));
  final decryptedBytes = aesCipher.decryptBytes(
    encrypt.Encrypted(encryptedContent),
    iv: encrypt.IV(iv),
  );

  // Décompresse les données avec zlib
  final decompressedBytes = ZLibDecoder().decodeBytes(decryptedBytes);
  return utf8.decode(decompressedBytes);
}

/// Fonction principale pour décoder le blob
Future<String> getPublicationHash({
  required int languageId,
  required String symbol,
  required int year,
  required int issueTagNumber,
}) async {
  final publicationHash = computeSha256Hash(languageId, symbol, year, issueTagNumber);
  return xorWithKey(publicationHash, xorKeyHex);

}

/// Fonction principale pour décoder le blob
Future<String> decodeBlobContent({
  required Uint8List contentBlob,
  required int languageId,
  required String symbol,
  required int year,
  required int issueTagNumber,
}) async {
  final publicationHash = computeSha256Hash(languageId, symbol, year, issueTagNumber);
  final xorResult = xorWithKey(publicationHash, xorKeyHex);

  final key = hexToBytes(xorResult.substring(0, 32));
  final iv = hexToBytes(xorResult.substring(32));

  return decryptContent(contentBlob, Uint8List.fromList(key), Uint8List.fromList(iv));
}


Future<String> decodeBlobContentWithHash({
  required Uint8List contentBlob,
  required String hashPublication,
}) async {
  final key = hexToBytes(hashPublication.substring(0, 32));
  final iv = hexToBytes(hashPublication.substring(32));

  return decryptContent(contentBlob, Uint8List.fromList(key), Uint8List.fromList(iv));
}

/// Utilitaires pour la conversion hexadécimale
List<int> hexToBytes(String hex) =>
    List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();