import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../models/publication.dart';
import '../models/tile.dart';

class MediaCollections {
  late Database _database;
  List<Audio> audios = [];
  List<Video> videos = [];

  Future<void> init() async {
    File mediaCollections = await getMediaCollectionsDatabaseFile();
    _database = await openDatabase(mediaCollections.path, version: 1, onCreate: (db, version) async {
      await createDbMediaCollection(db);
    });
    await fetchDownloadMedias();
  }

  Future<void> fetchDownloadMedias() async {
    // Chargement des publications
    //File mepsFile = await getMepsFile();

    //await _database.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

    List<Map<String, dynamic>> audiosResult = await _database.rawQuery('''
      SELECT Audio.*, MediaKey.* FROM Audio
      LEFT JOIN MediaKey ON Audio.MediaKeyId = MediaKey.MediaKeyId
      ''');

    if (audiosResult.isNotEmpty) {
      audios = audiosResult.map((a) => Audio.fromJson(json: a)).toList();
    }

    List<Map<String, dynamic>> videosResult = await _database.rawQuery('''
      SELECT Video.*, MediaKey.* FROM Video
      LEFT JOIN MediaKey ON Video.MediaKeyId = MediaKey.MediaKeyId
      ''');

    if (videosResult.isNotEmpty) {
      videos = videosResult.map((a) => Video.fromJson(json: a)).toList();
    }
  }

  Audio getAudio(Audio a) {
    Audio? audio = audios.firstWhereOrNull((element) => element.keySymbol == a.keySymbol && element.documentId == a.documentId && element.track == a.track);
    if (audio != null) {
      return audio;
    }
    return a;
  }

  Audio? getAudioFromMediaItem(RealmMediaItem mediaItem) {
    String keySymbol = mediaItem.pubSymbol ?? '';
    int documentId = mediaItem.documentId ?? 0;
    String mepsLanguage = mediaItem.languageSymbol ?? JwLifeSettings.instance.currentLanguage.value.symbol;
    int issueTagNumber = mediaItem.issueDate ?? 0;
    int? track = mediaItem.track ?? 0;

    return audios.firstWhereOrNull((element) => element.keySymbol == keySymbol && element.documentId == documentId && element.mepsLanguage == mepsLanguage && element.issueTagNumber == issueTagNumber && element.track == track);
  }

  List<Audio> getAudiosFromPub(Publication publication) {
    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    String mepsLanguage = publication.mepsLanguage.symbol;

    return audios.where((element) => element.keySymbol == keySymbol && element.issueTagNumber == issueTagNumber && element.mepsLanguage == mepsLanguage).toList();
  }

  Video? getVideo(RealmMediaItem mediaItem) {
    String keySymbol = mediaItem.pubSymbol ?? '';
    int documentId = mediaItem.documentId ?? 0;
    String mepsLanguage = mediaItem.languageSymbol ?? JwLifeSettings.instance.currentLanguage.value.symbol;
    int issueTagNumber = mediaItem.issueDate ?? 0;
    int? track = mediaItem.track ?? 0;

    return videos.firstWhereOrNull((element) => element.keySymbol == keySymbol && element.documentId == documentId && element.mepsLanguage == mepsLanguage && element.issueTagNumber == issueTagNumber && element.track == track);
  }

  Future<void> open() async {
    if(!_database.isOpen) {
      File mediaCollections = await getMediaCollectionsDatabaseFile();
      _database = await openDatabase(mediaCollections.path, version: 1);
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
        "ModifiedDateTime" TEXT,
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
        "CategoryKey" TEXT,
        "ImagePath" TEXT,
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
        "ModifiedDateTime" TEXT NOT NULL,
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
        "ModifiedDateTime" TEXT,
        PRIMARY KEY("VideoId" AUTOINCREMENT),
        FOREIGN KEY("MediaKeyId") REFERENCES "MediaKey"("MediaKeyId")
      );
    ''');
    });
  }

  Future<Media?> insertMedia(Media media, {int? file = 0}) async {
    final existingMediaKey = await _database.query(
      "MediaKey",
      where: "KeySymbol = ? AND MediaType = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
      whereArgs: [
        media.keySymbol ?? '',
        media is Audio ? 2 : 1,
        media.documentId ?? 0,
        media.mepsLanguage ?? JwLifeSettings.instance.currentLanguage.value.symbol,
        media.issueTagNumber ?? 0,
        media.track ?? 0,
      ],
    );

    String? imageUrl = media is Audio ? media.networkFullSizeImageSqr : media.networkFullSizeImageLsr;
    String imagePath = '';
    if (imageUrl != null && imageUrl.startsWith('https')) {
      Tile? tile = await TilesCache().getOrDownloadImage(imageUrl);
      imagePath = tile?.file.path ?? '';
    }

    media.imagePath = imagePath;

    int mediaKeyId;
    if (existingMediaKey.isNotEmpty) {
      mediaKeyId = existingMediaKey.first['MediaKeyId'] as int;
    }
    else {
      mediaKeyId = await _database.insert(
        "MediaKey",
        {
          "KeySymbol": media.keySymbol ?? '',
          "CategoryKey": media.categoryKey,
          "ImagePath": imagePath,
          "MediaType": media is Audio ? 2 : 1,
          "DocumentId": media.documentId ?? 0,
          "MepsLanguage": media.mepsLanguage ?? JwLifeSettings.instance.currentLanguage.value.symbol,
          "IssueTagNumber": media.issueTagNumber ?? 0,
          "Track": media.track ?? 0,
          "BookNumber": media.bookNumber ?? 0,
        },
      );
    }

    if (media is Audio) {
      return await insertAudio(media, mediaKeyId);
    }
    else if (media is Video) {
      return await insertVideo(media, file ?? 0, mediaKeyId);
    }
    return null;
  }

  Future<Audio> insertAudio(Audio audio, int mediaKeyId) async {
    // Insérer une ligne dans la table Audio
    await _database.insert(
      "Audio",
      {
        "MediaKeyId": mediaKeyId,
        "Title": audio.title,
        "Version": audio.version,
        "MimeType": audio.mimeType,
        "BitRate": audio.bitRate,
        "Duration": audio.duration,
        "Checksum": audio.checkSum,
        "FileSize": audio.fileSize,
        "FilePath": audio.filePath,
        "Source": audio.source,
        "ModifiedDateTime": audio.lastModified,
      },
    );

    printTime('Audio inserted successfully: ${audio.filePath}');

    return audio;
  }

  Future<Video> insertVideo(Video video, int file, int mediaKeyId) async {
    // Insérer une ligne dans la table Video
    int videoId = await _database.insert(
      "Video",
      {
        "MediaKeyId": mediaKeyId,
        "Title": video.title,
        "Version": video.version,
        "MimeType": video.mimeType,
        "BitRate": video.bitRate,
        "FrameRate": video.frameRate,
        "Duration": video.duration,
        "Checksum": video.checkSum,
        "FileSize": video.fileSize,
        "FrameHeight": video.frameHeight,
        "FrameWidth": video.frameWidth,
        "Label": video.label,
        "SpecialtyDescription": video.specialtyDescription, // à compléter si nécessaire
        "FilePath": video.filePath,
        "Source": video.source,
        "ModifiedDateTime": video.lastModified,
      },
    );

    // Insérer une ligne dans la table Subtitle (si fourni)
    if (video.subtitles != null) {
      await _database.insert(
        "Subtitle",
        {
          "VideoId": videoId,
          "Checksum": video.subtitles!.checkSum,
          "ModifiedDateTime": video.subtitles!.timeStamp,
          "MepsLanguage": video.subtitles!.mepsLanguage,
          "FilePath": video.subtitles!.filePath,
        },
      );
    }

    printTime('Video inserted successfully: ${video.filePath} and ${video.subtitles?.filePath ?? "no subtitle"}');

    return video;
  }

  Future<void> deleteMedia(Media media) async {
    // Récupérer le MediaKeyId avant suppression
    final keyResult = await _database.query(
      "MediaKey",
      columns: ["MediaKeyId"],
      where: "KeySymbol = ? AND MediaType = ? AND DocumentId = ? AND MepsLanguage = ? AND IssueTagNumber = ? AND Track = ?",
      whereArgs: [
        media.keySymbol ?? '',
        media is Audio ? 2 : 1,
        media.documentId ?? 0,
        media.mepsLanguage ?? JwLifeSettings.instance.currentLanguage.value.symbol,
        media.issueTagNumber ?? 0,
        media.track ?? 0,
      ],
    );

    if (keyResult.isEmpty) return; // rien à supprimer

    final mediaKeyId = keyResult.first["MediaKeyId"] as int;

    // Supprimer les dépendances
    if (media is Audio) {
      await _database.delete(
        "Audio",
        where: "MediaKeyId = ?",
        whereArgs: [mediaKeyId],
      );
    } else if (media is Video) {
      await _database.delete(
        "Video",
        where: "MediaKeyId = ?",
        whereArgs: [mediaKeyId],
      );

      await _database.delete(
        "Subtitle",
        where: "VideoId = ?",
        whereArgs: [mediaKeyId],
      );
    }

    // Enfin, supprimer la clé
    await _database.delete(
      "MediaKey",
      where: "MediaKeyId = ?",
      whereArgs: [mediaKeyId],
    );
  }

  Future<void> downloadPubAudioFile(dynamic audio, int mediaKeyId, String audioFilePath, Database db) async {
    // Insérer une ligne dans la table Video
    await db.insert(
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

  Future<void> deletePubAudioFile(int mediaKeyId, Database db) async {
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
}
