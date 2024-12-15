import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../jwlife.dart';

import '../utils/icons.dart';
import '../utils/utils.dart';
import '../widgets/image_widget.dart';
import 'JwAudioPlayer.dart';

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
  ImageCachedWidget? _currentImageWidget;
  String _currentSubtitles = "";
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

    jwAudioPlayer.player.currentIndexStream.listen((index) {
        if (index != null && jwAudioPlayer.playlist.children.isNotEmpty) {
          var tag = (jwAudioPlayer.playlist.children[index] as UriAudioSource).tag as MediaItem;
          setState(() {
            _currentTitle = tag.title;
            _currentImageWidget = ImageCachedWidget(
              imageUrl: tag.artUri.toString(),
              pathNoImage: 'pub_type_audio',
              width: 60,
              height: 60,
            );
            _currentSubtitles = tag.displaySubtitle ?? "";
          });
        }
      });

    jwAudioPlayer.player.durationStream.listen((duration) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });

        var tag = (jwAudioPlayer.playlist.children[jwAudioPlayer.currentId] as UriAudioSource).tag as MediaItem;
        setState(() {
          _currentTitle = tag.title;
          _currentImageWidget = ImageCachedWidget(
            imageUrl: tag.artUri.toString(),
            pathNoImage: 'pub_type_audio',
            width: 60,
            height: 60,
          );
          _currentSubtitles = tag.displaySubtitle ?? "";
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
    return widget.visible && _currentTitle.isNotEmpty ? GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SubtitleView(
                    titre: _currentTitle, subtitleKey: _currentSubtitles),
          ),
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
                              jwAudioPlayer.previous();
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
                            icon: const Icon(JwIcons.triangle_to_bar_right),
                            onPressed: () {
                              jwAudioPlayer.next();
                            },
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
                            onPressed: () {
                              jwAudioPlayer.close();
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
            child: _currentImageWidget ?? Container()
          ),
        ],
      ),
    ) : Container();
  }
}


class SubtitleView extends StatefulWidget {
  final String titre;
  final String subtitleKey;

  const SubtitleView({Key? key, required this.titre, required this.subtitleKey}) : super(key: key);

  @override
  _SubtitleViewState createState() => _SubtitleViewState();
}

class _SubtitleViewState extends State<SubtitleView> {
  String? _subtitles;
  String? _pdfPath;

  @override
  void initState() {
    super.initState();
    _loadSubtitles();
    //_loadPDF();
  }

  Future<void> _loadSubtitles() async {
    try {
      final response = await http.get(Uri.parse(widget.subtitleKey));
      if (response.statusCode == 200) {
        var document = html.parse(utf8.decode(response.bodyBytes));
        setState(() {
          _subtitles = document.body?.text ?? "Aucun sous-titre disponible";
        });
      }
    } catch (e) {
      setState(() {
        _subtitles = "Erreur lors du chargement des sous-titres.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_subtitles != null) Text(_subtitles!) else const CircularProgressIndicator(),
            const SizedBox(height: 20),
            if (_pdfPath != null)
              SizedBox(
                height: 400,
                child: PDFView(
                  filePath: _pdfPath!,
                ),
              )
            else
              const Text('Partition PDF non disponible.'),
          ],
        ),
      ),
    );
  }
}
