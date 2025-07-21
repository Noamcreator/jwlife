import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/widgets/searchfield_widget.dart';

import '../../../../../core/utils/utils.dart';
import '../../../models/local/publication_search_model.dart';
import '../../document/local/document_page.dart';
import '../../document/local/documents_manager.dart';

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
    }
    else {
      await _model.searchDocuments(widget.query, 1);
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
                        if(exactMatch) {
                          _model.searchDocuments(_query, 2);
                        }
                        else {
                          _model.searchDocuments(_query, 1);
                        }
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
                    List<int> wordsSelected = [];
                    for (var paragraph in doc['paragraphs']) {
                      for (var word in paragraph['words']) {
                        printTime(word['index']);
                        wordsSelected.add(word['index']);
                      }
                    }
                    showPage(
                      context,
                      DocumentPage(
                        publication: widget.publication,
                        audios: widget.audios,
                        mepsDocumentId: doc['mepsDocumentId'],
                        startParagraphId: doc['paragraphs'][0]['paragraphId'],
                        endParagraphId: doc['paragraphs'][0]['paragraphId'],
                        wordsSelected: _model.wordsSelectedDocument
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
                                  "${doc['occurrences']} résultats",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                if (doc['paragraphs'] == null || doc['paragraphs'].isEmpty)
                                  const Text('...', style: TextStyle(fontSize: 18))
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: (() {
                                      final sortedParagraphs = List<Map<String, dynamic>>.from(doc['paragraphs']);
                                      sortedParagraphs.sort((a, b) => (a['paragraphId'] as int).compareTo(b['paragraphId'] as int));

                                      return List.generate(sortedParagraphs.length * 2 - 1, (index) {
                                        if (index.isOdd) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 5),
                                            child: Text('…', style: TextStyle(fontSize: 18)),
                                          );
                                        }

                                        final para = sortedParagraphs[index ~/ 2];
                                        final paragraphText = para['paragraphText'] as String;
                                        final words = para['words'] as List<dynamic>;

                                        List<InlineSpan> spans = [];
                                        int currentIndex = 0;

                                        for (final word in words) {
                                          final start = word['startHighlight'] as int;
                                          final end = word['endHighlight'] as int;

                                          if (start < currentIndex || end > paragraphText.length) continue;

                                          if (start > currentIndex) {
                                            spans.add(TextSpan(
                                              text: paragraphText.substring(currentIndex, start),
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : const Color(0xFF292929),
                                              ),
                                            ));
                                          }

                                          spans.add(TextSpan(
                                            text: paragraphText.substring(start, end),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF292929),
                                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF86761e)
                                                  : const Color(0xFFfff9bb),
                                            ),
                                          ));

                                          currentIndex = end;
                                        }

                                        if (currentIndex < paragraphText.length) {
                                          spans.add(TextSpan(
                                            text: paragraphText.substring(currentIndex),
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF292929),
                                            ),
                                          ));
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: RichText(text: TextSpan(children: spans)),
                                        );
                                      });
                                    })(),
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
                              printTime("Option sélectionnée : $value");
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
                    printTime(verse.toString());

                    showPage(
                      context,
                      DocumentPage.bible(
                        bible: widget.publication,
                        audios: widget.audios,
                        book: verse['bookNumber'],
                        chapter: verse['chapterNumber'],
                        firstVerse: verse['verseNumber'],
                        lastVerse: verse['verseNumber'],
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
                                      "${verse['occurrences']} résultats",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    ]
                                ),
                                const SizedBox(height: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    (() {
                                      List<InlineSpan> spans = [];
                                      int currentIndex = 0;
                                      String verseText = verse['verse'] ?? '';

                                      // Tri des mots par position de début pour éviter les incohérences
                                      List<Map<String, dynamic>> highlightedWords = List<Map<String, dynamic>>.from(verse['words'] ?? []);
                                      highlightedWords.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

                                      final isDark = Theme.of(context).brightness == Brightness.dark;

                                      for (final word in highlightedWords) {
                                        final start = word['startHighlight'] as int;
                                        final end = word['endHighlight'] as int;

                                        if (start < currentIndex || end > verseText.length) continue;

                                        if (start > currentIndex) {
                                          spans.add(TextSpan(
                                            text: verseText.substring(currentIndex, start),
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF292929),
                                            ),
                                          ));
                                        }

                                        spans.add(TextSpan(
                                          text: verseText.substring(start, end),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : const Color(0xFF292929),
                                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF86761e)
                                                : const Color(0xFFfff9bb),
                                          ),
                                        ));

                                        currentIndex = end;
                                      }

                                      if (currentIndex < verseText.length) {
                                        spans.add(TextSpan(
                                          text: verseText.substring(currentIndex),
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : const Color(0xFF292929),
                                          ),
                                        ));
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: RichText(text: TextSpan(children: spans)),
                                      );
                                    })(),
                                  ],
                                )
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFc3c3c3)
                                    : const Color(0xFF626262)),
                            onSelected: (String value) {
                              printTime("Option sélectionnée : $value");
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
                  versesList,
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
