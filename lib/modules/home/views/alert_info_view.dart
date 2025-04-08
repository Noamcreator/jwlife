import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';

import '../../../app/jwlife_app.dart';
import '../../../widgets/dialog/language_dialog.dart';

class AlertInfoPage extends StatefulWidget {
  final List<dynamic> alerts; // URL de l'alerte à afficher

  const AlertInfoPage({Key? key, required this.alerts}) : super(key: key);

  @override
  _AlertInfoPageState createState() => _AlertInfoPageState();
}

class _AlertInfoPageState extends State<AlertInfoPage> {
  String language = '';
  late InAppWebViewController webViewController;
  String _html = '';

  @override
  void initState() {
    super.initState();
    setLanguage();
    _html = convertAlertsToHtml(widget.alerts);
  }

  String convertAlertsToHtml(List<dynamic> alerts) {
    WebViewData webViewData = JwLifeApp.settings.webViewData;
    final fontSize = 22;

    print('WebViewData: $alerts');

    String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
        <style>
          body {
            font-size: ${fontSize}px;
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
      language = JwLifeApp.settings.currentLanguage.vernacular;
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
                print('Language selected: $value');
              });
            },
          )
        ],
      ),
      body: InAppWebView(
        initialSettings: InAppWebViewSettings(
          cacheMode: CacheMode.LOAD_NO_CACHE,
          verticalScrollbarThumbColor: Theme.of(context).primaryColor,
          verticalScrollBarEnabled: false,
          allowUniversalAccessFromFileURLs: true,
          cacheEnabled: false,
        ),
        initialData: InAppWebViewInitialData(
          data: _html,
          mimeType: 'text/html',
          baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'),
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

            showDocumentDialog(context, docId!, track!, langwritten!, fileformat!);

            return NavigationActionPolicy.CANCEL;
          }
          else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
            if (uri.queryParameters.containsKey('lank')) {
              MediaItem? mediaItem;
              if(uri.queryParameters.containsKey('lank')) {
                final lank = uri.queryParameters['lank'];
                mediaItem = getVideoItemFromLank(lank!, JwLifeApp.settings.currentLanguage.symbol);
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
