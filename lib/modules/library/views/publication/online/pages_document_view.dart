import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/api.dart';
import 'publication_media_items_view.dart';
import '../local/publication_notes_view.dart';
import 'publication_svg_view.dart';

class PagesDocumentView extends StatefulWidget {
  final Map<String, dynamic> publication;
  final int currentIndex;
  final List<Map<String, dynamic>> navCards; // Ajoutez ce paramètre
  final ScrollController scrollController;

  const PagesDocumentView({Key? key, required this.publication, required this.currentIndex, required this.navCards, required this.scrollController}) : super(key: key);

  @override
  _PagesDocumentViewState createState() => _PagesDocumentViewState();
}

class _PagesDocumentViewState extends State<PagesDocumentView> {
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  List<Map<String, dynamic>> _blockRange = []; // Store the input fields here
  bool _isLoading = true;
  String _title = '';
  String _data = '';
  double _textSize = 22.0;
  html_dom.Document document = html_dom.Document();
  dynamic _pubJson = {};
  List<Map<String, String>> _images = [];
  bool _showNotes = false;
  bool _showVerseDialog = false;
  bool _imageMode = false;
  List<String> svgUrls = [];
  Map<String, double> _verseDialogPosition = {'x': 0, 'y': 0};
  double _scrollPosition = 0.0;
  late int _currentIndex = 0; // Pour suivre l'index de la publication actuelle


  @override
  void initState() {
    super.initState();
    _onPageChanged(widget.currentIndex);
  }

  Future<void> _loadInputFields(int currentIndex) async {
    int lang = JwLifeApp.settings.currentLanguage.id;
    var inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(widget.navCards[currentIndex]['docId']!, lang);
    print('inputFields: $inputFields');
    setState(() {
      _textInputs = inputFields; // Store the result in the variable
    });
  }

  Future<void> _loadBlockRange(int currentIndex) async {
    int lang = JwLifeApp.settings.currentLanguage.id;
    var blockRange = await JwLifeApp.userdata.getHighlightsFromDocId(widget.navCards[currentIndex]['docId']!, lang);
    print('blockRange: $blockRange');
    setState(() {
      _blockRange = blockRange; // Store the result in the variable
    });
  }

  Future<void> fetchData(String docLink) async {
    try {
      final uri = Uri.parse(docLink);
      final pathSegments = uri.pathSegments;
      final newPath = pathSegments.skip(1).join('/');

      final response = await Api.httpGetWithHeaders('https://wol.jw.org/$newPath');
      if (response.statusCode == 200) {

        final json = jsonDecode(response.body);

        setState(() {
          _title = html_parser.parse(json['title']).documentElement?.text ?? '';
          _data = json['content'];
        });
      }
      else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      fetchData(widget.navCards[_currentIndex]['link']!); // Charger les données de la publication en cours
      _images.clear();
      _loadInputFields(_currentIndex); // Charger les champs d'entrée pour la nouvelle publication
      _loadBlockRange(_currentIndex);
    });
  }

  @override
  void dispose() {
    widget.scrollController.dispose();
    super.dispose();
  }

  void _toggleNotesView() {
    setState(() {
      if (!_showNotes) {
        _scrollPosition = widget.scrollController.position.pixels;
      }
      _showNotes = !_showNotes;

      if (!_showNotes) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.scrollController.jumpTo(_scrollPosition);
        });
      }
    });
  }

  Future<void> fetchHyperlink(String docLink) async {
    try {
      final uri = Uri.parse(docLink);
      final pathSegments = uri.pathSegments;
      final newPath = pathSegments.skip(1).join('/');
      print('https://wol.jw.org/wol/' + newPath);

      final response = await http.get(Uri.parse('https://wol.jw.org/wol/' + newPath));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body); // Changez cela si nécessaire

        // Vérifiez que 'items' existe et récupérez le contenu
        if (jsonResponse['items'].isNotEmpty) {
          // Vérifie si un élément avec le 'docId' existe dans 'navCards'
          if (widget.navCards.any((e) => e['docId'] == jsonResponse['items'][0]['did'])) {
            _onPageChanged(widget.navCards.indexWhere((element) => element['docId'] == jsonResponse['items'][0]['did']));
          }
          else {
            // Sinon, met à jour l'état avec les nouvelles données
            setState(() {
              _pubJson = jsonResponse;
              _showVerseDialog = true;
            });
          }
        }
      }
      else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> closeVerseDialog() async {
    setState(() {
      _showVerseDialog = false;
    });
  }

  Future<void> switchImageMode() async {
    String link = widget.navCards[_currentIndex]['link']!;

    try {
      final response = await http.get(Uri.parse('https://wol.jw.org' + link));
      if (response.statusCode == 200) {
        document = html_parser.parse(response.body);

        final svgs = document.querySelectorAll('.lightbox');
        if (svgs.isNotEmpty) {
          setState(() {
            _imageMode = !_imageMode;
          });

          if (_imageMode) {
            for (var s in svgs) {
              svgUrls.add('https://wol.jw.org/' + s.attributes['src']!);
            }
          }
        }
      }
      else {
        throw Exception('Failed to load publication content');
      }
    } catch (e) {
      print('Error fetching publication content: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.publication['ShortTitle'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  child: Text('Langues'),
                  onTap: () {

                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Ajouter une note'),
                  onTap: () async {
                    int docId = widget.navCards[_currentIndex]['docId']!;
                    var note = await JwLifeApp.userdata.addNote(_title, '', 0, [], docId, widget.publication['IssueTagNumber'], widget.publication['KeySymbol'], widget.publication['MepsLanguageId']);

                    showPage(context, NoteView(note: note)).then((_) => _toggleNotesView());
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Voir les médias'),
                  onTap: () {
                    showPage(context, PublicationMediaItemsView(document: _data));
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Envoyer le lien'),
                  onTap: () {
                    int docId = widget.navCards[_currentIndex]['docId']!;
                    Share.share(
                      'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.publication['LanguageSymbol']}&prefer=lang&docid=$docId',
                      subject: widget.publication['ShortTitle'],
                    );
                  },
                ),
                PopupMenuItem<String>(
                  child: Text(_imageMode ? 'Mode Texte' : 'Mode Image'),
                  onTap: () {
                    switchImageMode();
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Taille de police'),
                  onTap: () {
                    _showFontSizeDialog();
                  },
                ),
              ];
          },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _imageMode ? PublicationSvgView(svgUrls: svgUrls) : _showNotes
          ? PublicationNotesView(document: widget.navCards[_currentIndex]['docId']!)
          : PageView.builder(
        controller: PageController(initialPage: _currentIndex),
        onPageChanged: _onPageChanged,
        itemCount: widget.navCards.length,
        itemBuilder: (context, index) {

          return Scrollbar(
            controller: widget.scrollController,
            thumbVisibility: true,
            thickness: 10.0,
            radius: const Radius.circular(8),
            interactive: true,
            child: Stack(
              children: [
              ],
            )
          );
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