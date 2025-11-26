import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/app/services/settings_service.dart';

import '../../../app/app_page.dart';
import '../../../core/utils/utils.dart';

class ArticlePage extends StatefulWidget {
  final String title;
  final String link;

  const ArticlePage({Key? key, required this.title, required this.link}) : super(key: key);

  @override
  _ArticlePageState createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  bool _isLoading = false;
  late InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await createHtmlWithClass();
    }
    catch (e) {
      printTime('Error initializing database: $e');
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> createHtmlWithClass() async {
    /*
    _htmlContent = createHtmlContent(
      widget.link,
      '''jwac showRuby ml-F ms-ROMAN dir-ltr layout-reading layout-sidebar''',
      false
    );

     */
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: JwLifeAppBar(
        title: widget.title,
        subTitle: JwLifeSettings.instance.currentLanguage.value.vernacular
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
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
              url: WebUri(widget.link), // Assurez-vous que widget.link est une URL valide
            ),
            /*
            initialData: InAppWebViewInitialData(
              data: _htmlContent,
              mimeType: 'text/html',
              baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'),
            ),
             */
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            shouldInterceptRequest: (controller, request) async {
              /*
              String requestedUrl = 'requestedUrl: ${request.url}';
              printTime(requestedUrl);
              if (requestedUrl.startsWith('jwpub-media://')) {
                final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                final imagePath = await _getImagePathFromDatabase(filePath);

                if (imagePath != null) {
                  final imageData = await File(imagePath).readAsBytes();
                  return WebResourceResponse(
                      contentType: 'image/jpeg',
                      data: imageData
                  );
                }
              }

               */
              return null;
            },
          ),
        ],
      ),
    );
  }
}
