import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../app/app_page.dart';
import '../../../../../i18n/i18n.dart';
import '../../../../../widgets/searchfield/searchfield_widget.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/widgets_utils.dart';
import '../../models/menu/local/publication_search_model.dart';

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
  int _sortMode = 0;

  final Map<int, bool> _expandedDocuments = {};
  final int _maxCharacters = 400;

  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _model = PublicationSearchModel(widget.publication);
    searchQuery(_query, newSearch: true);
  }

  Future<void> searchQuery(String query, {bool newSearch = false, bool isExactMatch = false, int sortMode = 0}) async {
    _isLoading = true;
    _query = query;
    _exactMatch = isExactMatch;
    _sortMode = sortMode;

    try {
      if (widget.publication.isBible()) {
        await _model.searchBibleVerses(query, isExactMatch ? 2 : 1, newSearch: newSearch);
        _model.sortVerses(_sortMode);
      } else {
        await _model.searchDocuments(query, isExactMatch ? 2 : 1, newSearch: newSearch);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _expandedDocuments.clear();
        });
      }
    }
  }

  Widget _buildDocumentItem(Map<String, dynamic> doc) {
    final docId = doc['mepsDocumentId'] as int;
    final bool isExpanded = _expandedDocuments[docId] ?? false;
    final List<dynamic> paragraphs = (doc['paragraphs'] as List?) ?? [];

    int totalChars = paragraphs.map((p) => (p['paragraphText'] as String).length).fold(0, (a, b) => a + b);
    final bool shouldTruncate = totalChars > _maxCharacters && !isExpanded;

    int visibleCount = paragraphs.length;
    if (shouldTruncate) {
      int acc = 0;
      visibleCount = 0;
      for (final p in paragraphs) {
        final int len = (p['paragraphText'] as String).length;
        if (acc + len <= _maxCharacters || visibleCount == 0) {
          acc += len;
          visibleCount++;
        } else {
          break;
        }
      }
    }

    final Color highlightColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF86761e)
        : const Color(0xFFfff9bb);
    final Color textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF292929);
    final Color linkColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFa0b9e2)
        : const Color(0xFF4a6da7);
    const TextStyle baseTextStyle = TextStyle(fontSize: 18, fontFamily: 'Roboto');
    const TextStyle boldTextStyle = TextStyle(fontSize: 18, fontFamily: 'Roboto', fontWeight: FontWeight.bold);

    return Card(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: linkColor),
                      ),
                      Text(
                        doc['occurrences'] == 0 ? i18n().search_results_none : doc['occurrences'] == 1 ? i18n().search_results_occurence : i18n().search_results_occurences(formatNumber(doc['occurrences'])),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                _buildPopupMenu(doc['title'], docId),
              ],
            ),
            if (paragraphs.isEmpty)
              const Text('...', style: baseTextStyle)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          children: _buildHighlightedTextSpans(
                            (paragraphs[i]['paragraphText'] as String).trim(),
                            (paragraphs[i]['words'] as List?) ?? [],
                            textColor,
                            highlightColor,
                            baseTextStyle,
                            boldTextStyle,
                          ),
                        ),
                      ),
                    ),
                    if (i < visibleCount - 1)
                      const SizedBox(height: 12),
                  ],

                  if (shouldTruncate || isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ElevatedButton(
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
                          isExpanded ? i18n().search_show_less : i18n().search_show_more,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseItem(Map<String, dynamic> verse) {
    final Color highlightColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF86761e)
        : const Color(0xFFfff9bb);
    final Color textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF292929);
    final Color linkColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFa0b9e2)
        : const Color(0xFF4a6da6);
    const TextStyle baseTextStyle = TextStyle(fontSize: 18, fontFamily: 'Roboto');
    const TextStyle boldTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Roboto');

    String verseRef = JwLifeApp.bibleCluesInfo.getVerses(
        verse['bookNumber'], verse['chapterNumber'], verse['verseNumber'],
        verse['bookNumber'], verse['chapterNumber'], verse['verseNumber'],
    );

    return GestureDetector(
      onTap: () {
        showPageBibleChapter(
          widget.publication,
          verse['bookNumber'],
          verse['chapterNumber'],
          firstVerse: verse['verseNumber'],
          lastVerse: verse['verseNumber'],
          wordsSelected: _model.wordsSelectedVerse,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    verseRef,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: linkColor),
                  ),
                  Text(
                    verse['occurrences'] == 0 ? i18n().search_results_none : verse['occurrences'] == 1 ? i18n().search_results_occurence : i18n().search_results_occurences(formatNumber(verse['occurrences'])),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: _buildHighlightedTextSpans(
                    verse['verse'] ?? '',
                    List<Map<String, dynamic>>.from(verse['words'] ?? []),
                    textColor,
                    highlightColor,
                    baseTextStyle,
                    boldTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildHighlightedTextSpans(String text, List<dynamic> words, Color textColor, Color highlightColor, TextStyle baseStyle, TextStyle boldStyle) {
    List<InlineSpan> spans = [];
    int currentIndex = 0;

    List<Map<String, dynamic>> highlightedWords = List<Map<String, dynamic>>.from(words);
    highlightedWords.sort((a, b) => (a['startHighlight'] as int).compareTo(b['startHighlight'] as int));

    for (final word in highlightedWords) {
      final int start = word['startHighlight'] as int;
      final int end = word['endHighlight'] as int;

      if (start < currentIndex || end > text.length || start >= end) continue;

      if (start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, start), style: baseStyle.copyWith(color: textColor)));
      }

      spans.add(TextSpan(
        text: text.substring(start, end),
        style: boldStyle.copyWith(color: textColor, backgroundColor: highlightColor),
      ));

      currentIndex = end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle.copyWith(color: textColor)));
    }

    return spans;
  }

  Widget _buildPopupMenu(String title, int docId) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFc3c3c3)
            : const Color(0xFF626262),
      ),
      onSelected: (String value) {
        if(value == 'bookmark') {
          showBookmarkDialog(context, widget.publication, mepsDocumentId: docId, title: title, snippet: '', blockType: 0, blockIdentifier: null);
        }
        else {
          String uri = JwOrgUri.document(
              wtlocale: widget.publication.mepsLanguage.symbol,
              docid: docId,
          ).toString();

        SharePlus.instance.share(
          ShareParams(
            title: title,
            uri: Uri.tryParse(uri),
          ),
        );
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(value: "bookmark", child: Text(i18n().action_bookmarks)),
        PopupMenuItem(value: "link", child: Text(i18n().action_open_in_share)),
      ],
    );
  }

  Widget _buildUnifiedResultsList() {
  if (_isLoading) {
    return getLoadingWidget(Theme.of(context).primaryColor);
  }

  bool isBible = widget.publication.isBible();
  int totalResults = (isBible ? _model.nbWordResultsInVerses : 0) + _model.nbWordResultsInDocuments;
  
  // On garde toujours au moins 2 éléments si vide (l'en-tête + le message vide)
  // Sinon : l'en-tête (1) + les versets + les documents
  int totalItems = (totalResults == 0) 
      ? 2 
      : (isBible ? _model.verses.length : 0) + _model.documents.length + 1;

  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    itemCount: totalItems,
    itemBuilder: (context, index) {
      // --- INDEX 0 : L'EN-TÊTE (Toujours affiché) ---
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  totalResults == 0 ? i18n().search_results_none : totalResults == 1 ? i18n().search_results_occurence : i18n().search_results_occurences(formatNumber(totalResults)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _exactMatch,
                        onChanged: (bool? value) {
                          searchQuery(_query, newSearch: false, isExactMatch: value ?? false, sortMode: _sortMode);
                        },
                      ),
                      Text(i18n().search_match_exact_phrase),
                    ],
                  ),
                  if (isBible)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF626262), width: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          elevation: 0,
                          isDense: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          value: _sortMode,
                          dropdownColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF292929)
                              : Colors.white,
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _sortMode = newValue;
                                _model.sortVerses(_sortMode);
                              });
                            }
                          },
                          items: [
                            DropdownMenuItem<int>(value: 0, child: Text(i18n().search_results_per_chronological, style: TextStyle(fontSize: 14))),
                            DropdownMenuItem<int>(value: 1, child: Text(i18n().search_results_per_top_verses, style: TextStyle(fontSize: 14))),
                            DropdownMenuItem<int>(value: 2, child: Text(i18n().search_results_per_occurences, style: TextStyle(fontSize: 14))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }

      // --- INDEX 1 : État vide (si aucun résultat) ---
      if (totalResults == 0 && index == 1) {
        return Padding(
          padding: const EdgeInsets.only(top: 100), // Centre visuellement sous l'en-tête
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(JwIcons.magnifying_glass, size: 60, color: Theme.of(context).hintColor),
                const SizedBox(height: 20),
                Text(
                  i18n().message_no_topics_found,
                  style: TextStyle(fontSize: 18, color: Theme.of(context).hintColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      // --- AUTRES INDEX : Les résultats réels ---
      final resultIndex = index - 1;
      
      if (isBible) {
        if (resultIndex < _model.verses.length) {
          return _buildVerseItem(_model.verses[resultIndex]);
        }
        else {
          final docIndex = resultIndex - _model.verses.length;
          if (docIndex >= 0 && docIndex < _model.documents.length) {
            return _buildDocumentItem(_model.documents[docIndex]);
          }
          return const SizedBox.shrink();
        }
      }
      else {
        // Pour les publications non-Bible, on s'assure de ne pas dépasser la taille
        if (resultIndex < _model.documents.length) {
          return _buildDocumentItem(_model.documents[resultIndex]);
        }
        return const SizedBox.shrink();
      }
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return AppPage(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : const Color(0xFFf1f1f1),
      appBar: _isSearching
          ? AppBar(
        titleSpacing: 0.0,
        leading: IconButton(
          icon: const Icon(JwIcons.chevron_left),
          onPressed: () => setState(() => _isSearching = false),
        ),
        title: SearchFieldWidget(
          query: _query,
          onSearchTextChanged: (text) {
            widget.publication.wordsSuggestionsModel?.fetchSuggestions(text);
          },
          onSuggestionTap: (item) async {
            final String query = item.item!.query;
            setState(() => _isSearching = false);
            await searchQuery(query, newSearch: true, isExactMatch: _exactMatch, sortMode: _sortMode);
          },
          onSubmit: (query) async {
            setState(() => _isSearching = false);
            await searchQuery(query, newSearch: true, isExactMatch: _exactMatch, sortMode: _sortMode);
          },
          onTapOutside: (event) => setState(() => _isSearching = false),
          suggestionsNotifier: _model.publication.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([]),
        ),
      )
          : JwLifeAppBar(
        title: _query,
        subTitle: widget.publication.getShortTitle(),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: (BuildContext context) {
              widget.publication.wordsSuggestionsModel ??= WordsSuggestionsModel(widget.publication);
              setState(() => _isSearching = true);
            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (BuildContext context) => JwLifeApp.history.showHistoryDialog(context),
          ),
        ],
      ),
      body: _buildUnifiedResultsList(),
    );
  }
}