import 'package:jwlife/data/realm/catalog.dart';

import 'media.dart';

class Audio extends Media {
  final int audioId;

  Audio({
    required this.audioId,
    super.naturalKey,
    required super.mediaId,
    required super.keySymbol,
    required super.categoryKey,
    required super.imagePath,
    required super.mediaType,
    required super.documentId,
    required super.mepsLanguage,
    required super.issueTagNumber,
    required super.track,
    required super.bookNumber,
    required super.title,
    required super.version,
    required super.mimeType,
    required super.bitRate,
    required super.duration,
    required super.checkSum,
    required super.fileSize,
    required super.filePath,
    required super.source,
    required super.modifiedDateTime,
    super.fileUrl = '',
    super.markers = const [],
    super.isDownloaded = false,
  });

  factory Audio.fromJson(
      Map<String, dynamic> json, {
        String? languageSymbol,
        MediaItem? mediaItem,
      }) {
    final file = json['file'];
    final files = json['files'];

    Map<String, dynamic>? firstFile;
    if (files is List && files.isNotEmpty && files[0] is Map<String, dynamic>) {
      firstFile = files[0];
    }

    return Audio(
      audioId: json['AudioId'] ?? -1,
      naturalKey: json['naturalKey'] ?? '',
      mediaId: json['MediaKeyId'] ?? -1,
      keySymbol: json['KeySymbol'] ?? json['pub'] ?? '',
      categoryKey: json['CategoryKey'] ?? '',
      imagePath: json['ImagePath'] ?? '',
      mediaType: json['MediaType'] ?? 0,
      documentId: json['DocumentId'] ?? json['docid'] ?? 0,
      mepsLanguage: json['MepsLanguage'] ?? languageSymbol ?? '',
      issueTagNumber: json['IssueTagNumber'] ?? 0,
      track: json['Track'] ?? json['track'] ?? 0,
      bookNumber: json['BookNumber'] ?? json['booknum'] ?? 0,
      title: json['Title'] ?? json['title'] ?? '',
      version: json['Version'] ?? 1,
      mimeType: json['MimeType'] ??
          json['mimeType'] ??
          firstFile?['mimeType'] ??
          '',
      bitRate: json['BitRate'] ??
          json['bitRate'] ??
          firstFile?['bitrate']?.toDouble() ??
          0.0,
      duration: json['Duration'] ??
          json['duration']?.toDouble() ??
          0.0,
      checkSum: json['Checksum'] ??
          file?['checksum'] ??
          firstFile?['checksum'] ??
          '',
      fileSize: json['FileSize'] ??
          json['filesize'] ??
          firstFile?['filesize'] ??
          0,
      filePath: json['FilePath'] ?? '',
      source: json['Source'] ?? 0,
      modifiedDateTime: json['ModifiedDateTime'] ??
          file?['modifiedDatetime'] ??
          firstFile?['modifiedDatetime'] ??
          '',
      fileUrl: file?['url'] ??
          firstFile?['progressiveDownloadURL'] ??
          '',
      markers: (json['markers'] != null &&
          json['markers']['markers'] is List)
          ? (json['markers']['markers'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Marker.fromJson)
          .toList()
          : [],
      isDownloaded: json['FilePath'] != null,
    );
  }
}
