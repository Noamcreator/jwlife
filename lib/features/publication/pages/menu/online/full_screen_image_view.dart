import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';

class FullScreenImageView extends StatefulWidget {
  final List<Map<String, String>> images;
  final Map<String, String> image;

  const FullScreenImageView({
    super.key,
    required this.images,
    required this.image,
  });

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.images.indexOf(widget.image);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // Flèche de retour en blanc
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Partager l'image
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
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
                    Image.network(
                      image['imageUrl']!,
                      fit: BoxFit.cover,
                    ),
                    if (image['type'] == 'video') // Vérifie si c'est une vidéo
                      GestureDetector(
                        onTap: () {
                          final uri = Uri.parse(image['videoUrl']!);
                          String lank = uri.queryParameters['lank']!;
                          String lang = uri.queryParameters['wtlocale']!;

                          MediaItem mediaItem = getMediaItemFromLank(lank, lang);
                          showFullScreenVideo(context, mediaItem);
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
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.black54,
            child: Text(
              widget.images[_currentIndex]['description']!, // Affiche la description de l'image actuelle
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8.0),
          Container(
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
                          Image.network(
                            widget.images[index]['imageUrl']!,
                            fit: BoxFit.cover,
                          ),
                          if (widget.images[index]['type'] == 'video') // Vérifie si c'est une vidéo
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
          SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
