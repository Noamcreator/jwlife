import 'dart:io';
import 'package:flutter/material.dart';

import '../../app/services/global_key_service.dart';

class ImagePage extends StatefulWidget {
  final String filePath;

  const ImagePage({
    super.key,
    required this.filePath,
  });

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  bool _controlsVisible = true;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Scaffold(
        backgroundColor: const Color(0xFF101010),
        body: Stack(
          children: [
            _buildImageView(),
            if (_controlsVisible) _buildAppBar(context),
            if (_controlsVisible)
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GlobalKeyService.jwLifePageKey.currentState!.getBottomNavigationBar(isBlack: true)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView() {
    return InteractiveViewer(
      transformationController: _transformationController,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 1.0,
      maxScale: 12.0,
      child: Center(
        child: Image.file(
          File(widget.filePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
      ),
    );
  }
}
