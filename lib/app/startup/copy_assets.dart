import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../core/utils/directory_helper.dart';
import '../../core/utils/utils.dart';

class CopyAssets {
  static Future<void> copy() async {
    Directory dbDir = await getAppDatabasesDirectory();
    Directory userDataDir = await getAppUserDataDirectory();

    await Future.wait([
      extractMepsUnitFileFromAssetsToDirectory(Assets.mepsUnit, '${dbDir.path}/mepsunit.db'),
      copyFileFromAssetsToDirectory(Assets.userDataUserData, '${userDataDir.path}/userData.db'),
      copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png')
    ]);
  }

  static Future<void> extractMepsUnitFileFromAssetsToDirectory(String assetPath, String targetDbPath) async {
    String lastMepsTimestamp = await getLastMepsTimestamp();
    File targetFile = File(targetDbPath);

    // Charger le zip en mémoire
    final zipData = await rootBundle.load(assetPath);
    final bytes = zipData.buffer.asUint8List();

    final archive = ZipDecoder().decodeBytes(bytes);

    // Trouver manifest.json et lire timestamp
    final manifestFile = archive.files.firstWhereOrNull((file) => file.name == 'manifest.json');

    if(manifestFile == null) {
      throw Exception('manifest.json not found in zip');
    }

    final manifestContent = utf8.decode(manifestFile.content);
    final manifestJson = json.decode(manifestContent);
    final timestampInZip = manifestJson['timestamp'] as String;

    // Si timestamp identique, on stoppe
    if (timestampInZip == lastMepsTimestamp && targetFile.existsSync()) {
      print('Le fichier est déjà à jour (timestamp identique). Extraction annulée.');
      return;
    }

    // Sinon on extrait uniquement mepsunit.db
    final mepsUnitFile = archive.files.firstWhereOrNull((file) => file.name == 'mepsunit.db');

    if(mepsUnitFile == null) {
      throw Exception('mepsunit.db not found in zip');
    }

    await targetFile.writeAsBytes(mepsUnitFile.content);

    // Mise à jour du timestamp
    await setNewMepsTimestamp(timestampInZip);

    print('Extraction de mepsunit.db terminée avec succès.');
  }

  static Future<void> copyFileFromAssetsToDirectory(String assetPath, String targetPath) async {
    File targetFile = File(targetPath);

    // Vérifie si le fichier ou dossier existe déjà
    if (await targetFile.exists()) return;

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final buffer = data.buffer;
      await targetFile.create(recursive: true);
      await targetFile.writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    catch (e) {
      printTime("Erreur lors de la copie du fichier : $assetPath → $e");
    }
  }
}
