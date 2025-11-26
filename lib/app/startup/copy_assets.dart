import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../core/utils/directory_helper.dart';
import '../../core/utils/utils.dart';

class CopyAssets {
  /// Copie les fichiers d'assets et extrait la base de données MEPS si nécessaire.
  static Future<void> copy() async {
    // Obtenir les répertoires en parallèle
    final [dbDir, userDataDir] = await Future.wait([
      getAppDatabasesDirectory(),
      getAppUserDataDirectory(),
    ]);

    await Future.wait([
      _extractMepsUnitFileIfOutdated(dbDir),
      _copyUserDataDefaultThumbnail(userDataDir),
    ]);
  }

  /// Extrait le fichier 'mepsunit.db' du zip dans les assets si le timestamp est différent.
  static Future<void> _extractMepsUnitFileIfOutdated(Directory dbDir) async {
    const assetMepsPath = Assets.mepsUnit;
    const mepsManifest = Assets.mepsManifest;
    const dbFileName = 'mepsunit.db';

    final mepsUnitDb = File('${dbDir.path}/$dbFileName');

    try {
      // 1. Charger et parser le manifest
      final manifestContent = await rootBundle.loadString(mepsManifest);
      final manifestJson = json.decode(manifestContent) as Map<String, dynamic>;
      final timestampInZip = manifestJson['timestamp'] as String;

      // 2. Vérifier l'état actuel
      final lastMepsTimestamp = AppSharedPreferences.instance.getLastMepsTimestamp();

      if (timestampInZip == lastMepsTimestamp && await mepsUnitDb.exists()) {
        print('Le fichier $dbFileName est déjà à jour. Extraction annulée.');
        return;
      }

      // 3. Charger le zip et décoder
      final zipData = await rootBundle.load(assetMepsPath);
      final archive = ZipDecoder().decodeBytes(zipData.buffer.asUint8List());

      // 4. Trouver et extraire le fichier
      final mepsUnitFile = archive.files.firstWhereOrNull((file) => file.name == dbFileName);

      if (mepsUnitFile == null) {
        throw StateError('$dbFileName not found in zip'); // Erreur plus spécifique
      }

      await mepsUnitDb.writeAsBytes(mepsUnitFile.content);

      // 5. Mise à jour du timestamp
      await AppSharedPreferences.instance.setNewMepsTimestamp(timestampInZip);

      print('Extraction de $dbFileName terminée avec succès.');
    } on StateError catch (e) {
      // Gérer l'erreur si mepsunit.db n'est pas trouvé dans le zip
      print('Erreur fatale: ${e.message}');
      rethrow;
    } catch (e) {
      // Gestion d'autres erreurs (lecture asset, I/O, parsing JSON)
      print('Erreur lors de l\'extraction de $dbFileName: $e');
    }
  }

  /// Copie le fichier thumbnail par défaut dans le répertoire utilisateur s'il n'existe pas.
  static Future<void> _copyUserDataDefaultThumbnail(Directory userDataDir) async {
    const assetPath = Assets.userDataDefaultThumbnail;
    final targetPath = '${userDataDir.path}/default_thumbnail.png';
    await copyFileFromAssetsToDirectory(assetPath, targetPath);
  }

  /// Copie un fichier d'asset vers un chemin cible si le fichier cible n'existe pas.
  static Future<void> copyFileFromAssetsToDirectory(String assetPath, String targetPath) async {
    final targetFile = File(targetPath);

    // Vérifie si le fichier existe déjà
    if (await targetFile.exists()) return;

    try {
      final data = await rootBundle.load(assetPath);
      await targetFile.create(recursive: true);
      // Utilisation simplifiée de writeAsBytes
      await targetFile.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (e) {
      // printTime est conservé si c'est une fonction utilitaire de votre projet
      printTime("Erreur lors de la copie du fichier: $assetPath -> $e");
    }
  }
}