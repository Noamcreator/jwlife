import 'dart:io';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/utils/directory_helper.dart';

class CopyAssets {
  static Future<void> copy() async {
    Directory dbDir = await getAppDatabasesDirectory();

    await _copyFileFromAssetsToDirectory(Assets.dbMepsunit, '${dbDir.path}/mepsunit.db');
    await _copyFileFromAssetsToDirectory(Assets.dbBibleverses, '${dbDir.path}/bibleverses.db');

    Directory userDataDir = await getAppUserDataDirectory();
    if (!userDataDir.existsSync()) {
      await userDataDir.create(recursive: true);
    }

    await _copyFileFromAssetsToDirectory(Assets.userDataUserData, '${userDataDir.path}/userData.db');
    await _copyFileFromAssetsToDirectory(Assets.userDataDefaultThumbnail, '${userDataDir.path}/default_thumbnail.png');
  }

  static Future<void> _copyFileFromAssetsToDirectory(String assetPath, String targetPath) async {
    File targetFile = File(targetPath);
    if (!targetFile.existsSync()) {
      final data = await rootBundle.load(assetPath);
      final buffer = data.buffer;
      await targetFile.writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}
