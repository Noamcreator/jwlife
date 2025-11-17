import 'package:flutter/material.dart';
import '../data/models/tile.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';
import 'dart:io';

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
    } else {
      _imageFuture = TilesCache().getOrDownloadImage(widget.imageUrl).then((tile) {
        if (tile != null && mounted) {
          // Prévisualisation de l'image locale pour un chargement plus rapide
          precacheImage(FileImage(tile.file), context);
        }
        return tile;
      });
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    final Color backgroundColor =
    isDark ? const Color(0xFF4F4F4F) : const Color(0xFF999999);

    double? width = widget.width;
    double? height = widget.height;

    if (width == null || width.isInfinite || width.isNaN) width = null;
    if (height == null || height.isInfinite || height.isNaN) height = null;

    double iconSize = 30.0;
    if (width != null && height != null) {
      iconSize = (width < height ? width : height) * 0.45;
      if (iconSize.isInfinite || iconSize.isNaN) {
        iconSize = 30.0;
      }
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

  int? safeToInt(double? value) {
    if (value == null || value.isInfinite || value.isNaN) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final placeholder = _buildPlaceholder(isDark);

    return FutureBuilder<Tile?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final bool isImageReady = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            snapshot.data != null;

        final file = snapshot.data?.file;

        if (!isImageReady || file == null) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: placeholder,
          );
        }

        // --- L'image est téléchargée et prête ---

        if (!widget.animation) {
          // Version sans animation : affichage direct
          return Image.file(
            file,
            key: ValueKey(file.path),
            width: widget.width,
            height: widget.height,
            cacheWidth:
            safeToInt(widget.width != null ? widget.width! * pixelRatio : null),
            cacheHeight:
            safeToInt(widget.height != null ? widget.height! * pixelRatio : null),
            fit: widget.fit,
            alignment: widget.alignment,
          );
        }

        // Version avec animation (FrameBuilder)
        return Image.file(
          file,
          key: ValueKey(file.path),
          width: widget.width,
          height: widget.height,
          cacheWidth:
          safeToInt(widget.width != null ? widget.width! * pixelRatio : null),
          cacheHeight:
          safeToInt(widget.height != null ? widget.height! * pixelRatio : null),
          fit: widget.fit,
          alignment: widget.alignment,
          // Utilisation de frameBuilder pour gérer l'animation de fondu
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            // Si l'image est déjà affichée ou chargée instantanément, on l'affiche directement
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }

            // Sinon, on affiche le placeholder pendant le chargement
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: placeholder,
            );
          },
        );
      },
    );
  }
}