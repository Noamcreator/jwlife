import 'package:flutter/material.dart';

import 'personal_page/about_me_page.dart';
import 'personal_page/study_page.dart';

class PersonalPage extends StatefulWidget {
  const PersonalPage({Key? key}) : super(key: key);

  @override
  _PersonalPageState createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Personel',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          bottom: TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            indicatorWeight: 1.0,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0),
            tabs: [
              Tab(text: 'Lecture de la Bible'),
              Tab(text: 'Études personnelles'),
              Tab(text: 'Réunions pour la prédication'),
              Tab(text: 'Sujets'),
              Tab(text: 'Moi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(child: Text('Contenu pour Lecture de la Bible')),
            StudyPageTab(),
            Center(child: Text('Contenu pour Réunions pour la prédication')),
            Center(child: Text('Contenu pour Sujets')),
            AboutMePage()
          ],
        ),
      ),
    );
  }
}
