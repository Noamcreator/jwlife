import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/utils/icons.dart';
import 'package:jwlife/video/FullScreenVideoPlayer.dart';
import 'package:jwlife/video/Subtitles.dart';
import 'package:http/http.dart' as http;

import '../jwlife.dart';
import '../jwlife.dart';

class SubtitlesPage extends StatefulWidget {
  final String apiVideoUrl;
  final String query;

  const SubtitlesPage({Key? key, required this.apiVideoUrl, this.query=""}) : super(key: key);

  @override
  _SubtitlesPageState createState() => _SubtitlesPageState();
}

class _SubtitlesPageState extends State<SubtitlesPage> {
  Subtitles _subtitles = Subtitles(); // Direct list initialization
  dynamic _mediaData = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Subtitle> _searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchSubtitles(widget.apiVideoUrl); // Fetch subtitles when the page initializes
  }

  void fetchSubtitles(String apiVideoUrl) async {
    final response = await http.get(Uri.parse(apiVideoUrl));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      _mediaData = jsonData['media'][0];
      await _subtitles.loadSubtitles(_mediaData);
      setState(() {
        _searchResults = _subtitles.getSubtitles();
        List<Subtitle> result = _subtitles.getSubtitles()
            .where((subtitle) => subtitle.text.toLowerCase().contains(widget.query.toLowerCase()))
            .toList();
        if (widget.query.isNotEmpty) {
          if (result.isNotEmpty) {
            _searchController.text = widget.query;
            _searchQuery = widget.query;
            _searchResults = result;
          }
        }
      });
      _searchController.addListener(_onSearchChanged);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      // Filter the results
      _searchResults = _subtitles.getSubtitles()
          .where((subtitle) => subtitle.text.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Render subtitles with highlighted text
  Text _highlightText(String text) {
    if (_searchQuery.isEmpty) {
      return Text(text, style: TextStyle(fontSize: 26.0), textAlign: TextAlign.center);
    }
    else {
      final regExp = RegExp(_searchQuery, caseSensitive: false);
      final matches = regExp.allMatches(text);

      List<TextSpan> textSpans = [];
      int start = 0;

      for (var match in matches) {
        // Add the text before the match
        if (match.start > start) {
          textSpans.add(TextSpan(text: text.substring(start, match.start)));
        }
        // Add the highlighted text
        textSpans.add(TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(backgroundColor: Colors.yellow),
        ));
        start = match.end;
      }

      // Add the text after the last match
      if (start < text.length) {
        textSpans.add(TextSpan(text: text.substring(start)));
      }

      return Text.rich(TextSpan(children: textSpans, style: TextStyle(fontSize: 26.0)), textAlign: TextAlign.center);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sous-titres'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(JwIcons.document_stack),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _subtitles.toString()));
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ) : null,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final subtitle = _searchResults[index];
                return GestureDetector(
                  onTap: () {
                    JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                          return FullScreenVideoPlayer(api: _mediaData, postionStart: subtitle.startTime);
                        },
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Center( // Centrer horizontalement le texte
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: _highlightText(subtitle.text),
                    ),
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
