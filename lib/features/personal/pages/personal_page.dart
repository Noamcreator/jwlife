import 'package:flutter/material.dart';
import 'package:jwlife/i18n/localization.dart';

import 'study_page.dart';

class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key});

  @override
  PersonalPageState createState() => PersonalPageState();
}

class PersonalPageState extends State<PersonalPage> {
  final GlobalKey<StudyTabViewState> _studyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  // 🔹 Méthode pour forcer le refresh
  void refreshUserdata() {
    _studyKey.currentState?.reloadData();
  }

  void refreshPlaylist() {
    _studyKey.currentState?.refreshPlaylist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          localization(context).navigation_personal,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: StudyTabView(
        key: _studyKey, // 🔹 associer la clé
      ),
    );
  }
}