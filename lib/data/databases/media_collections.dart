import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../models/publication.dart';

class MediaCollections {
  late Database _database;
  List<Audio> audios = [];
  List<Video> videos = [];

  Future<void> init() async {
    File mediaCollections = await getMediaCollectionsFile();
    _database = await openDatabase(mediaCollections.path, version: 1);
    await fetchDownloadMedias();
  }

  void clearMedias() {
    videos.clear();
    audios.clear();
  }

  Future<void> fetchDownloadMedias() async {
    clearMedias();

    // Chargement des publications
    //File mepsFile = await getMepsFile();

    //await _database.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

    List<Map<String, dynamic>> audiosResult = await _database.rawQuery('''
      SELECT Audio.*, MediaKey.* FROM Audio
      LEFT JOIN MediaKey ON Audio.MediaKeyId = MediaKey.MediaKeyId
      ''');

    if (audiosResult.isNotEmpty) {
      audios = audiosResult.map((a) => Audio.fromJson(a)).toList();
    }

    List<Map<String, dynamic>> videosResult = await _database.rawQuery('''
      SELECT Video.*, MediaKey.* FROM Video
      LEFT JOIN MediaKey ON Video.MediaKeyId = MediaKey.MediaKeyId
      ''');

    if (videosResult.isNotEmpty) {
      videos = videosResult.map((a) => Video.fromJson(a)).toList();
    }

    //_database.execute("DETACH DATABASE meps");
  }

  Audio getAudio(Audio a) {
    Audio? audio = audios.firstWhereOrNull((element) => element.keySymbol == a.keySymbol && element.documentId == a.documentId && element.track == a.track);
    if (audio != null) {
      return audio;
    }
    return a;
  }

  Audio? getAudioFromMediaItem(MediaItem mediaItem) {
    String keySymbol = mediaItem.pubSymbol ?? '';
    int documentId = mediaItem.documentId ?? 0;
    String mepsLanguage = mediaItem.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;
    int issueTagNumber = mediaItem.issueDate ?? 0;
    int? track = mediaItem.track ?? 0;

    return audios.firstWhereOrNull((element) => element.keySymbol == keySymbol && element.documentId == documentId && element.mepsLanguage == mepsLanguage && element.issueTagNumber == issueTagNumber && element.track == track);
  }

  List<Audio> getAudiosFromCategory(Category category) {
    return audios.where((element) => element.categoryKey == category.key).toList();
  }

  List<Audio> getAudiosFromPub(Publication publication) {
    String keySymbol = publication.keySymbol;
    int issueTagNumber = publication.issueTagNumber;
    String mepsLanguage = publication.mepsLanguage.symbol;

    return audios.where((element) => element.keySymbol == keySymbol && element.issueTagNumber == issueTagNumber && element.mepsLanguage == mepsLanguage).toList();
  }

  Video? getVideo(MediaItem mediaItem) {
    String keySymbol = mediaItem.pubSymbol ?? '';
    int documentId = mediaItem.documentId ?? 0;
    String mepsLanguage = mediaItem.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;
    int issueTagNumber = mediaItem.issueDate ?? 0;
    int? track = mediaItem.track ?? 0;

    return videos.firstWhereOrNull((element) => element.keySymbol == keySymbol && element.documentId == documentId && element.mepsLanguage == mepsLanguage && element.issueTagNumber == issueTagNumber && element.track == track);
  }

  Future<void> open() async {
    if(!_database.isOpen) {
      File mediaCollections = await getMediaCollectionsFile();
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
}
