import 'dart:io';

import 'package:jwlife/app/services/settings_service.dart';

import '../../../core/utils/directory_helper.dart';
import 'independent_media.dart';
import 'location.dart';

class PlaylistItem {
  int playlistItemId;
  String? label;
  int? startTrimOffsetTicks;
  int? endTrimOffsetTicks;
  int? accuracy = 1;
  int? endAction = JwLifeSettings.instance.playlistEndAction;
  IndependentMedia? thumbnail;
  int? position;
  int? durationTicks;
  int? majorMultimediaType;
  int? baseDurationTicks;
  Location? location;
  IndependentMedia? independentMedia;

  PlaylistItem({
    required this.playlistItemId,
    this.label,
    this.startTrimOffsetTicks,
    this.endTrimOffsetTicks,
    this.accuracy = 1,
    this.endAction = 0,
    this.thumbnail,
    this.position,
    this.durationTicks,
    this.majorMultimediaType,
    this.baseDurationTicks,
    this.location,
    this.independentMedia
  });

  /// Créé une instance Note à partir d'une map (ex: JSON)
  factory PlaylistItem.fromMap(Map<String, dynamic> map) {
    return PlaylistItem(
      playlistItemId: map['PlaylistItemId'],
      label: map['Label'],
      startTrimOffsetTicks: map['StartTrimOffsetTicks'],
      endTrimOffsetTicks: map['EndTrimOffsetTicks'],
      accuracy: map['Accuracy'] ?? 1,
      endAction: map['EndAction'] ?? JwLifeSettings.instance.playlistEndAction,
      thumbnail: IndependentMedia(originalFileName: map['ThumbnailOriginalFileName'], filePath: map['ThumbnailFilePath'], mimeType: map['ThumbnailMimeType'], hash: map['ThumbnailHash']),
      position: map['Position'],
      durationTicks: map['DurationTicks'],
      majorMultimediaType: map['MajorMultimediaType'],
      baseDurationTicks: map['BaseDurationTicks'],
      location: Location.fromMap(map),
      independentMedia: IndependentMedia.fromMap(map),
    );
  }

  Future<File?> getThumbnailFile() async {
    if(thumbnail == null) {
      return null;
    }

    final userDataDir = await getAppUserDataDirectory();
    final fullPath = '${userDataDir.path}/${thumbnail!.filePath}';
    final file = File(fullPath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }
}
