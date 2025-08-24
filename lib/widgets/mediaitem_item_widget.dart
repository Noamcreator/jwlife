import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/jwlife_app.dart';
import '../core/api/api.dart';
import '../core/icons.dart';
import '../core/utils/utils.dart';
import '../core/utils/utils_audio.dart';
import '../core/utils/utils_media.dart';
import '../core/utils/utils_video.dart';
import '../data/databases/tiles_cache.dart';
import '../data/models/tile.dart';
import '../data/models/video.dart';
import '../data/realm/catalog.dart';
import 'dialog/publication_dialogs.dart';
import 'image_cached_widget.dart';

class MediaItemItemWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final bool timeAgoText;
  final double width;

  const MediaItemItemWidget({
    super.key,
    required this.mediaItem,
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
    if (widget.mediaItem.naturalKey != oldWidget.mediaItem.naturalKey) {
      _updateImageIfNeeded();
    }
  }

  void _updateImageIfNeeded() {
    final images = widget.mediaItem.realmImages!;
    final wideImageUrl = images.wideFullSizeImageUrl ?? images.wideImageUrl;
    final squareImageUrl = images.squareFullSizeImageUrl ?? images.squareImageUrl;
    final newImageUrl = wideImageUrl ?? squareImageUrl;

    if (_imageUrl != newImageUrl) {
      _imageUrl = newImageUrl;
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        _imageFuture = TilesCache().getOrDownloadImage(_imageUrl!);
      } else {
        _imageFuture = Future.value(null);
      }
    }
  }

  bool get isAudio => widget.mediaItem.type == "AUDIO";

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        isAudio ? showAudioPlayer(context, widget.mediaItem) : showFullScreenVideo(context, widget.mediaItem);
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
                  _buildRightBottom(context),
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
    final images = widget.mediaItem.realmImages!;
    final wideImageUrl = images.wideFullSizeImageUrl ?? images.wideImageUrl;
    final squareImageUrl = images.squareFullSizeImageUrl ?? images.squareImageUrl;
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
        pathNoImage: isAudio ? "pub_type_audio" : "pub_type_video",
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
          return isAudio
              ? [
            getAudioShareItem(widget.mediaItem),
            getAudioLanguagesItem(context, widget.mediaItem),
            getAudioFavoriteItem(widget.mediaItem),
            getAudioDownloadItem(context, widget.mediaItem),
            getAudioLyricsItem(context, widget.mediaItem),
            getCopyLyricsItem(widget.mediaItem),
          ]
              : [
            getVideoShareItem(widget.mediaItem),
            getVideoLanguagesItem(context, widget.mediaItem),
            getVideoFavoriteItem(widget.mediaItem),
            getVideoDownloadItem(context, widget.mediaItem),
            getShowSubtitlesItem(context, widget.mediaItem),
            getCopySubtitlesItem(context, widget.mediaItem),
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
            Icon(isAudio ? JwIcons.headphones__simple : JwIcons.play, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              formatDuration(widget.mediaItem.duration!),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightBottom(BuildContext context) {
    Video? video = JwLifeApp.mediaCollections.getVideo(widget.mediaItem);

    return video != null && video.isDownloaded == true
        ? JwLifeApp.userdata.favorites.contains(widget.mediaItem)
        ? Positioned(
      bottom: 4,
      right: 4,
      child: const Icon(
        JwIcons.star,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
      ),
    )
        : const SizedBox()
        : Positioned(
      bottom: -7,
      right: -7,
      child: IconButton(
        iconSize: 22,
        padding: const EdgeInsets.all(0),
        onPressed: () async {
          if (await hasInternetConnection()) {
            String link =
                'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.mediaItem.languageSymbol}/${widget.mediaItem.languageAgnosticNaturalKey}';
            final response = await Api.httpGetWithHeaders(link);
            if (response.statusCode == 200) {
              final jsonData = json.decode(response.body);
              showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
                if (value != null) {
                  downloadMedia(context, widget.mediaItem, jsonData['media'][0], file: value);
                }
              });
            }
          }
        },
        icon: const Icon(JwIcons.cloud_arrow_down,
            color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
      ),
    );
  }

  Widget _buildMediaTitle(BuildContext context) {
    String timeAgo = '';
    if (widget.timeAgoText) {
      DateTime firstPublished = DateTime.parse(widget.mediaItem.firstPublished!);
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
            widget.mediaItem.title!,
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
