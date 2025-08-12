import 'dart:io';
import 'directory_helper.dart';

Future<File> getMepsUnitDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/mepsunit.db');
}

Future<File> getCatalogDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/catalog.db');
}

Future<File> getArticlesDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/articles.db');
}

Future<File> getTilesDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/TilesCache.db');
}

Future<File> getPubCollectionsDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/pub_collections.db');
}

Future<File> getMediaCollectionsDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/media_collections.db');
}

Future<File> getHistoryDatabaseFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/history.db');
}

Future<File> getUserdataDatabaseFile() async {
  Directory userData = await getAppUserDataDirectory();
  return File('${userData.path}/userData.db');
}
