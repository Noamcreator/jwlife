import 'package:flutter/material.dart';
import '../data/models/tile.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';

class ImageCachedWidget extends StatefulWidget {
  final String? imageUrl;
  final IconData? icon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final bool animation;

  const ImageCachedWidget({
    super.key,
    required this.imageUrl,
    this.icon,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.animation = true,
  });

  @override
  State<ImageCachedWidget> createState() => _ImageCachedWidgetState();
}

class _ImageCachedWidgetState extends State<ImageCachedWidget> {
  late Future<Tile?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant ImageCachedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      _imageFuture = Future.value(null);
    }
    else {
      _imageFuture = TilesCache().getOrDownloadImage(widget.imageUrl!).then((tile) {
        if (tile != null && mounted) {
          // Préchargement léger pour éviter le jank
          precacheImage(FileImage(tile.file), context);
        }
        return tile;
      });
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    final Color backgroundColor = isDark ? const Color(0xFF4F4F4F) : const Color(0xFF999999);

    double? width = widget.width;
    double? height = widget.height;

    if (width == null || width.isInfinite || width.isNaN) width = null;
    if (height == null || height.isInfinite || height.isNaN) height = null;

    double iconSize = 30.0;
    if (width != null && height != null) {
      iconSize = (width < height ? width : height) * 0.45;
      if (iconSize.isInfinite || iconSize.isNaN) iconSize = 30.0;
    }

    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      alignment: widget.alignment,
      child: widget.icon != null
          ? Icon(
        widget.icon,
        size: iconSize,
        color: Colors.white,
      )
          : null,
    );
  }

  // --- La méthode build avec la correction pour le cacheWidth/cacheHeight ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final placeholder = _buildPlaceholder(isDark);

    // Fonction utilitaire pour gérer les valeurs Infinity/NaN et calculer la dimension du cache
    int? getCacheDimension(double? dimension) {
      // Retourne null si la dimension est nulle, infinie ou NaN
      if (dimension == null || dimension.isInfinite || dimension.isNaN) {
        return null;
      }
      // Effectue le calcul sécurisé
      return (dimension * pixelRatio).toInt();
    }

    final int? cacheW = getCacheDimension(widget.width);
    final int? cacheH = getCacheDimension(widget.height);
    // -------------------------------------------------------------------------

    return FutureBuilder<Tile?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final file = snapshot.data?.file;
        if (snapshot.connectionState != ConnectionState.done || file == null) {
          if(widget.animation) {
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: placeholder,
            );
          }
          else {
            return SizedBox(
              width: widget.width,
              height: widget.height,
            );
          }
        }

        return Image.file(
          file,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          // Utilisation des valeurs validées
          cacheWidth: cacheW,
          cacheHeight: cacheH,
          filterQuality: FilterQuality.low,
          frameBuilder: widget.animation
              ? (context, child, frame, wasLoaded) {
            if (wasLoaded || frame != null) return child;
            return SizedBox(width: widget.width, height: widget.height, child: placeholder);
          }
              : null,
        );
      },
    );
  }
}