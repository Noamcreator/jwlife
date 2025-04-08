import 'package:jwlife/data/realm/catalog.dart';

import 'Media.dart';

class Video extends Media {
  final int videoId;

  Video({
    required this.videoId,
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

  factory Video.fromJson(
      Map<String, dynamic> json, {String? languageSymbol, MediaItem? mediaItem}) {
    final files = json['files'];

    Map<String, dynamic>? firstFile;
    if (files is List && files.isNotEmpty && files[0] is Map<String, dynamic>) {
      firstFile = files[0];
    }

    return Video(
      videoId: json['VideoId'] ?? -1,
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
          firstFile?['bitrate'] ??
          0.0,
      duration: json['Duration'] ??
          json['duration'] ??
          0.0,
      checkSum: json['Checksum'] ??
          firstFile?['checksum'] ??
          '',
      fileSize: json['FileSize'] ??
          json['filesize'] ??
          firstFile?['filesize'] ??
          0,
      filePath: json['FilePath'] ?? '',
      source: json['Source'] ?? 0,
      modifiedDateTime: json['ModifiedDateTime'] ??
          firstFile?['modifiedDatetime'] ??
          '',
      isDownloaded: json['FilePath'] != null,
    );
  }

  String get subtitlesFilePath => filePath.replaceAll('.mp4', '.vtt');
}
