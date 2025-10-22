import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import '../../../../../app/services/global_key_service.dart';
import '../../../../../data/models/video.dart';
import '../data/models/multimedia.dart';

class FullScreenImagePage extends StatefulWidget {
  final Publication publication;
  final List<Multimedia> multimedias;
  final Multimedia multimedia;

  const FullScreenImagePage({
    super.key,
    required this.publication,
    required this.multimedias,
    required this.multimedia,
  });

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late int _currentIndex;
  late final List<Multimedia> _multimedias;

  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);
  final ValueNotifier<bool> _descriptionVisible = ValueNotifier(false);
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();

  // Suppression du PhotoViewController pour simplifier et potentiellement améliorer la performance
  // PhotoViewController? _photoViewController;

  @override
  void initState() {
    super.initState();

    // Filtre des médias valides (exclut doublons vidéo)
    _multimedias = widget.multimedias.where((m) {
      return !widget.multimedias.any(
              (img) => img.linkMultimediaId == m.id && img.mimeType == 'video/mp4');
    }).toList();

    _currentIndex = _multimedias.indexWhere((img) => img.id == widget.multimedia.id);

    _pageController = PageController(initialPage: _currentIndex);

    // Suppression de l'initialisation du PhotoViewController
    // _photoViewController = PhotoViewController();

    // Initialiser l'état initial de la NavBar après la première frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(_controlsVisible.value);
    });
  }

  @override
  void dispose() {
    _descriptionVisible.dispose();
    _controlsVisible.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    // Suppression du dispose du PhotoViewController
    // _photoViewController?.dispose();
    super.dispose();
  }

  void _scrollToCurrentIndex() {
    final screenWidth = MediaQuery.of(context).size.width;
    const itemWidth = 60.0;
    final targetOffset = (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 50),
      curve: Curves.easeInOut,
    );
  }

  // Fonction simplifiée pour basculer la visibilité.
  // Elle est maintenant appelée par onTapUp des PhotoViewGalleryPageOptions.
  void _onTapImage() {
    _controlsVisible.value = !_controlsVisible.value;
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(_controlsVisible.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: _multimedias.length,
            backgroundDecoration: const BoxDecoration(color: Color(0xFF101010)),
            builder: (context, index) {
              Multimedia media = _multimedias[index];
              bool isVideo = media.mimeType == 'video/mp4';

              MediaItem? mediaItem;
              if (isVideo) {
                String? pub = media.keySymbol;
                int? track = media.track;
                int? documentId = media.mepsDocumentId;
                int? issueTagNumber = media.issueTagNumber;
                int? mepsLanguageId = media.mepsLanguageId;

                mediaItem = getMediaItem(
                    pub,
                    track,
                    documentId,
                    issueTagNumber,
                    mepsLanguageId,
                    isVideo: isVideo
                );
              }

              if (isVideo && mediaItem != null) {
                final video = Video.fromJson(mediaItem: mediaItem);
                return PhotoViewGalleryPageOptions.customChild(
                  child: GestureDetector(
                    onTap: () => video.showPlayer(context),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ImageCachedWidget(
                          imageUrl: mediaItem.realmImages?.wideFullSizeImageUrl ??
                              mediaItem.realmImages?.wideImageUrl ??
                              mediaItem.realmImages?.squareImageUrl,
                          icon: JwIcons.video,
                          fit: BoxFit.cover,
                          animation: false,
                        ),
                        const Icon(JwIcons.play_circle,
                            size: 80, color: Colors.white70),
                      ],
                    ),
                  ),
                  onTapDown: (context, details, controller) => _onTapImage(),
                );
              }

              // Image zoomable
              final imageProvider = FileImage(File('${widget.publication.path}/${media.filePath}')) as ImageProvider;

              // Remplacement du GestureDetector et du PhotoView.customChild par
              // la solution standard PhotoViewGalleryPageOptions avec onTapUp.
              return PhotoViewGalleryPageOptions(
                imageProvider: imageProvider,
                heroAttributes: PhotoViewHeroAttributes(tag: media.id),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                // Utilisation de onTapUp qui est le moyen le plus rapide de détecter un tap
                // sans conflit avec le swipe de PhotoViewGallery.
                onTapDown: (context, details, controller) => _onTapImage(),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _descriptionVisible.value = false;
                _scrollToCurrentIndex();
                // Retrait du dispose/réinitialisation du PhotoViewController pour la performance
              });
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

          // Barre supérieure
          ValueListenableBuilder<bool>(
            valueListenable: _controlsVisible,
            builder: (context, controlsVisible, child) {
              return controlsVisible ? _buildAppBar() : const SizedBox();
            },
          ),

          // Liste des miniatures
          ValueListenableBuilder<bool>(
            valueListenable: _controlsVisible,
            builder: (context, controlsVisible, child) {
              return controlsVisible ? _buildThumbnailList() : const SizedBox();
            },
          ),

          // Bouton description
          _buildFloatingDescriptionButton(),

          // Texte de description
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildAppBar() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        _multimedias[_currentIndex].caption,
        style: const TextStyle(color: Colors.white),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () =>
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(JwIcons.list_plus, color: Colors.white),
          onPressed: () {
            final fullFilePath =
                '${widget.publication.path}/${_multimedias[_currentIndex].filePath}';
            showAddItemToPlaylistDialog(context, fullFilePath);
          },
        ),
      ],
    ),
  );

  Widget _buildFloatingDescriptionButton() {
    if (_multimedias[_currentIndex].label.isEmpty) {
      return const SizedBox();
    }

    final double bottomOffset = isPortrait(context) ? MediaQuery.of(context).size.height / 10 + 70 : 90.0;

    return ValueListenableBuilder<bool>(
      valueListenable: _controlsVisible,
      builder: (context, controlsVisible, child) {
        if (!controlsVisible) {
          return const SizedBox();
        }
        return Positioned(
          bottom: bottomOffset,
          right: 16.0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _descriptionVisible,
            builder: (context, visible, _) {
              return FloatingActionButton(
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                onPressed: () => _descriptionVisible.value = !visible,
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(
                  visible ? JwIcons.image : JwIcons.gem,
                  color: Colors.white,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDescription() {
    final double bottom = isPortrait(context)
        ? MediaQuery.of(context).size.height / 4
        : MediaQuery.of(context).size.height / 2.5;

    return ValueListenableBuilder<bool>(
      valueListenable: _controlsVisible,
      builder: (context, controlsVisible, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: _descriptionVisible,
          builder: (context, descriptionVisible, _) {
            if (!descriptionVisible || !controlsVisible) return const SizedBox();
            return Positioned(
              bottom: bottom,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: descriptionVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _multimedias[_currentIndex].label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      backgroundColor: Colors.black.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnailList() => Positioned(
    bottom: 80,
    left: 0,
    right: 0,
    child: SizedBox(
      height: 80,
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

            mediaItem = getMediaItem(
                pub,
                track,
                documentId,
                issueTagNumber,
                mepsLanguageId,
                isVideo: true
            );
          }

          final isSelected = index == _currentIndex;

          return GestureDetector(
            onTap: () => _pageController.jumpToPage(index),
            child: Container(
              width: isSelected ? 80 : 60,
              margin: EdgeInsets.symmetric(horizontal: 5),
              child: Align(
                alignment: Alignment.center,
                child: Container(
                    width: isSelected ? 80 : 60,
                    height: isSelected ? 80 : 60,
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(0),
                          child: mediaItem != null ? ImageCachedWidget(
                            imageUrl:
                            mediaItem.realmImages?.squareFullSizeImageUrl ??
                                mediaItem.realmImages?.squareImageUrl ??
                                mediaItem.realmImages?.wideFullSizeImageUrl ?? mediaItem.realmImages?.wideImageUrl,
                            icon: JwIcons.video,
                            fit: BoxFit.cover,
                            animation: false,
                          ) : Image.file(File('${widget.publication.path}/${media.filePath}'), fit: BoxFit.cover),
                        ),
                        isVideo ? Icon(JwIcons.play_circle, color: Colors.white, size: 30) : Container(),
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