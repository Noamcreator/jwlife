import 'dart:io';
import 'package:flutter/services.dart';
import 'package:jwlife/utils/directory_helper.dart';
import 'package:jwlife/utils/files_helper.dart';
import 'package:jwlife/utils/utils_jwpub.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'assets.dart';

class LoadAssets {
  static Future<void> copyAssets() async {
    await _copyDatabaseAssets();

    final pubCollectionsDbFile = await getPubCollectionsFile();
    if (!pubCollectionsDbFile.existsSync()) {
      final db = await openDatabase(pubCollectionsDbFile.path, version: 1, onCreate: (db, version) async {
        return await createDbPubCollection(db);
      });
      db.close();
    }

    print('Assets copied.');
  }

  static Future<void> _copyDatabaseAssets() async {
    Directory dbDir = await getAppDatabasesDirectory();

    await _copyFileFromAssetsToDirectory(Assets.dbCatalog, '${dbDir.path}/catalog.db');
    await _copyFileFromAssetsToDirectory(Assets.dbMepsunit, '${dbDir.path}/mepsunit.db');
    await _copyFileFromAssetsToDirectory(Assets.dbTilesCache, '${dbDir.path}/TilesCache.db');
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
