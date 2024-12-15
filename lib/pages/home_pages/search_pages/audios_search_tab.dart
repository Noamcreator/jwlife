import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../../jwlife.dart';
import '../../../widgets/dialog/language_dialog.dart';

class AudioSearchTab extends StatefulWidget {
  final String query;

  const AudioSearchTab({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  _AudioSearchTabState createState() => _AudioSearchTabState();
}

class _AudioSearchTabState extends State<AudioSearchTab> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    fetchApiJw(widget.query);
  }

  Future<void> fetchApiJw(String query) async {
    final queryParams = {'q': query};
    final url = Uri.https(
        'b.jw-cdn.org', '/apis/search/results/${JwLifeApp.currentLanguage.symbol}/audio', queryParams);
    final jwtTokenUrl = Uri.https('b.jw-cdn.org', '/tokens/jworg.jwt');

    try {
      http.Response tokenResponse = await http.get(jwtTokenUrl);
      if (tokenResponse.statusCode == 200) {
        String jwtToken = tokenResponse.body;
        Map<String, String> headers = {
          'Authorization': 'Bearer $jwtToken',
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
        } else {
          print('Erreur de requête HTTP: ${alertResponse.statusCode}');
        }
      } else {
        print('Erreur de requête HTTP pour le token: ${tokenResponse.statusCode}');
      }
    } catch (e) {
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
          return GestureDetector(
            onTap: () async {
              JwLifeApp.jwAudioPlayer.setRandomMode(false);
              JwLifeApp.jwAudioPlayer.fetchAudioData(item['lank'], JwLifeApp.currentLanguage.symbol);
              JwLifeApp.jwAudioPlayer.play();
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
                          child: Text(
                            item['duration'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              child: const Text('Envoyer le lien'),
                              onTap: () {
                                Share.share(
                                  'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${JwLifeApp.currentLanguage.symbol}&lank=${item['lank']}',);
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Ajouter à la liste de lecture'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Autres langues'),
                              onTap: () async {
                                String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item['lank']}?clientType=www';
                                final response = await http.get(Uri.parse(link));
                                if (response.statusCode == 200) {
                                  final jsonFile = response.body;
                                  final jsonData = json.decode(jsonFile);

                                  LanguageDialog languageDialog = LanguageDialog(languagesListJson: jsonData['languages']);
                                  showDialog(
                                    context: context,
                                    builder: (context) => languageDialog,
                                  );
                                }
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Aujouter aux favoris'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Télécharger la vidéo'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Copier les sous-titres'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
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
}
