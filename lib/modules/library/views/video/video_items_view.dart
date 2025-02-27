import 'package:flutter/material.dart';

import 'package:realm/realm.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';

class VideoItemsView extends StatefulWidget {
  final Category category;

  VideoItemsView({super.key, required this.category});

  @override
  _VideoItemsViewState createState() => _VideoItemsViewState();
}

class _VideoItemsViewState extends State<VideoItemsView> {
  String categoryName = '';
  String language = '';
  List<Category> subcategories = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);
  }

  void loadItems(String? languageCode) async {
    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm.all<Language>().query("symbol == '$languageCode'").first;

    if (language.isEmpty || language == lang.vernacular) {
      setState(() {
        categoryName = widget.category.localizedName!;
        language = lang.vernacular!;
        subcategories = widget.category.subcategories;
      });
    }
    else {
      String key = widget.category.key!;
      List<Category> categories = RealmLibrary.realm.all<Category>().query("key == '$key'").query("language == '$languageCode'").toList();
      if (categories.isNotEmpty) {
        Category category = categories.first;
        setState(() {
          categoryName = category.localizedName!;
          language = lang.vernacular!;
          subcategories = category.subcategories;
        });
      }
      else {
        // Handle the case where no category was found (e.g., show an error message or fallback)
        print('No category found for key: $key and language: $languageCode');
      }
    }
  }

  void _filterAudios(String query) {
    if (query.isEmpty) {
      setState(() {
        subcategories = widget.category.subcategories;
      });
    } else {
      setState(() {
        /*
        filteredVideos = widget.category.categories.where((subCategory) {
          return subCategory.media.any((audio) {
            return audio['title'].toLowerCase().contains(query.toLowerCase());
          });
        }).toList();

         */
      });
    }
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
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black),
          ),
          style: const TextStyle(color: Colors.black),
          //onChanged: _filterAudios,
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: textStyleTitle,
            ),
            Text(
              language,
              style: textStyleSubtitle
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? JwIcons.x : JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  subcategories = widget.category.subcategories;
                } else {
                  _isSearching = true;
                }
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
          )
        ],
      ),
      body: ListView.builder(
        itemCount: subcategories.length,
        itemBuilder: (context, index) {
          var subCategory = subcategories[index];
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
              SizedBox(
                height: 180, // Adjust height as needed
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: subCategory.media.length,
                  itemBuilder: (context, index) {
                    MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '${subCategory.media[index]}'").first;
                    return GestureDetector(
                      onTap: () {
                        showFullScreenVideo(context, mediaItem.languageAgnosticNaturalKey!, mediaItem.languageSymbol!);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0), // Ajoutez une marge horizontale
                        child: SizedBox(
                          width: 180, // Ajuster la largeur avec un espace supplémentaire
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: ImageCachedWidget(
                                    imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl,
                                    pathNoImage: "pub_type_video",
                                    height: 100,
                                    width: 180
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  color: Colors.black.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    formatDuration(mediaItem.duration!),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -5,
                                right: -10,
                                child: PopupMenuButton(
                                  popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.ease), 0.5),
                                  icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)], size: 25),
                                  shadowColor: Colors.black,
                                  elevation: 8,
                                  itemBuilder: (context) => [
                                    getVideoShareItem(mediaItem),
                                    getVideoLanguagesItem(context, mediaItem),
                                    getVideoFavoriteItem(mediaItem),
                                    getVideoDownloadItem(context, mediaItem),
                                    getShowSubtitlesItem(context, mediaItem),
                                    getCopySubtitlesItem(context, mediaItem)
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 100, // Ajuster la position du titre
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  child: Text(
                                    mediaItem.title!,
                                    style: const TextStyle(
                                      fontSize: 12, // Ajuster la taille de la police au besoin
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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