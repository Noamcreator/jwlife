import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/data/realm/catalog.dart';
import '../../core/app_data/app_data_service.dart';
import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_video.dart';
import '../repositories/MediaRepository.dart';
import 'media.dart';

class Audio extends Media {
  int? audioId;
  List<Marker> markers;

  Audio({
    this.audioId,
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
    this.markers = const [],
    super.progressNotifier,
    super.isDownloadingNotifier,
    super.isDownloadedNotifier,
    super.isFavoriteNotifier,
  });

  factory Audio.fromJson({Map<String, dynamic>? json, MediaItem? mediaItem, String? languageSymbol, bool? isFavorite}) {
    final keySymbol = json?['KeySymbol'] ?? mediaItem?.pubSymbol;
    final documentId = json?['DocumentId'] ?? mediaItem?.documentId;
    final bookNumber = json?['BookNumber'];
    final issueTagNumber = json?['IssueTagNumber'] ?? mediaItem?.issueDate;
    final track = json?['Track'] ?? mediaItem?.track;

    final mepsLanguage = languageSymbol ?? json?['MepsLanguage'] ?? mediaItem?.languageSymbol ?? JwLifeSettings.instance.currentLanguage.value.symbol;

    mediaItem ??= getMediaItem(keySymbol, track, documentId, issueTagNumber, mepsLanguage, isVideo: false);

    // Recherche existant
    final existing = MediaRepository().getMediaWithMepsLanguageId(
      keySymbol ?? '',
      documentId ?? 0,
      bookNumber ?? 0,
      issueTagNumber ?? 0,
      track ?? 0,
      mepsLanguage,
      true, // isAudio
    );

    if (existing is Audio) {
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

    final audio = Audio(
      audioId: json?['AudioId'] ?? -1,
      mediaId: json?['MediaKeyId'] ?? -1,
      naturalKey: mediaItem?.languageAgnosticNaturalKey,
      keySymbol: keySymbol,
      documentId: documentId,
      issueTagNumber: issueTagNumber,
      track: track,
      mepsLanguage: mepsLanguage,
      categoryKey: json?['CategoryKey'] ?? mediaItem?.primaryCategory ?? '' ,
      bookNumber: json?['BookNumber'] ?? 0,
      title: json?['Title'] ?? mediaItem?.title ?? '',
      version: json?['Version'],
      mimeType: json?['MimeType'],
      bitRate: (json?['BitRate'] ?? 0).toDouble(),
      duration: (json?['Duration'] ?? mediaItem?.duration ?? 0).toDouble(),
      imagePath: json?['Image'] ?? json?['ImagePath'] ?? '',
      networkImageSqr: mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl,
      networkImageLsr: mediaItem?.realmImages!.wideFullSizeImageUrl ?? mediaItem?.realmImages!.wideImageUrl ?? mediaItem?.realmImages!.squareFullSizeImageUrl ?? mediaItem?.realmImages!.squareImageUrl,
      checkSum: json?['Checksum'],
      fileSize: json?['FileSize'],
      filePath: json?['FilePath'],
      source: json?['Source'],
      firstPublished: mediaItem?.firstPublished,
      lastModified: json?['ModifiedDateTime'],
      timeStamp: json?['ModifiedDateTime'],
      fileUrl: json?['FileUrl'],
      markers: (json?['Markers'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(Marker.fromJson)
          .toList() ??
          [],
      isDownloadedNotifier: ValueNotifier((json?['FilePath'] != null) && ((json?['FileSize'] ?? 0) > 0)),
      isFavoriteNotifier: ValueNotifier(
        isFavorite ??
            AppDataService.instance.favorites.value.any(
                  (fav) =>
              fav is Audio &&
                  fav.keySymbol == keySymbol &&
                  fav.documentId == documentId &&
                  fav.issueTagNumber == issueTagNumber &&
                  fav.track == track &&
                  fav.mepsLanguage == mepsLanguage,
            ),
      ),
    );

    MediaRepository().addMedia(audio);
    return audio;
  }

  @override
  Future<void> download(BuildContext context, {int? resolution, Offset? tapPosition}) async {
    if(naturalKey == null) {
      super.performDownload(context, null);
    }
    else {
      if(await hasInternetConnection(context: context)) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$mepsLanguage/$naturalKey';
        final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
        if (response.statusCode == 200) {
          super.performDownload(context, response.data['media'][0]);
        }
      }
    }
  }

  @override
  Future<void> showPlayer(BuildContext context, {Duration initialPosition = Duration.zero, List<Media> medias = const []}) async {
    if(isDownloadedNotifier.value) {
      JwLifeApp.audioPlayer.playAudio(this, initialPosition: initialPosition);
    }
    else {
      if(await hasInternetConnection(context: context)) {
        JwLifeApp.audioPlayer.playAudio(this, initialPosition: initialPosition);
      }
    }
  }
}

class Marker {
  final String duration;
  final String startTime;
  final int? mepsParagraphId;
  final int? verseNumber;

  Marker({
    required this.duration,
    required this.startTime,
    this.mepsParagraphId,
    this.verseNumber,
  });

  factory Marker.fromJson(Map<String, dynamic> json) {
    return Marker(
      duration: json['duration'] ?? '',
      startTime: json['startTime'] ?? '',
      verseNumber: json['verseNumber'],
      mepsParagraphId: json['mepsParagraphId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'duration': duration,
    'startTime': startTime,
    if (verseNumber != null) 'verseNumber': verseNumber,
    if (mepsParagraphId != null) 'mepsParagraphId': mepsParagraphId,
  };
}

