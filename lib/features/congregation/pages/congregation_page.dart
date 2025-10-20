import 'package:flutter/material.dart';
import 'package:jwlife/i18n/localization.dart';

import 'congregations_page.dart';

class CongregationPage extends StatefulWidget {
  const CongregationPage({super.key});

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
              localization(context).navigation_congregations,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: CongregationsPage()
        )
    );
  }
}
