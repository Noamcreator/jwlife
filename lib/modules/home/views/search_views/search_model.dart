import 'dart:convert';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api.dart';
import 'package:http/http.dart' as http;

class SearchModel {
  final String query;

  SearchModel({required this.query});

  List<Map<String, dynamic>> allSearch = [];
  List<Map<String, dynamic>> publications = [];
  List<Map<String, dynamic>> videos = [];
  List<Map<String, dynamic>> audios = [];
  List<Map<String, dynamic>> verses = [];

  /*
  Future<List<Map<String, dynamic>>> fetchAllSearch() async {
    final queryParams = {'q': query};
    final url = Uri.https('b.jw-cdn.org', '/apis/search/results/${JwLifeApp.settings.currentLanguage.symbol}/all', queryParams);

    try {
      Map<String, String> headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      http.Response alertResponse = await http.get(url, headers: headers);
      if (alertResponse.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(alertResponse.body);
        return (data['results'] as List).map((item) {
          return {
            'type': item['type'] ?? '',
            'label': item['label'] ?? '',
            'links': item['links'] ?? [],
            'layout': item['layout'] ?? [],
            'results': item['results'] ?? [],
          };
        }).toList();
      }
      else {
        print('Erreur de requête HTTP: ${alertResponse.statusCode}');
      }
    }
    catch (e) {
      print('Erreur lors de la récupération des données de l\'API: $e');
    }
    return [];
  }
  */


  Future<List<Map<String, dynamic>>> _fetchData(String path) async {
    final queryParams = {'q': query};
    final url = Uri.https(
      'b.jw-cdn.org',
      '/apis/search/results/${JwLifeApp.settings.currentLanguage.symbol}/$path',
      queryParams,
    );

    try {
      final headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final results = (data['results'] as List).map<Map<String, dynamic>>((item) {
          return {
            'title': item['title'] ?? '',
            'type': item['type'] ?? '',
            'label': item['label'] ?? '',
            'snippet': item['snippet'] ?? '',
            'context': item['context'] ?? '',
            'lank': item['lank'] ?? '',
            'imageUrl': item['image'] != null ? item['image']['url'] : '',
            'links': item['links'] ?? [],
            'layout': item['layout'] ?? [],
            'results': item['results'] ?? [],
          };
        }).toList();

        switch (path) {
          case 'all':
            allSearch = results;
            break;
          case 'publications':
            publications = results;
            break;
          case 'videos':
            videos = results;
            break;
          case 'audio':
            audios = results;
            break;
          case 'bible':
            verses = results;
            break;
        }

        return results;
      } else {
        print('Erreur de requête HTTP: ${response.statusCode}');
      }
    }
    catch (e) {
      print('Erreur lors de la récupération des données de l\'API: $e');
    }

    return [];
  }

  // Les méthodes publiques qui renvoient directement les résultats en cache si disponibles
  Future<List<Map<String, dynamic>>> fetchAllSearch() async {
    if (allSearch.isNotEmpty) return allSearch;
    return await _fetchData('all');
  }

  Future<List<Map<String, dynamic>>> fetchPublications() async {
    if (publications.isNotEmpty) return publications;
    return await _fetchData('publications');
  }

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    if (videos.isNotEmpty) return videos;
    return await _fetchData('videos');
  }

  Future<List<Map<String, dynamic>>> fetchAudios() async {
    if (audios.isNotEmpty) return audios;
    return await _fetchData('audio');
  }

  Future<List<Map<String, dynamic>>> fetchVerses() async {
    if (verses.isNotEmpty) return verses;
    return await _fetchData('bible');
  }
}
