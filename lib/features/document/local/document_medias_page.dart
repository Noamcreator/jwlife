import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/ui/text_styles.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/features/library/pages/audios/audios_items_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';

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
  List<Map<String, dynamic>> extractsMedias = [];

  @override
  void initState() {
    super.initState();
    fetchOtherImagesInExtractPublications();
    setState(() {
      videos = widget.document.multimedias.where((media) => media.mimeType == 'video/mp4').toList();
      images = widget.document.multimedias.where((media) => 
        media.mimeType != 'video/mp4' && 
        !widget.document.multimedias.any((media2) => media.id == media2.linkMultimediaId && media2.mimeType == 'video/mp4')
      ).toList();
    });
  }

  Future<void> fetchOtherImagesInExtractPublications() async {
    Database databasePub = widget.document.publication.documentsManager!.database;
    try {
      List<Map<String, dynamic>> response = await databasePub.rawQuery('''
        SELECT ext.Caption, ext.RefMepsDocumentId, ext.RefBeginParagraphOrdinal, ext.RefEndParagraphOrdinal
        FROM Extract ext
        INNER JOIN Document d ON dext.DocumentId = d.DocumentId
        INNER JOIN DocumentExtract dext ON ext.ExtractId = dext.ExtractId
        WHERE d.MepsDocumentId = ?;
      ''', [widget.document.mepsDocumentId]);

      for(Map<String, dynamic> extract in response) {
        if(extract['RefMepsDocumentId'] != null) {
           Publication? publicationPubExtract = await JwLifeApp.pubCollections.getDocumentFromAvailable(extract['RefMepsDocumentId'] as int, widget.document.mepsLanguageId);
          if(publicationPubExtract != null && publicationPubExtract.isDownloadedNotifier.value) {
            Database databaseExtract = publicationPubExtract.documentsManager == null ? await openReadOnlyDatabase(publicationPubExtract.databasePath!) : publicationPubExtract.documentsManager!.database;
            bool hasSuppressZoom = await checkIfColumnsExists(databaseExtract, 'Multimedia', ['SuppressZoom']);

            // Préparation dynamique des arguments
            String paragraphFilter = "";
            List<dynamic> queryParams = [extract['RefMepsDocumentId']];

            // Si les ordinals sont nuls, on ne rajoute pas le filtre (prend tout le document)
            if (extract['RefBeginParagraphOrdinal'] != null && extract['RefEndParagraphOrdinal'] != null) {
              paragraphFilter = "AND dm.BeginParagraphOrdinal >= ? AND dm.EndParagraphOrdinal <= ?";
              queryParams.add(extract['RefBeginParagraphOrdinal']);
              queryParams.add(extract['RefEndParagraphOrdinal']);
            }

            List<Map<String, dynamic>> responseExtract = await databaseExtract.rawQuery('''
              SELECT DISTINCT m.*
              FROM Multimedia m
              INNER JOIN DocumentMultimedia dm ON dm.MultimediaId = m.MultimediaId
              INNER JOIN Document d ON dm.DocumentId = d.DocumentId
              WHERE d.MepsDocumentId = ?
                AND m.MimeType IN ('image/jpeg', 'video/mp4')
                AND m.CategoryType != 9
                AND m.CategoryType != 4
                ${hasSuppressZoom ? 'AND m.SuppressZoom = 0' : ''}
                $paragraphFilter
            ''', queryParams);

            List<Multimedia> medias = responseExtract.map((e) => Multimedia.fromMap(e)).toList();

            if(medias.isNotEmpty) {
              var doc = parse(extract['Caption']);
              String caption = doc.querySelector('.etitle')?.text ?? '';

              setState(() {
                extractsMedias.add({
                  'title': caption,
                  'medias': medias,
                  'publication': publicationPubExtract
                });
              });
            }

            if (publicationPubExtract.documentsManager == null) await databaseExtract.close();
          }
        }
      }
    }
    catch (e) {
      printTime('Error: $e');
    }
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: emptyStateWidget(i18n().message_no_media_title, JwIcons.square_stack),      
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 6;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  double _getSpacing(double screenWidth) {
    if (screenWidth > 1200) return 10.0;
    if (screenWidth > 900) return 8.0;
    if (screenWidth > 600) return 6.0;
    return 6.0;
  }

  double _getAspectRatio(double screenWidth, bool isVideo) {
    if (isVideo) {
      return screenWidth > 600 ? 16 / 10.5 : 16 / 11.4;
    }
    return 1200 / 675; 
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
      body: (videos.isEmpty && images.isEmpty && extractsMedias.isEmpty)
          ? _buildEmptyState()
          : SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section Vidéos Principales ---
            if (videos.isNotEmpty) ...[
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
                    return FutureBuilder<Widget>(
                      future: videoTileNoMediaItem(context, media),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return snapshot.data ?? const SizedBox.shrink();
                        }
                        return const Center(child: CircularProgressIndicator()); // Widget d'attente
                      },
                    );
                  }
                  Video video = Video.fromJson(mediaItem: mediaItem);
                  return videoTile(context, video, screenWidth);
                },
              ),
              SizedBox(height: 4),
            ],

            // --- Section Images Principales ---
            if (images.isNotEmpty) ...[
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
                  return imageTile(context, media, screenWidth, widget.document.publication);
                },
              ),
              SizedBox(height: 8),
            ],

            // --- Section Extraits (Titre + Médias) ---
            if (extractsMedias.isNotEmpty) 
              for (var extract in extractsMedias) ...[
                Padding(
                  padding: EdgeInsets.only(top: spacing),
                  child: Text(
                    extract['title'] ?? "",
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
                    childAspectRatio: _getAspectRatio(screenWidth, false), // On garde un ratio image par défaut
                  ),
                  itemCount: (extract['medias'] as List<Multimedia>).length,
                  itemBuilder: (context, index) {
                    final Multimedia media = extract['medias'][index];
                    final Publication publication = extract['publication'];
                    
                    if (media.mimeType == 'video/mp4') {
                       RealmMediaItem? mediaItem = getMediaItem(media.keySymbol, media.track, media.mepsDocumentId, media.issueTagNumber, media.mepsLanguageId, isVideo: true);
                       if (mediaItem == null) {
                          return FutureBuilder<Widget>(
                            future: videoTileNoMediaItem(context, media),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done) {
                                return snapshot.data ?? Container();
                              }
                              return const Center(child: CircularProgressIndicator()); // Widget d'attente
                            },
                          );
                       }
                       return videoTile(context, Video.fromJson(mediaItem: mediaItem), screenWidth);
                    } 
                    else {
                       return imageTile(context, media, screenWidth, publication);
                    }
                  },
                ),
                SizedBox(height: 4),
              ],
          ],
        ),
      ),
    );
  }

  Future<Widget> videoTileNoMediaItem(BuildContext context, Multimedia media) async {
    Video? video = await getVideoApi(multimedia: media);
    if(video == null) return Container();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          video.showPlayer(context);
        },
        child: Padding(
          // *** MODIFICATION RTL: Utiliser EdgeInsetsDirectional ***
          padding: const EdgeInsetsDirectional.only(end: 2.0),
          child: SizedBox(
            child: Column(
              // CrossAxisAlignment.start est CORRECT
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ImageCachedWidget(
                      imageUrl: '',
                      icon: JwIcons.video,
                      width: 180,
                      height: 180 / 2,
                      fit: BoxFit.fitHeight,
                    ),

                    PositionedDirectional(
                      top: 0,
                      start: 0, // Utilisé au lieu de 'left'
                      child: Container(
                        color: Colors.black.withOpacity(0.85),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Row(
                          children: [
                            Text('►', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white)),
                            const SizedBox(width: 4),
                            Text(
                              formatDuration(video.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),

                    PositionedDirectional(
                      top: -13,
                      end: -7, // Utilisé au lieu de 'right'
                      child: PopupMenuButton(
                        useRootNavigator: true,
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                        shadowColor: Colors.black,
                        elevation: 8,
                        itemBuilder: (context) {
                          return [
                          if (video.isDownloadedNotifier.value && video.filePath != null) getVideoShareFileItem(video),
                            getVideoAddPlaylistItem(context, video),
                            getVideoAddNoteItem(context, video),
                            getVideoLanguagesItem(context, video),
                            getVideoFavoriteItem(video),
                            if (video.isDownloadedNotifier.value && ! video.isDownloadingNotifier.value) getVideoDownloadItem(context, video),
                            getShowSubtitlesItem(context, video),
                            getCopySubtitlesItem(context, video),
                          ];
                        },
                      ),
                    ),

                    // icônes / favoris (Positionné en BAS-FIN)
                    ValueListenableBuilder<bool>(
                      valueListenable: video.isDownloadingNotifier,
                      builder: (context, isDownloading, _) {
                        if (isDownloading) {
                          // Icône Annuler le téléchargement
                          return PositionedDirectional(
                            bottom: -7,
                            end: -7, // Utilisé au lieu de 'right'
                            child: IconButton(
                              iconSize: 22,
                              padding: EdgeInsets.zero,
                              onPressed: () => video.cancelDownload(context),
                              icon: const Icon(
                                JwIcons.x,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                              ),
                            ),
                          );
                        }

                        return ValueListenableBuilder<bool>(
                          valueListenable: video.isDownloadedNotifier,
                          builder: (context, isDownloaded, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: video.isFavoriteNotifier,
                              builder: (context, isFavorite, _) {
                                final hasUpdate = video.hasUpdate();

                                if (!isDownloaded) {
                                  // Icône de téléchargement
                                  return PositionedDirectional(
                                    bottom: -5,
                                    end: -5, // Utilisé au lieu de 'right'
                                    child: Builder(
                                        builder: (BuildContext iconButtonContext) {
                                          return IconButton(
                                            iconSize: 22,
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              final RenderBox renderBox = iconButtonContext.findRenderObject() as RenderBox;
                                              final Offset tapPosition = renderBox.localToGlobal(Offset.zero) + renderBox.size.center(Offset.zero);
                                              video.download(context, tapPosition: tapPosition);
                                            },
                                            icon: const Icon(
                                              JwIcons.cloud_arrow_down,
                                              color: Colors.white,
                                              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                            ),
                                          );
                                        }
                                    ),
                                  );
                                } 
                                else if (hasUpdate) {
                                  // Icône de mise à jour
                                  return PositionedDirectional(
                                    bottom: -5,
                                    end: -5, // Utilisé au lieu de 'right'
                                    child: IconButton(
                                      iconSize: 22,
                                      padding: EdgeInsets.zero,
                                      onPressed: () => video.download(context),
                                      icon: const Icon(
                                        JwIcons.arrows_circular,
                                        color: Colors.white,
                                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                      ),
                                    ),
                                  );
                                } else if (isFavorite) {
                                  // Icône de Favori
                                  return const PositionedDirectional(
                                    bottom: 4,
                                    end: 4, // Utilisé au lieu de 'right'
                                    child: Icon(
                                      JwIcons.star,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                    ),
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                            );
                          },
                        );
                      },
                    ),

                    // barre de progression (Positionnée sur toute la largeur)
                    ValueListenableBuilder<bool>(
                      valueListenable: video.isDownloadingNotifier,
                      builder: (context, isDownloading, _) {
                        if (!isDownloading) return const SizedBox.shrink();

                        return PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          child: ValueListenableBuilder<double>(
                            valueListenable: video.progressNotifier,
                            builder: (context, progress, _) {
                              return LinearProgressIndicator(
                                value: progress == -1 ? null : progress,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                                backgroundColor: Colors.black.withOpacity(0.3),
                                minHeight: 2,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2.0, end: 4.0),
                  child: Column(
                    // CrossAxisAlignment.start est CORRECT
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: Theme.of(context).extension<JwLifeThemeStyles>()!.rectangleMediaItemLargeTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget videoTile(BuildContext context, Media media, double screenWidth) {
    return MediaItemItemWidget(media: media, timeAgoText: false, width: 180);
  }

  Widget imageTile(BuildContext context, Multimedia media, double screenWidth, Publication publication) {
    final double captionFontSize = screenWidth > 600 ? 11.0 : 9.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showPage(FullScreenImagePage(
            publication: publication, 
            multimedias: [media], // Pour l'extrait, on affiche le média seul ou on pourrait passer la liste de l'extrait
            multimedia: media
          ));
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              child: ImageCachedWidget(
                imageUrl: '${publication.path}/${media.filePath}',
                icon: JwIcons.image,
                height: double.infinity,
                width: 180,
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