import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../jwlife.dart';
import '../../../utils/utils.dart';
import '../../library_pages/publication_pages/online/publication_menu.dart';

class PublicationsSearchTab extends StatefulWidget {
  final String query;

  const PublicationsSearchTab({
    super.key,
    required this.query,
  });

  @override
  _PublicationsSearchTabState createState() => _PublicationsSearchTabState();
}

class _PublicationsSearchTabState extends State<PublicationsSearchTab> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    fetchApiJw(widget.query);
  }

  Future<void> fetchApiJw(String query) async {
    final queryParams = {'q': query};
    final url = Uri.https(
        'b.jw-cdn.org', '/apis/search/results/${JwLifeApp.currentLanguage.symbol}/publications', queryParams);

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
                'snippet': item['snippet'] ?? '',
                'context': item['context'] ?? '',
                'lank': item['lank'] ?? '',
                'imageUrl': item['image'] != null ? item['image']['url'] : '',
                'jwLink': item['links']['jw.org'] ?? '',
                'wolLink': item['links']['wol'] ?? '',
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
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];

        return GestureDetector(
          child: Card(
            color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Container(
              height: 150, // Garde la hauteur de la Card
              child: Row(
                children: [
                  // Image à gauche
                  item['imageUrl'] != null && item['imageUrl'] != ''
                      ? Container(
                    width: 110, // Définit la largeur fixe pour l'image en mode portrait
                    height: 150, // Garde la hauteur pour correspondre à la Card
                    child: Image.network(
                      item['imageUrl'],
                      fit: BoxFit.cover, // Remplit tout l'espace en conservant les proportions
                    ),
                  )
                      : Container(
                    width: 110,
                    height: 150,
                    color: Colors.grey,
                  ),
                  // Texte à droite
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0), // Ajoute un peu de padding autour du texte
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['context'],
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            maxLines: 3, // Limite le texte à 3 lignes
                            overflow: TextOverflow.ellipsis, // Si le texte est trop long, il sera tronqué
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          onTap: () async {
            if (item['wolLink'] != null && item['wolLink'] != '') {
              String lank = item['lank'];
              String keySymbol = lank.replaceAll("pub-", "");
              Map<String, dynamic>? publication = await searchPub(keySymbol);
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                    return PublicationMenu(publication: publication!);
                  },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            } else {
              print(item['jwLink']);
              launchUrl(Uri.parse(item['jwLink']), mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }
}
