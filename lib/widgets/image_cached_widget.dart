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
  final Alignment alignment; // <-- La propriété d'alignement est ici
  final bool animation;

  const ImageCachedWidget({
    super.key,
    required this.imageUrl,
    this.icon,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center, // Valeur par défaut
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
          // Utiliser la bonne méthode pour la prévisualisation d'une image locale
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
      // 🚀 APPLIQUÉ 1/3 : Applique l'alignement au Container du placeholder
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

        // 🧩 Si animation désactivée, on affiche directement le contenu
        if (!widget.animation) {
          if (isImageReady && file != null) {
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
              // 🚀 APPLIQUÉ 2/3 : Applique l'alignement à l'Image.file (sans animation)
              alignment: widget.alignment,
            );
          }
          else {
            return SizedBox(
              width: widget.width,
              height: widget.height,
            );
          }
        }

        // 🪄 Version avec animation
        return Stack(
          // Important: L'alignement du Stack doit être center pour que les enfants se chevauchent correctement
          alignment: Alignment.center,
          children: [
            // Fade-out du placeholder
            AnimatedOpacity(
              opacity: isImageReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: placeholder,
              ),
            ),

            // Fade-in de l’image
            if (isImageReady && file != null)
              _FadeInImageWidget(
                file: file,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                // 🚀 APPLIQUÉ 3/3 : Passe l'alignement au widget d'animation enfant
                alignment: widget.alignment,
                pixelRatio: pixelRatio,
              ),
          ],
        );
      },
    );
  }
}

class _FadeInImageWidget extends StatefulWidget {
  // L'objet File est plus approprié que dynamic ici si vous travaillez avec dart:io.
  final File file;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment; // <-- Reçoit la propriété
  final double pixelRatio;

  const _FadeInImageWidget({
    required this.file,
    required this.width,
    required this.height,
    required this.fit,
    required this.alignment,
    required this.pixelRatio,
  });

  @override
  State<_FadeInImageWidget> createState() => _FadeInImageWidgetState();
}

class _FadeInImageWidgetState extends State<_FadeInImageWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 50));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? safeToInt(double? value) {
    if (value == null || value.isInfinite || value.isNaN) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Image.file(
        widget.file,
        key: ValueKey(widget.file.path),
        width: widget.width,
        height: widget.height,
        cacheWidth:
        safeToInt(widget.width != null ? widget.width! * widget.pixelRatio : null),
        cacheHeight:
        safeToInt(widget.height != null ? widget.height! * widget.pixelRatio : null),
        // 🚀 APPLIQUÉ 4/4 : Utilise l'alignement dans le widget final Image.file
        alignment: widget.alignment,
        fit: widget.fit,
      ),
    );
  }
}
