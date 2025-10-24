import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';

import '../../../../../core/utils/utils.dart';
import '../../../../../widgets/searchfield/searchfield_widget.dart';
import '../../../models/menu/local/publication_search_model.dart';


class PublicationSearchView extends StatefulWidget {
  final String query;
  final Publication publication;

  const PublicationSearchView({super.key, required this.query, required this.publication});

  @override
  _PublicationSearchViewState createState() => _PublicationSearchViewState();
}

class _PublicationSearchViewState extends State<PublicationSearchView> {
  late PublicationSearchModel _model;
  String _query = "";
  bool _exactMatch = false;
  bool _exactMatchVerse = false;
  int _sortMode = 0;

  final Map<int, bool> _expandedDocuments = {};
  final int _maxCharacters = 200;

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _model = PublicationSearchModel(widget.publication);
    searchQuery(_query);
  }

  Future<void> searchQuery(String query) async {
    _query = query;
    if (widget.publication.isBible()) {
      await _model.searchBibleVerses(widget.query, 1, newSearch: true);
    }
    else {
      await _model.searchDocuments(widget.query, 1, newSearch: true);
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
                    value: _exactMatch,
                    onChanged: (bool? value) {
                      setState(() {
                        _exactMatch = value ?? false;
                        _model.searchDocuments(_query, _exactMatch ? 2 : 1);
                      });
                    },
                  ),
                  const Text("Expression exacte"),
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
                final docId = doc['mepsDocumentId'] as int;
                final bool isExpanded = _expandedDocuments[docId] ?? false;

                // Paragraphes
                final List<dynamic> paragraphs = (doc['paragraphs'] as List?) ?? [];

                // Compte tous les caractères du document
                int totalChars = 0;
                for (final p in paragraphs) {
                  totalChars += (p['paragraphText'] as String).length;
                }

                // Décide si on tronque (mais jamais à l'intérieur d'un paragraphe)
                final bool shouldTruncate = totalChars > _maxCharacters && !isExpanded;

                // Calcule combien de paragraphes complets on affiche en mode réduit
                int visibleCount = paragraphs.length;
                if (shouldTruncate) {
                  int acc = 0;
                  visibleCount = 0;
                  for (final p in paragraphs) {
                    final int len = (p['paragraphText'] as String).length;
                    // On ajoute le paragraphe complet si on reste sous la limite
                    // ou si c'est le tout premier (toujours afficher au moins 1 paragraphe entier)
                    if (acc + len <= _maxCharacters || visibleCount == 0) {
                      acc += len;
                      visibleCount++;
                    } else {
                      break;
                    }
                  }
                }

                return Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF292929)
                      : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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

                                  if (paragraphs.isEmpty)
                                    const Text('...', style: TextStyle(fontSize: 18))
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Affiche uniquement des paragraphes complets
                                        for (int i = 0; i < visibleCount; i++) ...[
                                          GestureDetector(
                                            onTap: () {
                                              showPageDocument(
                                                widget.publication,
                                                docId,
                                                startParagraphId: paragraphs[i]['paragraphId'],
                                                endParagraphId: paragraphs[i]['paragraphId'],
                                                wordsSelected: _model.wordsSelectedDocument,
                                              );
                                            },
                                            child: RichText(
                                              text: TextSpan(
                                                children: (() {
                                                  List<InlineSpan> spans = [];
                                                  final String paragraphText = paragraphs[i]['paragraphText'] as String;
                                                  final List<dynamic> words = (paragraphs[i]['words'] as List?) ?? [];

                                                  int currentIndex = 0;
                                                  for (final word in words) {
                                                    final int start = word['startHighlight'] as int;
                                                    final int end = word['endHighlight'] as int;

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

                                                  return spans;
                                                })(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12), // Espace entre paragraphes
                                        ],

                                        // Bouton Voir plus / Voir moins
                                        if (shouldTruncate || isExpanded)
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _expandedDocuments[docId] = !isExpanded;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                            ),
                                            child: Text(
                                              isExpanded ? 'VOIR MOINS' : 'VOIR PLUS',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFc3c3c3)
                                    : const Color(0xFF626262),
                              ),
                              onSelected: (String value) {
                                print("Option sélectionnée : $value");
                              },
                              itemBuilder: (BuildContext context) => const [
                                PopupMenuItem(value: "option1", child: Text("Marque-pages")),
                                PopupMenuItem(value: "option2", child: Text("Envoyer le lien")),
                              ],
                            ),
                          ],
                        ),
                      ],
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
              Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _exactMatchVerse, // Make sure this is a defined state variable
                        onChanged: (bool? value) {
                          setState(() {
                            _exactMatchVerse = value ?? false;
                            // Assuming a method like _model.searchVerses exists
                            if(_exactMatchVerse) {
                              _model.searchBibleVerses(_query, 2); // 2 for exact match
                            }
                            else {
                              _model.searchBibleVerses(_query, 1); // 1 for general search
                            }
                          });
                        },
                      ),
                      const Text("Expression exacte"),
                    ],
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
                      items: const [
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
                    showPageBibleChapter(widget.publication, verse['bookNumber'], verse['chapterNumber'], firstVerse: verse['verseNumber'], lastVerse: verse['verseNumber'], wordsSelected: _model.wordsSelectedVerse);
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
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    (() {
                                      List<InlineSpan> spans = [];
                                      int currentIndex = 0;
                                      String verseText = verse['verse'] ?? '';

                                      List<Map<String, dynamic>> highlightedWords = List<Map<String, dynamic>>.from(verse['words'] ?? []);
                                      highlightedWords.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

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
                            itemBuilder: (BuildContext context) => const [
                              PopupMenuItem(value: "option1", child: Text("Marque-pages")),
                              PopupMenuItem(value: "option2", child: Text("Envoyer le lien")),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : const Color(0xFFf1f1f1),
        resizeToAvoidBottomInset: false,
        appBar: _isSearching
            ? AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isSearching = false;
              });
            },
          ),
          title: SearchFieldWidget(
            query: _query,
            onSearchTextChanged: (text) {
              widget.publication.wordsSuggestionsModel?.fetchSuggestions(text);
            },
            onSuggestionTap: (item) async {
              final String query = item.item!.query;

              setState(() {
                _isSearching = false;
              });

              searchQuery(query);

            },
            onSubmit: (query) async {
              setState(() {
                _isSearching = false;
              });

              searchQuery(query);
            },
            onTapOutside: (event) {
              setState(() {
                _isSearching = false;
              });
            },
            suggestionsNotifier: _model.publication.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([]),
          ),
        )
            : AppBar(
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
        body: widget.publication.isBible()
            ? Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'VERSETS'),
                Tab(text: 'DOCUMENTS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  versesList,
                  documentsList, // J'ai corrigé ici pour afficher documentsList
                ],
              ),
            ),
          ],
        )
            : documentsList,
      ),
    );
  }
}
