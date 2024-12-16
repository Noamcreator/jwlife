import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../jwlife.dart';
import '../../../../utils/icons.dart';
import '../../../../utils/utils_jwpub.dart';
import '../../../../utils/utils_document.dart';
import '../../../../utils/utils_publication.dart';
import '../../../../video/FullScreenVideoPlayer.dart';
import '../../../../widgets/contextMenu.dart';
import '../../../../widgets/publication/publication_dialogs.dart';
import '../../../home_pages/search_pages/search_page.dart';
import '../../../personal_page/note_page.dart';
import '../publication_notes_view.dart';
import 'full_screen_image_view_local.dart';

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
  late InAppWebViewController _controller;
  String _htmlContent = '';
  Map<String, dynamic> _document = {};
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _svgs = [];
  bool _isImageMode = false;
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  List<Map<String, dynamic>> _blockRange = []; // Store the input fields here
  bool _isLoadingDatabase = true;

  /* OTHER VIEW */
  bool _showNotes = false;
  dynamic _pubJson = {};
  bool _showVerseDialog = false;
  Map<String, double> _verseDialogPosition = {'x': 0, 'y': 0};

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndData();
  }

  Future<void> _initializeDatabaseAndData() async {
    try {
      _database = await openDatabase(widget.publication['DatabasePath']);
      fetchImages();
      fetchSvgs();
      await fetchAllDocuments();
    }
    catch (e) {
      print('Error initializing database: $e');
    } finally {
      setState(() {
        _isLoadingDatabase = false;
      });
    }
  }

  Future<void> fetchImages() async {
    try {
      List<Map<String, dynamic>> images = [];

      // Récupérer les données de la base
      List<Map<String, dynamic>> response = await _database!.rawQuery('''
    SELECT 
      Multimedia.*,
      LinkedMultimedia.FilePath AS VideoFilePath,
      LinkedMultimedia.KeySymbol AS VideoKeySymbol,
      LinkedMultimedia.Track AS VideoTrack
    FROM Document
    INNER JOIN DocumentMultimedia ON Document.DocumentId = DocumentMultimedia.DocumentId
    INNER JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
    LEFT JOIN Multimedia AS LinkedMultimedia ON Multimedia.MultimediaId = LinkedMultimedia.LinkMultimediaId
    WHERE Document.DocumentId = ? 
      AND (Multimedia.CategoryType = 8 OR Multimedia.CategoryType = 15)
    ''', [widget.documentId]);

      if (response.isNotEmpty) {
        for (Map<String, dynamic> item in response) {
          // Si le CategoryType est différent de -1, on ajoute l'image ou vidéo
          if (item['CategoryType'] != -1) {
            images.add({
              'path': item['FilePath'],
              'imagePath': widget.publication['Path'] + '/' + item['FilePath'],
              'description': item['Label'],
              'caption': item['Caption'],
              'type': item['SuppressZoom'] == 1 ? 'video' : 'image',
              'videoMultimedia': {
                // Récupération des informations du "LinkMultimedia" si elles existent
                'filePath': item['VideoFilePath'],
                'pubSymbol': item['VideoKeySymbol'],
                'track': item['VideoTrack'],
              },
            });
          }
        }

        for(dynamic image in images) {
          print(image);
        }

        setState(() {
          _images = images;
        });
      } else {
        throw Exception('No images found for the document.');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchSvgs() async {
    try {
      // Récupérer les données de la base
      List<Map<String, dynamic>> response = await _database!.rawQuery('''
  SELECT Multimedia.*
  FROM Document
  INNER JOIN DocumentMultimedia ON Document.DocumentId = DocumentMultimedia.DocumentId
  INNER JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
  WHERE Document.DocumentId = ? AND Multimedia.MimeType = 'image/svg+xml'
''', [widget.documentId]);

      if (response.isNotEmpty) {
        setState(() {
          _svgs = response;
        });
      }
    }
    catch (e) {
      print('Error: $e');
    }
  }

  Future<void> loadUserdata() async {
    int lang = widget.publication['MepsLanguageId'];
    int mepsDocumentId = _document['MepsDocumentId'];
    var inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(mepsDocumentId, lang);
    var blockRange = await JwLifeApp.userdata.getHightlightsFromDocId(mepsDocumentId, lang);
    print('inputFields: $inputFields');
    print('blockRange: $blockRange');
    setState(() {
      _textInputs = inputFields; // Store the result in the variable
      _blockRange = blockRange; // Store the result in the variable
    });
  }

  Future<void> fetchHyperlink(String link) async {
    try {
      List<Map<String, dynamic>> response = [];
      if (link.contains('jwpub://b')) {
        // Récupérer les données de la base
        response = await _database!.query(
          'Hyperlink INNER JOIN BibleCitation ON Hyperlink.Link = BibleCitation.HyperlinkId',
          where: 'Hyperlink.Link = ?',
          whereArgs: [link],
        );

        print('response: ${response.first}');
      }
      else if (link.contains('jwpub://p')) {
        response = await _database!.rawQuery('''
  SELECT 
    Extract.Content,
    Extract.Caption,
    RefPublication.Title
  FROM Extract
  INNER JOIN DocumentExtract ON Extract.ExtractId = DocumentExtract.ExtractId
  INNER JOIN Hyperlink ON Hyperlink.HyperlinkId = DocumentExtract.HyperlinkId
  INNER JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
  WHERE DocumentExtract.DocumentId = ? AND Hyperlink.Link = ?
''', [widget.documentId, link]);
      }

      if (response.isNotEmpty) {
        final extract = response.first;

        /// Décoder le contenu
        final decodedHtml = await decodeBlobContent(
          contentBlob: extract['Content'] as Uint8List,
          languageId: widget.publication['MepsLanguageId'],
          symbol: widget.publication['Symbol'],
          year: widget.publication['Year'],
          issueTagNumber: widget.publication['IssueTagNumber'],
        );

        dynamic document = {
          'items': [
            {
              'title': extract['Caption'],
              'content': decodedHtml,
              'hideThumbnailImage': false,
              'publicationTitle': extract['Title']
            }
          ],
          'title': 'Extrait de publication',
        };

        // Vérifie si un élément avec le 'docId' existe dans 'navCards'
        setState(() {
          _pubJson = document;
          _showVerseDialog = true;
        });
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

  Future<String?> _getImagePathFromDatabase(String url) async {
    // Mettre l'URL en minuscule
    List<Map<String, dynamic>> imageName = await _database!.rawQuery(
        'SELECT FilePath FROM Multimedia WHERE LOWER(FilePath) = ?', [url]
    );

    // Si une correspondance est trouvée, retourne le chemin
    if (imageName.isNotEmpty) {
      return widget.publication['Path'] + '/' + imageName.first['FilePath'];
    }
    return '';
  }


  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last;
    Map<String, dynamic> image = _images.firstWhere((img) => img['path'] == newPath);

    JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
          return FullScreenImageViewLocal(
              images: _images,
              image: image
          );
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> switchImageMode() async {
    if (_isImageMode) {
      _controller.loadData(data: _htmlContent, baseUrl: WebUri('https://wol.jw.org/'));
      setState(() {
        _isImageMode = false;
      });
    }
    else {
      String path = widget.publication['Path'] + '/' + _svgs[0]['FilePath'];
      File file = File(path);
      String colorBackground = Theme.of(context).brightness == Brightness.dark ? '#202020' : '#ecebe7';
      String svgBase64 = base64Encode(file.readAsBytesSync());
      String base64Html = '''
<html>
  <body style="margin:0;padding:0;background-color:$colorBackground;display:flex;align-items:center;justify-content:center;">
    <div style="background-color:#ffffff;height:65%;box-shadow:0 4px 10px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;">
      <img src="data:image/svg+xml;base64,$svgBase64" style="width:100%;height:100%;object-fit:contain;" />
    </div>
  </body>
</html>
''';
      _controller.loadData(data: base64Html, mimeType: 'text/html', encoding: 'utf8');
      setState(() {
        _isImageMode = true;
      });
    }
  }

  Future<void> fetchAllDocuments() async {
    try {
      List<Map<String, dynamic>> response = await _database!.query('Document');

      for (var document in response) {
        if (document['DocumentId'] == widget.documentId) {
          final contentBlob = document['Content'] as Uint8List;
          final decodedHtml = await decodeBlobContentWithHash(
            contentBlob: contentBlob,
            hashPublication: widget.publication['Hash'],
          );

          _htmlContent = await createHtmlContent(
            context,
            decodedHtml,
            '''jwac docClass-${_document['Class']} docId-${_document['MepsDocumentId']} ms-ROMAN ml-${widget.publication['LanguageSymbol']} dir-ltr pub-${widget.publication['KeySymbol']} layout-reading layout-sidebar''',
          );
          Map<String, dynamic> newDocument = Map<String, dynamic>.from(document);
          newDocument['Content'] = _htmlContent;
          _document = newDocument;
        }
      }
    } catch (e) {
      print('Error fetching all documents: $e');
    }
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
              _document['Title'] ?? '',
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
            itemBuilder: (context) => [
              getPubLanguagesItem(context, "Langues", widget.publication),
              PopupMenuItem<String>(
                child: Text('Ajouter une note'),
                onTap: () async {
                  String title = _document['Title'] ?? '';
                  int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                  var note = await JwLifeApp.userdata.addNote(title, '', 0, [], mepsDocumentId, widget.publication['IssueTagNumber'], widget.publication['KeySymbol'], widget.publication['MepsLanguageId']);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return NotePage(note: note);
                      },
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  ).then((_) => {
                    //_toggleNotesView()
                  });
                },
              ),
              PopupMenuItem<String>(
                child: Text('Voir les médias'),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return Container();
                      },
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
              PopupMenuItem<String>(
                child: Text('Envoyer le lien'),
                onTap: () {
                  int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                  Share.share(
                    'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.publication['LanguageSymbol']}&prefer=lang&docid=$mepsDocumentId',
                    subject: widget.publication['Title'],
                  );
                },
              ),
              if (_svgs.isNotEmpty)
                PopupMenuItem<String>(
                  child: _isImageMode ? Text('Mode Texte') : Text('Mode Image'),
                  onTap: () {
                    switchImageMode();
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
          ),
        ],
      ),
      body: _isLoadingDatabase
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
            InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
            ),
            initialData: InAppWebViewInitialData(
              data: _htmlContent,
              mimeType: 'text/html',
              baseUrl: WebUri('https://wol.jw.org/'),
            ),
            contextMenu: ContextMenu(
                menuItems: [
                  ContextMenuItem(
                      id: 1,
                      title: "Surligner",
                      action: () async {
                        print("Surligner clicked");
                      }),
                  ContextMenuItem(
                      id: 2,
                      title: "Note",
                      action: () async {
                        print("Add note clicked");
                      }),
                  ContextMenuItem(
                      id: 3,
                      title: "Surprimer",
                      action: () async {
                      }),
                  ContextMenuItem(
                      id: 4,
                      title: "Copier",
                      action: () async {
                        _controller.getSelectedText().then((value) => Clipboard.setData(ClipboardData(text: value.toString())));
                      }),
                  ContextMenuItem(
                      id: 6,
                      title: "Chercher",
                      action: () async {
                        String query = await _controller.getSelectedText() ?? "";
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                              return SearchPage(query: query);
                            },
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      }),
                ],
                settings: ContextMenuSettings(
                    hideDefaultSystemContextMenuItems: true
                ),
                onCreateContextMenu: (hitTestResult) async {
                  String selectedText = await _controller.getSelectedText() ?? "";
                  // save to Database
                },
                onContextMenuActionItemClicked: (menuItem) async {
                  await _controller.evaluateJavascript(
                      source: """
                                window.getSelection().removeAllRanges();
                          """);
                }
            ),
            onWebViewCreated: (controller) async {
              _controller = controller;

              // Gestionnaire pour les clics sur les images
              controller.addJavaScriptHandler(
                handlerName: 'onImageClick',
                callback: (args) async {
                  _openFullScreenImageView(args[0]); // Gérer l'affichage de l'image
                },
              );

              // Gestionnaire pour les clics sur les paragraphes
              controller.addJavaScriptHandler(
                handlerName: 'onParagraphClick',
                callback: (args) async {
                  String paragraphId = args[0];
                  String paragraphText = args[1];
                  double x = args[2].toDouble(); // Conversion en double
                  double y = args[3].toDouble(); // Conversion en double
                  Offset tapPosition = Offset(x, y);

                  showParagraphContextMenu(context, widget.publication['LanguageSymbol'], _document['MepsDocumentId'], paragraphId, paragraphText, tapPosition);
                },
              );

              // Gestionnaire pour les modifications des champs de formulaire
              controller.addJavaScriptHandler(
                handlerName: 'onInputChange',
                callback: (args) async {
                  updateFieldValue(args[0], widget.publication, _document['MepsDocumentId']); // Fonction pour mettre à jour la liste _textInputs
                },
              );
            },
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
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              WebUri uri = navigationAction.request.url!;

              // Vérifie si le lien contient "finder"
              if (uri.host == 'www.jw.org' &&
                  uri.path == '/finder' &&
                  uri.queryParameters.containsKey('lank') &&
                  uri.queryParameters.containsKey('wtlocale')) {
                // Récupère les paramètres
                final lank = uri.queryParameters['lank'];
                final wtlocale = uri.queryParameters['wtlocale'];

                // Affiche le dialogue
                if (lank != null && wtlocale != null) {
                  showVideoDialog(context, lank, wtlocale).then((result) {
                    if (result == 'play') { // Vérifiez si le résultat est 'play'
                      JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                            return FullScreenVideoPlayer(
                              lank: lank,
                              lang: wtlocale,
                            );
                          },
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    }
                  });
                }

                // Annule la navigation pour gérer le lien manuellement
                return NavigationActionPolicy.CANCEL;
              }

              // Permet la navigation pour tous les autres liens
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {
              await loadUserdata();
// Injection de JavaScript après le chargement complet de la page
              await controller.evaluateJavascript(source: """
  document.querySelectorAll('img').forEach((img) => {
    img.addEventListener('click', () => {
      window.flutter_inappwebview.callHandler('onImageClick', img.src);
    });
  });

  document.querySelectorAll('input, textarea').forEach((input) => {
    const eventType = input.type === 'checkbox' ? 'change' : 'input';
    input.addEventListener(eventType, () => {
      const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
      window.flutter_inappwebview.callHandler('onInputChange', {
        tag: input.id || '',
        value: value
      });
    });
  });

  document.body.style.userSelect = 'text';

  (function populateInputs() {
    const inputs = [${_textInputs.map((item) {
                final tag = item['TextTag'];
                final value = item['Value'] ?? '';
                return """{ tag: '$tag', value: `$value` }""";
              }).join(', ')}];

    inputs.forEach((input) => {
      const element = document.getElementById(input.tag);
      if (element) {
        if (element.type === 'checkbox') {
          element.checked = input.value === '1';
        } else if (element.tagName === 'TEXTAREA' || element.type === 'text') {
          element.value = input.value;
        }
      }
    });
  })();

  // Gestion des clics hors paragraphe pour désélectionner
  document.addEventListener('click', (event) => {
    if (!event.target.closest('p')) {
      document.querySelectorAll('p').forEach((p) => {
        p.classList.remove('jwac-textHighlight');
      });
    }
  });

  document.querySelectorAll('p').forEach((p) => {
    p.addEventListener('click', (event) => {
      const isAlreadySelected = p.classList.contains('jwac-textHighlight');
      document.querySelectorAll('p').forEach((p) => {
        p.classList.remove('jwac-textHighlight');
      });
      if (!isAlreadySelected) {
        p.classList.add('jwac-textHighlight');
        const paragraphId = p.getAttribute('data-pid') || '';
        const paragraphText = p.innerText || '';
        const x = event.clientX || 0;
        const y = event.clientY || 0;
        window.flutter_inappwebview.callHandler('onParagraphClick', paragraphId, paragraphText, x, y);
      }
    });
  });
""");
          },
      ),
    if (_showNotes) PublicationNotesView(docId: _document['MepsDocumentId']),
    ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleNotesView,
        elevation: 6.0,
        shape: const CircleBorder(),
        child: Icon(
          _isImageMode ? JwIcons.device_text : _showNotes ? JwIcons.arrow_to_bar_right : JwIcons.gem,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  void _toggleNotesView() {
    if (_isImageMode) {
      switchImageMode();
    }
    else {
      setState(() {
        _showNotes = !_showNotes;
      });
    }
  }
}