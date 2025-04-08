import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/utils/directory_helper.dart';

class DailyTextPage extends StatefulWidget {
  final Publication publication;

  const DailyTextPage({super.key, required this.publication});

  @override
  _DailyTextPageState createState() => _DailyTextPageState();
}

class _DailyTextPageState extends State<DailyTextPage> with SingleTickerProviderStateMixin {
  String _htmlContent = '';
  bool _showNotes = false;
  bool _isLoadingDatabase = false;
  bool _isLoadingWebView = false;

  String webappPath = '';

  late InAppWebViewController _controller;

  int _currentScrollPosition = 0;
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles

  late AnimationController _controllerAnimation;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _initializeDatabaseAndData();

    _controllerAnimation = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controllerAnimation, curve: Curves.easeIn);
  }

  Future<void> _initializeDatabaseAndData() async {
    try {
      Directory webApp = await getAppWebViewDirectory();
      webappPath = '${webApp.path}/webapp';

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
    dynamic document = await PubCatalog.getDatedDocumentForToday(widget.publication);

    final decodedHtml = decodeBlobContent(
      document!['Content'] as Uint8List,
      widget.publication.hash,
    );

    _htmlContent = createHtmlContent(
      decodedHtml,
      '''pub-${widget.publication.keySymbol} layout-reading layout-sidebar''',
      widget.publication,
      true
    );
  }

  void _toggleNotesView() {
    setState(() {
      _showNotes = !_showNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

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
                    baseUrl: WebUri('file://$webappPath/'),
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
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        DateFormat('d MMMM yyyy', JwLifeApp.settings.currentLanguage.primaryIetfCode).format(DateTime.now()),
                        style: textStyleTitle
                    ),
                    Text(
                        'Texte du jour',
                        style: textStyleSubtitle
                    ),
                  ],
                ),
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
