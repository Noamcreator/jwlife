import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../../app/services/global_key_service.dart';
import '../../../../../data/models/video.dart';
import '../../../../../i18n/i18n.dart';
import '../../../../../widgets/mediaitem_item_widget.dart';
import '../data/models/document.dart';
import '../data/models/multimedia.dart';
import 'full_screen_image_page.dart';

class DocumentMediasView extends StatefulWidget {
  final Document document;

  const DocumentMediasView({super.key, required this.document});

  @override
  _DocumentMediasViewState createState() => _DocumentMediasViewState();
}

class _DocumentMediasViewState extends State<DocumentMediasView> {
  List<Multimedia> videos = [];
  List<Multimedia> images = [];

  @override
  void initState() {
    super.initState();
    setState(() {
      videos = widget.document.multimedias.where((media) => media.mimeType == 'video/mp4').toList();
      images = widget.document.multimedias.where((media) => media.mimeType != 'video/mp4' && !widget.document.multimedias.any((media2) => media.id == media2.linkMultimediaId)).toList();
    });
  }

  // Fonction pour calculer le nombre de colonnes selon la largeur de l'écran (version compacte)
  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) {
      return 6; // Très large écran - plus de colonnes
    } else if (screenWidth > 900) {
      return 4; // Écran large
    } else if (screenWidth > 600) {
      return 3; // Écran moyen (tablettes)
    } else if (screenWidth > 400) {
      return 2; // Mobiles en paysage
    } else {
      return 2; // Petits mobiles - minimum 2 colonnes
    }
  }

  // Fonction pour calculer l'espacement selon la largeur de l'écran (version compacte)
  double _getSpacing(double screenWidth) {
    if (screenWidth > 1200) {
      return 12.0; // Réduit
    }
    else if (screenWidth > 900) {
      return 10.0; // Réduit
    }
    else if (screenWidth > 600) {
      return 8.0; // Réduit
    }
    else {
      return 6.0; // Réduit
    }
  }

  // Fonction pour calculer le ratio d'aspect selon le type de contenu (version compacte)
  double _getAspectRatio(double screenWidth, bool isVideo) {
    // Ratios plus compacts pour afficher plus d'éléments
    if (isVideo) {
      return screenWidth > 600 ? 16 / 10.5 : 16 / 11.4; // Légèrement plus carré
    }

    // Pour les images, ratios plus compacts
    if (screenWidth > 1200) {
      return 1.2; // Plus carré sur grands écrans
    }
    else if (screenWidth > 600) {
      return 1.4; // Presque carré sur tablettes
    } else {
      return 1.6; // Légèrement rectangulaire sur mobiles
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final spacing = _getSpacing(screenWidth);

    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFc3c3c3) : const Color(0xFF626262));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n().navigation_meetings_show_media,
              style: textStyleTitle,
            ),
            Text(
              widget.document.getDisplayTitle(),
              style: textStyleSubtitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: () {
              History.showHistoryDialog(context);
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
      ),
      body: (videos.isEmpty && images.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Vidéos
            if (videos.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  i18n().label_videos,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: _getAspectRatio(screenWidth, true),
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final media = videos[index];
                  MediaItem? mediaItem = getMediaItem(media.keySymbol, media.track, media.mepsDocumentId, media.issueTagNumber, media.mepsLanguageId, isVideo: media.mimeType == 'video/mp4');
                  if (mediaItem == null) {
                    return Container();
                  }
                  Video video = Video.fromJson(mediaItem: mediaItem);
                  return videoTile(context, video, screenWidth);
                },
              ),
              SizedBox(height: spacing),
            ],

            // Section Images
            if (images.isNotEmpty) ...[
              if (videos.isNotEmpty) ...[
                SizedBox(height: spacing),
              ],
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  i18n().label_pictures,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: _getAspectRatio(screenWidth, false),
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final media = images[index];
                  return imageTile(context, media, screenWidth);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget videoTile(BuildContext context, Media media, double screenWidth) {
    return MediaItemItemWidget(media: media, timeAgoText: false, width: 190);
  }

  Widget imageTile(BuildContext context, Multimedia media, double screenWidth) {
    final double captionFontSize = screenWidth > 600 ? 11.0 : 9.0;

    return GestureDetector(
      onTap: () {
        Multimedia? multimedia = widget.document.multimedias.firstWhereOrNull((img) => img.filePath.toLowerCase() == media.filePath.toLowerCase());
        if (multimedia != null) {
          showPage(FullScreenImagePage(publication: widget.document.publication, multimedias: widget.document.multimedias, multimedia: multimedia));
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: ImageCachedWidget(
              imageUrl: '${widget.document.publication.path}/${media.filePath}',
              icon: JwIcons.video,
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          if (media.caption.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                  ),
                ),
                padding: EdgeInsets.all(screenWidth > 600 ? 8.0 : 4.0),
                child: Text(
                  media.caption,
                  style: TextStyle(
                    fontSize: captionFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}