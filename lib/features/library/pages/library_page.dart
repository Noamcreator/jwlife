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

class LibraryPageState extends State<LibraryPage> {
  String language = '';
  List<PublicationCategory> catalogCategories = [];
  late Category? video;
  late Category? audio;
  bool _isMediaLoading = true;

  @override
  void initState() {
    super.initState();
    refreshLibraryCategories();
    PubCatalog.updateCatalogCategories();
  }

  void refreshLibraryCategories() {
    setLanguage();
    getCategories();
  }

  void refreshCatalogCategories(List<PublicationCategory> categories) async {
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
      _isMediaLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];

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

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
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
                  await setLibraryLanguage(value);
                  refreshLibraryCategories();
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
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF111111) : Colors.white,
              child: TabBar(
                isScrollable: true,
                tabs: tabs,
                dividerHeight: 1,
                dividerColor: Color(0xFF686868),
              )
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}