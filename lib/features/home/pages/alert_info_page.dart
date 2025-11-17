import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as http hide Response;
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/realm/catalog.dart';

import '../../../app/services/settings_service.dart';
import '../../../core/api/api.dart';
import '../../../core/utils/directory_helper.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/databases/catalog.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/video.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/dialog/publication_dialogs.dart';

class AlertInfoPage extends StatefulWidget {
  final List<dynamic> alerts; // URL de l'alerte à afficher

  const AlertInfoPage({super.key, required this.alerts});

  @override
  _AlertInfoPageState createState() => _AlertInfoPageState();
}

class _AlertInfoPageState extends State<AlertInfoPage> {
  String _language = '';
  String _languageSymbol = '';

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
      Directory filesDirectory = await getAppFilesDirectory();
      webappPath = '${filesDirectory.path}/webapp_assets';

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

    String htmlAlerts = '';

    // --- MODIFICATION ICI ---
    if (alerts.isEmpty) {
      // Message à afficher quand il n'y a pas d'alerte
      htmlAlerts = '''
        <div style="padding: 20px; text-align: center; color: ${webViewData.theme == 'dark' ? '#c3c3c3' : '#626262'};">
          <p style="font-size: 1.1em; margin-bottom: 10px;">
            Aucune alerte d'information disponible dans cette langue.
          </p>
          <p style="font-size: 0.9em;">
            Veuillez vérifier ultérieurement.
          </p>
        </div>
      ''';
    } else {
      // Générer le HTML pour chaque alerte existante
      for (var alert in alerts) {
        String title = alert['title'] ?? 'Sans titre';
        String body = alert['body'] ?? '';

        htmlAlerts += '''
          <div class="alertItem">
            <h3>$title</h3>
            <p>$body</p>
          </div> 
        ''';
      }
    }
    // -------------------------

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
      <body class='${webViewData.theme}'>
        <main role="main" id="content" class="topWhiteSpace">
          <article id="article" class="jwac layout-reading layout-sidebar">
            <div id="newsAlerts" class="jsAlertModule alertContainer cms-clearfix jsAlertsLoaded">
              <div class="jsAlertList">
                $htmlAlerts
              </div> 
            </div> 
          </article>
        </main>
      </body>   
    </html>
  ''';

    return htmlContent;
  }


  void setLanguage() async {
    setState(() {
      _language = JwLifeSettings().currentLanguage.vernacular;
      _languageSymbol = JwLifeSettings().currentLanguage.symbol;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n().label_breaking_news,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _language,
              style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFc3c3c3)
                  : const Color(0xFF626262))
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              showLanguageDialog(context).then((language) async {
                final queryParams = {
                  'type': 'news',
                  'lang': language['Symbol'],
                  'context': 'homePage',
                };

                // Construire l'URI avec les paramètres
                final url = Uri.https('b.jw-cdn.org', '/apis/alerts/list', queryParams);

                try {
                  // Préparer les headers pour la requête avec l'autorisation
                  Map<String, String> headers = {
                    'Authorization': 'Bearer ${Api.currentJwToken}',
                  };

                  // Faire la requête HTTP pour récupérer les alertes
                  http.Response alertResponse = await http.get(url, headers: headers);

                  if (alertResponse.statusCode == 200) {
                    // La requête a réussi, traiter la réponse JSON
                    final data = jsonDecode(alertResponse.body);

                    setState(() {
                      _language = language['VernacularName'];
                      _languageSymbol = language['Symbol'];
                    });

                    _htmlContent = convertAlertsToHtml(data['alerts']);
                    webViewController.loadData(data: _htmlContent, mimeType: 'text/html', baseUrl: WebUri('file://$webappPath/'), );
                  }
                  else {
                    // Gérer une erreur de statut HTTP
                    printTime('Erreur de requête HTTP: ${alertResponse.statusCode}');
                  }
                }
                catch (e) {
                  // Gérer les erreurs lors des requêtes
                  printTime('Erreur lors de la récupération des données de l\'API: $e');
                }
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

          if(url.startsWith('jwpub://')) {
            return NavigationActionPolicy.CANCEL;
          }
          else if (url.startsWith('webpubdl://')) {
            final uri = Uri.parse(url);

            final pub = uri.queryParameters['pub']?.toLowerCase();
            final docId = uri.queryParameters['docid'];
            final track = uri.queryParameters['track'];
            final fileformat = uri.queryParameters['fileformat'];
            final langwritten = _languageSymbol;

            if ((pub != null || docId != null) && fileformat != null) {
              showDocumentDialog(context, pub, docId, track, langwritten, fileformat);
              return NavigationActionPolicy.CANCEL;
            }
          }
          else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
            printTime('Requested URL: $url');
            final wtlocale = _languageSymbol;
            if (uri.queryParameters.containsKey('lank')) {
              MediaItem? mediaItem;
              if(uri.queryParameters.containsKey('lank')) {
                final lank = uri.queryParameters['lank'];
                mediaItem = getMediaItemFromLank(lank!, wtlocale!);
              }

              Video video = Video.fromJson(mediaItem: mediaItem!);
              video.showPlayer(context);
            }
            else if (uri.queryParameters.containsKey('pub')) {
              // Récupère les paramètres
              final pub = uri.queryParameters['pub']?.toLowerCase();
              final issueTagNumber = uri.queryParameters.containsKey('issueTagNumber') ? int.parse(uri.queryParameters['issueTagNumber']!) : 0;

              Publication? publication = await PubCatalog.searchPub(pub!, issueTagNumber, wtlocale);
              if (publication != null) {
                await publication.showMenu(context);
              }
            }
            else if (uri.queryParameters.containsKey('docid')) {
              final docid = uri.queryParameters['docid'];

              return NavigationActionPolicy.ALLOW;
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
