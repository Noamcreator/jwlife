import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/modules/home/views/search_views/search_model.dart';
import 'package:searchfield/searchfield.dart';

import 'all_search_tab.dart';
import 'audios_search_tab.dart';
import 'bible_search_page.dart';
import 'bible_search_tab.dart';
import 'publications_search_tab.dart';
import 'videos_search_tab.dart';

class SearchView extends StatefulWidget {
  final String query;

  const SearchView({super.key, required this.query});

  @override
  _SearchViewState createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with SingleTickerProviderStateMixin {
  late SearchModel _searchModel;
  late TabController _tabController;
  late TextEditingController _searchController;
  List<Map<String, dynamic>> suggestions = [];
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController = TextEditingController(text: widget.query);

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
      ],
    );
  }

  Widget buildSearchField(BuildContext context) {
    return SearchField<Map<String, dynamic>>(
      controller: _searchController,
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
                margin: const EdgeInsets.only(left: 5),
                child: Icon(JwIcons.magnifying_glass, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
            ),
            onTap: () {

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
          Publication? publication = await PubCatalog.searchPub(item.item!['query'], 0, JwLifeApp.settings.currentLanguage.id);
          if (publication != null) {
            publication.showMenu(context, update: null);
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
        // search tab active reload page
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
