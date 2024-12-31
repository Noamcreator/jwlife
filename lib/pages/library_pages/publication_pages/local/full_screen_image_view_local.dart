import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/utils/utils.dart';
import '../../../../jwlife.dart';
import '../../../../jwlife.dart';
import '../../../../utils/icons.dart';
import '../../../../video/FullScreenVideoPlayer.dart'; // Remplace par le bon chemin vers JwIcons

import 'package:http/http.dart' as http;

class FullScreenImageViewLocal extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final Map<String, dynamic> image;

  const FullScreenImageViewLocal({
    super.key,
    required this.images,
    required this.image,
  });

  @override
  _FullScreenImageViewLocalState createState() => _FullScreenImageViewLocalState();
}

class _FullScreenImageViewLocalState extends State<FullScreenImageViewLocal> {
  late PageController _pageController;
  late int _currentIndex;
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.images.indexOf(widget.image);
    _pageController = PageController(initialPage: _currentIndex);
  }

  Future<void> _openVideo(dynamic video) async {
    print('video: $video');
    String pub = video['pubSymbol'];
    int track = video['track'];
    String symbol = 'F';
    String api = 'https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?pub=$pub&track=$track&fileformat=MP4&langwritten=$symbol';

    final response = await http.get(Uri.parse(api));
    if (response.statusCode == 200) {
      final jsonFile = response.body;
      final jsonData = json.decode(jsonFile);

      JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
            return FullScreenVideoPlayer(
                pubApi: jsonData
            );
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          setState(() {
            // Toggle the visibility of both controls and appBar
            _controlsVisible = !_controlsVisible;
            JwLifePage.toggleNavBarVisibility.call(_controlsVisible);
          });
        },
        child: Scaffold(
          backgroundColor: Colors.black,

          body: Stack(
            children: [
              Positioned.fill(
                  child: Center(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.images.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index; // Met à jour l'index actuel
                        });
                      },
                      itemBuilder: (context, index) {
                        final image = widget.images[index];
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(image['imagePath']!),
                              fit: BoxFit.cover,
                            ),
                            if (image['type'] == 'video') // Vérifie si c'est une vidéo
                              GestureDetector(
                                onTap: () {
                                  _openVideo(image['videoMultimedia']!); // Ouvre la vidéo
                                },
                                child: Icon(
                                  JwIcons.play_circle, // Icône de lecture
                                  color: Colors.white.withOpacity(0.8), // Couleur de l'icône
                                  size: 80, // Taille de l'icône
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                )
              ),
              if (_controlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0, // Pour ne pas avoir d'ombre sous l'AppBar
                    title: Text(widget.images[_currentIndex]['caption']!, style: const TextStyle(color: Colors.white)),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        JwLifePage.toggleNavBarVisibility.call(true);
                        JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, false);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),


              if (_controlsVisible)
                Positioned(
                  bottom: isPortrait(context) ? MediaQuery.of(context).size.height / 4 : MediaQuery.of(context).size.height / 2.5,
                  left: 0,
                  right: 0,
                  child: Text(
                    widget.images[_currentIndex]['description']!, // Affiche la description de l'image actuelle
                    style: const TextStyle(color: Colors.white, fontSize: 16.0, backgroundColor: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_controlsVisible)
                Positioned(
                  bottom: 55,
                  left: -15,
                  right: -15,
                  height: 80.0, // Ajuste la hauteur pour plus de visibilité
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      bool isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.jumpToPage(index); // Change l'image affichée
                          setState(() {
                            _currentIndex = index; // Met à jour l'index actuel
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: isSelected ? 80 : 70, // 80 si sélectionné, sinon 70
                          height: isSelected ? 80 : 70, // 80 si sélectionné, sinon 70
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Stack(
                              alignment: Alignment.center, // Centrer le logo
                              children: [
                                Image.file(
                                  File(widget.images[index]['imagePath']!),
                                  fit: BoxFit.cover,
                                ),
                                if (widget.images[index]['type'] == 'video/mp4') // Vérifie si c'est une vidéo
                                  Icon(
                                    JwIcons.play_circle, // Icône de lecture
                                    color: Colors.white.withOpacity(0.8), // Couleur de l'icône
                                    size: 30, // Taille de l'icône
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        )
    );
  }
}
