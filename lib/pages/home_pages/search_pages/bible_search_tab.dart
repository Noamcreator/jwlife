import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../jwlife.dart';
import '../../../widgets/htmlView/html_widget.dart';

class BibleSearchTab extends StatefulWidget {
  final String query;

  const BibleSearchTab({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  _BibleSearchTabState createState() => _BibleSearchTabState();
}

class _BibleSearchTabState extends State<BibleSearchTab> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    fetchApiJw(widget.query);
  }

  Future<void> fetchApiJw(String query) async {
    final queryParams = {'q': query};
    final url = Uri.https('b.jw-cdn.org', '/apis/search/results/${JwLifeApp.currentLanguage.symbol}/bible', queryParams);
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
                'lank': item['lank'] ?? '',
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
              // Define the action on tapping the verse
            },
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: HtmlWidget(
                      item['title'],
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: HtmlWidget(
                      item['snippet'],
                      textStyle: TextStyle(
                        fontSize: 18,
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
