import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:realm/realm.dart';

import '../../../app/services/settings_service.dart';
import '../../../data/databases/catalog.dart';
import 'audio/audio_page.dart';
import 'download/download_page.dart';
import 'pending_update/pending_updates_page.dart';
import 'publication/publications_page.dart';
import 'video/video_page.dart';

class LibraryPage extends StatefulWidget {
  static late void Function() refreshLibraryCategories;
  static late void Function(List<PublicationCategory>) refreshCatalogCategories;

  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String language = '';
  List<PublicationCategory> catalogCategories = [];
  late Category? video; // Initialise une catégorie vide
  late Category? audio;
  bool _isMediaLoading = true;

  @override
  void initState() {
    super.initState();
    LibraryPage.refreshLibraryCategories = _refreshLibraryCategories;
    LibraryPage.refreshCatalogCategories = _refreshCatalogCategories;
    _refreshLibraryCategories();
    PubCatalog.updateCatalogCategories();
  }

  void _refreshLibraryCategories() {
    setLanguage();
    getCategories();
  }

  void _refreshCatalogCategories(List<PublicationCategory> categories) async {
    setState(() {
      catalogCategories = categories;
    });
  }

  void setLanguage() {
    setState(() {
      language = JwLifeSettings().currentLanguage.vernacular;
    });
  }

  void getCategories() {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeSettings().currentLanguage.symbol;

    Realm realm = Realm(config);
    final videoResults = realm.all<Category>().query("key == 'VideoOnDemand' AND language == '$languageSymbol'");
    final audioResults = realm.all<Category>().query("key == 'Audio' AND language == '$languageSymbol'");

    setState(() {
      video = videoResults.isNotEmpty ? videoResults.first : null;
      audio = audioResults.isNotEmpty ? audioResults.first : null;

      _isMediaLoading = false; // Indique que les données sont prêtes
    });
  }

  @override
  Widget build(BuildContext context) {
    int length = 5;

    if(catalogCategories.isEmpty) {
      length = length - 1;
    }
    if(!_isMediaLoading && video == null) {
      length = length - 1;
    }
    if(!_isMediaLoading && audio == null) {
      length = length - 1;
    }

    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),

    );

    return DefaultTabController(
      length: length,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localization(context).navigation_library, style: textStyleTitle),
              Text(language, style: textStyleSubtitle),
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
                  setLibraryLanguage(value);
                  _refreshLibraryCategories();
                  HomePage.refreshChangeLanguage();
                }
              },
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
            TabBar(
              isScrollable: true,
              tabs: [
                if (catalogCategories.isNotEmpty)
                  Tab(text: localization(context).navigation_publications.toUpperCase()),
                if (_isMediaLoading || video != null)
                  Tab(text: localization(context).navigation_videos.toUpperCase()),
                if (_isMediaLoading || audio != null)
                  Tab(text: localization(context).navigation_audios.toUpperCase()),
                Tab(text: localization(context).navigation_download.toUpperCase()),
                Tab(text: localization(context).navigation_pending_updates.toUpperCase()),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (catalogCategories.isNotEmpty)
                    PublicationsPage(categories: catalogCategories),
                  if (_isMediaLoading || video != null)
                    _isMediaLoading ? getLoadingWidget(Theme.of(context).primaryColor) : VideoPage(video: video!),
                  if (_isMediaLoading || audio != null)
                    _isMediaLoading ? getLoadingWidget(Theme.of(context).primaryColor) : AudioPage(audio: audio!),
                  DownloadPage(),
                  PendingUpdatesPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

