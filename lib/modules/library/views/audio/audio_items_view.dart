import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:realm/realm.dart';

class AudioItemsView extends StatefulWidget {
  final Category category;

   AudioItemsView({super.key, required this.category});

  @override
  _AudioItemsViewState createState() => _AudioItemsViewState();
}

class _AudioItemsViewState extends State<AudioItemsView> {
  String categoryName = '';
  String language = '';
  List<MediaItem> filteredAudios = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  late StreamSubscription<int?> _currentIndexSubscription;

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);

    _currentIndexSubscription = JwLifeApp.jwAudioPlayer.player.currentIndexStream.listen((index) {
      setState(() {
        JwLifeApp.jwAudioPlayer.setId(index ?? -1);
      });
    });
  }

  @override
  void dispose() {
    _currentIndexSubscription.cancel();
    super.dispose();
  }

  void loadItems(String? languageCode) async {
    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm.all<Language>().query("symbol == '$languageCode'").first;

    if (language.isEmpty || language == lang.vernacular) {
      setState(() {
        categoryName = widget.category.localizedName!;
        language = lang.vernacular!;
        filteredAudios = widget.category.media.map((key) {
          return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
        }).toList();
      });
    }
    else {
      String key = widget.category.key!;
      List<Category> categories = RealmLibrary.realm.all<Category>().query("key == '$key' AND language == '$languageCode'").toList();
      if (categories.isNotEmpty) {
        Category category = categories.first;
        setState(() {
          categoryName = category.localizedName!;
          language = lang.vernacular!;
          filteredAudios = category.media.map((key) {
            return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
          }).toList();
        });
      }
      else {
        print('No category found for key: $key and language: $languageCode');
      }
    }
  }


  void _filterAudios(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredAudios = widget.category.media.map((key) {
          // On récupère l'objet MediaItem correspondant à la clé
          return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
        }).toList();
      });
    } else {
      setState(() {
        // Filtrage des audios en fonction de la requête
        filteredAudios = widget.category.media.where((audio) {
          // On récupère l'objet MediaItem correspondant à la clé
          MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$audio'").first;
          String mediaTitle = mediaItem.title!; // Titre de l'élément
          return mediaTitle.toLowerCase().contains(query.toLowerCase());
        }).map((audio) {
          // Retourner l'objet MediaItem correspondant à la clé
          return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$audio'").first;
        }).toList();
      });
    }
  }

  void _play(index) async {
    JwLifeApp.jwAudioPlayer.setRandomMode(false);
    JwLifeApp.jwAudioPlayer.fetchAudiosCategoryData(widget.category, id: index);
    JwLifeApp.jwAudioPlayer.play();
  }

  void _playAll() async {
    JwLifeApp.jwAudioPlayer.setRandomMode(false);
    JwLifeApp.jwAudioPlayer.fetchAudiosCategoryData(widget.category);
    JwLifeApp.jwAudioPlayer.play();
  }

  void _playRandom() async {
    JwLifeApp.jwAudioPlayer.fetchAudiosCategoryData(widget.category, id: Random().nextInt(filteredAudios.length-1));
    JwLifeApp.jwAudioPlayer.setRandomMode(true);
    JwLifeApp.jwAudioPlayer.play();
  }

  void _playRandomLanguage() async {
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
        title: _isSearching ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Chercher...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontFamily: 'NotoSans', fontSize: 18.0, decoration: TextDecoration.none),
          onChanged: _filterAudios,
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: textStyleTitle
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
                  //filteredAudios = widget.category.media;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              LanguageDialog languageDialog = LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) async {
                // Mise à jour synchrone dans setState
                await setLibraryLanguage(value);

                setState(() {
                  loadItems(value['Symbol']);
                });

                await LibraryView.setStateLibraryPage();
                await HomeView.setStateHomePage();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _playAll,
                  icon: const Icon(Icons.playlist_play),
                  label: const Text("TOUT LIRE"),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _playRandom,
                  icon: const Icon(Icons.shuffle),
                  label: const Text("LECTURE ALÉATOIRE"),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _playRandomLanguage,
                  icon: const Icon(JwIcons.language),
                  label: const Text("LANGUE ALÉATOIRE"),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Widget>>(
              future: Future(() => filteredAudios
                  .map((audio) => buildAudioItem(filteredAudios.indexOf(audio)))
                  .toList()),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(5.0),
                    child: Column(
                      children: List.generate(
                        filteredAudios.length,
                            (index) => buildAudioItem(index),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(5.0),
                    itemCount: filteredAudios.length,
                    itemBuilder: (context, index) => buildAudioItem(index),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }
            )
          ),
        ],
      ),
    );
  }

  Widget buildAudioItem(int index) {
    MediaItem mediaItem = filteredAudios[index];

    return Stack(
        children: [
          SizedBox(
            height: 65,
            child: InkWell(
              onTap: () {
                _play(widget.category.media.indexOf(mediaItem.naturalKey!));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    ImageCachedWidget(
                        imageUrl: mediaItem.realmImages!.squareImageUrl,
                        pathNoImage: "pub_type_audio",
                        height: 55,
                        width: 55
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mediaItem.title!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                              color: JwLifeApp.jwAudioPlayer.currentId == index && JwLifeApp.jwAudioPlayer.album == widget.category.localizedName ? Theme.of(context).primaryColor : Theme.of(context).secondaryHeaderColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDuration(mediaItem.duration!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 25),
              itemBuilder: (context) => [
                getAudioShareItem(mediaItem),
                getAudioLanguagesItem(context, mediaItem),
                getAudioFavoriteItem(mediaItem),
                getAudioDownloadItem(context, mediaItem),
                getAudioLyricsItem(context, mediaItem),
                getCopyLyricsItem(mediaItem)
              ],
            ),
          )
        ]
    );
  }
}