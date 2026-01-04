import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/features/library/models/downloads/download_model.dart';
import 'package:jwlife/features/library/pages/pending_update/pending_updates_widget.dart';
import 'package:jwlife/features/library/pages/publications/publications_categories_widget.dart';
import 'package:jwlife/features/library/pages/search_library_page.dart';
import 'package:jwlife/features/library/pages/videos/videos_categories_widget.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/ui/text_styles.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../models/pending_update/pending_update_model.dart';
import 'audios/audios_categories_widget.dart';
import 'downloads/downloads_widget.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  LibraryPageState createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> with TickerProviderStateMixin {
  TabController? _tabController;
  late final DownloadPageModel _downloadModel;
  late final PendingUpdatesPageModel _pendingUpdatesModel;

  @override
  void initState() {
    super.initState();
    _initTabController(_calculateTabsLength());

    _downloadModel = DownloadPageModel();
    _pendingUpdatesModel = PendingUpdatesPageModel();

    // Écoute des changements dans les catégories pour reconstruire les onglets
    AppDataService.instance.publicationsCategories.addListener(_onModelChange);
    AppDataService.instance.videoCategories.addListener(_onModelChange);
    AppDataService.instance.audioCategories.addListener(_onModelChange);
  }

  void refreshDownloadTab() {
    _downloadModel.refreshData();
  }

  void refreshPendingUpdateTab() {
    _pendingUpdatesModel.refreshData();
  }

  void _initTabController(int length, {int initialIndex = 0}) {
    _tabController?.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, length - 1),
    );

    // Indispensable pour mettre à jour l'AppBar quand on change d'onglet
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {});
      }
    });
  }

  void goToThePubsTab() {
    final publications = AppDataService.instance.publicationsCategories.value;
    if (_tabController != null && publications.isNotEmpty) {
      _tabController!.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    AppDataService.instance.publicationsCategories.removeListener(_onModelChange);
    AppDataService.instance.videoCategories.removeListener(_onModelChange);
    AppDataService.instance.audioCategories.removeListener(_onModelChange);
    super.dispose();
  }

  void _onModelChange() {
    if (!mounted) return;

    final newLength = _calculateTabsLength();
    if (_tabController == null) return;

    if (_tabController!.length != newLength) {
      _initTabController(newLength, initialIndex: _tabController!.index);
      setState(() {});
    } else {
      setState(() {});
    }
  }

  int _calculateTabsLength() {
    final publications = AppDataService.instance.publicationsCategories.value;
    final videos = AppDataService.instance.videoCategories.value;
    final audios = AppDataService.instance.audioCategories.value;

    int length = 0;
    if (publications.isNotEmpty) length++;
    if (videos != null) length++;
    if (audios != null) length++;
    length += 2; // Téléchargés + Mises à jour
    return length;
  }

  void _onLanguagePressed(BuildContext context) async {
    final language = await showLanguageDialog(context);
    if (language != null) {
      await AppSharedPreferences.instance.setLibraryLanguage(language);
      AppDataService.instance.changeLibraryLanguageAndRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicationsCategories = AppDataService.instance.publicationsCategories.value;
    final videosCategories = AppDataService.instance.videoCategories.value;
    final audioCategories = AppDataService.instance.audioCategories.value;

    final tabs = <Tab>[];
    final views = <Widget>[];

    // Construction dynamique des listes pour identifier l'index
    if (publicationsCategories.isNotEmpty) {
      tabs.add(Tab(text: i18n().navigation_publications.toUpperCase()));
      views.add(PublicationsCategoriesWidget());
    }

    if (videosCategories != null) {
      tabs.add(Tab(text: i18n().pub_type_videos_uppercase));
      views.add(VideosCategoriesWidget(categories: videosCategories));
    }

    if (audioCategories != null) {
      tabs.add(Tab(text: i18n().pub_type_audio_programs_uppercase));
      views.add(AudiosCategoriesWidget(categories: audioCategories));
    }

    // Index pour le bouton de tri
    final int downloadIndex = tabs.length;
    tabs.add(Tab(text: i18n().label_downloaded_uppercase));
    views.add(DownloadWidget(model: _downloadModel));

    final int pendingUpdatesIndex = tabs.length;
    tabs.add(Tab(text: i18n().label_pending_updates_uppercase));
    views.add(PendingUpdatesWidget(model: _pendingUpdatesModel));

    // Vérification si on est sur l'onglet Téléchargements
    final bool isDownloadTab = _tabController?.index == downloadIndex;
    final bool isPendingUpdatesTab = _tabController?.index == pendingUpdatesIndex;

    return AppPage(
      appBar: JwLifeAppBar(
        canPop: false,
        title: i18n().navigation_library,
        subTitleWidget: ValueListenableBuilder(
            valueListenable: JwLifeSettings.instance.libraryLanguage,
            builder: (context, value, child) {
              return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
            }
        ),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: (buildContext) => showPage(SearchLibraryPage()),
          ),
          // Condition pour afficher Tri ou Langue
          if (isDownloadTab)
            IconTextButton(
              icon: const Icon(JwIcons.arrows_up_down), // Remplace par JwIcons.sort si disponible
              onPressed: (context) {
                /// 1. Définir les options du menu (les `PopupMenuItem`s)
                final List<PopupMenuEntry> menuItems = [
                  // --- Tri par Titre ---
                  // Option 1.1 : Tri par Titre (A-Z)
                  PopupMenuItem(
                    value: 'title_asc', // champ: title, ordre: ascendant
                    child: Text(i18n().label_sort_title_asc),
                  ),
                  // Option 1.2 : Tri par Titre (Z-A)
                  PopupMenuItem(
                    value: 'title_desc', // champ: title, ordre: descendant
                    child: Text(i18n().label_sort_title_desc),
                  ),

                  // Ajouter un séparateur visuel si vous le souhaitez (non obligatoire)
                  const PopupMenuDivider(),

                  // --- Tri par Année ---
                  // Option 2.1 : Tri par Année (Le plus récent d'abord)
                  PopupMenuItem(
                    value: 'year_desc', // champ: year, ordre: descendant (car année > -> plus récent)
                    child: Text(i18n().label_sort_year_desc),
                  ),
                  // Option 2.2 : Tri par Année (Le plus ancien d'abord)
                  PopupMenuItem(
                    value: 'year_asc', // champ: year, ordre: ascendant
                    child: Text(i18n().label_sort_year_asc),
                  ),

                  // Ajouter un séparateur visuel si vous le souhaitez
                  const PopupMenuDivider(),

                  // --- Tri par Symbole (Exemple) ---
                  // Option 3.1 : Tri par Symbole (A-Z)
                  PopupMenuItem(
                    value: 'symbol_asc',
                    child: Text(i18n().label_sort_symbol_asc),
                  ),
                  // Option 3.2 : Tri par Symbole (Z-A)
                  PopupMenuItem(
                    value: 'symbol_desc',
                    child: Text(i18n().label_sort_symbol_desc),
                  ),

                  const PopupMenuDivider(),

                  PopupMenuItem(
                    value: 'frequently_used',
                    child: Text(i18n().label_sort_frequently_used),
                  ),
                  // Option 3.2 : Tri par Symbole (Z-A)
                  PopupMenuItem(
                    value: 'rarely_used',
                    child: Text(i18n().label_sort_rarely_used),
                  ),

                  const PopupMenuDivider(),

                  PopupMenuItem(
                    value: 'largest_size',
                    child: Text(i18n().label_sort_largest_size),
                  ),
                ];

                // 2. Afficher le menu avec les options
                showMenu(
                  context: context,
                  elevation: 8.0,
                  items: menuItems,
                  initialValue: null,
                  position: RelativeRect.fromDirectional(
                    textDirection: Directionality.of(context),
                    start: MediaQuery.of(context).size.width - 210,
                    top: 40,
                    end: 10,
                    bottom: 0,
                  ),
                ).then((value) {
                  if (value != null) {
                    _downloadModel.sortItems(value);
                  }
                });
              }
            )
          else if (isPendingUpdatesTab)
            IconTextButton(
              icon: const Icon(JwIcons.cloud_arrow_down),
              onPressed: (context) async {
                  bool? hasUpdate = await _pendingUpdatesModel.updateAll(context);
                  if(hasUpdate != null) {
                      if(hasUpdate) {
                          showBottomMessage(i18n().message_catalog_success);
                      }
                      else {
                          showBottomMessage(i18n().message_catalog_up_to_date);
                      }
                  }
              },
            )
          else
            IconTextButton(
              icon: const Icon(JwIcons.language),
              onPressed: _onLanguagePressed,
            ),
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: JwLifeApp.history.showHistoryDialog,
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
              children: views.isEmpty
                  ? [getLoadingWidget(Theme.of(context).primaryColor)]
                  : views,
            ),
          ),
        ],
      ),
    );
  }
}