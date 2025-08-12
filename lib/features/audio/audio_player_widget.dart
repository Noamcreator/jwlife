import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/realm/catalog.dart' as realm;
import 'package:palette_generator/palette_generator.dart';
import 'package:realm/realm.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/jwlife_app.dart';
import '../../core/icons.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_video.dart';
import '../../data/realm/realm_library.dart';
import '../../widgets/image_cached_widget.dart';
import 'audio_player_model.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  JwLifeAudioPlayer jwAudioPlayer = JwLifeApp.audioPlayer;
  bool _isPlaying = false;
  String _currentTitle = "";
  Map<String, dynamic>? _currentExtras = {};
  ImageCachedWidget? _currentImageWidget;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _shuffleMode = false;
  LoopMode _loopMode = LoopMode.off;

  double _volume = 1.0;
  double _speed = 1.0;
  int _pitch = 1;

  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<SequenceState?> _sequenceStateSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<bool> _shuffleModeSub;

  @override
  void initState() {
    super.initState();

    _playerStateSub = jwAudioPlayer.player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _sequenceStateSub = jwAudioPlayer.player.sequenceStateStream.listen((state) {
      if (state.currentIndex != null) {

        if (jwAudioPlayer.isSettingPlaylist && state.currentIndex == 0) return;

        jwAudioPlayer.setId(state.currentIndex);

        var source = state.sequence[state.currentIndex!] as ProgressiveAudioSource;
        var tag = source.tag as MediaItem;

        if (!mounted) return;
        setState(() {
          _currentTitle = tag.title;
          _currentImageWidget = ImageCachedWidget(
            imageUrl: tag.artUri!.toString(),
            pathNoImage: 'pub_type_audio',
            width: 50,
            height: 50,
          );
          _currentExtras = tag.extras;
        });
      }
    });

    _durationSub = jwAudioPlayer.player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    _positionSub = jwAudioPlayer.player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });

      if (position != Duration.zero &&
          position.inSeconds == _duration.inSeconds &&
          !jwAudioPlayer.player.hasNext) {
        jwAudioPlayer.close();
      }
    });

    _shuffleModeSub = jwAudioPlayer.player.shuffleModeEnabledStream.listen((randomMode) {
      if (!mounted) return;
      setState(() {
        _shuffleMode = randomMode;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSub.cancel();
    _sequenceStateSub.cancel();
    _durationSub.cancel();
    _positionSub.cancel();
    _shuffleModeSub.cancel();
    super.dispose();
  }

  void setPitchBySemitone(int semitones) {
    _pitch = semitones;
    final pitch = pow(2, semitones / 12).toDouble();
    jwAudioPlayer.player.setPitch(pitch);
  }

  void setSpeed(double speed) {
    _speed = speed;
    jwAudioPlayer.player.setSpeed(_speed);
  }

  void setVolume(double volume) {
    _volume = volume;
    jwAudioPlayer.player.setVolume(_volume);
  }

  // Fonction utilitaire à mettre en dehors
  PopupMenuItem<double> _speedItem(double speed, [String? label]) {
    return PopupMenuItem<double>(
      value: speed,
      child: Text(
        '${speed.toStringAsFixed(1).replaceAll('.', ',')}x'
            '${label != null ? ' · $label' : ''}',
      ),
    );
  }

  String buildSpeedLabel() {
    String labelForSpeed(double speed) {
      if (speed == 2.0) return 'Rapide';
      if (speed == 1.0) return 'Normale';
      if (speed == 0.5) return 'Lente';
      return '';
    }

    final speedStr = '${_speed.toStringAsFixed(1).replaceAll('.', ',')}x';
    final label = labelForSpeed(_speed);

    return 'Vitesse de lecture · $speedStr${label.isNotEmpty ? ' · $label' : ''}';
  }

  String buildPitchLabel() {
    if (_pitch == 0) {
      return 'Pitch · Normal';
    } else if (_pitch > 0) {
      return 'Pitch · $_pitch demi-ton${_pitch > 1 ? 's' : ''} au-dessus';
    } else {
      final absPitch = _pitch.abs();
      return 'Pitch · $absPitch demi-ton${absPitch > 1 ? 's' : ''} en dessous';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showPage(context, FullAudioView());
      },
      child: Container(
        height: 80,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3c3c3c)
            : const Color(0xFFe8e8e8),
        child: Stack(
          children: [
            // Slider en haut
            Positioned(
              top: -8,
              left: -5,
              right: -5,
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 2.0,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
                ),
                child: Slider(
                  inactiveColor: Colors.grey[500],
                  activeColor: Theme.of(context).primaryColor,
                  value: _duration.inSeconds.toDouble() == 0 ? 0 : _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    jwAudioPlayer.player.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
            ),

            Positioned(
              top: 18,
              left: 10,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _currentImageWidget ??
                      ImageCachedWidget(
                          imageUrl: "",
                          pathNoImage: "pub_type_audio",
                          height: 65,
                          width: 65
                      )
              ),
            ),

            // Contenu principal
            Positioned(
              top: 20,
              left: 62,
              right: 10,
              bottom: -10,
              child: Row(
                children: [
                  const SizedBox(width: 10),

                  // Contenu de droite (titre + boutons)
                  Expanded(
                    child: Column(
                      children: [
                        // Titre et temps
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _currentTitle,
                                style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500, height: 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${formatDuration(_position.inSeconds.toDouble())} / ${formatDuration(_duration.inSeconds.toDouble())}',
                              style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500, height: 1),
                            ),
                          ],
                        ),

                        // Boutons de contrôle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Bouton précédent/restart
                                GestureDetector(
                                  onTap: () {
                                    if (jwAudioPlayer.player.position.inSeconds == 0) {
                                      jwAudioPlayer.previous();
                                    }
                                    else {
                                      jwAudioPlayer.player.seek(Duration.zero);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: const Icon(JwIcons.triangle_to_bar_left, size: 22),
                                  ),
                                ),

                                // Bouton play/pause
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_isPlaying) {
                                        jwAudioPlayer.pause();
                                      } else {
                                        jwAudioPlayer.play();
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                        _isPlaying ? JwIcons.pause : JwIcons.play,
                                        size: 22
                                    ),
                                  ),
                                ),

                                // Bouton suivant
                                GestureDetector(
                                  onTap: jwAudioPlayer.player.hasNext ? () => jwAudioPlayer.next() : null,
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      JwIcons.triangle_to_bar_right,
                                      size: 22,
                                      color: jwAudioPlayer.player.hasNext ? null : Colors.grey,
                                    ),
                                  ),
                                ),

                                // Bouton retour de 5 secondes
                                GestureDetector(
                                  onTap: () {
                                    // reculer 5 secondes
                                    jwAudioPlayer.player.seek(jwAudioPlayer.player.position - Duration(seconds: 5));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      JwIcons.arrow_circular_left_5,
                                      size: 22,
                                    ),
                                  ),
                                ),

                                // Bouton avancer de 15 secondes
                                GestureDetector(
                                  onTap: () {
                                    // avancer 15 secondes
                                    jwAudioPlayer.player.seek(jwAudioPlayer.player.position + Duration(seconds: 15));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      JwIcons.arrow_circular_right_15,
                                      size: 22,
                                    ),
                                  ),
                                ),

                                // Bouton volume
                                GestureDetector(
                                  onTap: () {
                                    jwAudioPlayer.player.setVolume(jwAudioPlayer.player.volume == 0.0 ? 1.0 : 0.0);
                                  },
                                  child: Icon(jwAudioPlayer.player.volume == 0.0 ? JwIcons.sound_x : JwIcons.sound, size: 22),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Menu des paramètres
                                PopupMenuButton(
                                  icon: Icon(
                                    JwIcons.gear,
                                    size: 22,
                                  ),
                                  // augmenter la taille en largeur
                                  constraints: const BoxConstraints(minWidth: 2.0),
                                  // monter le menu vers le haut
                                  offset: const Offset(30, -385),
                                  // animation de l'ouverture vers le haut
                                  popUpAnimationStyle: AnimationStyle.noAnimation,
                                  itemBuilder: (context) {
                                    String? naturalKey = _currentExtras?['naturalKey'];
                                    String? keySymbol = _currentExtras?['keySymbol'];
                                    int? track = _currentExtras?['track'];
                                    int? mepsDocumentId = _currentExtras?['documentId'];
                                    int? issueTagNumber = _currentExtras?['issueTagNumber'];
                                    String? mepsLanguage = _currentExtras?['mepsLanguage'];

                                    realm.MediaItem? mediaItem;
                                    if (naturalKey != null) {
                                      mediaItem = RealmLibrary.realm
                                          .all<realm.MediaItem>()
                                          .query("naturalKey == '$naturalKey'")
                                          .firstOrNull;
                                    } else {
                                      mediaItem = getMediaItem(keySymbol, track, mepsDocumentId, issueTagNumber, mepsLanguage);
                                    }

                                    final List<PopupMenuEntry> items = [];

                                    if (mediaItem != null) {
                                      items.add(getVideoShareItem(mediaItem));
                                      items.add(
                                        PopupMenuItem(
                                          child: Row(
                                            children: const [
                                              Icon(JwIcons.list_plus),
                                              SizedBox(width: 8),
                                              Text('Ajouter à la liste de lecture'),
                                            ],
                                          ),
                                          onTap: () {
                                            showAddPlaylistDialog(context, mediaItem);
                                          },
                                        ),
                                      );
                                    }

                                    items.add(
                                      PopupMenuItem(
                                        child: PopupMenuButton<String>(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF3c3c3c)
                                              : Colors.white,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(_loopMode == LoopMode.off ? JwIcons.arrows_loop_crossed : _loopMode == LoopMode.all ? JwIcons.arrows_loop : JwIcons.arrows_loop_1),
                                                  const SizedBox(width: 8),
                                                  Text('Répéter · ${_loopMode == LoopMode.off
                                                      ? 'Inactif'
                                                      : _loopMode == LoopMode.all
                                                      ? 'Toutes les pistes'
                                                      : 'La piste'}'),
                                                ],
                                              ),
                                              const Icon(JwIcons.chevron_right),
                                            ],
                                          ),
                                          onSelected: (String value) {
                                            switch (value) {
                                              case 'off':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.off);
                                                _loopMode = LoopMode.off;
                                                break;
                                              case 'all':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.all);
                                                _loopMode = LoopMode.all;
                                                break;
                                              case 'one':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.one);
                                                _loopMode = LoopMode.one;
                                                break;
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'off',
                                              child: Text('Inactif'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'all',
                                              child: Text('Toutes les pistes'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'one',
                                              child: Text('La piste'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    // Ajout de l’élément dans items
                                    items.add(
                                      PopupMenuItem(
                                        child: PopupMenuButton<double>(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF3c3c3c)
                                              : Colors.white,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(JwIcons.speedometer),
                                                  const SizedBox(width: 8),
                                                  Text(buildSpeedLabel()),
                                                ],
                                              ),
                                              const Icon(JwIcons.chevron_right),
                                            ],
                                          ),
                                          onSelected: (double value) {
                                            setSpeed(value);
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                                            _speedItem(2.0, 'Rapide'),
                                            _speedItem(1.8),
                                            _speedItem(1.6),
                                            _speedItem(1.4),
                                            _speedItem(1.2),
                                            _speedItem(1.1),
                                            _speedItem(1.0, 'Normale'),
                                            _speedItem(0.9),
                                            _speedItem(0.8),
                                            _speedItem(0.7),
                                            _speedItem(0.6),
                                            _speedItem(0.5, 'Lente'),
                                          ],
                                        ),
                                      ),
                                    );

                                    items.add(
                                      PopupMenuItem(
                                        child: PopupMenuButton<String>(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF3c3c3c)
                                              : Colors.white,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(JwIcons.arrows_twisted_right),
                                                  const SizedBox(width: 8),
                                                  Text('Lecture aléatoire · ${_shuffleMode ? 'Activé' : 'Inactif'}'),
                                                ],
                                              ),
                                              const Icon(JwIcons.chevron_right),
                                            ],
                                          ),
                                          onSelected: (String value) {
                                            switch (value) {
                                              case 'off':
                                                jwAudioPlayer.player.setShuffleModeEnabled(false);
                                                _shuffleMode = false;
                                                break;
                                              case 'on':
                                                jwAudioPlayer.player.setShuffleModeEnabled(true);
                                                _shuffleMode = true;
                                                break;
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'off',
                                              child: Text('Inactif'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'on',
                                              child: Text('Activé'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    items.add(
                                      PopupMenuItem(
                                        child: PopupMenuButton<String>(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF3c3c3c)
                                              : Colors.white,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(_loopMode == LoopMode.off ? JwIcons.arrows_loop_crossed : _loopMode == LoopMode.all ? JwIcons.arrows_loop : JwIcons.arrows_loop_1),
                                                  const SizedBox(width: 8),
                                                  Text('Répéter · ${_loopMode == LoopMode.off
                                                      ? 'Inactif'
                                                      : _loopMode == LoopMode.all
                                                      ? 'Toutes les pistes'
                                                      : 'La piste'}'),
                                                ],
                                              ),
                                              const Icon(JwIcons.chevron_right),
                                            ],
                                          ),
                                          onSelected: (String value) {
                                            switch (value) {
                                              case 'off':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.off);
                                                _loopMode = LoopMode.off;
                                                break;
                                              case 'all':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.all);
                                                _loopMode = LoopMode.all;
                                                break;
                                              case 'one':
                                                jwAudioPlayer.player.setLoopMode(LoopMode.one);
                                                _loopMode = LoopMode.one;
                                                break;
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'off',
                                              child: Text('Inactif'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'all',
                                              child: Text('Toutes les pistes'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'one',
                                              child: Text('La piste'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    items.add(
                                      PopupMenuItem(
                                        child: PopupMenuButton<String>(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF3c3c3c)
                                              : Colors.white,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(JwIcons.arrows_up_down),
                                                  const SizedBox(width: 8),
                                                  Text(buildPitchLabel()),
                                                ],
                                              ),
                                              const Icon(JwIcons.chevron_right),
                                            ],
                                          ),
                                          onSelected: (String value) {
                                            switch (value) {
                                              case 'pitch2':
                                                setPitchBySemitone(2);
                                                break;
                                              case 'pitch1':
                                                setPitchBySemitone(1);
                                                break;
                                              case 'pitch0':
                                                setPitchBySemitone(0);
                                                break;
                                              case 'pitch-1':
                                                setPitchBySemitone(-1);
                                                break;
                                              case 'pitch-2':
                                                setPitchBySemitone(-2);
                                                break;
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'pitch2',
                                              child: Text('+2 demi-tons au-dessus'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'pitch1',
                                              child: Text('+1 demi-ton au-dessus'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'pitch0',
                                              child: Text('Pitch normal'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'pitch-1',
                                              child: Text('-1 demi-ton en dessous'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'pitch-2',
                                              child: Text('-2 demi-tons en dessous'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    return items;
                                  },
                                ),

                                // Bouton fermer
                                GestureDetector(
                                  onTap: () async {
                                    await jwAudioPlayer.close();
                                    setState(() {
                                      _currentImageWidget = null;
                                      _currentTitle = "";
                                      _currentExtras = {};
                                      _position = Duration.zero;
                                      _duration = Duration.zero;
                                    });
                                  },
                                  child: const Icon(JwIcons.x, size: 22),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullAudioView extends StatefulWidget {
  const FullAudioView({super.key});

  @override
  _FullAudioViewState createState() => _FullAudioViewState();
}

class _FullAudioViewState extends State<FullAudioView> {
  JwLifeAudioPlayer jwAudioPlayer = JwLifeApp.audioPlayer;
  bool _isPlaying = false;
  String _currentTitle = "";
  String _currentAlbum = "";
  ImageCachedWidget? _currentImageWidget;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Color _dominantColor = Colors.black;

  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<SequenceState?> _sequenceStateSubscription;
  late StreamSubscription<Duration?> _durationSubscription;
  late StreamSubscription<Duration> _positionSubscription;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription =
        jwAudioPlayer.player.playerStateStream.listen((state) {
          setState(() {
            _isPlaying = state.playing;
          });
        });

    _sequenceStateSubscription =
        jwAudioPlayer.player.sequenceStateStream.listen((state) {
          int? currentIndex = state.currentIndex;
          if (currentIndex != null) {
            ProgressiveAudioSource source = state
                .sequence[currentIndex] as ProgressiveAudioSource;
            var tag = source.tag as MediaItem;

            setState(() {
              _currentTitle = tag.title;
              _currentAlbum = tag.album ?? "";
              _currentImageWidget = ImageCachedWidget(
                imageUrl: tag.artUri!.toString(),
                pathNoImage: 'pub_type_audio',
                width: 60,
                height: 60,
              );
            });

            _updateBackgroundColor();
          }
        });

    _durationSubscription =
        jwAudioPlayer.player.durationStream.listen((duration) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        });

    _positionSubscription =
        jwAudioPlayer.player.positionStream.listen((position) {
          setState(() {
            _position = position;
          });
        });

    _updateBackgroundColor();
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _sequenceStateSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    super.dispose();
  }

  Future<void> _updateBackgroundColor() async {
    ImageProvider imageProvider;
    if (_currentImageWidget!.imageUrl!.startsWith('https')) {
      imageProvider = NetworkImage(_currentImageWidget!.imageUrl!);
    }
    else if (_currentImageWidget!.imageUrl!.startsWith('file')) {
      imageProvider =
          FileImage(File.fromUri(Uri.parse(_currentImageWidget!.imageUrl!)));
    }
    else {
      imageProvider =
          FileImage(File.fromUri(Uri.parse(_currentImageWidget!.pathNoImage)));
    }

    final palette = await PaletteGenerator.fromImageProvider(imageProvider);

    setState(() {
      _dominantColor = palette.dominantColor?.color ?? Colors.black;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: _dominantColor,
        ),
        child: Column(
          children: [
            // Partie avec padding
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(
                            Icons.keyboard_arrow_down, color: Colors.white,
                            size: 32),
                        onPressed: () {
                          _playerStateSubscription.cancel();
                          _sequenceStateSubscription.cancel();
                          _durationSubscription.cancel();
                          _positionSubscription.cancel();
                          Navigator.pop(context);
                        },
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(Icons.more_vert, color: Colors.white,
                              size: 32),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _currentImageWidget != null
                              ? ImageCachedWidget(
                            imageUrl: _currentImageWidget!.imageUrl!,
                            pathNoImage: _currentImageWidget!.pathNoImage,
                            width: 380,
                            height: 380,
                          )
                              : Container(),
                        ),
                      ),
                    ),
                    // Alignement à gauche
                    Text(
                      _currentTitle,
                      style: TextStyle(color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _currentAlbum,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 5),
                  ],
                ),
              ),
            ),

            // Partie du slider sans padding, bien centré
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.0,
                      thumbColor: Colors.white,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                    ),
                    child: Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        jwAudioPlayer.player.seek(Duration(seconds: value
                            .toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(_position.inSeconds.toDouble()),
                            style: TextStyle(color: Colors.white)),
                        Text(formatDuration(_duration.inSeconds.toDouble()),
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contrôles audio
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                        Icons.skip_previous, color: Colors.white, size: 40),
                    onPressed: () {
                      jwAudioPlayer.previous();
                    },
                  ),
                  SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons
                          .play_circle_filled,
                      color: Colors.white,
                      size: 80,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isPlaying) {
                          jwAudioPlayer.pause();
                        } else {
                          jwAudioPlayer.play();
                        }
                      });
                    },
                  ),
                  SizedBox(width: 20),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white, size: 40),
                    onPressed: () {
                      jwAudioPlayer.next();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}