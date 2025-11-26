import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewManager {
  // Singleton
  WebViewManager._privateConstructor();
  static final WebViewManager instance = WebViewManager._privateConstructor();

  final GlobalKey<_WebViewPreloaderState> _preloadKey =
  GlobalKey<_WebViewPreloaderState>();

  /// Widget à placer en haut de ton widget principal
  Widget preloaderWidget() {
    return _WebViewPreloader(key: _preloadKey);
  }
}

//////////////////////////////////////////////////////////////
///                WIDGET DE PRÉCHARGEMENT
//////////////////////////////////////////////////////////////

class _WebViewPreloader extends StatefulWidget {
  const _WebViewPreloader({super.key});

  @override
  State<_WebViewPreloader> createState() => _WebViewPreloaderState();
}

class _WebViewPreloaderState extends State<_WebViewPreloader> {
  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri("about:blank")),
        ),
      ),
    );
  }
}
