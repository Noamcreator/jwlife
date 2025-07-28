import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:realm/realm.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../widgets/searchfield/searchfield_widget.dart';

class AudioItemsPage extends StatefulWidget {
  final Category category;

  const AudioItemsPage({super.key, required this.category});

  @override
  _AudioItemsPageState createState() => _AudioItemsPageState();
}

class _AudioItemsPageState extends State<AudioItemsPage> {
  String categoryName = '';
  String language = '';

  // Liste complète des médias
  List<MediaItem> allAudios = [];

  // Liste filtrée (change selon recherche)
  List<MediaItem> filteredAudios = [];

  bool _isSearching = false;

  late StreamSubscription<SequenceState?> _streamSequenceStateSubscription;

  @override
  void initState() {
    super.initState();
    loadItems(widget.category.language);
    _streamSequenceStateSubscription = JwLifeApp.audioPlayer.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      if (state.currentIndex != null) {
        if (JwLifeApp.audioPlayer.isSettingPlaylist && state.currentIndex == 0) return;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _streamSequenceStateSubscription.cancel();
    super.dispose();
  }

  void loadItems(String? languageCode) async {
    if (language == languageCode) return;

    RealmLibrary.realm.refresh();
    Language lang = RealmLibrary.realm.all<Language>().query("symbol == '$languageCode'").first;

    // On charge la liste complète uniquement ici
    allAudios = widget.category.media.map((key) {
      return RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$key'").first;
    }).toList();

    // Au début, filteredAudios = allAudios (pas de filtre)
    filteredAudios = List.from(allAudios);

    setState(() {
      language = lang.vernacular!;
      categoryName = widget.category.localizedName!;
    });
  }

  void _filterAudios(String query) {
    if (query.isEmpty) {
      setState(() {
        // Remet filteredAudios à la liste complète
        filteredAudios = List.from(allAudios);
      });
    } else {
      setState(() {
        filteredAudios = allAudios.where((mediaItem) {
          return mediaItem.title!.toLowerCase().contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _play(int index) async {
    JwLifeApp.audioPlayer.playAudios(widget.category, allAudios, id: index);
  }

  void _playAll() async {
    JwLifeApp.audioPlayer.playAudios(widget.category, allAudios);
  }

  void _playRandom() async {
    if (allAudios.isEmpty) return;
    final randomIndex = Random().nextInt(allAudios.length);
    JwLifeApp.audioPlayer.playAudios(widget.category, allAudios, id: randomIndex, randomMode: true);
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
      resizeToAvoidBottomInset: false,
      appBar: _isSearching
          ? AppBar(
        title: SearchFieldWidget(
          query: '',
          onSearchTextChanged: (text) {
            setState(() {
              _filterAudios(text);
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
              _filterAudios('');
            });
          },
        ),
      )
          : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: textStyleTitle),
            Text(language, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                _isSearching = true;
                _filterAudios('');
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
                loadItems(JwLifeSettings().currentLanguage.symbol);
                GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
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
    int id = allAudios.indexOf(mediaItem);

    return Stack(
      children: [
        SizedBox(
          height: 60,
          child: InkWell(
            onTap: () {
              _play(id);
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
                      width: 55,
                    ),
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
                            color: JwLifeApp.audioPlayer.currentId == id &&
                                JwLifeApp.audioPlayer.album == widget.category.localizedName
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).secondaryHeaderColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDuration(mediaItem.duration!),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF8e8e8e) : Color(0xFF757575),
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
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF8e8e8e) : Color(0xFF757575),
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
