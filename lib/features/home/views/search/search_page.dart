import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/views/search/search_model.dart';
import 'package:jwlife/features/home/views/search/verses_search_tab.dart';
import 'package:searchfield/searchfield.dart';

import '../../../../app/services/settings_service.dart';
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
      appBar: AppBar(
        title: buildSearchField(context),
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

  Widget buildSearchField(BuildContext context) {
    return SearchField<Map<String, dynamic>>(
      controller: _searchController,
      focusNode: _focusNode,
      itemHeight: 60,
      maxSuggestionsInViewPort: 6,
      suggestionAction: SuggestionAction.unfocus,
      searchInputDecoration: SearchInputDecoration(
          searchStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 20),
          fillColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
          filled: true,
          hintText: 'Rechercher...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          suffixIcon: GestureDetector(
            child: Container(
                color: Color(0xFF345996),
                margin: const EdgeInsets.only(left: 2),
                child: Icon(JwIcons.magnifying_glass, color: Colors.white)
            ),
            onTap: () {
              // search tab active reload page
              setState(() {
                _focusNode.unfocus();
                _searchModel.query = _searchController.text;
                _searchModel.clear();
                _searchModel.fetchOnActiveTab(_tabController.index);
              });
            },
          )
      ),
      onSearchTextChanged: (text) {
        setState(() {
          //fetchSuggestions(text);
        });
      },
      onSuggestionTap: (SearchFieldListItem<Map<String, dynamic>> item) async {
        if (item.item!['type'] == 2) {
          Publication? publication = await PubCatalog.searchPub(item.item!['query'], 0, JwLifeSettings().currentLanguage.id);
          if (publication != null) {
            publication.showMenu(context);
          }
        }
        else if(item.item!['type'] == 1) {
          showPage(context, SearchBiblePage(query: item.item?['query']));
        }
        else {
          // search tab active reload page
        }
      },
      onSubmit: (text) {
        setState(() {
          _searchModel.query = _searchController.text;
          _searchModel.clear();
          _searchModel.fetchOnActiveTab(_tabController.index);
        });
      },
      suggestionsDecoration: SuggestionDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      suggestions: suggestions
          .map((item) => SearchFieldListItem<Map<String, dynamic>>(item['caption'],
        item: item,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item['caption'], style: TextStyle(fontSize: 17)),
              item['label'] == '' ? Container() : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF595959) : Color(0xFFc0c0c0),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(item['label'], style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
      ).toList(),
    );
  }
}
