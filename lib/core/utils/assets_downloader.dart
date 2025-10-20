import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/utils.dart';

import '../api/api.dart';
import '../shared_preferences/shared_preferences_utils.dart';

class AssetsDownload {
  // Télécharge et enregistre les polices localement
  static Future<void> download() async {
    final directory = await getAppFilesDirectory();
    final webappDir = Directory('${directory.path}/webapp_assets');
    final webappVersion = await getWebAppVersion();
    String webappVersionServer = '0.0.0';
    String webappfileNameServer = 'webapp_assets.zip';

    final String antiCacheQuery = 'v=${DateTime.now().millisecondsSinceEpoch}';

    // récupérer la version du webapp
    try {
      // 🎯 Construction de l'URL avec le paramètre de requête pour bypasser le cache
      String webappInfoApi = '${Api.gitubApi}webapp_version.json?$antiCacheQuery';
      printTime('Fetching webapp version: $webappInfoApi');
      final response = await Api.httpGetWithHeaders(webappInfoApi);
      final jsonBody = json.decode(response.body);
      webappVersionServer = jsonBody['version'];
      webappfileNameServer = jsonBody['name'];
    }
    catch (e) {
      printTime('Error fetching webapp version: $e');
    }
    // ----------------------------------------------------------------------

    if (webappVersionServer != webappVersion) {
      String webappFileUrl = '${Api.gitubApi}$webappfileNameServer';
      await webappDir.create(recursive: true);
      printTime('Downloading webapp...');
      try {
        final response = await Api.httpGetWithHeaders(webappFileUrl);
        if (response.statusCode == 200) {
          printTime('Extracting webapp...');
          await extractWebAppZip(webappDir, response.bodyBytes);
          await setWebAppVersion(webappVersionServer);
          printTime('webapp downloaded');
        }
        else {
          printTime('Failed to download webapp: $webappFileUrl');
        }
      } catch (e) {
        printTime('Error downloading webapp: $e');
      }
    }
  }

  static Future<void> extractWebAppZip(Directory targetDirectory, Uint8List bytes) async {
    try {
      // Décompresser le ZIP
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      for (final ArchiveFile file in archive) {
        final String filePath = '${targetDirectory.path}/${file.name}';

        if (file.isFile) {
          // Créer le dossier parent si nécessaire
          await File(filePath).parent.create(recursive: true);
          // Écrire le contenu du fichier
          await File(filePath).writeAsBytes(file.content);
        }
        else {
          // Si c'est un dossier, le créer
          await Directory(filePath).create(recursive: true);
        }
      }
    } catch (e) {
      printTime("Erreur lors de l'extraction du ZIP : $e");
    }
  }
}