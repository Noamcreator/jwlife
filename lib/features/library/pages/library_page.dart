import 'package:flutter/material.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/features/library/pages/publications/publications_categories_page.dart';
import 'package:jwlife/features/library/pages/videos/videos_categories_page.dart';
import 'package:jwlife/i18n/localization.dart';

import '../../../app/services/global_key_service.dart' show GlobalKeyService;
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/models/publication_category.dart';
import '../models/library_model.dart';
import 'audios/audios_categories_page.dart';
import 'downloads/downloads_page.dart';
import 'pending_update/pending_updates_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  LibraryPageState createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> with TickerProviderStateMixin {
  TabController? _tabController;
  late final LibraryPageModel _model; // Le modèle de données/logique

  @override
  void initState() {
    super.initState();
    _model = LibraryPageModel(); // Initialisation du modèle

    // Le contrôleur est initialisé avec une longueur de 0 (ou celle du modèle)
    _tabController = TabController(length: _model.tabsLength, vsync: this);

    // Écoute les changements dans le modèle pour mettre à jour le TabController si nécessaire
    _model.addListener(_onModelChange);

    // Démarre la logique de chargement
    _model.refreshLibraryCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _model.removeListener(_onModelChange);
    _model.dispose(); // Libérer les ressources du modèle
    super.dispose();
  }

  void refreshCatalogCategories(List<PublicationCategory> categories) {
    _model.refreshCatalogCategories(categories);
  }

  void refreshLibraryCategories() {
    _model.refreshLibraryCategories();
  }

  // Gère la recréation du TabController si la liste des onglets change
  void _onModelChange() {
    // Si la page n'est plus montée, on ne fait rien.
    if (!mounted) return;

    final newLength = _model.tabsLength;

    if (_tabController!.length != newLength) {
      final currentIndex = _tabController!.index;

      // Un petit 'setState' pour s'assurer que le widget utilise la nouvelle logique
      // et que le TabController sera recréé.
      setState(() {
        _tabController!.dispose(); // Libérer l'ancien contrôleur

        // Créer un nouveau contrôleur avec la nouvelle longueur
        _tabController = TabController(
          length: newLength,
          vsync: this,
          // S'assurer que l'index initial est valide pour la nouvelle longueur
          initialIndex: currentIndex.clamp(0, newLength > 0 ? newLength - 1 : 0),
        );
      });
    }
  }

  void goToThePubsTab() {
    // Utilise la logique du modèle pour la vérification
    if (_tabController != null && _model.catalogCategories.isNotEmpty) {
      _tabController!.animateTo(0);
    }
  }

  // Fonctions de l'AppBar déplacées de la logique vers le widget
  void _onLanguagePressed(BuildContext context) async {
    showLanguageDialog(context).then((language) async {
      if (language != null) {
        // Supposons que setLibraryLanguage existe et soit asynchrone
        // await setLibraryLanguage(language);
        _model.refreshLibraryCategories(); // Utilisation de la fonction du modèle
        GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation de ListenableBuilder pour n'écouter que les changements
    // du modèle, tout en gardant le TickerProviderStateMixin du StatefulWidget.
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final tabs = <Tab>[];
        final views = <Widget>[];

        // --- Construction des Onglets (basée sur le modèle) ---
        if (_model.catalogCategories.isNotEmpty) {
          tabs.add(Tab(text: localization(context).navigation_publications.toUpperCase()));
          views.add(PublicationsCategoriesPage(categories: _model.catalogCategories));
        }

        if (_model.isMediaLoading || _model.video != null) {
          tabs.add(Tab(text: localization(context).navigation_videos.toUpperCase()));
          views.add(
            _model.isMediaLoading
                ? getLoadingWidget(Theme.of(context).primaryColor)
                : (_model.video != null ? VideosCategoriesPage(categories: _model.video!) : const SizedBox.shrink()),
          );
        }

        if (_model.isMediaLoading || _model.audio != null) {
          tabs.add(Tab(text: localization(context).navigation_audios.toUpperCase()));
          views.add(
            _model.isMediaLoading
                ? getLoadingWidget(Theme.of(context).primaryColor)
                : (_model.audio != null ? AudiosCategoriesPage(categories: _model.audio!) : const SizedBox.shrink()),
          );
        }

        tabs.add(Tab(text: localization(context).navigation_download.toUpperCase()));
        views.add(const DownloadPage());

        tabs.add(Tab(text: localization(context).navigation_pending_updates.toUpperCase()));
        views.add(const PendingUpdatesPage());

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localization(context).navigation_library,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                  _model.language, // Langue issue du modèle
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFc3c3c3)
                        : const Color(0xFF626262),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(JwIcons.language),
                onPressed: () => _onLanguagePressed(context),
              ),
              IconButton(
                disabledColor: Colors.grey,
                icon: const Icon(JwIcons.arrow_circular_left_clock),
                onPressed: () => History.showHistoryDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF111111)
                    : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: tabs,
                  dividerHeight: 1,
                  dividerColor: const Color(0xFF686868),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: tabs.isEmpty // Afficher un chargement si aucun onglet
                      ? [getLoadingWidget(Theme.of(context).primaryColor)]
                      : views,
                ),
              )
            ],
          ),
        );
      },
    );
  }
}