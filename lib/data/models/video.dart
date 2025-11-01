import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/data/realm/catalog.dart';
import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_video.dart';
import '../../features/video/video_player_page.dart';
import '../../core/utils/utils_dialog.dart';
import '../repositories/MediaRepository.dart';
import 'media.dart';

class Video extends Media {
  int? videoId;
  double? frameRate;
  int? frameHeight;
  int? frameWidth;
  String? label;
  String? specialtyDescription;
  Subtitles? subtitles;

  Video({
    this.videoId,
    super.mediaId,
    super.naturalKey,
    super.keySymbol,
    super.categoryKey,
    super.documentId,
    super.mepsLanguage,
    super.issueTagNumber,
    super.track,
    super.bookNumber,
    super.title,
    super.version,
    super.mimeType,
    super.bitRate,
    super.duration,
    super.imagePath,
    super.networkImageSqr,
    super.networkImageLsr,
    super.checkSum,
    super.fileSize,
    super.filePath,
    super.source,
    super.firstPublished,
    super.lastModified,
    super.timeStamp,
    super.fileUrl,
    super.progressNotifier,
    super.isDownloadingNotifier,
    super.isDownloadedNotifier,
    super.isFavoriteNotifier,
    this.frameRate,
    this.frameHeight,
    this.frameWidth,
    this.label,
    this.specialtyDescription,
    this.subtitles,
  });

  factory Video.fromJson({Map<String, dynamic>? json, MediaItem? mediaItem, bool? isFavorite}) {
    final keySymbol = json?['KeySymbol'] ?? mediaItem?.pubSymbol;
    final documentId = json?['DocumentId'] ?? mediaItem?.documentId;
    final bookNumber = json?['BookNumber'];
    final issueTagNumber = json?['IssueTagNumber'] ?? mediaItem?.issueDate;
    final track = json?['Track'] ?? mediaItem?.track;

    final mepsLanguage = json?['MepsLanguage'] ?? mediaItem?.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;

    mediaItem ??= getMediaItem(keySymbol, track, documentId, issueTagNumber, mepsLanguage, isVideo: true);

    // Recherche existant
    final existing = MediaRepository().getMediaWithMepsLanguageId(
      keySymbol ?? '',
      documentId ?? 0,
      bookNumber ?? 0,
      issueTagNumber ?? 0,
      track ?? 0,
      mepsLanguage,
      false, // isAudio
    );

    if (existing is Video) {
      if (!existing.isDownloadedNotifier.value && json != null) {
        existing.fileSize = json['FileSize'] ?? existing.fileSize;
        existing.filePath = json['FilePath'] ?? existing.filePath;
        existing.imagePath = json['ImagePath'] ?? existing.imagePath;
      }
      existing.naturalKey = mediaItem?.languageAgnosticNaturalKey ?? existing.naturalKey;
      existing.firstPublished = json?['FirstPublished'] ?? mediaItem?.firstPublished ?? existing.firstPublished;
      existing.lastModified = json?['ModifiedDateTime'] ?? existing.lastModified;
      existing.isFavoriteNotifier.value = isFavorite ?? existing.isFavoriteNotifier.value;
      existing.networkImageSqr = mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl;
      existing.networkImageLsr = mediaItem?.realmImages!.wideFullSizeImageUrl ?? mediaItem?.realmImages!.wideImageUrl ?? mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl;

      return existing;
    }

    final video = Video(
      videoId: json?['VideoId'] ?? -1,
      mediaId: json?['MediaKeyId'] ?? -1,
      naturalKey: mediaItem?.languageAgnosticNaturalKey,
      keySymbol: keySymbol,
      documentId: documentId,
      issueTagNumber: issueTagNumber,
      track: track,
      mepsLanguage: mepsLanguage,
      categoryKey: json?['CategoryKey'] ?? mediaItem?.primaryCategory ?? '',
      bookNumber: json?['BookNumber'] ?? 0,
      title: json?['Title'] ?? mediaItem?.title ?? '',
      version: json?['Version'],
      mimeType: json?['MimeType'],
      bitRate: (json?['BitRate'] ?? 0).toDouble(),
      duration: (json?['Duration'] ?? mediaItem?.duration ?? 0).toDouble(),
      imagePath: json?['ImagePath'] ?? '',
      networkImageSqr: mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl,
      networkImageLsr: mediaItem?.realmImages!.wideFullSizeImageUrl ?? mediaItem?.realmImages!.wideImageUrl ?? mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl,
      checkSum: json?['Checksum'],
      fileSize: json?['FileSize'],
      filePath: json?['FilePath'],
      source: json?['Source'],
      firstPublished: json?['FirstPublished'] ?? mediaItem?.firstPublished,
      lastModified: json?['ModifiedDateTime'],
      timeStamp: json?['ModifiedDateTime'],
      fileUrl: json?['FileUrl'],
      isDownloadedNotifier: ValueNotifier((json?['FilePath'] != null) && ((json?['FileSize'] ?? 0) > 0)),
      isFavoriteNotifier: ValueNotifier(
        isFavorite ??
            JwLifeApp.userdata.favorites.any(
                  (fav) =>
              fav is Video &&
                  fav.keySymbol == keySymbol &&
                  fav.documentId == documentId &&
                  fav.issueTagNumber == issueTagNumber &&
                  fav.track == track &&
                  fav.mepsLanguage == mepsLanguage,
            ),
      ),
      frameRate: json?['FrameRate'],
      frameHeight: json?['FrameHeight'],
      frameWidth: json?['FrameWidth'],
      label: json?['Label'],
      specialtyDescription: json?['SpecialtyDescription'],
      subtitles: json != null ? Subtitles.fromJson(json) : null
    );

    MediaRepository().addMedia(video);
    return video;
  }

  /// Exemple d’helper spécifique aux vidéos
  String get subtitlesFilePath => filePath!.replaceAll('.mp4', '.vtt');

  @override
  Future<void> download(BuildContext context, {int? resolution}) async {
    if (await hasInternetConnection()) {
      if (!isDownloadingNotifier.value && !isDownloadedNotifier.value) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$mepsLanguage/$naturalKey';
        final response = await Api.httpGetWithHeaders(link);
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          // Si 'file' est null, assigne le résultat de showVideoDownloadDialog à 'file'.
          resolution ??= await showVideoDownloadDialog(context, jsonData['media'][0]['files']);

          if(resolution == null) return;

          await super.performDownload(context, jsonData['media'][0], resolution: resolution);
        }
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }

  @override
  Future<void> showPlayer(BuildContext context, {Duration initialPosition = Duration.zero, List<Media> medias = const []}) async {
    if(isDownloadedNotifier.value) {
      // Exemple de mapping/filtrage si Video est un type spécifique dans la liste
      showPage(VideoPlayerPage(
          video: this,
          videos: medias.whereType<Video>().toList(),
          initialPosition: initialPosition
      ));
    }
    else {
      if(await hasInternetConnection()) {
        showPage(VideoPlayerPage(
            video: this,
            videos: medias.whereType<Video>().toList(),
            initialPosition: initialPosition
        ));
      }
      else {
        showNoConnectionDialog(context);
      }
    }
  }
}

class Subtitles {
  final int subtitleId;
  final int videoId;
  String? checkSum;
  String? timeStamp;
  String? mepsLanguage;
  String? filePath;

  Subtitles({
    this.subtitleId = -1,
    this.videoId = -1,
    this.checkSum,
    this.timeStamp,
    this.mepsLanguage,
    this.filePath,
  });

  factory Subtitles.fromJson(Map<String, dynamic> json) {
    return Subtitles(
      subtitleId: json['SubtitleId'] ?? -1,
      videoId: json['VideoId'] ?? -1,
      checkSum: json['Checksum'],
      timeStamp: json['ModifiedDateTime'],
      mepsLanguage: json['MepsLanguage'],
      filePath: json['FilePath'],
    );
  }
}

