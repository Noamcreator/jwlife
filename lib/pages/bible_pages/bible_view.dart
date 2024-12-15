import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../utils/icons.dart';
import '../bible_page.dart';
import 'bible_chapter.dart';

class BibleView extends StatefulWidget {
  final Book book;
  final Chapter chapter;

  const BibleView({Key? key, required this.book, required this.chapter}) : super(key: key);

  @override
  _BibleViewState createState() => _BibleViewState();
}

class _BibleViewState extends State<BibleView> {
  bool _isLoading = true;
  String _html = '';
  late InAppWebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String link = 'https://wol.jw.org/' + widget.chapter.link.substring(3);
      print(link);
      final response = await http.get(Uri.parse(link));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Vérifiez que 'content' existe et récupérez le contenu
        if (jsonResponse['content'].isNotEmpty) {
          setState(() {
            _html = jsonResponse['content'];
          });
        }
      } else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
      // Gérer l'erreur et afficher un message si nécessaire
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book.name} ${widget.chapter.number}', style: TextStyle(fontWeight: FontWeight.bold)), // bold font
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('data:text/html;base64,${base64Encode(utf8.encode(_html))}')),
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
        onPressed: () {
          // Handle floating action button press
        },
        shape: CircleBorder(),
        child: Icon(JwIcons.gem,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white
        ),
      ),
    );
  }
}
