import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

    await _createDatabase(getPubCollectionsFile, createDbPubCollection);
    await _createDatabase(getMediaCollectionsFile, createDbMediaCollection);
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