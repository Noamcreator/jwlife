import 'package:flutter/material.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:diacritic/diacritic.dart';

class PublicationsItemsViewModel with ChangeNotifier {
  // --- État ---
  MepsLanguage _mepsLanguage = JwLifeSettings.instance.currentLanguage.value;
  String _selectedLanguageSymbol = '';
  // *** MODIFICATION DE LA STRUCTURE DE LA MAP : Clé simple (PublicationAttribute) ***
  Map<PublicationAttribute, List<Publication>> _publications = {};
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
  MepsLanguage get mepsLanguage => _mepsLanguage;
  String get selectedLanguageSymbol => _selectedLanguageSymbol;
  // *** MODIFICATION DU GETTER ***
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
    // *** MODIFICATION : Map locale utilise la clé simple ***
    Map<PublicationAttribute, List<Publication>> publications = {};

    int mepsLanguageId = mepsLanguage?['LanguageId'] ?? JwLifeSettings.instance.currentLanguage.value.id;
    _selectedLanguageSymbol = mepsLanguage?['Symbol'] ?? JwLifeSettings.instance.currentLanguage.value.symbol;

    // Charger les publications existantes (la sortie de PubCatalog devra être ajustée côté Base de données)
    Map<List<PublicationAttribute>, List<Publication>> rawPublications = {};

    if (year != null) {
      rawPublications = await CatalogDb.instance.getPublicationsFromCategory(
          category.id,
          year: year,
          mepsLanguageId: mepsLanguageId
      );
    }
    else {
      rawPublications = await CatalogDb.instance.getPublicationsFromCategory(
          category.id,
          mepsLanguageId: mepsLanguageId
      );
    }

    // Regrouper les publications brutes par leur premier attribut
    rawPublications.values.expand((list) => list).forEach((pub) {
      if (pub.attributes.isNotEmpty) {
        PublicationAttribute attribute = pub.attributes.first;
        // Vérifie s'il y a plus d'un attribut (optionnel)
        if (pub.attributes.length > 1) {
          // Vérifie si la liste contient l'attribut avec ID 3 ET l'attribut avec ID 9
          final bool hasAttribute3 = pub.attributes.any((attr) => attr.id == 3);
          final bool hasAttribute9 = pub.attributes.any((attr) => attr.id == 9);

          // Si les deux attributs spéciaux sont présents
          if (hasAttribute3 && hasAttribute9) {
            attribute = PublicationAttribute.all.firstWhere((attr) => attr.id == 58);
          }
        }

        publications.putIfAbsent(attribute, () => []).add(pub);
      }
    });

    // Ajout des publications téléchargées
    for (var pub in PublicationRepository().getAllDownloadedPublications()) {
      if (pub.category.id == category.id && pub.mepsLanguage.id == mepsLanguageId && (year == null || pub.year == year) && !publications.values.expand((list) => list).any((p) => p.keySymbol == pub.keySymbol && p.issueTagNumber == pub.issueTagNumber)) {

        PublicationAttribute attribute = pub.attributes.first;
        // Vérifie s'il y a plus d'un attribut (optionnel)
        if (pub.attributes.length > 1) {
          // Vérifie si la liste contient l'attribut avec ID 3 ET l'attribut avec ID 9
          final bool hasAttribute3 = pub.attributes.any((attr) => attr.id == 3);
          final bool hasAttribute9 = pub.attributes.any((attr) => attr.id == 9);

          // Si les deux attributs spéciaux sont présents
          if (hasAttribute3 && hasAttribute9) {
            attribute = PublicationAttribute.all.firstWhere((attr) => attr.id == 58);
          }
        }

        if (pub.attributes.isNotEmpty) {
          publications.putIfAbsent(attribute, () => []).add(pub);
        }
      }
    }

    // Tri des attributs (clés) pour un ordre de section stable
    var sortedEntries = publications.keys.toList()..sort((a, b) => a.id.compareTo(b.id));
    _publications = Map.fromEntries(sortedEntries.map((key) => MapEntry(key, publications[key]!)));

    // Initialise la liste filtrée avec toutes les publications
    _filteredPublications = Map.from(_publications);

    // Applique le tri par défaut/actuel après le chargement
    _applySorting(_filteredPublications);

    _mepsLanguage = mepsLanguage != null ? MepsLanguage.fromJson(mepsLanguage) : _publications.values.first.first.mepsLanguage;

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

      // *** MODIFICATION : La carte filtrée utilise la clé simple ***
      _filteredPublications = {};
      _publications.forEach((attribute, publicationList) {
        final filteredList = publicationList.where((pub) {
          // Normalisation du titre et du symbole pour la comparaison
          final normalizedTitle = removeDiacritics(pub.title).toLowerCase();
          final normalizedKeySymbol = removeDiacritics(pub.keySymbol).toLowerCase();

          return normalizedTitle.contains(normalizedQuery) || normalizedKeySymbol.contains(normalizedQuery);
        }).toList();

        if (filteredList.isNotEmpty) {
          // *** MODIFICATION : La clé est l'attribut simple ***
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

    // --- Logique de restauration de la structure après un tri 'year' ou 'symbol' ---
    // Les tris 'year' et 'symbol' utilisent l'attribut générique, ce qui aplatit la liste
    bool wasFlattened = _filteredPublications.length == 1 && _filteredPublications.containsKey(genericAttribute);

    // Si on change pour un critère qui n'est ni 'year' ni 'symbol' ET que la liste était aplatie
    if (newCriterion != 'year' && newCriterion != 'symbol' && wasFlattened) {
      final List<Publication> flattenedList = _filteredPublications[genericAttribute]!;

      // Restaurer la structure de _filteredPublications en fonction de l'attribut PRINCIPAL
      _filteredPublications = {};

      // Reconstruction des groupes d'attributs pour les publications actuellement affichées
      for (var pub in flattenedList) {
        // *** MODIFICATION : Utilise l'attribut PRINCIPAL (pub.attributes.first) pour le nouveau regroupement ***
        if (pub.attributes.isNotEmpty) {
          _filteredPublications.putIfAbsent(pub.attributes.first, () => []).add(pub);
        }
      }
    }
    // -----------------------------------------------------------------

    _currentSortCriterion = newCriterion;
    _applySorting(_filteredPublications);
    notifyListeners();
  }

  /// Logique de tri générique appliquée après le chargement, le filtrage ou le changement de critère.
  // *** MODIFICATION : mapToSort a maintenant PublicationAttribute comme clé ***
  void _applySorting(Map<PublicationAttribute, List<Publication>> mapToSort) {
    String field = '';
    String order = ''; // 'asc' ou 'desc'

    final parts = _currentSortCriterion.split('_');
    if (parts.length == 2) {
      field = parts[0];
      order = parts[1];
    } else {
      field = _currentSortCriterion;
      order = 'asc';
    }

    // --- 1. Tri par Année (Logique de Fusion) ---
    if (field == 'year') {
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

        if (isIssueTagNumber) {
          return (order == 'desc') ? b.issueTagNumber.compareTo(a.issueTagNumber) : a.issueTagNumber.compareTo(b.issueTagNumber);
        }
        return (order == 'desc') ? b.year.compareTo(a.year) : a.year.compareTo(b.year);
      });

      mapToSort.clear();
      mapToSort[genericAttribute] = allPublications;
      return;
    }

    // --- 2. Tri par Symbole (Logique de Fusion) ---
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

    // --- 3. Tri par Attribut / Tri par défaut (Titre) ---

    // A. Tri interne des publications
    mapToSort.forEach((attribute, publicationsFromAttribute) {
      if (category.hasYears) {
        publicationsFromAttribute.sort((a, b) => b.issueTagNumber.compareTo(a.issueTagNumber));
        return;
      }

      // 'attribute' est maintenant l'attribut clé simple, on vérifie son ordre
      bool shouldSortByYearInternal = attribute.id != -1 && attribute.order == 1;

      publicationsFromAttribute.sort((a, b) {
        if (shouldSortByYearInternal) {
          final int primaryComparison = b.year.compareTo(a.year);

          if (primaryComparison == 0) {
            return b.issueTagNumber.compareTo(a.issueTagNumber);
          }
          return primaryComparison;
        }

        // --- Logique de Tri par Critère Utilisateur (Titre) ---
        String titleA = removeDiacritics(a.title).toLowerCase();
        String titleB = removeDiacritics(b.title).toLowerCase();

        bool isSpecialA = RegExp(r'^[^a-zA-Z]').hasMatch(titleA);
        bool isSpecialB = RegExp(r'^[^a-zA-Z]').hasMatch(titleB);

        final int comparison = isSpecialA == isSpecialB
            ? titleA.compareTo(titleB)
            : (isSpecialA ? -1 : 1);

        return (order == 'asc') ? comparison : -comparison;
      });
    });

    // B. Tri des groupes d'attributs (pour garantir l'ordre des sections)
    if (field == 'title') {
      // Nous trions les clés (PublicationAttribute) par leur ID pour un ordre stable des sections
      final List<PublicationAttribute> sortedKeys = mapToSort.keys.toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      // Reconstruit la map triée
      final Map<PublicationAttribute, List<Publication>> newMap = {};
      for (var key in sortedKeys) {
        newMap[key] = mapToSort[key]!;
      }
      mapToSort.clear();
      mapToSort.addAll(newMap);
    }
  }
}