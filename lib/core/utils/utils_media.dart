import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../app/services/settings_service.dart';
import '../api.dart';
import 'files_helper.dart';

Future<dynamic> getVideoIfDownload(Database db, MediaItem item) async {
  String keySymbol = item.pubSymbol ?? '';
  int documentId = item.documentId ?? 0;
  String mepsLanguage = item.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;
  int issueTagNumber = item.issueDate ?? 0;
  int? track = item.track ?? 0;

  // Requête unique pour récupérer la meilleure vidéo
  final result = await db.rawQuery(
    '''
    SELECT *,
    Subtitle.FilePath AS SubtitleFilePath
    FROM MediaKey
    LEFT JOIN Video ON MediaKey.MediaKeyId = Video.MediaKeyId
    LEFT JOIN Subtitle ON Video.VideoId = Subtitle.VideoId
    WHERE MediaKey.KeySymbol = ? 
      AND MediaKey.DocumentId = ? 
      AND MediaKey.MepsLanguage = ? 
      AND MediaKey.IssueTagNumber = ? 
      AND MediaKey.Track = ?
    ORDER BY Video.BitRate DESC 
    LIMIT 1
    ''',
    [
      keySymbol,
      documentId,
      mepsLanguage,
      issueTagNumber,
      track,
    ],
  );

  await db.close();

  if (result.isNotEmpty) {
    return result.first;
  }
  return null; // Si aucune vidéo n'est trouvée
}

Future<void> downloadAudio(BuildContext context, String? pubSymbol, int? issueTagNumber, int? documentId, int? track, String? mepsLanguage, String imageUrl, dynamic media) async {
  double progress = 0; // Initialiser la progression

  try {
    // Télécharger le fichier avec mise à jour de la progression
    final response = await Dio().get(media['file']['url'],
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          progress = received / total;
        }
      },
    );

    // Sauvegarder les données du fichier téléchargé
    final bytes = response.data as Uint8List;

    // Obtenir le répertoire de stockage externe
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception("Impossible d'obtenir le répertoire de stockage externe.");
    }

    final mediasDirectory = Directory('${directory.path}/Audios');
    if (!await mediasDirectory.exists()) {
      await mediasDirectory.create(recursive: true);
    }

    final mediaFileName = media['file']['url'].split('/').last;
    final mediaFilePath = '${mediasDirectory.path}/$mediaFileName';

    // Enregistrer le fichier
    await File(mediaFilePath).writeAsBytes(bytes);

    // Ouvrir la base de données SQLite
    final mediaCollectionsDbFile = await getMediaCollectionsDatabaseFile();
    final db = await openDatabase(mediaCollectionsDbFile.path, version: 1);

    try {
      final existingMediaKey = await db.query(
        "MediaKey",
        where: "KeySymbol = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
        whereArgs: [
          pubSymbol ?? '',
          documentId ?? 0,
          mepsLanguage ?? JwLifeSettings().currentLanguage.symbol,
          issueTagNumber ?? 0,
          track ?? 0,
        ],
      );

      String imagePath = '';
      if (imageUrl.startsWith('https')) {
        File tileCacheFile = await getTilesDatabaseFile();
        Database database = await openDatabase(tileCacheFile.path);
        final List<Map<String, dynamic>> result = await database.query(
          'TilesCache',
          where: 'FileName = ?',
          whereArgs: [basename(imageUrl)],
        );
        await database.close();
        imagePath = result.isNotEmpty ? result.first['FilePath'] as String : '';
      }

      int mediaKeyId;
      if (existingMediaKey.isNotEmpty) {
        mediaKeyId = existingMediaKey.first['MediaKeyId'] as int;
      }
      else {
        mediaKeyId = await db.insert(
          "MediaKey",
          {
            "KeySymbol": pubSymbol ?? '',
            "CategoryKey": '',
            "ImagePath": imagePath,
            "MediaType": 0,
            "DocumentId": documentId ?? 0,
            "MepsLanguage": mepsLanguage ?? JwLifeSettings().currentLanguage.symbol,
            "IssueTagNumber": issueTagNumber ?? 0,
            "Track": track ?? 0,
            "BookNumber": 0,
          },
        );
      }

      await downloadPubAudioFile(context, media, mediaKeyId, mediaFilePath, db);

      showBottomMessageWithAction(context, 'Audio « ${media['title']} » a été téléchargée',
          SnackBarAction(
              label: 'Lire',
              textColor: Theme.of(context).primaryColor,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                //showAudioPlayer(context, item);
              }
          ));
    }
    finally {
      await db.close(); // Assurez-vous de fermer la base de données après usage
    }
  }
  catch (e) {
    printTime('Erreur lors du téléchargement du fichier média : $e');
  }
}

Future<void> deleteAudio(BuildContext context, String? pubSymbol, int? issueTagNumber, int? documentId, int? track, String? mepsLanguage) async {
  // Ouvrir la base de données SQLite
  final mediaCollectionsDbFile = await getMediaCollectionsDatabaseFile();
  final db = await openDatabase(mediaCollectionsDbFile.path, version: 1);

  try {
    final existingMediaKey = await db.query(
      "MediaKey",
      where: "KeySymbol = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
      whereArgs: [
        pubSymbol ?? '',
        documentId ?? 0,
        mepsLanguage ?? JwLifeSettings().currentLanguage.symbol,
        issueTagNumber ?? 0,
        track ?? 0,
      ],
    );

    if (existingMediaKey.isNotEmpty) {
      int mediaKeyId = existingMediaKey.first['MediaKeyId'] as int;

      await deletePubAudioFile(context, mediaKeyId, db);

      showBottomMessage(context, 'Audio « $documentId » a été supprimé');
    }
  }
  finally {
    await db.close(); // Assurez-vous de fermer la base de données après usage
  }
}

Future<void> downloadMedia(BuildContext context, MediaItem item, dynamic media, {int? file = 0}) async {
  double progress = 0; // Initialiser la progression

  try {
    // Télécharger le fichier avec mise à jour de la progression
    final response = await Dio().get(media['files'][file]['progressiveDownloadURL'],
      options: Options(
        headers: Api.getHeaders(),
        responseType: ResponseType.bytes,
        followRedirects: true
      ),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          progress = received / total;
        }
      },
    );

    // Sauvegarder les données du fichier téléchargé
    final bytes = response.data as Uint8List;

    // Obtenir le répertoire de stockage externe
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception("Impossible d'obtenir le répertoire de stockage externe.");
    }

    final mediasDirectory = Directory('${directory.path}/${item.type == 'AUDIO' ? 'Audios' : 'Videos'}');
    if (!await mediasDirectory.exists()) {
      await mediasDirectory.create(recursive: true);
    }

    final mediaFileName = media['files'][file]['progressiveDownloadURL'].split('/').last;
    final mediaFilePath = '${mediasDirectory.path}/$mediaFileName';

    // Enregistrer le fichier
    await File(mediaFilePath).writeAsBytes(bytes);

    String subtitleFilePath = '';
    if (item.type == 'VIDEO' && media['files'][file]['subtitles'] != null) {
      final subtitlesDirectory = Directory('${directory.path}/Subtitles');
      if (!await subtitlesDirectory.exists()) {
        await subtitlesDirectory.create(recursive: true);
      }

      final subtitleFileName = media['files'][file]['subtitles']['url'].split('/').last;
      subtitleFilePath = '${subtitlesDirectory.path}/$subtitleFileName';

      final subtitleResponse = await Dio().get(
        media['files'][file]['subtitles']['url'],
        options: Options(responseType: ResponseType.bytes),
      );

      final subtitleBytes = subtitleResponse.data as Uint8List;
      await File(subtitleFilePath).writeAsBytes(subtitleBytes);
    }

    // Ouvrir la base de données SQLite
    final mediaCollectionsDbFile = await getMediaCollectionsDatabaseFile();
    final db = await openDatabase(mediaCollectionsDbFile.path, version: 1);

    try {
      final existingMediaKey = await db.query(
        "MediaKey",
        where: "KeySymbol = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
        whereArgs: [
          item.pubSymbol ?? '',
          item.documentId ?? 0,
          item.languageSymbol ?? JwLifeSettings().currentLanguage.symbol,
          item.issueDate ?? 0,
          item.track ?? 0,
        ],
      );

      String? imageUrl = item.type == 'AUDIO' ? item.realmImages!.squareImageUrl! : item.realmImages?.wideFullSizeImageUrl ?? item.realmImages?.wideImageUrl ?? item.realmImages?.squareImageUrl;
      String imagePath = '';
      if (imageUrl != null && imageUrl.startsWith('https')) {
        File tileCacheFile = await getTilesDatabaseFile();
        Database database = await openDatabase(tileCacheFile.path);
        final List<Map<String, dynamic>> result = await database.query(
          'TilesCache',
          where: 'FileName = ?',
          whereArgs: [basename(imageUrl)],
        );
        await database.close();
        imagePath = result.isNotEmpty ? result.first['FilePath'] as String : '';
      }

      int mediaKeyId;
      if (existingMediaKey.isNotEmpty) {
        mediaKeyId = existingMediaKey.first['MediaKeyId'] as int;
      }
      else {
        mediaKeyId = await db.insert(
          "MediaKey",
          {
            "KeySymbol": item.pubSymbol ?? '',
            "CategoryKey": item.primaryCategory ?? '',
            "ImagePath": imagePath,
            "MediaType": 0,
            "DocumentId": item.documentId ?? 0,
            "MepsLanguage": item.languageSymbol ?? JwLifeSettings().currentLanguage.symbol,
            "IssueTagNumber": item.issueDate ?? 0,
            "Track": item.track ?? 0,
            "BookNumber": 0,
          },
        );
      }

      if (item.type == 'AUDIO') {
        await downloadAudioFile(context, item, mediaKeyId, mediaFilePath, db);

        showBottomMessageWithAction(context, 'Audio « ${item.title} » a été téléchargée',
            SnackBarAction(
                label: 'Lire',
                textColor: Theme.of(context).primaryColor,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  showAudioPlayer(context, item);
                }
            ));
      }
      else if (item.type == 'VIDEO') {
        await downloadVideoFile(context, item, media, file ?? 0, mediaKeyId, mediaFilePath, subtitleFilePath, db);

        showBottomMessageWithAction(context, 'Vidéo « ${item.title} » a été téléchargée',
            SnackBarAction(
                label: 'Lire',
                textColor: Theme.of(context).primaryColor,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  showFullScreenVideo(context, item);
                }
            ));
      }
    }
    finally {
      await db.close(); // Assurez-vous de fermer la base de données après usage
      if(item.type == 'VIDEO') {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
  catch (e) {
    printTime('Erreur lors du téléchargement du fichier média : $e');
    if(item.type == 'VIDEO') {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

Future<void> downloadPubAudioFile(BuildContext context, dynamic audio, int mediaKeyId, String audioFilePath, Database db) async {
  // Insérer une ligne dans la table Video
  int audioId = await db.insert(
    "Audio",
    {
      "MediaKeyId": mediaKeyId,
      "Title": audio['title'],
      "Version": 0, // Remplacer par la version si nécessaire
      "MimeType": audio['mimetype'] ?? '',
      "BitRate": audio['bitRate'] ?? 0,
      "Duration": audio['duration'] ?? 0,
      "Checksum": audio['file']['checksum'] ?? '',
      "FileSize": audio['filesize'] ?? 0,
      "FilePath": audioFilePath,
      "Source": 0,
      "ModifiedDateTime": audio['file']['modifiedDatetime'] ?? "",
    },
  );
  printTime('Audio file downloaded successfully: $audioFilePath');
}

Future<void> deletePubAudioFile(BuildContext context, int mediaKeyId, Database db) async {
  await db.delete(
    "MediaKey",
    where: "MediaKeyId = ?",
    whereArgs: [mediaKeyId],
  );

  int audioId = await db.delete(
    "Audio",
    where: "MediaKeyId = ?",
    whereArgs: [mediaKeyId],
  );

  await db.delete(
    "AudioMarker",
    where: "AudioId = ?",
    whereArgs: [audioId],
  );

  printTime('Audio file deleted successfully');
}

Future<void> downloadAudioFile(BuildContext context, dynamic audio, int mediaKeyId, String audioFilePath, Database db) async {
  // Insérer une ligne dans la table Video
  int audioId = await db.insert(
  "Audio",
    {
      "MediaKeyId": mediaKeyId,
      "Title": audio['title'],
      "Version": 0, // Remplacer par la version si nécessaire
      "MimeType": audio['files'][0]['mimetype'] ?? '',
      "BitRate": audio['files'][0]['bitRate'] ?? 0,
      "Duration": audio['files'][0]['duration'] ?? 0,
      "Checksum": audio['files'][0]['checksum'] ?? '',
      "FileSize": audio['files'][0]['filesize'] ?? 0,
      "FilePath": audioFilePath,
      "Source": 0,
      "ModifiedDateTime": audio['files'][0]['modifiedDatetime'] ?? "",
    },
  );

  /*
  // Insérer une ligne dans la table Subtitle
  if(subtitleFilePath.isNotEmpty) {
    await db.insert(
      "AudioMarker",
      {
        "AudioId": audioId,
        "Label": '',
        "Caption": '',
        "StartTimeTicks": 0,
        "DurationTicks": 0,
        "BeginTransitionTicks": 0,
        "EndTransitionTicks": 0,
        "MepsParagraphId": 0,
        "VerseNumber": 0,
      },
    );
  }

   */

  printTime('Audio file downloaded successfully: $audioFilePath');
}


Future<void> downloadVideoFile(BuildContext context, MediaItem item, dynamic video, int file, int mediaKeyId, String videoFilePath, String subtitleFilePath, Database db) async {
  // Insérer une ligne dans la table Video
  int videoId = await db.insert(
    "Video",
    {
      "MediaKeyId": mediaKeyId,
      "Title": video['title'],
      "Version": 0, // Remplacer par la version si nécessaire
      "MimeType": video['files'][file]['mimetype'] ?? '',
      "BitRate": video['files'][file]['bitRate'] ?? 0,
      "FrameRate": video['files'][file]['frameRate'] ?? 0,
      "Duration": video['files'][file]['duration'] ?? 0,
      "Checksum": video['files'][file]['checksum'] ?? '',
      "FileSize": video['files'][file]['filesize'] ?? 0,
      "FrameHeight": video['files'][file]['frameHeight'] ?? 0,
      "FrameWidth": video['files'][file]['frameWidth'] ?? 0,
      "Label": video['files'][file]['label'] ?? '',
      "SpecialtyDescription": "", // Remplacer par la description
      "FilePath": videoFilePath,
      "Source": 0,
      "ModifiedDateTime": video['files'][file]['modifiedDatetime'] ?? "",
    },
  );

  // Insérer une ligne dans la table Subtitle
  if(subtitleFilePath.isNotEmpty) {
    await db.insert(
      "Subtitle",
      {
        "VideoId": videoId,
        "Checksum": video['files'][file]['subtitles']['checksum'] ?? '',
        "ModifiedDateTime": video['files'][file]['subtitles']['modifiedDatetime'] ?? 0,
        "MepsLanguage": item.languageSymbol,
        "FilePath": subtitleFilePath,
      },
    );
  }

  printTime('Video file downloaded successfully: $videoFilePath and $subtitleFilePath');
}

Future<void> removeMedia(MediaItem item) async {
  // Ouvrir la base de données SQLite
  final mediaCollectionsDbFile = await getMediaCollectionsDatabaseFile();
  final db = await openDatabase(mediaCollectionsDbFile.path, version: 1);

  await db.delete(
    "MediaKey",
    where: "KeySymbol = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
    whereArgs: [
      item.pubSymbol ?? '',
      item.documentId ?? 0,
      item.languageSymbol ?? JwLifeSettings().currentLanguage.symbol,
      item.issueDate ?? 0,
      item.track ?? 0,
    ],
  );

  await db.close(); // Assurez-vous de fermer la base de données après usage
}