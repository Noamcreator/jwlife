
import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../core/utils/utils.dart';
import '../core/utils/utils_audio.dart';
import '../core/utils/utils_video.dart';
import '../data/databases/tiles_cache.dart';
import '../data/models/audio.dart';
import '../data/models/media.dart';
import '../data/models/tile.dart';
import '../data/models/video.dart';
import '../data/repositories/MediaRepository.dart';
import 'image_cached_widget.dart';

class MediaItemItemWidget extends StatefulWidget {
  final Media media;
  final bool timeAgoText;
  final double width;

  const MediaItemItemWidget({
    super.key,
    required this.media,
    required this.timeAgoText,
    this.width = 165,
  });

  @override
  State<MediaItemItemWidget> createState() => _MediaItemItemWidgetState();
}

class _MediaItemItemWidgetState extends State<MediaItemItemWidget> {
  Future<Tile?>? _imageFuture;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _updateImageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaItemItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.media.naturalKey != oldWidget.media.naturalKey) {
      _updateImageIfNeeded();
    }
  }

  void _updateImageIfNeeded() {
    final newImageUrl = widget.media.networkImageLsr ?? widget.media.networkImageSqr;

    if (_imageUrl != newImageUrl) {
      _imageUrl = newImageUrl;
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        _imageFuture = TilesCache().getOrDownloadImage(_imageUrl!);
      } else {
        _imageFuture = Future.value(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = MediaRepository().getMedia(widget.media);

    return InkWell(
      onTap: () {
        m.showPlayer(context);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 2.0),
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildMediaImage(),
                  _buildPopupMenu(context),
                  _buildMediaInfoOverlay(),
                  // icônes / favoris
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.media.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (isDownloading) {
                        return Positioned(
                          bottom: -7,
                          right: -7,
                          child: IconButton(
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            onPressed: () => widget.media.cancelDownload(context),
                            icon: const Icon(
                              JwIcons.x,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                            ),
                          ),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: widget.media.isDownloadedNotifier,
                        builder: (context, isDownloaded, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: widget.media.isFavoriteNotifier,
                            builder: (context, isFavorite, _) {
                              final hasUpdate = widget.media.hasUpdate();

                              if (!isDownloaded) {
                                return Positioned(
                                  bottom: -7,
                                  right: -7,
                                  child: IconButton(
                                    iconSize: 22,
                                    padding: EdgeInsets.zero,
                                    onPressed: () => widget.media.download(context),
                                    icon: const Icon(
                                      JwIcons.cloud_arrow_down,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                    ),
                                  ),
                                );
                              } else if (hasUpdate) {
                                return Positioned(
                                  bottom: -7,
                                  right: -7,
                                  child: IconButton(
                                    iconSize: 22,
                                    padding: EdgeInsets.zero,
                                    onPressed: () => widget.media.download(context),
                                    icon: const Icon(
                                      JwIcons.arrows_circular,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                    ),
                                  ),
                                );
                              } else if (isFavorite) {
                                return Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: const Icon(
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

                  // barre de progression
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.media.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (!isDownloading) return const SizedBox.shrink();

                      return Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ValueListenableBuilder<double>(
                          valueListenable: widget.media.progressNotifier,
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
              _buildMediaTitle(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaImage() {
    final wideImageUrl = widget.media.networkImageLsr;
    final squareImageUrl = widget.media.networkImageSqr;
    final isWide = wideImageUrl != null;
    final imageUrl = wideImageUrl ?? squareImageUrl;

    if (isWide || imageUrl == null) {
      return _buildCachedImage(imageUrl);
    }

    return FutureBuilder<Tile?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final tile = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting || tile == null) {
          return _buildCachedImage(imageUrl);
        }

        return FutureBuilder<Color>(
          future: getDominantColorFromFile(tile.file),
          builder: (context, colorSnapshot) {
            final bgColor = colorSnapshot.data ?? const Color(0xFFE0E0E0);
            return ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: Container(
                width: widget.width,
                height: widget.width / 2,
                color: bgColor,
                alignment: Alignment.center,
                child: Image.file(
                  tile.file,
                  width: 85,
                  height: 85,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCachedImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.0),
      child: ImageCachedWidget(
        imageUrl: imageUrl,
        icon: widget.media is Audio ? JwIcons.headphones__simple : JwIcons.video,
        height: widget.width / 2,
        width: widget.width,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return Positioned(
      top: -8,
      right: -13,
      child: PopupMenuButton(
        icon: const Icon(
          Icons.more_vert,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
        ),
        shadowColor: Colors.black,
        elevation: 8,
        itemBuilder: (context) {
          return widget.media is Audio
              ? [
            getAudioShareItem(widget.media as Audio),
            getAudioAddPlaylistItem(context, widget.media as Audio),
            getAudioLanguagesItem(context, widget.media as Audio),
            getAudioFavoriteItem(widget.media as Audio),
            getAudioDownloadItem(context, widget.media as Audio),
            getAudioLyricsItem(context, widget.media as Audio),
            getCopyLyricsItem(widget.media as Audio),
          ] : [
            getVideoShareItem(widget.media as Video),
            getVideoAddPlaylistItem(context, widget.media as Video),
            getVideoLanguagesItem(context, widget.media as Video),
            getVideoFavoriteItem(widget.media as Video),
            getVideoDownloadItem(context, widget.media as Video),
            getShowSubtitlesItem(context, widget.media as Video),
            getCopySubtitlesItem(context, widget.media as Video),
          ];
        },
      ),
    );
  }

  Widget _buildMediaInfoOverlay() {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(widget.media is Audio ? JwIcons.headphones__simple : JwIcons.play, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              formatDuration(widget.media.duration),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTitle(BuildContext context) {
    String timeAgo = '';
    if (widget.timeAgoText) {
      DateTime firstPublished = DateTime.parse(widget.media.firstPublished ?? '');
      DateTime publishedDate = DateTime(firstPublished.year, firstPublished.month, firstPublished.day);
      DateTime today = DateTime.now();
      DateTime currentDate = DateTime(today.year, today.month, today.day);
      int days = currentDate.difference(publishedDate).inDays;

      timeAgo = (days == 0)
          ? "Aujourd'hui"
          : (days == 1)
          ? "Hier"
          : "Il y a $days jours";
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2.0, right: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.media.title,
            style: TextStyle(fontSize: widget.timeAgoText == true ? 10 : 11.5, height: 1.1),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
          if (widget.timeAgoText && timeAgo.isNotEmpty)
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFc3c3c3)
                    : const Color(0xFF585858),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
        ],
      ),
    );
  }
}
