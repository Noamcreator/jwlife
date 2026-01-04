import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/realm/catalog.dart';

import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/api/api.dart';
import '../../../core/utils/directory_helper.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../core/utils/widgets_utils.dart';
import '../../../data/databases/catalog.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/video.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/dialog/publication_dialogs.dart';
import '../../../widgets/responsive_appbar_actions.dart';

class AlertsListPage extends StatefulWidget {
  final List<dynamic> alerts; // URL de l'alerte à afficher

  const AlertsListPage({super.key, required this.alerts});

  @override
  _AlertsListPageState createState() => _AlertsListPageState();
}

class _AlertsListPageState extends State<AlertsListPage> {
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
    WebViewSettings webViewData = JwLifeSettings.instance.webViewSettings;

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
    <html style="overflow: hidden;">
    <meta content="text/html" charset="UTF-8">
    <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <link rel="stylesheet" href="jw-styles.css" />
      <head>
        <meta charset="UTF-8">
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
      _language = JwLifeSettings.instance.libraryLanguage.value.vernacular;
      _languageSymbol = JwLifeSettings.instance.libraryLanguage.value.symbol;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().label_breaking_news,
        subTitle: _language,
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.language),
            onPressed: (BuildContext context) async {
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
      body: _isLoadingHtml ? getLoadingWidget(Theme.of(context).primaryColor) : InAppWebView(
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
            final issue = uri.queryParameters['issue'];
            final fileformat = uri.queryParameters['fileformat'];
            final langwritten = _languageSymbol;

            if ((pub != null || docId != null)) {
              showDocumentDialog(context, pub, docId, track, issue, langwritten, fileformat);
              return NavigationActionPolicy.CANCEL;
            }
          }
          else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
            JwOrgUri jwOrgUri = JwOrgUri.parse(uri.toString());
            printTime('Requested URL: $url');

            if(jwOrgUri.isPublication) {
              Publication? publication = await CatalogDb.instance.searchPub(jwOrgUri.pub!, jwOrgUri.issue!, jwOrgUri.wtlocale);
              if (publication != null) {
                publication.showMenu(context);
              }
            }
            else if (jwOrgUri.isMediaItem) {
              Duration startTime = Duration.zero;
              Duration? endTime;

              if (jwOrgUri.ts != null && jwOrgUri.ts!.isNotEmpty) {
                final parts = jwOrgUri.ts!.split('-');
                if (parts.isNotEmpty) {
                  startTime = JwOrgUri.parseDuration(parts[0]) ?? Duration.zero;
                }
                if (parts.length > 1) {
                  endTime = JwOrgUri.parseDuration(parts[1]);
                }
              }

              RealmMediaItem? mediaItem = getMediaItemFromLank(jwOrgUri.lank!, jwOrgUri.wtlocale);

              if (mediaItem == null) return NavigationActionPolicy.ALLOW;

              if(mediaItem.type == 'AUDIO') {
                Audio audio = Audio.fromJson(mediaItem: mediaItem);
                audio.showPlayer(context, initialPosition: startTime);
              }
              else {
                Video video = Video.fromJson(mediaItem: mediaItem);
                video.showPlayer(context, initialPosition: startTime);
              }
            }
            else {
              if(await hasInternetConnection(context: context)) {
                return NavigationActionPolicy.ALLOW;
              }
              else {
                return NavigationActionPolicy.CANCEL;
              }
            }

            // Annule la navigation pour gérer le lien manuellement
            return NavigationActionPolicy.CANCEL;
          }
          // On vérifie que c'est bien un lien vers le web et qu'on a une connexion internet
          else if(url.startsWith('https://')) {
            // Permet la navigation pour tous les autres liens
            if(await hasInternetConnection(context: context)) {
              return NavigationActionPolicy.ALLOW;
            }
            else {
              return NavigationActionPolicy.CANCEL;
            }
          }
          return NavigationActionPolicy.CANCEL;
        },
      ),
    );
  }
}
