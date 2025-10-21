import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
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
  String _title = '';
  Duration _duration = Duration.zero;

  List<Subtitle> _subtitles = [];
  bool _showSubtitle = false;

  // Gestion de la résolution
  dynamic _onlineMediaData;
  String _currentResolution = 'Auto';
  List<String> _availableResolutions = [];

  // ValueNotifiers pour les mises à jour optimisées
  final ValueNotifier<bool> _controlsVisibleNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _volumeNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> _positionNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _speedNotifier = ValueNotifier(1.0);
  final ValueNotifier<int?> _seekDirectionNotifier = ValueNotifier(null);
  final ValueNotifier<double?> _tempSpeedDisplayNotifier = ValueNotifier(null);

  bool _isPositionSeeking = false;
  Timer? _timer;
  Timer? _timerSpeedDisplay;
  Timer? _timerSeekDisplay;

  bool _isClosingVideo = false;
  double _lastDragPosition = 0.0;
  bool _hasSpeedBeenAdjusted = false;

  int _activePointers = 0;
  bool _isDragging = false;
  bool _justDidTwoFingerAction = false;

  // Variables pour sauvegarder l'état lors du changement de résolution
  Duration? _lastPosition;
  bool _wasPlaying = false;

  Timer? _doubleTapTimer;
  DateTime? _lastTapTime;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 200); // Temps max entre deux clics

  bool _isFullScreen = false;

  int _currentLoopMode = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.video.title;
    _duration = Duration(seconds: widget.video.duration.toInt());

    BuildContext context = GlobalKeyService.jwLifePageKey.currentContext!;
    _isFullScreen = MediaQuery.of(context).orientation == Orientation.landscape;
    GlobalKeyService.jwLifePageKey.currentState!.orientation = MediaQuery.of(context).orientation;

    History.insertVideo(widget.video);

    if(widget.video.isDownloadedNotifier.value) {
      playLocalVideo();
    }
    else if (widget.onlineVideo != null) {
      _onlineMediaData = widget.onlineVideo;
      _updateAvailableResolutions(_onlineMediaData);
      fetchMedia(_onlineMediaData);
    }
    else {
      getVideoApi();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _timer?.cancel();
    _timerSpeedDisplay?.cancel();
    _timerSeekDisplay?.cancel();

    _controlsVisibleNotifier.dispose();
    _isInitializedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _volumeNotifier.dispose();
    _positionNotifier.dispose();
    _speedNotifier.dispose();
    _seekDirectionNotifier.dispose();
    _tempSpeedDisplayNotifier.dispose();

    super.dispose();
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;

    if (_isInitializedNotifier.value != value.isInitialized) {
      _isInitializedNotifier.value = value.isInitialized;
    }

    if (_isPlayingNotifier.value != value.isPlaying) {
      _isPlayingNotifier.value = value.isPlaying;
    }

    if (_volumeNotifier.value != value.volume) {
      _volumeNotifier.value = value.volume;
    }

    if (_speedNotifier.value != value.playbackSpeed) {
      _speedNotifier.value = value.playbackSpeed;
    }

    if (!_isPositionSeeking) {
      final newPosition = value.position.inSeconds.toDouble();
      if ((_positionNotifier.value - newPosition).abs() > 0.5) {
        _positionNotifier.value = newPosition;
      }
    }

    if (value.position >= value.duration && value.duration.inSeconds > 0 && !_isClosingVideo) {
      _isClosingVideo = true;

      GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
    }
  }

  void _startControlsTimer() {
    _timer?.cancel();

    int currentNavBarIndex = GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex;

    if (_controller != null && _controller!.value.isPlaying) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          if(currentNavBarIndex == GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex) {
            _controlsVisibleNotifier.value = false;
            GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
          }
        }
        _timer?.cancel();
      });
    }
  }

  // ============== GESTION DES RÉSOLUTIONS ==============

  void _updateAvailableResolutions(dynamic media) {
    if (media == null || media['files'] == null) return;

    final files = media['files'] as List<dynamic>;
    _availableResolutions = files
        .where((file) =>
    file['mimetype'] == 'video/mp4' &&
        file.containsKey('label') &&
        file.containsKey('progressiveDownloadURL'))
        .map<String>((file) => file['label'] as String)
        .toSet()
        .toList();

    _availableResolutions.sort((a, b) {
      final aInt = int.tryParse(a.replaceAll('p', '')) ?? 0;
      final bInt = int.tryParse(b.replaceAll('p', '')) ?? 0;
      return bInt.compareTo(aInt);
    });
  }

  String _getBestAvailableResolution() {
    if (_availableResolutions.isEmpty) return '360p';
    return _availableResolutions.first;
  }

  Future<void> fetchMedia(dynamic media, {String? desiredResolution}) async {
    if (media == null || media['files'] == null) {
      printTime('Données média invalides');
      return;
    }

    final files = media['files'] as List<dynamic>;

    String resolutionToPlay = desiredResolution ?? _getBestAvailableResolution();

    dynamic selectedFile;

    if (desiredResolution == null || desiredResolution == 'Auto') {
      selectedFile = files.firstWhere(
            (file) =>
        file['mimetype'] == 'video/mp4' &&
            file.containsKey('progressiveDownloadURL') &&
            file['label'] == resolutionToPlay,
        orElse: () => files.firstWhere(
              (file) => file['mimetype'] == 'video/mp4' && file.containsKey('progressiveDownloadURL'),
          orElse: () => null,
        ),
      );
      setState(() {
        _currentResolution = 'Auto';
      });
    } else {
      selectedFile = files.firstWhere(
            (file) =>
        file['label'] == resolutionToPlay &&
            file['mimetype'] == 'video/mp4' &&
            file.containsKey('progressiveDownloadURL'),
        orElse: () => files.firstWhere(
              (file) => file['mimetype'] == 'video/mp4' && file.containsKey('progressiveDownloadURL'),
          orElse: () => null,
        ),
      );
      setState(() {
        _currentResolution = desiredResolution;
      });
    }

    if (selectedFile == null || !selectedFile.containsKey('progressiveDownloadURL')) {
      printTime('Aucun fichier vidéo valide trouvé');
      return;
    }

    final videoUrl = selectedFile['progressiveDownloadURL'];

    if (_controller != null) {
      _lastPosition = _controller!.value.position;
      _wasPlaying = _controller!.value.isPlaying;

      _controller!.removeListener(_videoListener);
      _isInitializedNotifier.value = false;

      final oldController = _controller;
      _controller = null;

      await oldController!.dispose();
    }

    await playOnlineVideo(videoUrl);
  }

  Future<void> getVideoApi() async {
    String? lank = widget.video.naturalKey;
    String? lang = widget.video.mepsLanguage;

    if(widget.video.fileUrl != null) {
      final videoUrl = widget.video.fileUrl!;
      await playOnlineVideo(videoUrl);
      return;
    }

    if (lank != null && lang != null) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank?clientType=www';
      printTime('apiUrl: $apiUrl');
      try {
        final response = await Api.httpGetWithHeaders(apiUrl);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _onlineMediaData = data['media'][0];
          _updateAvailableResolutions(_onlineMediaData);
          fetchMedia(_onlineMediaData);
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

  Future<void> playOnlineVideo(String videoUrl) async {
    Uri uriVideo = Uri.parse(videoUrl);
    _controller = VideoPlayerController.networkUrl(
        uriVideo,
        httpHeaders: Api.getHeaders()
    )
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!.addListener(_videoListener);

        Duration position = _lastPosition ?? widget.initialPosition;
        _controller!.seekTo(position);

        if (_speedNotifier.value != 1.0) {
          _controller!.setPlaybackSpeed(_speedNotifier.value);
        }

        if (_wasPlaying || _lastPosition == null) {
          _controller!.play();
          _startControlsTimer();
        }

        _lastPosition = null;
        _wasPlaying = false;

        _isInitializedNotifier.value = true;
        _isPlayingNotifier.value = _controller!.value.isPlaying;
      })
          .catchError((error) {
        printTime("Erreur lors de l'initialisation de la vidéo: $error");
      });
  }

  Future<void> playLocalVideo() async {
    File file = File(widget.video.filePath!);

    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!.addListener(_videoListener);
        _controller!.play();
        _controller!.seekTo(widget.initialPosition);
        _isInitializedNotifier.value = true;
        _isPlayingNotifier.value = true;
        _startControlsTimer();
      });
  }

  Subtitle _getCurrentSubtitle() {
    if (_controller == null) {
      return Subtitle(text: '', startTime: Duration.zero, endTime: Duration.zero, alignment: Alignment.center);
    }
    final position = _controller!.value.position + const Duration(milliseconds: 800);
    return _subtitles.firstWhere(
          (subtitle) => position >= subtitle.startTime && position <= subtitle.endTime,
      orElse: () => Subtitle(text: '', startTime: Duration.zero, endTime: Duration.zero, alignment: Alignment.center),
    );
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    if (_controller!.value.isPlaying) {
      _startControlsTimer();
    } else {
      _timer?.cancel();
    }
  }

  void setSpeed(double value) {
    if (_controller != null) {
      double newSpeed = double.parse(value.clamp(0.5, 2.0).toStringAsFixed(1));

      if (newSpeed != _speedNotifier.value) {
        _controller!.setPlaybackSpeed(newSpeed);
        _speedNotifier.value = newSpeed;

        _tempSpeedDisplayNotifier.value = newSpeed;

        _timerSpeedDisplay?.cancel();
        _timerSpeedDisplay = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _tempSpeedDisplayNotifier.value = null;
          }
        });
      }
      _startControlsTimer();
    }
  }

  PopupMenuItem<double> _speedItem(double speed, [String? label]) {
    return PopupMenuItem<double>(
      value: speed,
      child: ValueListenableBuilder<double>(
        valueListenable: _speedNotifier,
        builder: (context, currentSpeed, _) {
          final bool isSelected = speed == currentSpeed;
          return Text(
            '${speed.toStringAsFixed(1).replaceAll('.', ',')}x'
                '${label != null ? ' · $label' : ''}',
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  String buildSpeedLabel() {
    final double speed = _speedNotifier.value;
    String labelForSpeed(double speed) {
      if (speed == 2.0) return 'Rapide';
      if (speed == 1.0) return 'Normale';
      if (speed == 0.5) return 'Lente';
      return '';
    }
    final speedStr = '${speed.toStringAsFixed(1).replaceAll('.', ',')}x';
    final label = labelForSpeed(speed);
    return 'Vitesse de lecture · $speedStr${label.isNotEmpty ? ' · $label' : ''}';
  }

  PopupMenuItem<String> _resolutionItem(String resolution) {
    return PopupMenuItem<String>(
      value: resolution,
      child: Text(
        resolution,
        style: TextStyle(
          color: _currentResolution == resolution ? Theme.of(context).primaryColor : Colors.white,
          fontWeight: _currentResolution == resolution ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _buildResolutionLabel() {
    return 'Résolution · $_currentResolution';
  }

  Future<void> _showResolutionMenu() async {
    if (_onlineMediaData == null || _availableResolutions.isEmpty) {
      showBottomMessage('Résolutions non disponibles pour cette vidéo.');
      return;
    }

    final selectedResolution = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(30, 500, 0, 0),
      popUpAnimationStyle: AnimationStyle(
        curve: Curves.fastLinearToSlowEaseIn,
        duration: const Duration(milliseconds: 200),
        reverseCurve: Curves.fastLinearToSlowEaseIn,
        reverseDuration: const Duration(milliseconds: 200),
      ),
      items: <PopupMenuEntry<String>>[
        _resolutionItem('Auto'),
        ..._availableResolutions.map((res) => _resolutionItem(res)),
      ],
    );

    if (selectedResolution != null && _onlineMediaData != null) {
      if (selectedResolution == 'Auto') {
        await fetchMedia(_onlineMediaData, desiredResolution: null);
      }
      else {
        await fetchMedia(_onlineMediaData, desiredResolution: selectedResolution);
      }
    }

    GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false);
    _startControlsTimer();
  }

  void _showSeekOverlay(int direction) {
    _seekDirectionNotifier.value = direction;

    _timerSeekDisplay?.cancel();
    _timerSeekDisplay = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _seekDirectionNotifier.value = null;
      }
    });
  }

  String _getLoopText(int loopMode) {
    if(loopMode == 0) {
      return 'Inactif';
    }
    else if(loopMode == 1) {
      return 'La piste';
    }
    else if(loopMode == 2) {
      return 'Toutes les pistes';
    }
    return '';
  }

  PopupMenuItem<int> _loopItem(int loopMode) {
    return PopupMenuItem<int>(
      value: loopMode,
      child: Text(
        _getLoopText(loopMode),
        style: TextStyle(
          color: _currentLoopMode == loopMode ? Theme.of(context).primaryColor : Colors.white,
          fontWeight: _currentLoopMode == loopMode ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _buildLoopLabel() {
    String loopText = _getLoopText(_currentLoopMode);
    return 'Répéter · $loopText';
  }

  Future<void> _showLoopMenu() async {
    final selectedLoop = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(30, 600, 0, 0),
      popUpAnimationStyle: AnimationStyle(
        curve: Curves.fastLinearToSlowEaseIn,
        duration: const Duration(milliseconds: 200),
        reverseCurve: Curves.fastLinearToSlowEaseIn,
        reverseDuration: const Duration(milliseconds: 200),
      ),
      items: <PopupMenuEntry<int>>[
        _loopItem(0),
        _loopItem(1),
        _loopItem(2),
      ],
    );

    if (selectedLoop != null) {
      if (selectedLoop == 0) {
        _controller!.setLooping(false);
        _currentLoopMode = 0;
      }
      else if(selectedLoop == 1) {
        _controller!.setLooping(true);
        _currentLoopMode = 1;
      }
      else if(selectedLoop == 2) {
        _controller!.setLooping(true);
        _currentLoopMode = 2;
      }
    }

    GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false);
    _startControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
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
          if (_controller != null && _activePointers == 1) {
            final deltaY = event.position.dy - _lastDragPosition;
            const double threshold = 30.0;

            if (deltaY.abs() > 5.0) {
              _isDragging = true;
              //_controlsVisibleNotifier.value = false;
              //GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
            }

            if (_hasSpeedBeenAdjusted) {
              return;
            }

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

        // ... (à l'intérieur de la méthode build, dans le Listener)
        onPointerUp: (PointerUpEvent event) {
          _activePointers--;

          if (_activePointers == 0) {
            if (_justDidTwoFingerAction) {
              _justDidTwoFingerAction = false;
              _startControlsTimer();
              return;
            }

            // --- DÉTECTION DU DOUBLE-CLIC ---
            if (!_isDragging) {
              final now = DateTime.now();

              // 1. Zone Supérieure et Inférieure (inchangé)
              final double appBarHeight = kToolbarHeight;
              final double topSafeArea = MediaQuery.of(context).padding.top;
              final double totalTopZone = appBarHeight + topSafeArea;

              const double bottomControlsHeight = 130.0;
              final double screenHeight = MediaQuery.of(context).size.height;
              final double totalBottomZoneStart = screenHeight - bottomControlsHeight;

              final double tapY = event.position.dy;
              final double tapX = event.position.dx; // 🚨 NOUVEAU: Stocker la position X
              final bool isTapInControlZone = tapY < totalTopZone || tapY > totalBottomZoneStart;

              // VÉRIFICATION DU DOUBLE-CLIC
              if (_lastTapTime != null &&
                  now.difference(_lastTapTime!) < _doubleTapTimeout &&
                  !isTapInControlZone)
              {
                // 🚨 DOUBLE-CLIC DÉTECTÉ 🚨

                // Annuler le timer du premier clic (s'il était en attente de simple clic)
                _doubleTapTimer?.cancel();

                // === LOGIQUE DE SAUT DE TEMPS (AVANCE/RECUL) ===
                final widgetWidth = MediaQuery.of(context).size.width; // Obtenir la largeur de l'écran

                if (_controller != null) {
                  if (tapX > widgetWidth / 2) { // Côté droit de l'écran -> Avance rapide (15s)
                    _controller!.seekTo(_controller!.value.position + const Duration(seconds: 15));
                    _showSeekOverlay(1);
                  } else { // Côté gauche de l'écran -> Recul rapide (5s)
                    _controller!.seekTo(_controller!.value.position - const Duration(seconds: 5));
                    _showSeekOverlay(-1);
                  }
                }
                // ===============================================

                // Réinitialiser les variables de tap
                _lastTapTime = null;

                // Redémarrer le timer des contrôles (puisque les contrôles étaient visibles ou basculés)
                _startControlsTimer();
                return;
              }

              // --- LOGIQUE DE SIMPLE CLIC (avec Timer) ---
              // ... (le reste de la logique du simple clic reste inchangé) ...

              // Annuler l'ancien timer si l'utilisateur a tapé une fois (le timer est pour la détection du second tap)
              _doubleTapTimer?.cancel();

              // Démarrer un timer pour attendre le second tapotement.
              _doubleTapTimer = Timer(_doubleTapTimeout, () {
                // Si le délai expire sans second tap, nous traitons cela comme un simple clic.
                _lastTapTime = null; // Réinitialiser pour le prochain geste
                _doubleTapTimer = null;

                // VÉRIFICATION DE LA NÉCESSITÉ DE BASCULER (Logique de simple clic déplacée)
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

              // Enregistrer l'heure du premier tap.
              _lastTapTime = now;

              return; // Retourner immédiatement pour laisser le Timer gérer le simple clic/double clic
            }

            // Le reste du bloc pour le glissement reste le même
            if (_isDragging) {
              _isDragging = false;
              return;
            }

            _startControlsTimer();
          }

          // Répétition de la logique de glissement (à retirer si vous l'avez déplacée au-dessus)
          if (_isDragging) {
            _isDragging = false;
            return;
          }

          _startControlsTimer();
        },

        onPointerCancel: (PointerCancelEvent event) {
          _activePointers = 0;
          _isDragging = false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Stack(
            children: [
              // Vidéo + Sous-titres
              Positioned.fill(
                child: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isInitializedNotifier,
                    builder: (context, isInitialized, child) {
                      if (_controller == null || !isInitialized) {
                        return CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        );
                      }

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vidéo
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),

                          // Sous-titres superposés
                          // 📝 Sous-titres - Affichés en bas de la vidéo
                          if (_showSubtitle && _subtitles.isNotEmpty)
                            Positioned.fill(
                              child: ValueListenableBuilder<double>(
                                valueListenable: _positionNotifier,
                                builder: (context, position, child) {
                                  final subtitle = _getCurrentSubtitle();
                                  if (subtitle.text.isEmpty) return const SizedBox.shrink();

                                  return Align(
                                    alignment: Alignment.bottomCenter, // toujours en bas
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10), // petit décalage du bord
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        subtitle.getText(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Overlay play/pause central
              ValueListenableBuilder<bool>(
                  valueListenable: _controlsVisibleNotifier,
                  builder: (context, controlsVisible, child) {
                    return Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _isPlayingNotifier,
                            builder: (context, isPlaying, innerChild) {
                              return AnimatedOpacity(
                                opacity: controlsVisible ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                  child: IconButton(
                                    iconSize: 75.0,
                                    padding: const EdgeInsets.all(2),
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }
              ),

              // Overlay d'affichage de la vitesse temporaire
              ValueListenableBuilder<double?>(
                valueListenable: _tempSpeedDisplayNotifier,
                builder: (context, tempSpeed, child) {
                  if (tempSpeed == null) {
                    return const SizedBox.shrink();
                  }

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
                            style: TextStyle(
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
              ),

              // Overlay d'affichage du saut
              ValueListenableBuilder<int?>(
                valueListenable: _seekDirectionNotifier,
                builder: (context, direction, child) {
                  if (direction == null) {
                    return const SizedBox.shrink();
                  }

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
              ),


              // AppBar
              ValueListenableBuilder<bool>(
                  valueListenable: _controlsVisibleNotifier,
                  builder: (context, controlsVisible, child) {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: controlsVisible ? 1.0 : 0.0,
                      child: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        titleSpacing: 2,
                        title: ValueListenableBuilder<double>(
                            valueListenable: _speedNotifier,
                            builder: (context, speed, _) {
                              return Text(_title, style: const TextStyle(color: Colors.white, fontSize: 16));
                            }
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
                          },
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(JwIcons.list_plus, color: Colors.white),
                            onPressed: () {
                              showAddItemToPlaylistDialog(context, widget.video);
                            },
                          ),
                          IconButton(
                            icon: const Icon(JwIcons.screen_square_right, color: Colors.white),
                            onPressed: () {
                              _controlsVisibleNotifier.value = false;

                              // Activer le PiP interne
                              BuildContext ctx = GlobalKeyService.jwLifePageKey.currentContext!;
                              //PIPView.of(context)!.presentBelow(GlobalKeyService.jwLifePageKey.currentState!.getMainScreen());
                            },
                          ),
                        ],
                      ),
                    );
                  }
              ),

              // Contrôles du bas
              ValueListenableBuilder<bool>(
                valueListenable: _controlsVisibleNotifier,
                builder: (context, controlsVisible, child) {
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
                                    value: position,
                                    min: 0.0,
                                    max: _duration.inSeconds.toDouble(),
                                    onChanged: (double newValue) {
                                      _positionNotifier.value = newValue;
                                    },
                                    onChangeStart: (double newValue) {
                                      _isPositionSeeking = true;
                                    },
                                    onChangeEnd: (double newValue) {
                                      _controller?.seekTo(Duration(seconds: newValue.toInt()));
                                      _isPositionSeeking = false;
                                      _startControlsTimer();
                                    },
                                    activeColor: Theme.of(context).primaryColor,
                                    inactiveColor: Colors.white.withOpacity(0.5),
                                  ),
                                );
                              },
                            ),
                            Row(
                              children: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isPlayingNotifier,
                                  builder: (context, isPlaying, child) {
                                    return IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        isPlaying ? JwIcons.pause : JwIcons.play,
                                        color: Colors.white,
                                      ),
                                      onPressed: _togglePlayPause,
                                    );
                                  },
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: _positionNotifier,
                                  builder: (context, position, child) {
                                    return Text(
                                      "${formatDuration(position)} / ${formatDuration(_duration.inSeconds.toDouble())}",
                                      style: const TextStyle(color: Colors.white),
                                    );
                                  },
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(JwIcons.text_box, color: Colors.white),
                                  onPressed: _showSubtitles,
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: _volumeNotifier,
                                  builder: (context, volume, child) {
                                    return IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                          volume == 0.0 ? JwIcons.sound_x : JwIcons.sound,
                                          color: Colors.white
                                      ),
                                      onPressed: () {
                                        _controller?.setVolume(volume == 0.0 ? 1.0 : 0.0);
                                        _startControlsTimer();
                                      },
                                    );
                                  },
                                ),
                                _buildSettingsMenu(),
                                IconButton(
                                  icon: Icon(_isFullScreen ? JwIcons.arrows_inward : JwIcons.arrows_outward, color: Colors.white),
                                  onPressed: () {
                                    // mettre en plein écran
                                    _isFullScreen = !_isFullScreen;

                                    // change portrait or landscape
                                    if (_isFullScreen) {
                                      SystemChrome.setPreferredOrientations([
                                        DeviceOrientation.landscapeLeft,
                                        DeviceOrientation.landscapeRight,
                                      ]);
                                    }
                                    else {
                                      SystemChrome.setPreferredOrientations([
                                        DeviceOrientation.portraitUp,
                                        DeviceOrientation.portraitDown,
                                      ]);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSettingsMenu() {
    return ValueListenableBuilder<double>(
        valueListenable: _speedNotifier,
        builder: (context, currentSpeed, child) {
          return PopupMenuButton(
            icon: const Icon(JwIcons.gear, size: 22, color: Colors.white),
            onOpened: () {
              GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(true);
              _timer?.cancel();
            },
            onSelected: (value) {
              GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false);
              _startControlsTimer();
            },
            onCanceled: () {
              GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false);
              _startControlsTimer();
            },
            constraints: const BoxConstraints(minWidth: 2.0),
            offset: const Offset(30, -300),
            popUpAnimationStyle: AnimationStyle(
              curve: Curves.fastLinearToSlowEaseIn,
              duration: const Duration(milliseconds: 200),
              reverseCurve: Curves.fastLinearToSlowEaseIn,
              reverseDuration: const Duration(milliseconds: 200),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    final uri = Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.video.mepsLanguage}&lank=${widget.video.naturalKey}');
                    SharePlus.instance.share(
                        ShareParams(title: widget.video.title, uri: uri)
                    );
                  });
                },
                child: const Row(
                  children: [
                    Icon(JwIcons.share),
                    SizedBox(width: 10),
                    Text('Partager'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => {
                  showAddItemToPlaylistDialog(context, widget.video)
                },
                child: const Row(
                  children: [
                    Icon(JwIcons.list_plus),
                    SizedBox(width: 10),
                    Text('Ajouter à la liste de lecture'),
                  ],
                ),
              ),
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
                    position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width / 2, 100, 0, 0),
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
                  GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false);
                  _startControlsTimer();
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
              PopupMenuItem(
                onTap: () async {
                  await Future.delayed(Duration.zero, () => _showResolutionMenu());
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(JwIcons.video_encoding),
                        const SizedBox(width: 10),
                        Text(_buildResolutionLabel()),
                      ],
                    ),
                    const Icon(JwIcons.chevron_right),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () async {
                  await Future.delayed(Duration.zero, () => _showLoopMenu());
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(JwIcons.arrows_loop),
                        const SizedBox(width: 10),
                        Text(_buildLoopLabel()),
                      ],
                    ),
                    const Icon(JwIcons.chevron_right),
                  ],
                ),
              ),
            ],
          );
        }
    );
  }

  Future<void> _showSubtitles() async {
    Subtitles subtitles = Subtitles();

    if (_subtitles.isEmpty) {
      if (widget.video.isDownloadedNotifier.value) {
        File file = File(widget.video.subtitlesFilePath);
        await subtitles.loadSubtitlesFromFile(file);
      } else {
        Map<String, dynamic> jsonData;

        if (widget.onlineVideo != null) {
          jsonData = widget.onlineVideo!;
        }
        else {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.video.mepsLanguage}/${widget.video.naturalKey}';
          final response = await Api.httpGetWithHeaders(link);
          if (response.statusCode == 200) {
            final jsonFile = response.body;
            jsonData = json.decode(jsonFile)['media'][0];
          } else {
            jsonData = {};
          }
        }

        await subtitles.loadSubtitles(jsonData);
      }
    }

    setState(() {
      _subtitles = _subtitles.isEmpty ? subtitles.getSubtitles() : _subtitles;
      _showSubtitle = !_showSubtitle;
    });
  }
}