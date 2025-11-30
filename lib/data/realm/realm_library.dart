import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:path/path.dart' as path;

import '../../app/services/settings_service.dart';
import '../models/audio.dart';
import '../models/video.dart';
import '../models/media.dart';
import 'catalog.dart';

/// Classe pour gérer les opérations de la base de données Realm.
class RealmLibrary {
  RealmLibrary._();

  static late Realm realm;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();

    // --- Chemins de l'ancienne base ---
    final oldRealmPath = path.join(dir.path, "default.realm");
    final oldLock = "$oldRealmPath.lock";
    final oldNote = "$oldRealmPath.note";
    final oldManagement = "$oldRealmPath.management"; // dossier

    // --- Suppression de l'ancienne base ---
    // Fichiers
    for (final filePath in [oldRealmPath, oldLock, oldNote]) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Dossier .management
    final managementDir = Directory(oldManagement);
    if (await managementDir.exists()) {
      await managementDir.delete(recursive: true);
    }

    // --- Nouveau chemin ---
    final newRealmPath = path.join(dir.path, "mediator.realm");

    final config = Configuration.local(
      [
        RealmImages.schema,
        RealmMediaItem.schema,
        RealmLanguage.schema,
        RealmCategory.schema,
      ],
      path: newRealmPath,
    );

    realm = Realm(config);
  }

  // ---------- LECTURE ----------

  /// Charge les vidéos et audios de la catégorie 'TeachingToolbox' pour la langue courante.
  static List<Media> loadTeachingToolboxVideos() {
    return _loadMediaFromCategory('TeachingToolbox');
  }

  /// Charge les vidéos et audios de la catégorie 'LatestAudioVideo' pour la langue courante.
  static List<Media> loadLatestMedias() {
    return _loadMediaFromCategory('LatestAudioVideo');
  }

  static void updateLibraryCategories() {
    String languageSymbol = JwLifeSettings.instance.currentLanguage.value.symbol;

    final videoResults = realm.all<RealmCategory>().query("Key == 'VideoOnDemand' AND LanguageSymbol == '$languageSymbol'");
    final audioResults = realm.all<RealmCategory>().query("Key == 'Audio' AND LanguageSymbol == '$languageSymbol'");

    AppDataService.instance.videoCategories.value = videoResults.isNotEmpty ? videoResults.first : null;
    AppDataService.instance.audioCategories.value = audioResults.isNotEmpty ? audioResults.first : null;
  }

  /// Helper générique pour charger les médias à partir d'une clé de catégorie.
  static List<Media> _loadMediaFromCategory(String categoryKey) {
    final List<Media> out = [];
    // Utiliser `symbol` directement est plus propre
    final String languageSymbol = JwLifeSettings.instance.currentLanguage.value.symbol;

    final categories = realm.all<RealmCategory>().query("Key == \$0 AND LanguageSymbol == \$1", [categoryKey, languageSymbol]);

    final mediaKeys = categories.expand((c) => c.media).toSet();

    for (final mediaKey in mediaKeys) {
      final mediaItem = realm.all<RealmMediaItem>().query("NaturalKey == \$0", [mediaKey]).firstOrNull;

      if (mediaItem != null) {
        final t = (mediaItem.type ?? '').toUpperCase();
        if (t == 'VIDEO') {
          // Utilisez le constructeur nommé pour la clarté
          out.add(Video.fromJson(mediaItem: mediaItem));
        } else if (t == 'AUDIO') {
          out.add(Audio.fromJson(mediaItem: mediaItem));
        }
      }
    }
    return out;
  }

  static RealmMediaItem getMediaItemByNaturalKey(String naturalKey, String languageSymbol) {
    RealmResults<RealmMediaItem> mediaItems = RealmLibrary.realm.all<RealmMediaItem>().query("NaturalKey == \$0", [naturalKey]);

    if(mediaItems.length > 1) {
      String compoundKey = '$languageSymbol-$naturalKey';
      return RealmLibrary.realm.all<RealmMediaItem>().query("CompoundKey == \$0", [compoundKey]).first;
    }
    else {
      return mediaItems.first;
    }
  }

  // ---------- IMPORT JSON -> REALM ----------

  /// Décode les données GZip JSON, parse et insère/met à jour les données dans la base de donnée Realm.
  static Future<void> convertMediaJsonToRealm(Uint8List bodyBytes, String serverEtag, String serverDate) async {
    final decodedData = GZipCodec().decode(bodyBytes);
    final String jsonString = utf8.decode(decodedData);

    // Utiliser LineSplitter.split est correct si chaque ligne est un objet JSON.
    final List<dynamic> jsonList = LineSplitter.split(jsonString).map((line) => json.decode(line)).toList();

    // Déclaration des listes pour l'insertion
    final List<RealmLanguage> languagesToAdd = [];
    final List<RealmCategory> categoriesToAdd = [];
    final List<RealmMediaItem> mediaToAdd = [];

    // 2. Pré-parsing et collecte
    for (final entry in jsonList) {
      final type = entry['type'];
      final data = entry['o'];

      if (type == 'language') {
        languagesToAdd.add(RealmLanguage(
          data['code'] ?? '',
          locale: data['locale'],
          vernacular: data['vernacular'],
          name: data['name'],
          isLanguagePair: data['isLangPair'] ?? false,
          isSignLanguage: data['isSignLanguage'] ?? false,
          isRtl: data['isRTL'] ?? false,
          eTag: serverEtag,
          lastModified: serverDate,
        ));
      }
      else if (type == 'category') {
        categoriesToAdd.add(_parseCategory(data, languagesToAdd.first.symbol));
      }
      else if (type == 'media-item') {
        // Ajouter la vérification de la langue
        if (languagesToAdd.isNotEmpty) {
          final item = _parseMediaItem(data, languagesToAdd.first.symbol);
          if (item != null) {
            mediaToAdd.add(item);
          }
        }
      }
    }

    // Si aucune langue n'a été trouvée, on ne peut pas faire la purge/insertion
    if (languagesToAdd.isEmpty) {
      // Optionnel: logger une erreur
      return;
    }

    // 3. 🔥 Transaction : purge + réinsertion
    realm.write(() {
      // 1. Identification des objets liés à la langue
      final catsToPurge = realm.all<RealmCategory>().query("LanguageSymbol == \$0", [languagesToAdd.first.symbol ?? '']);
      final mediasToPurge = realm.all<RealmMediaItem>().query("LanguageSymbol == \$0", [languagesToAdd.first.symbol ?? '']);

      // 2. Collecte des images à supprimer
      // On collecte tous les objets Images référencés par les Category et MediaItem
      // que nous allons supprimer.
      final List<RealmImages> imagesToDelete = [];

      // Collecter les images des catégories
      for (final cat in catsToPurge) {
        if (cat.images != null) {
          imagesToDelete.add(cat.images!);
        }
      }

      // Collecter les images des médias
      for (final media in mediasToPurge) {
        if (media.images != null) {
          imagesToDelete.add(media.images!);
        }
      }

      // 3. Purger les Images
      // C'est l'étape que vous vouliez réintégrer, mais en utilisant une liste
      // collectée en amont, ce qui est plus direct et performant.
      realm.deleteMany(imagesToDelete);

      // 4. Purger les objets principaux (Category et MediaItem)
      // C'EST CETTE ÉTAPE QUI GARANTIT QU'IL N'Y AURA PAS DE DOUBLONS
      realm.deleteMany(catsToPurge);
      realm.deleteMany(mediasToPurge);

      // 5. Ajouter les nouvelles données (Insertion/Mise à jour)
      realm.addAll(languagesToAdd, update: true);
      realm.addAll(categoriesToAdd);
      realm.addAll(mediaToAdd);
    });
  }

  // ---------- HELPERS ----------

  /// Parse les données JSON pour créer un objet [RealmCategory].
  static RealmCategory _parseCategory(Map<String, dynamic> data, String? languageSymbol) {
    // Vérification de nullité plus stricte pour le code de catégorie
    final String categoryKey = data['key']?.toString() ?? '';
    if (categoryKey.isEmpty) {
      // Optionnel: log d'erreur
      throw Exception('Category key is missing');
    }

    final List<String> media = (data['media'] is List)
        ? List<String>.from(data['media'] as List).toSet().toList()
        : <String>[];

    final List<dynamic> rawSubs = data['subcategories'] as List? ?? const [];
    final List<RealmCategory> subcategories = [];

    // Utilisation de `try-catch` pour le parsing récursif
    for (final sub in rawSubs) {
      if (sub is Map<String, dynamic>) {
        try {
          subcategories.add(_parseCategory(sub, languageSymbol));
        } catch (e) {
          // Gérer les sous-catégories malformées
          // Optionnel: log d'erreur
        }
      }
    }

    // Assurer que les champs non-nullables dans le modèle Realm sont gérés.
    return RealmCategory(
      key: categoryKey,
      type: data['type'],
      name: data['name'],
      images: _parseImages(data['images'], true),
      media: media,
      subCategories: subcategories,
      languageSymbol: languageSymbol,
    );
  }

  /// Parse les données JSON pour créer un objet [RealmMediaItem].
  static RealmMediaItem? _parseMediaItem(Map<String, dynamic> data, String? languageSymbol) {
    // 1. Traitement de la clé naturelle
    final String? rawNk = data['naturalKey'];
    if (rawNk == null || rawNk.isEmpty) return null;

    // Remplacement correct, s'assurant que `naturalKey` est non-null
    final String naturalKey = rawNk;
    final String compoundKey = '${languageSymbol ?? ''}-$rawNk';

    if (naturalKey.isEmpty) return null;

    // 2. Normalisation du type (simplifié)
    String? normalizeType(dynamic format) {
      if (format == null) return null;
      final f = format.toString().toUpperCase();
      if (f == 'VIDEO' || f == 'AUDIO') return f;
      // Retourner null si ce n'est ni VIDEO ni AUDIO pour éviter les types non supportés
      return null;
    }

    // 3. Parsing des KeyParts
    final Map<String, dynamic> keyParts =
    (data['keyParts'] is Map<String, dynamic>) ? data['keyParts'] as Map<String, dynamic> : {};
    final String? type = normalizeType(keyParts['formatCode']);

    // Si le type n'est pas VIDEO ou AUDIO, on peut l'ignorer
    if (type == null) return null;

    // 4. Parsing de la durée (plus robuste)
    double? duration;
    final d = data['duration'];
    if (d is num) {
      // Gère int et double
      duration = d.toDouble();
    } else if (d is String) {
      duration = double.tryParse(d);
    }

    // 5. Parsing de issueDate (plus robuste)
    int? issueDate;
    final issue = keyParts['issueDate'];
    if (issue is int) {
      issueDate = issue;
    } else if (issue is String) {
      issueDate = int.tryParse(issue);
    }

    String? remoteType;
    final remote = keyParts['remoteType'];
    if (remote is String) {
      remoteType = remote;
    }

    // Assurer que les champs non-nullables dans le modèle Realm sont gérés.
    return RealmMediaItem(
      compoundKey,
      duration ?? 0.0,
      DateTime.parse(data['firstPublished']),
      (data['tags'] is List) ? List<String>.from(data['tags'] as List).contains('ConventionRelease') : false,
      documentId: keyParts['docID'],
      issueDate: issueDate,
      languageAgnosticNaturalKey: data['languageAgnosticNaturalKey'],
      languageSymbol: keyParts['languageCode'] ?? languageSymbol,
      naturalKey: naturalKey,
      checksums: (data['checksums'] is List) ? List<String>.from(data['checksums'] as List) : const <String>[],
      images: _parseImages(data['images'], false),
      type: type,
      remoteType: remoteType ?? '',
      primaryCategory: data['primaryCategory'],
      pubSymbol: keyParts['pubSymbol'],
      title: data['title'],
      track: keyParts['track'],
    );
  }

  /// Parse les données JSON pour créer un objet [images].
  static RealmImages? _parseImages(dynamic images, bool isCategory) {
    if (images is! Map<String, dynamic>) return null;
    // Utiliser des variables locales pour simplifier le code
    final Map<String, dynamic> sqr = images['sqr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> cvr = images['cvr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> lsr = images['lsr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> pnr = images['pnr'] as Map<String, dynamic>? ?? {};

    String? squareImageUrl = isCategory ? sqr['md'] ?? sqr['xs'] : sqr['xs'] ?? sqr['md'] as String?;
    String? squareFullSizeImageUrl = isCategory ? sqr['lg'] ?? sqr['xl'] : sqr['xl'] ?? sqr['lg'] as String?;
    String? wideImageUrl = lsr['xs'] as String?;
    String? wideFullSizeImageUrl = lsr['xl'] as String?;
    String? extraWideImageUrl = pnr['sm'] as String?;
    String? extraWideFullSizeImageUrl = pnr['lg'] as String?;

    // Logique de fallback pour `squareImageUrl`
    squareImageUrl ??= cvr['xs'] as String?;
    squareFullSizeImageUrl ??= cvr['lg'] as String?;

    // Retourner null si aucune image n'a pu être trouvée
    if (squareImageUrl == null &&
        squareFullSizeImageUrl == null &&
        wideImageUrl == null &&
        wideFullSizeImageUrl == null &&
        extraWideImageUrl == null &&
        extraWideFullSizeImageUrl == null) {
      return null;
    }

    // Assurer que les champs non-nullables sont gérés dans le constructeur
    return RealmImages(
      squareImageUrl: squareImageUrl,
      squareFullSizeImageUrl: squareFullSizeImageUrl,
      wideImageUrl: wideImageUrl,
      wideFullSizeImageUrl: wideFullSizeImageUrl,
      extraWideImageUrl: extraWideImageUrl,
      extraWideFullSizeImageUrl: extraWideFullSizeImageUrl,
    );
  }
}