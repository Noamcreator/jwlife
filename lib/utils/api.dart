import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/utils/shared_preferences_helper.dart';
import 'package:jwlife/utils/utils.dart';
import 'package:realm/realm.dart';
import '../jwlife.dart';
import '../realm/catalog.dart';
import '../realm/realm.dart';
import 'files_helper.dart';
import 'gzip.dart';

class Api {
  static String apiVersion = 'https://app.jw-cdn.org/catalogs/publications/v4/manifest.json';
  static String jwToken = 'https://b.jw-cdn.org/tokens/jworg.jwt';
  static String catalogInfo = 'https://app.jw-cdn.org/catalogs/publications/v4/{currentVersion}/catalog.info.json.gz';
  static String catalogs = 'https://app.jw-cdn.org/catalogs/publications/v4/{currentVersion}/catalog.db.gz';

  static String langCatalogs = 'https://app.jw-cdn.org/catalogs/media/{language_code}.json.gz';

  //static String allLanguages = 'https://data.jw-api.org/mediator/v1/languages/S/all.json';
  static String allLanguages = 'https://www.jw.org/fr/languages';
  static String langPubCatalogs = 'https://app.jw-cdn.org/catalogs/media/{language_catalog}';
  //static String mediaCategories = 'https://b.jw-cdn.org/apis/mediator/v1/categories/{language_catalog}/{categories}?detailed=1&mediaLimit=0';
  //static String mediaCategories = 'https://b.jw-cdn.org/apis/mediator/v1/categories/{language_catalog}/{categories}?detailed=1&clientType=www';

  static String currentVersion = '';
  static String currentJwToken = '';

  static Future<void> getCurrentVersionApi() async {
    try {
      final response = await http.get(Uri.parse(apiVersion));
      final jsonBody = json.decode(response.body);
      currentVersion = jsonBody['current'];
    }
    catch (e) {
      print('Error fetching current version: $e');
    }
  }

  static Future<void> getCurrentJwTokenApi() async {
    try {
      final response = await http.get(Uri.parse(jwToken));
      currentJwToken = response.body;
    }
    catch (e) {
      print('Error fetching current JW token: $e');
    }
  }

  static Future<String> getCatalogDateTime(String currentVersion) async {
    final catalogInfoResponse = await http.get(Uri.parse(catalogInfo.replaceFirst('{currentVersion}', currentVersion)));
    if (catalogInfoResponse.statusCode == 200) {
      final catalogInfoBytes = await decompressGZip(catalogInfoResponse.bodyBytes);
      final catalogInfoJson = json.decode(catalogInfoBytes!);
      // Enregistrer la date dans SharedPreferences
      setCatalogDate(catalogInfoJson['created']);

      return catalogInfoJson['created'];
    }
    return '';
  }

  static Future<bool> catalogHasUpdate() async {
    String catalogDate = await getCatalogDate(); // Obtenir la date qu'on a enregistré dans SharedPreferences
    String newCatalogDate = await getCatalogDateTime(currentVersion); // Obtenir la date du catalog en ligne

    if (catalogDate != newCatalogDate) { // On vérifie si les dates sont différentes
      print('Une mise à jour de catalog.db est disponible');
      return true; // true si une mise à jour est disponible
    }
    return false; // false si aucune mise à jour
  }

  // Fonction de mise à jour du catalogue
  static Future<void> updateCatalog() async {
    File catalogFile = await getCatalogFile(); // on récupère l'emplacement du fichier catalog en local

    // On télécharge le catalog.db
    final response = await http.get(Uri.parse(catalogs.replaceFirst('{currentVersion}', currentVersion)));
    if (response.statusCode == 200) {
      print('catalog.db est en cours de téléchargement...');
      await decompressGZipDb(response.bodyBytes, catalogFile); // On décompresse le gzip qui contient le catalog.db et on le stocke dans le fichier local

      print("catalog.db a été mis à jour dans: $catalogFile");
    } else {
      print('Erreur lors du téléchargement du catalog.db: ${response.statusCode}');
    }
  }

  // Fonction pour vérifier si une mise à jour de la bibliothèque est disponible
  static Future<bool> libraryHasUpdate(String languageSymbol) async {
    try {
      String link = langCatalogs.replaceFirst('{language_code}', languageSymbol); // Lien vers la librairie de la langue
      final response = await http.get(Uri.parse(link));

      // Récupérer la date de modification du catalogue sur le serveur
      String catalogDateServer = response.headers['last-modified']!;

      // Rechercher la langue dans la base de données
      final results = JwLifeApp.library.all<Language>().query("symbol == '$languageSymbol'");

      // Vérifier si des résultats existent
      Language? language;
      if (results.isNotEmpty) {
        language = results.first;
      }

      // Si la langue est trouvée, vérifier sa date de dernière modification
      if (language != null) {
        String catalogDateLocal = language.lastModified!;

        // Si la date locale est vide ou différente de celle du serveur, une mise à jour est nécessaire
        if (catalogDateLocal.isEmpty || catalogDateLocal != catalogDateServer) {
          print('Une mise à jour du catalogue de la langue $languageSymbol est disponible');
          return true;
        } else {
          print('Le catalogue de la langue $languageSymbol est déjà à jour');
          return false;
        }
      } else {
        // Si la langue n'est pas trouvée, cela signifie qu'elle doit être ajoutée, et donc qu'une mise à jour est nécessaire
        print('Le catalogue de la langue $languageSymbol doit être ajouté');
        return true;
      }
    } catch (e) {
      print('Une erreur est survenue lors de la vérification de la mise à jour de la bibliothèque: $e');
      return false;
    }
  }

  // Fonction de mise à jour de la bibliothèque
  static Future<bool> updateLibrary(String languageSymbol) async {
    try {
      String link = langCatalogs.replaceFirst('{language_code}', languageSymbol); // Lien vers la librairie de la langue
      final response = await http.get(Uri.parse(link));

      if (response.statusCode == 200) {
        print('Chargement du catalogue de la langue $languageSymbol');
        await RealmMediaHandler.convertMediaJsonToRealm(response.bodyBytes);

        // Mettre à jour la date de dernière modification
        String catalogDateServer = response.headers['last-modified']!;
        final results = JwLifeApp.library.all<Language>().query("symbol == '$languageSymbol'");
        Language language = results.first;
        JwLifeApp.library.write(() {
          language.lastModified = catalogDateServer;
        });

        print('Le catalogue de la langue $languageSymbol a été mis à jour');
        return true;
      } else {
        print('Échec du téléchargement du catalogue de la langue $languageSymbol: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Une erreur est survenue lors de la mise à jour de la bibliothèque: $e');
      return false;
    }
  }
}
