import 'dart:convert';

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
import '../../i18n/localization.dart';
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
      itemHeight: 53,
      autofocus: widget.autofocus ?? true,
      offset: const Offset(-65, 55),
      maxSuggestionsInViewPort: 9,
      maxSuggestionBoxHeight: 200,
      suggestionState: Suggestion.expand,
      searchInputDecoration: SearchInputDecoration(
        hintText: localization(context).search_hint,
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
      item.caption,
      item: item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Row(
              children: [
                item.icon?.isNotEmpty ?? false ? ImageCachedWidget(
                  imageUrl: item.icon!,
                  width: 40,
                  height: 40,
                )
                    : Container(width: 40, height: 40, color: Colors.grey[400],),
                const SizedBox(width: 10),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.caption, style: TextStyle(fontSize: item.subtitle?.isNotEmpty ?? false ? 16 : 20), overflow: TextOverflow.ellipsis),
                  if (item.subtitle?.isNotEmpty ?? false)
                    Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (item.type == 5) const SizedBox(width: 5),
            if (item.type == 5)
              Icon(item.label == 'Audio' ? JwIcons.music : JwIcons.video),
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

    String apiWol = 'https://wol.jw.org/wol/sg/${JwLifeSettings().currentLanguage.rsConf}/${JwLifeSettings().currentLanguage.lib}?q=$query';
    printTime(apiWol);
    final response = await Api.httpGetWithHeaders(apiWol);
    final data = json.decode(response.body);
    final items = (data['items'] as List).take(2); // prend seulement les 2 premiers

    List<SuggestionItem> newSuggestions = [];

    for (var item in items) {
      newSuggestions.add(
        SuggestionItem(
          type: item['type'],
          query: item['query'],
          caption: item['caption'],
          icon: '', // ton icône
          subtitle: item['label'], // ton sous-titre
          label: '',
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
          type: 4,
          query: topicsList.first['MepsDocumentId'],
          caption: topicsList.first['DisplayTopic'] as String,
          icon: pub.imageSqr,
          subtitle: pub.title,
          label: 'Ouvrage de référence',
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
    final medias = RealmLibrary.realm.all<MediaItem>().query(
      r"title CONTAINS[c] $0 AND languageSymbol == $1",
      [query, JwLifeSettings().currentLanguage.symbol],
    );

    if (requestId == _latestRequestId) {
      for (final media in medias.take(10)) {

        final category = RealmLibrary.realm
            .all<Category>()
            .query(r"key == $0", [media.primaryCategory ?? ''])
            .firstOrNull;

        if(media.type == 'AUDIO') {
          Audio audio = Audio.fromJson(mediaItem: media);
          newSuggestions.add(SuggestionItem(
            type: 5,
            query: media,
            caption: audio.title,
            icon: audio.networkImageSqr,
            subtitle: category?.localizedName ?? '',
            label: 'Audio',
          ));
        }
        else {
          Video video = Video.fromJson(mediaItem: media);
          newSuggestions.add(SuggestionItem(
            type: 5,
            query: video,
            caption: video.title,
            icon: video.networkImageSqr,
            subtitle: category?.localizedName ?? '',
            label: 'Vidéo',
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
      case 4:
        await showDocumentView(context, selected.query, JwLifeSettings().currentLanguage.id);
        break;
      case 6:
        showPage(SearchBiblePage(query: selected.query));
        break;
      case 7:
        final publication = await PubCatalog.searchPub(selected.query, 0, JwLifeSettings().currentLanguage.id);
        if (publication != null) {
          publication.showMenu(context);
        } else {
          showErrorDialog(context, "Aucune publication ${selected.query} n'a pu être trouvée.");
        }
        break;
      case 5:
        selected.query.showPlayer(context);
        break;
      default:
        showPage(SearchPage(query: selected.query));
    }
  }
}
