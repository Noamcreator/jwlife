import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../jwlife.dart';
import '../../utils/icons.dart';
import '../../utils/utils_document.dart';
import '../library_pages/publication_pages/publication_notes_view.dart';

class DailyTextPage extends StatefulWidget {
  final dynamic data;

  const DailyTextPage({super.key, required this.data});

  @override
  _DailyTextPageState createState() => _DailyTextPageState();
}

class _DailyTextPageState extends State<DailyTextPage> {
  String _htmlContent = '';
  bool _isLoading = true;
  int docId = 502016177;
  Map<String, dynamic> publication = {};
  bool _showNotes = false;
  bool _isLoadingDatabase = true;

  late InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();

    int currentYear = DateTime.now().year;
    String yearSuffix = (currentYear % 100).toString().padLeft(2, '0'); // Assurez-vous d'obtenir un format à deux chiffres

    publication = {
      'IssueTagNumber': 0,
      'KeySymbol': 'es$yearSuffix', // on fait es + l'année (24 pour 2024)
      'MepsLanguageId': JwLifeApp.currentLanguage.id,
      'DocumentId': docId,
      'Content': widget.data['Content'],
    };

    _initializeDatabaseAndData();
  }

  Future<void> _initializeDatabaseAndData() async {
    try {
      await fetchAllDocuments();
    }
    catch (e) {
      print('Error initializing database: $e');
    }
    finally {
      setState(() {
        _isLoadingDatabase = false;
      });
    }
  }

  Future<void> fetchAllDocuments() async {
    print('widget.data: ${widget.data['Class']}');
    _htmlContent = await createHtmlContent(
      widget.data['Content'],
      '''${widget.data['Class']} pub-${publication['KeySymbol']} layout-reading layout-sidebar''',
    );
  }

  void _toggleNotesView() {
    setState(() {
      _showNotes = !_showNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.white,
      appBar: AppBar(
        title: Text(DateFormat('d MMMM yyyy', JwLifeApp.currentLanguage.primaryIetfCode).format(DateTime.now())),
        actions: [
          IconButton(
              icon: Icon(Icons.punch_clock),
              onPressed: () {
                print('Pressed');
              }
          ),
        ],
      ),
      body: _isLoadingDatabase ?
      const Center(child: CircularProgressIndicator()) :
      Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
            ),
            initialData: InAppWebViewInitialData(
              data: _htmlContent,
              mimeType: 'text/html',
              baseUrl: WebUri('https://wol.jw.org/'),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _isLoading = progress < 100;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                _isLoading = false;
              });
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
