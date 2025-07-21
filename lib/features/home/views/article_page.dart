import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/utils.dart';

class ArticlePage extends StatefulWidget {
  final String title;
  final String link;

  const ArticlePage({Key? key, required this.title, required this.link}) : super(key: key);

  @override
  _ArticlePageState createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  String _htmlContent = '';
  bool _showNotes = false;
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

  void _toggleNotesView() {
    setState(() {
      _showNotes = !_showNotes;
    });
  }

  Future<String?> _getImagePathFromDatabase(String url) async {
    // Mettre l'URL en minuscule
    File articlesFile = await getArticlesFile();
    Database db = await openDatabase(articlesFile.path);
    List<Map<String, dynamic>> imageName = await db.rawQuery(
        'SELECT Path FROM Image WHERE LOWER(Name) = ?', [url]
    );

    // Si une correspondance est trouvée, retourne le chemin
    if (imageName.isNotEmpty) {
      return imageName.first['Path'];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useHybridComposition: true,
              cacheEnabled: false,
              clearCache: true,
              cacheMode: CacheMode.LOAD_NO_CACHE,
              allowUniversalAccessFromFileURLs: true,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleNotesView,
        elevation: 6.0,
        shape: const CircleBorder(),
        child: Icon(
          _showNotes ? JwIcons.arrow_to_bar_right : JwIcons.gem,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
