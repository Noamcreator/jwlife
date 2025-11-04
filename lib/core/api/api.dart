import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:realm/realm.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/audio.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../utils/files_helper.dart';
import '../utils/gzip_helper.dart';

class Api {
  static final String gitubApi = 'https://github.com/Noamcreator/jwlife/raw/refs/heads/main/api/';

  // URLs des API nécessaires
  static const String version = 'v5';
  static const String apiVersionUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/manifest.json';
  static const String jwTokenUrl = 'https://b.jw-cdn.org/tokens/jworg.jwt';
  //static const String jwTokenUrl = 'https://app.jw-cdn-qa.org/tokens/jwl-public.jwt';
  static const String catalogInfoUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/{currentVersion}/catalog.info.json.gz';
  static const String catalogUrl = 'https://app.jw-cdn.org/catalogs/publications/$version/{currentVersion}/catalog.db.gz';
  static const String langCatalogUrl = 'https://app.jw-cdn.org/catalogs/media/{language_code}.json.gz';

  static const String baseUrl = 'b.jw-cdn.org';
  static const String getPubMediaLinks = '/apis/pub-media/GETPUBMEDIALINKS';

  // Variables pour stocker la version et le token JW.org
  static String currentVersion = '';
  static String currentJwToken = '';

  static int lastRevisionAvailable = 0;

  static final Dio dio = Dio(
      BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 0),
          headers: {
            'User-Agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
            'Accept': "*/*",
            'Accept-Encoding': "gzip, deflate, br, zstd",
            'Connection': 'keep-alive',
            'Content-Length': null,
            'Host': null
          },
          persistentConnection: false
      ),
  );

  /// Récupère la version actuelle de l'API.
  static Future<void> fetchCurrentVersion() async {
    try {
      final response = await httpGetWithHeaders(apiVersionUrl);
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
      final response = await httpGetWithHeaders(jwTokenUrl);
      currentJwToken = response.body;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du token JWT : $e');
    }
  }

  /// Récupère la date de création du catalogue pour une version donnée.
  static Future<int> fetchCatalogInfo() async {
    if(currentVersion.isEmpty) {
      await fetchCurrentVersion();
    }

    try {
      final url = catalogInfoUrl.replaceFirst('{currentVersion}', currentVersion);
      final response = await httpGetWithHeaders(url);

      if (response.statusCode == 200) {
        final json = await GZipHelper.decompressJson(response.bodyBytes);
        return json['revision'];
      }
    }
    catch (e) {
      printTime('Erreur lors de la récupération de la dernière révision du catalogue : $e');
    }
    return 0;
  }

  /// Vérifie si une mise à jour du catalogue est disponible.
  static Future<bool> isCatalogUpdateAvailable() async {
    try {
      final catalogFile = await getCatalogDatabaseFile();
      final lastRevisionDownloaded = await getLastCatalogRevision();
      final lastRevisionAvailable = await fetchCatalogInfo();
      Api.lastRevisionAvailable = lastRevisionAvailable;

      if (lastRevisionDownloaded != lastRevisionAvailable || !catalogFile.existsSync()) {
        printTime('Une mise à jour de "catalog.db" est disponible.');
        return true;
      }
    } catch (e) {
      printTime('Erreur lors de la vérification de la mise à jour du catalogue : $e');
    }
    return false;
  }

  /// Met à jour le fichier catalog.db en local.
  static Future<void> updateCatalog() async {
    try {
      final catalogFile = await getCatalogDatabaseFile();
      final url = catalogUrl.replaceFirst('{currentVersion}', currentVersion);

      printTime('Téléchargement de catalog.db en cours... $url');
      final response = await httpGetWithHeaders(url);
      if (response.statusCode == 200) {
        printTime('Le fichier "catalog.db" a été téléchargé');

        printTime('Decompression de catalog.db en cours...');
        await GZipHelper.decompressToFile(response.bodyBytes, catalogFile);
        printTime('Le fichier "catalog.db" a été décompressé avec succés dans : $catalogFile');

        printTime('On met à jour ala dernière revision ($lastRevisionAvailable) du catalogue dans les préférences');
        setNewCatalogRevision(lastRevisionAvailable);
      }
      else {
        printTime('Erreur lors du téléchargement de catalog.db : ${response.statusCode}');
      }
    }
    catch (e) {
      printTime('Erreur lors de la mise à jour du catalogue : $e');
    }
  }

  /// Vérifie si une mise à jour de la bibliothèque pour une langue donnée est disponible.
  static Future<bool> isLibraryUpdateAvailable({String? symbol}) async {
    String languageSymbol = symbol ?? JwLifeSettings().currentLanguage.symbol;

    try {
      final url = langCatalogUrl.replaceFirst('{language_code}', languageSymbol);
      final response = await httpGetWithHeaders(url);
      final serverETag = response.headers['etag'] ?? '';
      final serverDate = response.headers['last-modified'] ?? '';

      final results = RealmLibrary.realm.all<Language>().query("symbol == '$languageSymbol'");
      final language = results.isNotEmpty ? results.first : null;

      if (language == null || language.eTag != serverETag || language.lastModified != serverDate) {
        printTime('Une mise à jour de la bibliothèque pour la langue $languageSymbol est disponible.');
        return true;
      }
    }
    catch (e) {
      printTime('Erreur lors de la vérification de mise à jour de la bibliothèque : $e');
    }
    printTime('La Bibliothèque pour la langue $languageSymbol est déjà à jour.');
    return false;
  }

  /// Met à jour la bibliothèque pour une langue donnée.
  static Future<bool> updateLibrary(String languageSymbol) async {
    try {
      final url = langCatalogUrl.replaceFirst('{language_code}', languageSymbol);
      final response = await httpGetWithHeaders(url);

      if (response.statusCode == 200) {
        debugPrint('Chargement du catalogue pour la langue $languageSymbol...');
        // Mettre à jour la date de modification
        final serverEtag = response.headers['etag'] ?? '';
        final serverDate = response.headers['last-modified'] ?? '';

        await RealmLibrary.convertMediaJsonToRealm(response.bodyBytes, serverEtag, serverDate);

        debugPrint('Catalogue de la langue $languageSymbol mis à jour.');
        return true;
      }
      else {
        debugPrint('Échec du téléchargement du catalogue pour la langue $languageSymbol : ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la bibliothèque : $e');
    }
    return false;
  }

  static Future<List<Audio>?> getPubAudio({required String keySymbol, required int issueTagNumber, required String languageSymbol}) async {
    try {
      final pubKey = keySymbol.contains('nwt') ? 'nwt' : keySymbol;

      final queryParams = {
        'pub': pubKey,
        'issue': issueTagNumber.toString(),
        'langwritten': languageSymbol,
        'fileformat': 'mp3',
      };

      final url = Uri.https(baseUrl, getPubMediaLinks, queryParams);
      print('Generated URL: $url');

      final response = await dio.getUri(
        url,
        options: Options(
          headers: Api.getHeaders(),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        List<Audio> audioList = [];

        if (data.containsKey('files') && data['files'][languageSymbol] != null) {
          final files = data['files'][languageSymbol];

          if (files.containsKey('MP3') && files['MP3'] is List) {
            for (final audio in files['MP3']) {
              if (audio.containsKey('file')) {
                final file = audio['file'] as Map<String, dynamic>? ?? {};

                final Map<String, dynamic> audioMap = {
                  "KeySymbol": audio['pub'] ?? '',
                  "DocumentId": audio['docid'] ?? '',
                  "Track": audio['track'] ?? 0,
                  "BookNumber": audio['booknum'] ?? 0,
                  "Title": audio['title'] ?? '',
                  "FileSize": audio['filesize'] ?? 0,
                  "FileUrl": file['url'] ?? '',
                  "ModifiedDateTime": file['modifiedDatetime'] ?? '',
                  "Markers": audio['markers']['markers'] ?? [],
                  "Version": 1,
                  "MimeType": audio['mimetype'] ?? '',
                  "BitRate": audio['bitRate'] ?? 0,
                  "Duration": audio['duration'] ?? 0,
                  "Checksum": file['checksum'] ?? '',
                  "Source": 0,
                };

                audioList.add(Audio.fromJson(
                  json: audioMap,
                  languageSymbol: languageSymbol,
                ));
              }
            }
          }
          return audioList;
        }
      }

      return null;
    }
    catch (e) {
      print('Error fetching audios: $e');
      return null;
    }
  }

  static Future<http.Response> httpGetWithHeadersUri(Uri url, {Map<String, String>? headers}) async {
    try {
      final h = getHeaders();

      if (headers != null) {
        h.addAll(headers);
      }

      final response = await http.get(url, headers: h);
      return response;
    }
    catch (e) {
      printTime('Erreur HTTP GET : $e');
      return http.Response('', 500);
    }
  }

  static Future<http.Response> httpGetWithHeaders(String url) async {
    try {
      final headers = getHeaders();

      final response = await http.get(Uri.parse(url), headers: headers);
      return response;
    }
    catch (e) {
      printTime('Erreur HTTP GET : $e');
      return http.Response('', 500);
    }
  }

  static Map<String, String> getHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'sec-ch-ua': '"Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Android"',
      'Connection': 'keep-alive',
    };
  }
}