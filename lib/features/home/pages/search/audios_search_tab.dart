import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../data/models/audio.dart';
import 'search_model.dart';

class AudioSearchTab extends StatefulWidget {
  final SearchModel model;

  const AudioSearchTab({super.key, required this.model});

  @override
  _AudioSearchTabState createState() => _AudioSearchTabState();
}

class _AudioSearchTabState extends State<AudioSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchAudios(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Aucun résultat trouvé.'));
        } else {
          final results = snapshot.data!;
          return Scaffold(
            body: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                MediaItem mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings().currentLanguage.symbol);
                Audio audio = Audio.fromJson(mediaItem: mediaItem);

                return GestureDetector(
                  onTap: () async {
                    audio.showPlayer(context);
                  },
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            item['imageUrl'].isNotEmpty
                                ? ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                              child: Image.network(
                                item['imageUrl'],
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Container(
                              width: double.infinity,
                              height: 150,
                              color: Colors.grey,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  color: Colors.black.withOpacity(0.7),
                                  child: Row(
                                      children: [
                                        const Icon(
                                          JwIcons.headphones,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatDuration(audio.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ]
                                  )
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: PopupMenuButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                                itemBuilder: (context) => [
                                  getAudioShareItem(audio),
                                  getAudioLanguagesItem(context, audio),
                                  getAudioFavoriteItem(audio),
                                  getAudioDownloadItem(context, audio),
                                  getAudioLyricsItem(context, audio),
                                  getCopyLyricsItem(audio)
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            item['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}
