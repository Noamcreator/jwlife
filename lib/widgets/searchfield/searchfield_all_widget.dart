
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/decoration.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/input_decoration.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/searchfield.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/searchfield_list_item.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/icons.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_database.dart';
import '../../core/utils/utils_document.dart';
import '../../data/databases/catalog.dart';
import '../../data/models/audio.dart';
import '../../data/models/meps_language.dart';
import '../../data/models/video.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../data/repositories/PublicationRepository.dart';
import '../../features/home/pages/search/search_page.dart';
import '../../features/home/pages/search/suggestion.dart';
import '../../i18n/i18n.dart';
import '../image_cached_widget.dart';

class SearchFieldAll extends StatefulWidget {
  final void Function()? onClose;
  final bool? autofocus;
  final String? initialText;

  const SearchFieldAll({super.key, this.onClose, this.autofocus, this.initialText});

  @override
  State<SearchFieldAll> createState() => _SearchFieldAllState();
}

class _SearchFieldAllState extends State<SearchFieldAll> {
  late TextEditingController _controller;
  List<SuggestionItem> _suggestions = [];
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SearchField<SuggestionItem>(
      controller: _controller,
      animationDuration: const Duration(milliseconds: 300),
      itemHeight: 50,
      autofocus: widget.autofocus ?? true,
      offset: Directionality.of(context) == TextDirection.ltr ? const Offset(-45, 55) : const Offset(10, 55),
      maxSuggestionsInViewPort: 10,
      maxSuggestionBoxHeight: 200,
      suggestionState: Suggestion.expand,
      searchInputDecoration: SearchInputDecoration(
        hintText: i18n().search_hint,
        searchStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
        fillColor: isDark ? const Color(0xFF1f1f1f) : const Color(0xFFf1f1f1),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        cursorColor: isDark ? Colors.white : Colors.black,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
        suffixIcon: GestureDetector(
          child: Container(
            color: const Color(0xFF345996),
            margin: const EdgeInsets.only(left: 2),
            child: const Icon(JwIcons.magnifying_glass, color: Colors.white),
          ),
          onTap: () {
            widget.onClose?.call();
            showPage(SearchPage(query: _controller.text));
          },
        ),
      ),
      suggestionsDecoration: SuggestionDecoration(
        color: isDark ? const Color(0xFF1f1f1f) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        width: MediaQuery.of(context).size.width - 15,
      ),
      suggestions: _suggestions.map(_buildSuggestionItem).toList(),
      onSearchTextChanged: (text) {
        _fetchSuggestions(text);
        return [];
      },
      onSuggestionTap: _handleTap,
      onSubmit: (text) {
        widget.onClose?.call();
        showPage(SearchPage(query: text));
      },
      onTapOutside: (_) => widget.onClose?.call(),
    );
  }

  SearchFieldListItem<SuggestionItem> _buildSuggestionItem(SuggestionItem item) {
    return SearchFieldListItem<SuggestionItem>(
      item.title,
      item: item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Row(
              children: [
                item.image?.isNotEmpty ?? false ? ImageCachedWidget(
                  imageUrl: item.image!,
                  width: 40,
                  height: 40,
                )
                    : SizedBox(width: 40, height: 40, child: Icon(item.type == 'bible' ? JwIcons.bible : JwIcons.magnifying_glass, color: Colors.grey)),
                const SizedBox(width: 10),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TextStyle(fontSize: item.subtitle?.isNotEmpty ?? false ? 16 : 20), overflow: TextOverflow.ellipsis),
                  if (item.subtitle?.isNotEmpty ?? false)
                    Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (item.type == 'video' || item.type == 'audio') const SizedBox(width: 10),
            if (item.type == 'video' || item.type == 'audio')
              Icon(item.type == 'audio' ? JwIcons.music : JwIcons.video),

            if (item.type == 'wolTopic') const SizedBox(width: 10),
            if (item.label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : const Color(0xFFc0c0c0),
                ),
                child: Text(
                  item.label!,
                  style: const TextStyle(color: Colors.white),
                )
              )
          ],
        ),
      ),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    List<SuggestionItem> newSuggestions = [];

    final trimmedQuery = query.trim();

    final requestId = ++_latestRequestId;
    setState(() {
      _suggestions.clear();
    });

    String normalizedQuery = normalize(query).toLowerCase();
    MepsLanguage mepsLanguage = JwLifeSettings.instance.currentLanguage.value;

    String apiWol = 'https://wol.jw.org/wol/sg/${mepsLanguage.rsConf}/${mepsLanguage.lib}?q=$query';
    printTime(apiWol);
    final response = await Api.httpGetWithHeaders(apiWol, responseType: ResponseType.json);

    if(response.statusCode == 200) {
      final items = (response.data['items'] as List).take(2); // prend seulement les 2 premiers

      for (var item in items) {
        if(item['type'] != 2) {
          newSuggestions.add(
            SuggestionItem(
              type: item['type'] == 1 ? 'bible' : item['type'] == 3 ? 'wolTopic' : 'word',
              query: item['query'],
              title: item['caption'],
              label: item['label'],
            ),
          );
        }
      }
    }

    // 🔎 Recherches dans les publications téléchargées avec sujets
    final pubsWithTopics = PublicationRepository().getAllDownloadedPublications().where((pub) => (pub.hasTopics || pub.hasHeading) && pub.mepsLanguage.symbol == mepsLanguage.symbol).toList();

    for (final pub in pubsWithTopics) {
      Database? db = pub.documentsManager?.database ?? await openReadOnlyDatabase(pub.databasePath!);

      if(!db.isOpen && pub.documentsManager != null ) {
        pub.documentsManager!.database = await openReadOnlyDatabase(pub.databasePath!);
      }

      if (pub.hasHeading) {
        final sqlColumn = buildAccentInsensitiveQuery('Child.Title');
        final headings = await db.rawQuery('''
            SELECT 
              Child.DisplayTitle, 
              Parent.DisplayTitle AS ParentTitle,
              Child.BeginParagraphOrdinal, 
              Child.EndParagraphOrdinal, 
              Child.ContentEndParagraphOrdinal, 
              Document.MepsDocumentId
            FROM Heading AS Child
            INNER JOIN Document ON Child.DocumentId = Document.DocumentId
            LEFT JOIN Heading AS Parent ON Child.ParentHeadingId = Parent.HeadingId
            WHERE $sqlColumn LIKE ?
          ''', ['%$normalizedQuery%']);

        if (headings.isNotEmpty && requestId == _latestRequestId) {
          final headingsList = List<Map<String, dynamic>>.from(headings);

          headingsList.sort((a, b) {
            final s1 = normalize(a['DisplayTitle'] as String);
            final s2 = normalize(b['DisplayTitle'] as String);
            final scoreA = StringSimilarity.compareTwoStrings(normalizedQuery, s1);
            final scoreB = StringSimilarity.compareTwoStrings(normalizedQuery, s2);
            return scoreB.compareTo(scoreA);
          });

          newSuggestions.add(SuggestionItem(
            type: 'heading',
            query: headingsList.first['MepsDocumentId'],
            startParagraphId: headingsList.first['BeginParagraphOrdinal'],
            endParagraphId: headingsList.first['EndParagraphOrdinal'],
            title: headingsList.first['DisplayTitle'] as String,
            image: pub.imageSqr,
            subtitle: headingsList.first['ParentTitle'] != null ? '${pub.getShortTitle()} • ${headingsList.first['ParentTitle']}' : pub.getShortTitle(),
            label: i18n().search_suggestions_topics,
          ));
        }
      }
      else if(pub.hasTopics) {
        if(!db.isOpen && pub.documentsManager != null) {
          pub.documentsManager!.database = await openReadOnlyDatabase(pub.databasePath!);
        }

        final sqlColumn = buildAccentInsensitiveQuery('Topic.Topic');
        final topics = await db.rawQuery('''
          SELECT Topic.DisplayTopic, Document.MepsDocumentId
          FROM Topic
          LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
          LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
          WHERE $sqlColumn LIKE ?
        ''', ['%$normalizedQuery%']); // recherche insensible à la casse

        if (topics.isNotEmpty && requestId == _latestRequestId) {
          final topicsList = List<Map<String, dynamic>>.from(topics);

          topicsList.sort((a, b) {
            final s1 = normalize(a['DisplayTopic'] as String);
            final s2 = normalize(b['DisplayTopic'] as String);
            final scoreA = StringSimilarity.compareTwoStrings(normalizedQuery, s1);
            final scoreB = StringSimilarity.compareTwoStrings(normalizedQuery, s2);
            return scoreB.compareTo(scoreA);
          });

          newSuggestions.add(SuggestionItem(
            type: 'topic',
            query: topicsList.first['MepsDocumentId'],
            title: topicsList.first['DisplayTopic'] as String,
            image: pub.imageSqr,
            subtitle: pub.getShortTitle(),
            label: i18n().search_suggestions_topics,
          ));
        }
      }

      if(pub.documentsManager == null) await db.close();
    }

    // 📘 Recherche dans le catalogue principal
    final pubResults = await CatalogDb.instance.fetchPubs(trimmedQuery, mepsLanguage, limit: 6);
    final pubs = PublicationRepository().getAllDownloadedPublications().where((pub) =>
    pub.mepsLanguage.symbol == mepsLanguage.symbol &&
        (pub.title.toLowerCase().contains(normalizedQuery)
            || pub.category.getName().toLowerCase().contains(normalizedQuery)
            || pub.keySymbol.toLowerCase().contains(normalizedQuery)
            || pub.symbol.toLowerCase().contains(normalizedQuery)
            || pub.year.toString().contains(normalizedQuery))).toList().take(6);

    for(var pub in pubs) {
      if(!pubResults.contains(pub)) {
        pubResults.add(pub);
      }
    }

    for(var pub in pubResults) {
      newSuggestions.add(SuggestionItem(
        type: 'publication',
        query: pub.keySymbol,
        title: pub.getShortTitle(),
        image: pub.networkImageSqr ?? pub.imageSqr,
        subtitle: pub.category.getName(),
      ));
    }

    // 🎵 Recherche dans les médias Realm
    final medias = RealmLibrary.realm.all<RealmMediaItem>().query(r"Title CONTAINS[c] $0 AND LanguageSymbol == $1", [trimmedQuery, mepsLanguage.symbol]);

    if (requestId == _latestRequestId) {
      for (final media in medias.take(10)) {

        final category = RealmLibrary.realm.all<RealmCategory>().query(r"Key == $0 AND LanguageSymbol == $1", [media.primaryCategory ?? '', mepsLanguage.symbol]).firstOrNull;

        if(media.type == 'AUDIO') {
          Audio audio = Audio.fromJson(mediaItem: media);
          newSuggestions.add(SuggestionItem(
            type: 'audio',
            query: media,
            title: audio.title,
            image: audio.networkImageSqr,
            subtitle: category?.name ?? '',
          ));
        }
        else {
          Video video = Video.fromJson(mediaItem: media);
          newSuggestions.add(SuggestionItem(
            type: 'video',
            query: video,
            title: video.title,
            image: video.networkImageSqr,
            subtitle: category?.name ?? '',
          ));
        }
      }
    }

    if (mounted) {
      if (requestId == _latestRequestId) {
        setState(() => _suggestions = newSuggestions);
      }
    }
  }

  void _handleTap(SearchFieldListItem<SuggestionItem> item) async {
    widget.onClose?.call();

    SuggestionItem? selected = item.item;
    if (selected == null) return;
    BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;

    if(selected.type == 'bible') {
      String bibleLink = 'https://wol.jw.org/wol/l/r30/lp-f?q=${selected.query}';

      final response = await Api.httpGetWithHeaders(bibleLink, responseType: ResponseType.json);

      if(response.statusCode == 200) {
        // 1. On récupère la liste 'items'
        final items = response.data['items'] as List;
        if (items.isNotEmpty) {
          final firstItem = items.first;

          // 2. 'results' est une liste de listes.
          // Ton JSON montre : "results": [ [ { ... } ] ]
          final resultsOuter = firstItem['results'] as List;

          if (resultsOuter.isNotEmpty) {
            final resultsInner = resultsOuter.first as List;

            if (resultsInner.isNotEmpty) {
              // 3. C'est ici que se trouve ton objet final
              final data = resultsInner.first;

              final book = data['book'];
              final firstChapter = data['first_chapter'];
              final firstVerse = data['first_verse'];
              final lastChapter = data['last_chapter'];
              final lastVerse = data['last_verse'];

              Publication? currentBible = PublicationRepository().getLookUpBible();
              if(currentBible != null) {
                showChapterView(
                    context,
                    currentBible.keySymbol,
                    currentBible.mepsLanguage.id,
                    book,
                    firstChapter,
                    firstVerseNumber: firstVerse,
                    lastVerseNumber: lastVerse
                );
              }
            }
          }
        }
      }
    }

    switch (selected.type) {
      case 'topic':
        await showDocumentView(context, selected.query, JwLifeSettings.instance.currentLanguage.value.id);
        break;
      case 'heading':
        await showDocumentView(context, selected.query, JwLifeSettings.instance.currentLanguage.value.id, startParagraphId: selected.startParagraphId, endParagraphId: selected.endParagraphId);
        break;
      case 'bible':
        break;
      case 'publication':
        final publication = await CatalogDb.instance.searchPub(selected.query, 0, JwLifeSettings.instance.currentLanguage.value.id);
        if (publication != null) {
          publication.showMenu(context);
        } else {
          showErrorDialog(context, i18n().message_file_missing_pub_title, "Aucune publications ${selected.query} n'a pu être trouvée.");
        }
        break;
      case 'audio' || 'video':
        selected.query.showPlayer(context);
        break;
      default:
        showPage(SearchPage(query: selected.query));
    }
  }
}
