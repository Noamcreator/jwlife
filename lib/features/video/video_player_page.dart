import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/data/databases/history.dart';

import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_page.dart';
import '../../app/services/global_key_service.dart';
import '../../core/api/api.dart';
import '../../core/utils/utils_playlist.dart';
import '../../i18n/i18n.dart';
import 'subtitles.dart';

class VideoPlayerPage extends StatefulWidget {
  final Video video;
  final List<Video> videos;
  final dynamic onlineVideo;
  final Duration initialPosition;

  const VideoPlayerPage({super.key, required this.video, this.onlineVideo, this.initialPosition=Duration.zero, this.videos = const []});

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

  // Variables pour sauvegarder l'état lors du changement de résolution ou de navigation
  Duration? _lastPosition;
  bool _wasPlaying = false;

  // NOUVEAU : Index de la vidéo en cours dans la liste widget.videos
  int _currentVideoIndex = 0;

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

    // NOUVEAU : Trouver l'index de la vidéo initiale
    _currentVideoIndex = widget.videos.indexWhere((v) => v.naturalKey == widget.video.naturalKey);
    if (_currentVideoIndex == -1 && widget.videos.isNotEmpty) {
      // Si la vidéo initiale n'est pas dans la liste (cas possible pour un lien direct),
      // on peut la laisser à 0 ou gérer un état spécifique si nécessaire.
      // Ici, on la laisse à 0 par défaut (cas simple).
      _currentVideoIndex = 0;
    } else if (widget.videos.isEmpty) {
      _currentVideoIndex = 0;
    }


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

      // NOUVEAU : Ajouter la logique de passage automatique à la vidéo suivante si nécessaire
      if (_hasNextItem() && _currentLoopMode == 0) { // Exemple simple: si on n'est pas en boucle simple
        _nextItem();
        _isClosingVideo = false; // Réinitialiser pour la prochaine vidéo
      } else {
        GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
      }
    }
  }

  void _startControlsTimer() {
    _timer?.cancel();

    int currentNavBarIndex = GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value;

    if (_controller != null && _controller!.value.isPlaying) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          if(currentNavBarIndex == GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex.value) {
            _controlsVisibleNotifier.value = false;
            GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
          }
        }
        _timer?.cancel();
      });
    }
  }

  /// S'occupe de la logique de nettoyage du VideoPlayerController actuel.
  Future<void> _disposeCurrentController() async {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _isInitializedNotifier.value = false;

      final oldController = _controller;
      _controller = null;

      // Dispose l'ancien contrôleur
      await oldController!.dispose();
    }
  }

  /// S'occupe de la logique de lancement de la lecture pour une nouvelle vidéo.
  Future<void> _playNewVideo(Video newVideo) async {
    History.insertVideo(newVideo);

    if(newVideo.isDownloadedNotifier.value) {
      await playLocalVideo(video: newVideo);
    }
    else {
      await getVideoApi(video: newVideo);
    }
  }

  // ============== GESTION DES RÉSOLUTIONS ==============

  void _updateAvailableResolutions(dynamic media, {bool isGetPubMedia = false}) {
    String listName = isGetPubMedia ? 'MP4' : 'files';
    String download = isGetPubMedia ? 'file' : 'progressiveDownloadURL';

    if (media == null || media[listName] == null) return;

    final files = media[listName] as List<dynamic>;
    _availableResolutions = files
        .where((file) =>
    file['mimetype'] == 'video/mp4' &&
        file.containsKey('label') &&
        file.containsKey(download))
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

  Future<void> fetchMedia(dynamic media, {String? desiredResolution, bool isGetPubMedia = false}) async {
    String listName = isGetPubMedia ? 'MP4' : 'files';
    String download = isGetPubMedia ? 'file' : 'progressiveDownloadURL';

    if (media == null || media[listName] == null) {
      printTime('Données média invalides');
      return;
    }

    final files = media[listName] as List<dynamic>;

    String resolutionToPlay = desiredResolution ?? _getBestAvailableResolution();

    dynamic selectedFile;

    if (desiredResolution == null || desiredResolution == 'Auto') {
      selectedFile = files.firstWhere(
            (file) =>
        file['mimetype'] == 'video/mp4' &&
            file.containsKey(download) &&
            file['label'] == resolutionToPlay,
        orElse: () => files.firstWhere(
              (file) => file['mimetype'] == 'video/mp4' && file.containsKey(download),
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
            file.containsKey(download),
        orElse: () => files.firstWhere(
              (file) => file['mimetype'] == 'video/mp4' && file.containsKey(download),
          orElse: () => null,
        ),
      );
      setState(() {
        _currentResolution = desiredResolution;
      });
    }

    if (selectedFile == null || !selectedFile.containsKey(download)) {
      printTime('Aucun fichier vidéo valide trouvé');
      return;
    }

    if(isGetPubMedia) {
      // Si c'est un changement de vidéo, on met à jour le titre/durée
      if (_onlineMediaData != widget.onlineVideo) {
        setState(() {
          _title = selectedFile['title'];
          _duration = Duration(seconds: selectedFile['duration'].toInt());
        });
      }
    }

    final videoUrl = isGetPubMedia ? selectedFile['file']['url'] : selectedFile['progressiveDownloadURL'];

    if (_controller != null) {
      _lastPosition = _controller!.value.position;
      _wasPlaying = _controller!.value.isPlaying;

      await _disposeCurrentController(); // Utilisation de la nouvelle fonction utilitaire
    }

    await playOnlineVideo(videoUrl);
  }

// MODIFICATION : Ajout d'un paramètre optionnel 'video'
  Future<void> getVideoApi({Video? video}) async {
    final currentVideo = video ?? widget.video;

    String? lank = currentVideo.naturalKey;
    String? lang = currentVideo.mepsLanguage;

    if(currentVideo.fileUrl != null) {
      final videoUrl = currentVideo.fileUrl!;
      await playOnlineVideo(videoUrl);
      return;
    }

    if (lank != null && lang != null) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank?clientType=www';
      printTime('apiUrl: $apiUrl');
      try {
        final response = await Api.httpGetWithHeaders(apiUrl, responseType: ResponseType.json);

        if (response.statusCode == 200) {
          _onlineMediaData = response.data['media'][0];
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
    else if (currentVideo.mepsLanguage != null) {
      // Déclaration et initialisation des variables
      String? pub = currentVideo.keySymbol;
      int? issue = currentVideo.issueTagNumber;
      int? docId = currentVideo.documentId;
      int? track = currentVideo.track;
      String langwritten = currentVideo.mepsLanguage!;

      // 1. Préparation des paramètres de requête
      final Map<String, String> queryParameters = {
        'langwritten': langwritten,
      };

      if (pub != null) {
        queryParameters['pub'] = pub;
      }
      if (issue != null) {
        queryParameters['issue'] = issue.toString();
      }
      if (docId != null) {
        queryParameters['docId'] = docId.toString();
      }
      if (track != null) {
        queryParameters['track'] = track.toString();
      }

      // 2. Construction de l'URL sécurisée
      final uri = Uri.https(
        'app.jw-cdn.org',
        '/apis/pub-media/GETPUBMEDIALINKS',
        queryParameters,
      );

      final apiUrl = uri.toString();

      printTime('apiUrl: $apiUrl');

      try {
        final response = await Api.httpGetWithHeaders(apiUrl);

        if (response.statusCode == 200) {
          final data = json.decode(response.data);
          _onlineMediaData = data['files'][langwritten];
          _updateAvailableResolutions(_onlineMediaData, isGetPubMedia: true);
          fetchMedia(_onlineMediaData, isGetPubMedia: true);
        }
        else {
          printTime('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        printTime('An exception occurred: $e');
      }
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

        // Utilise _lastPosition (sauvé lors de la navigation ou du changement de résolution)
        Duration position = _lastPosition ?? widget.initialPosition;
        _controller!.seekTo(position);

        if (_speedNotifier.value != 1.0) {
          _controller!.setPlaybackSpeed(_speedNotifier.value);
        }

        // Reprend la lecture si c'était le cas avant ou si c'est la première lecture
        if (_wasPlaying || _lastPosition == null) {
          _controller!.play();
          _startControlsTimer();
        }

        // Réinitialisation des états de navigation/changement
        _lastPosition = null;
        _wasPlaying = false;

        _isInitializedNotifier.value = true;
        _isPlayingNotifier.value = _controller!.value.isPlaying;
      })
          .catchError((error) {
        printTime("Erreur lors de l'initialisation de la vidéo: $error");
      });
  }

// MODIFICATION : Ajout d'un paramètre optionnel 'video'
  Future<void> playLocalVideo({Video? video}) async {
    final currentVideo = video ?? widget.video;
    File file = File(currentVideo.filePath!); // Utilisation de currentVideo

    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!.addListener(_videoListener);

        // Utilise _lastPosition pour reprendre après la navigation
        Duration position = _lastPosition ?? widget.initialPosition;
        _controller!.seekTo(position);

        // Reprend la lecture si c'était le cas ou si c'est la première lecture
        if (_wasPlaying || _lastPosition == null) {
          _controller!.play();
        }

        _isInitializedNotifier.value = true;
        _isPlayingNotifier.value = true;
        _startControlsTimer();

        // Réinitialisation des états de navigation/changement
        _lastPosition = null;
        _wasPlaying = false;
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

  /// Vérifie s'il y a une vidéo suivante dans la liste 'widget.videos'.
  bool _hasNextItem() {
    // S'assurer que _currentVideoIndex est à jour.
    final int currentIndex = _currentVideoIndex;

    // Retourne true si la liste n'est pas vide et l'index n'est pas le dernier.
    return widget.videos.isNotEmpty && currentIndex != -1 && currentIndex < widget.videos.length - 1;
  }

  /// Vérifie s'il y a une vidéo précédente dans la liste 'widget.videos'.
  bool _hasPreviousItem() {
    // S'assurer que _currentVideoIndex est à jour.
    final int currentIndex = _currentVideoIndex;

    // Retourne true si l'index est supérieur à 0 (pas la première vidéo).
    return widget.videos.isNotEmpty && currentIndex > 0;
  }

  /// Charge la vidéo suivante SANS changer de page.
  Future<void> _nextItem() async {
    if (!_hasNextItem()) {
      printTime('Aucun élément suivant disponible.');
      return;
    }

    // 1. Détermination de la prochaine vidéo et mise à jour de l'index
    final int nextIndex = _currentVideoIndex + 1;
    final Video nextVideo = widget.videos[nextIndex];

    // 2. Nettoyage du contrôleur actuel (important pour libérer les ressources)
    // Sauvegarde de l'état de lecture actuel (pour la prochaine vidéo)
    _lastPosition = Duration.zero; // Nouvelle vidéo commence au début
    _wasPlaying = _controller?.value.isPlaying ?? false; // Reprendre la lecture si elle était en cours

    await _disposeCurrentController();

    // 3. Mise à jour de l'état du widget pour la nouvelle vidéo
    setState(() {
      // Note: widget.video ne change pas, seule la variable interne _currentVideoIndex
      // et les états d'affichage (_title, _duration) changent.
      _currentVideoIndex = nextIndex;
      _title = nextVideo.title;
      _duration = Duration(seconds: nextVideo.duration.toInt());
      // Réinitialisation des états spécifiques à la vidéo
      _onlineMediaData = null;
      _currentResolution = 'Auto';
      _availableResolutions = [];
    });

    // 4. Initialisation de la nouvelle vidéo (Utilise la logique locale ou API)
    await _playNewVideo(nextVideo);
  }

  /// Charge la vidéo précédente SANS changer de page.
  Future<void> _previousItem() async {
    if (!_hasPreviousItem() || _positionNotifier.value >= 1.0) {
      // retourner au début de la vidéo
      _controller?.seekTo(Duration.zero);
      return;
    }

    // 1. Détermination de la vidéo précédente et mise à jour de l'index
    final int previousIndex = _currentVideoIndex - 1;
    final Video previousVideo = widget.videos[previousIndex];

    // 2. Nettoyage du contrôleur actuel
    _lastPosition = Duration.zero;
    _wasPlaying = _controller?.value.isPlaying ?? false;

    await _disposeCurrentController();

    // 3. Mise à jour de l'état du widget pour la nouvelle vidéo
    setState(() {
      _currentVideoIndex = previousIndex;
      _title = previousVideo.title;
      _duration = Duration(seconds: previousVideo.duration.toInt());
      // Réinitialisation des états spécifiques à la vidéo
      _onlineMediaData = null;
      _currentResolution = 'Auto';
      _availableResolutions = [];
    });

    // 4. Initialisation de la nouvelle vidéo
    await _playNewVideo(previousVideo);
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

  PopupMenuItem<double> _speedItem(double speed) {
    return PopupMenuItem<double>(
      value: speed,
      child: ValueListenableBuilder<double>(
        valueListenable: _speedNotifier,
        builder: (context, currentSpeed, _) {
          final bool isSelected = speed == currentSpeed;
          return Text(
            speed == 1.0 ? i18n().label_playback_speed_normal(1.0) : '${speed.toStringAsFixed(1).replaceAll('.', ',')}x',
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
    final speedStr = speed == 1.0 ? i18n().label_playback_speed_normal('${speed.toStringAsFixed(1).replaceAll('.', ',')}x') : '${speed.toStringAsFixed(1).replaceAll('.', ',')}x';
    return i18n().label_playback_speed_colon(speedStr);
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
    return '${i18n().message_select_video_size_title} · $_currentResolution';
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
      return i18n().label_off;
    }
    else if(loopMode == 1) {
      return i18n().label_repeat_one_short;
    }
    else if(loopMode == 2) {
      return i18n().label_repeat_all_short;
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
    return '${i18n().label_repeat} · $loopText';
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
        child: AppPage(
          isWebview: true,
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
                          if (_showSubtitle && _subtitles.isNotEmpty)
                            Positioned.fill(
                              child: ValueListenableBuilder<double>(
                                valueListenable: _positionNotifier,
                                builder: (context, position, child) {

                                  // 1. Déterminer l'orientation
                                  final orientation = MediaQuery.of(context).orientation;
                                  final isLandscape = orientation == Orientation.landscape;

                                  // 2. Définir la marge en fonction de l'orientation
                                  final double bottomMargin = isLandscape ? _controlsVisibleNotifier.value == true ? 130.0 : 10.0 : 10.0; // Plus haut en mode paysage (par exemple 50.0)

                                  final subtitle = _getCurrentSubtitle();
                                  if (subtitle.text.isEmpty) return const SizedBox.shrink();

                                  return Align(
                                    alignment: Alignment.bottomCenter, // toujours en bas
                                    child: Container(
                                      // 3. Utiliser la marge calculée
                                      margin: EdgeInsets.only(bottom: bottomMargin),
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
                                    iconSize: 50.0,
                                    padding: const EdgeInsets.all(2),
                                    icon: Icon(
                                      isPlaying ? JwIcons.pause : JwIcons.play,
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
                        titleSpacing: 0,
                        actionsPadding: const EdgeInsets.only(left: 10, right: 5),
                        title: ValueListenableBuilder<double>(
                            valueListenable: _speedNotifier,
                            builder: (context, speed, _) {
                              return Text(_title, style: const TextStyle(color: Colors.white, fontSize: 16));
                            }
                        ),
                        leading: IconButton(
                          icon: const Icon(JwIcons.chevron_left, color: Colors.white),
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
                  return SafeArea(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: controlsVisible ? 1.0 : 0.0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 50),
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
                                  // 1. Bouton Play/Pause (Pas de padding si désiré)
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _isPlayingNotifier,
                                    builder: (context, isPlaying, child) {
                                      return IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          isPlaying ? JwIcons.pause : JwIcons.play,
                                          color: Colors.white,
                                        ),
                                        onPressed: _togglePlayPause,
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 5),

                                  // 2. Durée (Contrainte par Expanded pour éviter le débordement)
                                  ValueListenableBuilder<double>(
                                    valueListenable: _positionNotifier,
                                    builder: (context, position, child) {
                                      return Text(
                                        "${formatDuration(position)} / ${formatDuration(_duration.inSeconds.toDouble())}",
                                        style: const TextStyle(color: Colors.white),
                                        overflow: TextOverflow.ellipsis, // Coupe le texte s'il est trop long
                                        maxLines: 1,
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 5),

                                  // 3. Bouton Précédent
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    splashRadius: 1,
                                    onPressed: _previousItem,
                                    icon: Icon(
                                      JwIcons.triangle_to_bar_left,
                                      color: Colors.white,
                                    ),
                                  ),

                                  // 4. Bouton Suivant
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    onPressed: _hasNextItem() ? _nextItem : null,
                                    icon: Icon(
                                      JwIcons.triangle_to_bar_right,
                                      color: _hasNextItem() ? Colors.white : Colors.white.withOpacity(0.3),
                                    ),
                                  ),

                                  const Spacer(flex: 1),

                                  // 5. Bouton Sous-titres
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(_showSubtitle ? JwIcons.caption : JwIcons.caption_crossed, color: Colors.white),
                                    onPressed: _showSubtitles,
                                  ),

                                  // 6. Bouton Volume
                                  ValueListenableBuilder<double>(
                                    valueListenable: _volumeNotifier,
                                    builder: (context, volume, child) {
                                      return IconButton(
                                        visualDensity: VisualDensity.compact,
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

                                  // Bouton Plein Écran
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    icon: Icon(_isFullScreen ? JwIcons.arrows_inward : JwIcons.arrows_outward, color: Colors.white),
                                    onPressed: () {
                                      _isFullScreen = !_isFullScreen;

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

                                  // Menu Paramètres (Le code _buildSettingsMenu() est conservé tel quel)
                                  _buildSettingsMenu(),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    )
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
                child: Row(
                  children: [
                    const Icon(JwIcons.share),
                    const SizedBox(width: 10),
                    Text(i18n().action_open_in_share),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => {
                  showAddItemToPlaylistDialog(context, widget.video)
                },
                child: Row(
                  children: [
                    const Icon(JwIcons.list_plus),
                    const SizedBox(width: 10),
                    Text(i18n().action_add_to_playlist),
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
                      _speedItem(2.0),
                      _speedItem(1.8),
                      _speedItem(1.6),
                      _speedItem(1.4),
                      _speedItem(1.2),
                      _speedItem(1.1),
                      _speedItem(1.0),
                      _speedItem(0.9),
                      _speedItem(0.8),
                      _speedItem(0.7),
                      _speedItem(0.6),
                      _speedItem(0.5),
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
          final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
          if (response.statusCode == 200) {
            jsonData = response.data['media'][0];
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