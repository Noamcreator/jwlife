import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import '../app/jwlife_app.dart';

import '../core/icons.dart';
import '../core/utils/common_ui.dart';
import '../core/utils/utils.dart';
import '../widgets/image_widget.dart';
import 'audio_player_model.dart';

class AudioPlayerWidget extends StatefulWidget {
  final bool visible;
  const AudioPlayerWidget({super.key, required this.visible});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  JwAudioPlayer jwAudioPlayer = JwLifeApp.jwAudioPlayer;
  bool _isPlaying = false;
  String _currentTitle = "";
  String _currentAlbum = "";
  ImageCachedWidget? _currentImageWidget;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    jwAudioPlayer.player.playerStateStream.listen((state) {
        setState(() {
          _isPlaying = state.playing;
        });
      });

    jwAudioPlayer.player.sequenceStateStream.listen((state) {
      SequenceState sequenceState = state;
      int? currentIndex = sequenceState.currentIndex;
      if(currentIndex != null) {
        ProgressiveAudioSource source = sequenceState.sequence[currentIndex] as ProgressiveAudioSource;

        var tag = source.tag as MediaItem;
        setState(() {
          _currentTitle = tag.title;
          _currentImageWidget = ImageCachedWidget(
            imageUrl: tag.artUri!.toString(),
            pathNoImage: 'pub_type_audio',
            width: 60,
            height: 60,
          );
          _currentAlbum = tag.album!;
        });
      }
    });

    jwAudioPlayer.player.durationStream.listen((duration) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      });

    jwAudioPlayer.player.positionStream.listen((position) {
        setState(() {
          _position = position;
        });
      });
  }

  void _changePitch(double pitch) {
    jwAudioPlayer.player.setPitch(pitch);
  }

  @override
  Widget build(BuildContext context) {
    return widget.visible ? GestureDetector(
      onTap: () {
        showPage(context, FullAudioView(),
        );
      },
      child: Stack(
        children: [
          Container(
            height: 88,
            padding: const EdgeInsets.only(top: 20.0, left: 0.0, right: 0.0, bottom: 0.0),
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3c3c3c) : const Color(0xFFe8e8e8),
            child: Row(
              children: [
                const SizedBox(width: 90.0),
                // Ajoutez le padding nécessaire ici
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _currentTitle,
                              style: const TextStyle(fontSize: 14.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ' - ',
                            style: const TextStyle(fontSize: 14.0),
                            maxLines: 1,
                          ),
                          Text(
                            '${formatDuration(_position.inSeconds.toDouble())} / ${formatDuration(_duration.inSeconds.toDouble())}',
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14.0),
                          ),
                          SizedBox(width: 15.0),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(JwIcons.triangle_to_bar_left),
                            onPressed: () {
                              if (jwAudioPlayer.player.hasPrevious) {
                                jwAudioPlayer.previous();
                              }
                              else {
                                jwAudioPlayer.player.seek(Duration.zero);
                              }
                            },
                          ),
                          IconButton(
                            iconSize: 23,
                            icon: Icon(_isPlaying ? JwIcons.pause : JwIcons.play),
                            onPressed: () {
                              setState(() {
                                if (_isPlaying) {
                                  jwAudioPlayer.pause();
                                }
                                else {
                                  jwAudioPlayer.play();
                                }
                              });
                            },
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: Icon(
                              JwIcons.triangle_to_bar_right,
                              color: jwAudioPlayer.player.hasNext ? null : Colors.grey, // Applique la couleur gris si désactivé
                            ),
                            onPressed: jwAudioPlayer.player.hasNext ? () => jwAudioPlayer.next() : () {},
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: Icon(jwAudioPlayer.player.volume == 0.0 ? JwIcons.sound_x : JwIcons.sound),
                            onPressed: () {
                              jwAudioPlayer.player.setVolume(jwAudioPlayer.player.volume == 0.0 ? 1.0 : 0.0);
                            },
                          ),
                          PopupMenuButton<String>(
                            color: Theme
                                .of(context)
                                .brightness == Brightness.dark ? const Color(
                                0xFF3c3c3c) : Colors.white,
                            icon: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              // Arrondir les bords
                              child: const Icon(
                                JwIcons.gear,
                                size: 18,
                              ),
                            ),
                            itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'download',
                                child: Text('Télécharger'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'share',
                                child: Text('Envoyer le lien'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'otherLanguages',
                                child: Text('Autres langues'),
                              ),
                              PopupMenuItem<String>(
                                value: 'pitch',
                                child: PopupMenuButton<String>(
                                  color: Theme
                                      .of(context)
                                      .brightness == Brightness.dark
                                      ? const Color(0xFF3c3c3c)
                                      : Colors.white,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: const [
                                      Text('Pitch'),
                                      Icon(Icons.arrow_right),
                                      // Flèche indiquant un sous-menu
                                    ],
                                  ),
                                  onSelected: (String value) {
                                    switch (value) {
                                      case 'pitch-2':
                                        _changePitch(0.8);
                                        break;
                                      case 'pitch-1':
                                        _changePitch(0.9);
                                        break;
                                      case 'pitch0':
                                        _changePitch(1.0);
                                        break;
                                      case 'pitch1':
                                        _changePitch(1.1);
                                        break;
                                      case 'pitch2':
                                        _changePitch(1.2);
                                        break;
                                      default:
                                        break;
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'pitch-2',
                                      child: Text('-2'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'pitch-1',
                                      child: Text('-1'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'pitch0',
                                      child: Text('0'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'pitch1',
                                      child: Text('+1'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'pitch2',
                                      child: Text('+2'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (String value) {
                              switch (value) {
                                case 'download':
                                // Action to download
                                  break;
                                case 'share':
                                // Action to share
                                  break;
                                case 'otherLanguages':
                                // Action for other languages
                                  break;
                                default:
                                  break;
                              }
                            },
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(JwIcons.x),
                            onPressed: () async {
                              await jwAudioPlayer.close();
                              setState(() {
                                _currentImageWidget = null;
                                _currentTitle = "";
                                _currentAlbum = "";
                                _position = Duration.zero;
                                _duration = Duration.zero;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -7,
            left: 0,
            right: 0,
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
              ),
              child: Slider(
                inactiveColor: Colors.grey[500],
                activeColor: Theme.of(context).primaryColor,
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) {
                  jwAudioPlayer.player.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 15,
            child: _currentImageWidget == null ? Container() : ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: _currentImageWidget
            )
          ),
        ],
      ),
    ) : Container();
  }
}

class FullAudioView extends StatefulWidget {
  const FullAudioView({super.key});

  @override
  _FullAudioViewState createState() => _FullAudioViewState();
}

class _FullAudioViewState extends State<FullAudioView> {
  JwAudioPlayer jwAudioPlayer = JwLifeApp.jwAudioPlayer;
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