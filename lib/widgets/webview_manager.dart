import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/directory_helper.dart';

class WebViewManager {
  WebViewManager._privateConstructor();
  static final WebViewManager instance = WebViewManager._privateConstructor();

  final GlobalKey<_WebViewPreloaderState> _preloadKey =
      GlobalKey<_WebViewPreloaderState>();

  Widget preloaderWidget() {
    return _WebViewPreloader(key: _preloadKey);
  }
}

class _WebViewPreloader extends StatefulWidget {
  const _WebViewPreloader({super.key});

  @override
  State<_WebViewPreloader> createState() => _WebViewPreloaderState();
}

class _WebViewPreloaderState extends State<_WebViewPreloader> {
  String? webappPath;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  /// Initialisation asynchrone du chemin des fichiers
  Future<void> _initPath() async {
    // Remplacement par un appel fictif si getAppFilesDirectory n'est pas accessible ici
    // Directory filesDirectory = await getAppFilesDirectory(); 
    
    // Simulation du comportement de ton utilitaire :
    final Directory filesDirectory = await getAppFilesDirectory();
    
    if (mounted) {
      setState(() {
        webappPath = '${filesDirectory.path}/webapp_assets';
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // On n'affiche rien tant que le chemin n'est pas résolu
    if (!_isReady || webappPath == null) {
      return const SizedBox.shrink();
    }

    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: """
              <!DOCTYPE html>
              <html>
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                  <link rel="stylesheet" href="jw-styles.css" />
                </head>
                <body></body>
              </html>
            """,
            baseUrl: WebUri('file://$webappPath/'),
          ),
          onWebViewCreated: (controller) {
            print("WebView de préchargement créée avec le path: $webappPath");
          },
        ),
      ),
    );
  }
}