import 'package:flutter/material.dart';
import 'package:realm/realm.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/video.dart';

import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_video.dart';

class VideoItemsModel extends ChangeNotifier {
  final RealmCategory initialCategory;

  late RealmCategory? _category;
  RealmCategory? get category => _category;

  late RealmLanguage _language;
  RealmLanguage get language => _language;

  List<RealmCategory> _subcategories = [];
  // Contient la liste complète non filtrée

  List<RealmCategory> _filteredVideos = [];
  List<RealmCategory> get filteredVideos => _filteredVideos; // La liste affichée

  final Map<String, List<String>> _filteredMediaMap = {};
  Map<String, List<String>> get filteredMediaMap => _filteredMediaMap;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Constructeur
  VideoItemsModel({required this.initialCategory});

  // --- Méthodes de Gestion de l'État ---

  void setIsSearching(bool value) {
    _isSearching = value;
    if (!value) {
      filterVideos(''); // Réinitialise le filtre en quittant la recherche
    }
    notifyListeners();
  }

  void cancelSearch() {
    _isSearching = false;
    filterVideos('');
    notifyListeners();
  }

  // --- Logique de Données / Métier ---

  Media getMediaFromKey(String naturalKey) {
    // Accès à l'objet Realm MediaItem

    final mediaItem = RealmLibrary.getMediaItemByNaturalKey(naturalKey, initialCategory.languageSymbol!);

    // Convertit le modèle Realm en modèle métier (Audio/Video)
    return mediaItem.type == 'AUDIO' ? Audio.fromJson(mediaItem: mediaItem) : Video.fromJson(mediaItem: mediaItem);
  }

  void loadItems({String? symbol}) async {
    symbol ??= initialCategory.languageSymbol;

    RealmLibrary.realm.refresh();
    // Récupère les informations sur la langue
    RealmLanguage? lang = RealmLibrary.realm.all<RealmLanguage>().query("Symbol == '$symbol'").firstOrNull;
    if(lang == null) return;

    // Récupère la catégorie spécifique à la langue
    _category = RealmLibrary.realm.all<RealmCategory>().query("Key == '${initialCategory.key}' AND LanguageSymbol == '$symbol'").firstOrNull;

    _language = lang;

    // Utilisation de .toList() pour la liste des sous-catégories
    _subcategories = _category?.subCategories.toList() ?? [];
    _filteredVideos = _subcategories;

    notifyListeners();
  }

  void filterVideos(String query) {
    _filteredMediaMap.clear();

    if (query.isEmpty) {
      _filteredVideos = _subcategories;
    } else {
      final normalizedQuery = normalize(query);
      _filteredVideos = [];

      // Filtre les médias dans chaque sous-catégorie
      for (var subCategory in _subcategories) {
        final filteredNaturalKeys = subCategory.media.where((naturalKey) {
          try {
            final mediaItem = RealmLibrary.getMediaItemByNaturalKey(naturalKey, subCategory.languageSymbol!);

            if (mediaItem.title == null) return false;

            final normalizedTitle = normalize(mediaItem.title!);
            return normalizedTitle.contains(normalizedQuery);
          } catch (_) {
            return false;
          }
        }).toList();

        // Ajoute la sous-catégorie si elle contient des médias filtrés
        if (filteredNaturalKeys.isNotEmpty) {
          _filteredMediaMap[subCategory.key!] = filteredNaturalKeys;
          _filteredVideos.add(subCategory);
        }
      }
    }
    notifyListeners();
  }

  Future<void> downloadAllVideo(BuildContext context, List<String> mediaKeys) async {
    // Récupère les objets Media dans l'ordre original
    List<Media> medias = getAllMedias(context, mediaKeys, shuffle: false);

    // Correction 1 : Déclaration d'une List de Map<String, String> (la syntaxe correcte)
    List<Map<String, String>> resolutions = [
      {'label': '240p'},
      {'label': '360p'},
      {'label': '480p'},
      {'label': '720p'},
    ];

    int? resolutionIndex = await showVideoDownloadDialog(context, resolutions);

    if (resolutionIndex == null) return;

    // Correction 3 : Utiliser l'index de résolution choisi pour le téléchargement.
    for (Media media in medias) {
      media.download(context, resolution: resolutionIndex);
    }
  }

  List<Media> getAllMedias(BuildContext context, List<String> mediaKeys, {bool shuffle = false}) {
    List<String> processingKeys = List.from(mediaKeys);
    if (shuffle) {
      processingKeys.shuffle(); // Mélange les clés si demandé
    }

    List<Media> sequentialMedias = [];
    // Convertit chaque clé en objet Media
    for (String mediaKey in processingKeys) {
      sequentialMedias.add(getMediaFromKey(mediaKey));
    }
    return sequentialMedias;
  }

  // --- Logique d'Interaction (Play Media) ---

  void _playMedia(BuildContext context, List<Media> medias, {bool shuffle = false}) {
    if (medias.isNotEmpty) {
      // Lance le lecteur média
      medias.first.showPlayer(context, medias: medias);
    }
  }

  void playMediaSequentially(BuildContext context, List<String> mediaKeys) {
    // Récupère les objets Media dans l'ordre original
    List<Media> medias = getAllMedias(context, mediaKeys, shuffle: false);
    _playMedia(context, medias, shuffle: false);
  }

  void playMediaRandomly(BuildContext context, List<String> mediaKeys) {
    // Récupère les objets Media en mode aléatoire
    List<Media> medias = getAllMedias(context, mediaKeys, shuffle: true);
    _playMedia(context, medias, shuffle: true);
  }

  void playAllMediaRandomly(BuildContext context) {
    List<String> allMediaKeys = [];
    // Collecte toutes les clés de médias de toutes les sous-catégories
    for (RealmCategory category in _subcategories) {
      allMediaKeys.addAll(category.media);
    }

    // Récupère et lance tous les médias en mode aléatoire
    List<Media> allMedias = getAllMedias(context, allMediaKeys, shuffle: true);
    _playMedia(context, allMedias, shuffle: true);
  }

  // --- Logique de service (Changement de Langue) ---
  void showLanguageSelection(BuildContext context) async {
    // Affiche la boîte de dialogue de sélection de langue
    final language = await showLanguageDialog(context, firstSelectedLanguage: _language.symbol);
    if (language != null) {
      final languageSymbol = language['Symbol'] as String;
      if (languageSymbol != _language.symbol) {
        loadItems(symbol: languageSymbol); // Recharge les données dans la nouvelle langue

        if (await Api.isLibraryUpdateAvailable(languageSymbol)) {
          Api.updateLibrary(languageSymbol).then((_) {
            loadItems(symbol: languageSymbol);
          });
        }
      }
    }
  }
}