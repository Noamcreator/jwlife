// audio_items_model.dart (Le ViewModel / Controller)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import 'package:realm/realm.dart';
// Imports des Modèles de données (Realm et classes métier)
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';

class AudioItemsModel extends ChangeNotifier {
  final RealmCategory initialCategory;

  // --- Propriétés (État) ---
  RealmCategory? _category;
  RealmCategory get category => _category ?? initialCategory;

  String _categoryName = '';
  String get categoryName => _categoryName;

  String _language = '';
  String get language => _language;

  String? _selectedLanguageSymbol;
  String get selectedLanguageSymbol => _selectedLanguageSymbol ?? initialCategory.languageSymbol!;

  List<Audio> _allAudios = [];
  List<Audio> get allAudios => _allAudios; // Liste complète

  List<Audio> _filteredAudios = [];
  List<Audio> get filteredAudios => _filteredAudios; // Liste affichée

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Constructeur
  AudioItemsModel({required this.initialCategory});

  // --- Logique de Chargement et de Données ---

  void loadItems({String? symbol}) async {
    symbol ??= initialCategory.languageSymbol;
    _selectedLanguageSymbol = symbol;

    RealmLibrary.realm.refresh();
    RealmLanguage? lang = RealmLibrary.realm.all<RealmLanguage>().query("Symbol == '$symbol'").firstOrNull;
    if(lang == null) return;

    // Récupérer la catégorie mise à jour (peut-être dans une autre langue)
    _category = RealmLibrary.realm.all<RealmCategory>().query("Key == '${initialCategory.key}' AND LanguageSymbol == '$symbol'").firstOrNull ?? initialCategory;

    _categoryName = _category?.name ?? initialCategory.name!;
    _language = lang.vernacular!;

    // Conversion des clés média en objets Audio
    _allAudios = _category!.media.map((naturalKey) {
      return Audio.fromJson(mediaItem: RealmLibrary.getMediaItemByNaturalKey(naturalKey, lang.symbol!));
    }).toList();

    _filteredAudios = List.from(_allAudios);

    notifyListeners();
  }

  void filterAudios(String query) {
    if (query.isEmpty) {
      _filteredAudios = List.from(_allAudios);
    } else {
      final normalizedQuery = removeDiacritics(query).toLowerCase();

      _filteredAudios = _allAudios.where((mediaItem) {
        final normalizedTitle = removeDiacritics(mediaItem.title).toLowerCase();
        return normalizedTitle.contains(normalizedQuery);
      }).toList();
    }
    notifyListeners();
  }

  // --- Logique de l'UI (État de recherche) ---

  void setIsSearching(bool value) {
    _isSearching = value;
    if (!value) {
      filterAudios('');
    }
    notifyListeners();
  }

  void cancelSearch() {
    _isSearching = false;
    filterAudios('');
    notifyListeners();
  }

  // --- Logique de Lecture Audio ---

  void play(int index) async {
    // La méthode _allAudios est la liste complète (non filtrée) pour le player
    JwLifeApp.audioPlayer.playAudios(category, _allAudios, id: index);
  }

  void playAll() async {
    JwLifeApp.audioPlayer.playAudios(category, _allAudios);
  }

  void playRandom() async {
    if (_allAudios.isEmpty) return;
    final randomIndex = Random().nextInt(_allAudios.length);
    JwLifeApp.audioPlayer.playAudios(category, _allAudios, id: randomIndex, randomMode: true);
  }

  // void playRandomLanguage() async {
  //   // Logique à implémenter ici
  // }

  // --- Logique de service (Changement de Langue) ---

  void showLanguageSelection(BuildContext context) async {
    final language = await showLanguageDialog(context, selectedLanguageSymbol: _selectedLanguageSymbol);
    if (language != null) {
      final newSymbol = language['Symbol'] as String;

      // 1. Charger les nouveaux éléments
      loadItems(symbol: newSymbol);

      // 2. Vérifier et lancer la mise à jour si nécessaire
      if(await Api.isLibraryUpdateAvailable(symbol: newSymbol)) {
        Api.updateLibrary(newSymbol).then((_) {
          // Recharger les éléments après la mise à jour
          loadItems(symbol: newSymbol);
        });
      }
    }
  }
}