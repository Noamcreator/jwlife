import 'package:flutter/material.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:realm/realm.dart';
// Importations manquantes dans l'extrait original, mais nécessaires pour la logique:
// Elles doivent être dans votre projet. Ici, on assume qu'elles existent.
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/app/services/settings_service.dart';

class LibraryPageModel with ChangeNotifier {
  String _language = '';
  List<PublicationCategory> _catalogCategories = [];
  Category? _video;
  Category? _audio;
  bool _isMediaLoading = true;

  // --- Getters publics ---
  String get language => _language;
  List<PublicationCategory> get catalogCategories => _catalogCategories;
  Category? get video => _video;
  Category? get audio => _audio;
  bool get isMediaLoading => _isMediaLoading;

  // Méthode pour obtenir le nombre d'onglets (logique)
  int get tabsLength {
    int length = 0;
    if (_catalogCategories.isNotEmpty) length++; // Publications
    if (_isMediaLoading || _video != null) length++; // Vidéos
    if (_isMediaLoading || _audio != null) length++; // Audios
    length++; // Téléchargements
    length++; // Mises à jour en attente
    return length;
  }

  // J'ai conservé la fonction d'origine et j'ai corrigé sa logique :
  void refreshLibraryCategories() {
    _setLanguage();
    _getCategories();

    // Force la mise à jour des catégories du catalogue après avoir mis à jour les catégories Realm.
    // Cela doit notifier le changement.
    PubCatalog.updateCatalogCategories();
  }

  void refreshCatalogCategories(List<PublicationCategory> categories) {
    _catalogCategories = categories;
    notifyListeners(); // Notifie le widget des changements de l'état
  }

  void _setLanguage() {
    _language = JwLifeSettings().currentLanguage.vernacular;
    notifyListeners();
  }

  void _getCategories() {
    _isMediaLoading = true;
    notifyListeners(); // Affiche l'état de chargement

    // Les configurations Realm
    final config = Configuration.local([
      MediaItem.schema,
      Language.schema,
      Images.schema,
      Category.schema
    ]);
    String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    final Realm realm = Realm(config);
    final videoResults = realm
        .all<Category>()
        .query("key == 'VideoOnDemand' AND language == '$languageSymbol'");
    final audioResults =
    realm.all<Category>().query("key == 'Audio' AND language == '$languageSymbol'");

    _video = videoResults.isNotEmpty ? videoResults.first : null;
    _audio = audioResults.isNotEmpty ? audioResults.first : null;
    _isMediaLoading = false;

    notifyListeners(); // Notifie le widget une fois les catégories chargées
  }
}