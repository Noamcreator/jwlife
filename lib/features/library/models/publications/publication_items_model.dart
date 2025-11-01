import 'package:flutter/material.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:diacritic/diacritic.dart'; // <<< Importation de la librairie diacritic

class PublicationsItemsViewModel with ChangeNotifier {
  // --- État ---
  String _language = '';
  String _selectedLanguageSymbol = '';
  // Liste complète des publications, telle que chargée depuis la base de données
  Map<PublicationAttribute, List<Publication>> _publications = {};
  // La carte des publications par attribut est utilisée pour l'affichage filtré
  Map<PublicationAttribute, List<Publication>> _filteredPublications = {};
  bool _isSearching = false;

  bool _isLoading = true;

  // Paramètres injectés à l'initialisation
  final PublicationCategory category;
  final int? year;

  PublicationsItemsViewModel({required this.category, this.year});

  // --- Getters publics ---
  String get language => _language;
  String get selectedLanguageSymbol => _selectedLanguageSymbol;
  Map<PublicationAttribute, List<Publication>> get filteredPublications => _filteredPublications;
  bool get isSearching => _isSearching;
  bool get isLoading => _isLoading;

  // --- Actions/Mutations d'État ---

  void setIsSearching(bool value) {
    _isSearching = value;
    notifyListeners();
  }

  // --- LOGIQUE DE DONNÉES ---

  Future<void> loadItems({Map<String, dynamic>? mepsLanguage}) async {
    Map<PublicationAttribute, List<Publication>> publications;

    int mepsLanguageId = mepsLanguage?['LanguageId'] ?? JwLifeSettings().currentLanguage.id;
    _selectedLanguageSymbol = mepsLanguage?['Symbol'] ?? JwLifeSettings().currentLanguage.symbol;

    if (year != null) {
      publications = await PubCatalog.getPublicationsFromCategory(
          category.id,
          year: year,
          mepsLanguageId: mepsLanguageId
      );
    }
    else {
      publications = await PubCatalog.getPublicationsFromCategory(
          category.id,
          mepsLanguageId: mepsLanguageId
      );
    }

    // Ajout des publications téléchargées qui ne sont pas dans le catalogue (logique complexe déplacée ici)
    for (var pub in PublicationRepository().getAllDownloadedPublications()) {
      if (pub.category.id == category.id && pub.mepsLanguage.id == mepsLanguageId && (year == null || pub.year == year) && !publications.values.expand((list) => list).any((p) => p.keySymbol == pub.keySymbol && p.issueTagNumber == pub.issueTagNumber)) {
        publications.putIfAbsent(pub.attribute, () => []).add(pub);
      }
    }

    // Tri des attributs
    var sortedEntries = publications.keys.toList()..sort((a, b) => a.id.compareTo(b.id));
    _publications = Map.fromEntries(sortedEntries.map((key) => MapEntry(key, publications[key]!)));

    // Initialise la liste filtrée avec toutes les publications
    _filteredPublications = Map.from(_publications);
    _sortPublicationsInMap();

    _language = mepsLanguage?['VernacularName'] ?? JwLifeSettings().currentLanguage.vernacular;

    _isLoading = false;
    notifyListeners(); // Rafraîchit l'interface
  }

  void filterPublications(String query) {
    if (query.isEmpty) {
      _filteredPublications = Map.from(_publications);
    } else {
      // Normalisation de la requête pour la recherche (sans diacritiques et minuscule)
      final normalizedQuery = removeDiacritics(query).toLowerCase();

      _filteredPublications = {}; // Réinitialise la carte filtrée
      _publications.forEach((attribute, publicationList) {
        final filteredList = publicationList.where((pub) {
          // Normalisation du titre et du symbole pour la comparaison
          final normalizedTitle = removeDiacritics(pub.title).toLowerCase();
          final normalizedKeySymbol = removeDiacritics(pub.keySymbol).toLowerCase();

          return normalizedTitle.contains(normalizedQuery) || normalizedKeySymbol.contains(normalizedQuery);
        }).toList();

        if (filteredList.isNotEmpty) {
          _filteredPublications[attribute] = filteredList;
        }
      });
    }
    _sortPublicationsInMap();
    notifyListeners(); // Rafraîchit l'interface
  }

  // Logique de tri (privée car interne au modèle)
  void _sortPublicationsInMap() {
    _filteredPublications.forEach((attribute, publicationsFromAttribute) {
      if (category.hasYears) {
        publicationsFromAttribute.sort((a, b) => a.issueTagNumber.compareTo(b.issueTagNumber));
      }
      else {
        bool shouldSortByYear = attribute.id != -1 && attribute.order == 1;

        if (shouldSortByYear) {
          publicationsFromAttribute.sort((a, b) => b.year.compareTo(a.year));
        }
        else {
          publicationsFromAttribute.sort((a, b) {
            // Normalisation pour un tri insensible à la casse et aux diacritiques
            String titleA = removeDiacritics(a.title).toLowerCase();
            String titleB = removeDiacritics(b.title).toLowerCase();

            // La logique de tri pour les caractères spéciaux au début est conservée.
            bool isSpecialA = RegExp(r'^[^a-zA-Z]').hasMatch(titleA);
            bool isSpecialB = RegExp(r'^[^a-zA-Z]').hasMatch(titleB);

            return isSpecialA == isSpecialB ? titleA.compareTo(titleB) : (isSpecialA ? -1 : 1);
          });
        }
      }
    });
  }
}