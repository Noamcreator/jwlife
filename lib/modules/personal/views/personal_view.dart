import 'package:flutter/material.dart';
import 'package:jwlife/l10n/localization.dart';

import 'about_me_view.dart';
import 'study_view.dart';

class PersonalView extends StatefulWidget {
  const PersonalView({Key? key}) : super(key: key);

  @override
  _PersonalViewState createState() => _PersonalViewState();
}

class _PersonalViewState extends State<PersonalView> {
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
            localization(context).navigation_personal,
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
              Tab(text: localization(context).navigation_personal_bible_reading.toUpperCase()),
              Tab(text: localization(context).navigation_personal_study.toUpperCase()),
              Tab(text: localization(context).navigation_personal_predication_meetings.toUpperCase()),
              Tab(text: localization(context).navigation_personal_talks.toUpperCase()),
              Tab(text: localization(context).navigation_personal_about_me.toUpperCase()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(child: Text('Contenu pour Lecture de la Bible')),
            StudyTabView(),
            Center(child: Text('Contenu pour Réunions pour la prédication')),
            Center(child: Text('Contenu pour Sujets')),
            AboutMeView()
          ],
        ),
      ),
    );
  }
}
