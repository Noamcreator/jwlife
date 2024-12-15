import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../utils/icons.dart';
import '../library_pages/publication_pages/publication_notes_view.dart';

class WatchTowerPage extends StatefulWidget {
  final String html;
  final int docId;

  const WatchTowerPage({Key? key, required this.html, required this.docId}) : super(key: key);

  @override
  _WatchTowerPageState createState() => _WatchTowerPageState();
}

class _WatchTowerPageState extends State<WatchTowerPage> {
  bool _showNotes = false;
  late InAppWebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  void _toggleNotesView() {
    setState(() {
      _showNotes = !_showNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showNotes
          ? PublicationNotesView(docId: widget.docId)
          : InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('data:text/html,${Uri.encodeFull(widget.html)}')),
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
        onProgressChanged: (controller, progress) {
          if (progress == 100) {
            setState(() {
              _isLoading = false;
            });
          }
        },
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
