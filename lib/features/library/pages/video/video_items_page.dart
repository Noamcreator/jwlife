import 'package:flutter/material.dart';

import 'package:realm/realm.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

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
  String categoryName = '';
  String language = '';
  List<Category> subcategories = [];
  List<Category> filteredVideos = [];
  Map<String, List<String>> filteredMediaMap = {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);
  }

  void loadItems(String? languageCode) async {
    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm
        .all<Language>()
        .query("symbol == '$languageCode'")
        .first;

    if (language.isEmpty || language == lang.vernacular) {
      setState(() {
        categoryName = widget.category.localizedName!;
        language = lang.vernacular!;
        subcategories = widget.category.subcategories;
        filteredVideos = subcategories;
      });
    } else {
      String key = widget.category.key!;
      List<Category> categories = RealmLibrary.realm
          .all<Category>()
          .query("key == '$key'")
          .query("language == '$languageCode'")
          .toList();
      if (categories.isNotEmpty) {
        Category category = categories.first;
        setState(() {
          categoryName = category.localizedName!;
          language = lang.vernacular!;
          subcategories = category.subcategories;
          filteredVideos = subcategories;
        });
      }
    }
  }

  void _filterVideos(String query) {
    setState(() {
      filteredMediaMap.clear();

      if (query.isEmpty) {
        filteredVideos = subcategories;
      } else {
        filteredVideos = [];

        for (var subCategory in subcategories) {
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
            filteredMediaMap[subCategory.key!] = filteredMedia;
            filteredVideos.add(subCategory);
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _isSearching ? AppBar(
        title: SearchFieldWidget(
          query: '',
          onSearchTextChanged: (text) {
            setState(() {
              _filterVideos(text);
            });
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
              filteredVideos = subcategories;  // Réinitialiser filteredVideos lors de la recherche
            });
          },
        ),
      )
          : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: textStyleTitle,
            ),
            Text(
              language,
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
                filteredVideos = subcategories;  // Réinitialiser filteredVideos lors de la recherche
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              LanguageDialog languageDialog = const LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) {
                loadItems(value['Symbol']);
              });
            },
          ),
        ],
      ),
      body: ListView.builder(
        key: ValueKey(filteredVideos.length),
        itemCount: filteredVideos.length,  // Utiliser filteredVideos ici
        itemBuilder: (context, index) {
          final subCategory = filteredVideos[index];
          final mediaList = filteredMediaMap[subCategory.key!] ?? subCategory.media;

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
                height: 140, // Ajuster la hauteur comme nécessaire
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaList.length,
                  itemBuilder: (context, index) {
                    final mediaKey = mediaList[index];
                    final mediaItem = RealmLibrary.realm
                        .all<MediaItem>()
                        .query("naturalKey == '$mediaKey'")
                        .first;

                    Media media = mediaItem.type == 'AUDIO' ? Audio.fromJson(mediaItem: mediaItem) : Video.fromJson(mediaItem: mediaItem);

                    return MediaItemItemWidget(
                      media: media,
                        timeAgoText: false
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
