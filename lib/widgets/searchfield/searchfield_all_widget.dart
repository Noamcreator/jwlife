import 'package:flutter/material.dart';
import 'package:realm/realm.dart';
import 'package:searchfield/searchfield.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/icons.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/files_helper.dart';
import '../../core/utils/utils_audio.dart';
import '../../core/utils/utils_document.dart';
import '../../core/utils/utils_video.dart';
import '../../data/databases/catalog.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../data/repositories/PublicationRepository.dart';
import '../../features/home/pages/search/bible_search_page.dart';
import '../../features/home/pages/search/search_page.dart';
import '../../features/home/pages/search/suggestion.dart';
import '../../i18n/localization.dart';
import '../image_cached_widget.dart';
// Ajoute les imports nécessaires pour JwIcons, PubCatalog, RealmLibrary, etc.

class SearchFieldAll extends StatefulWidget {
  final void Function()? onClose;
  final bool? autofocus;
  final String? initialText;

  const SearchFieldAll({super.key, this.onClose, this.autofocus, this.initialText});

  @override
  State<SearchFieldAll> createState() => _SearchFieldAllState();
}

class _SearchFieldAllState extends State<SearchFieldAll> {
  final TextEditingController _controller = TextEditingController();
  List<SuggestionItem> _suggestions = [];
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText ?? '';
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
            showPage(context, SearchPage(query: _controller.text));
          },
        ),
      ),
      suggestionsDecoration: SuggestionDecoration(
        color: isDark ? const Color(0xFF1f1f1f) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        width: MediaQuery.of(context).size.width - 15,
      ),
      suggestions: _suggestions.map(_buildSuggestionItem).toList(),
      onSearchTextChanged: (text) async {
        await _fetchSuggestions(text);
        return [];
      },
      onSuggestionTap: _handleTap,
      onSubmit: (text) {
        widget.onClose?.call();
        showPage(context, SearchPage(query: text));
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
            if (item.icon?.isNotEmpty ?? false)
              Row(
                children: [
                  ImageCachedWidget(
                    imageUrl: item.icon!,
                    pathNoImage: 'pub_type_placeholder',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.caption, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                  if (item.subtitle?.isNotEmpty ?? false)
                    Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (item.type == 3) const SizedBox(width: 5),
            if (item.type == 3)
              Icon(item.label == 'Audio' ? JwIcons.music : JwIcons.video),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_latestRequestId;
    const baseImageUrl = "https://app.jw-cdn.org/catalogs/publications/";
    List<SuggestionItem> newSuggestions = [];

    if (query.isEmpty || requestId != _latestRequestId) {
      setState(() => _suggestions = []);
      return;
    }

    // 🔎 Recherches dans les publications téléchargées avec sujets
    final pubsWithTopics = PublicationRepository()
        .getAllDownloadedPublications()
        .where((pub) => pub.hasTopics)
        .toList();

    for (final pub in pubsWithTopics) {
      final db = await openReadOnlyDatabase(pub.databasePath!);
      final topics = await db.rawQuery('''
        SELECT Topic.DisplayTopic, Document.MepsDocumentId
        FROM Topic
        LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
        LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
        WHERE Topic.Topic LIKE ?
        LIMIT 1
      ''', ['%$query%']);

      if (topics.isNotEmpty && requestId == _latestRequestId) {
        final topic = topics.first;
        newSuggestions.add(SuggestionItem(
          type: 0,
          query: topic['MepsDocumentId'],
          caption: topic['DisplayTopic'] as String,
          icon: pub.imageSqr,
          subtitle: pub.title,
          label: 'Ouvrage de référence',
        ));
      }

      if (!pub.isBible()) await db.close();
    }

    // 📘 Recherche dans le catalogue principal
    final catalogFile = await getCatalogDatabaseFile();
    final db = await openDatabase(catalogFile.path, readOnly: true);

    //final result = await db.rawQuery(/* comme ton code source ci-dessus */);
    //final fallbackResult = await db.rawQuery(/* fallback query */);

    // Ajout des résultats à newSuggestions comme dans ton code

    await db.close();

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

        newSuggestions.add(SuggestionItem(
          type: 3,
          query: media,
          caption: media.title.toString(),
          icon: media.realmImages?.squareImageUrl ?? '',
          subtitle: category?.localizedName ?? '',
          label: media.type == 'AUDIO' ? 'Audio' : 'Vidéo',
        ));
      }
    }

    setState(() => _suggestions = newSuggestions);
  }

  void _handleTap(SearchFieldListItem<SuggestionItem> item) async {
    widget.onClose?.call();

    SuggestionItem selected = item.item!;
    switch (selected.type) {
      case 0:
        showDocumentView(context, selected.query, JwLifeSettings().currentLanguage.id);
        break;
      case 1:
        showPage(context, SearchBiblePage(query: selected.query));
        break;
      case 2:
        final publication = await PubCatalog.searchPub(selected.query, 0, JwLifeSettings().currentLanguage.id);
        if (publication != null) {
          publication.showMenu(context);
        } else {
          showErrorDialog(context, "Aucune publication ${selected.query} n'a pu être trouvée.");
        }
        break;
      case 3:
        selected.label == 'Audio'
            ? showAudioPlayer(context, selected.query)
            : showFullScreenVideo(context, selected.query);
        break;
      default:
        showPage(context, SearchPage(query: selected.query));
    }
  }
}
