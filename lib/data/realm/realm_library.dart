import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:realm/realm.dart';

import '../../app/services/settings_service.dart';
import '../models/audio.dart';
import '../models/video.dart';
import '../models/media.dart'; // Assurez-vous que MediaItem, Language, Images, Category sont importés ici
import 'catalog.dart'; // Contient probablement les classes Language, Images, Category, MediaItem.

/// Classe pour gérer les opérations de la base de données Realm.
class RealmLibrary {
  // Rendre le constructeur privé pour une utilisation en singleton/statique
  RealmLibrary._();

  // Utiliser un getter pour le Realm, pour s'assurer qu'il est toujours initialisé.
  // Utiliser `lazy` ou `static final` est bon pour un Realm global.
  static final Realm realm = Realm(
    Configuration.local([
      MediaItem.schema,
      Language.schema,
      Images.schema,
      Category.schema,
    ],
    ),
  );

  // ---------- LECTURE ----------

  /// Charge les vidéos et audios de la catégorie 'TeachingToolbox' pour la langue courante.
  static List<Media> loadTeachingToolboxVideos() {
    return _loadMediaFromCategory('TeachingToolbox');
  }

  /// Charge les vidéos et audios de la catégorie 'LatestAudioVideo' pour la langue courante.
  static List<Media> loadLatestMedias() {
    return _loadMediaFromCategory('LatestAudioVideo');
  }

  /// Helper générique pour charger les médias à partir d'une clé de catégorie.
  static List<Media> _loadMediaFromCategory(String categoryKey) {
    final List<Media> out = [];
    // Utiliser `symbol` directement est plus propre
    final String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    final categories = realm
        .all<Category>()
    // Utiliser une requête plus précise pour la clé et la langue
        .query("key == \$0 AND language == \$1", [categoryKey, languageSymbol]);

    // Optimisation: Utiliser `expand` sur la liste des catégories trouvées
    // Si la requête est bien indexée, Realm sera très rapide.
    // L'utilisation de `toSet` garantit l'unicité des `mediaKey`
    final mediaKeys = categories
        .expand((c) => c.media)
        .toSet();

    // Récupérer tous les MediaItem correspondant aux clés en une seule requête si possible,
    // ou itérer sur les clés. L'itération actuelle est moins performante mais plus simple
    // à maintenir dans Realm Dart. On garde la structure pour la compatibilité avec votre code,
    // mais on la simplifie.

    for (final mediaKey in mediaKeys) {
      final mediaItem = realm
          .all<MediaItem>()
          .query("naturalKey == \$0", [mediaKey])
          .firstOrNull;

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

  // ---------- IMPORT JSON -> REALM ----------

  /// Décode les données GZip JSON, parse et insère/met à jour les données dans Realm.
  static Future<void> convertMediaJsonToRealm(Uint8List bodyBytes, String serverEtag, String serverDate) async {
    // 1. Décodage et Parsing
    final decodedData = GZipCodec().decode(bodyBytes);
    final String jsonString = utf8.decode(decodedData);
    // Utiliser LineSplitter.split est correct si chaque ligne est un objet JSON.
    final List<dynamic> jsonList =
    LineSplitter.split(jsonString).map((line) => json.decode(line)).toList();

    // Déclaration des listes pour l'insertion
    final List<Language> languagesToAdd = [];
    final List<Category> categoriesToAdd = [];
    final List<MediaItem> mediaToAdd = [];
    String languageCode = '';

    // 2. Pré-parsing et collecte
    for (final entry in jsonList) {
      final type = entry['type'];
      final data = entry['o'];

      if (type == 'language') {
        languageCode = data['code'] ?? '';
        // Utiliser des valeurs par défaut pour les champs booléens et assurer
        // que tous les arguments sont non-nullables si les constructeurs l'exigent.
        languagesToAdd.add(Language(
          data['code'] ?? '',
          // Assurer que le code n'est pas nul (clé primaire)
          locale: data['locale'],
          vernacular: data['vernacular'],
          name: data['name'],
          isSignLanguage: data['isSignLanguage'] ?? false,
          isRtl: data['isRTL'] ?? false,
          eTag: serverEtag,
          lastModified: serverDate,
        ));
      } else if (type == 'category') {
        // Ajouter la vérification du languageCode si la catégorie dépend de la langue
        if (languageCode.isNotEmpty) {
          categoriesToAdd.add(_parseCategory(data, languageCode));
        }
      } else if (type == 'media-item') {
        // Ajouter la vérification du languageCode
        if (languageCode.isNotEmpty) {
          final item = _parseMediaItem(data, languageCode);
          if (item != null) {
            mediaToAdd.add(item);
          }
        }
      }
      // Ignorer les autres types pour le moment
    }

    // Si aucune langue n'a été trouvée, on ne peut pas faire la purge/insertion
    if (languageCode.isEmpty) {
      // Optionnel: logger une erreur
      return;
    }

    // 3. 🔥 Transaction : purge + réinsertion
    realm.write(() {
      // 1. Identification des objets liés à la langue
      final catsToPurge = realm.all<Category>().query("language == \$0", [languageCode]);
      final mediasToPurge = realm.all<MediaItem>().query("languageSymbol == \$0", [languageCode]);

      // 2. Collecte des images à supprimer
      // On collecte tous les objets Images référencés par les Category et MediaItem
      // que nous allons supprimer.
      final List<Images> imagesToDelete = [];

      // Collecter les images des catégories
      for (final cat in catsToPurge) {
        if (cat.persistedImages != null) {
          imagesToDelete.add(cat.persistedImages!);
        }
      }

      // Collecter les images des médias
      for (final media in mediasToPurge) {
        if (media.realmImages != null) {
          imagesToDelete.add(media.realmImages!);
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

  /// Parse les données JSON pour créer un objet [Category].
  static Category _parseCategory(Map<String, dynamic> data, String languageCode) {
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
    final List<Category> subcategories = [];

    // Utilisation de `try-catch` pour le parsing récursif
    for (final sub in rawSubs) {
      if (sub is Map<String, dynamic>) {
        try {
          subcategories.add(_parseCategory(sub, languageCode));
        } catch (e) {
          // Gérer les sous-catégories malformées
          // Optionnel: log d'erreur
        }
      }
    }

    // Assurer que les champs non-nullables dans le modèle Realm sont gérés.
    return Category(
      key: categoryKey,
      localizedName: data['name'],
      type: data['type'],
      media: media,
      subcategories: subcategories,
      persistedImages: _parseImages(data['images']),
      language: languageCode,
    );
  }

  /// Parse les données JSON pour créer un objet [MediaItem].
  static MediaItem? _parseMediaItem(Map<String, dynamic> data, String languageCode) {
    // 1. Traitement de la clé naturelle
    final String? rawNk = data['naturalKey'];
    if (rawNk == null || rawNk.isEmpty) return null;

    // Remplacement correct, s'assurant que `naturalKey` est non-null
    final String naturalKey = rawNk.replaceAll('univ', languageCode);

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

    // Assurer que les champs non-nullables dans le modèle Realm sont gérés.
    return MediaItem(
      // La clé primaire doit être `naturalKey` ou un ID unique
      // Assumer que le premier argument du constructeur est la clé primaire
      naturalKey,
      naturalKey: naturalKey,
      languageAgnosticNaturalKey: data['languageAgnosticNaturalKey'],
      type: type,
      primaryCategory: data['primaryCategory'],
      title: data['title'],
      firstPublished: data['firstPublished'],
      checksums: (data['checksums'] is List)
          ? List<String>.from(data['checksums'] as List)
          : const <String>[],
      duration: duration,
      pubSymbol: keyParts['pubSymbol'],
      // Utiliser le code de langue du keyParts s'il existe, sinon le code de la langue du fichier
      languageSymbol: keyParts['languageCode'] ?? languageCode,
      realmImages: _parseImages(data['images']),
      documentId: keyParts['docID'],
      issueDate: issueDate,
      track: keyParts['track'],
    );
  }

  /// Parse les données JSON pour créer un objet [Images].
  static Images? _parseImages(dynamic images) {
    if (images is! Map<String, dynamic>) return null;
    // Utiliser des variables locales pour simplifier le code
    final Map<String, dynamic> sqr = images['sqr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> cvr = images['cvr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> lsr = images['lsr'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> pnr = images['pnr'] as Map<String, dynamic>? ?? {};

    String? squareImageUrl = sqr['lg'] as String?;
    String? squareFullSizeImageUrl = sqr['xml'] as String?;
    String? wideImageUrl = lsr['md'] as String?;
    String? wideFullSizeImageUrl = lsr['xml'] as String?;
    String? extraWideFullSizeImageUrl = pnr['lg'] as String?;

    // Logique de fallback pour `squareImageUrl`
    squareImageUrl ??= cvr['lg'] as String?;

    // Retourner null si aucune image n'a pu être trouvée
    if (squareImageUrl == null &&
        squareFullSizeImageUrl == null &&
        wideImageUrl == null &&
        wideFullSizeImageUrl == null &&
        extraWideFullSizeImageUrl == null) {
      return null;
    }

    // Assurer que les champs non-nullables sont gérés dans le constructeur
    return Images(
      squareImageUrl: squareImageUrl,
      squareFullSizeImageUrl: squareFullSizeImageUrl,
      wideImageUrl: wideImageUrl,
      wideFullSizeImageUrl: wideFullSizeImageUrl,
      extraWideFullSizeImageUrl: extraWideFullSizeImageUrl,
    );
  }
}