import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';

import '../../../app/services/settings_service.dart';
import '../../../core/utils/directory_helper.dart';
import '../../../core/utils/utils.dart';
import '../../../widgets/dialog/language_dialog.dart';

class AlertInfoPage extends StatefulWidget {
  final List<dynamic> alerts; // URL de l'alerte à afficher

  const AlertInfoPage({super.key, required this.alerts});

  @override
  _AlertInfoPageState createState() => _AlertInfoPageState();
}

class _AlertInfoPageState extends State<AlertInfoPage> {
  String language = '';

  String _htmlContent = '';
  bool _isLoadingHtml = true;

  String webappPath = '';

  late InAppWebViewController webViewController;

  @override
  void initState() {
    super.initState();
    setLanguage();
    _initializeHtml();
  }

  Future<void> _initializeHtml() async {
    try {
      Directory webApp = await getAppWebViewDirectory();
      webappPath = '${webApp.path}/webapp';

      _htmlContent = convertAlertsToHtml(widget.alerts);
    }
    catch (e) {
      printTime('Error initializing HTML: $e');
    }
    finally {
      setState(() {
        _isLoadingHtml = false;
      });
    }
  }

  String convertAlertsToHtml(List<dynamic> alerts) {
    WebViewData webViewData = JwLifeSettings().webViewData;

    String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
        <style>
          body {
            font-size: ${webViewData.fontSize}px;
            background-color: ${webViewData.backgroundColor};
          }
        </style>
      </head>
      <body class="jwac layout-reading layout-sidebar ${webViewData.theme}">
        <div class="content-wrapper">
  ''';

    for (var alert in alerts) {
      String title = alert['title'] ?? 'Sans titre';
      String body = alert['body'] ?? '';

      htmlContent += '''
      <h2>$title</h2>
        $body
    ''';
    }

    htmlContent += '''
        </div>
      </body>
    </html>
  ''';

    return htmlContent;
  }


  void setLanguage() async {
    setState(() {
      language = JwLifeSettings().currentLanguage.vernacular;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerte Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              language,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              LanguageDialog languageDialog = const LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) {
                printTime('Language selected: $value');
              });
            },
          )
        ],
      ),
      body: _isLoadingHtml ? const Center(child: CircularProgressIndicator()) : InAppWebView(
        initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useHybridComposition: true,
            allowFileAccess: true,
            allowContentAccess: true,
            cacheMode: CacheMode.LOAD_NO_CACHE,
            allowUniversalAccessFromFileURLs: true
        ),
        initialData: InAppWebViewInitialData(
          data: _htmlContent,
          mimeType: 'text/html',
          baseUrl: WebUri('file://$webappPath/'),
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          WebUri uri = navigationAction.request.url!;
          String url = uri.uriValue.toString();

          if (url.startsWith('webpubdl://'))  {
            final docId = uri.queryParameters['docid'];
            final track = uri.queryParameters['track'];
            final langwritten = uri.queryParameters.containsKey('langwritten') ? uri.queryParameters['langwritten'] : '';
            final fileformat = uri.queryParameters['fileformat'];

            //showDocumentDialog(context, docId!, track!, langwritten!, fileformat!);

            return NavigationActionPolicy.CANCEL;
          }
          else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
            if (uri.queryParameters.containsKey('lank')) {
              MediaItem? mediaItem;
              if(uri.queryParameters.containsKey('lank')) {
                final lank = uri.queryParameters['lank'];
                mediaItem = getVideoItemFromLank(lank!, JwLifeSettings().currentLanguage.symbol);
              }

              showFullScreenVideo(context, mediaItem!);
            }

            // Annule la navigation pour gérer le lien manuellement
            return NavigationActionPolicy.CANCEL;
          }

          // Permet la navigation pour tous les autres liens
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
