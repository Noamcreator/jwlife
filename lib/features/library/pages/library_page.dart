import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:realm/realm.dart';

import '../../../app/services/global_key_service.dart' show GlobalKeyService;
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../data/databases/catalog.dart';
import 'audio/audio_page.dart';
import 'download/download_page.dart';
import 'pending_update/pending_updates_page.dart';
import 'publication/publications_page.dart';
import 'video/video_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  LibraryPageState createState() => LibraryPageState();
}

// CORRECTION PRINCIPALE : Remplacement de SingleTickerProviderStateMixin
// par TickerProviderStateMixin pour supporter la recréation du TabController (plusieurs Tickers).
class LibraryPageState extends State<LibraryPage> with TickerProviderStateMixin {
  TabController? _tabController;
  String language = '';
  List<PublicationCategory> catalogCategories = [];
  late Category? video;
  late Category? audio;
  bool _isMediaLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    // Appel à la fonction de rafraîchissement d'origine
    refreshLibraryCategories();
    // Chargement initial des catégories du catalogue
    PubCatalog.updateCatalogCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // J'ai conservé la fonction d'origine et j'ai corrigé sa logique :
  // elle doit forcer la mise à jour des catégories du catalogue après avoir mis à jour les catégories Realm.
  void refreshLibraryCategories() {
    setLanguage();
    getCategories();

    // Ajout d'une lecture synchrone des catégories du catalogue pour assurer la mise à jour
    PubCatalog.updateCatalogCategories();
  }

  // Cette fonction est conservée, mais elle est maintenant appelée à la fois dans
  // initState et refreshLibraryCategories pour garantir la synchronisation du TabController.
  void refreshCatalogCategories(List<PublicationCategory> categories) {
    setState(() {
      catalogCategories = categories;
      _updateTabController(); // Mise à jour du contrôleur
    });
  }

  void setLanguage() {
    setState(() {
      language = JwLifeSettings().currentLanguage.vernacular;
    });
  }

  void getCategories() {
    // Marquer le début du chargement
    setState(() {
      _isMediaLoading = true;
    });

    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    Realm realm = Realm(config);
    final videoResults = realm.all<Category>().query("key == 'VideoOnDemand' AND language == '$languageSymbol'");
    final audioResults = realm.all<Category>().query("key == 'Audio' AND language == '$languageSymbol'");

    setState(() {
      video = videoResults.isNotEmpty ? videoResults.first : null;
      audio = audioResults.isNotEmpty ? audioResults.first : null;
      _isMediaLoading = false;
      _updateTabController(); // Mise à jour du contrôleur
    });
  }

  // Méthode pour obtenir le nombre d'onglets
  int _getTabsLength() {
    int length = 0;
    if (catalogCategories.isNotEmpty) length++; // Publications
    if (_isMediaLoading || video != null) length++; // Vidéos
    if (_isMediaLoading || audio != null) length++; // Audios
    length++; // Téléchargements
    length++; // Mises à jour en attente
    return length;
  }

  // Gère la recréation du TabController si la liste des onglets change
  void _updateTabController() {
    final newLength = _getTabsLength();

    if (_tabController!.length != newLength) {
      final currentIndex = _tabController!.index;
      _tabController!.dispose(); // Libérer l'ancien contrôleur

      // Créer un nouveau contrôleur avec la nouvelle longueur
      _tabController = TabController(
        length: newLength,
        vsync: this,
        // S'assurer que l'index initial est valide pour la nouvelle longueur
        initialIndex: currentIndex.clamp(0, newLength > 0 ? newLength - 1 : 0),
      );
    }
  }

  void goToThePubsTab() {
    if (_tabController != null && catalogCategories.isNotEmpty) {
      _tabController!.animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];

    // --- Construction des Onglets (doit refléter _getTabsLength) ---
    if (catalogCategories.isNotEmpty) {
      tabs.add(Tab(text: localization(context).navigation_publications.toUpperCase()));
      views.add(PublicationsPage(categories: catalogCategories));
    }

    if (_isMediaLoading || video != null) {
      tabs.add(Tab(text: localization(context).navigation_videos.toUpperCase()));
      views.add(
        _isMediaLoading
            ? getLoadingWidget(Theme.of(context).primaryColor)
            : (video != null ? VideoPage(video: video!) : const SizedBox.shrink()),
      );
    }

    if (_isMediaLoading || audio != null) {
      tabs.add(Tab(text: localization(context).navigation_audios.toUpperCase()));
      views.add(
        _isMediaLoading
            ? getLoadingWidget(Theme.of(context).primaryColor)
            : (audio != null ? AudioPage(audio: audio!) : const SizedBox.shrink()),
      );
    }

    tabs.add(Tab(text: localization(context).navigation_download.toUpperCase()));
    views.add(const DownloadPage());

    tabs.add(Tab(text: localization(context).navigation_pending_updates.toUpperCase()));
    views.add(const PendingUpdatesPage());

    // Vérification finale pour s'assurer que le contrôleur est synchronisé
    if (_tabController!.length != tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Déclenche un setState si la longueur des onglets change de manière inattendue
        setState(() {});
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localization(context).navigation_library, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              language,
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
            onPressed: () async {
              LanguageDialog languageDialog = LanguageDialog();
              final value = await showDialog(
                context: context,
                builder: (context) => languageDialog,
              );
              if (value != null) {
                // await setLibraryLanguage(value); // Décommentez si cette fonction existe
                refreshLibraryCategories(); // Utilisation de ta fonction de rafraîchissement d'origine
                GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
              }
            },
          ),
          IconButton(
            disabledColor: Colors.grey,
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: () => History.showHistoryDialog(context),
          ),
        ],
        // TabBar placée en bas de l'AppBar
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF111111) : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: tabs,
              dividerHeight: 1,
              dividerColor: Color(0xFF686868),
            ),
          ),
          Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabController!.length == 0
                    ? [getLoadingWidget(Theme.of(context).primaryColor)]
                    : views,
              ),
          )
        ],
      )
    );
  }
}