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
  List<Category> filteredVideos = [];  // Ajout de filteredVideos
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadItems(String? languageCode) async {
    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm.all<Language>().query("symbol == '$languageCode'").first;

    if (language.isEmpty || language == lang.vernacular) {
      setState(() {
        categoryName = widget.category.localizedName!;
        language = lang.vernacular!;
        subcategories = widget.category.subcategories;
        filteredVideos = subcategories;  // Initialiser filteredVideos
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
          filteredVideos = subcategories;  // Initialiser filteredVideos
        });
      }
      else {
        // Handle the case where no category was found (e.g., show an error message or fallback)
        print('No category found for key: $key and language: $languageCode');
      }
    }
  }

  void _filterVideos(String query) {
    setState(() {
      // Si la requête est vide, on réinitialise filteredVideos à toutes les sous-catégories
      if (query.isEmpty) {
        filteredVideos = subcategories;
      } else {
        /*
        // Sinon, on filtre les sous-catégories et leurs vidéos
        filteredVideos = subcategories.map((subCategory) {
          // Filtrer les médias qui contiennent la requête
          List<String> filteredMedia = subCategory.media
              .where((media) {
            try {
              // Récupérer l'élément MediaItem à partir de la clé
              MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$media'").first;
              // Retourner vrai si le titre correspond à la recherche
              return mediaItem.title != null && mediaItem.title!.toLowerCase().contains(query.toLowerCase());
            } catch (e) {
              return false;
            }
          }).toList();

          // Retourner la sous-catégorie avec les vidéos filtrées
          return subCategory.copyWith(media: filteredMedia);
        }).where((subCategory) => subCategory.media.isNotEmpty) // Garder les sous-catégories qui ont des vidéos correspondantes
            .toList();

         */
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
      appBar: _isSearching
          ? AppBar(
        title: SearchBar(
          autoFocus: true,
          hintText: 'Rechercher...',
          controller: _searchController,
          onChanged: _filterVideos,
          onSubmitted: _filterVideos,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
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
                _searchController.clear();
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
        itemCount: filteredVideos.length,  // Utiliser filteredVideos ici
        itemBuilder: (context, index) {
          var subCategory = filteredVideos[index];  // Utiliser filteredVideos
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
                height: 180, // Ajuster la hauteur comme nécessaire
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: subCategory.media.length,
                  itemBuilder: (context, index) {
                    MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '${subCategory.media[index]}'").first;
                    return GestureDetector(
                      onTap: () {
                        showFullScreenVideo(context, mediaItem);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                        child: SizedBox(
                          width: 180,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2.0),
                                child: ImageCachedWidget(
                                  imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl ?? mediaItem.realmImages!.wideImageUrl,
                                  pathNoImage: "pub_type_video",
                                  height: 100,
                                  width: 180,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  color: Colors.black.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.play, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatDuration(mediaItem.duration!),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -5,
                                right: -10,
                                child: PopupMenuButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
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
                                top: 100,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  child: Text(
                                    mediaItem.title!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.start,
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
