import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_media.dart';
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

  late StreamSubscription<SequenceState?>  _streamSubscription;

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);
    _streamSubscription = JwLifeApp.jwAudioPlayer.player.sequenceStateStream.listen((state) {
      int? currentIndex;
      if(state != null) {
        SequenceState sequenceState = state;
        currentIndex = sequenceState.currentIndex;
      }

      JwLifeApp.jwAudioPlayer.setId(currentIndex);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  void loadItems(String? languageCode) async {
    // Eviter de charger les données plusieurs fois
    if (language == languageCode) return;

    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm.all<Language>().query("symbol == '$languageCode'").first;

    setState(() {
      language = lang.vernacular!;
      categoryName = widget.category.localizedName!;
    });

    setState(() {
      filteredAudios = widget.category.media.map((key) {
        return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
      }).toList();
    });
  }

  void _filterAudios(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredAudios = widget.category.media.map((key) {
          return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
        }).toList();
      });
    } else {
      setState(() {
        filteredAudios = widget.category.media.where((audio) {
          MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$audio'").first;
          return mediaItem.title!.toLowerCase().contains(query.toLowerCase());
        }).map((audio) {
          return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$audio'").first;
        }).toList();
      });
    }
  }

  void _play(int index) async {
    // Pas de besoin de redemander la liste à chaque fois
    JwLifeApp.jwAudioPlayer.playAudiosCategory(widget.category, filteredAudios, id: index);
  }

  void _playAll() async {
    JwLifeApp.jwAudioPlayer.playAudiosCategory(widget.category, filteredAudios);
  }

  void _playRandom() async {
    JwLifeApp.jwAudioPlayer.playAudiosCategory(widget.category, filteredAudios, id: Random().nextInt(filteredAudios.length - 1), randomMode: true);
  }

  void _playRandomLanguage() async {
    // Fonctionnalité à définir selon vos besoins
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
            hintText: 'Chercher...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18.0, decoration: TextDecoration.none),
          onChanged: _filterAudios,
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: textStyleTitle),
            Text(language, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? JwIcons.x : JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
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
                await setLibraryLanguage(value);
                loadItems(value['Symbol']);
                HomeView.setStateHomePage();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _buildOutlinedButton(Icons.playlist_play, "TOUT LIRE", _playAll),
                const SizedBox(width: 10),
                _buildOutlinedButton(Icons.shuffle, "LECTURE ALÉATOIRE", _playRandom),
                const SizedBox(width: 10),
                _buildOutlinedButton(JwIcons.language, "LANGUE ALÉATOIRE", _playRandomLanguage),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(5.0),
              itemCount: filteredAudios.length,
              itemBuilder: (context, index) => buildAudioItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlinedButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        overlayColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF8e8e8e) : Color(0xFF757575),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }

  Widget buildAudioItem(int index) {
    MediaItem mediaItem = filteredAudios[index];

    return Stack(
      children: [
        SizedBox(
          height: 60,
          child: InkWell(
            onTap: () {
              _play(index);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: ImageCachedWidget(
                        imageUrl: mediaItem.realmImages!.squareFullSizeImageUrl ?? mediaItem.realmImages!.squareImageUrl,
                        pathNoImage: "pub_type_audio",
                        height: 55,
                        width: 55),
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                            color: JwLifeApp.jwAudioPlayer.currentId == index &&
                                JwLifeApp.jwAudioPlayer.album == widget.category.localizedName
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).secondaryHeaderColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDuration(mediaItem.duration!),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF8e8e8e)
                                : Color(0xFF757575),
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
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF8e8e8e)
                  : Color(0xFF757575),
              size: 25,
            ),
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
      ],
    );
  }
}
