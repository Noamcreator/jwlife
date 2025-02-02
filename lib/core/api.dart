import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:realm/realm.dart';
import '../data/realm/catalog.dart';
import '../data/realm/realm_library.dart';
import 'utils/files_helper.dart';
import 'utils/gzip.dart';

class Api {
  // URLs des API nécessaires
  static const String version = 'v5';
  static const String apiVersionUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/manifest.json';
  static const String jwTokenUrl = 'https://b.jw-cdn.org/tokens/jworg.jwt';
  static const String catalogInfoUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/{currentVersion}/catalog.info.json.gz';
  static const String catalogUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/{currentVersion}/catalog.db.gz';
  static const String langCatalogUrl = 'https://app.jw-cdn.org/catalogs/media/{language_code}.json.gz';
  static const String allLanguagesUrl = 'https://www.jw.org/fr/languages';

  // Variables pour stocker la version et le token JW.org
  static String currentVersion = '';
  static String currentJwToken = '';

  /// Récupère la version actuelle de l'API.
  static Future<void> fetchCurrentVersion() async {
    try {
      final response = await http.get(Uri.parse(apiVersionUrl));
      final jsonBody = json.decode(response.body);
      currentVersion = jsonBody['current'];
    }
    catch (e) {
      debugPrint('Erreur lors de la récupération de la version actuelle : $e');
    }
  }

  /// Récupère le token JWT actuel.
  static Future<void> fetchCurrentJwToken() async {
    try {
      final response = await http.get(Uri.parse(jwTokenUrl));
      currentJwToken = response.body;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du token JWT : $e');
    }
  }

  /// Récupère la date de création du catalogue pour une version donnée.
  static Future<String> fetchCatalogDate(String version) async {
    try {
      final url = catalogInfoUrl.replaceFirst('{currentVersion}', version);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decompressedBytes = await decompressGZip(response.bodyBytes);
        final catalogInfo = json.decode(decompressedBytes!);

        // Enregistrer la date dans les préférences partagées
        await setCatalogDate(catalogInfo['created']);

        return catalogInfo['created'];
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la date du catalogue : $e');
    }
    return '';
  }

  /// Vérifie si une mise à jour du catalogue est disponible.
  static Future<bool> isCatalogUpdateAvailable() async {
    try {
      final catalogFile = await getCatalogFile();
      final localDate = await getCatalogDate();
      final serverDate = await fetchCatalogDate(currentVersion);

      if (localDate != serverDate || !catalogFile.existsSync()) {
        debugPrint('Une mise à jour de catalog.db est disponible.');
        return true;
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de mise à jour du catalogue : $e');
    }
    return false;
  }

  /// Met à jour le fichier catalog.db en local.
  static Future<void> updateCatalog() async {
    try {
      final catalogFile = await getCatalogFile();
      final url = catalogUrl.replaceFirst('{currentVersion}', currentVersion);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        debugPrint('Téléchargement de catalog.db en cours...');
        await decompressGZipDb(response.bodyBytes, catalogFile);
        debugPrint('catalog.db mis à jour dans : $catalogFile');
      }
      else {
        debugPrint('Erreur lors du téléchargement de catalog.db : ${response.statusCode}');
      }
    }
    catch (e) {
      debugPrint('Erreur lors de la mise à jour du catalogue : $e');
    }
  }

  /// Vérifie si une mise à jour de la bibliothèque pour une langue donnée est disponible.
  static Future<bool> isLibraryUpdateAvailable(String languageSymbol) async {
    try {
      final url = langCatalogUrl.replaceFirst('{language_code}', languageSymbol);
      final response = await http.get(Uri.parse(url));
      final serverDate = response.headers['last-modified'] ?? '';

      final results = RealmLibrary.realm.all<Language>().query("symbol == '$languageSymbol'");
      final language = results.isNotEmpty ? results.first : null;

      if (language == null || language.lastModified != serverDate) {
        debugPrint('Une mise à jour de la bibliothèque pour la langue \$languageSymbol est disponible.');
        return true;
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de mise à jour de la bibliothèque : $e');
    }
    debugPrint('La bibliothèque pour la langue \$languageSymbol est déjà à jour.');
    return false;
  }

  /// Met à jour la bibliothèque pour une langue donnée.
  static Future<bool> updateLibrary(String languageSymbol) async {
    try {
      final url = langCatalogUrl.replaceFirst('{language_code}', languageSymbol);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        debugPrint('Chargement du catalogue pour la langue \$languageSymbol...');
        await RealmLibrary.convertMediaJsonToRealm(response.bodyBytes);

        // Mettre à jour la date de modification
        final serverDate = response.headers['last-modified'] ?? '';
        final results = RealmLibrary.realm.all<Language>().query("symbol == '$languageSymbol'");

        RealmLibrary.realm.write(() {
          results.first.lastModified = serverDate;
        });

        debugPrint('Catalogue de la langue \$languageSymbol mis à jour.');
        return true;
      }
      else {
        debugPrint('Échec du téléchargement du catalogue pour la langue \$languageSymbol : ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la bibliothèque : $e');
    }
    return false;
  }
}
