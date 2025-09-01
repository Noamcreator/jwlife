import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<Directory> getAppDirectory() async { // Récupérer le dossier de l'application
  final directory = await getApplicationSupportDirectory();
  final parent = directory.parent;
  return parent;
}

Future<Directory> getAppDocumentsDirectory() async { // Get the default application documents directory
  final directory = await getApplicationDocumentsDirectory();
  return directory;
}

Future<Directory> getAppPublications() async { // Get the default application documents directory
  final directory = await getAppDirectory();
  Directory appPublicationDirectory = Directory('${directory.path}/app_publications');
  if (!await appPublicationDirectory.exists()) {
    await appPublicationDirectory.create();
  }
  return appPublicationDirectory;
}

Future<Directory> getAppTemp() async { // Get the default application documents directory
  final directory = await getAppDirectory();
  Directory appTempDirectory = Directory('${directory.path}/app_temp');
  if (!await appTempDirectory.exists()) {
    await appTempDirectory.create();
  }
  return appTempDirectory;
}

Future<Directory> getAppTileDirectory() async { // Get the default application documents directory
  final directory = await getAppDirectory();
  Directory appTileDirectory = Directory('${directory.path}/app_tile');
  if (!await appTileDirectory.exists()) {
    await appTileDirectory.create();
  }
  return appTileDirectory;
}

Future<Directory> getAppWebViewDirectory() async { // Get the default application documents directory
  final directory = await getAppDirectory();
  Directory appWebViewDirectory = Directory('${directory.path}/app_webview');
  if (!await appWebViewDirectory.exists()) {
    await appWebViewDirectory.create();
  }
  return appWebViewDirectory;
}

Future<Directory> getAppCacheDirectory() async { // Get the default application cache directory
  final directory = await getApplicationCacheDirectory();
  return directory;
}

Future<Directory> getAppCodeCacheDirectory() async { // Get the default application cache directory
  final directory = await getAppDirectory();
  final codeCacheDirectory = Directory('${directory.path}/code_cache');
  return codeCacheDirectory;
}

Future<Directory> getAppDatabasesDirectory() async { // Get the default application databases directory
  final databasePath = await getDatabasesPath();
  Directory appDatabasesDirectory = Directory(databasePath);
  return appDatabasesDirectory;
}

Future<Directory> getAppFilesDirectory() async { // Get the default application files directory
  final directory = await getApplicationSupportDirectory();
  return directory;
}

Future<Directory> getAppSharedPreferencesDirectory() async { // Get the default application databases directory
  String databasePath = await getDatabasesPath();
  return Directory('${databasePath.substring(0, databasePath.lastIndexOf('/'))}/shared_prefs');
}

Future<Directory> getAppUserDataDirectory() async { // Get the default application databases directory
  String databasePath = await getDatabasesPath();
  return Directory('${databasePath.substring(0, databasePath.lastIndexOf('/'))}/userData');
}

Future<Directory> getLanguagesDirectory() async { // Get the default application files directory
  final directory = await getAppFilesDirectory();
  final languagesDirectory = Directory('${directory.path}/languages');
  if (!await languagesDirectory.exists()) {
    await languagesDirectory.create();
  }
  return languagesDirectory;
}
