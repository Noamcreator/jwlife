import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/api.dart';
import '../../core/utils/directory_helper.dart';

import 'package:http/http.dart' as http;

import 'Tiles.dart';

class TilesCache {
  late Database _database;
  List<Tile> tiles = [];

  Future<void> init() async {
    File tilesDb = await getTilesDbFile();
    _database = await openDatabase(tilesDb.path, version: 1);
    await fetchTilesCache();
  }

  void clearTiles() {
    tiles.clear();
  }

  Future<void> fetchTilesCache() async {
    clearTiles();

    final result = await _database.query('TilesCache');

    if (result.isNotEmpty) {
      tiles = result.map((tile) => Tile.fromJson(tile)).toList();
    }
  }

  dynamic getImagePath(String imageUrl, String filename) {
    return tiles.firstWhereOrNull((tile) => tile.fileName.toLowerCase() == filename.toLowerCase());
  }

  void _addImageToDatabase(String filename, File file) {
    tiles.add(Tile(fileName: filename, file: file));

    _database.insert(
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
      await file.writeAsBytes(response.bodyBytes);

      // Vérifier que le fichier a bien été écrit
      if (await file.exists()) {
        _addImageToDatabase(filename, file);
        return Tile(fileName: filename, file: file);
      }
      else {
        throw Exception('Échec de la sauvegarde de l\'image sur le stockage local.');
      }
    } else {
      throw Exception('Erreur lors du téléchargement de l\'image : ${response.statusCode}');
    }
  }

  Future<Tile?> getOrDownloadImage(String? imageUrl) async {
    Tile? tile;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      String filename = basename(imageUrl);
      if (imageUrl.startsWith('https')) {
        Tile? existingPath = getImagePath(imageUrl, filename);

        if (existingPath != null) {
          tile = existingPath;
        }
        else {
          tile = await downloadImage(imageUrl, filename);
        }
      }
      else if (imageUrl.startsWith('file')) {
        tile = Tile(fileName: filename, file: File.fromUri(Uri.parse(imageUrl)));
      }
      else {
        tile = Tile(fileName: filename, file: File(imageUrl));
      }
    }
    return tile;
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
