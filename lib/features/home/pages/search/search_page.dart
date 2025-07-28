import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:jwlife/features/home/pages/search/verses_search_tab.dart';
import 'package:searchfield/searchfield.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../widgets/searchfield/searchfield_all_widget.dart';
import 'all_search_tab.dart';
import 'audios_search_tab.dart';
import 'bible_search_page.dart';
import 'bible_search_tab.dart';
import 'images_search_tab.dart';
import 'publications_search_tab.dart';
import 'videos_search_tab.dart';

class SearchPage extends StatefulWidget {
  final String query;
  final int tab;

  const SearchPage({super.key, required this.query, this.tab = 0});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late SearchModel _searchModel;
  late TabController _tabController;
  late TextEditingController _searchController;
  late FocusNode _focusNode;

  List<Map<String, dynamic>> suggestions = [];
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this, initialIndex: widget.tab);
    _searchController = TextEditingController(text: widget.query);
    _focusNode = FocusNode();

    // Initialisation async du modèle
    initializeModel();
  }

  Future<void> initializeModel() async {
    _searchModel = SearchModel(query: widget.query);
    setState(() {
      isInitialized = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: SearchFieldAll(autofocus: false,  initialText: widget.query),
      ),
      body: Column(
        children: [
          buildTabBar(context),
          Expanded(
            child: isInitialized
                ? TabBarView(
              controller: _tabController,
              children: [
                AllSearchTab(model: _searchModel),
                PublicationsSearchTab(model: _searchModel),
                VideosSearchTab(model: _searchModel),
                AudioSearchTab(model: _searchModel),
                BibleSearchTab(model: _searchModel),
                VersesSearchTab(model: _searchModel),
                ImagesSearchTab(model: _searchModel),
              ],
            )
                : Center(child: CircularProgressIndicator()), // ou un autre widget de chargement
          ),
        ],
      ),
    );
  }

  Widget buildTabBar(BuildContext context) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
      labelStyle: TextStyle(fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.bold),
      unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.black,
      unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 2),
      tabs: [
        Tab(text: 'TOUT'),
        Tab(text: 'PUBLICATIONS'),
        Tab(text: 'VIDÉOS'),
        Tab(text: 'AUDIOS'),
        Tab(text: 'BIBLE'),
        Tab(text: 'VERSETS'),
        Tab(text: 'IMAGES'),
      ],
    );
  }
}
