import 'dart:collection';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:path/path.dart' as path;

import '../../../../core/app_data/meetings_pubs_service.dart';
import '../../../../core/utils/common_ui.dart';
import '../../../../core/utils/utils.dart';
import '../../../publication/pages/local/publication_menu_view.dart';

class DownloadPageModel with ChangeNotifier {
  bool _isLoading = true;
  String _currentSort = 'title_asc';
  Map<String, List<dynamic>> _groupedItems = {};
  List<dynamic> _mixedItems = [];

  bool get isLoading => _isLoading;
  Map<String, List<dynamic>> get groupedItems => _groupedItems;
  List<dynamic> get mixedItems => _mixedItems;

  DownloadPageModel() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      sortItems(_currentSort, refresh: false);
    } catch (e) {
      debugPrint('Erreur: $e');
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

    final allPubs = PublicationRepository().getAllDownloadedPublications();
    final allMedias = MediaRepository().getAllDownloadedMedias();

    _groupedItems = {};
    _mixedItems = [];

    if (sortType.contains('title')) {
      List<dynamic> items = [...allPubs, ...allMedias];

      // 1. Tri des items à l'intérieur des futurs groupes
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

      // 3. Répartition dans les groupes
      for (var item in items) {
        if (item is Publication) {
          final categoryId = item.category.id.toString();
          sortedGroups.putIfAbsent(categoryId, () => []).add(item);
        }
        else if (item is Media) {
          // Correction : On utilise item.type ou une distinction simple
          final typeKey = (item is Audio) ? 'Audios' : 'Videos';
          sortedGroups.putIfAbsent(typeKey, () => []).add(item);
        }
      }

      _groupedItems = sortedGroups;
    }

    // --- CAS 2 : AFFICHAGE MÉLANGÉ (Année, Symbole, Taille) ---
    else {
      _mixedItems = [...allPubs, ...allMedias];

      // 1. On gère d'abord les tris qui demandent la base de données
      if (sortType == 'frequently_used' || sortType == 'rarely_used') {
        _mixedItems = await History.searchUsedItems(_mixedItems, sortType);
      }

      // 2. On gère les autres tris synchrones
      else {
        _mixedItems.sort((a, b) {
          switch (sortType) {
            case 'year_asc':
              int yearA = (a is Publication) ? a.year : (a as Media).firstPublished?.year ?? 0;
              int yearB = (b is Publication) ? b.year : (b as Media).firstPublished?.year ?? 0;
              return yearA.compareTo(yearB);
            case 'year_desc':
              int yearA = (a is Publication) ? a.year : (a as Media).firstPublished?.year ?? 0;
              int yearB = (b is Publication) ? b.year : (b as Media).firstPublished?.year ?? 0;
              return yearB.compareTo(yearA);
            case 'symbol_asc':
              String symA = (a is Publication) ? a.keySymbol : (a as Media).keySymbol ?? '';
              String symB = (b is Publication) ? b.keySymbol : (b as Media).keySymbol ?? '';
              return symA.toLowerCase().compareTo(symB.toLowerCase());
            case 'symbol_desc':
              String symA = (a is Publication) ? a.keySymbol : (a as Media).keySymbol ?? '';
              String symB = (b is Publication) ? b.keySymbol : (b as Media).keySymbol ?? '';
              return symB.toLowerCase().compareTo(symA.toLowerCase());
            case 'largest_size':
              int sizeA = (a is Publication) ? a.expandedSize : (a as Media).fileSize ?? 0;
              int sizeB = (b is Publication) ? b.expandedSize : (b as Media).fileSize ?? 0;
              return sizeB.compareTo(sizeA);
            default:
              return 0;
          }
        });
      }
    }

    if (refresh) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void importJwpub(BuildContext context) {
    FilePicker.platform.pickFiles(allowMultiple: true).then((result) async {
      if (result != null && result.files.isNotEmpty) {
        for (PlatformFile f in result.files) {
          String filePath = f.path!;
          if (showInvalidExtensionDialog(context, filePath: filePath, expectedExtension: '.jwpub')) {
            File file = File(filePath);
            String fileName = path.basename(file.path);
            BuildContext? dialogContext = await showJwImport(context, fileName);
            Publication? jwpub = await jwpubUnzip(file.readAsBytesSync());

            if (dialogContext != null) Navigator.of(dialogContext).pop();

            if (jwpub == null) {
              showImportFileError(context, '.jwpub');
            } else {
              if (jwpub.keySymbol == 'S-34') refreshPublicTalks();
              if (f == result.files.last) {
                CatalogDb.instance.updateCatalogCategories(JwLifeSettings.instance.libraryLanguage.value);
                await _loadData();
                showPage(PublicationMenuView(publication: jwpub));
              }
            }
          }
        }
      }
    });
  }

  Future<void> refreshData() async => await _loadData();
}