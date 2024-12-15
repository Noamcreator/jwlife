import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../jwlife.dart';
import '../../utils/icons.dart';
import '../library_pages/publication_pages/publication_notes_view.dart';

class DailyTextPage extends StatefulWidget {
  final String data;

  const DailyTextPage({Key? key, required this.data}) : super(key: key);

  @override
  _DailyTextPageState createState() => _DailyTextPageState();
}

class _DailyTextPageState extends State<DailyTextPage> {
  bool _isLoading = true;
  double _textSize = 22.0;
  String _html = '';
  int docId = 502016177;
  Map<String, dynamic> publication = {};
  bool _showNotes = false;

  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    fetchTextOfTheDay();

    int currentYear = DateTime.now().year;
    String yearSuffix = (currentYear % 100).toString().padLeft(2, '0'); // Assurez-vous d'obtenir un format à deux chiffres

    publication = {
      'IssueTagNumber': 0,
      // on fait es + l'année (24 pour 2024)
      'KeySymbol': 'es$yearSuffix',
      'MepsLanguageId': JwLifeApp.currentLanguage.id
    };
  }

  Future<void> fetchTextOfTheDay() async {
    String languageSymbol = JwLifeApp.currentLanguage.symbol;
    try {
      final response = await http.get(Uri.parse('https://wol.jw.org/wol/finder?wtlocale=$languageSymbol&alias=daily-text&date=${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1)))}'));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        // Trouver l'élément contenant le verset du jour
        final element = document.querySelector('.tabContent');
        if (element != null) {
          setState(() {
            docId = 1102024209;
            _html = element.outerHtml;
          });
        } else {
          throw Exception('Element with class .themeScrp not found');
        }
      } else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Taille de police",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 1.0,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
                        ),
                        child: Slider(
                          value: _textSize, // Utilisez directement _textSize ici
                          min: 12.0,
                          max: 30.0,
                          divisions: 9,
                          onChanged: (double newValue) {
                            // Met à jour la valeur de _textSize
                            setState(() {
                              _textSize = newValue; // Met à jour la valeur locale
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // Affiche la valeur actuelle de _textSize
                    Text(
                      _textSize.toStringAsFixed(0), // Afficher la taille de police sélectionnée
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Optionnel : un aperçu pour voir la taille de police sélectionnée
                Text(
                  "Aperçu de la taille de police",
                  style: TextStyle(fontSize: _textSize), // Utilise _textSize ici
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Fermer le dialogue
                    },
                    child: Text('ANNULER'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      appBar: AppBar(
        title: Text(DateFormat('d MMMM yyyy', JwLifeApp.currentLanguage.primaryIetfCode).format(DateTime.now())),
        actions: [
          IconButton(
              icon: Icon(Icons.text_fields),
              onPressed: () {
                _showFontSizeDialog();
              }
          ),
          IconButton(
            // Icon rappel
              icon: Icon(Icons.punch_clock),
              onPressed: () {
                print('Pressed');
              }
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) : _showNotes
          ? PublicationNotesView(docId: docId)
          : InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('data:text/html,${Uri.encodeFull(_html)}')),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            useOnDownloadStart: true,
          ),
        ),
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
