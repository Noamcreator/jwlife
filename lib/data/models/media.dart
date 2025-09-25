import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:async/async.dart';
import 'package:jwlife/app/services/settings_service.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/notification_service.dart';
import '../../core/jworg_uri.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils_media.dart';

abstract class Media {
  final int mediaId;
  String? naturalKey;
  String? keySymbol;
  int? documentId;
  int? issueTagNumber;
  int? track;
  int? bookNumber;
  String? mepsLanguage;
  String categoryKey;
  String title;
  int? version;
  String? mimeType;
  double? bitRate;
  double duration;
  String? checkSum;
  int? fileSize;
  String? filePath;
  int? source;
  String? firstPublished;
  String? lastModified;
  String? timeStamp;
  String? imagePath;
  String? networkImageSqr;
  String? networkImageLsr;

  /* Media */
  String? fileUrl;
  CancelableOperation? _downloadOperation;
  CancelableOperation? _updateOperation;
  CancelToken? _cancelToken;

  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isDownloadingNotifier;
  final ValueNotifier<bool> isDownloadedNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;

  Media({
    required this.mediaId,
    this.naturalKey,
    this.keySymbol,
    this.documentId,
    this.mepsLanguage,
    this.issueTagNumber,
    this.track,
    this.bookNumber,
    this.categoryKey = '',
    this.duration = 0.0,
    this.title = '',
    this.version,
    this.mimeType,
    this.bitRate,
    this.imagePath,
    this.networkImageSqr,
    this.networkImageLsr,
    this.checkSum,
    this.fileSize,
    this.filePath,
    this.source,
    this.firstPublished,
    this.lastModified,
    this.timeStamp,
    this.fileUrl,
    ValueNotifier<double>? progressNotifier,
    ValueNotifier<bool>? isDownloadingNotifier,
    ValueNotifier<bool>? isDownloadedNotifier,
    ValueNotifier<bool>? isFavoriteNotifier,
  })  : progressNotifier = progressNotifier ?? ValueNotifier(0.0),
        isDownloadingNotifier = isDownloadingNotifier ?? ValueNotifier(false),
        isDownloadedNotifier = isDownloadedNotifier ?? ValueNotifier(false),
        isFavoriteNotifier = isFavoriteNotifier ?? ValueNotifier(false);

  Future<void> download(BuildContext context);

  Future<void> notifyDownload(String title) async {
    if(JwLifeSettings().notificationDownload) {
      // Notification de fin avec bouton "Ouvrir"
      await NotificationService().showCompletionNotification(
        id: hashCode,
        title: title,
        body: this.title,
        payload: naturalKey != null ? JwOrgUri.mediaItem(
          wtlocale: mepsLanguage!,
          lank: naturalKey!,
        ).toString() : '',
      );
    }
    else {
      BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;
      showBottomMessageWithAction(this.title, SnackBarAction(label: 'Lire', onPressed: () {
        showPlayer(context);
      }));
    }
  }

  Future<void> performDownload(BuildContext context, Map<String, dynamic>? mediaJson, {int? file = 0}) async {
    isDownloadingNotifier.value = true;
    progressNotifier.value = 0;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    _downloadOperation = CancelableOperation.fromFuture(
      downloadMedia(context, this, fileUrl, mediaJson, cancelToken, false, file: file),
      onCancel: () {
        isDownloadingNotifier.value = false;
        isDownloadedNotifier.value = false;
        progressNotifier.value = 0;
        // Annuler la notification
        NotificationService().cancelNotification(hashCode);
      },
    );

    Media? media = await _downloadOperation!.valueOrCancellation();

    if (media != null) {
      isDownloadedNotifier.value = true;
      progressNotifier.value = 1.0;

      notifyDownload('Téléchargement terminé');
    }
    else {
      // Téléchargement annulé ou échoué
      await NotificationService().cancelNotification(hashCode);
    }

    isDownloadingNotifier.value = false;
  }

  Future<void> cancelDownload(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _downloadOperation != null) {
      _cancelToken!.cancel();
      _downloadOperation!.cancel();
      _cancelToken = null;
      _downloadOperation = null;
      showBottomMessage('Téléchargement annulé');
    }
  }

  Future<void> update(BuildContext context, Map<String, dynamic> mediaJson) async {
    progressNotifier.value = -1;
    isDownloadingNotifier.value = true;
    isDownloadedNotifier.value = false;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    _updateOperation = CancelableOperation.fromFuture(
      downloadMedia(context, this, fileUrl, mediaJson, cancelToken, true, file: 0), // TODO mettre le bon file pour la mise à jour
      onCancel: () {
        isDownloadingNotifier.value = false;
        isDownloadedNotifier.value = false;
        progressNotifier.value = 0;
        // Annuler la notification
        NotificationService().cancelNotification(hashCode);
      },
    );

    Media? media = await _updateOperation!.valueOrCancellation();

    if (media != null) {
      isDownloadedNotifier.value = true;

      progressNotifier.value = 1.0;

      // Notification de fin avec bouton "Ouvrir"
      notifyDownload('Mise à jour terminée');
    }
    else {
      // Téléchargement annulé ou échoué
      await NotificationService().cancelNotification(hashCode);
    }

    isDownloadingNotifier.value = false;
  }

  Future<void> cancelUpdate(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _updateOperation != null) {
      _cancelToken!.cancel();
      _updateOperation!.cancel();
      _cancelToken = null;
      _updateOperation = null;
      showBottomMessage('Mis à jour annulée');
    }
  }

  Future<void> remove(BuildContext context) async {
    progressNotifier.value = -1;
    await removeMedia(this);

    imagePath = null;
    filePath = null;
    isDownloadingNotifier.value = false;
    isDownloadedNotifier.value = false;
    progressNotifier.value = 0;

    showBottomMessage('Media supprimé');
  }

  Future<void> showPlayer(BuildContext context, {Duration initialPosition = Duration.zero});

  bool hasUpdate() {
    if (lastModified == null || timeStamp == null) {
      return false;
    }

    DateTime lastModDate = DateTime.parse(lastModified!);
    DateTime pubDate = DateTime.parse(timeStamp!);

    if (lastModDate.isAtSameMomentAs(pubDate)) {
      return false;
    }

    return lastModDate.isAfter(pubDate);
  }
}