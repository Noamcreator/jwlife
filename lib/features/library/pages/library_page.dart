import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/features/library/pages/pending_update/pending_updates_widget.dart';
import 'package:jwlife/features/library/pages/publications/publications_categories_widget.dart';
import 'package:jwlife/features/library/pages/videos/videos_categories_widget.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/ui/text_styles.dart';
import '../../../core/utils/utils_language_dialog.dart';
import 'audios/audios_categories_widget.dart';
import 'downloads/downloads_widget.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  LibraryPageState createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _calculateTabsLength(), vsync: this);

    // Écoute des changements dans les catégories pour reconstruire les onglets
    AppDataService.instance.publicationsCategories.addListener(_onModelChange);
    AppDataService.instance.videoCategories.addListener(_onModelChange);
    AppDataService.instance.audioCategories.addListener(_onModelChange);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _onModelChange() {
    if (!mounted) return;

    final newLength = _calculateTabsLength();
    if (_tabController == null) return;

    if (_tabController!.length != newLength) {
      final currentIndex = _tabController!.index;
      _tabController!.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: currentIndex.clamp(0, newLength - 1),
      );
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
    if (publications.isNotEmpty) length++; // Publications
    if (videos != null) length++; // Vidéos
    if (audios != null) length++; // Audio
    length += 2; // Téléchargés + Mises à jour en attente
    return length;
  }

  void goToThePubsTab() {
    final publications = AppDataService.instance.publicationsCategories.value;
    if (_tabController != null && publications.isNotEmpty) {
      _tabController!.animateTo(0);
    }
  }

  void _onLanguagePressed(BuildContext context) async {
    final language = await showLanguageDialog(context);
    if (language != null) {
      await AppSharedPreferences.instance.setLibraryLanguage(language);
      AppDataService.instance.changeLanguageAndRefreshContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicationsCategories = AppDataService.instance.publicationsCategories.value;
    final videosCategories = AppDataService.instance.videoCategories.value;
    final audioCategories = AppDataService.instance.audioCategories.value;

    final tabs = <Tab>[];
    final views = <Widget>[];

    // Publications
    if (publicationsCategories.isNotEmpty) {
      tabs.add(Tab(text: i18n().navigation_publications.toUpperCase()));
      views.add(PublicationsCategoriesWidget());
    }

    // Vidéos
    if (videosCategories != null) {
      tabs.add(Tab(text: i18n().pub_type_videos_uppercase));
      views.add(VideosCategoriesWidget(categories: videosCategories));
    }

    // Audio
    if (audioCategories != null) {
      tabs.add(Tab(text: i18n().pub_type_audio_programs_uppercase));
      views.add(AudiosCategoriesWidget(categories: audioCategories));
    }

    // Téléchargés
    tabs.add(Tab(text: i18n().label_downloaded_uppercase));
    views.add(const DownloadWidget());

    // Mises à jour en attente
    tabs.add(Tab(text: i18n().label_pending_updates_uppercase));
    views.add(const PendingUpdatesWidget());

    // Mise à jour du TabController si nécessaire
    if (_tabController == null || _tabController!.length != tabs.length) {
      _tabController?.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
    }

    return AppPage(
      appBar: JwLifeAppBar(
        canPop: false,
        title: i18n().navigation_library,
        subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.currentLanguage, builder: (context, value, child) {
          return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
        }),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.language),
            onPressed: _onLanguagePressed,
          ),
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: History.showHistoryDialog,
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
              children: tabs.isEmpty
                  ? [getLoadingWidget(Theme.of(context).primaryColor)]
                  : views,
            ),
          ),
        ],
      ),
    );
  }
}
