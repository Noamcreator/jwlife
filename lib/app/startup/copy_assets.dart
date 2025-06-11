import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/utils/directory_helper.dart';

class CopyAssets {
  static Future<void> copy() async {
    Directory dbDir = await getAppDatabasesDirectory();
    Directory userDataDir = await getAppUserDataDirectory();

    await Future.wait([
      copyFileFromAssetsToDirectory(Assets.dbMepsunit, '${dbDir.path}/mepsunit.db'),
      copyFileFromAssetsToDirectory(Assets.userDataUserData, '${userDataDir.path}/userData.db'),
      copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png')
    ]);
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
      print("Erreur lors de la copie du fichier : $assetPath → $e");
    }
  }
}
