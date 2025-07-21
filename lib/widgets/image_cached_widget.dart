import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';
import '../data/models/tile.dart';

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
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      _imageFuture = Future.value(null);
    } else {
      _imageFuture = TilesCache().getOrDownloadImage(widget.imageUrl);
    }
  }

  @override
  void didUpdateWidget(covariant ImageCachedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
        _imageFuture = Future.value(null);
      } else {
        _imageFuture = TilesCache().getOrDownloadImage(widget.imageUrl);
      }
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return Image.asset(
      'assets/images/${widget.pathNoImage}${isDark ? "_gray" : ""}.png',
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
    );
  }

  int? safeToInt(double? value) {
    if (value == null || value.isInfinite || value.isNaN) {
      return null;
    }
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Tile?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(isDark);
        } else if (snapshot.hasError || snapshot.data == null) {
          return _buildPlaceholder(isDark);
        } else {
          final pixelRatio = MediaQuery.of(context).devicePixelRatio;
          return Image.file(
            snapshot.data!.file,
            width: widget.width,
            height: widget.height,
            cacheWidth: safeToInt(widget.width != null ? widget.width! * pixelRatio : null),
            cacheHeight: safeToInt(widget.height != null ? widget.height! * pixelRatio : null),
            fit: widget.fit,
          );
        }
      },
    );
  }

}