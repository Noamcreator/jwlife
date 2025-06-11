import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/modules/home/views/search_views/search_view.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:realm/realm.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../online/publication_menu.dart';
import 'publication_notes_view.dart';
import 'full_screen_image_view_local.dart';

class MeetingsDocumentView extends StatefulWidget {
  final Publication publication;
  final String weekRange;

  const MeetingsDocumentView({
    super.key,
    required this.publication,
    required this.weekRange
  });

  @override
  _DocumentView createState() => _DocumentView();
}

class _DocumentView extends State<MeetingsDocumentView> with SingleTickerProviderStateMixin {
  int _documentId = 0;
  Database? _database;
  late InAppWebViewController _controller;
  String _htmlContent = '';
  Map<String, dynamic> _document = {};
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _svgs = [];
  bool _isImageMode = false;
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  List<Map<String, dynamic>> _blockRange = []; // Store the input fields here
  bool _isLoadingDatabase = false;
  bool _isLoadingWebView = false;

  String webappPath = '';

  /* OTHER VIEW */
  bool _showNotes = false;
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
      _database = await openDatabase(widget.publication.databasePath);
      await fetchDocument();
      //await loadUserdata();
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
    ''', [_documentId]);

      if (response.isNotEmpty) {
        /*
        for (Map<String, dynamic> item in response) {
          // Si le CategoryType est différent de -1, on ajoute l'image ou vidéo
          if (item['CategoryType'] != -1) {
            images.add({
              'path': item['FilePath'],
              'imagePath': widget.publication['Path'] + '/' + item['FilePath'],
              'description': item['Label'],
              'caption': item['Caption'],
              'type': item['MimeType'] == 'video/mp4' ? 'video' : 'image',
              'videoMultimedia': {
                // Récupération des informations du "LinkMultimedia" si elles existent
                'filePath': item['VideoFilePath'],
                'pubSymbol': item['VideoKeySymbol'],
                'track': item['VideoTrack'],
              },
            });
          }
        }

         */

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
''', [_documentId]);

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
    int lang = widget.publication.mepsLanguage.id;
    int mepsDocumentId = _document['MepsDocumentId'];
    var inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(mepsDocumentId, lang);
    var blockRange = await JwLifeApp.userdata.getHighlightsFromDocId(mepsDocumentId, lang);
    print('inputFields: $inputFields');
    print('blockRange: $blockRange');
    setState(() {
      _textInputs = inputFields; // Store the result in the variable
      _blockRange = blockRange; // Store the result in the variable
    });
  }

  Future<void> fetchHyperlink(String link) async {
    try {
      if (link.startsWith('jwpub://b')) {
        await fetchVerses(link);
      }
      else if (link.startsWith('jwpub://p')) {
        await fetchPublication(link);
      }
    }
    catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchPublication(String link) async {
    print('fetchPublication: $link');
    List<Map<String, dynamic>> response = await _database!.rawQuery('''
  SELECT 
    Extract.Content,
    Extract.Caption,
    RefPublication.Title
  FROM Extract
  INNER JOIN DocumentExtract ON Extract.ExtractId = DocumentExtract.ExtractId
  INNER JOIN Hyperlink ON Hyperlink.HyperlinkId = DocumentExtract.HyperlinkId
  INNER JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
  WHERE DocumentExtract.DocumentId = ? AND Hyperlink.Link = ?
''', [_documentId, link]);

    print('response: $response');

    if (response.isNotEmpty) {
      final extract = response.first;

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(
        extract['Content'] as Uint8List,
        widget.publication.hash
      );

      dynamic document = {
        'items': [
          {
            'title': 'test',
            'content': decodedHtml,
            'imageUrl': '/wol/publication/r30/lp-f/nwtsty/thumbnail',
            'publicationTitle': extract['Title']
          }
        ],
        'title': 'Extrait de publication',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(document);
    }
    else {
      print('No hyperlink found for the document.');
    }
  }

  Future<void> fetchVerses(String link) async {
    try {
      // Récupérer les données de la base
      List<Map<String, dynamic>> verses = await _database!.rawQuery('''
      SELECT *
      FROM BibleCitation 
      INNER JOIN Hyperlink ON Hyperlink.HyperlinkId = BibleCitation.HyperlinkId
      WHERE Hyperlink.Link = ? AND BibleCitation.DocumentId = ?
    ''',
        [link, _documentId],
      );

      File bibleFile = await getBibleFile();
      Database bibleDB = await openDatabase(bibleFile.path);

      String query = '''
      SELECT BibleVerse.Content, BibleVerse.Label
      FROM BibleVerse
      WHERE BibleVerse.BibleVerseId BETWEEN ? AND ?
    ''';

      List<Map<String, dynamic>> response = await bibleDB.rawQuery(query, [
        verses.first['FirstBibleVerseId'],
        verses.first['LastBibleVerseId'],
      ]);

      print('response: $response');

      String htmlContent = '';
      for (Map<String, dynamic> row in response) {
        htmlContent += row['Label'];
        final decodedHtml = decodeBlobContent(
          row['Content'] as Uint8List,
          JwLifeApp.pubCollections.getBibles().first.hash,
        );
        htmlContent += decodedHtml;
      }

      dynamic versesJson = {
        'items': [
          {
            'title': 'test',
            'content': htmlContent,
            'imageUrl': '/wol/publication/r30/lp-f/nwtsty/thumbnail',
            'publicationTitle': JwLifeApp.pubCollections.getBibles().first.shortTitle,
          }
        ],
        'title': 'Verset(s)',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(versesJson);
    }
    catch (e) {
      print('Error fetching verses: $e');
    }
  }

  Future<void> injectHtmlDialog(dynamic verses) async {
    final verseHtml = await createHtmlContent(
      verses["items"][0]["content"],
      '''bibleCitation pub-nwtsty jwac showRuby ml-F ms-ROMAN dir-ltr layout-reading layout-sidebar''',
      widget.publication,
      false
    );

    // Encodez le contenu HTML en échappant les caractères spéciaux
    await _controller.evaluateJavascript(source: """
{
  const existingDialog = document.getElementById('customDialog');
  if (existingDialog) {
    existingDialog.querySelector('div:nth-child(3)').innerHTML = \`
      ${verseHtml}
    \`;
    existingDialog.style.display = 'block';
    document.body.classList.add('noscroll'); // Ajouter la classe noscroll
  } 
  else {
    const dialog = document.createElement('div');
    dialog.id = 'customDialog';
    dialog.style.cssText = 'position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #121212; padding: 0; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.2); z-index: 1000; width: 80%; max-width: 800px;';
    
    const header = document.createElement('div');
    header.style.cssText = 'background: #333; color: white; padding: 10px; font-size: 18px; font-weight: bold; display: flex; justify-content: space-between; align-items: center; border-top-left-radius: 8px; border-top-right-radius: 8px; cursor: move;';
    header.innerHTML = '${verses["title"]}';
    
    const closeButton = document.createElement('button');
    closeButton.textContent = '×';
    closeButton.style.cssText = 'background: transparent; border: none; color: white; font-size: 20px; cursor: pointer;';
    closeButton.onclick = function(event) {
      event.stopPropagation();
      event.preventDefault();
      dialog.style.display = 'none';
      document.body.classList.remove('noscroll'); // Supprimer la classe noscroll
      dialog.close();
    };
    header.appendChild(closeButton);
    dialog.appendChild(header);
    
    // Ajouter la bande noire avec l'image et le texte
    const infoBar = document.createElement('div');
    infoBar.style.cssText = 'background: #000; color: white; padding: 10px; display: flex; align-items: center;';
    const img = document.createElement('img');
    img.src = 'https://wol.jw.org/wol/publication/r30/lp-f/nwtsty/thumbnail'; // Remplacez par le lien de l'image
    img.alt = 'Bible';
    img.style.cssText = 'height: 40px; margin: 0; padding: 0;';

    const textContainer = document.createElement('div');
    textContainer.style.cssText = 'text-align: left; margin-left: 10px;';
    const bibleText = document.createElement('div');
    bibleText.textContent = '${verses['items'][0]["publicationTitle"]}';
    bibleText.style.cssText = 'font-size: 16px; font-weight: bold;';
    const frenchText = document.createElement('div');
    frenchText.textContent = 'Français';
    frenchText.style.cssText = 'font-size: 12px;';
    
    textContainer.appendChild(bibleText);
    textContainer.appendChild(frenchText);
    infoBar.appendChild(img);
    infoBar.appendChild(textContainer);
    dialog.appendChild(infoBar);

    const content = document.createElement('div');
    content.innerHTML = \`
      ${verseHtml}
    \`;
    content.style.cssText = 'max-height: 400px; overflow-y: auto; padding: 15px;';
    dialog.appendChild(content);
    document.body.appendChild(dialog);
    document.body.classList.add('noscroll'); // Ajouter la classe noscroll
  }
}
""");
  }

  Future<String?> _getImagePathFromDatabase(String url) async {
    // Mettre l'URL en minuscule
    List<Map<String, dynamic>> imageName = await _database!.rawQuery(
        'SELECT FilePath FROM Multimedia WHERE LOWER(FilePath) = ?', [url]
    );

    // Si une correspondance est trouvée, retourne le chemin
    if (imageName.isNotEmpty) {
      return '${widget.publication.path}/${imageName.first['FilePath']}';
    }
    return '';
  }


  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last;
    Map<String, dynamic> image = _images.firstWhere((img) => img['FilePath'] == newPath);

    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

    /*
    showPage(context, FullScreenImageViewLocal(
        publication: widget.publication,
        multimedia: image,
        multimedias: _images
    ));

     */
  }

  Future<void> switchImageMode() async {
    if (_isImageMode) {
      _controller.loadData(data: _htmlContent, baseUrl: WebUri('file://$webappPath/'));

      setState(() {
        _isImageMode = false;
      });
    }
    else {
      String path = widget.publication.path + '/' + _svgs[0]['FilePath'];
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

  Future<void> fetchDocument() async {
    try {
      String query = '''
      SELECT DatedText.Content, Publication.UndatedSymbol
      FROM DatedText, Publication
      WHERE DatedText.FirstDateOffset <= ? 
      AND DatedText.LastDateOffset >= ? 
    ''';

      List<Map<String, dynamic>> response = await _database!.rawQuery(query, [
        widget.weekRange,
        widget.weekRange
      ]);

      Map<String, dynamic> document = response.first;

      final contentBlob = document['Content'] as Uint8List;
      String decodedHtml = decodeBlobContent(
        contentBlob,
        widget.publication.hash,
      );

      if (document['UndatedSymbol'] == 'w') {
        // Utilisation d'une expression régulière pour extraire le lien
        RegExp regExp = RegExp(r'jwpub://[^\"]+');
        RegExpMatch? matche = regExp.firstMatch(decodedHtml);

        String query = '''
        SELECT *
        FROM Document
        JOIN InternalLink ON Document.MepsDocumentId = InternalLink.MepsDocumentId
        WHERE InternalLink.Link = ? 
      ''';

        List<Map<String, dynamic>> response = await _database!.rawQuery(query, [
          matche!.group(0)!.replaceAll('jwpub://', '')
        ]);

        document = response.first;

        final contentBlob = document['Content'] as Uint8List;
        decodedHtml = decodeBlobContent(
          contentBlob,
          widget.publication.hash,
        );

        _documentId = document['DocumentId'];
      }

      _htmlContent = await createHtmlContent(
        decodedHtml,
        '''jwac docClass-${document['Class']} docId-${document['MepsDocumentId']} ms-ROMAN ml-${widget.publication.mepsLanguage.symbol} dir-ltr pub-${widget.publication.keySymbol} layout-reading layout-sidebar''',
        widget.publication,
        false
      );

      print(widget.publication.hash);

      _document = document;
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
      body: Stack(children: [
        FadeTransition(
          opacity: _animation,
          child: _isLoadingDatabase
              ? InAppWebView(
              initialSettings: InAppWebViewSettings(
                disableContextMenu: false,
                javaScriptEnabled: true,
                useHybridComposition: false,
                allowFileAccess: true,
                allowContentAccess: true,
                cacheMode: CacheMode.LOAD_NO_CACHE,
                allowUniversalAccessFromFileURLs: true,
                disableHorizontalScroll: true,
              ),
              initialData: InAppWebViewInitialData(
                data: _htmlContent,
                mimeType: 'text/html',
                baseUrl: WebUri('file://$webappPath/'),
              ),
              contextMenu: ContextMenu(
                  menuItems: [
                    ContextMenuItem(
                        id: 4,
                        title: "Copier",
                        action: () async {
                          _controller.getSelectedText().then((value) =>
                              Clipboard.setData(ClipboardData(text: value.toString())));
                        }),
                    ContextMenuItem(
                        id: 6,
                        title: "Chercher",
                        action: () async {
                          String query = await _controller.getSelectedText() ?? "";
                          showPage(context, SearchView(query: query));
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
              onWebViewCreated: (controller) async {
                _controller = controller;

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'onImageClick',
                  callback: (args) async {
                    _openFullScreenImageView(args[0]); // Gérer l'affichage de l'image
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'onInputChange',
                  callback: (args) async {
                    updateFieldValue(widget.publication, _documentId, args[0]); // Fonction pour mettre à jour la liste _textInputs
                  },
                );
              },
              gestureRecognizers: Set()
                ..add(
                  Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                  ),
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
                        data: imageData
                    );
                  }
                }
                return null;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                WebUri uri = navigationAction.request.url!;

                String url = uri.uriValue.toString();
                if(url.startsWith('jwpub://')) {
                  fetchHyperlink(url);
                  return NavigationActionPolicy.CANCEL;
                }

                // Vérifie si le lien contient "finder"
                if (uri.host == 'www.jw.org' &&
                    uri.path == '/finder' &&
                    uri.queryParameters.containsKey('lank') &&
                    uri.queryParameters.containsKey('wtlocale')) {
                  // Récupère les paramètres
                  final lank = uri.queryParameters['lank'];
                  final wtlocale = uri.queryParameters['wtlocale'];

                  MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$wtlocale'").first;

                  // Affiche le dialogue
                  if (lank != null && wtlocale != null) {
                    showVideoDialog(context, mediaItem).then((result) {
                      if (result == 'play') { // Vérifiez si le résultat est 'play'
                         showFullScreenVideo(context, mediaItem);
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
                    
                    function adjustHeight(element) {
                      element.style.height = 'auto';
                      element.style.height = (element.scrollHeight) + 'px';
                    }

                    document.querySelectorAll('textarea').forEach((textarea) => {
                      adjustHeight(textarea);  // Ajuster la hauteur initiale en fonction du contenu existant
                      textarea.addEventListener('input', () => {
                        adjustHeight(textarea);
                      });
                    });
                  """);

                fetchImages();
                fetchSvgs();
              },
              onProgressChanged: (controller, progress) {
               if (progress == 100) {
                 setState(() {
                   _isLoadingWebView = true;
                   _controllerAnimation.forward(); // Démarrer l'animation une fois le chargement terminé
                 });
               }
            }
          )
              : Container(),
        ),
        if (_showNotes) PublicationNotesView(docId: _document['MepsDocumentId']),
        if (!_isLoadingDatabase || !_isLoadingWebView) const Center(child: CircularProgressIndicator()),
      ]),
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