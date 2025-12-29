import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
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
  Future<List<Media>> loadTeachingToolboxVideosAsync() async {
    final languageSymbol = JwLifeSettings.instance.currentLanguage.value.symbol;

    // Récupérer juste les données serializables pour l'isolate
    final categoriesData = realm.all<RealmCategory>()
        .query("Key == \$0 AND LanguageSymbol == \$1", ['TeachingToolbox', languageSymbol])
        .map((c) => c.media) // juste les clés
        .expand((e) => e)
        .toList();

    final mediaData = categoriesData
        .map((key) {
      final item = realm.all<RealmMediaItem>().query("NaturalKey == \$0", [key]).firstOrNull;
      if (item == null) return null;
      return {
        'type': item.type,
        'naturalKey': item.naturalKey,
        'data': item, // tu peux sérialiser ce qui est nécessaire
      };
    })
        .whereType<Map<String, dynamic>>()
        .toList();

    // Déplacer la construction des Media dans un isolate
    return compute(_createMediaList, mediaData);
  }

// Fonction top-level pour compute
  List<Media> _createMediaList(List<Map<String, dynamic>> mediaData) {
    final out = <Media>[];
    for (final item in mediaData) {
      final t = (item['type'] ?? '').toUpperCase();
      if (t == 'VIDEO') out.add(Video.fromJson(mediaItem: item['data']));
      else if (t == 'AUDIO') out.add(Audio.fromJson(mediaItem: item['data']));
    }
    return out;
  }

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

  // ------------------ TOP-LEVEL FUNCTION POUR ISOLATE ------------------

  /// Transforme le bodyBytes GZip JSON en Map serializable pour Realm
  static Map<String, dynamic> _parseToPayload(Uint8List bodyBytes) {
    final decoded = GZipCodec().decode(bodyBytes);
    final jsonString = utf8.decode(decoded);

    final lines = LineSplitter.split(jsonString).map((line) => json.decode(line) as Map<String, dynamic>).toList();

    final List<Map<String, dynamic>> languages = [];
    final List<Map<String, dynamic>> categories = [];
    final List<Map<String, dynamic>> media = [];

    for (final entry in lines) {
      final type = entry['type'];
      final data = entry['o'];
      if (type == 'language') languages.add(data);
      if (type == 'category') categories.add(data);
      if (type == 'media-item') media.add(data);
    }

    return {
      'languages': languages,
      'categories': categories,
      'media': media,
    };
  }


  static Future<void> convertMediaJsonToRealm(Uint8List bodyBytes, String serverEtag, String serverDate) async {
    // Parsing lourd dans un isolate
    final payloadMap = await compute(RealmLibrary._parseToPayload, bodyBytes);

    final List<Map<String, dynamic>> languagesData = List<Map<String, dynamic>>.from(payloadMap['languages']);
    final List<Map<String, dynamic>> categoriesData = List<Map<String, dynamic>>.from(payloadMap['categories']);
    final List<Map<String, dynamic>> mediaData = List<Map<String, dynamic>>.from(payloadMap['media']);

    if (languagesData.isEmpty) return;

    final languageSymbol = languagesData.first['code'] ?? '';

    // Préparer objets Realm sur le thread principal
    final languagesToAdd = languagesData.map((data) => RealmLanguage(
      data['code'] ?? '',
      locale: data['locale'],
      vernacular: data['vernacular'],
      name: data['name'],
      isLanguagePair: data['isLangPair'] ?? false,
      isSignLanguage: data['isSignLanguage'] ?? false,
      isRtl: data['isRTL'] ?? false,
      eTag: serverEtag,
      lastModified: serverDate,
    )).toList();

    final categoriesToAdd = categoriesData.map((data) => _parseCategory(data, languageSymbol)).toList();
    final mediaToAdd = mediaData.map((data) => _parseMediaItem(data, languageSymbol)).whereType<RealmMediaItem>().toList();

    // 🔥 Transaction Realm
    realm.write(() {
      final catsToPurge = realm.all<RealmCategory>().query("LanguageSymbol == \$0", [languageSymbol]);
      final mediasToPurge = realm.all<RealmMediaItem>().query("LanguageSymbol == \$0", [languageSymbol]);

      final List<RealmImages> imagesToDelete = [
        for (final cat in catsToPurge) if (cat.images != null) cat.images!,
        for (final media in mediasToPurge) if (media.images != null) media.images!,
      ];

      realm.deleteMany(imagesToDelete);
      realm.deleteMany(catsToPurge);
      realm.deleteMany(mediasToPurge);

      realm.addAll(languagesToAdd, update: true);
      realm.addAll(categoriesToAdd);
      realm.addAll(mediaToAdd);
    });
  }

  // ------------------ HELPERS ------------------

  static RealmCategory _parseCategory(Map<String, dynamic> data, String? languageSymbol) {
    final String categoryKey = data['key']?.toString() ?? '';
    if (categoryKey.isEmpty) throw Exception('Category key missing');

    final List<String> media = (data['media'] is List) ? List<String>.from(data['media'] as List).toSet().toList() : <String>[];
    final List<dynamic> rawSubs = data['subcategories'] as List? ?? const [];
    final List<RealmCategory> subcategories = [];

    for (final sub in rawSubs) {
      if (sub is Map<String, dynamic>) {
        try {
          subcategories.add(_parseCategory(sub, languageSymbol));
        } catch (_) {}
      }
    }

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

  static RealmMediaItem? _parseMediaItem(Map<String, dynamic> data, String? languageSymbol) {
    final String? rawNk = data['naturalKey'];
    if (rawNk == null || rawNk.isEmpty) return null;

    final String naturalKey = rawNk;
    final String compoundKey = '${languageSymbol ?? ''}-$rawNk';

    Map<String, dynamic> keyParts = (data['keyParts'] is Map<String, dynamic>) ? data['keyParts'] as Map<String, dynamic> : {};
    String? type;
    final f = keyParts['formatCode']?.toString().toUpperCase();
    if (f == 'VIDEO' || f == 'AUDIO') type = f;
    if (type == null) return null;

    double? duration;
    final d = data['duration'];
    if (d is num) duration = d.toDouble();
    else if (d is String) duration = double.tryParse(d);

    int? issueDate;
    final issue = keyParts['issueDate'];
    if (issue is int) issueDate = issue;
    else if (issue is String) issueDate = int.tryParse(issue);

    String? remoteType;
    final remote = keyParts['remoteType'];
    if (remote is String) remoteType = remote;

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

  static RealmImages? _parseImages(dynamic images, bool isCategory) {
    if (images is! Map<String, dynamic>) return null;

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

    squareImageUrl ??= cvr['xs'] as String?;
    squareFullSizeImageUrl ??= cvr['lg'] as String?;

    if (squareImageUrl == null && squareFullSizeImageUrl == null && wideImageUrl == null &&
        wideFullSizeImageUrl == null && extraWideImageUrl == null && extraWideFullSizeImageUrl == null) return null;

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