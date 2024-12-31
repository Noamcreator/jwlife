import 'dart:io';
import 'directory_helper.dart';

Future<File> getMepsFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/mepsunit.db');
}

Future<File> getCatalogFile() async {
  print('getCatalogFile');
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/catalog.db');
}

Future<File> getArticlesFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/articles.db');
}

Future<File> getTilesDbFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/TilesCache.db');
}

Future<File> getPubCollectionsFile() async {
  final directory = await getAppDatabasesDirectory();
  return File('${directory.path}/pub_collections.db');
}

Future<File> getUserdataFile() async {
  Directory userData = await getAppUserDataDirectory();
  return File('${userData.path}/userData.db');
}

Future<File> getMediaCategory(String language, String category) async {
  final directory = await getLanguagesDirectory();
  return File('${directory.path}/$language/$category.json');
}
