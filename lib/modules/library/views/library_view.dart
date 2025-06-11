import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';

import 'audio/audio_view.dart';
import 'download/download_view.dart';
import 'pending_update/pending_updates_view.dart';
import 'publication/publications_view.dart';
import 'video/video_view.dart';

class LibraryView extends StatefulWidget {
  static late Future<void> Function() setStateLibraryPage;

  LibraryView({Key? key}) : super(key: key);

  @override
  _LibraryViewState createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  String language = '';
  late Category? video = Category(); // Initialise une catégorie vide
  late Category? audio = Category();
  bool _isMediaLoading = true;

  @override
  void initState() {
    super.initState();
    LibraryView.setStateLibraryPage = _reloadPage;
    _reloadPage();
  }

  Future<void> _reloadPage() async {
    setLanguage();
    getCategories();
  }

  void setLanguage() {
    setState(() {
      language = JwLifeApp.settings.currentLanguage.vernacular;
    });
  }

  void getCategories() {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeApp.settings.currentLanguage.symbol;

    Realm realm = Realm(config);

    setState(() {
      final videoResults = realm.all<Category>().query("key == 'VideoOnDemand' AND language == '$languageSymbol'");
      final audioResults = realm.all<Category>().query("key == 'Audio' AND language == '$languageSymbol'");

      video = videoResults.isNotEmpty ? videoResults.first : null;
      audio = audioResults.isNotEmpty ? audioResults.first : null;

      _isMediaLoading = false; // Indique que les données sont prêtes
    });
  }

  @override
  Widget build(BuildContext context) {
    int length = 5;

    if(JwLifeApp.categories.isEmpty) {
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
                  await setLibraryLanguage(value);
                  _reloadPage();
                  HomeView.setStateHomePage();
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
                if (JwLifeApp.categories.isNotEmpty)
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
                  if (JwLifeApp.categories.isNotEmpty)
                    PublicationsView(categories: JwLifeApp.categories),
                  if (_isMediaLoading || video != null)
                    _isMediaLoading ? getLoadingWidget() : VideoView(video: video!),
                  if (_isMediaLoading || audio != null)
                    _isMediaLoading ? getLoadingWidget() : AudioView(audio: audio!),
                  DownloadView(),
                  PendingUpdatesView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

