import 'package:flutter/material.dart';

import 'package:realm/realm.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';

import '../../../../core/api/api.dart';
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
        _filteredVideos = [];

        for (var subCategory in _subcategories) {
          final filteredMedia = subCategory.media.where((mediaKey) {
            try {
              final mediaItem = RealmLibrary.realm
                  .all<MediaItem>()
                  .query("naturalKey == '$mediaKey'")
                  .first;

              return mediaItem.title != null &&
                  mediaItem.title!.toLowerCase().contains(query.toLowerCase());
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
      bodyContent = ListView.builder(
        key: ValueKey(_filteredVideos.length),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, index) {
          final subCategory = _filteredVideos[index];
          final mediaList = _filteredMediaMap[subCategory.key!] ?? subCategory.media;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  subCategory.localizedName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              Container(
                height: 140,
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaList.length,
                  itemBuilder: (context, index) {
                    final mediaKey = mediaList[index];
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
            return null;
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
          suggestions: [],
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
              LanguageDialog languageDialog = LanguageDialog(selectedLanguageSymbol: _selectedLanguageSymbol);
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) async {
                if (value != null) {
                  _selectedLanguageSymbol = value['Symbol'] as String;
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