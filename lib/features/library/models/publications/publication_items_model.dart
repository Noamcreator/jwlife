import 'package:flutter/material.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:diacritic/diacritic.dart';

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

  // Critère de tri actuel, 'title' par défaut.
  String _currentSortCriterion = 'title_asc';

  // Paramètres injectés à l'initialisation
  final PublicationCategory category;
  final int? year;

  // Attribut factice/générique pour le regroupement lors du tri par année (constant)
  static final genericAttribute = PublicationAttribute.all.first;

  PublicationsItemsViewModel({required this.category, this.year});

  // --- Getters publics ---
  String get language => _language;
  String get selectedLanguageSymbol => _selectedLanguageSymbol;
  Map<PublicationAttribute, List<Publication>> get filteredPublications => _filteredPublications;
  bool get isSearching => _isSearching;
  bool get isLoading => _isLoading;
  String get currentSortCriterion => _currentSortCriterion;

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

    // Ajout des publications téléchargées
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

    // Applique le tri par défaut/actuel après le chargement
    _applySorting(_filteredPublications);

    _language = mepsLanguage?['VernacularName'] ?? JwLifeSettings().currentLanguage.vernacular;

    _isLoading = false;
    notifyListeners(); // Rafraîchit l'interface
  }

  void filterPublications(String query) {
    if (query.isEmpty) {
      // Si la recherche est vide, on repart de la structure complète originale
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

    // Applique le tri actuel après le filtrage
    _applySorting(_filteredPublications);
    notifyListeners(); // Rafraîchit l'interface
  }

  /// Change le critère de tri et réapplique le tri à la liste filtrée.
  void sortPublications(String newCriterion) {
    if (_currentSortCriterion == newCriterion) {
      return;
    }

    // --- Logique de restauration de la structure après un tri 'year' ---
    // Vérifie si la carte est actuellement "aplatie" (tri par année)
    bool wasFlattened = _filteredPublications.length == 1 && _filteredPublications.containsKey(genericAttribute);

    // Si on change pour un critère qui n'est pas 'year' ET que la liste était aplatie
    if (newCriterion != 'year' && wasFlattened) {
      final List<Publication> flattenedList = _filteredPublications[genericAttribute]!;

      // Restaurer la structure de _filteredPublications en fonction des attributs
      _filteredPublications = {};

      // Reconstruction des groupes d'attributs pour les publications actuellement affichées
      for (var pub in flattenedList) {
        _filteredPublications.putIfAbsent(pub.attribute, () => []).add(pub);
      }
    }
    // -----------------------------------------------------------------

    _currentSortCriterion = newCriterion;
    _applySorting(_filteredPublications);
    notifyListeners();
  }

  /// Logique de tri générique appliquée après le chargement, le filtrage ou le changement de critère.
  void _applySorting(Map<PublicationAttribute, List<Publication>> mapToSort) {
    String field = '';
    String order = ''; // 'asc' ou 'desc'

    final parts = _currentSortCriterion.split('_');
    if (parts.length == 2) {
      field = parts[0];
      order = parts[1];
    } else {
      // Cas de critère non-standard (ex: tri interne par défaut 'issueTagNumber')
      field = _currentSortCriterion;
      order = 'asc'; // Ordre par défaut si non spécifié
    }

    // --- 2. Tri par Année (Logique de Fusion) ---
    if (field == 'year') {
      // ... (Le code de tri par année est correct)
      List<Publication> allPublications = mapToSort.values.expand((list) => list).toList();
      bool isIssueTagNumber = allPublications.every((pub) => pub.issueTagNumber != 0);

      allPublications.sort((a, b) {
        int comparison;
        if(isIssueTagNumber) {
          comparison = a.issueTagNumber.compareTo(b.issueTagNumber);
        }
        else {
          comparison = a.year.compareTo(b.year);
        }
        // Logique correcte : Inverser si 'desc', garder si 'asc'
        return isIssueTagNumber ? ((order == 'desc') ? comparison : -comparison) : (order == 'desc') ? -comparison : comparison;
      });
      mapToSort.clear();
      mapToSort[genericAttribute] = allPublications;
      return;
    }

    if(field == 'symbol') {
      List<Publication> allPublications = mapToSort.values.expand((list) => list).toList();

      allPublications.sort((a, b) {
        final comparison = a.keySymbol.compareTo(b.keySymbol);
        return order == 'desc' ? -comparison : comparison;
      });
      mapToSort.clear();
      mapToSort[genericAttribute] = allPublications;
      return;
    }

    // --- 3. Tri par Attribut / Tri par défaut ---

    // ... (Le bloc de tri 'issueTagNumber' reste inchangé)
    if (category.hasYears) {
      mapToSort.forEach((attribute, publicationsFromAttribute) {
        publicationsFromAttribute.sort((a, b) => a.issueTagNumber.compareTo(b.issueTagNumber));
      });
      return;
    }

    // Tri par Attribut (Titre, Symbole, Année interne)
    mapToSort.forEach((attribute, publicationsFromAttribute) {
      bool shouldSortByYearInternal = attribute.id != -1 && attribute.order == 1;

      publicationsFromAttribute.sort((a, b) {
        if (shouldSortByYearInternal) {
          // Tri primaire : Année (descendant)
          final int primaryComparison = b.year.compareTo(a.year);

          // Tri secondaire : issueTagNumber (descendant) si les années sont égales
          if (primaryComparison == 0) {
            return a.issueTagNumber.compareTo(b.issueTagNumber);
          }

          // Retourner le résultat du tri primaire si les années sont différentes
          return primaryComparison;
        }

        // --- Logique de Tri par Critère Utilisateur ---

        final int comparison;

        // Tri par défaut (Titre)
        String titleA = removeDiacritics(a.title).toLowerCase();
        String titleB = removeDiacritics(b.title).toLowerCase();

        bool isSpecialA = RegExp(r'^[^a-zA-Z]').hasMatch(titleA);
        bool isSpecialB = RegExp(r'^[^a-zA-Z]').hasMatch(titleB);

        // Comparaison finale
        comparison = isSpecialA == isSpecialB
            ? titleA.compareTo(titleB)
            : (isSpecialA ? -1 : 1);

        // 🎯 CORRECTION: Appliquer l'ordre (ascendant ou descendant) en se basant uniquement sur 'order'
        return (order == 'asc')
            ? comparison
            : -comparison;
      });
    });
  }
}