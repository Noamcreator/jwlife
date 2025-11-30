import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
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
import '../../core/utils/utils_document.dart';
import '../../data/databases/catalog.dart';
import '../../data/models/audio.dart';
import '../../data/models/video.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../data/repositories/PublicationRepository.dart';
import '../../features/home/pages/search/bible_search_page.dart';
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
      offset: const Offset(-45, 55),
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
                    : Container(width: 40, height: 40, color: Colors.grey[400],),
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

            if (item.type == 'topic') const SizedBox(width: 10),
            if (item.type == 'topic' && item.label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFc0c0c0),
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
    final requestId = ++_latestRequestId;
    setState(() {
      _suggestions.clear();
    });

    String normalizedText = normalize(query);

    String apiWol = 'https://wol.jw.org/wol/sg/${JwLifeSettings.instance.currentLanguage.value.rsConf}/${JwLifeSettings.instance.currentLanguage.value.lib}?q=$query';
    printTime(apiWol);
    final response = await Api.httpGetWithHeaders(apiWol, responseType: ResponseType.json);
    final items = (response.data['items'] as List).take(2); // prend seulement les 2 premiers

    List<SuggestionItem> newSuggestions = [];

    for (var item in items) {
      newSuggestions.add(
        SuggestionItem(
          type: item['type'] == 1 ? 'bible' : item['type'] == 2 ? 'publication' : item['type'] == 3 ? 'topic' : 'word',
          query: item['query'],
          title: item['caption'],
          label: item['label'],
        ),
      );
    }

    // 🔎 Recherches dans les publications téléchargées avec sujets
    final pubsWithTopics = PublicationRepository()
        .getAllDownloadedPublications()
        .where((pub) => pub.hasTopics)
        .toList();

    for (final pub in pubsWithTopics) {
      Database? db;
      if (pub.documentsManager == null) {
        db = await openReadOnlyDatabase(pub.databasePath!);
      } else {
        db = pub.documentsManager!.database;
      }

      final topics = await db.rawQuery('''
        SELECT Topic.DisplayTopic, Document.MepsDocumentId
        FROM Topic
        LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
        LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
        WHERE LOWER(Topic.Topic) LIKE ?
      ''', ['%$normalizedText%']); // recherche insensible à la casse

      if (topics.isNotEmpty && requestId == _latestRequestId) {
        // trie par similarité
        final normalizedQuery = normalize(query);
        final topicsList = List<Map<String, dynamic>>.from(topics);

        topicsList.sort((a, b) {
          final s1 = normalize(a['DisplayTopic'] as String);
          final s2 = normalize(b['DisplayTopic'] as String);
          final scoreA = StringSimilarity.compareTwoStrings(normalizedQuery, s1);
          final scoreB = StringSimilarity.compareTwoStrings(normalizedQuery, s2);
          return scoreB.compareTo(scoreA);
        });

        newSuggestions.add(SuggestionItem(
          type: 'document',
          query: topicsList.first['MepsDocumentId'],
          title: topicsList.first['DisplayTopic'] as String,
          image: pub.imageSqr,
          subtitle: pub.title,
          label: i18n().search_suggestions_topics,
        ));
      }

      if(pub.documentsManager == null) await db.close();
    }

    // 📘 Recherche dans le catalogue principal
    /*
    final catalogFile = await getCatalogDatabaseFile();
    final db = await openDatabase(catalogFile.path, readOnly: true);

    final result = await db.rawQuery(/* comme ton code source ci-dessus */);
    final fallbackResult = await db.rawQuery(/* fallback query */);

    // Ajout des résultats à newSuggestions comme dans ton code

    await db.close();

     */

    // 🎵 Recherche dans les médias Realm
    final medias = RealmLibrary.realm.all<RealmMediaItem>().query(r"Title CONTAINS[c] $0 AND LanguageSymbol == $1",
      [query, JwLifeSettings.instance.currentLanguage.value.symbol],
    );

    if (requestId == _latestRequestId) {
      for (final media in medias.take(10)) {

        final category = RealmLibrary.realm.all<RealmCategory>().query(r"Key == $0", [media.primaryCategory ?? '']).firstOrNull;

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
    switch (selected.type) {
      case 'document':
        await showDocumentView(context, selected.query, JwLifeSettings.instance.currentLanguage.value.id);
        break;
      case 'bible':
        showPage(SearchBiblePage(query: selected.query));
        break;
      case 'publication':
        final publication = await CatalogDb.instance.searchPub(selected.query, 0, JwLifeSettings.instance.currentLanguage.value.id);
        if (publication != null) {
          publication.showMenu(context);
        } else {
          showErrorDialog(context, "Aucune publications ${selected.query} n'a pu être trouvée.");
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
