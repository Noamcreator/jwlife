import 'package:flutter/material.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/congregation/views/brothers_and_sisters_view.dart';

import 'congregations_view.dart';

class CongregationView extends StatefulWidget {
  const CongregationView({Key? key}) : super(key: key);

  @override
  _CongregationViewState createState() => _CongregationViewState();
}

class _CongregationViewState extends State<CongregationView> {
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
              localization(context).navigation_congregations,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: localization(context).navigation_congregations.toUpperCase()),
                  Tab(text: localization(context).navigation_congregation_brothers_and_sisters.toUpperCase()),
                  Tab(text: localization(context).navigation_congregation_events.toUpperCase()),
                ],
              ),
              Expanded(
                  child: TabBarView(
                    children: [
                      CongregationsView(),
                      BrothersAndSistersView(),
                      Center(child: Text('Contenu pour Sujets')),
                    ],
                  )
              )
            ],
          ),
        )
    );
  }
}
