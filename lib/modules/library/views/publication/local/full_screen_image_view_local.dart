import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/video/video_player_view.dart';

class FullScreenImageViewLocal extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final Map<String, dynamic> image;

  const FullScreenImageViewLocal({
    super.key,
    required this.images,
    required this.image,
  });

  @override
  _FullScreenImageViewLocalState createState() =>
      _FullScreenImageViewLocalState();
}

class _FullScreenImageViewLocalState extends State<FullScreenImageViewLocal> {
  late PageController _pageController;
  late int _currentIndex;
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  TransformationController _transformationController = TransformationController();
  bool _isScaling = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.images.indexOf(widget.image);
    _pageController = PageController(initialPage: _currentIndex);
    _scrollController = ScrollController();
    _transformationController.addListener(_handleTransformationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentIndex());
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openVideo(dynamic video) async {
    print('video: $video');
    String pub = video['pubSymbol'];
    int track = video['track'];
    String symbol = 'F';
    String api =
        'https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?pub=$pub&track=$track&fileformat=MP4&langwritten=$symbol';
    final response = await http.get(Uri.parse(api));
    if (response.statusCode == 200) {
      final jsonFile = response.body;
      final jsonData = json.decode(jsonFile);
      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

      showPage(context, VideoPlayerView(pubApi: jsonData));
    }
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _isScaling = scale != 1.0;
    });
  }

  void _scrollToCurrentIndex() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = 50.0; // Smaller size for thumbnails
    final targetOffset = (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle the visibility of both controls and appBar
          _controlsVisible = !_controlsVisible;
          JwLifeView.toggleNavBarVisibility.call(_controlsVisible);
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _isScaling
                        ? NeverScrollableScrollPhysics()
                        : AlwaysScrollableScrollPhysics(),
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index; // Met à jour l'index actuel
                        _transformationController.value = Matrix4.identity(); // Reset transformation when changing pages
                        _scrollToCurrentIndex();
                      });
                    },
                    itemBuilder: (context, index) {
                      final image = widget.images[index];
                      return InteractiveViewer(
                        transformationController: _transformationController,
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(image['imagePath']!),
                              fit: BoxFit.contain,
                            ),
                            if (image['type'] == 'video')
                              GestureDetector(
                                onTap: () {
                                  _openVideo(image['videoMultimedia']!); // Ouvre la vidéo
                                },
                                child: Icon(
                                  JwIcons.play_circle, // Icône de lecture
                                  color: Colors.white.withOpacity(0.8),
                                  size: 80, // Taille de l'icône
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Thumbnail list positioned at the bottom
            if (_controlsVisible)
              Positioned(
                bottom: isPortrait(context)
                    ? MediaQuery.of(context).size.height / 10
                    : MediaQuery.of(context).size.height / 2.5,
                left: 0,
                right: 0,
                child: Container(
                  height: 60, // Height of the thumbnail list
                  margin: EdgeInsets.only(bottom: 10), // Spacing above the bottom navigation bar
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollController,
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      final image = widget.images[index];
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.jumpToPage(index);
                        },
                        child: Container(
                          width: isSelected ? 60 : 50, // Larger size for selected item
                          margin: EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Image.file(
                            File(image['imagePath']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Rest of your widgets (AppBar, description, etc.)
            if (_controlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0, // Pour ne pas avoir d'ombre sous l'AppBar
                  title: Text(
                    widget.images[_currentIndex]['caption']!,
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      JwLifeView.toggleNavBarVisibility.call(true);
                      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, false);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            if (_controlsVisible)
              Positioned(
                bottom: isPortrait(context)
                    ? MediaQuery.of(context).size.height / 4
                    : MediaQuery.of(context).size.height / 2.5,
                left: 0,
                right: 0,
                child: Text(
                  widget.images[_currentIndex]['description']!,
                  style: const TextStyle(color: Colors.white, fontSize: 16.0, backgroundColor: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
