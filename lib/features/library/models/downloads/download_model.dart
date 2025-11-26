import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:path/path.dart' as path;

import '../../../../core/app_data/meetings_pubs_service.dart';
import '../../../../core/utils/common_ui.dart';
import '../../../publication/pages/menu/local/publication_menu_view.dart';

class DownloadPageModel with ChangeNotifier {
  bool _isLoading = true;
  // Publications groupées par nom de catégorie
  Map<String, List<Publication>> _groupedPublications = {};
  // Médias groupés par type ('Audios', 'Videos')
  Map<String, List<Media>> _groupedMedias = {};

  // --- Getters publics ---
  bool get isLoading => _isLoading;
  Map<String, List<Publication>> get groupedPublications => _groupedPublications;
  Map<String, List<Media>> get groupedMedias => _groupedMedias;

  DownloadPageModel() {
    _loadData();
  }

  // --- Logique de chargement des données ---

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners(); // Affiche le CircularProgressIndicator

    try {
      await _loadMedias();
      await _loadAndGroupPublications();
    } catch (e) {
      debugPrint('Erreur lors du chargement des données de téléchargement: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadMedias() async {
    List<Media> mediasDownload = List.from(MediaRepository().getAllDownloadedMedias());
    List<Audio> audiosDownload = mediasDownload.whereType<Audio>().toList();
    List<Video> videosDownload = mediasDownload.whereType<Video>().toList();

    _groupedMedias = {};
    if (audiosDownload.isNotEmpty) {
      _groupedMedias['Audios'] = audiosDownload.toList();
    }
    if (videosDownload.isNotEmpty) {
      _groupedMedias['Videos'] = videosDownload.toList();
    }
  }

  Future<void> _loadAndGroupPublications() async {
    // Tri et groupement des publications - fait une seule fois
    List<Publication> sortedPublications = List.from(PublicationRepository().getAllDownloadedPublications())
      ..sort((a, b) => a.category.id.compareTo(b.category.id));

    _groupedPublications = {};
    // La méthode getName(context) ne peut pas être appelée dans le modèle sans context.
    // Il faudra la passer si elle est absolument nécessaire, ou utiliser une propriété statique/locale.
    // Ici, nous allons utiliser le keySymbol pour un groupement simple,
    // MAIS puisque vous utilisez `pub.category.getName(context)` dans l'original,
    // nous allons temporairement utiliser un nom de catégorie qui sera localisé par le widget.
    // Pour que cela fonctionne, je vais utiliser un nom de catégorie simple et présumer que
    // l'UI gérera la traduction.
    for (Publication pub in sortedPublications) {
      // Pour éviter de passer le BuildContext au modèle, on utilise l'ID de la catégorie
      // et la traduction sera faite dans le widget.
      final categoryId = pub.category.id.toString();
      _groupedPublications.putIfAbsent(categoryId, () => []).add(pub);
    }
  }

  // --- Logique d'Importation ---

  void importJwpub(BuildContext context) {
    // Utiliser context ici pour la localisation des chaînes de dialogue
    FilePicker.platform.pickFiles(allowMultiple: true).then((result) async {
      if (result != null && result.files.isNotEmpty) {
        for (PlatformFile f in result.files) {
          String filePath = f.path!;
          File file = File(filePath);

          if (showInvalidExtensionDialog(context, filePath: filePath, expectedExtension: '.jwpub')) {
            String fileName = path.basename(file.path);
            BuildContext? dialogContext = await showJwImport(context, fileName);

            Publication? jwpub = await jwpubUnzip(file.readAsBytesSync());

            if (dialogContext != null) {
              Navigator.of(dialogContext).pop();
            }

            if (jwpub == null) {
              showImportFileError(context, '.jwpub');
            }
            else {
              if (jwpub.keySymbol == 'S-34') {
                refreshPublicTalks();
              }

              if (f == result.files.last) {
                CatalogDb.instance.updateCatalogCategories();

                // Recharger les données après import
                await _loadData();

                // Afficher la page après l'import (logique de navigation laissée dans le modèle pour simplicité)
                showPage(PublicationMenuView(publication: jwpub));
              }
            }
          }
        }
      }
    });
  }

  // Méthode pour recharger les données depuis l'extérieur si nécessaire
  Future<void> refreshData() async {
    await _loadData();
  }
}