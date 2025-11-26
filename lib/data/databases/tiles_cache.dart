import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/api/api.dart';
import '../../core/utils/directory_helper.dart';

import '../models/tile.dart';

class TilesCache {
  // Singleton
  static final TilesCache _instance = TilesCache._internal();
  factory TilesCache() => _instance;
  TilesCache._internal();

  late Database _database;
  final List<Tile> tiles = [];

  Future<void> init() async {
    File tilesDb = await getTilesDatabaseFile();
    _database = await openDatabase(
      tilesDb.path,
      version: 1,
      onCreate: (db, version) async {
        await createDbTilesCache(db);
      },
    );
    await fetchTilesCache();
  }

  void clearTiles() {
    tiles.clear();
  }

  Future<void> fetchTilesCache() async {
    clearTiles();

    final result = await _database.query('TilesCache');

    if (result.isNotEmpty) {
      tiles.addAll(result.map((tile) => Tile.fromJson(tile)));
    }
  }

  Tile? getImagePath(String filename) {
    return tiles.firstWhereOrNull((tile) => tile.fileName.toLowerCase() == filename.toLowerCase());
  }

  Future<void> _addImageToDatabase(String filename, File file) async {
    tiles.add(Tile(fileName: filename, file: file));

    await _database.insert(
      'TilesCache',
      {'FileName': filename, 'FilePath': file.path},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Tile> downloadImage(String imageUrl, String filename) async {
    final directory = await getAppTileDirectory();
    final file = File('${directory.path}/$filename');

    final response = await Api.httpGetWithHeaders(imageUrl);
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.data);

      if (await file.exists()) {
        await _addImageToDatabase(filename, file);
        return Tile(fileName: filename, file: file);
      } else {
        throw Exception('Échec de la sauvegarde de l\'image sur le stockage local.');
      }
    } else {
      throw Exception('Erreur lors du téléchargement de l\'image : ${response.statusCode}');
    }
  }

  Future<Tile?> getOrDownloadImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    String filename = basename(imageUrl);

    if (imageUrl.startsWith('https')) {
      Tile? existingPath = getImagePath(filename);

      if (existingPath != null) {
        return existingPath;
      } else {
        return await downloadImage(imageUrl, filename);
      }
    }
    else if (imageUrl.startsWith('file')) {
      return Tile(fileName: filename, file: File.fromUri(Uri.parse(imageUrl)));
    }
    else {
      return Tile(fileName: filename, file: File(imageUrl));
    }
  }

  Future<void> createDbTilesCache(Database db) async {
    await db.execute('''
      CREATE TABLE TilesCache (
        FileName TEXT PRIMARY KEY,
        FilePath TEXT
      )
    ''');
  }
}
