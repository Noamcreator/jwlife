import 'package:flutter/material.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';

class PendingUpdatesPageModel with ChangeNotifier {
  bool _isLoading = true;
  List<dynamic> _mixedItems = [];

  bool get isLoading => _isLoading;
  List<dynamic> get mixedItems => _mixedItems;

  PendingUpdatesPageModel() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await sortItems(refresh: false);
    } catch (e) {
      debugPrint('Erreur lors du chargement des MAJ: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sortItems({bool refresh = true}) async {
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    // On récupère uniquement celles qui ont une MAJ en base
    final allPubs = await CatalogDb.instance.getAllUpdatePublications();
    // Les médias n'ont pas forcément de système de "Update" identique, on garde la liste téléchargée
    final allMedias = MediaRepository().getAllDownloadedMedias();

    _mixedItems = [];

    _mixedItems = [...allPubs, ...allMedias];
    _mixedItems.sort((a, b) {
      String? yA = (a is Publication) ? a.lastModified : (a as Media).firstPublished?.year.toString() ?? '0';
      String? yB = (b is Publication) ? b.lastModified : (b as Media).firstPublished?.year.toString() ?? '0';
      return yA?.compareTo(yB ?? '0') ?? 0;
    });

    if (refresh) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async => await _loadData();

  Future<bool?> updateAll(BuildContext context, {bool refresh = true}) async {
    // On crée une liste pour stocker toutes les "promesses" (Futures)
    List<Future<void>> tasks = [];
    bool hasUpdate = false;

    for (var item in _mixedItems) {
      if (item is Publication && item.hasUpdateNotifier.value) {
        // On AJOUTE la fonction à la liste sans mettre "await" ici
        // Cela lance l'exécution immédiatement en arrière-plan
        tasks.add(item.update(context, refreshUi: false));
        hasUpdate = true;
      } 
      else if (item is Media && item.hasUpdateNotifier.value) {
        tasks.add(item.update(context));
        hasUpdate = true;
      }
    }

    // C'est ICI qu'on attend. 
    // Future.wait attend que TOUTES les tâches de la liste soient terminées.
    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }

    if(!hasUpdate && refresh) {
      await refreshData();
      await updateAll(context, refresh: false);
      return null;
    }

    notifyListeners();
    return hasUpdate;
  }
}