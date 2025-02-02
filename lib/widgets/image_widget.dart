import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ImageCachedWidget extends StatefulWidget {
  final String? imageUrl;
  final String pathNoImage;
  final double width;
  final double height;

  const ImageCachedWidget({
    super.key,
    required this.imageUrl,
    required this.pathNoImage,
    this.height = 60,
    this.width = 60,
  });

  @override
  _ImageCachedWidgetState createState() => _ImageCachedWidgetState();
}

class _ImageCachedWidgetState extends State<ImageCachedWidget> {
  late Future<File?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _getOrDownloadImage();
  }

  @override
  void didUpdateWidget(covariant ImageCachedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'URL a changé, recharger l'image
    if (widget.imageUrl != oldWidget.imageUrl) {
      _imageFuture = _getOrDownloadImage();
    }
  }

  Future<String?> _getImagePathFromDatabase(Database database, String imageUrl, String filename) async {
    if (imageUrl.startsWith('https')) {
      final List<Map<String, dynamic>> result = await database.query(
        'TilesCache',
        where: 'FileName = ?',
        whereArgs: [filename],
      );
      return result.isNotEmpty ? result.first['FilePath'] as String : null;
    }
    else if (imageUrl.isNotEmpty) {
      return imageUrl;
    }
    return null;
  }

  Future<void> _addImageToDatabase(Database database, String filename, String path) async {
    await database.insert(
      'TilesCache',
      {'FileName': filename, 'FilePath': path},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<File> _downloadImage(database, String imageUrl, String filename) async {
    final directory = await getAppTileDirectory();

    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await _addImageToDatabase(database, filename, file.path);
      return file;
    }
    else {
      throw Exception('Erreur lors du téléchargement de l\'image : ${response.statusCode}');
    }
  }

  Future<File?> _getOrDownloadImage() async {
    File? imageFile;
    if (widget.imageUrl != null) {
      final filename = basename(widget.imageUrl!);
      final directory = await getTilesDbFile();
      final database = await openDatabase(directory.path);
      final existingPath = await _getImagePathFromDatabase(database, widget.imageUrl!, filename);

      if (existingPath != null) {
        imageFile = File(existingPath);
      }
      else {
        imageFile = await _downloadImage(database, widget.imageUrl!, filename);
      }
    }
    return imageFile;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _imageFuture, // Utilisation de _imageFuture pour éviter de relancer la tâche
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/${widget.pathNoImage}_gray.png'
                : 'assets/images/${widget.pathNoImage}.png',
            height: widget.height,
            width: widget.width,
            fit: BoxFit.cover,
          );
        }
        else if (snapshot.hasError || snapshot.data == null) {
          return Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/${widget.pathNoImage}_gray.png'
                : 'assets/images/${widget.pathNoImage}.png',
            height: widget.height,
            width: widget.width,
            fit: BoxFit.cover,
          );
        }
        else {
          return Image.file(
            snapshot.data!,
            height: widget.height,
            width: widget.width,
            fit: BoxFit.cover,
          );
        }
      },
    );
  }
}
