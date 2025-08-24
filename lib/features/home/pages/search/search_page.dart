import 'package:flutter/material.dart';
import 'package:jwlife/features/home/pages/search/input_fields_search_tab.dart';
import 'package:jwlife/features/home/pages/search/notes_search_tab.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:jwlife/features/home/pages/search/verses_search_tab.dart';
import 'package:jwlife/features/home/pages/search/wikipedia_search_tab.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../widgets/searchfield/searchfield_all_widget.dart';
import 'all_search_tab.dart';
import 'audios_search_tab.dart';
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

class _SearchPageState extends State<SearchPage> {
  late SearchModel _searchModel;
  late TextEditingController _searchController;
  late FocusNode _focusNode;

  bool isInitialized = false;
  int currentTab = 0;

  final List<String> tabs = [
    'WIKIPEDIA',
    'TOUT',
    'PUBLICATIONS',
    'VIDÉOS',
    'AUDIOS',
    'BIBLE',
    'VERSETS',
    'IMAGES',
    'NOTES',
    'CHAMPS',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    currentTab = widget.tab;

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
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void selectTab(int index) {
    setState(() {
      currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: SearchFieldAll(
          autofocus: false,
          initialText: widget.query,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
        actions: [
          PopupMenuButton<int>(
            icon: Icon(Icons.menu),
            onSelected: selectTab,
            itemBuilder: (context) {
              return List.generate(
                tabs.length,
                    (index) => PopupMenuItem(
                  value: index,
                  child: Text(tabs[index]),
                ),
              );
            },
          ),
        ],
      ),
      body: isInitialized
          ? IndexedStack(
        index: currentTab,
        children: [
          WikipediaSearchTab(model: _searchModel),
          AllSearchTab(model: _searchModel),
          PublicationsSearchTab(model: _searchModel),
          VideosSearchTab(model: _searchModel),
          AudioSearchTab(model: _searchModel),
          BibleSearchTab(model: _searchModel),
          VersesSearchTab(model: _searchModel),
          ImagesSearchTab(model: _searchModel),
          NotesSearchTab(model: _searchModel),
          InputFieldsSearchTab(model: _searchModel),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
