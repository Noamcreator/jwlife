import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'files_helper.dart';

Future<dynamic> getMediaIfDownload(Database db, MediaItem item) async {
  String keySymbol = item.pubSymbol ?? '';
  int documentId = item.documentId ?? 0;
  String mepsLanguage = item.languageSymbol ?? 'E';
  int issueTagNumber = item.issueDate ?? 0;
  int? track = item.track;

  // Requête unique pour récupérer la meilleure vidéo
  final result = await db.rawQuery(
    '''
    SELECT v.*,
    s.FilePath AS SubtitleFilePath
    FROM MediaKey mk
    JOIN Video v ON mk.MediaKeyId = v.MediaKeyId
    JOIN Subtitle s ON v.VideoId = s.VideoId
    WHERE mk.KeySymbol = ? 
      AND mk.MediaType = ? 
      AND mk.DocumentId = ? 
      AND mk.MepsLanguage = ? 
      AND mk.IssueTagNumber = ? 
      AND mk.Track = ?
    ORDER BY v.BitRate DESC 
    LIMIT 1
    ''',
    [
      keySymbol,
      0, // MediaType
      documentId,
      mepsLanguage,
      issueTagNumber,
      track,
    ],
  );

  if (result.isNotEmpty) {
    return result.first;
  }
  return null; // Si aucune vidéo n'est trouvée
}


Future<void> downloadVideoFile(MediaItem item, dynamic video, int file, BuildContext context) async {
  double progress = 0; // Initialiser la progression

  try {
    // Télécharger le fichier vidéo avec mise à jour de la progression
    final response = await Dio().get(
      video['files'][file]['progressiveDownloadURL'],
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          // Calculer la progression
          final newProgress = received / total;
        }
      },
    );

    // Sauvegarder les données du fichier téléchargé
    final bytes = response.data as Uint8List;

    // Obtenir le répertoire "Videos" dans le stockage externe de l'application
    final directory = await getExternalStorageDirectory();
    final videosDirectory = Directory('${directory?.path}/Videos');
    if (!await videosDirectory.exists()) {
      // Créer le dossier "Videos" s'il n'existe pas
      await videosDirectory.create(recursive: true);
    }

    final videoFileName = video['files'][file]['progressiveDownloadURL'].split('/').last;
    final videoFilePath = '${videosDirectory.path}/$videoFileName';

    // Enregistrer le fichier vidéo dans le dossier "Videos"
    await File(videoFilePath).writeAsBytes(bytes);


    final subtitlesDirectory = Directory('${directory?.path}/Subtitles');
    if (!await subtitlesDirectory.exists()) {
      // Créer le dossier "Videos" s'il n'existe pas
      await subtitlesDirectory.create(recursive: true);
    }

    final subtitleFileName = video['files'][file]['subtitles']['url'].split('/').last;
    final subtitleFilePath = '${subtitlesDirectory.path}/$subtitleFileName';

    final subtitleResponse = await Dio().get(video['files'][file]['subtitles']['url'], options: Options(responseType: ResponseType.bytes));
    final subtitleBytes = subtitleResponse.data as Uint8List;

    // Enregistrer le fichier vidéo dans le dossier "Videos"
    await File(subtitleFilePath).writeAsBytes(subtitleBytes);

    // Ouvrir la base de données SQLite
    final mediaCollectionsDbFile = await getMediaCollectionsFile();
    final db = await openDatabase(mediaCollectionsDbFile.path, readOnly: false, version: 1);

    final existingMediaKey = await db.query(
      "MediaKey",
      where: "KeySymbol = ? AND MediaType = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
      whereArgs: [
        item.pubSymbol,
        0, // MediaType
        item.documentId ?? 0,
        item.languageSymbol ?? 'E',
        item.issueDate ?? 0,
        item.track
      ],
    );

    int mediaKeyId;

    if (existingMediaKey.isNotEmpty) {
      // Si un MediaKey existe déjà, récupérer son ID
      mediaKeyId = existingMediaKey.first['MediaKeyId'] as int;
    }
    else {
      // Si aucun MediaKey n'existe, insérer un nouveau MediaKey
      mediaKeyId = await db.insert(
        "MediaKey",
        {
          "KeySymbol": item.pubSymbol,
          "MediaType": 0,
          "DocumentId": item.documentId ?? 0,
          "MepsLanguage": item.languageSymbol ?? 'E',
          "IssueTagNumber": item.issueDate ?? 0,
          "Track": item.track,
          "BookNumber": 0,
        },
      );
    }

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
      },
    );

    // Insérer une ligne dans la table Subtitle
    if(existingMediaKey.isEmpty) {
      await db.insert(
        "Subtitle",
        {
          "VideoId": videoId,
          "Checksum": video['files'][file]['checksum'] ?? '',
          "MepsLanguage": item.languageSymbol ?? 'E',
          "FilePath": subtitleFilePath,
        },
      );
    }

    // Fermer le dialog une fois le téléchargement terminé
    Navigator.of(context, rootNavigator: true).pop();

    print('Video file downloaded successfully: $videoFilePath and $subtitleFilePath');
  }
  catch (e) {
    print('Error downloading video file: $e');
    // Fermer le dialog en cas d'erreur
    Navigator.of(context, rootNavigator: true).pop();
  }
}

Future<void> createDbMediaCollection(Database db) async {
  return await db.transaction((txn) async {
    // Creating tables for audio, video, subtitle, and media key
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS "Audio" (
        "AudioId" INTEGER NOT NULL,
        "MediaKeyId" INTEGER,
        "Title" TEXT,
        "Version" INTEGER,
        "MimeType" TEXT,
        "BitRate" REAL,
        "Duration" REAL,
        "Checksum" TEXT,
        "FileSize" INTEGER,
        "FilePath" TEXT NOT NULL,
        "Source" INTEGER NOT NULL DEFAULT 0,
        "MarkerHash" TEXT,
        PRIMARY KEY("AudioId" AUTOINCREMENT),
        FOREIGN KEY("MediaKeyId") REFERENCES "MediaKey"("MediaKeyId")
      );
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS "AudioMarker" (
        "AudioMarkerId" INTEGER NOT NULL,
        "AudioId" INTEGER NOT NULL,
        "Label" TEXT,
        "Caption" TEXT,
        "StartTimeTicks" INTEGER NOT NULL,
        "DurationTicks" INTEGER NOT NULL,
        "BeginTransitionTicks" INTEGER,
        "EndTransitionTicks" INTEGER,
        "MepsParagraphId" INTEGER,
        "VerseNumber" INTEGER,
        PRIMARY KEY("AudioMarkerId"),
        FOREIGN KEY("AudioId") REFERENCES "Audio"("AudioId")
      );
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS "MediaKey" (
        "MediaKeyId" INTEGER NOT NULL,
        "KeySymbol" TEXT,
        "MediaType" INTEGER NOT NULL,
        "DocumentId" INTEGER NOT NULL DEFAULT -1,
        "MepsLanguage" TEXT NOT NULL,
        "IssueTagNumber" INTEGER NOT NULL DEFAULT -1,
        "Track" INTEGER NOT NULL DEFAULT -1,
        "BookNumber" INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY("MediaKeyId" AUTOINCREMENT)
      );
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS "Subtitle" (
        "SubtitleId" INTEGER NOT NULL,
        "VideoId" INTEGER NOT NULL,
        "Checksum" TEXT NOT NULL,
        "MepsLanguage" TEXT NOT NULL,
        "FilePath" TEXT NOT NULL,
        PRIMARY KEY("SubtitleId"),
        FOREIGN KEY("VideoId") REFERENCES "Video"("VideoId")
      );
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS "Video" (
        "VideoId" INTEGER NOT NULL,
        "MediaKeyId" INTEGER,
        "Title" TEXT,
        "Version" INTEGER,
        "MimeType" TEXT,
        "BitRate" REAL,
        "FrameRate" REAL,
        "Duration" REAL,
        "Checksum" TEXT,
        "FileSize" INTEGER,
        "FrameHeight" INTEGER,
        "FrameWidth" INTEGER,
        "Label" TEXT,
        "SpecialtyDescription" TEXT,
        "FilePath" TEXT NOT NULL,
        "Source" INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY("VideoId" AUTOINCREMENT),
        FOREIGN KEY("MediaKeyId") REFERENCES "MediaKey"("MediaKeyId")
      );
    ''');
  });
}
