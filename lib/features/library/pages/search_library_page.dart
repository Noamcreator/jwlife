import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/app_page.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/home/pages/search/search_page.dart';
import 'package:jwlife/features/library/widgets/rectangle_mediaItem_item.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../../app/services/settings_service.dart';
import '../../../core/ui/app_dimens.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_database.dart';
import '../../../core/utils/widgets_utils.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/video.dart';
import '../../../data/realm/catalog.dart';
import '../../../data/realm/realm_library.dart';
import '../../../i18n/i18n.dart';
import '../widgets/rectangle_topic_item.dart';

// --- Utilitaire Debouncer pour retarder la recherche ---
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() => _timer?.cancel();
}

class SearchLibraryPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SearchLibraryPageState();
}

class SearchLibraryPageState extends State<SearchLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 500);

  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> fetchItems(String query) async {
    final trimmedQuery = query.trim();

    // CONDITION STRICTE : Si vide, on ne cherche rien
    if (trimmedQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<dynamic> topicResults = [];
      List<dynamic> pubResults = [];
      List<dynamic> mediaResults = [];

      String normalizedQuery = normalize(trimmedQuery).toLowerCase();
      MepsLanguage mepsLanguage = JwLifeSettings.instance.libraryLanguage.value;

      /// RECHERCHE DES TOPICS
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

          for (var row in headings) {
            topicResults.add({
              'Type': 'heading',
              'MepsDocumentId': row['MepsDocumentId'],
              'BeginParagraphOrdinal': row['BeginParagraphOrdinal'],
              'EndParagraphOrdinal': row['EndParagraphOrdinal'],
              'ContentEndParagraphOrdinal': row['ContentEndParagraphOrdinal'],
              'MepsLanguageId': mepsLanguage.id,
              'ParentTitle': row['ParentTitle'],
              'Title': row['DisplayTitle'] as String,
              'Publication': pub,
            });
          }
        }
        else if(pub.hasTopics) {
          final sqlColumn = buildAccentInsensitiveQuery('Topic.Topic');
          final topics = await db.rawQuery('''
            SELECT Topic.DisplayTopic, Document.MepsDocumentId
            FROM Topic
            LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
            LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
            WHERE $sqlColumn LIKE ?
          ''', ['%$normalizedQuery%']);

          for (var row in topics) {
            topicResults.add({
              'Type': 'topic',
              'MepsDocumentId': row['MepsDocumentId'],
              'MepsLanguageId': mepsLanguage.id,
              'Title': row['DisplayTopic'] as String,
              'Publication': pub,
            });
          }
        }

        if (pub.documentsManager == null) await db.close();
      }

      /// RECHERCHE DANS LES PUBLICATIONS
      pubResults = await CatalogDb.instance.fetchPubs(trimmedQuery, mepsLanguage);
      final pubs = PublicationRepository().getAllDownloadedPublications().where((pub) =>
      pub.mepsLanguage.symbol == mepsLanguage.symbol &&
          (pub.title.toLowerCase().contains(normalizedQuery)
              || pub.category.getName().toLowerCase().contains(normalizedQuery)
              || pub.keySymbol.toLowerCase().contains(normalizedQuery)
              || pub.symbol.toLowerCase().contains(normalizedQuery)
              || pub.year.toString().contains(normalizedQuery))).toList();

      for(var pub in pubs) {
        if(!pubResults.contains(pub)) {
          pubResults.add(pub);
        }
      }

      /// RECHERCHE DES MEDIAS
      final initialMedias = RealmLibrary.realm.all<RealmMediaItem>().query(r"(Title CONTAINS[c] $0 OR PubSymbol == $0) AND LanguageSymbol == $1", [trimmedQuery, mepsLanguage.symbol]);

      final uniqueMedias = initialMedias.toSet();

      final categories = RealmLibrary.realm.all<RealmCategory>().query(r"Name CONTAINS[c] $0 AND LanguageSymbol == $1", [trimmedQuery, mepsLanguage.symbol]);

      for (final category in categories) {
        for (final mediaKey in category.media) {
          final media = RealmLibrary.realm.all<RealmMediaItem>().query(r"NaturalKey == $0", [mediaKey]).firstOrNull;
          if (media != null) uniqueMedias.add(media);
        }
      }

      for (final media in uniqueMedias) {
        mediaResults.add(media.type == 'AUDIO' ? Audio.fromJson(mediaItem: media) : Video.fromJson(mediaItem: media));
      }

      // Tri par similarité textuelle
      _sortBySimilarity(topicResults, trimmedQuery);
      _sortBySimilarity(mediaResults, trimmedQuery);

      if (mounted && _searchController.text.isNotEmpty) {
        setState(() {
          _results = [...topicResults, ...pubResults, ...mediaResults];
          _isLoading = false;
        });
      }
    }
    catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortBySimilarity(List<dynamic> list, String query) {
    list.sort((a, b) {
      double scoreA = StringSimilarity.compareTwoStrings(query, _getTitleOf(a));
      double scoreB = StringSimilarity.compareTwoStrings(query, _getTitleOf(b));
      return scoreB.compareTo(scoreA);
    });
  }

  String _getTitleOf(dynamic item) {
    if (item is Map) return item['Title'] ?? '';
    if (item is Publication) return item.title;
    if (item is Media) return item.title;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: JwLifeAppBar(
        titleWidget: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: i18n().search_hint,
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1f1f1f) : const Color(0xFFf1f1f1),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                icon: const Icon(JwIcons.x),
                onPressed: () {
                  _debouncer.dispose(); // Annule le délai en cours
                  _searchController.clear();
                  fetchItems(""); // Reset immédiat des listes
                })
                : null,
          ),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              _debouncer.dispose();
              fetchItems(""); // Stop et vide l'UI
            } else {
              _debouncer.run(() => fetchItems(value));
            }
          },
          autofocus: true,
          textInputAction: TextInputAction.search,
        ),
        title: '',
      ),
      body: Column(
        children: [
          // On retire le "if (_isLoading)" d'ici pour le mettre dans le Expanded
          Expanded(
            child: _searchController.text.isEmpty
                ? const SizedBox.shrink()
                : LayoutBuilder(
              builder: (context, constraints) {
                // 1. CAS : CHARGEMENT (Centré)
                if (_isLoading) {
                  return Center(
                    child: getLoadingWidget(Theme.of(context).primaryColor),
                  );
                }

                // 2. CAS : AUCUN RÉSULTAT (Centré)
                if (_results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            "Aucun résultat trouvé pour \"${_searchController.text}\"",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 3. CAS : RÉSULTATS TROUVÉS
                final double screenWidth = constraints.maxWidth;
                final double contentPadding = getContentPadding(screenWidth);

                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 8),
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 3),
                  itemBuilder: (context, index) {
                    var item = _results[index];
                    if (item is Media) {
                      return RectangleMediaItemItem(media: item, searchWidget: true);
                    } else if (item is Publication) {
                      return RectanglePublicationItem(publication: item, searchWidget: true);
                    } else if (item is Map && (item['Type'] == 'topic' || item['Type'] == 'heading')) {
                      return RectangleTopicItem(topic: item, publication: item['Publication']);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
              child: TextButton(
                onPressed: () => showPage(SearchPage(query: _searchController.text)),
                child: Text(
                  'Recherche Globale',
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}