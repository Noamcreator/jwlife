import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/jwlife_app.dart';
import '../../../widgets/dialog/language_dialog_pub.dart';
import '../../personal/views/note_view.dart';

class DailyTextPage extends StatefulWidget {
  final dynamic data;

  const DailyTextPage({super.key, required this.data});

  @override
  _DailyTextPageState createState() => _DailyTextPageState();
}

class _DailyTextPageState extends State<DailyTextPage> with SingleTickerProviderStateMixin {
  String _htmlContent = '';
  int docId = 502016177;
  Map<String, dynamic> publication = {};
  bool _showNotes = false;
  bool _isLoadingDatabase = false;
  bool _isLoadingWebView = false;

  late InAppWebViewController _controller;

  int _currentScrollPosition = 0;
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles

  late AnimationController _controllerAnimation;
  late Animation<double> _animation;

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

    _controllerAnimation = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controllerAnimation, curve: Curves.easeIn);
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
        _isLoadingDatabase = true;
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
      body: Stack(
        children: [
          FadeTransition(
              opacity: _animation,
              child: _isLoadingDatabase ? InAppWebView(
                  initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useHybridComposition: true,
                      allowFileAccess: true,
                      allowContentAccess: true,
                      cacheMode: CacheMode.LOAD_NO_CACHE,
                      allowUniversalAccessFromFileURLs: true
                  ),
                  initialData: InAppWebViewInitialData(
                    data: _htmlContent,
                    mimeType: 'text/html',
                    baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'),
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },

                  onScrollChanged: (controller, x, y) {
                    // Si la différence est plus grande que 2 pour que l'état change
                    if (y > _currentScrollPosition) {
                      // Quand on descend
                      if (_controlsVisible) {
                        //JwLifeView.toggleNavBarVisibility.call(false);
                        setState(() {
                          _controlsVisible = false;
                        });
                      }
                    }
                    else if (y < _currentScrollPosition) {
                      // Quand on monte
                      if (!_controlsVisible) {
                        //JwLifeView.toggleNavBarVisibility.call(true);
                        setState(() {
                          _controlsVisible = true;
                        });
                      }
                    }
                    _currentScrollPosition = y;
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _isLoadingWebView = true;
                      _controllerAnimation.forward(); // Démarrer l'animation une fois le chargement terminé
                    });
                  }
              ) : Container(),
          ),
          if (!_isLoadingDatabase || !_isLoadingWebView) const Center(child: CircularProgressIndicator()),
          if (_isLoadingDatabase && _controlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                title: Text(DateFormat('d MMMM yyyy', JwLifeApp.currentLanguage.primaryIetfCode).format(DateTime.now())),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if(_showNotes) {
                      _toggleNotesView();
                    }
                    else {
                      Navigator.pop(context);
                    }
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(JwIcons.magnifying_glass),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(JwIcons.language),
                    onPressed: () {
                      /*
                      LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: widget.publication);
                      showDialog(
                        context: context,
                        builder: (context) => languageDialog,
                      ).then((value) {
                        if (value != null) {
                          showPage(context, PublicationMenu(publication: widget.publication, publicationLanguage: value));
                        }
                      }
                      );

                       */
                    },
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        child: Text('Ajouter une note'),
                        onTap: () async {
                          /*
                          String title = _document['Title'] ?? '';
                          int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                          var note = await JwLifeApp.userdata.addNote(title, '', 0, [], mepsDocumentId, widget.publication['IssueTagNumber'], widget.publication['KeySymbol'], widget.publication['MepsLanguageId']);

                          showPage(context, NotePage(note: note)).then((_) => {
                            //_toggleNotesView()
                          });

                           */
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Voir les médias'),
                        onTap: () {
                          showPage(context, Container());
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Envoyer le lien'),
                        onTap: () {
                          /*
                          int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                          Share.share(
                            'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.publication['LanguageSymbol']}&prefer=lang&docid=$mepsDocumentId',
                            subject: widget.publication['Title'],
                          );

                           */
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Taille de police'),
                        onTap: () {
                          Future.delayed(
                            Duration.zero,
                                () => showFontSizeDialog(context, _controller),
                          );
                        },
                      ),
                    ],
                  )
                ],
              ),
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
