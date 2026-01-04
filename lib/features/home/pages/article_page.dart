import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/ui/text_styles.dart';

import '../../../app/app_page.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/widgets_utils.dart';

class ArticlePage extends StatefulWidget {
  final String title;
  final String link;

  const ArticlePage({super.key, required this.title, required this.link});

  @override
  _ArticlePageState createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  // On initialise à true pour montrer le chargement dès l'entrée sur la page
  bool _isLoading = true;
  late InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await createHtmlWithClass();
    } catch (e) {
      printTime('Error initializing: $e');
    }
    // Note: On ne passe pas _isLoading à false ici, 
    // on laisse le WebView s'en charger via onLoadStop.
  }

  Future<void> createHtmlWithClass() async {
    // Ta logique de préparation de contenu si nécessaire
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return AppPage(
      appBar: JwLifeAppBar(
        title: widget.title,
        subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.articlesLanguage, builder: (context, value, child) {
          return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
        }),
      ),
      body: Stack(
        children: [
          // Le WebView est toujours présent en fond
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useHybridComposition: true,
              hardwareAcceleration: true,
              cacheEnabled: false,
              clearCache: true,
              cacheMode: CacheMode.LOAD_NO_CACHE,
              allowUniversalAccessFromFileURLs: true,
              minimumViewportInset: EdgeInsets.zero,
              maximumViewportInset: EdgeInsets.zero,
            ),
            initialUrlRequest: URLRequest(
              url: WebUri(widget.link),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                _isLoading = false;
              });
            },
            onReceivedError: (controller, request, error) {
              setState(() {
                _isLoading = false;
              });
              printTime("WebView Error: ${error.description}");
            },
            shouldInterceptRequest: (controller, request) async {
              // Ton code de gestion jwpub-media:// si activé
              return null;
            },
          ),

          // L'indicateur de chargement s'affiche par-dessus
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: getLoadingWidget(primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}