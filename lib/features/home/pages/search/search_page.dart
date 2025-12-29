import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/features/home/pages/search/input_fields_search_tab.dart';
import 'package:jwlife/features/home/pages/search/notes_search_tab.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:jwlife/features/home/pages/search/verses_search_tab.dart';
import 'package:jwlife/features/home/pages/search/wikipedia_search_tab.dart';
import 'package:jwlife/features/home/pages/search/wol_search_tab.dart';
import 'package:jwlife/widgets/slide_indexed_stack.dart';

import '../../../../app/app_page.dart';
import '../../../../app/services/global_key_service.dart';
import '../../../../i18n/i18n.dart';
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
    i18n().label_research_all,
    i18n().label_research_wol,
    i18n().navigation_publications_uppercase,
    i18n().pub_type_videos_uppercase,
    i18n().pub_type_audio_programs_uppercase,
    i18n().label_research_bible,
    i18n().label_research_verses,
    i18n().label_research_images,
    i18n().label_research_notes,
    i18n().label_research_inputs_fields,
    i18n().label_research_wikipedia
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
    return AppPage(
      appBar: AppBar(
        titleSpacing: 0.0,
        actionsPadding: const EdgeInsets.only(left: 10, right: 5),
        title: SearchFieldAll(
          autofocus: false,
          initialText: widget.query,
        ),
        leading: IconButton(
          icon: Icon(JwIcons.chevron_left),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
        actions: [
          PopupMenuButton<int>(
            style: ButtonStyle(visualDensity: VisualDensity.compact),
            icon: Icon(JwIcons.three_dots_horizontal),
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
          ? LazyIndexedStack(
        index: currentTab,
        builders: [
              (context) => AllSearchTab(model: _searchModel),
              (context) => WolSearchTab(model: _searchModel),
              (context) => PublicationsSearchTab(model: _searchModel),
              (context) => VideosSearchTab(model: _searchModel),
              (context) => AudioSearchTab(model: _searchModel),
              (context) => BibleSearchTab(model: _searchModel),
              (context) => VersesSearchTab(model: _searchModel),
              (context) => ImagesSearchTab(model: _searchModel),
              (context) => NotesSearchTab(model: _searchModel),
              (context) => InputFieldsSearchTab(model: _searchModel),
              (context) => WikipediaSearchTab(model: _searchModel),
        ],
      )
          : getLoadingWidget(Theme.of(context).primaryColor),
    );
  }
}
