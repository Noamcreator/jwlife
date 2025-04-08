import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:realm/realm.dart';

class VideosSearchTab extends StatefulWidget {
  final String query;

  const VideosSearchTab({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  _VideosSearchTabState createState() => _VideosSearchTabState();
}

class _VideosSearchTabState extends State<VideosSearchTab> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    fetchApiJw(widget.query);
  }

  Future<void> fetchApiJw(String query) async {
    final queryParams = {'q': query};
    final url = Uri.https('b.jw-cdn.org', '/apis/search/results/${JwLifeApp.currentLanguage.symbol}/videos', queryParams);
    try {
      Map<String, String> headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      http.Response alertResponse = await http.get(url, headers: headers);
      if (alertResponse.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(alertResponse.body);
        setState(() {
          results = (data['results'] as List).map((item) {
            return {
              'title': item['title'] ?? '',
              'duration': item['duration'] ?? '',
              'lank': item['lank'] ?? '',
              'imageUrl': item['image']?['url'] ?? '',
              'jwLink': item['links']['jw.org'] ?? '',
            };
          }).toList();
        });
      }
      else {
        print('Erreur de requête HTTP: ${alertResponse.statusCode}');
      }
    }
    catch (e) {
      print('Erreur lors de la récupération des données de l\'API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          MediaItem? mediaItem = RealmLibrary.realm.all<MediaItem>().query(
              "languageAgnosticNaturalKey == '${item['lank']}' && languageSymbol == '${JwLifeApp.currentLanguage.symbol}'").firstOrNull;

          return GestureDetector(
            onTap: () async {
              JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

              showPage(context, VideoPlayerView(
                lank: item['lank'],
                lang: JwLifeApp.currentLanguage.symbol,
              ));
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
                      mediaItem != null ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: ImageCachedWidget(
                            imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl!,
                            pathNoImage: "pub_type_video",
                            width: double.infinity,
                            height: 200,
                        ),
                      ) : item['imageUrl'].isNotEmpty
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
                        height: 200,
                        color: Colors.grey,
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            item['duration'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      mediaItem != null ? Positioned(
                        top: 8,
                        right: 8,
                        child: PopupMenuButton(
                          icon: Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (context) => [
                            getVideoShareItem(mediaItem),
                            getVideoLanguagesItem(context, mediaItem),
                            getVideoFavoriteItem(mediaItem),
                            getVideoDownloadItem(context, mediaItem),
                            getShowSubtitlesItem(context, mediaItem, query: widget.query),
                            getCopySubtitlesItem(context, mediaItem)
                          ],
                        ),
                      ) : Container(),
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
}
