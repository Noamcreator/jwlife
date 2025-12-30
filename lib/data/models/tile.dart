import 'dart:io';

class Tile {
  final String fileName;
  final File file;

  Tile({
    required this.fileName,
    required this.file,
  });

  factory Tile.fromJson(Map<String, dynamic> map) {
    return Tile(
      fileName: map['FileName'] as String,
      file: File(map['FilePath'] as String),
    );
  }
}
