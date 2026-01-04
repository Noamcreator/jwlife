import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/features/library/pages/audios/audios_items_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:realm/realm.dart';

import '../../../../../app/app_page.dart';
import '../../../../../data/models/video.dart';
import '../../../../../i18n/i18n.dart';
import '../../../../../widgets/mediaitem_item_widget.dart';
import '../../../../../widgets/responsive_appbar_actions.dart';
import '../../../core/utils/widgets_utils.dart';
import '../data/models/document.dart';
import '../data/models/multimedia.dart';
import '../../image/pages/full_screen_image_page.dart';

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
      images = widget.document.multimedias.where((media) => 
        media.mimeType != 'video/mp4' && 
        !widget.document.multimedias.any((media2) => media.id == media2.linkMultimediaId && media2.mimeType == 'video/mp4')
      ).toList();
    });
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 6;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  double _getSpacing(double screenWidth) {
    if (screenWidth > 1200) return 12.0;
    if (screenWidth > 900) return 10.0;
    if (screenWidth > 600) return 8.0;
    return 6.0;
  }

  // Ratio pour les vidéos (ton original) et pour les images (1200/675)
  double _getAspectRatio(double screenWidth, bool isVideo) {
    if (isVideo) {
      return screenWidth > 600 ? 16 / 10.5 : 16 / 11.4;
    }
    return 1200 / 675; // Ratio 16:9 forcé pour la grille d'images
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final spacing = _getSpacing(screenWidth);

    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().navigation_meetings_show_media,
        subTitle: widget.document.getDisplayTitle(),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: JwLifeApp.history.showHistoryDialog
          ),
          IconTextButton(
              icon: const Icon(JwIcons.video_music),
              onPressed: (BuildContext context) {
                String categoryKey = 'SJJMeetings';
                String languageSymbol = widget.document.publication.mepsLanguage.symbol;
                RealmResults<RealmCategory> category = RealmLibrary.realm.all<RealmCategory>().query("Key == \$0 AND LanguageSymbol == \$1", [categoryKey, languageSymbol]);
                if (category.isNotEmpty) {
                  showPage(AudioItemsPage(category: category.first));
                }
              }
          ),
        ],
      ),
      body: (videos.isEmpty && images.isEmpty)
          ? getLoadingWidget(Theme.of(context).primaryColor)
          : SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Vidéos (Inchangée)
            if (videos.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  i18n().label_videos,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  RealmMediaItem? mediaItem = getMediaItem(media.keySymbol, media.track, media.mepsDocumentId, media.issueTagNumber, media.mepsLanguageId, isVideo: media.mimeType == 'video/mp4');
                  if (mediaItem == null) {
                    return Container();
                  }
                  Video video = Video.fromJson(mediaItem: mediaItem);
                  return videoTile(context, video, screenWidth);
                },
              ),
              SizedBox(height: spacing),
            ],

            // Section Images (Format 1200/675 avec contain)
            if (images.isNotEmpty) ...[
              if (videos.isNotEmpty) ...[
                SizedBox(height: spacing),
              ],
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  i18n().label_pictures,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  // Widget Vidéo : Strictement identique à ton original
  Widget videoTile(BuildContext context, Media media, double screenWidth) {
    return MediaItemItemWidget(media: media, timeAgoText: false, width: 190);
  }

  // Widget Image : Ratio fixé et adaptation "contain"
  Widget imageTile(BuildContext context, Multimedia media, double screenWidth) {
    final double captionFontSize = screenWidth > 600 ? 11.0 : 9.0;

    return GestureDetector(
      onTap: () {
        Multimedia? multimedia = widget.document.multimedias.firstWhereOrNull((img) => img.filePath.toLowerCase() == media.filePath.toLowerCase());
        if (multimedia != null) {
          showPage(FullScreenImagePage(publication: widget.document.publication, multimedias: widget.document.multimedias, multimedia: multimedia));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03), // Fond très léger pour garder la structure
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              child: ImageCachedWidget(
                imageUrl: '${widget.document.publication.path}/${media.filePath}',
                icon: JwIcons.image,
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
                          offset: const Offset(1, 1),
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
      ),
    );
  }
}