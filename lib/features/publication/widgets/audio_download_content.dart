import 'package:flutter/material.dart';

// Supposons que ces imports sont corrects
import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Contient formatFileSize
import '../../../data/models/audio.dart'; // Audio contient maintenant les ValueNotifier

class AudioDownloadContent extends StatefulWidget {
  final List<Audio> audios;
  final int totalSize;
  final BuildContext dialogContext;

  const AudioDownloadContent({
    super.key,
    required this.audios,
    required this.totalSize,
    required this.dialogContext,
  });

  @override
  _AudioDownloadContentState createState() => _AudioDownloadContentState();
}

class _AudioDownloadContentState extends State<AudioDownloadContent> {
  // Variables d'état globales calculées à partir des notifiers individuels
  double _globalProgress = 0.0; // Progression totale (0.0 à 1.0)
  bool _isDownloading = false;
  bool _isFullyDownloaded = false;

  @override
  void initState() {
    super.initState();
    _attachListeners();
    _updateGlobalStatus(); // Mise à jour initiale de l'état
  }

  @override
  void dispose() {
    _detachListeners();
    super.dispose();
  }

  // --- Gestion des Listeners ---

  void _attachListeners() {
    for (final audio in widget.audios) {
      audio.progressNotifier.addListener(_updateGlobalStatus);
      audio.isDownloadingNotifier.addListener(_updateGlobalStatus);
      audio.isDownloadedNotifier.addListener(_updateGlobalStatus);
    }
  }

  void _detachListeners() {
    for (final audio in widget.audios) {
      audio.progressNotifier.removeListener(_updateGlobalStatus);
      audio.isDownloadingNotifier.removeListener(_updateGlobalStatus);
      audio.isDownloadedNotifier.removeListener(_updateGlobalStatus);
    }
  }

  // --- Logique de Calcul Global ---

  void _updateGlobalStatus() {
    if (!mounted) return;

    int downloadedBytesSum = 0;
    bool anyIsDownloading = false;
    bool allAreDownloaded = true; // On suppose tout téléchargé, puis on infirme

    for (final audio in widget.audios) {
      // progressNotifier contient la taille téléchargée en octets (double)
      downloadedBytesSum += audio.progressNotifier.value.toInt();

      if (audio.isDownloadingNotifier.value) {
        anyIsDownloading = true;
      }

      if (!audio.isDownloadedNotifier.value) {
        allAreDownloaded = false;
      }
    }

    double newGlobalProgress = 0.0;
    if (widget.totalSize > 0) {
      newGlobalProgress = (downloadedBytesSum / widget.totalSize).clamp(0.0, 1.0);
    }

    setState(() {
      _isDownloading = anyIsDownloading;
      _isFullyDownloaded = allAreDownloaded;

      if (_isFullyDownloaded) {
        _globalProgress = 1.0;
      } else {
        _globalProgress = newGlobalProgress;
      }
    });
  }

  // --- Déclencheur du Téléchargement ---

  void _startDownload() async {
    if (_isDownloading || widget.audios.isEmpty || _isFullyDownloaded) return;

    setState(() {
      _isDownloading = true; // Afficher la barre de progression immédiatement
    });

    for (final audio in widget.audios) {
      audio.download(widget.dialogContext);
    }
    _updateGlobalStatus();
  }

  // --- Fonction de Suppression ---

  void _deleteDownload() {
    print('Suppression des médias audio lancée.');

    for (final audio in widget.audios) {
      // audio.remove(context) : Ceci est l'appel de suppression
      audio.remove(context);
    }

    // Après la suppression, mettez à jour l'état pour que la section "Supprimer" disparaisse
    _updateGlobalStatus();
  }


  @override
  Widget build(BuildContext context) {
    String downloadedSizeFormatted = formatFileSize((widget.totalSize * _globalProgress).toInt());
    String totalSizeFormatted = formatFileSize(widget.totalSize);

    // --- LOGIQUE POUR LA SECTION TÉLÉCHARGER (AUDIOS) ---
    IconData? downloadAudioIcon;
    Function()? onDownloadAudioPressed;
    Color downloadAudioIconColor = Theme.of(context).primaryColor;

    if (_isDownloading) {
      downloadAudioIcon = JwIcons.cloud_arrow_down; // L'indicateur circulaire remplacera l'icône
      onDownloadAudioPressed = null; // Désactiver le bouton pendant le téléchargement
    } else if (_isFullyDownloaded) {
      downloadAudioIcon = null; // Non utilisé car le ListTile est masqué
      onDownloadAudioPressed = null;
    } else {
      downloadAudioIcon = JwIcons.cloud_arrow_down;
      onDownloadAudioPressed = widget.audios.isNotEmpty ? _startDownload : null;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Titre "Télécharger" ---
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, top: 0.0),
            child: Text(
              'Télécharger',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // --- Section Enregistrements audio (Télécharger) ---
          // Masquée si _isFullyDownloaded est true
          if (!_isFullyDownloaded)
            ListTile(
              leading: Icon(JwIcons.headphones__simple, size: 25),
              title: Text('Enregistrements audio'),
              subtitle: Text(
                _isDownloading
                    ? 'Téléchargement en cours : $downloadedSizeFormatted / $totalSizeFormatted'
                    : '${widget.audios.length} fichiers • $totalSizeFormatted',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: _isDownloading
                  ? SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  value: _globalProgress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.shade300,
                ),
              )
                  : IconButton(
                icon: Icon(downloadAudioIcon, size: 25),
                color: downloadAudioIconColor,
                onPressed: onDownloadAudioPressed,
              ),
              contentPadding: EdgeInsets.zero,
            ),

          // **Barre de progression linéaire**
          // Affichée si un téléchargement est en cours OU si tout est téléchargé
          if (_isDownloading && !_isFullyDownloaded && _globalProgress != 1.0)
            Padding(
              // Ajoutez une marge inférieure si la section audio est masquée et que la section vidéo suit
              padding: EdgeInsets.only(top: 4.0, bottom: _isFullyDownloaded ? 16.0 : 8.0),
              child: LinearProgressIndicator(
                value: _globalProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_isFullyDownloaded ? Colors.green : Theme.of(context).primaryColor),
              ),
            ),

          // --- Section Vidéos supplémentaires (Télécharger) ---
          ListTile(
            leading: Icon(JwIcons.video, size: 25),
            title: Text('Vidéos supplémentaires'),
            subtitle: Text('28 fichiers', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(
              JwIcons.cloud_arrow_down,
              color: Theme.of(context).primaryColor,
              size: 25,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          // --- Sections de Suppression (Conditionnelles) ---
          if (_isFullyDownloaded)
            ...[ // Utilisation du spread operator pour ajouter des widgets conditionnellement
              Divider(height: 30, thickness: 1),

              // Titre "Supprimer"
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Supprimer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

              // Section Supprimer les médias audio
              ListTile(
                leading: Icon(JwIcons.headphones__simple, size: 25),
                title: Text('Enregistrements audio'),
                subtitle: Text(
                  '${widget.audios.length} fichiers • $totalSizeFormatted',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: Icon(JwIcons.trash, color: Theme.of(context).primaryColor, size: 25),
                  onPressed: _deleteDownload,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
        ],
      ),
    );
  }
}