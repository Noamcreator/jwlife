import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';

import '../../app/app_page.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/icons.dart';
import '../../core/utils/utils.dart';
import '../../i18n/i18n.dart';

class LyricsPage extends StatefulWidget {
  final String audioJwPage;
  final String? mepsLanguage;
  final String query;

  const LyricsPage({super.key, required this.audioJwPage, required this.mepsLanguage, this.query = ""});

  @override
  _LyricsPageState createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  String _htmlContent = '';
  late InAppWebViewController _controller;
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchLyrics(widget.audioJwPage); // Fetch subtitles when the page initializes
  }

  void fetchLyrics(String apiVideoUrl) async {
    final response = await Api.httpGetWithHeaders(apiVideoUrl);
    if (response.statusCode == 200) {
      // Parse le contenu HTML
      var document = parse(response.data);

      // Sélectionne tous les éléments <ol class="source">
      var elements = document.querySelectorAll('ol.source');

      // Concatène le HTML de chaque élément trouvé
      String htmlContent = elements.map((e) => e.outerHtml).join('\n');

      setState(() {
        _htmlContent = '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta content="text/html" charset="UTF-8">
            <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <link rel="stylesheet" href="jw-styles.css" />
          </head>
          <meta charset="utf-8">
          <style> 
            body {
              font-size: ${JwLifeSettings.instance.webViewData.fontSize}px;
              overflow-y: scroll;
            }
            body.cc-theme--dark {
              background-color: #121212;
            }
    
            body.cc-theme--light {
              background-color: #ffffff;
            }
            
            ::selection {
              background-color: rgba(66, 236, 241, 0.3) !important;
              background-size: auto 75%;
            }
          </style>
          <body class="${JwLifeSettings.instance.webViewData.theme}">
            <article id="article" class="jwac docClass-31 ms-${JwLifeSettings.instance.currentLanguage.value.internalScriptName} ml-${widget.mepsLanguage} dir-${JwLifeSettings.instance.currentLanguage.value.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar">
              $htmlContent
            </article>
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
    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().action_show_lyrics,
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.document_stack),
            onPressed: (BuildContext context) {
              Clipboard.setData(ClipboardData(text: _htmlContent));
            },
          ),
        ],
      ),
      body: InAppWebView(
        initialSettings: InAppWebViewSettings(
          scrollBarStyle: null,
          verticalScrollBarEnabled: false,
          horizontalScrollBarEnabled: false,
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          useOnLoadResource: false,
          allowUniversalAccessFromFileURLs: true,
          allowFileAccess: true,
          allowContentAccess: true,
          useHybridComposition: true,
          hardwareAcceleration: true,
        ),
        initialData: InAppWebViewInitialData(
            data: '',
            baseUrl: WebUri('file://${JwLifeSettings.instance.webViewData.webappPath}/')
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
