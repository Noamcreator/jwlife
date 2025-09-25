import 'dart:convert';
import 'dart:async'; // Importer pour utiliser Timer
import 'dart:io';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/data/databases/history.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app/services/global_key_service.dart';
import '../../core/api/api.dart';
import '../../core/utils/utils_playlist.dart';
import 'subtitles.dart';

class VideoPlayerPage extends StatefulWidget {
  final Video video;
  final dynamic onlineVideo;
  final Duration initialPosition;

  const VideoPlayerPage({super.key, required this.video, this.onlineVideo, this.initialPosition=Duration.zero});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  String _title = '';  // Valeur par défaut pour le titre
  Duration _duration = Duration.zero;  // Valeur par défaut pour la durée

  List<Subtitle> _subtitles = [];
  bool _isPositionSeeking = false;
  double _positionSlider = 0.0;
  Timer? _timer; // Variable pour le Timer
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _showSubtitle = false;

  @override
  void initState() {
    super.initState();
    _title = widget.video.title;
    _duration = Duration(seconds: widget.video.duration.toInt());

    History.insertVideo(widget.video);

    if(widget.video.isDownloadedNotifier.value) {
      playLocalVideo();
    }
    else if (widget.onlineVideo != null) {
      fetchMedia(widget.onlineVideo);
    }
    else {
      getVideoApi();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel(); // Annulez le Timer
    super.dispose();
  }

  // Method to play the video
  Future<void> getVideoApi() async {
    String? lank = widget.video.naturalKey;
    String? lang = widget.video.mepsLanguage;
    if(widget.video.fileUrl != null) {
      final videoUrl = widget.video.fileUrl!;
      await playOnlineVideo(videoUrl);
    }
    if (lank != null && lang != null) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank?clientType=www';
      printTime('apiUrl: $apiUrl');
      try {
        final response = await Api.httpGetWithHeaders(apiUrl);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          fetchMedia(data['media'][0]);
        }
        else {
          printTime('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        printTime('An exception occurred: $e');
      }
    }
    else {
      printTime('Lank or lang parameters are missing in the URL.');
    }
  }

  Future<void> fetchMedia(dynamic media) async {
    final videoUrl = media['files'][2]['progressiveDownloadURL']; // Adapt according to response structuresponse structure
    await playOnlineVideo(videoUrl);
  }

  Future<void> fetchPubMedia(dynamic media) async {
    final videoUrl = media['files']['F']['MP4'][2]['file']['url'];
    await playOnlineVideo(videoUrl);
  }

  // Method to play the video
  Future<void> playOnlineVideo(String videoUrl) async {
    Uri uriVideo = Uri.parse(videoUrl);
    _controller = VideoPlayerController.networkUrl(
        uriVideo,
        httpHeaders: Api.getHeaders()
      )
      ..initialize().then((_) {
        _controller!.play();
        _controller!.seekTo(widget.initialPosition);
        _controller!.addListener(() {
          setState(() {
            if(!_isPositionSeeking) {
              _positionSlider = _controller!.value.position.inSeconds.toDouble();
            }
          });
          if(_controller!.value.position >= _controller!.value.duration) {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          }
        });
        _timer = Timer(Duration(seconds: 3), () {
          setState(() {
            _controlsVisible = false;
          });
          GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
        });
      });
  }

  // Method to play the video
  Future<void> playLocalVideo() async {
    File file = File(widget.video.filePath!);

    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        _controller!.play();
        _controller!.seekTo(widget.initialPosition);
        _controller!.addListener(() {
          setState(() {
            if(!_isPositionSeeking) {
              _positionSlider = _controller!.value.position.inSeconds.toDouble();
            }
          });
          if(_controller!.value.position >= _controller!.value.duration) {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          }
        });
        _timer = Timer(Duration(seconds: 3), () {
          setState(() {
            _controlsVisible = false; // Toggle visibility
          });
          GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
        });
      });
  }

  // Méthode pour obtenir les sous-titres actuellement visibles
  Subtitle _getCurrentSubtitle() {
    final position = _controller!.value.position+Duration(milliseconds: 800);
    return _subtitles.firstWhere(
          (subtitle) =>
      position >= subtitle.startTime && position <= subtitle.endTime,
      orElse: () => Subtitle(text: '', startTime: Duration.zero, endTime: Duration.zero, alignment: Alignment.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _timer?.cancel();
        setState(() {
          _controlsVisible = !_controlsVisible;
        });
        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(_controlsVisible);

        if(_controlsVisible) {
          // lancer un timer de 3 secondes pour ensuite enlever la barre de navigation
          _timer = Timer(Duration(seconds: 3), () {
            setState(() {
              _controlsVisible = false;
            });
            GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
            _timer?.cancel();
          });
        }
      },
      onDoubleTapDown: (details) {
        final tapPosition = details.localPosition;
        final widgetWidth = context.size?.width ?? 0;

        // Si l'utilisateur double-tap sur la partie droite de l'ecran
        if (tapPosition.dx > widgetWidth / 2) {
          // on avance de 15 secondes
          _controller!.seekTo(_controller!.value.position + Duration(seconds: 15));
        }
        // Sinon on revient 15 secondes
        else {
          _controller!.seekTo(_controller!.value.position - Duration(seconds: 5));
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Stack(
          children: [
            // Vidéo centrée, derrière l'AppBar
            Positioned.fill(
              child: Center(
                child: Stack(
                  children: [
                    _controller != null && _controller!.value.isInitialized ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ) : Container(),
                    // Sous-titres au-dessus de la vidéo
                    if (_showSubtitle && _subtitles.isNotEmpty && _getCurrentSubtitle().text.isNotEmpty)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Align(
                          alignment: _getCurrentSubtitle().alignment,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: Text(
                              _getCurrentSubtitle().getText(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16
                              ),
                            ),
                          ),
                        ),
                      ),
                ]
              ),
            ),
            ),

            // AppBar positionné absolument
            if (_controlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0, // Pour ne pas avoir d'ombre sous l'AppBar
                  title: Text(_title, style: TextStyle(color: Colors.white)),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(JwIcons.list_plus, color: Colors.white),
                      onPressed: () {
                        showAddPlaylistDialog(context, widget.video);
                      },
                    ),
                    IconButton(
                      icon: Icon(JwIcons.screen_square_right, color: Colors.white),
                      onPressed: () async {
                        _controlsVisible = false;
                        final floating = Floating();
                        final canUsePiP = await floating.isPipAvailable;

                        if (canUsePiP) {
                          PiPStatus statusAfterEnabling  = await floating.enable(ImmediatePiP());
                          if (PiPStatus.disabled == statusAfterEnabling) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Échec de l’activation du mode PiP')),
                            );
                          }
                        }
                        else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Le mode PiP n’est pas disponible sur cet appareil')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

            // Contrôles positionnés en bas
            if (_controlsVisible)
              Positioned(
                bottom: 65,
                left: -15,
                right: -15,
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Ajout d'un espacement entre le slider et le texte
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2.0,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0), // Ajustez cette valeur pour réduire le rond
                        ),
                        child: Slider(
                          value: _positionSlider,
                          min: 0.0,
                          max: _duration.inSeconds.toDouble(),
                          onChanged: (double newValue) {
                            setState(() {
                              _positionSlider = newValue;
                            });
                          },
                          onChangeStart: (double newValue) {
                            setState(() {
                              _isPositionSeeking = true;
                            });
                          },
                          onChangeEnd: (double newValue) {
                            setState(() {
                              _positionSlider = newValue;
                              _controller!.seekTo(Duration(seconds: newValue.toInt()));
                              _isPositionSeeking = false;
                            });
                          },
                          activeColor: Theme.of(context).primaryColor,
                          inactiveColor: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      // Texte à côté du slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              "${formatDuration(_positionSlider)} / ${formatDuration(_duration.inSeconds.toDouble())}",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Boutons de contrôle vidéo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller != null && _controller!.value.isInitialized
                                    ? _controller!.value.isPlaying
                                    ? JwIcons.pause
                                    : JwIcons.play : JwIcons.play,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller!.value.isPlaying
                                      ? _controller!.pause()
                                      : _controller!.play();
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(JwIcons.arrow_circular_left_5, color: Colors.white),
                              onPressed: () {
                                _controller!.seekTo(Duration(seconds: _controller!.value.position.inSeconds - 5));
                              },
                            ),
                            IconButton(
                              icon: Icon(JwIcons.arrow_circular_right_15, color: Colors.white),
                              onPressed: () {
                                _controller!.seekTo(Duration(seconds: _controller!.value.position.inSeconds + 15));
                              },
                            ),
                            IconButton(
                              icon: Icon(JwIcons.triangle_to_bar_left, color: Colors.white),
                              onPressed: () {
                                // Logique pour la vidéo précédente
                              },
                            ),
                            IconButton(
                              icon: Icon(JwIcons.triangle_to_bar_right, color: Colors.white),
                              onPressed: () {
                                // Logique pour la vidéo suivante
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _controller != null && _controller!.value.isInitialized
                                    ? _controller!.value.volume == 0.0 ? JwIcons.sound_x : JwIcons.sound : JwIcons.sound,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller!.value.volume == 0.0
                                      ? _controller!.setVolume(1.0)
                                      : _controller!.setVolume(0.0);
                                });
                              },
                            ),
                            PopupMenuButton(
                              icon: Icon(JwIcons.gear, color: Colors.white),
                              offset: Offset(100, -300),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.share),
                                      SizedBox(width: 10),
                                      Text('Partager'),
                                    ],
                                  ),
                                  onTap: () {
                                    Uri uri = Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.video.mepsLanguage}&lank=${widget.video.naturalKey}');
                                    SharePlus.instance.share(
                                        ShareParams(title: widget.video.title, uri: uri)
                                    );
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.list_plus),
                                      SizedBox(width: 10),
                                      Text('Ajouter à la liste de lecture'),
                                    ],
                                  ),
                                  onTap: () {
                                    // Action à effectuer pour l'option 2
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(JwIcons.caption),
                                          SizedBox(width: 10),
                                          Text('Sous-titres'),
                                        ],
                                      ),
                                      Icon(Icons.arrow_right),
                                    ],
                                  ),
                                  onTap: () {
                                    // Afficher le sous-menu
                                    showMenu(
                                      context: context,
                                      position: RelativeRect.fromLTRB(
                                        MediaQuery.of(context).size.width - 20, // Ajouter un espace de 20px depuis le bord droit
                                        MediaQuery.of(context).size.height - 270, // Au-dessus de la barre de lecture
                                        20, // Ajouter un espace de 20px depuis la gauche
                                        0, // Distance minimale depuis le bas
                                      ),
                                      items: [
                                        PopupMenuItem(
                                          child: Text('Français'),
                                          onTap: () async {
                                            Subtitles subtitles = Subtitles();
                                            if(widget.video.isDownloadedNotifier.value) {
                                              File file = File(widget.video.subtitlesFilePath);
                                              await subtitles.loadSubtitlesFromFile(file);
                                            }
                                            else {
                                              var jsonData = {};
                                              if (widget.onlineVideo != null) {
                                                jsonData = widget.onlineVideo;
                                              }
                                              else {
                                                String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.video.mepsLanguage}/${widget.video.naturalKey}';
                                                final response = await Api.httpGetWithHeaders(link);
                                                if (response.statusCode == 200) {
                                                  final jsonFile = response.body;
                                                  jsonData = json.decode(jsonFile)['media'][0];
                                                }
                                              }
                                              await subtitles.loadSubtitles(jsonData);
                                            }
                                            setState(() {
                                              _subtitles = subtitles.getSubtitles();
                                              _showSubtitle = true;
                                            });
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: Text('Inactif'),
                                          onTap: () {
                                            setState(() {
                                              _showSubtitle = false;
                                            });
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.speedometer),
                                      SizedBox(width: 10),
                                      Text('Vitesse de lecture'),
                                    ],
                                  ),
                                  onTap: () {
                                    // Action à effectuer pour l'option 4
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.video_encoding),
                                      SizedBox(width: 10),
                                      Text('Résolution'),
                                    ],
                                  ),
                                  onTap: () {
                                    // Action à effectuer pour l'option 5
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(JwIcons.arrows_loop),
                                      SizedBox(width: 10),
                                      Text('Répéter'),
                                    ],
                                  ),
                                  onTap: () {
                                    // Action à effectuer pour l'option 6
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_controlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      curve: Curves.easeInOut,
                      child: GlobalKeyService.jwLifePageKey.currentState!.getBottomNavigationBar(isBlack: true)
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
