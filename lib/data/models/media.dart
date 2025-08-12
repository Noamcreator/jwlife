class Media {
  final int mediaId;
  final String? naturalKey;
  final String keySymbol;
  final String categoryKey;
  final int mediaType;
  final int documentId;
  final String mepsLanguage;
  final int issueTagNumber;
  final int track;
  final int bookNumber;
  final String title;
  final int version;
  final String mimeType;
  final num bitRate;
  final num duration;
  final String checkSum;
  final int fileSize;
  final String filePath;
  final int source;
  final String modifiedDateTime;

  String imagePath;

  /* Media */
  String fileUrl = '';
  bool isDownloading = false;
  bool isDownloaded = false;
  double downloadProgress = 0.0;
  List<Marker> markers = [];

  Media({
    required this.mediaId,
    this.naturalKey,
    required this.keySymbol,
    required this.categoryKey,
    required this.imagePath,
    required this.mediaType,
    required this.documentId,
    required this.mepsLanguage,
    required this.issueTagNumber,
    required this.track,
    required this.bookNumber,
    required this.title,
    required this.version,
    required this.mimeType,
    required this.bitRate,
    required this.duration,
    required this.checkSum,
    required this.fileSize,
    required this.filePath,
    required this.source,
    required this.modifiedDateTime,
    this.fileUrl = '',
    this.markers = const [],
    this.isDownloaded = false
  });
}

class Marker {
  final String duration;
  final String startTime;
  int? mepsParagraphId;
  int? verseNumber;

  Marker({
    required this.duration,
    required this.startTime,
    this.mepsParagraphId,
    this.verseNumber
  });

  factory Marker.fromJson(Map<String, dynamic> json) {
    return Marker(
      duration: json['duration'] ?? '',
      startTime: json['startTime'] ?? '',
      verseNumber: json['verseNumber'] ?? -1,
      mepsParagraphId: json['mepsParagraphId'] ?? -1,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'duration': duration,
      'startTime': startTime,
    };

    if (verseNumber != null) {
      data['verseNumber'] = verseNumber;
    }

    if (mepsParagraphId != null) {
      data['mepsParagraphId'] = mepsParagraphId;
    }

    return data;
  }
}