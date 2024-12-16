import 'package:flutter/material.dart';
import 'package:jwlife/pages/bible_page.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_items_page.dart';

import '../jwlife.dart';
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

  @override
  void initState() {
    super.initState();
    setLanguage();
  }

  void setLanguage() async {
    setState(() {
      language = JwLifeApp.currentLanguage.vernacular;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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
                    await JwLifeApp.setStateHomePage();
                    setLanguage();
                  });
                  //reloadItems();
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
                  VideoPage(),
                  AudioPage(),
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
