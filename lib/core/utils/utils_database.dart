import 'dart:io';

import 'package:jwlife/core/utils/utils.dart';
import 'package:sqflite/sqflite.dart';

/// Vérifie si tous les fichiers spécifiés existent.
bool allFilesExist(List<File> files) {
  for (final file in files) {
    if (!file.existsSync()) return false;
  }
  return true;
}

/// Attache les bases de données supplémentaires au catalogue principal.
Future<void> attachDatabases(Database db, Map<String, String> databases) async {
  for (final entry in databases.entries) {
    try {
      await db.execute("ATTACH DATABASE '${entry.value}' AS ${entry.key}");
      printTime("Database '${entry.key}' attached successfully.");
    } catch (e) {
      // Ignore l'erreur, par exemple "database already in use"
      printTime("Database '${entry.key}' attach skipped: $e");
    }
  }
}

Future<void> attachTransaction(Transaction txn, Map<String, String> databases) async {
  for (final entry in databases.entries) {
    try {
      await txn.execute("ATTACH DATABASE '${entry.value}' AS ${entry.key}");
      printTime("Database '${entry.key}' attached successfully.");
    } catch (e) {
      // Ignore l'erreur, par exemple "database already in use"
      printTime("Database '${entry.key}' attach skipped: $e");
    }
  }
}

/// Détache les bases de données supplémentaires, ignore les erreurs.
Future<void> detachDatabases(Database db, List<String> aliases) async {
  for (final alias in aliases) {
    try {
      await db.execute("DETACH DATABASE $alias");
      printTime("Database '$alias' detached successfully.");
    } catch (e) {
      // Ignore l'erreur si la base n'était pas attachée
      printTime("Database '$alias' detach skipped: $e");
    }
  }
}

/// Même version pour une transaction
Future<void> detachTransaction(Transaction txn, List<String> aliases) async {
  for (final alias in aliases) {
    try {
      await txn.execute("DETACH DATABASE $alias");
      printTime("Database '$alias' detached successfully in transaction.");
    } catch (e) {
      // Ignore l'erreur si la base n'était pas attachée
      printTime("Database '$alias' detach skipped in transaction: $e");
    }
  }
}

// Optimisation: utilise une méthode rapide 'LIMIT 1'
Future<bool> checkIfTableExists(Database db, String tableName) async {
  final result = await db.rawQuery("SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", [tableName]);
  return result.isNotEmpty;
}

// Fonction inchangée, elle est déjà rapide (PRAGMA est une commande interne)
Future<List<String>> getColumnsForTable(Database db, String tableName) async {
  final result = await db.rawQuery("PRAGMA table_info($tableName)");
  return result.map((row) => row['name'] as String).toList();
}

// Créez une fonction utilitaire pour générer la requête SQL avec remplacements
String buildAccentInsensitiveQuery(String column) {
  return '''
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER($column), 'é', 'e'), 'è', 'e'), 'ê', 'e'), 'à', 'a'), 'î', 'i'), 'ô', 'o')
  ''';
}

Future<void> addColumnSafe(Database db, String table, String column, String type) async {
  try {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }
  catch (e) {
    // Si l'erreur contient "duplicate column name", on ne fait rien
    print("La colonne $column existe probablement déjà : $e");
  }
}