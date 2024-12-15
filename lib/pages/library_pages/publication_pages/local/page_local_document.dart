import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../utils/icons.dart';
import '../../../../utils/utils_jwpub.dart';
import '../../../../utils/utils_document.dart';

class PageLocalDocumentView extends StatefulWidget {
  final Map<String, dynamic> publication;
  final int documentId;

  const PageLocalDocumentView({
    super.key,
    required this.publication,
    required this.documentId,
  });

  @override
  _PageLocalDocumentViewState createState() => _PageLocalDocumentViewState();
}

class _PageLocalDocumentViewState extends State<PageLocalDocumentView> {
  Database? _database;
  Map<String, dynamic> _document = {};
  bool _isLoadingDatabase = true;

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndData();
  }

  Future<void> _initializeDatabaseAndData() async {
    try {
      _database = await openDatabase(widget.publication['DatabasePath']);
      await fetchAllDocuments();
    } catch (e) {
      print('Error initializing database: $e');
    } finally {
      setState(() {
        _isLoadingDatabase = false;
      });
    }
  }

  Future<void> fetchAllDocuments() async {
    try {
      List<Map<String, dynamic>> response = await _database!.query('Document');

      for (var document in response) {
        if (document['Id'] == widget.documentId) {
          final contentBlob = document['Content'] as Uint8List;
          final decodedHtml = await decodeBlobContentWithHash(
            contentBlob: contentBlob,
            hashPublication: widget.publication['Hash'],
          );

          Map<String, dynamic> newDocument = Map<String, dynamic>.from(document);
          newDocument['Content'] = decodedHtml;
          _document = newDocument;
        }
      }
    } catch (e) {
      print('Error fetching all documents: $e');
    }
  }

  Future<String?> _getImagePathFromDatabase(String url) async {
    List<Map<String, dynamic>> imageName = await _database!.rawQuery(
      'SELECT FilePath FROM Multimedia WHERE LOWER(FilePath) = ?',
      [url.toLowerCase()],
    );

    if (imageName.isNotEmpty) {
      return widget.publication['Path'] + '/' + imageName.first['FilePath'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111111)
          : Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.publication['ShortTitle'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoadingDatabase
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<String>(
        future: createHtmlContent(
          context,
          _document['Content'],
          '''jwac docClass-${_document['Class']} docId-${_document['MepsDocumentId']} ms-ROMAN ml-${widget.publication['LanguageSymbol']} dir-ltr pub-${widget.publication['KeySymbol']} layout-reading layout-sidebar''',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading document.'));
          }

          return InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
            ),
            initialData: InAppWebViewInitialData(
              data: snapshot.data!,
              mimeType: 'text/html',
            ),
            shouldInterceptRequest: (controller, request) async {
              String requestedUrl = '${request.url}';
              if (requestedUrl.startsWith('jwpub-media://')) {
                final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                final imagePath = await _getImagePathFromDatabase(filePath);

                if (imagePath != null) {
                  final imageData = await File(imagePath).readAsBytes();
                  return WebResourceResponse(
                    contentType: 'image/jpeg',
                    data: imageData,
                    statusCode: 200,
                    reasonPhrase: "OK",
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}