import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';
import 'package:jwlife/data/databases/history.dart';

class PendingUpdatesPageModel with ChangeNotifier {
  bool _isLoading = true;
  String _currentSort = 'title_asc';
  Map<String, List<dynamic>> _groupedItems = {};
  List<dynamic> _mixedItems = [];

  bool get isLoading => _isLoading;
  Map<String, List<dynamic>> get groupedItems => _groupedItems;
  List<dynamic> get mixedItems => _mixedItems;

  PendingUpdatesPageModel() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await sortItems(_currentSort, refresh: false);
    } catch (e) {
      debugPrint('Erreur lors du chargement des MAJ: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sortItems(String sortType, {bool refresh = true}) async {
    _currentSort = sortType;
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    // On récupère uniquement celles qui ont une MAJ en base
    final allPubs = await CatalogDb.instance.getAllUpdatePublications();
    // Les médias n'ont pas forcément de système de "Update" identique, on garde la liste téléchargée
    final allMedias = MediaRepository().getAllDownloadedMedias();

    _groupedItems = {};
    _mixedItems = [];

    if (sortType.contains('title')) {
      List<dynamic> items = [...allPubs, ...allMedias];

      // Tri alphabétique
      items.sort((a, b) {
        String titleA = (a is Publication) ? normalize(a.title) : normalize((a as Media).title);
        String titleB = (b is Publication) ? normalize(b.title) : normalize((b as Media).title);
        return sortType.contains('asc') ? titleA.compareTo(titleB) : titleB.compareTo(titleA);
      });

      // Groupement par catégories (Ordre JW)
      List<int> categoryIds = PublicationCategory.all.map((e) => int.parse(e.id.toString())).toList();
      final sortedGroups = SplayTreeMap<String, List<dynamic>>((a, b) {
        int indexA = categoryIds.indexOf(int.tryParse(a) ?? -1);
        int indexB = categoryIds.indexOf(int.tryParse(b) ?? -1);
        if (indexA == -1) indexA = (a == 'Audios' ? 1000 : 1001);
        if (indexB == -1) indexB = (b == 'Audios' ? 1000 : 1001);
        return indexA.compareTo(indexB);
      });

      for (var item in items) {
        if (item is Publication) {
          sortedGroups.putIfAbsent(item.category.id.toString(), () => []).add(item);
        } else if (item is Media) {
          sortedGroups.putIfAbsent((item is Audio) ? 'Audios' : 'Videos', () => []).add(item);
        }
      }
      _groupedItems = sortedGroups;
    }
    else {
      _mixedItems = [...allPubs, ...allMedias];
      if (sortType.contains('used')) {
        _mixedItems = await History.searchUsedItems(_mixedItems, sortType);
      }
      else {
        _mixedItems.sort((a, b) {
          switch (sortType) {
            case 'year_asc':
              int yA = (a is Publication) ? a.year : (a as Media).firstPublished?.year ?? 0;
              int yB = (b is Publication) ? b.year : (b as Media).firstPublished?.year ?? 0;
              return yA.compareTo(yB);
            case 'largest_size':
              int sA = (a is Publication) ? a.expandedSize : (a as Media).fileSize ?? 0;
              int sB = (b is Publication) ? b.expandedSize : (b as Media).fileSize ?? 0;
              return sB.compareTo(sA);
            default: return 0;
          }
        });
      }
    }

    if (refresh) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async => await _loadData();
}