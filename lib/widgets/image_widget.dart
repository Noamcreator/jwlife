import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import '../data/databases/Tiles.dart';

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
  late Future<Tile?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = JwLifeApp.tilesCache.getOrDownloadImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant ImageCachedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'URL a changé, recharger l'image
    if (widget.imageUrl != oldWidget.imageUrl) {
      _imageFuture = JwLifeApp.tilesCache.getOrDownloadImage(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Tile?>(
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
            snapshot.data!.file,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
          );
        }
      },
    );
  }
}