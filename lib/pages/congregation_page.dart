import 'package:flutter/material.dart';

import 'personal_page/about_me_page.dart';
import 'personal_page/study_page.dart';

class CongregationPage extends StatefulWidget {
  const CongregationPage({Key? key}) : super(key: key);

  @override
  _CongregationPageState createState() => _CongregationPageState();
}

class _CongregationPageState extends State<CongregationPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Assemblée Locale',
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
              Tab(text: 'Mon Assemblée Locale'),
              Tab(text: 'Frères et Soeurs'),
              Tab(text: 'Dates Importantes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(child: Text('Contenu pour Lecture de la Bible')),
            Center(child: Text('Contenu pour Réunions pour la prédication')),
            Center(child: Text('Contenu pour Sujets')),
          ],
        ),
      ),
    );
  }
}
