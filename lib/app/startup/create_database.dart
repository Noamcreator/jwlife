import 'dart:io';

import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_media.dart';

class CreateDatabase {
  static Future<void> create() async {
    await _createDatabase(
      getTilesDbFile,
          (db) async {
        await db.execute('''
          CREATE TABLE TilesCache (
            FileName TEXT PRIMARY KEY,
            FilePath TEXT
          )
        ''');
      }
    );

    await _createDatabase(getPubCollectionsFile, JwLifeApp.pubCollections.createDbPubCollection);
    await _createDatabase(getMediaCollectionsFile, JwLifeApp.mediaCollections.createDbMediaCollection);
    await _createDatabase(getHistoryFile, History.createDbHistory);
  }

  static Future<void> _createDatabase(
      Future<File> Function() getFile,
      Future<void> Function(Database db) onCreateCallback,
      ) async {
    final dbFile = await getFile();

    if (!dbFile.existsSync()) {
      final db = await openDatabase(
        dbFile.path,
        version: 1,
        onCreate: (db, version) async => await onCreateCallback(db),
      );
      await db.close();
    }
  }
}