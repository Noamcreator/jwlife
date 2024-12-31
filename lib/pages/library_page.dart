import 'package:flutter/material.dart';
import 'package:jwlife/pages/bible_page.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_items_page.dart';
import 'package:realm/realm.dart';

import '../jwlife.dart';
import '../realm/catalog.dart';
import '../utils/icons.dart';
import '../utils/shared_preferences_helper.dart';
import '../widgets/dialog/language_dialog.dart';
import 'library_pages/audio_pages/audio_page.dart';
import 'library_pages/download_pages/publication_download_page.dart';
import 'library_pages/publication_pages/publications_page.dart';
import 'library_pages/video_pages/video_page.dart';

class LibraryPage extends StatefulWidget {
  LibraryPage({Key? key}) : super(key: key);

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String language = '';
  late Category video = Category(); // Initialise une catégorie vide
  late Category audio = Category();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
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
        isLoading = false; // Indique que les données sont prêtes
      });
    } catch (e) {
      // Gérez les erreurs si nécessaire
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator()) // Affiche un loader pendant le chargement
        : DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bibliothèque',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                language,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                    setLanguage();
                    getCategories();
                    await JwLifeApp.setStateHomePage();
                  });
                });
              },
            )
          ],
        ),
        body: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: <Widget>[
                Tab(text: 'PUBLICATIONS'),
                Tab(text: 'VIDÉOS'),
                Tab(text: 'AUDIOS'),
                Tab(text: 'TÉLÉCHARGÉ'),
                Tab(text: 'MISES À JOUR EN ATTENTE'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  PublicationsPage(),
                  VideoPage(video: video), // Passe les données préchargées
                  AudioPage(audio: audio), // Passe les données préchargées
                  PublicationDownload(),
                  Text('Mise à jour en attente'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

