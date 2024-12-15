import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:realm/realm.dart';
import 'dart:convert';
import '../../../audio/JwAudioPlayer.dart';
import '../../../jwlife.dart';
import '../../../jwlife.dart';
import '../../../load_pages.dart';
import '../../../realm/catalog.dart';
import '../../../utils/api.dart';
import '../../../utils/files_helper.dart';
import '../../../utils/icons.dart';
import '../../../utils/shared_preferences_helper.dart';
import 'package:http/http.dart' as http;

import '../../../utils/utils.dart';
import '../../../utils/utils_audio.dart';
import '../../../utils/utils_video.dart';
import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/image_widget.dart';

class AudioItemsPage extends StatefulWidget {
  final Category category;

   AudioItemsPage({super.key, required this.category});

  @override
  _AudioItemsPageState createState() => _AudioItemsPageState();
}

class _AudioItemsPageState extends State<AudioItemsPage> {
  late Realm realm;
  String categoryName = '';
  String language = '';
  List<dynamic> filteredAudios = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  late StreamSubscription<int?> _currentIndexSubscription;

  @override
  void initState() {
    super.initState();
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    realm = Realm(config);

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
    realm.refresh();
    Language lang = realm.all<Language>().query("symbol == '$languageCode'").first;

    if (language.isEmpty || language == lang.vernacular) {
      setState(() {
        categoryName = widget.category.localizedName!;
        language = lang.vernacular!;
        filteredAudios = widget.category.media;
      });
    }
    else {
      String key = widget.category.key!;
      List<Category> categories = realm.all<Category>().query("key == '$key'").query("language == '$languageCode'").toList();
      if (categories.isNotEmpty) {
        Category category = categories.first;
        setState(() {
          categoryName = category.localizedName!;
          language = lang.vernacular!;
          filteredAudios = category.media;
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
        filteredAudios = widget.category.media;
      });
    }
    else {
      setState(() {
        filteredAudios = widget.category.media.where((audio) {
          MediaItem mediaItem = realm.all<MediaItem>().query("naturalKey == '$audio'").first;
          String mediaTitle = mediaItem.title!;
          return mediaTitle.toLowerCase().contains(query.toLowerCase());
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
    // Télécharger la catégorie de langue
    LoadPages.downloadLanguageCategory('E', widget.category.key!);

    // Obtenir le fichier JSON de la catégorie de médias
    File audioCategoryJson = await getMediaCategory('E', widget.category.key!);
    List<dynamic> englishAudios = [];
    if (await audioCategoryJson.exists()) {
      String jsonString = await audioCategoryJson.readAsString();
      Map<String, dynamic> jsonResponse = json.decode(jsonString);

      if (jsonResponse["category"] != null &&
          jsonResponse["category"].containsKey("media")) {
        englishAudios = jsonResponse["category"]["media"];
      }
    }

    // Créer une source audio concaténée
    ConcatenatingAudioSource multiPlaylist = ConcatenatingAudioSource(children: []);

    int mediaId = 0;
    for (var audio in englishAudios) {
      int randomLanguage = Random().nextInt(audio['availableLanguages'].length - 1);
      String languageCode = audio['availableLanguages'][randomLanguage];
      String pub = audio['languageAgnosticNaturalKey'];

      List<String> parts = pub.split('-');
      String pubKey = parts[1].split('_')[0];
      int track = int.parse(parts[1].split('_')[1]);

      String mediaApi = "https://app.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?langwritten=$languageCode&pub=$pubKey&track=$track&fileformat=mp3";
      try {
        final response = await http.get(Uri.parse(mediaApi));
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          Map<String, dynamic> jsonResponse = json.decode(jsonFile);

          String titleAudio = jsonResponse['files'][languageCode]['MP3'][0]['title'];
          String albumAudio = jsonResponse['pubName'];
          String language = jsonResponse['languages'][languageCode]['name'];
          String urlAudio = jsonResponse['files'][languageCode]['MP3'][0]['file']['url'];
          String urlImage = audio['images']['sqr']['lg'];

          // Créer une source audio à partir de l'URL
          /*
          AudioSource audioLanguage = AudioSource.uri(
            Uri.parse(urlAudio),
            tag: MediaItem(
              id: '${mediaId++}',
              album: language,
              title: titleAudio,
              artUri: Uri.parse(urlImage),
            ),
          );

           */

          // Ajouter la source audio à la playlist
          //multiPlaylist.add(audioLanguage);

          // Si c'est le premier élément ajouté, commencer la lecture
          if (multiPlaylist.length == 2) {
            JwLifeApp.jwAudioPlayer.setLanguagePlaylist(multiPlaylist, albumAudio, id: Random().nextInt(2));
            JwLifeApp.jwAudioPlayer.setRandomMode(true);
            JwLifeApp.jwAudioPlayer.play();
          }
        }
        else {
          print('Failed to download language catalog $languageCode: ${response.statusCode}');
        }
      }
      catch (e) {
        print('Error updating language catalog $languageCode: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Chercher...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontFamily: 'NotoSans', fontSize: 15.0),
          onChanged: _filterAudios,
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              language,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
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
                  filteredAudios = widget.category.media;
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
                // Effectuer le travail asynchrone en dehors de setState
                await Api.updateLibrary(value['Symbol']);

                // Mise à jour synchrone dans setState
                setState(() {
                  setLibraryLanguage(value);
                  loadItems(value['Symbol']);
                });

                // Autres opérations après la mise à jour de l'état
                LoadPages.loadLatestVideos();
                LoadPages.loadTeachingToolbox();
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
            child: ListView.builder(
              dragStartBehavior: DragStartBehavior.down,
              itemCount: filteredAudios.length,
              itemBuilder: (context, index) {
                MediaItem mediaItem = realm.all<MediaItem>().query("naturalKey == '${filteredAudios[index]}'").first;

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
                              imageUrl: mediaItem.realmImages!.squareImageUrl!,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}