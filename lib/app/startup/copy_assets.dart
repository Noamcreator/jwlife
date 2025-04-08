import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/utils/directory_helper.dart';

class CopyAssets {
  static Future<void> copy() async {
    Directory dbDir = await getAppDatabasesDirectory();
    Directory webappDir = await getAppWebViewDirectory();

    await copyFileFromAssetsToDirectory(Assets.dbMepsunit, '${dbDir.path}/mepsunit.db');

    Directory userDataDir = await getAppUserDataDirectory();
    if (!userDataDir.existsSync()) {
      await userDataDir.create(recursive: true);
    }

    await copyFileFromAssetsToDirectory(Assets.userDataUserData, '${userDataDir.path}/userData.db');

    await copyFileFromAssetsToDirectory(Assets.jwlifeAssetsWebapp, '${webappDir.path}/webapp');
  }

  static Future<void> copyFileFromAssetsToDirectory(String assetPath, String targetPath) async {
    File targetFile = File(targetPath);

    // Vérifie si le fichier ou dossier existe déjà
    if (await targetFile.exists()) return;

    if (assetPath == Assets.jwlifeAssetsWebapp) {
      await extractWebAppZip(targetPath);
    }
    else {
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final buffer = data.buffer;
        await targetFile.create(recursive: true);
        await targetFile.writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      catch (e) {
        print("Erreur lors de la copie du fichier : $assetPath → $e");
      }
    }
  }

  static Future<void> extractWebAppZip(String targetDirectory) async {
    try {
      // Charger le ZIP depuis les assets
      final ByteData data = await rootBundle.load(Assets.jwlifeAssetsWebapp);
      final List<int> bytes = data.buffer.asUint8List();

      // Décompresser le ZIP
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      for (final ArchiveFile file in archive) {
        final String filePath = '$targetDirectory/${file.name}';

        if (file.isFile) {
          // Créer le dossier parent si nécessaire
          await File(filePath).parent.create(recursive: true);
          // Écrire le contenu du fichier
          await File(filePath).writeAsBytes(file.content);
        } else {
          // Si c'est un dossier, le créer
          await Directory(filePath).create(recursive: true);
        }
      }
    } catch (e) {
      print("Erreur lors de l'extraction du ZIP : $e");
    }
  }
}
