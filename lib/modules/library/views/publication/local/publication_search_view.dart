import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/databases/Audio.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/modules/library/models/publications/local/publication_search_model.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:jwlife/widgets/searchfield_widget.dart';

import 'document/document_view.dart';

class PublicationSearchView extends StatefulWidget {
  final String query;
  final Publication publication;
  final DocumentsManager documentsManager;
  final List<Audio> audios;

  const PublicationSearchView({super.key, required this.query, required this.publication, required this.documentsManager, required this.audios});

  @override
  _PublicationSearchViewState createState() => _PublicationSearchViewState();
}

class _PublicationSearchViewState extends State<PublicationSearchView> {
  late PublicationSearchModel _model;
  String _query = "";
  bool exactMatch = false;
  int _sortMode = 0;

  bool _isSearching = false;
  List<Map<String, dynamic>> suggestions = [];

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _model = PublicationSearchModel(widget.publication, widget.documentsManager);
    searchQuery(_query);
  }

  Future<void> searchQuery(String query) async {
    _query = query;
    if (widget.publication.isBible()) {
      await _model.searchBibleVerses(widget.query);
      //await _model.searchDocuments(widget.query);
    }
    else {
      await _model.searchDocuments(widget.query);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    Widget documentsList = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_model.nbWordResultsInDocuments} résultats",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Checkbox(
                    value: exactMatch,
                    onChanged: (bool? value) {
                      setState(() {
                        exactMatch = value ?? false;
                      });
                    },
                  ),
                  const Text("Expression exacte")
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _model.documents.length,
              itemBuilder: (context, index) {
                final doc = _model.documents[index];
                return GestureDetector(
                  onTap: () {
                    showPage(
                      context,
                      DocumentView(
                        publication: widget.publication,
                        audios: widget.audios,
                        mepsDocumentId: doc['mepsDocumentId'],
                        startParagraphId: doc['paragraphId'],
                        endParagraphId: doc['paragraphId'],
                      ),
                    );
                  },
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF292929)
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFa0b9e2)
                                        : const Color(0xFF4a6da7),
                                  ),
                                ),
                                Text(
                                  "${doc['occurences']} résultats",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                  doc['paragraph'] == '' ? const Text('...', style: TextStyle(fontSize: 18)) : RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: doc['paragraph'].substring(0, doc['wordPosition']),
                                          style: TextStyle(fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF292929)),
                                        ),
                                        TextSpan(
                                          text: doc['paragraph'].substring(doc['wordPosition'], doc['wordPosition'] + doc['wordLength']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF292929),
                                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF86761e) : Color(0xFFfff9bb),
                                          ),
                                        ),
                                        TextSpan(
                                          text: doc['paragraph'].substring(doc['wordPosition'] + doc['wordLength']),
                                          style: TextStyle(fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF292929)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFc3c3c3)
                                    : const Color(0xFF626262)),
                            onSelected: (String value) {
                              print("Option sélectionnée : $value");
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(value: "option1", child: Text("Marque-pages")),
                              const PopupMenuItem(value: "option2", child: Text("Envoyer le lien")),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    Widget versesList = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_model.nbWordResultsInVerses} résultats",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF626262), width: 0.5),
                ),
                child: DropdownButton<int>(
                  elevation: 0,
                  isDense: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  value: _sortMode,
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF292929)
                      : Colors.white,
                  underline: SizedBox.shrink(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _sortMode = newValue ?? 0;
                      _model.sortVerses(newValue ?? 0);
                    });
                  },
                  items: [
                    DropdownMenuItem<int>(
                      value: 0,
                      child: Text("CHRONOLOGIQUE"),
                    ),
                    DropdownMenuItem<int>(
                      value: 1,
                      child: Text("LES PLUS CITÉS"),
                    ),
                    DropdownMenuItem<int>(
                      value: 2,
                      child: Text("OCCURRENCES"),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _model.verses.length,
              itemBuilder: (context, index) {
                final verse = _model.verses[index];
                return GestureDetector(
                  onTap: () {
                    showPage(
                      context,
                      DocumentView.bible(
                        bible: widget.publication,
                        audios: widget.audios,
                        book: verse['bookNumber'],
                        chapter: verse['chapterNumber'],
                      ),
                    );
                  },
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF292929)
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      JwLifeApp.bibleCluesInfo.getVerses(verse['bookNumber'], verse['chapterNumber'], verse['verseNumber'], verse['bookNumber'], verse['chapterNumber'], verse['verseNumber']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFa0b9e2)
                                            : const Color(0xFF4a6da6),
                                      ),
                                    ),
                                    Text(
                                      "${verse['occurences']} résultats",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    ]
                                ),
                                const SizedBox(height: 10),
                                Text(verse['verse'], style: TextStyle(fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF292929))),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFc3c3c3)
                                    : const Color(0xFF626262)),
                            onSelected: (String value) {
                              print("Option sélectionnée : $value");
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(value: "option1", child: Text("Marque-pages")),
                              const PopupMenuItem(value: "option2", child: Text("Envoyer le lien")),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return widget.publication.isBible()
        ? DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_query, style: textStyleTitle),
              Text(
                widget.publication.issueTitle.isNotEmpty
                    ? widget.publication.issueTitle
                    : widget.publication.shortTitle,
                style: textStyleSubtitle,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(JwIcons.magnifying_glass),
              onPressed: () {
                History.showHistoryDialog(context);
              },
            ),
            IconButton(
              icon: const Icon(JwIcons.arrow_circular_left_clock),
              onPressed: () {
                History.showHistoryDialog(context);
              },
            ),
          ],
        ),
        body: Column(
            children: [
              TabBar(
                isScrollable: true, // Permet d'utiliser TabAlignment.start
                tabs: [
                  Tab(text: "VERSETS"),
                  Tab(text: "DOCUMENTS"),
                ],
              ),
              Expanded(child: TabBarView(
                children: [
                  versesList,
                  documentsList,
                ],
              ),
              )
            ]
        )
      ),
    ) : Scaffold(
      appBar: _isSearching ? AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isSearching = false;
              });
            },
          ),
          title: SearchFieldWidget(
            query: _query,
            onSearchTextChanged: (text) {
              setState(() {
                fetchSuggestions(text);
              });
            },
            onSuggestionTap: (item) async {
              // Accéder à l'élément encapsulé
              String text = item.item!['query'];  // Utilise 'item.item' au lieu de 'item['query']'
              await searchQuery(text);
              setState(() {
                _isSearching = false;
              });
            },
            onSubmit: (text) async {
              await searchQuery(text);
              setState(() {
                _isSearching = false;
              });
            },
            onTapOutside: (event) {
              setState(() {
                _isSearching = false;
              });
            },
            suggestions: suggestions,
          )
      ) : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_query, style: textStyleTitle),
            Text(
              widget.publication.issueTitle.isNotEmpty
                  ? widget.publication.issueTitle
                  : widget.publication.shortTitle,
              style: textStyleSubtitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: () {
              History.showHistoryDialog(context);
            },
          ),
        ],
      ),
      body: documentsList,
    );
  }

  Future<void> fetchSuggestions(String text) async {
    List<Map<String, dynamic>> suggestionsForWord = [];

    if (text.isEmpty) {
      setState(() {
        suggestions.clear();
      });
      return;
    }

    List<String> words = text.split(' ');
    for (String word in words) {
      suggestionsForWord = await widget.documentsManager.database.rawQuery(
        '''
      SELECT Word
      FROM Word
      WHERE Word LIKE ?
    ''',
        ['$word%'], // Seulement les mots qui commencent par "word"
      );
    }

    setState(() {
      suggestions.clear();

      for (Map<String, dynamic> suggestion in suggestionsForWord) {
        suggestions.add({
          'type': 0,
          'query': suggestion['Word'],
        });
      }
    });
  }
}
