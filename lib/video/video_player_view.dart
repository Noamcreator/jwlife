import 'dart:convert';
import 'dart:async'; // Importer pour utiliser Timer
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/Video.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import 'subtitles.dart';

class VideoPlayerView extends StatefulWidget {
  final MediaItem mediaItem;
  final dynamic onlineVideo;
  final Video? localVideo;
  final Duration startPosition;

  const VideoPlayerView({super.key, required this.mediaItem, this.onlineVideo, this.localVideo, this.startPosition=Duration.zero});

  @override
  _VideoPlayerViewState createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _controller;
  String _title = '';  // Valeur par défaut pour le titre
  Duration _duration = Duration.zero;  // Valeur par défaut pour la durée

  List<Subtitle> _subtitles = [];
  bool _isPositionSeeking = false;
  double _positionSlider = 0.0;
  Timer? _timer; // Variable pour le Timer
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _showSubtitle = false;
  final bool _audioWidgetVisible = JwLifeView.isAudioWidgetVisible; // Variable pour contrôler la visibilité de l'audio widget

  @override
  void initState() {
    super.initState();
    // Met le mode plein écran en masquant les barres système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    setState(() {
      _title = widget.mediaItem.title ?? '';
      _duration = Duration(seconds: widget.mediaItem.duration!.toInt());
    });

    // Met le mode plein écran en masquant le player audio
    toggleAudioWidgetVisibility();

    History.insertVideo(widget.mediaItem);

    if(widget.localVideo != null) {
      playLocalVideo();
    }
    else if (widget.onlineVideo != null) {
      fetchMedia(widget.onlineVideo);
    }
    else {
      getVideoApi();
    }
  }

  Future<void> toggleAudioWidgetVisibility() async {
    if(JwLifeView.isAudioWidgetVisible) {
      JwLifeView.toggleAudioWidgetVisibility(false);
    }
  }

  // Method to play the video
  Future<void> getVideoApi() async {
    String lank = widget.mediaItem.languageAgnosticNaturalKey!;
    String lang = widget.mediaItem.languageSymbol!;
    if (lank.isNotEmpty && lang.isNotEmpty) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank?clientType=www';
      print('apiUrl: $apiUrl');
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          fetchMedia(data['media'][0]);
        }
        else {
          print('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        print('An exception occurred: $e');
      }
    } else {
      print('Lank or lang parameters are missing in the URL.');
    }
  }

  Future<void> fetchMedia(final media) async {
    final videoUrl = media['files'][2]['progressiveDownloadURL']; // Adapt according to response structure
    final title = media['title']; // Adapt according to response structure
    final duration = Duration(seconds: (media['duration'] as num).toInt()); // Adapt according to response structure

    await playOnlineVideo(title, duration, videoUrl);
  }

  Future<void> fetchPubMedia(final media) async {
    final videoUrl = media['files']['F']['MP4'][2]['file']['url'];
    final title = media['files']['F']['MP4'][2]['title'];
    final duration = Duration(seconds: (media['files']['F']['MP4'][2]['duration'] as num).toInt()); // Adapt according to response structure

    await playOnlineVideo(title, duration, videoUrl);
  }

  // Method to play the video
  Future<void> playOnlineVideo(String title, Duration duration, String videoUrl) async {
    _controller = VideoPlayerController.network(videoUrl)
      ..initialize().then((_) {
        setState(() {
          _controller!.play();
          _controller!.seekTo(widget.startPosition);
          // Démarrez le Timer lorsque le contrôleur est prêt
          _timer = Timer.periodic(Duration(milliseconds: 100), (Timer timer) {
            if (_controller!.value.isInitialized && mounted) {
              setState(() {
                if(!_isPositionSeeking) {
                  _positionSlider = _controller!.value.position.inSeconds.toDouble();
                }
              });
            }
            if(_controller!.value.position >= _controller!.value.duration) {
              JwLifeView.toggleNavBarVisibility.call(true);
              JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, false);
              Navigator.pop(context);
            }
          });
          Timer(Duration(seconds: 2), () {
            if(JwLifeView.persistentBarIsBlack[JwLifeView.currentTabIndex] == true) {
              setState(() {
                _controlsVisible = !_controlsVisible; // Toggle visibility
                JwLifeView.toggleNavBarVisibility.call(_controlsVisible); // Appeler la fonction pour modifier la visibilité de la barre de navigation
              });
            }
          });
        });
      });
  }

  // Method to play the video
  Future<void> playLocalVideo() async {
    File file = File(widget.localVideo!.filePath);

    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        setState(() {
          _controller!.play();
          _controller!.seekTo(widget.startPosition);
          // Démarrez le Timer lorsque le contrôleur est prêt
          _timer = Timer.periodic(Duration(milliseconds: 100), (Timer timer) {
            if (_controller!.value.isInitialized && mounted) {
              setState(() {
                if(!_isPositionSeeking) {
                  _positionSlider = _controller!.value.position.inSeconds.toDouble();
                }
              });
            }
            if(_controller!.value.position >= _controller!.value.duration) {
              JwLifeView.toggleNavBarVisibility.call(true);
              JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, false);
              Navigator.pop(context);
            }
          });
          Timer(Duration(seconds: 2), () {
            if(JwLifeView.persistentBarIsBlack[JwLifeView.currentTabIndex] == true) {
              setState(() {
                _controlsVisible = !_controlsVisible; // Toggle visibility
                JwLifeView.toggleNavBarVisibility.call(_controlsVisible); // Appeler la fonction pour modifier la visibilité de la barre de navigation
              });
            }
          });
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
        _controlsVisible = !_controlsVisible;
        JwLifeView.toggleNavBarVisibility.call(_controlsVisible);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Vidéo centrée, derrière l'AppBar
            Positioned.fill(
              child: Center(
                child: Stack(
                  children: [
                    _controller != null && _controller!.value.isInitialized
                        ? AspectRatio(
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
                  title: Text(_title.isEmpty ? 'Video' : _title, style: TextStyle(color: Colors.white)),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      // Restaure l'affichage des barres système
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

                      JwLifeView.toggleNavBarVisibility.call(true);
                      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, false);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),

            // Contrôles positionnés en bas
            if (_controlsVisible)
              Positioned(
                bottom: 55,
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
                              _controller!.play();
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
                                    Share.share(
                                        'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.mediaItem.languageSymbol}&lank=${widget.mediaItem.languageAgnosticNaturalKey}'
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
                                            if(widget.localVideo != null) {
                                              File file = File(widget.localVideo!.subtitlesFilePath);
                                              await subtitles.loadSubtitlesFromFile(file);
                                            }
                                            else {
                                              var jsonData = {};
                                              if (widget.onlineVideo != null) {
                                                jsonData = widget.onlineVideo;
                                              }
                                              else {
                                                String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.mediaItem.languageSymbol}/${widget.mediaItem.languageAgnosticNaturalKey}';
                                                final response = await http.get(Uri.parse(link));
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Restaure l'affichage des barres système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _controller?.dispose();
    _timer?.cancel(); // Annulez le Timer
    JwLifeView.toggleNavBarVisibility.call(true);
    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, false);
    if(_audioWidgetVisible) {
      JwLifeView.toggleAudioWidgetVisibility(true);
    }
    super.dispose();
  }
}
