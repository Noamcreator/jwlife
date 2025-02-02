import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/video/subtitles.dart';
import 'package:http/http.dart' as http;

class SubtitlesView extends StatefulWidget {
  final String apiVideoUrl;
  final String query;
  final dynamic localVideo;

  const SubtitlesView({Key? key, this.apiVideoUrl="", this.query="", this.localVideo}) : super(key: key);

  @override
  _SubtitlesViewState createState() => _SubtitlesViewState();
}

class _SubtitlesViewState extends State<SubtitlesView> {
  Subtitles _subtitles = Subtitles(); // Direct list initialization
  dynamic _mediaData = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Subtitle> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if(widget.localVideo != null) {
      fetchLocalSubtitles(widget.localVideo!); // Fetch subtitles when the page initializes
    }
    else {
      fetchOnlineSubtitles(widget.apiVideoUrl); // Fetch subtitles when the page initializes
    }
  }

  void fetchLocalSubtitles(dynamic localVideo) async {
    File file = File(localVideo['SubtitleFilePath']);
    await _subtitles.loadSubtitlesFromFile(file);
    _loadSubtitles();
  }

  void fetchOnlineSubtitles(String apiVideoUrl) async {
    final response = await http.get(Uri.parse(apiVideoUrl));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      _mediaData = jsonData['media'][0];
      await _subtitles.loadSubtitles(_mediaData);
      _loadSubtitles();
    }
  }

  void _loadSubtitles() async {
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
                    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);
                    if (widget.localVideo != null) {
                      print('localVideo: ${widget.localVideo}');
                      showPage(context, VideoPlayerView(localVideo: widget.localVideo, postionStart: subtitle.startTime));
                    }
                    else {
                      showPage(context, VideoPlayerView(api: _mediaData, postionStart: subtitle.startTime));
                    }
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
