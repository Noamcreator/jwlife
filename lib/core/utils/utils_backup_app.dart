import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'directory_helper.dart';

Future<File> exportAppBackup() async {
  // 1. Répertoire temporaire pour le backup
  final tempDir = await getAppCacheDirectory(); // ta fonction existante
  final backupPath =
      '${tempDir.path}/app_backup_${DateTime.now().millisecondsSinceEpoch}.jwlife';
  final backupFile = File(backupPath);

  // 2. Créer le fichier ZIP
  final encoder = ZipFileEncoder();
  encoder.create(backupFile.path);

  final tempPubDir = Directory('${tempDir.path}/app_publications');
  if (!await tempPubDir.exists()) {
    await tempPubDir.create();
  }

// Copier les fichiers DB souhaités dedans
  final dbFiles = [
    'pub_collections.db',
    'TilesCache.db',
    'history.db',
    'media_collections.db',
    'articles.db',
  ];

  final databasesDir = await getAppDatabasesDirectory();
  for (var fileName in dbFiles) {
    final file = File('${databasesDir.path}/$fileName');
    if (await file.exists()) {
      await file.copy('${tempPubDir.path}/$fileName');
    }
  }

  // Ajouter le répertoire temporaire dans le ZIP
  encoder.addDirectory(tempPubDir, includeDirName: true);

  // Nettoyer le répertoire temporaire après ajout
  try {
    await tempPubDir.delete(recursive: true);
  } catch (_) {}


  // 4. Ajouter le répertoire Tile et Databases complet
  final tileDir = await getAppTileDirectory();
  final publicationsDir = await getAppPublications();

  if (await tileDir.exists()) {
    await encoder.addDirectory(tileDir, includeDirName: true);
  }
  if (await publicationsDir.exists()) {
    await encoder.addDirectory(publicationsDir, includeDirName: true);
  }

  // 5. SharedPreferences filtrées
  final prefs = await SharedPreferences.getInstance();
  final excludedKeys = {
    'last_meps_timestamp',
    'webapp_version',
    'last_catalog_revision'
  };

  final prefsMap = <String, dynamic>{};
  for (var key in prefs.getKeys()) {
    if (!excludedKeys.contains(key)) {
      prefsMap[key] = prefs.get(key);
    }
  }

  // Écriture dans fichier temporaire
  final prefsJson = jsonEncode(prefsMap);
  final prefsTempFile = File('${tempDir.path}/shared_prefs.json');
  await prefsTempFile.writeAsString(prefsJson);

  await encoder.addFile(prefsTempFile);

  // 6. Fermer ZIP et nettoyer
  await encoder.close();
  try {
    await prefsTempFile.delete();
  } catch (_) {}

  return backupFile;
}


Future<void> importAppBackup(File zipFile) async {
  if (!await zipFile.exists()) {
    throw Exception('Le fichier de sauvegarde n’existe pas');
  }

  // 1. Créer un répertoire temporaire pour extraire le ZIP
  final tempDir = await getAppCacheDirectory();
  final extractDir = Directory('${tempDir.path}/backup_extract_${DateTime.now().millisecondsSinceEpoch}');
  if (!await extractDir.exists()) {
    await extractDir.create(recursive: true);
  }

  // 2. Lire et extraire le fichier ZIP
  final inputStream = InputFileStream(zipFile.path);
  final archive = ZipDecoder().decodeStream(inputStream);

  for (final file in archive.files) {
    final filename = file.name;
    final filePath = p.join(extractDir.path, filename);

    if (file.isFile) {
      final outFile = File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      await Directory(filePath).create(recursive: true);
    }
  }

  // 3. Récupérer les chemins des dossiers cibles
  final publicationsDir = await getAppPublications();
  final tileDir = await getAppTileDirectory();
  final filesDir = await getAppFilesDirectory();
  final databasesDir = await getAppDatabasesDirectory();

  // 4. Fonction utilitaire pour copier les répertoires
  Future<void> copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    await for (var entity in source.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: source.path);
        final newFile = File(p.join(destination.path, relativePath));
        await newFile.create(recursive: true);
        await newFile.writeAsBytes(await entity.readAsBytes());
      }
    }
  }

  // 5. Copier les répertoires restaurés
  final extractedPublications = Directory(p.join(extractDir.path, 'app_publications'));
  final extractedTiles = Directory(p.join(extractDir.path, 'app_tile'));
  final extractedFiles = Directory(p.join(extractDir.path, 'files'));
  final extractedDatabases = Directory(p.join(extractDir.path, 'databases'));

  if (await extractedPublications.exists()) {
    await copyDirectory(extractedPublications, publicationsDir);
  }
  if (await extractedTiles.exists()) {
    await copyDirectory(extractedTiles, tileDir);
  }
  if (await extractedFiles.exists()) {
    await copyDirectory(extractedFiles, filesDir);
  }
  if (await extractedDatabases.exists()) {
    await copyDirectory(extractedDatabases, databasesDir);
  }

  // 6. Restaurer les SharedPreferences
  final prefsFile = File(p.join(extractDir.path, 'shared_prefs.json'));
  if (await prefsFile.exists()) {
    final jsonString = await prefsFile.readAsString();
    final Map<String, dynamic> prefsMap = jsonDecode(jsonString);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Supprimer les anciennes données
    for (var entry in prefsMap.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
      }
    }
  }

  // 7. Nettoyer le dossier temporaire
  if (await extractDir.exists()) {
    await extractDir.delete(recursive: true);
  }
}