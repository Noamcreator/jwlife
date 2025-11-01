import 'package:flutter/material.dart';
import 'package:realm/realm.dart';
import 'package:diacritic/diacritic.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/video.dart';

import '../../../../core/utils/utils_video.dart';

class VideoItemsModel extends ChangeNotifier {
  final Category initialCategory;

  // --- Propriétés (État de la Vue) ---
  String _categoryName = '';
  String get categoryName => _categoryName;

  String _language = '';
  String get language => _language;

  String? _selectedLanguageSymbol = '';
  String get selectedLanguageSymbol => _selectedLanguageSymbol ?? initialCategory.language!;

  List<Category> _subcategories = [];
  // Contient la liste complète non filtrée

  List<Category> _filteredVideos = [];
  List<Category> get filteredVideos => _filteredVideos; // La liste affichée

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

  Media getMediaFromKey(String mediaKey) {
    // Accès à l'objet Realm MediaItem
    final mediaItem = RealmLibrary.realm
        .all<MediaItem>()
        .query("naturalKey == '$mediaKey'")
        .first;

    // Convertit le modèle Realm en modèle métier (Audio/Video)
    return mediaItem.type == 'AUDIO'
        ? Audio.fromJson(mediaItem: mediaItem)
        : Video.fromJson(mediaItem: mediaItem);
  }

  void loadItems({String? symbol}) async {
    symbol ??= initialCategory.language;
    _selectedLanguageSymbol = symbol;

    RealmLibrary.realm.refresh();
    // Récupère les informations sur la langue
    Language? lang = RealmLibrary.realm.all<Language>().query("symbol == '$symbol'").firstOrNull;
    if(lang == null) return;

    // Récupère la catégorie spécifique à la langue
    Category? category = RealmLibrary.realm
        .all<Category>()
        .query("key == '${initialCategory.key}' AND language == '$symbol'")
        .firstOrNull;

    _categoryName = category?.localizedName ?? initialCategory.localizedName!;
    _language = lang.vernacular!;
    // Utilisation de .toList() pour la liste des sous-catégories
    _subcategories = category?.subcategories.toList() ?? [];
    _filteredVideos = _subcategories;

    notifyListeners();
  }

  void filterVideos(String query) {
    _filteredMediaMap.clear();

    if (query.isEmpty) {
      _filteredVideos = _subcategories;
    } else {
      final normalizedQuery = removeDiacritics(query).toLowerCase();
      _filteredVideos = [];

      // Filtre les médias dans chaque sous-catégorie
      for (var subCategory in _subcategories) {
        final filteredMediaKeys = subCategory.media.where((mediaKey) {
          try {
            final mediaItem = RealmLibrary.realm
                .all<MediaItem>()
                .query("naturalKey == '$mediaKey'")
                .first;

            if (mediaItem.title == null) return false;

            final normalizedTitle = removeDiacritics(mediaItem.title!).toLowerCase();
            return normalizedTitle.contains(normalizedQuery);
          } catch (_) {
            return false;
          }
        }).toList();

        // Ajoute la sous-catégorie si elle contient des médias filtrés
        if (filteredMediaKeys.isNotEmpty) {
          _filteredMediaMap[subCategory.key!] = filteredMediaKeys;
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
    for (Category category in _subcategories) {
      allMediaKeys.addAll(category.media);
    }

    // Récupère et lance tous les médias en mode aléatoire
    List<Media> allMedias = getAllMedias(context, allMediaKeys, shuffle: true);
    _playMedia(context, allMedias, shuffle: true);
  }

  // --- Logique de service (Changement de Langue) ---
  void showLanguageSelection(BuildContext context) async {
    // Affiche la boîte de dialogue de sélection de langue
    final language = await showLanguageDialog(context, selectedLanguageSymbol: _selectedLanguageSymbol);
    if (language != null) {
      final newSymbol = language['Symbol'] as String;
      loadItems(symbol: newSymbol); // Recharge les données dans la nouvelle langue

      if (await Api.isLibraryUpdateAvailable(symbol: newSymbol)) {
        // Déclenche la mise à jour de la librairie si nécessaire
        Api.updateLibrary(newSymbol).then((_) {
          loadItems(symbol: newSymbol); // Recharge après la mise à jour
        });
      }
    }
  }
}