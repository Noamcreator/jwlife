import 'dart:io';

import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwlife/core/utils/files_helper.dart';

import '../../data/databases/tiles_cache.dart';

class CreateDatabase {
  static Future<void> create() async {
    await Future.wait([
      _createDatabase(getPubCollectionsFile, JwLifeApp.pubCollections.createDbPubCollection),
      _createDatabase(getMediaCollectionsFile, JwLifeApp.mediaCollections.createDbMediaCollection),
      _createDatabase(getTilesDbFile, TilesCache().createDbTilesCache),
      _createDatabase(getHistoryFile, History.createDbHistory),
    ]);
  }

  static Future<void> _createDatabase(Future<File> Function() getFile, Future<void> Function(Database db) onCreateCallback,) async {
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