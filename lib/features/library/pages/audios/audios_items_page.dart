import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:realm/realm.dart';

import '../../../../app/app_page.dart';
import '../../../../app/jwlife_app_bar.dart';
import '../../../../core/api/api.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../i18n/i18n.dart';
import '../../../../widgets/responsive_appbar_actions.dart';
import '../../../../widgets/searchfield/searchfield_widget.dart';

class AudioItemsPage extends StatefulWidget {
  final RealmCategory category;

  const AudioItemsPage({super.key, required this.category});

  @override
  _AudioItemsPageState createState() => _AudioItemsPageState();
}

class _AudioItemsPageState extends State<AudioItemsPage> {
  RealmCategory? _category;
  late RealmLanguage _language;

  // Liste complète des médias
  List<Audio> _allAudios = [];

  // Liste filtrée (change selon recherche)
  List<Audio> _filteredAudios = [];

  bool _isSearching = false;

  late StreamSubscription<SequenceState?> _streamSequenceStateSubscription;

  @override
  void initState() {
    super.initState();

    _category = widget.category;

    loadItems();

    _streamSequenceStateSubscription = JwLifeApp.audioPlayer.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      if (state.currentIndex != null) {
        if (JwLifeApp.audioPlayer.isSettingPlaylist && state.currentIndex == 0) return;
        setState(() {});
      }
      else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _streamSequenceStateSubscription.cancel();
    super.dispose();
  }

  void loadItems({String? symbol}) async {
    symbol ??= widget.category.languageSymbol;

    RealmLibrary.realm.refresh();
    RealmLanguage? lang = RealmLibrary.realm.all<RealmLanguage>().query("Symbol == '$symbol'").firstOrNull;
    if(lang == null) return;
    _category = RealmLibrary.realm.all<RealmCategory>().query("Key == '${widget.category.key}' AND LanguageSymbol == '$symbol'").firstOrNull ?? _category;

    setState(() {
      _language = lang;
      // On charge la liste complète uniquement ici
      _allAudios = _category!.media.map((naturalKey) {
        return Audio.fromJson(mediaItem: RealmLibrary.getMediaItemByNaturalKey(naturalKey, lang.symbol!));
      }).toList();

      // Au début, filteredAudios = allAudios (pas de filtre)
      _filteredAudios = List.from(_allAudios);
    });
  }

  void _filterAudios(String query) {
    if (query.isEmpty) {
      setState(() {
        // Remet filteredAudios à la liste complète
        _filteredAudios = List.from(_allAudios);
      });
    } else {
      // 1. Normaliser la requête de recherche : minuscule + suppression des diacritiques
      final normalizedQuery = normalize(query);

      setState(() {
        _filteredAudios = _allAudios.where((mediaItem) {
          // 2. Normaliser le titre de l'élément pour la comparaison
          final normalizedTitle = normalize(mediaItem.title);

          // 3. Comparer les chaînes normalisées
          return normalizedTitle.contains(normalizedQuery);
        }).toList();
      });
    }
  }

  void _play(Audio audio) async {
    JwLifeApp.audioPlayer.playAudios(_category ?? widget.category, _allAudios, first: audio);
  }

  void _playAll() async {
    JwLifeApp.audioPlayer.playAudios(_category ?? widget.category, _allAudios);
  }

  void _playRandom() async {
    JwLifeApp.audioPlayer.playAudios(_category ?? widget.category, _allAudios, randomMode: true);
  }

  void _playRandomLanguage() async {
    // Fonctionnalité à définir selon vos besoins
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_filteredAudios.isEmpty && !_isSearching) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            i18n().message_no_items_audios,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      );
    } else {
      bodyContent = Column(
        children: [
          // Boutons en haut (non scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _buildOutlinedButton(JwIcons.play, i18n().action_play_all.toUpperCase(), _playAll),
                const SizedBox(width: 10),
                _buildOutlinedButton(JwIcons.arrows_twisted_right, i18n().action_shuffle.toUpperCase(), _playRandom),
              ],
            ),
          ),
          // Liste scrollable
          Expanded(
            child: Directionality(
              textDirection: _language.isRtl! ? TextDirection.rtl : TextDirection.ltr,
              child: ListView.builder(
                padding: const EdgeInsets.all(5.0),
                itemCount: _filteredAudios.length,
                itemBuilder: (context, index) => buildAudioItem(index),
              ),
            ),
          ),
        ],
      );
    }

    return AppPage(
      appBar: _isSearching
          ? AppBar(
        titleSpacing: 0.0,
        title: SearchFieldWidget(
          query: '',
          onSearchTextChanged: (text) {
            _filterAudios(text);
            return;
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
          icon: const Icon(JwIcons.chevron_left),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _filterAudios('');
            });
          },
        ),
      )
          : JwLifeAppBar(
        title: _category?.name ?? '',
        subTitle: _language.vernacular,
        actions: [
          IconTextButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: (BuildContext context) {
              setState(() {
                _isSearching = true;
                _filterAudios('');
              });
            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.language),
            onPressed: (BuildContext context) async {
              showLanguageDialog(context, selectedLanguageSymbol: _language.symbol).then((language) async {
                if (language != null) {
                  loadItems(symbol: language['Symbol']);

                  if (await Api.isLibraryUpdateAvailable(symbol: language['Symbol'])) {
                    Api.updateLibrary(language['Symbol']!).then((_) {
                      loadItems(symbol: language['Symbol']);
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

  Widget _buildOutlinedButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget buildAudioItem(int index) {
    Audio audio = _filteredAudios[index];
    int id = _allAudios.indexOf(audio);

    return SizedBox(
      height: kAudioItemHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _play(audio),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(start: 10, end: 0),
                child: Row(
                  children: [
                    // --- Image ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: ImageCachedWidget(
                        imageUrl: audio.networkImageSqr,
                        icon: JwIcons.headphones__simple,
                        height: kAudioItemHeight-5,
                        width: kAudioItemHeight-5,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // --- Titre / Durée ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            audio.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                              color: JwLifeApp.audioPlayer.currentId == id &&
                                  JwLifeApp.audioPlayer.album?.name ==
                                      (_category?.name ?? widget.category.name)
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).secondaryHeaderColor,
                            ),
                            maxLines: 1,
                          ),
                          Text(
                            formatDuration(audio.duration),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF8e8e8e)
                                  : const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Actions ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionIcon(context, audio),
                        PopupMenuButton(
                          useRootNavigator: true,
                          icon: Icon(
                            Icons.more_horiz,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF8e8e8e)
                                : const Color(0xFF757575),
                            size: 25,
                          ),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context) => [
                            if (audio.isDownloadedNotifier.value && audio.filePath != null) getAudioShareFileItem(audio),
                            getAudioShareItem(audio),
                            getAudioQrCode(context, audio),
                            getAudioAddPlaylistItem(context, audio),
                            getAudioLanguagesItem(context, audio),
                            getAudioFavoriteItem(audio),
                            getAudioDownloadItem(context, audio),
                            getAudioLyricsItem(context, audio),
                            getCopyLyricsItem(audio),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Barre de progression EN BAS ---
              PositionedDirectional(
                start: 70,
                end: 0,
                bottom: 4,
                child: ValueListenableBuilder<bool>(
                  valueListenable: audio.isDownloadingNotifier,
                  builder: (context, isDownloading, _) {
                    if (!isDownloading) return const SizedBox.shrink();

                    return ValueListenableBuilder<double>(
                      valueListenable: audio.progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress == -1 ? null : progress,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                          backgroundColor: Colors.black.withOpacity(0.2),
                          minHeight: 2,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(BuildContext context, Audio audio) {
    return ValueListenableBuilder<bool>(
      valueListenable: audio.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        if (isDownloading) {
          return IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            onPressed: () => audio.cancelDownload(context),
            icon: const Icon(
              JwIcons.x,
              color: Colors.grey,
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: audio.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: audio.isFavoriteNotifier,
              builder: (context, isFavorite, _) {
                final hasUpdate = audio.hasUpdate();

                if (!isDownloaded) {
                  return IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: () => audio.download(context),
                    icon: const Icon(
                      JwIcons.cloud_arrow_down,
                      color: Colors.grey,
                    ),
                  );
                } else if (hasUpdate) {
                  return IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: () => audio.download(context),
                    icon: const Icon(
                      JwIcons.arrows_circular,
                      color: Colors.grey,
                    ),
                  );
                } else if (isFavorite) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                    child: Icon(
                      JwIcons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}