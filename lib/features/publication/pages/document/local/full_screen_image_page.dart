import 'dart:io'; // Importe les fonctionnalités d'entrée/sortie de Dart
import 'package:flutter/material.dart'; // Importe les composants Flutter Material
import 'package:jwlife/core/icons.dart'; // Importe les icônes personnalisées
import 'package:jwlife/core/utils/utils.dart'; // Importe les utilitaires généraux
import 'package:jwlife/core/utils/utils_playlist.dart'; // Importe les utilitaires de playlist
import 'package:jwlife/core/utils/utils_video.dart'; // Importe les utilitaires vidéo
import 'package:jwlife/data/models/publication.dart'; // Importe le modèle Publication
import 'package:jwlife/data/realm/catalog.dart'; // Importe le catalogue Realm (pour MediaItem)
import 'package:jwlife/widgets/image_cached_widget.dart'; // Importe le widget d'image en cache

import '../../../../../app/services/global_key_service.dart'; // Importe le service de clés globales
import '../../../../../data/models/video.dart'; // Importe le modèle Video
import '../data/models/multimedia.dart'; // Importe le modèle Multimedia

class FullScreenImagePage extends StatefulWidget { // Widget de la page d'affichage plein écran
  final Publication publication; // La publication parente
  final List<Multimedia> multimedias; // La liste complète des médias
  final Multimedia multimedia; // Le média initial à afficher

  const FullScreenImagePage({ // Constructeur du widget
    super.key,
    required this.publication,
    required this.multimedias,
    required this.multimedia,
  });

  @override
  _FullScreenImagePageState createState() => _FullScreenImagePageState(); // Crée l'état
}

class _FullScreenImagePageState extends State<FullScreenImagePage> { // Classe d'état
  late int _currentIndex; // Index du média actuellement affiché
  final List<Multimedia> _multimedias = []; // Liste filtrée des images/vidéos
  bool _controlsVisible = true; // Visibilité de l'AppBar et des vignettes
  bool _descriptionVisible = false; // Visibilité de la description (par le FAB)
  final TransformationController _transformationController = TransformationController(); // Contrôleur de zoom/pan
  bool _isScaling = false; // Indicateur si l'image est zoomée
  ScrollController? _scrollController; // Contrôleur de défilement des vignettes
  PageController? _pageController; // Contrôleur de la vue paginée (PageView)

  @override
  void initState() { // Initialisation de l'état
    super.initState();
    setState(() { // Met à jour l'état
      for(Multimedia multimedia in widget.multimedias) { // Parcourt les médias
        if (!widget.multimedias.any((img) => img.linkMultimediaId == multimedia.id && img.mimeType == 'video/mp4')) { // Filtre les vidéos liées aux images
          _multimedias.add(multimedia); // Ajoute le média filtré
        }
      }
    });

    _currentIndex = _multimedias.indexWhere((img) => img.id == widget.multimedia.id); // Trouve l'index initial

    _pageController = PageController(initialPage: _currentIndex); // Initialise le PageController
    _scrollController = ScrollController(); // Initialise le ScrollController
    _transformationController.addListener(_handleTransformationChanged); // Écoute le zoom
  }

  @override
  void dispose() { // Nettoyage de l'état
    _transformationController.dispose(); // Libère le contrôleur de transformation
    _scrollController?.dispose(); // Libère le contrôleur de défilement
    super.dispose();
  }

  void _handleTransformationChanged() { // Gère les changements de transformation
    final scale = _transformationController.value.getMaxScaleOnAxis(); // Récupère le facteur d'échelle
    setState(() {
      _isScaling = scale != 1.0; // Met à jour l'état de zoom
    });
  }

  void _scrollToCurrentIndex() { // Fait défiler les vignettes jusqu'à l'index actuel
    final screenWidth = MediaQuery.of(context).size.width; // Largeur de l'écran
    final itemWidth = 60.0; // Largeur de chaque vignette
    final targetOffset = (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2); // Calcul de la position cible
    _scrollController!.animateTo(
      targetOffset.clamp(0.0, _scrollController!.position.maxScrollExtent), // Cible limitée
      duration: Duration(milliseconds: 150),
      curve: Curves.easeInOut, // Animation douce
    );
  }

  void _toggleDescriptionVisibility() { // Bascule la visibilité de la description
    setState(() {
      _descriptionVisible = !_descriptionVisible; // Inverse l'état
    });
  }

  Widget _buildFloatingDescriptionButton() { // Construit le bouton flottant de description
    if (!_controlsVisible || _multimedias[_currentIndex].label.isEmpty) { // Ne le montre pas si les contrôles sont masqués
      return Container();
    }

    // Calcul pour placer le FAB au-dessus des vignettes ou de la nav bar
    final double bottomOffset = isPortrait(context)
        ? MediaQuery.of(context).size.height / 10 + 90
        : 90.0;

    return Positioned(
      bottom: bottomOffset, // Position verticale ajustée
      right: 16.0, // Position horizontale à droite
      child: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
        onPressed: _toggleDescriptionVisibility, // Action au clic
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          // Icône qui change selon l'état de visibilité
          _descriptionVisible ? JwIcons.image : JwIcons.gem,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // Construction de l'interface utilisateur
    return GestureDetector(
      onTap: () { // Détecte le simple tap
        setState(() {
          _controlsVisible = !_controlsVisible; // Bascule la visibilité des contrôles
        });
        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(_controlsVisible); // Bascule la NavBar
      },
      child: Scaffold(
        backgroundColor: Color(0xFF101010), // Fond sombre
        body: Stack( // Utilise un Stack pour superposer les éléments
          children: [
            _buildPageView(), // Affichage des médias (images/vidéos)
            if (_controlsVisible) _buildAppBar(), // Barre d'application supérieure
            // Affiche la description si activée
            if (_descriptionVisible && _currentIndex != -1) _buildDescription(),
            if (_controlsVisible && _currentIndex != -1) _buildThumbnailList(), // Liste des vignettes
            _buildFloatingDescriptionButton(), // Bouton flottant pour la description

            if (_controlsVisible && _currentIndex != -1)
              if (_controlsVisible && _currentIndex != -1)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GlobalKeyService.jwLifePageKey.currentState!.getBottomNavigationBar(isBlack: true) // Barre de navigation inférieure
                ),
          ],
        ),
      ),
    );
  }

  /// Affichage avec `PageView` pour plusieurs images
  Widget _buildPageView() { // Construit la vue paginée des médias
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: _isScaling ? NeverScrollableScrollPhysics() : AlwaysScrollableScrollPhysics(), // Bloque le swipe si zoomé
            itemCount: _multimedias.length,
            onPageChanged: (index) { // Lors du changement de page
              setState(() {
                _currentIndex = index; // Met à jour l'index
                _transformationController.value = Matrix4.identity(); // Réinitialise le zoom
                _scrollToCurrentIndex(); // Défile vers la nouvelle vignette
                _descriptionVisible = false; // Cache la description lors du changement de page
              });
            },
            itemBuilder: (context, index) { // Construction de chaque page
              Multimedia media =_multimedias[index];

              bool isVideo = media.mimeType == 'video/mp4'; // Vérifie si c'est une vidéo

              MediaItem? mediaItem; // Élément média (pour les ressources JW)
              if (isVideo) {
                String? pub = media.keySymbol;
                int? track = media.track;
                int? documentId = media.mepsDocumentId;
                int? issueTagNumber = media.issueTagNumber;
                int? mepsLanguageId = media.mepsLanguageId;

                // Récupération de l'élément vidéo
                mediaItem = getMediaItem(
                    pub,
                    track,
                    documentId,
                    issueTagNumber,
                    mepsLanguageId,
                    isVideo: isVideo // Indique que c'est une vidéo
                );
              }

              return InteractiveViewer( // Permet le zoom et le pan
                transformationController: _transformationController,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 12.0,
                child: GestureDetector(
                  onTap: () { // Gère le tap sur le média
                    if (isVideo && mediaItem != null) {
                      Video video = Video.fromJson(mediaItem: mediaItem);
                      video.showPlayer(context); // Ouvre le lecteur vidéo
                    }
                    else {
                      setState(() {
                        _controlsVisible = !_controlsVisible; // Bascule les contrôles
                      });
                      GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(_controlsVisible); // Bascule la NavBar
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      mediaItem != null ? ImageCachedWidget( // Si c'est un média JW (avec MediaItem)
                        imageUrl:
                        mediaItem.realmImages?.wideFullSizeImageUrl ?? // URL de l'image
                            mediaItem.realmImages?.wideImageUrl ??
                            mediaItem.realmImages?.squareImageUrl,
                        pathNoImage: "pub_type_video",
                        fit: BoxFit.cover,
                      ) : Image.file(File('${widget.publication.path}/${media.filePath}'), fit: BoxFit.contain), // Si c'est un fichier local
                      isVideo ? Icon(JwIcons.play_circle, color: Colors.white.withOpacity(0.8), size: 80) : Container(), // Icône de lecture pour les vidéos

                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Barre d'application en haut
  Widget _buildAppBar() { // Construit l'AppBar
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.transparent, // Fond transparent
        elevation: 0,
        title: Text(
          _multimedias[_currentIndex].caption, // Titre du média
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context); // Gère le retour
          },
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.list_plus, color: Colors.white),
            onPressed: () {
              String fullFilePath = '${widget.publication.path}/${_multimedias[_currentIndex].filePath}'; // Chemin complet du fichier
              showAddPlaylistDialog(context, fullFilePath); // Affiche la boîte de dialogue Playlist
            },
          ),
        ],
      ),
    );
  }

  /// Description sous l'image
  Widget _buildDescription() { // Construit la description textuelle
    // La description est affichée si _descriptionVisible est vrai
    return Positioned(
      bottom: isPortrait(context) ? MediaQuery.of(context).size.height / 4 : MediaQuery.of(context).size.height / 2.5, // Position calculée
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          _multimedias[_currentIndex].label, // Le texte de la description
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            backgroundColor: Colors.black.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildThumbnailList() { // Construit la liste horizontale des vignettes
    return Positioned(
      bottom: isPortrait(context) ? MediaQuery.of(context).size.height / 10 : MediaQuery.of(context).size.height / 2.5, // Position des vignettes
      left: 0,
      right: 0,
      child: SizedBox(
        height: 80, // Hauteur fixe pour la liste
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          itemCount: _multimedias.length,
          itemBuilder: (context, index) {
            final media = _multimedias[index];

            bool isVideo = media.mimeType == 'video/mp4';

            MediaItem? mediaItem;
            if (isVideo) {
              String? pub = media.keySymbol;
              int? track = media.track;
              int? documentId = media.mepsDocumentId;
              int? issueTagNumber = media.issueTagNumber;
              int? mepsLanguageId = media.mepsLanguageId;

              // Récupération de l'élément vidéo
              mediaItem = getMediaItem(
                  pub,
                  track,
                  documentId,
                  issueTagNumber,
                  mepsLanguageId,
                  isVideo: true
              );
            }

            final isSelected = index == _currentIndex; // Vérifie si c'est la vignette actuelle

            return GestureDetector(
              onTap: () => _pageController?.jumpToPage(index), // Navigue vers la page correspondante
              child: Container(
                width: isSelected ? 80 : 60, // L'élément sélectionné est plus large
                margin: EdgeInsets.symmetric(horizontal: 5),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                      width: isSelected ? 80 : 60,
                      height: isSelected ? 80 : 60, // Seul l'élément sélectionné s'agrandit
                      decoration: BoxDecoration(
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null, // Bordure blanche si sélectionné
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(0),
                            child: mediaItem != null ? ImageCachedWidget( // Si MediaItem est disponible
                              imageUrl:
                              mediaItem.realmImages?.squareFullSizeImageUrl ??
                                  mediaItem.realmImages?.squareImageUrl ??
                                  mediaItem.realmImages?.wideFullSizeImageUrl ?? mediaItem.realmImages?.wideImageUrl, // URL de la vignette
                              pathNoImage: "pub_type_video",
                              fit: BoxFit.cover,
                            ) : Image.file(File('${widget.publication.path}/${media.filePath}'), fit: BoxFit.cover), // Fichier local
                          ),
                          isVideo ? Icon(JwIcons.play_circle, color: Colors.white, size: 30) : Container(), // Icône de lecture pour les vidéos
                        ],
                      )
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}