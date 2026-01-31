import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/media.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../app/jwlife_app.dart';
import '../../data/models/audio.dart';
import '../../data/models/video.dart';
import '../api/api.dart';

Future<Media?> downloadMedia(BuildContext context, Media media, String? fileUrl, List<dynamic>? mediasFilesData, CancelToken cancelToken, bool update, {int? resolution = 0}) async {
  Api.dio.interceptors.clear();

  double lastProgress = 0.0;

  try {
    // Télécharger le fichier avec mise à jour de la progression
    final responseMedia = await Api.dio.get(fileUrl ?? mediasFilesData?[resolution ?? 0]['progressiveDownloadURL'],
      options: Options(
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          double progress = received / total;

          // Mise à jour seulement si +5% depuis la dernière update
          if (progress - lastProgress >= 0.02 || progress == 1.0) {
            lastProgress = progress;
            media.progressNotifier.value = progress;
          }
        }
      },
      cancelToken: cancelToken,
    );

    media.progressNotifier.value = -1;

    if(responseMedia.statusCode != 200) {
      media.progressNotifier.value = 0.0;
      throw Exception('Erreur lors du téléchargement du fichier média');
    }

    return await mediaCopy(responseMedia.data!, fileUrl, mediasFilesData, media, update: update, resolution: resolution);
  }
  catch (e) {
    printTime('Erreur lors du téléchargement du fichier média : $e');

    return null;
  }
}

Future<Media?> mediaCopy(Uint8List bytes, String? fileUrl, List<dynamic>? mediasFilesData, Media media, {bool update = false, int? resolution = 0}) async {
  if(update) {
    await removeMedia(media);
  }

  // Obtenir le répertoire de stockage externe
  final directory = await getExternalStorageDirectory();
  if (directory == null) {
    throw Exception("Impossible d'obtenir le répertoire de stockage externe.");
  }

  final mediasDirectory = Directory('${directory.path}/${media is Audio ? 'Audios' : 'Videos'}');
  if (!await mediasDirectory.exists()) {
    await mediasDirectory.create(recursive: true);
  }

  final mediaFileName = (fileUrl ?? mediasFilesData?[resolution ?? 0]['progressiveDownloadURL']).split('/').last;
  final mediaFilePath = '${mediasDirectory.path}/$mediaFileName';

  // Enregistrer le fichier
  await File(mediaFilePath).writeAsBytes(bytes);

  String subtitleFilePath = '';
  if (media is Video && mediasFilesData != null) {
    if(mediasFilesData[resolution ?? 0]['subtitles'] != null) {
      final subtitlesDirectory = Directory('${directory.path}/Subtitles');
      if (!await subtitlesDirectory.exists()) {
        await subtitlesDirectory.create(recursive: true);
      }

      final subtitleFileName = mediasFilesData[resolution ?? 0]['subtitles']['url'].split('/').last;
      subtitleFilePath = '${subtitlesDirectory.path}/$subtitleFileName';

      final subtitleResponse = await Api.dio.get(
        mediasFilesData[resolution ?? 0]['subtitles']['url'],
        options: Options(responseType: ResponseType.bytes),
      );

      final subtitleBytes = subtitleResponse.data as Uint8List;
      await File(subtitleFilePath).writeAsBytes(subtitleBytes);
    }
  }

  printTime('Fichiers copié dans : $mediaFilePath');

  media.filePath = mediaFilePath;

  if(mediasFilesData != null) {
    dynamic fileMap = mediasFilesData[resolution ?? 0];

    media.title = mediasFilesData[resolution ?? 0]['title'] ?? media.title;
    media.version = 1;
    media.mimeType = fileMap['mimetype'] ?? '';
    media.bitRate = fileMap['bitRate'] ?? 0;
    media.duration = fileMap['duration'] ?? 0;
    media.checkSum = fileMap['checksum'] ?? '';
    media.fileSize = fileMap['filesize'] ?? 0;
    media.lastModified = fileMap['modifiedDatetime'];
    media.fileUrl = fileUrl ?? fileMap['progressiveDownloadURL'];
    media.source = 0;
    if(media is Video) {
      media.frameRate = fileMap['frameRate'] ?? 0;
      media.frameHeight = fileMap['frameHeight'] ?? 0;
      media.frameWidth = fileMap['frameWidth'] ?? 0;
      media.label = fileMap['label'] ?? '';
      media.specialtyDescription = fileMap['specialtyDescription'];

      if(mediasFilesData[resolution ?? 0]['subtitles'] != null) {
        media.subtitles = Subtitles(
          checkSum: fileMap['subtitles']['checksum'],
          timeStamp: fileMap['subtitles']['modifiedDatetime'],
          mepsLanguage: media.mepsLanguage,
          filePath: subtitleFilePath,
        );
      }
    }
  }

  return await JwLifeApp.mediaCollections.insertMedia(media, file: resolution);
}

Future<void> removeMedia(Media media) async {
  File file = File(media.filePath!);
  if (await file.exists()) {
    try {
      await file.delete(); // Delete media file
    }
    catch (e) {
      printTime('Error while deleting directory ${file.path}: $e');
    }
  }
  else {
    printTime('File ${file.path} does not exist.');
  }

  // On enlève aussi les fichiers de sous-titres
  if (media is Video && media.subtitlesFilePath != null) {
    final subtitlesFile = File(media.subtitlesFilePath!);
    if (await subtitlesFile.exists()) {
      try {
        await subtitlesFile.delete(); // Delete subtitle file
      }
      catch (e) {
        printTime('Error while deleting subtitle file ${subtitlesFile.path}: $e');
      }
    }
  }

  await JwLifeApp.mediaCollections.deleteMedia(media);
}