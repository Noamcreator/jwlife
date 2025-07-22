import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../data/models/multimedia.dart';

class FullScreenImagePage extends StatefulWidget {
  final Publication publication;
  final List<Multimedia> multimedias;
  final int index;

  const FullScreenImagePage({
    super.key,
    required this.publication,
    required this.multimedias,
    required this.index,
  });

  @override
  _FullScreenImagePageState createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late int _currentIndex;
  final List<Multimedia> _multimedias = [];
  bool _controlsVisible = true;
  final TransformationController _transformationController = TransformationController();
  bool _isScaling = false;
  ScrollController? _scrollController;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;

    setState(() {
      for(Multimedia multimedia in widget.multimedias) {
        if (!widget.multimedias.any((img) => img.linkMultimediaId == multimedia.id && img.mimeType == 'video/mp4')) {
          _multimedias.add(multimedia);
        }
      }
     // _multimedias.sort((a, b) => a.beginParagraphOrdinal.compareTo(b.beginParagraphOrdinal));
    });

    _pageController = PageController(initialPage: _currentIndex);
    _scrollController = ScrollController();
    _transformationController.addListener(_handleTransformationChanged);
    //WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentIndex());
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _isScaling = scale != 1.0;
    });
  }

  void _scrollToCurrentIndex() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = 60.0; // Smaller size for thumbnails
    final targetOffset = (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    _scrollController!.animateTo(
      targetOffset.clamp(0.0, _scrollController!.position.maxScrollExtent),
      duration: Duration(milliseconds: 150),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _controlsVisible = !_controlsVisible;
          JwLifePage.toggleNavBarVisibility.call(_controlsVisible);
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildPageView(),        // Cas d'une liste d'images
            if (_controlsVisible) _buildAppBar(),
            if (_controlsVisible && _currentIndex != -1) _buildDescription(),
            if (_controlsVisible && _currentIndex != -1) _buildThumbnailList(),
          ],
        ),
      ),
    );
  }

  /// Affichage avec `PageView` pour plusieurs images
  Widget _buildPageView() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: _isScaling ? NeverScrollableScrollPhysics() : AlwaysScrollableScrollPhysics(),
            itemCount: _multimedias.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _transformationController.value = Matrix4.identity();
                _scrollToCurrentIndex();
              });
            },
            itemBuilder: (context, index) {
              Multimedia media =_multimedias[index];

              bool isVideo = media.mimeType == 'video/mp4';

              MediaItem? mediaItem;
              if (isVideo) {
                String? pub = media.keySymbol;
                int? track = media.track;
                int? documentId = media.mepsDocumentId;
                int? issueTagNumber = media.issueTagNumber;
                int? mepsLanguageId = media.mepsLanguageId;

                // Récupération de l'élément vidéo
                mediaItem = getVideoItem(
                  pub,
                  track,
                  documentId,
                  issueTagNumber,
                  mepsLanguageId,
                );
              }

              return InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: GestureDetector(
                  onTap: () {
                    if (isVideo && mediaItem != null) {
                      showFullScreenVideo(context, mediaItem);
                    }
                    else {
                      setState(() {
                        _controlsVisible = !_controlsVisible;
                        JwLifePage.toggleNavBarVisibility.call(_controlsVisible);
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      mediaItem != null ? ImageCachedWidget(
                        imageUrl:
                        mediaItem.realmImages?.wideFullSizeImageUrl ??
                            mediaItem.realmImages?.wideImageUrl ??
                            mediaItem.realmImages?.squareImageUrl,
                        pathNoImage: "pub_type_video",
                        fit: BoxFit.cover,
                      ) : Image.file(File('${widget.publication.path}/${media.filePath}'), fit: BoxFit.contain),
                      isVideo ? Icon(JwIcons.play_circle, color: Colors.white.withOpacity(0.8), size: 80) : Container(),

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
  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _multimedias[_currentIndex].caption,
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            JwLifePage.toggleNavBarVisibility.call(true);
            JwLifePage.toggleNavBarBlack.call(false);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Description sous l'image
  Widget _buildDescription() {
    return Positioned(
      bottom: isPortrait(context) ? MediaQuery.of(context).size.height / 4 : MediaQuery.of(context).size.height / 2.5,
      left: 0,
      right: 0,
      child: Text(
        _multimedias[_currentIndex].label,
        style: TextStyle(color: Colors.white, fontSize: 16.0, backgroundColor: Colors.black),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Positioned(
      bottom: isPortrait(context) ? MediaQuery.of(context).size.height / 10 : MediaQuery.of(context).size.height / 2.5,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 80, // Permet d'afficher la plus grande vignette correctement
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
              mediaItem = getVideoItem(
                pub,
                track,
                documentId,
                issueTagNumber,
                mepsLanguageId,
              );
            }

            final isSelected = index == _currentIndex;

            return GestureDetector(
              onTap: () => _pageController?.jumpToPage(index),
              child: Container(
                width: isSelected ? 80 : 60, // L'élément sélectionné est plus large
                margin: EdgeInsets.symmetric(horizontal: 5),
                child: Align( // Permet d'aligner les non-sélectionnés en bas
                  alignment: Alignment.center,
                  child: Container(
                    width: isSelected ? 80 : 60,
                    height: isSelected ? 80 : 60, // Seul l'élément sélectionné s'agrandit
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
                            pathNoImage: "pub_type_video",
                            fit: BoxFit.cover,
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
}
