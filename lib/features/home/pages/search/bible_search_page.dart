import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_page.dart';
import '../../../../core/api/api.dart';
import '../../../../core/utils/utils.dart';
import '../../../../widgets/searchfield/searchfield_with_suggestions/decoration.dart';
import '../../../../widgets/searchfield/searchfield_with_suggestions/input_decoration.dart';
import '../../../../widgets/searchfield/searchfield_with_suggestions/searchfield.dart';
import '../../../../widgets/searchfield/searchfield_with_suggestions/searchfield_list_item.dart';

class SearchBiblePage extends StatefulWidget {
  final String query;

  const SearchBiblePage({
    super.key,
    required this.query,
  });

  @override
  _SearchBiblePageState createState() => _SearchBiblePageState();
}

class _SearchBiblePageState extends State<SearchBiblePage> {
  List<Map<String, dynamic>> suggestions = [];
  List<Map<String, dynamic>> bibleResults = [];

  @override
  void initState() {
    super.initState();
    fetchApiBible(widget.query);
    fetchSuggestions(widget.query);
  }

  Future<void> fetchApiBible(String query) async {
    try {
      Response response = await Api.httpGetWithHeaders("https://wol.jw.org/wol/l/r30/lp-f?q=$query");

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.data);
        setState(() {
          bibleResults = (data['items'] as List).expand((item) {
            // Chaque item de 'items' contient 'results' qui est une liste de listes
            return (item['results'] as List).expand((sublist) => sublist).map((
                verse) {
              return {
                'title': verse['title'] ?? '',
                'caption': verse['caption'] ?? '',
                'content': verse['content'] ?? '',
                'publicationTitle': verse['publicationTitle'] ?? '',
                'categories': verse['categories'] ?? [],
                'url': 'https://wol.jw.org' + (verse['url'] ?? ''),
                'imageUrl': 'https://wol.jw.org' + (verse['imageUrl'] ?? ''),
              };
            }).toList();
          }).toList();
        });
      } else {
        printTime('Erreur de requête HTTP: ${response.statusCode}');
      }
    } catch (e) {
      printTime('Erreur lors de la récupération des données de l\'API: $e');
    }
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
      });
      return;
    }

    String newQuery = Uri.encodeComponent(query);
    final String url = "https://wol.jw.org/wol/sg/r30/lp-f?q=$newQuery";
    final response = await Api.httpGetWithHeaders(url);

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.data);
      if (jsonResponse['items'] is List) {
        setState(() {
          suggestions = (jsonResponse['items'] as List).map((item) {
            return {
              'caption': item['caption'] ?? '',
              'label': item['label'] ?? '',
              'query': item['query'] ?? '',
            };
          }).toList();
        });
      } else {
        setState(() {
          suggestions = [];
        });
      }
    } else {
      throw Exception('Error fetching suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: AppBar(
        title: Text('Recherche Biblique'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchField<Map<String, dynamic>>(
              itemHeight: 60,
              autofocus: false,
              maxSuggestionsInViewPort: 4,
              suggestionAction: SuggestionAction.unfocus,
              searchInputDecoration: SearchInputDecoration(
                labelText: widget.query,
                fillColor: Theme
                    .of(context)
                    .brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors
                    .white,
                filled: true,
                hintText: 'Rechercher dans la Bible...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSearchTextChanged: (text) {
                fetchSuggestions(text);
                return null;
              },
              onSuggestionTap: (
                  SearchFieldListItem<Map<String, dynamic>> item) {
                fetchApiBible(item.item!['query']);
              },
              onSubmit: (text) {
                fetchApiBible(text);
              },
              suggestionsDecoration: SuggestionDecoration(
                color: Theme
                    .of(context)
                    .brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors
                    .white,
                borderRadius: BorderRadius.circular(10),
              ),
              suggestions: suggestions
                  .map((item) =>
                  SearchFieldListItem<Map<String, dynamic>>(
                    item['caption'],
                    item: item,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['caption'],
                              style: const TextStyle(fontSize: 22),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (item['label'].isNotEmpty) ...[
                            const SizedBox(width: 8), // Espace entre le caption et le label
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF595959)
                                    : Color(0xFFc0c0c0),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Text(
                                item['label'],
                                style: const TextStyle(fontSize: 17, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: bibleResults.length,
              itemBuilder: (context, index) {
                final item = bibleResults[index];

                return GestureDetector(
                  onTap: () {
                    printTime(item["title"]);
                  },
                  child: Column(
                    children: [
                      Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF262626)
                            : Color(0xFFf2f1ef),
                        child: Row(
                          children: [
                            item["imageUrl"] == null
                                ? Container()
                                : Image.network(
                              item["imageUrl"],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["title"],
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    item["publicationTitle"],
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      /*
                      Container(
                        color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF262626) : Color(0xFFffffff),
                          padding: const EdgeInsets.all(8.0),
                          child: HtmlWidget(
                            item["content"],
                            textStyle: const TextStyle(fontSize: 18),
                            customStylesBuilder: (htmlElement) {
                              if (item["categories"] != null &&
                                  item["categories"].isNotEmpty) {
                                if (item["categories"][0] == "bi") {
                                  if (htmlElement.localName == 'p') {
                                    return {
                                      'font-family': 'Wt-ClearText',
                                    };
                                  }
                                  if (htmlElement.localName == 'a') {
                                    return {
                                      'text-decoration': 'none',
                                      'color': Theme.of(context).brightness == Brightness.dark
                                          ? '#9fb9e3'
                                          : '#4a6da7',
                                      'font-family': 'NotoSans',
                                      'font-weight': 'bold',
                                    };
                                  }
                                }
                              }
                              return null;
                            },
                          ),
                      ),

                       */
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
