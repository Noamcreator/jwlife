import 'dart:io';

import 'package:sqflite/sqflite.dart';

/// Vérifie si tous les fichiers spécifiés existent.
Future<bool> allFilesExist(List<File> files) async {
  for (final file in files) {
    if (!await file.exists()) return false;
  }
  return true;
}

/// Attache les bases de données supplémentaires au catalogue principal.
Future<void> attachDatabases(Database catalog, Map<String, String> databases) async {
  for (final entry in databases.entries) {
    await catalog.execute("ATTACH DATABASE '${entry.value}' AS ${entry.key}");
  }
}

/// Détache les bases de données supplémentaires.
Future<void> detachDatabases(Database catalog, List<String> aliases) async {
  for (final alias in aliases) {
    await catalog.execute("DETACH DATABASE $alias");
  }
}