import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/app/services/settings_service.dart';

class PublicationsItemsViewModel with ChangeNotifier {
  Map<PublicationAttribute, List<Publication>> _publications = {};
  Map<PublicationAttribute, List<Publication>> _filteredPublications = {};
  bool _isSearching = false;
  bool _isLoading = true;

  // Critère de tri actuel, 'title' par défaut.
  String _currentSortCriterion = 'title_asc';

  // Paramètres injectés à l'initialisation
  final PublicationCategory category;
  final int? year;
  MepsLanguage? mepsLanguage;

  // Attribut factice/générique pour le regroupement lors du tri par année (constant)
  static final genericAttribute = PublicationAttribute.all.first;

  PublicationsItemsViewModel({required this.category, this.year, this.mepsLanguage});

  // --- Getters publics ---
  MepsLanguage? get currentMepsLanguage => mepsLanguage;
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

  Future<void> loadItems({Map<String, dynamic>? mepsLanguageMap}) async {
    // *** MODIFICATION : Map locale utilise la clé simple ***
    Map<PublicationAttribute, List<Publication>> publications = {};

    mepsLanguage = mepsLanguageMap != null ? MepsLanguage.fromJson(mepsLanguageMap) : currentMepsLanguage ?? JwLifeSettings.instance.libraryLanguage.value;

    // Charger les publications existantes (la sortie de PubCatalog devra être ajustée côté Base de données)
    Map<List<PublicationAttribute>, List<Publication>> rawPublications = {};

    if (year != null) {
      rawPublications = await CatalogDb.instance.getPublicationsFromCategory(
          category.id,
          mepsLanguage!,
          year: year,
      );
    }
    else {
      rawPublications = await CatalogDb.instance.getPublicationsFromCategory(
          category.id,
          mepsLanguage!
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
      if (pub.category.id == category.id && pub.mepsLanguage.id == mepsLanguage!.id && (year == null || pub.year == year) && !publications.values.expand((list) => list).any((p) => p.keySymbol == pub.keySymbol && p.issueTagNumber == pub.issueTagNumber)) {

        PublicationAttribute attribute = pub.attributes.first;
        // Vérifie s'il y a plus d'un attribut (optionnel)
        if (pub.attributes.length > 1) {
          // Vérifie si les attributs pour les assemblées de circonscription et régionales sont présents
          final bool hasAttribute2 = pub.attributes.any((attr) => attr.id == 2);

          // Vérifie si la liste contient l'attribut avec ID 3 ET l'attribut avec ID 9
          final bool hasAttribute3 = pub.attributes.any((attr) => attr.id == 3);
          final bool hasAttribute9 = pub.attributes.any((attr) => attr.id == 9);

          // Vérifie si la liste contient l'attribut avec ID 1 ET l'attribut avec ID 2
          if (hasAttribute2 && hasAttribute3) {
            attribute = PublicationAttribute.all.firstWhere((attr) => attr.id == 1);
          }

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

    _isLoading = false;
    notifyListeners(); // Rafraîchit l'interface
  }

  void filterPublications(String query) {
    if (query.isEmpty) {
      // Si la recherche est vide, on repart de la structure complète originale
      _filteredPublications = Map.from(_publications);
    } else {
      // Normalisation de la requête pour la recherche (sans diacritiques et minuscule)
      final normalizedQuery = normalize(query);

      // *** MODIFICATION : La carte filtrée utilise la clé simple ***
      _filteredPublications = {};
      _publications.forEach((attribute, publicationList) {
        final filteredList = publicationList.where((pub) {
          // Normalisation du titre et du symbole pour la comparaison
          final normalizedTitle = normalize(pub.title);
          final normalizedKeySymbol = normalize(pub.keySymbol);

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
        final comparison = a.keySymbol.toLowerCase().compareTo(b.keySymbol.toLowerCase());
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
        publicationsFromAttribute.sort((a, b) => a.issueTagNumber.compareTo(b.issueTagNumber));
        return;
      }

      // 'attribute' est maintenant l'attribut clé simple, on vérifie son ordre
      bool shouldSortByYearInternal = attribute.id != -1 && attribute.order == 1;

      publicationsFromAttribute.sort((a, b) {
        if (shouldSortByYearInternal) {
          if (a.issueTagNumber != 0 && b.issueTagNumber != 0) {
            return a.issueTagNumber.compareTo(b.issueTagNumber);
          }
          else {
            return b.year.compareTo(a.year);
          }
        }

        // --- Logique de Tri par Critère Utilisateur (Titre) ---
        String titleA = normalize(a.title);
        String titleB = normalize(b.title);

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