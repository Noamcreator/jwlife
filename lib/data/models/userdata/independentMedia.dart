import 'dart:io';

import '../../../core/utils/directory_helper.dart';

class IndependentMedia {
  String? originalFileName;
  String? filePath;
  String? mimeType;
  String? hash;

  IndependentMedia({
    this.originalFileName,
    this.filePath,
    this.mimeType,
    this.hash,
  });

  factory IndependentMedia.fromMap(Map<String, dynamic> map) {
    return IndependentMedia(
      originalFileName: map['OriginalFilename'],
      filePath: map['FilePath'],
      mimeType: map['MimeType'],
      hash: map['Hash'],
    );
  }

  Future<File> getMediaFile() async {
    Directory userDataDir = await getAppUserDataDirectory();
    String fullPath = '${userDataDir.path}/$filePath';
    return File(fullPath);
  }

  Future<bool> removeMediaFile() async {
    if (filePath == null) return false;

    try {
      Directory userDataDir = await getAppUserDataDirectory();
      String fullPath = '${userDataDir.path}/$filePath';
      final file = File(fullPath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la suppression du fichier : $e');
      return false;
    }
  }


  bool isNull() => originalFileName == null && filePath == null && mimeType == null && hash == null;
}
