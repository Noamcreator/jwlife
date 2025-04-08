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
  final double? width;
  final double? height;
  final BoxFit fit;

  const ImageCachedWidget({
    super.key,
    required this.imageUrl,
    this.pathNoImage = 'pub_type_placeholder',
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  _ImageCachedWidgetState createState() => _ImageCachedWidgetState();
}

class _ImageCachedWidgetState extends State<ImageCachedWidget> {
  late Future<File?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = ImageDatabase.getOrDownloadImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant ImageCachedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'URL a changé, recharger l'image
    if (widget.imageUrl != oldWidget.imageUrl) {
      _imageFuture = ImageDatabase.getOrDownloadImage(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _imageFuture, // Utilisation de _imageFuture pour éviter de relancer la tâche
      builder: (context, snapshot) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Image.asset(
            isDark ? 'assets/images/${widget.pathNoImage}_gray.png' : 'assets/images/${widget.pathNoImage}.png',
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
          );
        }
        else if (snapshot.hasError || snapshot.data == null) {
          return Image.asset(
            isDark ? 'assets/images/${widget.pathNoImage}_gray.png' : 'assets/images/${widget.pathNoImage}.png',
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
          );
        }
        else {
          return Image.file(
            snapshot.data!,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
          );
        }
      },
    );
  }
}

class ImageDatabase {
  static Future<String?> getImagePathFromDatabase(Database database, String imageUrl, String filename) async {
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

  static void addImageToDatabase(Database database, String filename, String path) {
    database.insert(
      'TilesCache',
      {'FileName': filename, 'FilePath': path},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<File> downloadImage(Database database, String imageUrl, String filename) async {
    final directory = await getAppTileDirectory();
    final file = File('${directory.path}/$filename');

    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);

      // Vérifier que le fichier a bien été écrit
      if (await file.exists()) {
        addImageToDatabase(database, filename, file.path);
        return file;
      }
      else {
        throw Exception('Échec de la sauvegarde de l\'image sur le stockage local.');
      }
    } else {
      throw Exception('Erreur lors du téléchargement de l\'image : ${response.statusCode}');
    }
  }

  static Future<File?> getOrDownloadImage(String? imageUrl) async {
    File? imageFile;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('https')) {
        final filename = basename(imageUrl);
        final directory = await getTilesDbFile();
        final database = await openDatabase(directory.path);
        final existingPath = await getImagePathFromDatabase(database, imageUrl, filename);

        if (existingPath != null) {
          imageFile = File(existingPath);
        }
        else {
          imageFile = await downloadImage(database, imageUrl, filename);
        }
      }
      else if (imageUrl.startsWith('file')) {
        imageFile = File.fromUri(Uri.parse(imageUrl));
      }
      else {
        imageFile = File(imageUrl);
      }
    }
    return imageFile;
  }
}
