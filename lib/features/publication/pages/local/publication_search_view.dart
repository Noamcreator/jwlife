import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
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

class _PublicationSearchViewState extends State<PublicationSearchView> with SingleTickerProviderStateMixin {
  late PublicationSearchModel _model;
  String _query = "";
  bool _isExactMatch = false;
  int _searchScope = 0;
  int _sortMode = 1;

  final Map<int, bool> _expandedDocuments = {};

  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _model = PublicationSearchModel(widget.publication);
    searchQuery(_query, newSearch: true);
  }

  Future<void> searchQuery(String query, {bool newSearch = false, bool isExactMatch = false, int searchScope = 0, int sortMode = 0}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _query = query;
      _isExactMatch = isExactMatch;
      _searchScope = searchScope;
      _sortMode = sortMode;
    });

    try {
      if (widget.publication.isBible()) {
        await Future.wait([
          _model.searchBibleVerses(query, _isExactMatch, newSearch: newSearch),
          _model.searchDocuments(query, _searchScope, newSearch: newSearch),
        ]);
        _model.sortVerses(_sortMode);
      } else {
        await _model.searchDocuments(query, _searchScope, newSearch: newSearch);
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

  // --- UI BUILDERS (VERSES & DOCUMENTS) ---

  Widget _buildResultsList({required bool showVerses}) {
    if (_isLoading) {
      return Center(child: getLoadingWidget(Theme.of(context).primaryColor));
    }

    final results = showVerses ? _model.verses : _model.documents;
    final totalOccurrences = showVerses ? _model.nbWordResultsInVerses : _model.nbWordResultsInDocuments;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      // On garde toujours l'index 0 pour le header, même si results est vide
      itemCount: results.isEmpty ? 2 : results.length + 1, 
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(totalOccurrences, showVerses);
        }
        
        if (results.isEmpty) {
          return _buildEmptyState();
        }

        final item = results[index - 1];
        return showVerses ? _buildVerseItem(item) : _buildDocumentItem(item);
      },
    );
  }

  Widget _buildHeader(int totalResults, bool isVerseTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  totalResults == 0
                      ? i18n().search_results_none
                      : totalResults == 1
                          ? i18n().search_results_occurence
                          : i18n().search_results_occurences(formatNumber(totalResults)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if(!isVerseTab)
                _buildDropdown(
                  value: _searchScope,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(i18n().search_scope_article)),
                    DropdownMenuItem(value: 1, child: Text(i18n().search_scope_paragraph)),
                    DropdownMenuItem(value: 2, child: Text(i18n().search_scope_sentence)),
                  ],
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      searchQuery(_query, newSearch: false, searchScope: newValue, sortMode: _sortMode);
                    }
                  },
                ),
              if(isVerseTab)
                Row(
                  children: [
                    Checkbox(
                      value: _isExactMatch,
                      onChanged: (bool? value) {
                        searchQuery(_query, newSearch: false, isExactMatch: value ?? false, sortMode: _sortMode);
                      },
                    ),
                    Text(i18n().search_match_exact_phrase),
                  ],
                ),
            ],
          ),

          if(isVerseTab)
            Align(
              alignment: Alignment.centerRight,
              child: _buildDropdown(
                value: _sortMode,
                items: [
                  DropdownMenuItem(value: 0, child: Text(i18n().search_results_per_chronological)),
                  DropdownMenuItem(value: 1, child: Text(i18n().search_results_per_top_verses)),
                  DropdownMenuItem(value: 2, child: Text(i18n().search_results_per_occurences)),
                ],
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _sortMode = newValue;
                      _model.sortVerses(_sortMode);
                    });
                  }
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _buildDropdown({required int value, required List<DropdownMenuItem<int>> items, required ValueChanged<int?> onChanged}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white38 : Colors.black26, width: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          elevation: 2,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          value: value,
          dropdownColor: isDark ? const Color(0xFF292929) : Colors.white,
          onChanged: onChanged,
          items: items,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
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

  // --- LOGIQUE D'AFFICHAGE DES ITEMS ---

  Widget _buildDocumentItem(Map<String, dynamic> doc) {
    final docId = doc['mepsDocumentId'] as int;
    final bool isExpanded = _expandedDocuments[docId] ?? false;
    final List<dynamic> paragraphs = (doc['paragraphs'] as List?) ?? [];
    final int occurrences = doc['occurrences'] ?? 0;

    final document = widget.publication.documentsManager?.getDocumentFromMepsDocumentId(docId);
    final content = document?.content;
    if(content == null) return const SizedBox.shrink();
    final decodedContent = decodeBlobParagraph(content, widget.publication.hash!);

    final Color highlightColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF86761e) : const Color(0xFFfff9bb);
    final Color textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF292929);
    final Color linkColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFa0b9e2) : const Color(0xFF4a6da7);
    final Color subtitleColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54;

    const TextStyle baseTextStyle = TextStyle(fontSize: 16.5, fontFamily: 'Roboto', height: 1.3);
    const TextStyle boldTextStyle = TextStyle(fontSize: 16.5, fontFamily: 'Roboto', fontWeight: FontWeight.bold, height: 1.3);

    return Card(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 4, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: linkColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (occurrences > 0)
                      Text(
                        occurrences == 1 ? i18n().search_results_occurence : i18n().search_results_occurences(formatNumber(occurrences)),
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    _buildPopupMenu(doc['title'], docId),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (paragraphs.isEmpty) return const SizedBox.shrink();

                    List<InlineSpan> spans = [];
                    if (isExpanded) {
                      for (int i = 0; i < paragraphs.length; i++) {
                        spans.add(_buildParagraphSpan(paragraphs[i], docId, decodedContent, textColor, highlightColor, baseTextStyle, boldTextStyle));
                        if (i < paragraphs.length - 1) spans.add(const TextSpan(text: '\n\n'));
                      }
                    } 
                    else {
                      spans.add(_buildParagraphSpan(paragraphs[0], docId, decodedContent, textColor, highlightColor, baseTextStyle, boldTextStyle));
                    }

                    final fullTextSpan = TextSpan(children: spans);
                    final tp = TextPainter(
                      text: fullTextSpan,
                      maxLines: 3, // Plus petit par défaut (3 lignes au lieu de 5)
                      textDirection: TextDirection.ltr,
                    )..layout(maxWidth: constraints.maxWidth);

                    final bool isParagraphTooLong = tp.didExceedMaxLines;
                    final bool hasMoreParagraphs = paragraphs.length > 1;
                    final bool showButton = isParagraphTooLong || hasMoreParagraphs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text.rich(
                            fullTextSpan,
                            maxLines: isExpanded ? null : 3,
                            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                        ),
                        if (showButton)
                          GestureDetector(
                            onTap: () => setState(() => _expandedDocuments[docId] = !isExpanded),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                isExpanded ? i18n().search_show_less.toUpperCase() : i18n().search_show_more.toUpperCase(),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: linkColor),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildParagraphSpan(Map<String, dynamic> p, int docId, List<int> decodedContent, Color textColor, Color highlightColor, TextStyle base, TextStyle bold) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        showPageDocument(
          widget.publication,
          docId,
          startParagraphId: p['paragraphId'],
          endParagraphId: p['paragraphId'],
          wordsSelected: _model.wordsSelectedDocument,
        );
      };

    final begin = p['begin'] as int;
    final end = p['end'] as int;
    final paraHtml = utf8.decode(decodedContent.sublist(begin, end));

    return TextSpan(
      children: _buildHighlightedTextSpans(
        parse(paraHtml).body?.text ?? '',
        (p['words'] as List?) ?? [],
        textColor,
        highlightColor,
        base,
        bold,
        recognizer,
      ),
    );
  }

  Widget _buildVerseItem(Map<String, dynamic> verse) {
    final verseId = verse['verseId'];
    final int occurrences = verse['occurrences'] ?? 0;

    final Color highlightColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF86761e) : const Color(0xFFfff9bb);
    final Color textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF292929);
    final Color linkColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFa0b9e2) : const Color(0xFF4a6da7);
    final Color subtitleColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54;

    const TextStyle baseTextStyle = TextStyle(fontSize: 16.5, fontFamily: 'Roboto', height: 1.3);
    const TextStyle boldTextStyle = TextStyle(fontSize: 16.5, fontFamily: 'Roboto', fontWeight: FontWeight.bold, height: 1.3);

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
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        margin: const EdgeInsets.symmetric(vertical: 2),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      verseRef,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: linkColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (occurrences > 0)
                    Text(
                       occurrences == 1 ? i18n().search_results_occurence : i18n().search_results_occurences(formatNumber(occurrences)),
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  _buildPopupMenu(verseRef, verseId),
                ],
              ),
              RichText(
                text: TextSpan(
                  children: _buildHighlightedTextSpans(
                    verse['verse'] ?? '',
                    List<Map<String, dynamic>>.from(verse['words'] ?? []),
                    textColor, highlightColor, baseTextStyle, boldTextStyle, null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildHighlightedTextSpans(
    String text, 
    List<dynamic> words, 
    Color textColor, 
    Color highlightColor, 
    TextStyle baseStyle, 
    TextStyle boldStyle, 
    GestureRecognizer? recognizer
  ) {
    // 1. On trim le texte original
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) return [];

    // 2. On calcule l'offset (combien de caractères ont été supprimés au début)
    // Cela permet de décaler les index startHighlight/endHighlight pour qu'ils correspondent au nouveau texte
    final int leadingSpaces = text.length - text.trimLeft().length;

    List<InlineSpan> spans = [];
    int currentIndex = 0;
    
    List<Map<String, dynamic>> highlightedWords = List<Map<String, dynamic>>.from(words);
    highlightedWords.sort((a, b) => (a['startHighlight'] as int).compareTo(b['startHighlight'] as int));

    for (final word in highlightedWords) {
      // 3. Ajustement des index par rapport au trim
      final int start = (word['startHighlight'] as int) - leadingSpaces;
      final int end = (word['endHighlight'] as int) - leadingSpaces;

      // Sécurité : on ignore ce qui sort des nouvelles bornes du texte trimmé
      if (start < currentIndex || end > trimmedText.length || start >= end || start < 0) continue;

      if (start > currentIndex) {
        spans.add(TextSpan(
          text: trimmedText.substring(currentIndex, start), 
          style: baseStyle.copyWith(color: textColor), 
          recognizer: recognizer
        ));
      }

      spans.add(TextSpan(
        text: trimmedText.substring(start, end), 
        style: boldStyle.copyWith(color: textColor, backgroundColor: highlightColor), 
        recognizer: recognizer
      ));
      currentIndex = end;
    }

    if (currentIndex < trimmedText.length) {
      spans.add(TextSpan(
        text: trimmedText.substring(currentIndex), 
        style: baseStyle.copyWith(color: textColor), 
        recognizer: recognizer
      ));
    }

    return spans;
  }
  
  Widget _buildPopupMenu(String title, int docId) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFc3c3c3) : const Color(0xFF626262)),
      onSelected: (String value) {
        if (value == 'bookmark') {
          showBookmarkDialog(context, widget.publication, mepsDocumentId: docId, title: title, snippet: '', blockType: 0, blockIdentifier: null);
        } else {
          String uri = JwOrgUri.document(wtlocale: widget.publication.mepsLanguage.symbol, docid: docId).toString();
          SharePlus.instance.share(ShareParams(title: title, uri: Uri.tryParse(uri)));
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(value: "bookmark", child: Text(i18n().action_bookmarks)),
        PopupMenuItem(value: "link", child: Text(i18n().action_open_in_share)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isBible = widget.publication.isBible();
    Widget body;
    if (isBible) {
      body = DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).hintColor,
              indicatorColor: Theme.of(context).primaryColor,
              tabAlignment: TabAlignment.fill, isScrollable: false,
              tabs: [Tab(text: i18n().label_research_verses), Tab(text: i18n().search_results_articles.toUpperCase())],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildResultsList(showVerses: true), _buildResultsList(showVerses: false)],
              ),
            ),
          ],
        ),
      );
    } else {
      body = _buildResultsList(showVerses: false);
    }

    return AppPage(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFf1f1f1),
      appBar: _isSearching
          ? AppBar(
              titleSpacing: 0.0,
              leading: IconButton(icon: const Icon(JwIcons.chevron_left), onPressed: () => setState(() => _isSearching = false)),
              title: SearchFieldWidget(
                query: _query,
                onSearchTextChanged: (text) => widget.publication.wordsSuggestionsModel?.fetchSuggestions(text),
                onSuggestionTap: (item) async {
                  setState(() => _isSearching = false);
                  await searchQuery(item.item!.query, newSearch: true, searchScope: _searchScope, sortMode: _sortMode);
                },
                onSubmit: (query) async {
                  setState(() => _isSearching = false);
                  await searchQuery(query, newSearch: true, searchScope: _searchScope, sortMode: _sortMode);
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
      body: body,
    );
  }
}