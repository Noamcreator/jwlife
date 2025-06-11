import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:http/http.dart' as http;

class AssetsDownload {
  static final String webappFileUrl = 'https://github.com/Noamcreator/jwlife/raw/refs/heads/main/webapp.zip';

  // Télécharge et enregistre les polices localement
  static Future<void> download() async {
    final directory = await getAppWebViewDirectory();
    final webappDir = Directory('${directory.path}/webapp');

    if (!await webappDir.exists()) {
      await webappDir.create(recursive: true);
      try {
        final response = await http.get(Uri.parse(webappFileUrl));
        if (response.statusCode == 200) {
          extractWebAppZip(webappDir, response.bodyBytes);
        }
        else {
          print('Failed to download webapp: $webappFileUrl');
        }
      } catch (e) {
        print('Error downloading webapp: $e');
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
      print("Erreur lors de l'extraction du ZIP : $e");
    }
  }
}
