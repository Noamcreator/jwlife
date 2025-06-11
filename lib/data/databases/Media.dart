import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/meps/language.dart';
import 'package:jwlife/modules/bible/views/bible_view.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

class Media {
  final int mediaId;
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
  final int mepsParagraphId;

  Marker({
    required this.duration,
    required this.startTime,
    required this.mepsParagraphId,
  });

  factory Marker.fromJson(Map<String, dynamic> json) {
    return Marker(
      duration: json['duration'] ?? '',
      startTime: json['startTime'] ?? '',
      mepsParagraphId: json['mepsParagraphId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'startTime': startTime,
      'mepsParagraphId': mepsParagraphId,
    };
  }
}