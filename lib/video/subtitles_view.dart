import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/Video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/video/subtitles.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';

class SubtitlesView extends StatefulWidget {
  final MediaItem? mediaItem;
  final String query;
  final Video? localVideo;

  const SubtitlesView({Key? key, this.mediaItem, this.query="", this.localVideo}) : super(key: key);

  @override
  _SubtitlesViewState createState() => _SubtitlesViewState();
}

class _SubtitlesViewState extends State<SubtitlesView> {
  Subtitles _subtitles = Subtitles(); // Direct list initialization
  dynamic _mediaData = {};
  List<Subtitle> _searchResults = [];

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if(widget.localVideo != null) {
      fetchLocalSubtitles(widget.localVideo!); // Fetch subtitles when the page initializes
    }
    else {
      fetchOnlineSubtitles(); // Fetch subtitles when the page initializes
    }
  }

  void fetchLocalSubtitles(dynamic localVideo) async {
    File file = File(localVideo['SubtitleFilePath']);
    await _subtitles.loadSubtitlesFromFile(file);
    _loadSubtitles();
  }

  void fetchOnlineSubtitles() async {
    String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.mediaItem!.languageSymbol}/${widget.mediaItem!.languageAgnosticNaturalKey}';

    final response = await Api.httpGetWithHeaders(link);
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
          _searchResults = result;
        }
      }
    });
  }

  void _searchSubtitles(String query) {
    setState(() {
      _searchResults = _subtitles.getSubtitles().where((subtitle) => subtitle.text.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Render subtitles with highlighted text
  Text _highlightText(String text) {
    String query = _searchController.text;
    if (query.isEmpty) {
      return Text(text, style: TextStyle(fontSize: 26.0), textAlign: TextAlign.center);
    }
    else {
      final regExp = RegExp(query, caseSensitive: false);
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
      appBar: _isSearching ? AppBar(
        title: SearchBar(
          autoFocus: true,
          hintText: 'Rechercher...',
          controller: _searchController,
          onChanged: _searchSubtitles,
          onSubmitted: _searchSubtitles,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
            });
          },
        ),
      ) : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.mediaItem != null ? Text(widget.mediaItem!.title!, style: const TextStyle(fontSize: 18.0)) : Container(),
            const Text('Sous-titres', style: TextStyle(fontSize: 12.0)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.document_stack),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _subtitles.toString()));
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final subtitle = _searchResults[index];
          return GestureDetector(
            onTap: () {
              JwLifeView.toggleNavBarBlack.call(true);
              if (widget.localVideo != null) {
                MediaItem? mediaItem = getVideoItem(widget.localVideo!.keySymbol, widget.localVideo!.track, widget.localVideo!.documentId, widget.localVideo!.issueTagNumber, JwLifeApp.settings.currentLanguage.id);
                showPage(context, VideoPlayerView(mediaItem: mediaItem!, localVideo: widget.localVideo, startPosition: subtitle.startTime));
              }
              else {
                showPage(context, VideoPlayerView(mediaItem: widget.mediaItem!, onlineVideo: _mediaData, startPosition: subtitle.startTime));
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
      )
    );
  }
}
