import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/pages/home_pages/search_pages/publications_search_tab.dart';
import 'package:jwlife/pages/home_pages/search_pages/videos_search_tab.dart';
import 'package:http/http.dart' as http;
import 'package:searchfield/searchfield.dart';

import '../../../jwlife.dart';
import '../../../utils/utils.dart';
import '../../library_pages/publication_pages/online/publication_menu.dart';
import 'all_search_tab.dart';
import 'audios_search_tab.dart';
import 'bible_search_page.dart';
import 'bible_search_tab.dart';

class SearchPage extends StatefulWidget {
  final String query;

  const SearchPage({Key? key, required this.query}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  List<Map<String, dynamic>> suggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController = TextEditingController(text: widget.query); // Initialiser avec la query
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose(); // Ne pas oublier de libérer le contrôleur
    super.dispose();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        suggestions = []; // Clear suggestions if the query is empty
      });
      return;
    }

    // Prepare the query for the API call
    String newQuery = Uri.encodeComponent(query);
    final String url = "https://wol.jw.org/wol/sg/${JwLifeApp.currentLanguage.rsConf}/${JwLifeApp.currentLanguage.lib}?q=$newQuery";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      // Verify that 'items' is a list
      if (jsonResponse['items'] is List) {
        setState(() {
          suggestions = (jsonResponse['items'] as List).map((item) {
            return {
              'type': item['type'] ?? 0,
              'query': item['query'] ?? '',
              'caption': item['caption'] ?? '',
              'label': item['label'] ?? '',
            };
          }).toList();
        });
      } else {
        setState(() {
          suggestions = []; // Initialize suggestions to an empty list
        });
      }
    } else {
      throw Exception('Error fetching suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recherche'),
      ),
      body: Column(
        children: [
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchField<Map<String, dynamic>>(
              controller: _searchController,
              itemHeight: 60,
              maxSuggestionsInViewPort: 6,
              suggestionAction: SuggestionAction.unfocus,
              searchInputDecoration: SearchInputDecoration(
                fillColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                filled: true,
                hintText: 'Rechercher...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSearchTextChanged: (text) {
                setState(() {
                  fetchSuggestions(text);
                });
              },
              onSuggestionTap: (SearchFieldListItem<Map<String, dynamic>> item) async {
                if (item.item!['type'] == 2) {
                  Map<String, dynamic>? publication = await searchPub(item.item!['query']);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return PublicationMenu(publication: publication!);
                      },
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                }
                else if(item.item!['type'] == 1) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return SearchBiblePage(query: item.item?['query']);
                      },
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
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
            ),
          ),
          // Onglets
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: EdgeInsets.symmetric(vertical: 5.0),
            labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
            labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            labelStyle: TextStyle(
              fontSize: 15,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.black,
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              letterSpacing: 2,
            ),
            controller: _tabController,
            tabs: [
              Tab(text: 'TOUT'),
              Tab(text: 'PUBLICATIONS'),
              Tab(text: 'VIDÉOS'),
              Tab(text: 'AUDIOS'),
              Tab(text: 'BIBLE'),
            ],
          ),
          // Vue des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet Tout
                AllSearchTab(query: _searchController.text),
                // Onglet Publications
                PublicationsSearchTab(query: _searchController.text),
                // Onglet Vidéos
                VideosSearchTab(query: _searchController.text),
                // Onglet Audios
                AudioSearchTab(query: _searchController.text),
                // Onglet Bible
                BibleSearchTab(query: _searchController.text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
