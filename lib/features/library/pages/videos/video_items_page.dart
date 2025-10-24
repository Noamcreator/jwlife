import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';

import 'package:realm/realm.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';

import '../../../../core/api/api.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/video.dart';
import '../../../../widgets/mediaitem_item_widget.dart';
import '../../../../widgets/searchfield/searchfield_widget.dart';

class VideoItemsPage extends StatefulWidget {
  final Category category;

  const VideoItemsPage({super.key, required this.category});

  @override
  _VideoItemsPageState createState() => _VideoItemsPageState();
}

class _VideoItemsPageState extends State<VideoItemsPage> {
  String _categoryName = '';
  String _language = '';

  String? _selectedLanguageSymbol;

  List<Category> _subcategories = [];
  List<Category> _filteredVideos = [];
  final Map<String, List<String>> _filteredMediaMap = {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems({String? symbol}) async {
    symbol ??= widget.category.language;

    RealmLibrary.realm.refresh();
    Language? lang = RealmLibrary.realm.all<Language>().query("symbol == '$symbol'").firstOrNull;
    if(lang == null) return;

    Category? category = RealmLibrary.realm.all<Category>().query("key == '${widget.category.key}' AND language == '$symbol'").firstOrNull;

    setState(() {
      _categoryName = category?.localizedName ?? widget.category.localizedName!;
      _language = lang.vernacular!;
      _subcategories = category?.subcategories ?? [];
      _filteredVideos = _subcategories;
    });
  }

  void _filterVideos(String query) {
    setState(() {
      _filteredMediaMap.clear();

      if (query.isEmpty) {
        _filteredVideos = _subcategories;
      } else {
        // 1. Normaliser la requête de recherche : sans diacritiques et minuscule
        final normalizedQuery = removeDiacritics(query).toLowerCase();

        _filteredVideos = [];

        for (var subCategory in _subcategories) {
          final filteredMedia = subCategory.media.where((mediaKey) {
            try {
              final mediaItem = RealmLibrary.realm
                  .all<MediaItem>()
                  .query("naturalKey == '$mediaKey'")
                  .first;

              if (mediaItem.title == null) {
                return false;
              }

              // 2. Normaliser le titre de l'élément pour la comparaison
              final normalizedTitle = removeDiacritics(mediaItem.title!).toLowerCase();

              // 3. Comparer les chaînes normalisées
              return normalizedTitle.contains(normalizedQuery);
            } catch (_) {
              return false;
            }
          }).toList();

          if (filteredMedia.isNotEmpty) {
            _filteredMediaMap[subCategory.key!] = filteredMedia;
            _filteredVideos.add(subCategory);
          }
        }
      }
    });
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

    // This is the core logic for displaying the message.
    Widget bodyContent;
    if (_filteredVideos.isEmpty && !_isSearching) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Il n\'y a pas de vidéos disponibles pour le moment dans cette langue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      );
    } else {
      // Le ListView.builder est conservé comme bodyContent
      bodyContent = ListView.builder(
        // L'itemCount est augmenté de 1 pour inclure le bouton
        itemCount: _filteredVideos.length + 1,
        itemBuilder: (context, index) {
          // Si l'index est 0, on affiche le bouton "Lecture aléatoire"
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Votre liste initiale de catégories
                  List<Category> cats = List.from(_subcategories);

                  // Initialiser la liste finale qui contiendra tous les médias
                  List<String> allMedias = [];

                  // 2. Boucler sur les catégories (maintenant mélangées)
                  for (Category category in cats) {
                    // Créer une copie modifiable des médias de la catégorie
                    List<String> medias = List.from(category.media);
                    // 4. Ajouter les médias mélangés de cette catégorie à la liste finale
                    allMedias.addAll(medias);
                  }

                  List<Media> shuffledMedias = [];

                  // me donner une liste de medias en strinf
                  for(String mediaKey in allMedias) {
                    final mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$mediaKey'").first;

                    Media media = mediaItem.type == 'AUDIO' ? Audio.fromJson(mediaItem: mediaItem) : Video.fromJson(mediaItem: mediaItem);
                    shuffledMedias.add(media);
                  }

                  shuffledMedias.shuffle();

                  shuffledMedias.first.showPlayer(context, medias: shuffledMedias);
                },
                icon: Icon(JwIcons.arrows_twisted_right, size: 20),
                label: Text('Lecture aléatoire', style: TextStyle(fontSize: 16)),
              ),
            );
          }

          // Pour les index suivants, on affiche les catégories de vidéos (index - 1)
          final subCategory = _filteredVideos[index - 1];
          final mediaList = _filteredMediaMap[subCategory.key!] ?? subCategory.media;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subCategory.localizedName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 21,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: <Widget>[
                                // Premier IconButton : Lecture séquentielle
                                IconButton(
                                  padding: const EdgeInsets.all(0),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    JwIcons.play,
                                    color: Theme.of(context).primaryColor,
                                    size: 25,
                                  ),
                                  // LOGIQUE DU BOUTON "Play" (Lecture séquentielle)
                                  onPressed: () {
                                    // 1. Convertir la liste de mediaKey en objets Media
                                    List<Media> sequentialMedias = [];

                                    // mediaList contient les keys des médias dans l'ordre séquentiel
                                    for (String mediaKey in mediaList) {
                                      final mediaItem = RealmLibrary.realm
                                          .all<MediaItem>()
                                          .query("naturalKey == '$mediaKey'")
                                          .first;

                                      Media media = mediaItem.type == 'AUDIO'
                                          ? Audio.fromJson(mediaItem: mediaItem)
                                          : Video.fromJson(mediaItem: mediaItem);

                                      sequentialMedias.add(media);
                                    }

                                    // 2. Lancer la lecture avec la première vidéo de la liste
                                    // et fournir toute la liste pour la lecture continue.
                                    if (sequentialMedias.isNotEmpty) {
                                      sequentialMedias.first
                                          .showPlayer(context, medias: sequentialMedias);
                                    }
                                  },
                                ),

                                // Deuxième IconButton : Lecture aléatoire
                                IconButton(
                                  // Réduire le padding au minimum.
                                  padding: const EdgeInsets.all(0),
                                  // Réduire la densité visuelle.
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    JwIcons.arrows_twisted_right,
                                    color: Theme.of(context).primaryColor,
                                    size: 25,
                                  ),
                                  // LOGIQUE DU BOUTON "Random Play" (Lecture aléatoire)
                                  onPressed: () {
                                    // 1. Créer une copie modifiable et la mélanger
                                    List<String> shuffledMediaKeys = List.from(mediaList);
                                    shuffledMediaKeys.shuffle();

                                    // 2. Convertir la liste de mediaKey mélangée en objets Media
                                    List<Media> shuffledMedias = [];

                                    for (String mediaKey in shuffledMediaKeys) {
                                      final mediaItem = RealmLibrary.realm
                                          .all<MediaItem>()
                                          .query("naturalKey == '$mediaKey'")
                                          .first;

                                      Media media = mediaItem.type == 'AUDIO'
                                          ? Audio.fromJson(mediaItem: mediaItem)
                                          : Video.fromJson(mediaItem: mediaItem);

                                      shuffledMedias.add(media);
                                    }

                                    // 3. Lancer la lecture avec la première vidéo de la liste mélangée
                                    // et fournir toute la liste pour la lecture continue aléatoire.
                                    if (shuffledMedias.isNotEmpty) {
                                      shuffledMedias.first
                                          .showPlayer(context, medias: shuffledMedias);
                                    }
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ]
                  )
              ),
              Container(
                height: 140,
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaList.length,
                  itemBuilder: (context, idx) {
                    final mediaKey = mediaList[idx];
                    final mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$mediaKey'").first;

                    Media media = mediaItem.type == 'AUDIO' ? Audio.fromJson(mediaItem: mediaItem) : Video.fromJson(mediaItem: mediaItem);

                    return MediaItemItemWidget(
                      media: media,
                      timeAgoText: false,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _isSearching
          ? AppBar(
        title: SearchFieldWidget(
          query: '',
          onSearchTextChanged: (text) {
            _filterVideos(text);
          },
          onSuggestionTap: (item) {},
          onSubmit: (item) {
            setState(() {
              _isSearching = false;
            });
          },
          onTapOutside: (event) {
            setState(() {
              _isSearching = false;
            });
          },
          suggestionsNotifier: ValueNotifier([]),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _filterVideos(''); // Réinitialiser le filtre pour afficher tous les éléments
            });
          },
        ),
      )
          : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _categoryName,
              style: textStyleTitle,
            ),
            Text(
              _language,
              style: textStyleSubtitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                _isSearching = true;
                _filterVideos(''); // Réinitialiser le filtre lors de l'ouverture de la recherche
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              showLanguageDialog(context).then((language) async {
                if (language != null) {
                  _selectedLanguageSymbol = language['Symbol'] as String;
                  loadItems(symbol: _selectedLanguageSymbol);

                  if(await Api.isLibraryUpdateAvailable(symbol: _selectedLanguageSymbol)) {
                    Api.updateLibrary(_selectedLanguageSymbol!).then((_) {
                      loadItems(symbol: _selectedLanguageSymbol);
                    });
                  }
                }
              });
            },
          ),
        ],
      ),
      body: bodyContent,
    );
  }
}