import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour SystemChrome
import 'package:jwlife/core/utils/common_ui.dart'; // Pour showPage
// Audio utilities (non spécifié, donc omis)
import 'package:jwlife/core/utils/utils_video.dart'; // Video utilities (à adapter si nécessaire)
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';
import 'package:video_player/video_player.dart';
import 'package:jwlife/core/icons.dart';

import '../../../app/app_page.dart';
import '../../../app/services/global_key_service.dart';
import '../../../core/api/api.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/userdata/playlist_item.dart';
// Durée maximale entre deux taps pour détecter un double-tap.
const Duration _doubleTapTimeout = Duration(milliseconds: 300);

// --- PLAYLIST PLAYER ---
// --- PLAYLIST PLAYER ---
class PlaylistPlayerPage extends StatefulWidget {
  final List<PlaylistItem> items;
  final int startIndex;

  const PlaylistPlayerPage({
    super.key,
    required this.items,
    this.startIndex = 0,
  });

  @override
  State<PlaylistPlayerPage> createState() => _PlaylistPlayerPageState();
}

class _PlaylistPlayerPageState extends State<PlaylistPlayerPage> {
  // --- Propriétés d'état de la Playlist ---
  late int _currentIndex;

  // --- Propriétés d'état du Lecteur Avancé ---
  final ValueNotifier<bool> _controlsVisibleNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _positionNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _speedNotifier = ValueNotifier(1.0);
  final ValueNotifier<double?> _tempSpeedDisplayNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _seekDirectionNotifier = ValueNotifier(null);

  VideoPlayerController? _videoController;
  Timer? _imagePlaybackTimer;

  Duration _duration = Duration.zero;
  Timer? _controlsTimer;
  bool _isFullScreen = false;

  bool _isImageMedia = false;

  // --- Propriétés de gestion des gestes ---
  int _activePointers = 0;
  Timer? _timer;
  DateTime? _lastTapTime;
  Timer? _doubleTapTimer;
  bool _isDragging = false;
  bool _justDidTwoFingerAction = false;
  double _lastDragPosition = 0.0;
  bool _hasSpeedBeenAdjusted = false;
  bool _isPositionSeeking = false;

  // --- Propriétés du Média actuel ---
  Media? _currentMedia;
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex.clamp(0, widget.items.length - 1);
    _loadAndPlayItem(widget.items[_currentIndex]);
    _startControlsTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _imagePlaybackTimer?.cancel();
    _controlsVisibleNotifier.dispose();
    _isPlayingNotifier.dispose();
    _positionNotifier.dispose();
    _speedNotifier.dispose();
    _tempSpeedDisplayNotifier.dispose();
    _seekDirectionNotifier.dispose();
    _controlsTimer?.cancel();
    _doubleTapTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _imageListener(Timer timer) {
    if (_isPositionSeeking) return;

    final currentPosition = _positionNotifier.value;
    const double step = 0.1;
    final newPosition = currentPosition + step;

    if (newPosition >= _duration.inSeconds.toDouble()) {
      _positionNotifier.value = _duration.inSeconds.toDouble();
      timer.cancel();
      _handleEndAction();
    } else {
      _positionNotifier.value = newPosition;
    }
  }

  Future<String?> getVideoApi(Media media) async {
    String? lank = media.naturalKey;
    String? lang = media.mepsLanguage;

    if (lank != null && lang != null) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank?clientType=www';
      printTime('apiUrl: $apiUrl'); // Votre log d'origine
      try {
        final response = await Api.httpGetWithHeaders(apiUrl, responseType: ResponseType.json);
        if (response.statusCode == 200) {
          return await fetchMedia(response.data['media'][0]);
        } else {
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
    return null;
  }

  Future<String?> fetchMedia(dynamic media, {String? desiredResolution}) async {
    // Vérification basique de la validité des données
    if (media == null || media['files'] == null) {
      printTime('❌ Données média invalides');
      return null;
    }

    final List<dynamic> files = media['files'];
    if (files.isEmpty) {
      printTime('❌ Aucun fichier média disponible');
      return null;
    }

    // Détermination de la résolution cible
    final String resolutionToPlay = desiredResolution ?? '720p';
    final bool autoSelect = desiredResolution == null || desiredResolution == 'Auto';

    // Fonction utilitaire pour filtrer les fichiers valides
    bool isValidVideo(Map<String, dynamic> file) =>
        file['mimetype'] == 'video/mp4' &&
            file.containsKey('progressiveDownloadURL');

    // Sélection du fichier
    Map<String, dynamic>? selectedFile;

    if (autoSelect) {
      // Mode automatique : on essaie d'abord la 720p, sinon le premier fichier mp4 dispo
      selectedFile = files.cast<Map<String, dynamic>?>().firstWhere(
            (file) => isValidVideo(file!) && file['label'] == resolutionToPlay,
        orElse: () => files.cast<Map<String, dynamic>?>().firstWhere(
              (file) => isValidVideo(file!),
          orElse: () => null,
        ),
      );
      // _currentResolution = 'Auto';
    } else {
      // Mode manuel : on cherche d'abord la résolution demandée
      selectedFile = files.cast<Map<String, dynamic>?>().firstWhere(
            (file) => isValidVideo(file!) && file['label'] == resolutionToPlay,
        orElse: () => files.cast<Map<String, dynamic>?>().firstWhere(
              (file) => isValidVideo(file!),
          orElse: () => null,
        ),
      );
      // _currentResolution = desiredResolution;
    }

    // Vérification du fichier sélectionné
    if (selectedFile == null || selectedFile['progressiveDownloadURL'] == null) {
      printTime('❌ Aucun fichier vidéo valide trouvé');
      return null;
    }

    final String videoUrl = selectedFile['progressiveDownloadURL'];
    printTime('✅ Fichier sélectionné : ${selectedFile['label'] ?? 'inconnu'}');

    return videoUrl;
  }


  void _loadAndPlayItem(PlaylistItem item) async {
    // 1. Nettoyer l'état précédent
    _videoController?.dispose();
    _videoController = null;
    _imagePlaybackTimer?.cancel();
    _currentMedia = null;
    _isImageMedia = false;

    _isPlayingNotifier.value = false;
    _positionNotifier.value = 0.0;
    _duration = Duration.zero;
    _currentTitle = item.label ?? 'Média';

    setState(() {}); // Affichage immédiat des contrôles

    // 2. Déterminer et charger le nouveau Média
    final location = item.location;
    final independentMedia = item.independentMedia;

    Media? media;
    String? filePath;
    String? fileUrl;
    bool isVideo = false; // Rétabli pour la logique de l'audio/vidéo

    if (location != null && !location.isNull()) {
      final mediaItem = getMediaItem(
        location.keySymbol,
        location.track,
        location.mepsDocumentId,
        location.issueTagNumber,
        location.mepsLanguageId,
        isVideo: location.type != 2,
      );

      if (mediaItem != null) {
        final mediaRepo = MediaRepository();
        final existingMedia = mediaRepo.getByCompositeKey(mediaItem);

        if (mediaItem.type == 'AUDIO') {
          media = existingMedia ?? Audio.fromJson(mediaItem: mediaItem);
          filePath = (media as Audio).filePath;
          isVideo = false;
        }
        else {
          media = existingMedia ?? Video.fromJson(mediaItem: mediaItem);
          filePath = (media as Video).filePath;
          isVideo = true;
        }

        if(filePath == null) {
          // Si le fichier local n'est pas trouvé, tenter l'API pour l'URL
          fileUrl = await getVideoApi(media); // media ne sera pas null ici
        }
      }
    }
    else if (independentMedia != null && !independentMedia.isNull()) {
      final file = await independentMedia.getMediaFile();
      filePath = file.path;

      if (independentMedia.mimeType?.contains('video') == true) {
        isVideo = true;
      } else if (independentMedia.mimeType?.contains('audio') == true) {
        isVideo = false;
      } else if (independentMedia.mimeType?.contains('image') == true) {
        _isImageMedia = true;
      }
    }

    _currentMedia = media;
    _currentTitle = item.label ?? media?.title ?? 'Média';

    // 3. Initialiser le contrôleur/Timer
    if (_isImageMedia) {
      if (item.durationTicks != null && item.durationTicks! > 0) {
        _duration = Duration(milliseconds: item.durationTicks! ~/ 10000);
        _isPlayingNotifier.value = true;
        _imagePlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), _imageListener);
      }
    }
    else if (filePath != null) {
      _videoController = VideoPlayerController.file(File(filePath));
      try {
        await _videoController!.initialize();
        _duration = _videoController!.value.duration;
        _videoController!.addListener(_videoListener);
        _videoController!.play();
        _isPlayingNotifier.value = true;
      }
      catch (e) {
        print('Erreur lors de l\'initialisation du contrôleur (Local): $e');
        _videoController = null;
      }
    }
    else if (fileUrl != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fileUrl));
      try {
        await _videoController!.initialize();
        _duration = _videoController!.value.duration;
        _videoController!.addListener(_videoListener);
        _videoController!.play();
        _isPlayingNotifier.value = true;
      }
      catch (e) {
        print('Erreur lors de l\'initialisation du contrôleur (Network): $e');
        _videoController = null;
      }
    }

    setState(() {});
  }

  void _videoListener() {
    if (!_isPositionSeeking && _videoController != null && _videoController!.value.isInitialized) {
      _positionNotifier.value = _videoController!.value.position.inSeconds.toDouble();

      if (_videoController!.value.position >= _videoController!.value.duration) {
        _handleEndAction();
      }
    }
    _isPlayingNotifier.value = _videoController?.value.isPlaying ?? false;
  }

  void _handleEndAction() {
    if (_isImageMedia) {
      _imagePlaybackTimer?.cancel();
    }

    final isLastItem = _currentIndex == widget.items.length - 1;
    final endAction = widget.items[_currentIndex].endAction ?? 0;

    if (endAction == 0) { // Continuer
      if (isLastItem) {
        _videoController?.pause();
        _isPlayingNotifier.value = false;
        GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
      } else {
        _nextItem();
      }
    }
    else if (endAction == 1) { // Arrêter
      _videoController?.pause();
      _videoController?.seekTo(Duration.zero);
      _isPlayingNotifier.value = false;
      GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
    }
    else if (endAction == 2) { // Pause
      _videoController?.pause();
      _isPlayingNotifier.value = false;
    }
    else if (endAction == 3) { // Répéter
      if (_isImageMedia) {
        _positionNotifier.value = 0.0;
        _isPlayingNotifier.value = true;
        _imagePlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), _imageListener);
      } else {
        _videoController?.seekTo(Duration.zero);
        _videoController?.play();
      }
    }
  }

  void _nextItem() {
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
        _loadAndPlayItem(widget.items[_currentIndex]);
      });
    }
  }

  void _previousItem() {
    // Revenir au début de la piste actuelle si déjà en cours de lecture
    if (_positionNotifier.value > 1.0) {
      if (_isImageMedia) {
        _positionNotifier.value = 0.0;
        if (_isPlayingNotifier.value) {
          _imagePlaybackTimer?.cancel();
          _imagePlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), _imageListener);
        }
      } else if (_videoController != null) {
        _videoController!.seekTo(Duration.zero);
      }
    }
    // Sinon, passer à la piste précédente
    else if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _loadAndPlayItem(widget.items[_currentIndex]);
      });
    }
  }

  void _togglePlayPause() {
    if (_isImageMedia) {
      if (_isPlayingNotifier.value) {
        _imagePlaybackTimer?.cancel();
        _isPlayingNotifier.value = false;
      } else {
        _imagePlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), _imageListener);
        _isPlayingNotifier.value = true;
      }
    }
    else if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
    }
    _startControlsTimer();
  }

  void _seek(double seconds) {
    if (_isImageMedia) {
      final newPosition = (_positionNotifier.value + seconds).clamp(0.0, _duration.inSeconds.toDouble());
      _positionNotifier.value = newPosition;
      if (newPosition == _duration.inSeconds.toDouble()) {
        _imagePlaybackTimer?.cancel();
        _handleEndAction();
      }
    }
    else if (_videoController != null) {
      final newPosition = _videoController!.value.position + Duration(seconds: seconds.toInt());
      _videoController!.seekTo(newPosition);
    }
    _showSeekOverlay(seconds > 0 ? 1 : -1);
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (_controlsVisibleNotifier.value) {
        _controlsVisibleNotifier.value = false;
        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
      }
    });
  }

  void setSpeed(double newSpeed) {
    if (_isImageMedia || _videoController == null) return;

    final clampedSpeed = newSpeed.clamp(0.5, 2.0);
    _speedNotifier.value = clampedSpeed;
    _videoController?.setPlaybackSpeed(clampedSpeed);

    _tempSpeedDisplayNotifier.value = clampedSpeed;
    Timer(const Duration(milliseconds: 1000), () {
      if (_tempSpeedDisplayNotifier.value == clampedSpeed) {
        _tempSpeedDisplayNotifier.value = null;
      }
    });
    _startControlsTimer();
  }

  void _showSeekOverlay(int direction) {
    _seekDirectionNotifier.value = direction;
    Timer(const Duration(milliseconds: 500), () {
      if (_seekDirectionNotifier.value == direction) {
        _seekDirectionNotifier.value = null;
      }
    });
  }

  Widget _buildMediaViewer(PlaylistItem playlistItem) {
    final independentMedia = playlistItem.independentMedia;

    // 1. Cas Média Image (restauré)
    if (independentMedia != null && independentMedia.mimeType?.contains('image') == true) {
      return FutureBuilder<File>(
        future: independentMedia.getMediaFile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return Center(
              child: Image.file(
                snapshot.data!,
                fit: BoxFit.contain,
                height: double.infinity,
                width: double.infinity,
              ),
            );
          }
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
      );
    }

    // 2. Cas Média Audio/Vidéo
    if (_videoController != null && _videoController!.value.isInitialized) {
      final isAudio = playlistItem.location?.type == 2 || independentMedia?.mimeType?.contains('audio') == true;

      if (isAudio) {
        // Affichage de la pochette pour l'audio (restauré)
        return FutureBuilder<File?>(
          future: playlistItem.getThumbnailFile(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Center(child: Image.file(snapshot.data!, fit: BoxFit.contain));
            }
            return const Center(child: Icon(Icons.music_note, color: Colors.white, size: 100));
          },
        );
      }

      // Pour la Vidéo (restauré)
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    }

    // Cas par défaut (chargement en cours ou non supporté)
    return Center(
      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildCenterPlayPauseOverlay() {
    final isTimeBasedMedia = _videoController != null || (_isImageMedia && _duration > Duration.zero);
    if (!isTimeBasedMedia) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _controlsVisibleNotifier,
      builder: (context, controlsVisible, child) {
        return Positioned.fill(
          child: Center(
            child: AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: ValueListenableBuilder<bool>(
                valueListenable: _isPlayingNotifier,
                builder: (context, isPlaying, innerChild) {
                  final displayIcon = isPlaying ? JwIcons.pause : JwIcons.play;

                  return GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: IconButton(
                        iconSize: 75.0,
                        padding: const EdgeInsets.all(2),
                        icon: Icon(displayIcon, color: Colors.white),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedOverlay(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: _tempSpeedDisplayNotifier,
      builder: (context, tempSpeed, child) {
        if (tempSpeed == null) return const SizedBox.shrink();

        return Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Vitesse de lecture : ${tempSpeed.toStringAsFixed(1).replaceAll('.', ',')}x',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeekOverlay(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: _seekDirectionNotifier,
      builder: (context, direction, child) {
        if (direction == null) return const SizedBox.shrink();

        final isForward = direction == 1;
        final icon = isForward ? JwIcons.arrow_circular_right_15 : JwIcons.arrow_circular_left_5;
        final alignment = isForward ? Alignment.centerRight : Alignment.centerLeft;

        return Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 50.0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, {required bool controlsVisible}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: controlsVisible ? 1.0 : 0.0,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 2,
        title: Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, PlaylistItem item, {required bool controlsVisible, required bool isTimeBasedMedia}) {
    final isReady = (_videoController?.value.isInitialized ?? false) || _isImageMedia;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: controlsVisible ? 1.0 : 0.0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.only(bottom: 65),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Slider
              if (isTimeBasedMedia)
                ValueListenableBuilder<double>(
                  valueListenable: _positionNotifier,
                  builder: (context, position, child) {
                    return SliderTheme(
                      data: const SliderThemeData(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        trackHeight: 2.0,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        value: position.clamp(0.0, _duration.inSeconds.toDouble()),
                        min: 0.0,
                        max: _duration.inSeconds.toDouble(),
                        onChanged: isReady ? (double newValue) {
                          _positionNotifier.value = newValue;
                        } : null,
                        onChangeStart: isReady ? (double newValue) {
                          _isPositionSeeking = true;
                        } : null,
                        onChangeEnd: isReady ? (double newValue) {
                          if (_isImageMedia) {
                            _positionNotifier.value = newValue;
                            _isPositionSeeking = false;
                            _startControlsTimer();

                            if (_isPlayingNotifier.value) {
                              _imagePlaybackTimer?.cancel();
                              _imagePlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), _imageListener);
                            }
                          } else {
                            _videoController?.seekTo(Duration(seconds: newValue.toInt()));
                            _isPositionSeeking = false;
                            _startControlsTimer();
                          }
                        } : null,
                        activeColor: Theme.of(context).primaryColor,
                        inactiveColor: Colors.white.withOpacity(0.5),
                      ),
                    );
                  },
                ),

              Row(
                children: [
                  // Play/Pause et Affichage du temps
                  if (isTimeBasedMedia)
                    ...[
                      ValueListenableBuilder<bool>(
                        valueListenable: _isPlayingNotifier,
                        builder: (context, isPlaying, child) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isPlaying ? JwIcons.pause : JwIcons.play,
                              color: isReady ? Colors.white : Colors.grey[600],
                            ),
                            onPressed: isReady ? _togglePlayPause : null,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(JwIcons.triangle_to_bar_left, color: Colors.white),
                        disabledColor: Colors.grey[800],
                        onPressed: _currentIndex == 0 ? null : _previousItem,
                      ),
                      IconButton(
                        icon: const Icon(JwIcons.triangle_to_bar_right, color: Colors.white),
                        disabledColor: Colors.grey[800],
                        onPressed: _currentIndex == widget.items.length - 1 ? null : _nextItem,
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: _positionNotifier,
                        builder: (context, position, child) {
                          return Text(
                            "${formatDuration(position)} / ${formatDuration(_duration.inSeconds.toDouble())}",
                            style: TextStyle(color: isReady ? Colors.white : Colors.grey[600]),
                          );
                        },
                      ),
                    ]
                  else
                  // Pour les images SANS durée
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(item.label ?? 'Image', style: const TextStyle(color: Colors.white)),
                    ),

                  const Spacer(),

                  // Les autres boutons
                  IconButton(
                    icon: Icon(JwIcons.caption_crossed, color: isReady ? Colors.white : Colors.grey[600]),
                    onPressed: isReady ? () {} : null,
                  ),
                  IconButton(
                    icon: Icon(JwIcons.sound, color: isReady ? Colors.white : Colors.grey[600]),
                    onPressed: isReady ? () {} : null,
                  ),
                  IconButton(
                    icon: Icon(_isFullScreen ? JwIcons.arrows_inward : JwIcons.arrows_outward, color: Colors.white),
                    onPressed: () {
                      GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const AppPage(
        backgroundColor: Colors.black,
        body: Center(child: Text('La playlist est vide.', style: TextStyle(color: Colors.white))),
      );
    }

    final currentItem = widget.items[_currentIndex];
    final isTimeBasedMedia = _videoController != null || (_isImageMedia && _duration > Duration.zero);

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (PointerDownEvent event) {
        _activePointers++;
        _timer?.cancel();
        _justDidTwoFingerAction = false;
        _lastDragPosition = event.position.dy;
        _hasSpeedBeenAdjusted = false;
        _isDragging = false;

        if (_activePointers == 2) {
          _isDragging = false;
          _justDidTwoFingerAction = true;
          _controlsVisibleNotifier.value = true;
          GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(true);
          _togglePlayPause();
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_videoController != null && _activePointers == 1) {
          final deltaY = event.position.dy - _lastDragPosition;
          const double threshold = 30.0;
          if (deltaY.abs() > 5.0) _isDragging = true;
          if (_hasSpeedBeenAdjusted) return;

          if (deltaY.abs() >= threshold) {
            double newSpeed = _speedNotifier.value;
            if (deltaY < -threshold) {
              newSpeed += 0.1;
            } else if (deltaY > threshold) {
              newSpeed -= 0.1;
            }
            setSpeed(newSpeed);
            _lastDragPosition = event.position.dy;
            _hasSpeedBeenAdjusted = true;
          }
        }
      },
      onPointerUp: (PointerUpEvent event) {
        _activePointers--;

        if (_activePointers == 0) {
          if (_justDidTwoFingerAction) {
            _justDidTwoFingerAction = false;
            _startControlsTimer();
            return;
          }

          if (!_isDragging) {
            final now = DateTime.now();

            final double totalTopZone = kToolbarHeight + MediaQuery.of(context).padding.top;
            const double bottomControlsHeight = 130.0;
            final double totalBottomZoneStart = MediaQuery.of(context).size.height - bottomControlsHeight;
            final bool isTapInControlZone = event.position.dy < totalTopZone || event.position.dy > totalBottomZoneStart;

            if (_lastTapTime != null && now.difference(_lastTapTime!) < _doubleTapTimeout && !isTapInControlZone) {
              _doubleTapTimer?.cancel();
              final widgetWidth = MediaQuery.of(context).size.width;

              if (isTimeBasedMedia) {
                _seek(event.position.dx > widgetWidth / 2 ? 15.0 : -5.0);
              }
              _lastTapTime = null;
              _startControlsTimer();
              return;
            }

            _doubleTapTimer?.cancel();
            _doubleTapTimer = Timer(_doubleTapTimeout, () {
              _lastTapTime = null;
              _doubleTapTimer = null;

              if (_controlsVisibleNotifier.value && isTapInControlZone) {
                _startControlsTimer();
                return;
              }

              final newVisibility = !_controlsVisibleNotifier.value;
              _controlsVisibleNotifier.value = newVisibility;
              GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(newVisibility);

              if (newVisibility) {
                _startControlsTimer();
              } else {
                _timer?.cancel();
              }
            });

            _lastTapTime = now;
            return;
          }

          if (_isDragging) {
            _isDragging = false;
            return;
          }

          _startControlsTimer();
        }

        if (_isDragging) _isDragging = false;
        _startControlsTimer();
      },

      onPointerCancel: (PointerCancelEvent event) {
        _activePointers = 0;
        _isDragging = false;
      },
      child: AppPage(
        backgroundColor: const Color(0xFF121212),
        body: Stack(
          children: [
            // 1. Contenu Média
            Positioned.fill(
              child: Center(child: _buildMediaViewer(currentItem)),
            ),

            // 2. Overlay play/pause central (Optimisé)
            _buildCenterPlayPauseOverlay(),

            // 3. Overlays d'affichage temporaires
            _buildSpeedOverlay(context),
            _buildSeekOverlay(context),

            // 4. Barres de Contrôles
            ValueListenableBuilder<bool>(
              valueListenable: _controlsVisibleNotifier,
              builder: (context, controlsVisible, child) => _buildAppBar(context, controlsVisible: controlsVisible),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _controlsVisibleNotifier,
              builder: (context, controlsVisible, child) => _buildBottomControls(context, currentItem, controlsVisible: controlsVisible, isTimeBasedMedia: isTimeBasedMedia),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Exemple d'utilisation (Fonction utilitaire pour ouvrir le lecteur) ---

/// Fonction utilitaire pour lancer le lecteur de playlist en mode plein écran.
void showPlaylistPlayer(
    List<PlaylistItem> playlist, {
      int startIndex = 0,
      bool randomMode = false,
    }) {
  if (playlist.isEmpty) {
    print('⚠️ Playlist vide — lecture annulée');
    return;
  }

  final List<PlaylistItem> effectivePlaylist = List.from(playlist);

  // Mélange la playlist si le mode aléatoire est activé
  if (randomMode) {
    effectivePlaylist.shuffle();
    print('🔀 Lecture en mode aléatoire (${effectivePlaylist.length} éléments)');
  }

  showPage(
    PlaylistPlayerPage(
      items: effectivePlaylist,
      startIndex: startIndex,
    ),
  );
}