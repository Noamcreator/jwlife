import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwlife/utils/shared_preferences_helper.dart';
import 'package:realm/realm.dart';
import '../jwlife.dart';
import '../realm/catalog.dart';
import '../realm/realm.dart';
import 'files_helper.dart';
import 'gzip.dart';

// 8f9edb62-1ab4-4308-9a33-6a1cfbb29ca6
class Api {
  static String apiVersion = 'https://app.jw-cdn.org/catalogs/publications/v4/manifest.json';
  static String catalogInfo = 'https://app.jw-cdn.org/catalogs/publications/v4/{currentVersion}/catalog.info.json.gz';
  static String catalogs = 'https://app.jw-cdn.org/catalogs/publications/v4/{currentVersion}/catalog.db.gz';

  static String langCatalogs = 'https://app.jw-cdn.org/catalogs/media/{language_code}.json.gz';

  //static String allLanguages = 'https://data.jw-api.org/mediator/v1/languages/S/all.json';
  static String allLanguages = 'https://www.jw.org/fr/languages';
  static String langPubCatalogs = 'https://app.jw-cdn.org/catalogs/media/{language_catalog}';
  //static String mediaCategories = 'https://b.jw-cdn.org/apis/mediator/v1/categories/{language_catalog}/{categories}?detailed=1&mediaLimit=0';
  //static String mediaCategories = 'https://b.jw-cdn.org/apis/mediator/v1/categories/{language_catalog}/{categories}?detailed=1&clientType=www';


  static Future<String> getCurrentVersionApi() async {
    try {
      final response = await http.get(Uri.parse(apiVersion));
      final jsonBody = json.decode(response.body);
      return jsonBody['current'];
    }
    catch (e) {
      print('Error fetching current version: $e');
      return '';
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

  static Future<bool> catalogHasUpdate(String currentVersion) async {
    String catalogDate = await getCatalogDate(); // Obtenir la date qu'on a enregistré dans SharedPreferences
    String newCatalogDate = await getCatalogDateTime(currentVersion); // Obtenir la date du catalog en ligne

    if (catalogDate != newCatalogDate) { // On verifie si les dates sont differentes
      print('Une mise à jour de catalog.db est disponible');
      return true; // true si une mise à jour est disponible
    }
    return false; // false si aucune mise à jour
  }

  static Future<void> updateCatalog() async {
    String currentVersion = await getCurrentVersionApi(); // Obtenir le "current" de la version actuelle de l'api

    File catalogFile = await getCatalogFile(); // on récupère l'emplacement du fichier catalog en local

    if(await catalogHasUpdate(currentVersion)) { // Si une mise à jour est disponible
      // On télécharge le catalog.db
      final response = await http.get(Uri.parse(catalogs.replaceFirst('{currentVersion}', currentVersion)));
      if(response.statusCode == 200) {
        print('catalog.db est en cours de téléchargement...');
        await decompressGZipDb(response.bodyBytes, catalogFile); // On decompresse le gzip qui contient le catalog.db et on le stocke dans le fichier local

        print("catalog.db a été mis à jour dans: $catalogFile");

        await JwLifeApp.setStateHomePage(); // On rafraichit la page d'accueil
      }
      else {
        print('Erreur lors du téléchargement du catalog.db: ${response.statusCode}');
      }
    }
    else {
      print("catalog.db n'a pas de mise à jour disponible");
    }
  }

  static Future<void> updateLibrary(String languageSymbol) async {
    try {
      String link = langCatalogs.replaceFirst('{language_code}', languageSymbol); // Lien vers la librairie de la langue
      final response = await http.get(Uri.parse(link));

      final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
      Realm realm = Realm(config);

      // Rechercher la langue dans la base de données
      final results = realm.all<Language>().query("symbol == '$languageSymbol'");

      // Vérifier si des résultats existent
      Language? language;
      if (results.isNotEmpty) {
        language = results.first;
      }

      // Récupérer la date de modification du catalogue sur le serveur
      String catalogDateServer = response.headers['last-modified']!;

      // Si la langue est trouvée, vérifier sa date de dernière modification
      if (language != null) {
        String catalogDateLocal = language.lastModified!;

        if (catalogDateLocal.isEmpty || catalogDateLocal != catalogDateServer) {
          if (response.statusCode == 200) {
            print('Chargement du catalogue de la langue $languageSymbol');
            await RealmMediaHandler.convertMediaJsonToRealm(response.bodyBytes);

            print('Le catalogue de la langue $languageSymbol est mis à jour');
          }
          else {
            print('Échec du téléchargement du catalogue de la langue $languageSymbol: ${response.statusCode}');
          }
        }
        else {
          print('Le catalogue de la langue $languageSymbol est déjà mis à jour');
        }

        // Mettre à jour la date de dernière modification
        realm.write(() {
          language?.lastModified = catalogDateServer;
        });
      }
      else {
        // La langue n'a pas été trouvée, donc on doit peut-être gérer cela (ajouter un nouveau langage ou autre)
        if (response.statusCode == 200) {
          print('Chargement du catalogue de la langue $languageSymbol (nouvelle langue)');
          await RealmMediaHandler.convertMediaJsonToRealm(response.bodyBytes);

          realm.refresh();

          Language language = realm.all<Language>().query("symbol == '$languageSymbol'").first;
          realm.write(() {
            language.lastModified = catalogDateServer;
          });

          print('Le catalogue de la langue $languageSymbol a été ajouté');
        }
        else {
          print('Échec du téléchargement du catalogue de la langue $languageSymbol: ${response.statusCode}');
        }
      }

      realm.close();
    } catch (e) {
      print('Une erreur est survenue: $e');
    }
  }
}
