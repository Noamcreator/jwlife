import 'dart:io';

import 'package:jwlife/data/models/userdata/tag.dart';

import '../../../core/utils/directory_helper.dart';

class Playlist extends Tag {
  String? thumbnailFilePath;
  Playlist({required super.id, required super.type, required super.name, this.thumbnailFilePath});

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['TagId'],
      type: map['Type'] ?? 2,
      name: map['Name'],
      thumbnailFilePath: map['ThumbnailFilePath'],
    );
  }

  Future<File?> getThumbnailFile() async {
    if (thumbnailFilePath == null || thumbnailFilePath!.isEmpty) {
      return null;
    }

    final userDataDir = await getAppUserDataDirectory();
    final fullPath = '${userDataDir.path}/$thumbnailFilePath';
    final file = File(fullPath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }
}
