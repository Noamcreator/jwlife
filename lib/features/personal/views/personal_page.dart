import 'package:flutter/material.dart';
import 'package:jwlife/i18n/localization.dart';

import 'about_me_page.dart';
import 'study_page.dart';

class PersonalView extends StatefulWidget {
  const PersonalView({super.key});

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
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: Text(
                localization(context).navigation_personal,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            body: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: localization(context).navigation_personal_bible_reading.toUpperCase()),
                    Tab(text: localization(context).navigation_personal_study.toUpperCase()),
                    Tab(text: localization(context).navigation_personal_predication_meetings.toUpperCase()),
                    Tab(text: localization(context).navigation_personal_talks.toUpperCase()),
                    Tab(text: localization(context).navigation_personal_about_me.toUpperCase()),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Center(child: Text('Contenu pour Lecture de la Bible')),
                      StudyTabView(),
                      Center(child: Text('Contenu pour Réunions pour la prédication')),
                      Center(child: Text('Contenu pour Sujets')),
                      AboutMePage()
                    ],
                  ),
                )
              ],
            )
        )
    );
  }
}
