import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/realm/catalog.dart' as realm;
import 'package:path_provider/path_provider.dart';
import '../../app/jwlife_app.dart';
import '../../core/icons.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_video.dart';
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
  int _pitch = 0;

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
            icon: JwIcons.headphones__simple,
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

      if (position != Duration.zero && position.inSeconds == _duration.inSeconds && !jwAudioPlayer.player.hasNext) {
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
    String? keySymbol = _currentExtras?['keySymbol'];
    int? track = _currentExtras?['track'];
    int? mepsDocumentId = _currentExtras?['documentId'];
    int? issueTagNumber = _currentExtras?['issueTagNumber'];
    String? mepsLanguage = _currentExtras?['mepsLanguage'];

    realm.MediaItem? mediaItem = getMediaItem(keySymbol, track, mepsDocumentId, issueTagNumber, mepsLanguage);

    return GestureDetector(
      onTap: () {
        showPage(FullAudioView());
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
                          icon: JwIcons.headphones__simple,
                          height: 50,
                          width: 50
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
                            Expanded(
                              child: _currentExtras?["stream"] ?? true == true
                                  ? Row(
                                children: [
                                  Icon(JwIcons.stream, size: 15),
                                  const SizedBox(width: 5),
                                  Expanded( // <-- important pour gérer l’ellipsis
                                    child: Text(
                                      _currentTitle,
                                      style: const TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                                  : Text(
                                _currentTitle,
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${formatDuration(_position.inSeconds.toDouble())} / ${formatDuration(_duration.inSeconds.toDouble())}',
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
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
                                  icon: Icon(JwIcons.gear, size: 22),
                                  onOpened: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(true),
                                  onSelected: (value) => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
                                  onCanceled: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
                                  constraints: const BoxConstraints(minWidth: 2.0),
                                  offset: Offset(30, mediaItem != null ? -350 : -260),
                                  popUpAnimationStyle: AnimationStyle(
                                    curve: Curves.fastLinearToSlowEaseIn,
                                    duration: const Duration(milliseconds: 200),
                                    reverseCurve: Curves.fastLinearToSlowEaseIn,
                                    reverseDuration: const Duration(milliseconds: 200),
                                  ),
                                  itemBuilder: (context) {
                                    final List<PopupMenuEntry> items = [];

                                    if (mediaItem != null) {
                                      Audio audio = Audio.fromJson(mediaItem: mediaItem);
                                      items.add(getAudioShareItem(audio));
                                      items.add(getAudioAddPlaylistItem(context, audio));
                                    }

                                    // ---- SOUS MENU VITESSE ----
                                    items.add(
                                      PopupMenuItem(
                                        onTap: () async {
                                          final value = await showMenu<double>(
                                            context: context,
                                            popUpAnimationStyle: AnimationStyle(
                                              curve: Curves.fastLinearToSlowEaseIn,
                                              duration: const Duration(milliseconds: 200),
                                              reverseCurve: Curves.fastLinearToSlowEaseIn,
                                              reverseDuration: const Duration(milliseconds: 200),
                                            ),
                                            position: RelativeRect.fromLTRB(30, 150, 0, 0),
                                            items: <PopupMenuEntry<double>>[
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
                                          );
                                          if (value != null) {
                                            setSpeed(value);
                                          }
                                        },
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
                                      ),
                                    );

                                    // ---- SOUS MENU SHUFFLE ----
                                    items.add(
                                      PopupMenuItem(
                                        onTap: () async {
                                          final value = await showMenu<String>(
                                            context: context,
                                            position: RelativeRect.fromLTRB(30, 625, 0, 0),
                                            popUpAnimationStyle: AnimationStyle(
                                              curve: Curves.fastLinearToSlowEaseIn,
                                              duration: const Duration(milliseconds: 200),
                                              reverseCurve: Curves.fastLinearToSlowEaseIn,
                                              reverseDuration: const Duration(milliseconds: 200),
                                            ),
                                            items: const [
                                              PopupMenuItem<String>(
                                                value: 'off',
                                                child: Text('Inactif'),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'on',
                                                child: Text('Activé'),
                                              ),
                                            ],
                                          );
                                          if (value != null) {
                                            jwAudioPlayer.player.setShuffleModeEnabled(value == 'on');
                                          }
                                        },
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
                                      ),
                                    );

                                    // ---- SOUS MENU LOOP ----
                                    items.add(
                                      PopupMenuItem(
                                        onTap: () async {
                                          final value = await showMenu<String>(
                                            context: context,
                                            popUpAnimationStyle: AnimationStyle(
                                              curve: Curves.fastLinearToSlowEaseIn,
                                              duration: const Duration(milliseconds: 200),
                                              reverseCurve: Curves.fastLinearToSlowEaseIn,
                                              reverseDuration: const Duration(milliseconds: 200),
                                            ),
                                            position: RelativeRect.fromLTRB(30, 580, 0, 0),
                                            items: const [
                                              PopupMenuItem<String>(
                                                value: 'off',
                                                child: Text('Inactif'),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'all',
                                                child: Text('Toutes les pistes'),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'one',
                                                child: Text('La piste'),
                                              ),
                                            ],
                                          );
                                          if (value != null) {
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
                                          }
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(_loopMode == LoopMode.off
                                                    ? JwIcons.arrows_loop_crossed
                                                    : _loopMode == LoopMode.all
                                                    ? JwIcons.arrows_loop
                                                    : JwIcons.arrows_loop_1),
                                                const SizedBox(width: 8),
                                                Text('Répéter · ${_loopMode == LoopMode.off ? 'Inactif' : _loopMode == LoopMode.all ? 'Toutes les pistes' : 'La piste'}'),
                                              ],
                                            ),
                                            const Icon(JwIcons.chevron_right),
                                          ],
                                        ),
                                      ),
                                    );

                                    // ---- SOUS MENU PITCH ----
                                    items.add(
                                      PopupMenuItem(
                                        onTap: () async {
                                          final value = await showMenu<String>(
                                            context: context,
                                            popUpAnimationStyle: AnimationStyle(
                                              curve: Curves.fastLinearToSlowEaseIn,
                                              duration: const Duration(milliseconds: 200),
                                              reverseCurve: Curves.fastLinearToSlowEaseIn,
                                              reverseDuration: const Duration(milliseconds: 200),
                                            ),
                                            position: RelativeRect.fromLTRB(30, 480, 0, 0),
                                            items: const [
                                              PopupMenuItem<String>(value: 'pitch2', child: Text('+2 demi-tons au-dessus')),
                                              PopupMenuItem<String>(value: 'pitch1', child: Text('+1 demi-ton au-dessus')),
                                              PopupMenuItem<String>(value: 'pitch0', child: Text('Pitch normal')),
                                              PopupMenuItem<String>(value: 'pitch-1', child: Text('-1 demi-ton en dessous')),
                                              PopupMenuItem<String>(value: 'pitch-2', child: Text('-2 demi-tons en dessous')),
                                            ],
                                          );
                                          if (value != null) {
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
                                          }
                                        },
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
                icon: JwIcons.headphones__simple,
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
    try {
      Color palette;

      if (_currentImageWidget!.imageUrl!.startsWith('https')) {
        // Télécharger l’image temporairement
        final response = await NetworkAssetBundle(Uri.parse(_currentImageWidget!.imageUrl!)).load("");
        final Uint8List bytes = response.buffer.asUint8List();
        final tempFile = File('${(await getApplicationCacheDirectory()).path}/temp_img.jpg');
        await tempFile.writeAsBytes(bytes);
        palette = await getDominantColorFromFile(tempFile);
      }
      else if (_currentImageWidget!.imageUrl!.startsWith('file')) {
        final file = File.fromUri(Uri.parse(_currentImageWidget!.imageUrl!));
        palette = await getDominantColorFromFile(file);
      }
      else {
        palette = const Color(0xFF8e8e8e);
      }

      setState(() {
        _dominantColor = palette;
      });
    } catch (e) {
      setState(() {
        _dominantColor = const Color(0xFFE0E0E0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                        onPressed: () {
                          _playerStateSubscription.cancel();
                          _sequenceStateSubscription.cancel();
                          _durationSubscription.cancel();
                          _positionSubscription.cancel();
                          GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
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
                            icon: JwIcons.headphones__simple,
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