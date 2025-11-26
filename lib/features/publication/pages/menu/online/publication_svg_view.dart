import 'package:flutter/material.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../../app/app_page.dart';

class PublicationSvgView extends StatefulWidget {
  final List<String> svgUrls;

  const PublicationSvgView({super.key, required this.svgUrls});

  @override
  _PublicationSvgViewState createState() => _PublicationSvgViewState();
}

class _PublicationSvgViewState extends State<PublicationSvgView> {
  final PageController _pageController = PageController();
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.svgUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onDoubleTapDown: (details) {
              _doubleTapDetails = details;
            },
            onDoubleTap: () {
              if (_transformationController.value != Matrix4.identity()) {
                _transformationController.value = Matrix4.identity();
              } else {
                final position = _doubleTapDetails!.localPosition;
                _transformationController.value = Matrix4.identity()
                  ..translate(-position.dx * 2, -position.dy * 2)
                  ..scale(2.0);
              }
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: true,
              scaleEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: ImageCachedWidget(imageUrl: widget.svgUrls[index]),
            ),
          );
        },
      ),
    );
  }
}
