import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/databases/Publication.dart';

import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

import 'directory_helper.dart';

Future<Publication?> downloadJwpubFile(Publication publication, BuildContext context, CancelToken? cancelToken, {void Function(double downloadProgress)? update}) async {
  final queryParams = {
    'pub': publication.keySymbol,
    'issue': publication.issueTagNumber.toString(),
    'langwritten': publication.mepsLanguage.symbol,
    'fileformat': 'jwpub',
  };

  final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);
  print('Generated URL: $url');

  try {
    final response = await Dio().getUri(url);

    if (response.statusCode == 200) {
      final data = response.data;
      final downloadUrl = data['files'][publication.mepsLanguage.symbol]['JWPUB'][0]['file']['url'];
      print('downloadUrl: $downloadUrl');

      Dio dio = Dio();
      final responseBytes = await dio.get(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken, // Ajouter le cancelToken ici
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = (received / total);
            publication.downloadProgress = progress > 1 ? -1 : progress;
            update?.call(publication.downloadProgress);
          }
        },
      );

      publication.downloadProgress = -1;
      update?.call(publication.downloadProgress);

      publication.downloadProgress = 0;
      update?.call(publication.downloadProgress);

      return await jwpubUnzip(responseBytes.data, context, publication: publication);
    } else {
      throw Exception('Erreur lors de la récupération des données');
    }
  }
  catch (e) {
    if (e is DioException && CancelToken.isCancel(e)) {
      print('Téléchargement annulé');
    } else {
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
    }
  }
  return null;
}

Future<Publication> jwpubUnzip(List<int> bytes, BuildContext context, {Publication? publication}) async {
  // Décoder l'archive principale
  final archive = ZipDecoder().decodeBytes(bytes);

  // Récupérer et décoder le fichier manifest.json
  final manifestFile = archive.files.firstWhere((file) => file.name == 'manifest.json');
  final manifestData = jsonDecode(utf8.decode(manifestFile.content));
  final name = manifestData['name'];

  // Déterminer le dossier de destination
  final appDir = await getAppPublications();
  final destinationDir = Directory('${appDir.path}/$name');
  await destinationDir.create(recursive: true);

  // Extraire le fichier manifest.json dans le dossier de destination
  final manifestFilePath = '${destinationDir.path}/manifest.json';
  await File(manifestFilePath).writeAsString(jsonEncode(manifestData));

  // Extraire l'archive des contenus
  final contentsFile = archive.files.firstWhere((file) => file.name == 'contents');
  final contentsArchive = ZipDecoder().decodeBytes(contentsFile.content);

  // Extraire chaque fichier dans le dossier de destination
  for (final file in contentsArchive.files) {
    if (!file.isFile) continue; // Ignorer les dossiers
    final filePath = '${destinationDir.path}/${file.name}';
    await File(filePath).writeAsBytes(file.content);
  }

  print('Fichiers extraits dans : ${destinationDir.path}');

  return await JwLifeApp.pubCollections.insertPublicationFromManifest(manifestData, destinationDir.path, publication: publication);
}

Future<void> removeJwpubFile(Publication pub) async {
  Directory path = Directory(pub.path);
  if (await path.exists()) {
    try {
      await path.delete(recursive: true); // Deletes the directory and all its contents
    }
    catch (e) {
      print('Error while deleting directory ${path.path}: $e');
    }
  }
  else {
    print('Directory ${path.path} does not exist.');
  }

  await JwLifeApp.pubCollections.deletePublication(pub);
}

/// Calcule le hash SHA-256 à partir des identifiants donnés
String computeSha256Hash(int languageId, String symbol, int year, int issueTagNumber) {
  final publicationCard = issueTagNumber == 0
      ? "${languageId}_${symbol}_$year"
      : "${languageId}_${symbol}_${year}_$issueTagNumber";

  return sha256.convert(utf8.encode(publicationCard)).toString();
}

/// Effectue l'opération XOR entre deux valeurs hexadécimales
String xorWithKey(String hashString) {
  const xorKeyHex = "11cbb5587e32846d4c26790c633da289f66fe5842a3a585ce1bc3a294af5ada7";

  final hashBytes = hexToBytes(hashString);
  final keyBytes = hexToBytes(xorKeyHex);
  final xorResult = List<int>.generate(hashBytes.length, (index) => hashBytes[index] ^ keyBytes[index]);

  return bytesToHex(xorResult);
}

/// Fonction principale pour calculer le hash de la publication
String getPublicationHash(int languageId, String symbol, int year, int issueTagNumber) {
  final publicationHash = computeSha256Hash(languageId, symbol, year, issueTagNumber);
  return xorWithKey(publicationHash);
}

/// Décrypte et décompresse le contenu du blob
String decryptContent(Uint8List encryptedContent, Uint8List key, Uint8List iv) {
  final aesCipher = encrypt.Encrypter(encrypt.AES(
    encrypt.Key(key),
    mode: encrypt.AESMode.cbc,
  ));

  // Décompresse les données avec zlib après décryption AES
  final decryptedBytes = aesCipher.decryptBytes(encrypt.Encrypted(encryptedContent), iv: encrypt.IV(iv));

  // Décoder en UTF-8
  return utf8.decode(ZLibDecoder().decodeBytes(decryptedBytes));
}

/// Fonction principale pour décoder le blob avec le hash de la publication en HTML
String decodeBlobContent(Uint8List contentBlob, String hashPublication) {
  final key = hexToBytes(hashPublication.substring(0, 32));
  final iv = hexToBytes(hashPublication.substring(32));
  return decryptContent(contentBlob, Uint8List.fromList(key), Uint8List.fromList(iv));
}

/// Décrypte et décompresse le contenu du blob
List<int> decryptContentParagraph(Uint8List encryptedContent, Uint8List key, Uint8List iv) {
  final aesCipher = encrypt.Encrypter(encrypt.AES(
    encrypt.Key(key),
    mode: encrypt.AESMode.cbc,
  ));

  // Décompresse les données avec zlib après décryption AES
  final decryptedBytes = aesCipher.decryptBytes(encrypt.Encrypted(encryptedContent), iv: encrypt.IV(iv));

  // Décoder en UTF-8
  return ZLibDecoder().decodeBytes(decryptedBytes);
}

/// Fonction principale pour décoder le blob avec le hash de la publication en HTML
List<int> decodeBlobParagraph(Uint8List contentBlob, String hashPublication) {
  final key = hexToBytes(hashPublication.substring(0, 32));
  final iv = hexToBytes(hashPublication.substring(32));
  return decryptContentParagraph(contentBlob, Uint8List.fromList(key), Uint8List.fromList(iv));
}

/// Encrypte et compresse le contenu du blob
Uint8List encryptContent(String content, Uint8List key, Uint8List iv) {
  final aesCipher = encrypt.Encrypter(encrypt.AES(
    encrypt.Key(key),
    mode: encrypt.AESMode.cbc,
  ));

  // Convertir le contenu en bytes
  final contentBytes = utf8.encode(content);

  // Appliquer le chiffrement AES
  final encryptedContent = aesCipher.encryptBytes(Uint8List.fromList(contentBytes), iv: encrypt.IV(iv));

  // Compresser le contenu crypté avec ZLib
  final compressedContent = ZLibEncoder().encode(encryptedContent.bytes);

  return Uint8List.fromList(compressedContent);
}

/// Fonction principale pour coder le HTML avec le hash de la publication en Blob
Uint8List encodeContent(String content, String hashPublication) {
  final key = hexToBytes(hashPublication.substring(0, 32));
  final iv = hexToBytes(hashPublication.substring(32));
  return encryptContent(content, Uint8List.fromList(key), Uint8List.fromList(iv));
}

/// Utilitaires pour la conversion hexadécimale
List<int> hexToBytes(String hex) {
  final length = hex.length ~/ 2;
  return List.generate(length, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}

String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
