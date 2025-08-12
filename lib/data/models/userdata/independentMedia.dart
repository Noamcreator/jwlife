import 'dart:io';

import '../../../core/utils/directory_helper.dart';

class IndependentMedia {
  final String? originalFileName;
  final String? filePath;
  final String? mimeType;
  final String? hash;

  IndependentMedia({
    this.originalFileName,
    this.filePath,
    this.mimeType,
    this.hash,
  });

  factory IndependentMedia.fromMap(Map<String, dynamic> map) {
    return IndependentMedia(
      originalFileName: map['OriginalFileName'],
      filePath: map['FilePath'],
      mimeType: map['MimeType'],
      hash: map['Hash'],
    );
  }

  Future<File> getImageFile() async {
    Directory userDataDir = await getAppUserDataDirectory();
    String fullPath = '${userDataDir.path}/$filePath';
    return File(fullPath);
  }

  bool isNull() => originalFileName == null && filePath == null && mimeType == null && hash == null;
}
