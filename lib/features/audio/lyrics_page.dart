import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';

import '../../core/api/api.dart';
import '../../core/icons.dart';
import '../../core/utils/utils.dart';
import '../video/subtitles.dart';

class LyricsPage extends StatefulWidget {
  final String audioJwPage;
  final String query;

  const LyricsPage({super.key, required this.audioJwPage, this.query = ""});

  @override
  _LyricsPageState createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  String _htmlContent = '';
  late InAppWebViewController _controller;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Subtitle> _searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchLyrics(widget.audioJwPage); // Fetch subtitles when the page initializes
  }

  void fetchLyrics(String apiVideoUrl) async {
    final response = await Api.httpGetWithHeaders(apiVideoUrl);
    if (response.statusCode == 200) {
      // Parse le contenu HTML
      var document = parse(response.body);

      // Sélectionne tous les éléments <ol class="source">
      var elements = document.querySelectorAll('ol.source');

      // Concatène le HTML de chaque élément trouvé
      String htmlContent = elements.map((e) => e.outerHtml).join('\n');

      final theme = Theme.of(context).brightness == Brightness.dark
          ? 'cc-theme--dark'
          : 'cc-theme--light';
      final backgroundColor =
      Theme.of(context).brightness == Brightness.dark ? '#111111' : '#ffffff';

      setState(() {
        _htmlContent = '''
      <!DOCTYPE html>
      <html style="overflow-x: hidden;">
      <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="initial-scale=1.0, user-scalable=no, maximum-scale=1.0, minimum-scale=1.0">
      </head>
      <body>
      <style> 
      body {
         font-size: 24px;
         background-color: $backgroundColor;
      }
      </style>
      <div class="jwac layout-reading layout-sidebar $theme">
      $htmlContent
       </div>
      </body>
      </html>
      ''';
      });

      _controller.loadData(data: _htmlContent, mimeType: 'text/html', encoding: 'utf8');

      printTime('htmlContent: $_htmlContent');
    } else {
      printTime('Erreur ${response.statusCode} lors de la récupération des données.');
    }
  }

  void _onSearchChanged() {
    /*
    setState(() {
      _searchQuery = _searchController.text;
      // Filter the results
      _searchResults = _subtitles.getSubtitles()
          .where((subtitle) => subtitle.text.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    });
    */
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
    } else {
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
        title: const Text('Paroles'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(JwIcons.document_stack),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _htmlContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contenu copié dans le presse-papiers')),
                );
              },
            ),
          ),
        ],
      ),
      body: InAppWebView(
        initialData: InAppWebViewInitialData(data: ''),
        onWebViewCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
