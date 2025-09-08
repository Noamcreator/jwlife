import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/data/realm/catalog.dart';
import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_video.dart';
import '../../widgets/dialog/utils_dialog.dart';
import '../repositories/MediaRepository.dart';
import 'media.dart';

class Audio extends Media {
  final int audioId;
  List<Marker> markers;

  Audio({
    required this.audioId,
    required super.mediaId,
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
    final issueTagNumber = json?['IssueTagNumber'] ?? mediaItem?.issueDate;
    final track = json?['Track'] ?? mediaItem?.track;

    final mepsLanguage = languageSymbol ?? json?['MepsLanguage'] ?? mediaItem?.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;

    mediaItem ??= getMediaItem(keySymbol, track, documentId, issueTagNumber, mepsLanguage, isVideo: false);

    // Recherche existant
    final existing = MediaRepository().getMediaWithMepsLanguageId(
      keySymbol ?? '',
      documentId ?? 0,
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
      existing.lastModified = json?['ModifiedDateTime'] ?? existing.lastModified;
      existing.isFavoriteNotifier.value = isFavorite ?? existing.isFavoriteNotifier.value;
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
            JwLifeApp.userdata.favorites.any(
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
  Future<void> download(BuildContext context) async {
    if(await hasInternetConnection()) {
      if(fileUrl != null) {
        super.performDownload(context, null);
      }
      else {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$mepsLanguage/$naturalKey';
        final response = await Api.httpGetWithHeaders(link);
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          final jsonData = json.decode(jsonFile);

          super.performDownload(context, jsonData['media'][0]);
        }
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }

  @override
  Future<void> showPlayer(BuildContext context, {Duration initialPosition = Duration.zero}) async {
    if(isDownloadedNotifier.value) {
      JwLifeApp.audioPlayer.playAudio(this, initialPosition: initialPosition);
    }
    else {
      if(await hasInternetConnection()) {
        JwLifeApp.audioPlayer.playAudio(this, initialPosition: initialPosition);
      }
      else {
        showNoConnectionDialog(context);
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

