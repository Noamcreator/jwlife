import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/l10n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:realm/realm.dart';

import 'audio/audio_view.dart';
import 'download/download_view.dart';
import 'publication/publications_view.dart';
import 'video/video_view.dart';

class LibraryView extends StatefulWidget {
  static late Function() setStateLibraryPage;

  LibraryView({Key? key}) : super(key: key);

  @override
  _LibraryViewState createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  String language = '';
  late Category video = Category(); // Initialise une catégorie vide
  late Category audio = Category();
  bool _isLoading = true;

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

  void setLanguage() async {
    setState(() {
      language = JwLifeApp.currentLanguage.vernacular;
    });
  }

  Future<void> getCategories() async {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    Realm realm = Realm(config);

    try {
      setState(() {
        video = realm.all<Category>().query("key == 'VideoOnDemand' AND language == '$languageSymbol'").first;
        audio = realm.all<Category>().query("key == 'Audio' AND language == '$languageSymbol'").first;
        _isLoading = false; // Indique que les données sont prêtes
      });
    } catch (e) {
      // Gérez les erreurs si nécessaire
    }
  }

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localization(context).navigation_library,
                style: textStyleTitle
              ),
              Text(
                language,
                style: textStyleSubtitle
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(JwIcons.language),
              onPressed: () async {
                LanguageDialog languageDialog = LanguageDialog();
                showDialog(
                  context: context,
                  builder: (context) => languageDialog,
                ).then((value) {
                  setState(() async {
                    await setLibraryLanguage(value);
                    _reloadPage();
                    await HomeView.setStateHomePage();
                  });
                });
              },
            )
          ],
        ),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: <Widget>[
                Tab(text: localization(context).navigation_publications.toUpperCase()),
                Tab(text: localization(context).navigation_videos.toUpperCase()),
                Tab(text: localization(context).navigation_audios.toUpperCase()),
                Tab(text: localization(context).navigation_download.toUpperCase()),
                Tab(text: localization(context).navigation_pending_updates.toUpperCase()),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  PublicationsView(),
                  _isLoading ? getLoadingWidget() : VideoView(video: video),
                  _isLoading ? getLoadingWidget() : AudioView(audio: audio),
                  DownloadView(),
                  Center(child: Text('Mise à jour en attente')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

