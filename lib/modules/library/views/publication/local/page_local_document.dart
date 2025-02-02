import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/modules/home/views/search_views/search_view.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/publication/publication_dialogs.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../online/publication_menu.dart';
import '../publication_notes_view.dart';
import 'full_screen_image_view_local.dart';

class PageLocalDocumentView extends StatefulWidget {
  final Map<String, dynamic> publication;
  final int mepsDocumentId;

  const PageLocalDocumentView({
    super.key,
    required this.publication,
    required this.mepsDocumentId,
  });

  @override
  _PageLocalDocumentViewState createState() => _PageLocalDocumentViewState();
}

class _PageLocalDocumentViewState extends State<PageLocalDocumentView> with SingleTickerProviderStateMixin {
  Database? _database;
  late PageController _pageController;
  late InAppWebViewController _controller;
  List<String> _htmlContents = [];
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic> _document = {};
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _svgs = [];
  bool _isImageMode = false;
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  List<Map<String, dynamic>> _blockRange = []; // Store the input fields here
  bool _isLoadingPageController = false;
  bool _isLoadingDatabase = false;
  bool _isLoadingWebView = false;

  /* OTHER VIEW */
  bool _showNotes = false;
  int _currentScrollPosition = 0;
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles

  late AnimationController _controllerAnimation;
  late Animation<double> _animation;

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

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

  @override
  void dispose() {
    _controllerAnimation.dispose();
    _disposeNavBarBody();
    super.dispose();
  }

  Future<void> _disposeNavBarBody() async {
    //JwLifeView.toggleNavBarBody.call(false);
  }

  Future<void> _initializeDatabaseAndData() async {
    try {
      _database = await openDatabase(widget.publication['DatabasePath']);
      await fetchDocuments();
      //JwLifeView.toggleNavBarBody.call(true);
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

  void _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) {
    final javascriptCode = """
    // Localiser l'élément avec l'attribut data-pid correspondant
    var element = document.querySelector('[data-pid="${beginParagraphOrdinal}"]');
    if (element) {
      // Obtenir la position de l'élément
      var elementPosition = element.getBoundingClientRect().top + window.scrollY;
      
      // Ajouter un espace (par exemple, 20 pixels) entre le haut de l'écran et l'élément
      var offset = 40; // Ajuste cette valeur pour l'espace souhaité
      
      // Faire défiler la page avec un décalage
      window.scrollTo({ top: elementPosition - offset, behavior: 'instant' });
    } 
  """;

    // Exécuter le JavaScript dans le WebView
    _controller.evaluateJavascript(source: javascriptCode);
  }

  void _jumpToPage(int page) {
    setState(() {
      _pageHistory.add(_pageController.page!.round()); // Ajouter la page actuelle à l'historique
      _currentPageHistory = page;
    });
    _pageController.jumpToPage(page);
  }

  bool _handleBackPress() {
    if (_pageHistory.isNotEmpty) {
      setState(() {
        _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
      });
      _pageController.jumpToPage(_currentPageHistory);
      return false; // Ne pas quitter l'application
    }
    return true; // Quitter l'application si aucun historique
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
    ''', [_pageController.page?.round()]);

      print(response);

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

        setState(() {
          _images = images;
        });
      }
      else {
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
''', [_pageController.page?.round()]);

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
''', [_pageController.page?.toInt(), link]);

    print('response: $response');

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
      String newLink = link.replaceFirst('jwpub://', '');
      List<Map<String, dynamic>> internalLinks = await _database!.rawQuery('''
  SELECT 
    Document.*,
    InternalLink.BeginParagraphOrdinal,
    InternalLink.EndParagraphOrdinal
  FROM InternalLink
  INNER JOIN Document ON InternalLink.MepsDocumentId = Document.MepsDocumentId
  WHERE InternalLink.Link = ?
''', [newLink]);

      dynamic document = internalLinks.first;
      if (document['DocumentId'] != _pageController.page?.toInt()) {
        _jumpToPage(document['DocumentId']);
      }

      int beginParagraphOrdinal = document['BeginParagraphOrdinal'];
      int endParagraphOrdinal = document['EndParagraphOrdinal'];

      print('beginParagraphOrdinal: $beginParagraphOrdinal');
      print('endParagraphOrdinal: $endParagraphOrdinal');

      _jumpToParagraph(beginParagraphOrdinal, endParagraphOrdinal);
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
        [link, _pageController.page?.toInt()],
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

      String htmlContent = '';
      for (Map<String, dynamic> row in response) {
        htmlContent += row['Label'];
        final decodedHtml = await decodeBlobContentWithHash(
          contentBlob: row['Content'] as Uint8List,
          hashPublication: JwLifeApp.bibles.first['Hash'],
        );
        htmlContent += decodedHtml;
      }

      dynamic versesJson = {
        'items': [
          {
            'title': 'test',
            'content': htmlContent,
            'imageUrl': '/wol/publication/r30/lp-f/nwtsty/thumbnail',
            'publicationTitle': JwLifeApp.bibles.first['ShortTitle'],
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
    final verseHtml = await createHtmlVerseContent(
      verses["items"][0]["content"],
      '''bibleCitation pub-nwtsty jwac showRuby ml-F ms-ROMAN dir-ltr layout-reading layout-sidebar''',
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
      return widget.publication['Path'] + '/' + imageName.first['FilePath'];
    }
    return '';
  }


  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last;
    Map<String, dynamic> image = _images.firstWhere((img) => img['path'] == newPath);

    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

    showPage(context, FullScreenImageViewLocal(
        images: _images,
        image: image
    ));
  }

  Future<void> switchImageMode() async {
    if (_isImageMode) {
      _controller.loadData(data: _htmlContents.elementAt(_pageController.page!.round()), baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'));

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

  Future<void> fetchDocuments() async {
    try {
      _documents = await _database!.rawQuery("""
    SELECT 
      Document.*, 
      (SELECT Title 
       FROM PublicationViewItem pvi 
       JOIN PublicationViewSchema pvs 
         ON pvi.SchemaType = pvs.SchemaType
       WHERE pvi.DefaultDocumentId = Document.DocumentId 
         AND pvs.DataType = 'name'
       LIMIT 1
      ) AS DisplayTitle
    FROM Document
""");

      _htmlContents = List<String>.generate(_documents.length, (index) => '');

      int page = _documents.indexWhere((doc) => doc['MepsDocumentId'] == widget.mepsDocumentId);
      _pageController = PageController(initialPage: page);

      setState(() {
        _isLoadingPageController = true;
      });

      await changePageAt(page);
      await loadUserdata();
    }
    catch (e) {
      print('Error fetching all documents: $e');
    }
  }

  Future<void> changePageAt(int index) async {
    Map<String, dynamic> document = _documents[index];

    final contentBlob = document['Content'] as Uint8List;
    final decodedHtml = await decodeBlobContentWithHash(
      contentBlob: contentBlob,
      hashPublication: widget.publication['Hash'],
    );

    String htmlContent = await createHtmlContent(
      decodedHtml,
      '''jwac docClass-${document['Class']} docId-${document['MepsDocumentId']} ms-ROMAN ml-${widget.publication['LanguageSymbol']} dir-ltr pub-${widget.publication['KeySymbol']} layout-reading layout-sidebar''',
    );

    setState(() {
      _controlsVisible = true;
      _htmlContents[index] = htmlContent;
      _document = document;
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
          ? const Color(0xFF111111)
          : Colors.white,
      body: Stack(children: [
        _isLoadingPageController ? PageView(
          controller: _pageController,
          onPageChanged: changePageAt,
          children: List<Widget>.generate(_documents.length, (index) => FadeTransition(
            opacity: _animation,
            child: _isLoadingDatabase && _htmlContents[index] != ''
                ? InAppWebView(
                initialSettings: InAppWebViewSettings(
                  disableContextMenu: false,
                  javaScriptEnabled: true,
                  useHybridComposition: false,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  cacheMode: CacheMode.LOAD_NO_CACHE,
                  allowUniversalAccessFromFileURLs: true,
                ),
                initialData: InAppWebViewInitialData(
                  data: _htmlContents[index],
                  mimeType: 'text/html',
                  baseUrl: WebUri('file:///android_asset/flutter_assets/assets/webapp/'),
                ),
                onScrollChanged: (controller, x, y) {
                  // Si la différence est plus grande que 2 pour que l'état change
                  if (y > _currentScrollPosition) {
                    // Quand on descend
                    if (_controlsVisible) {
                      //JwLifeView.toggleNavBarVisibility.call(false);
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
                      updateFieldValue(args[0], widget.publication, _document['MepsDocumentId']); // Fonction pour mettre à jour la liste _textInputs
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

                  else if (url.startsWith('webpubdl://'))  {
                    final docId = uri.queryParameters['docid'];
                    final track = uri.queryParameters['track'];
                    final langwritten = uri.queryParameters.containsKey('langwritten')
                        ? uri.queryParameters['langwritten']
                        : widget.publication['LanguageSymbol'];
                    final fileformat = uri.queryParameters['fileformat'];

                    showDocumentDialog(context, docId!, track!, langwritten!, fileformat!);

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

                    // Affiche le dialogue
                    if (lank != null && wtlocale != null) {
                      showVideoDialog(context, lank, wtlocale).then((result) {
                        if (result == 'play') { // Vérifiez si le résultat est 'play'
                          showFullScreenVideo(context, lank, wtlocale);
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

                  await controller.evaluateJavascript(source: """
  const blockRange = ${jsonEncode(_blockRange)};
  const colorClasses = [
    'highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 
    'highlight-pink', 'highlight-orange', 'highlight-purple'
  ];

  document.querySelectorAll('[data-pid]').forEach((element) => {
    var paragraphId = element.getAttribute('data-pid');

    blockRange.forEach((block) => {
      if (block['Identifier'] == paragraphId) {
        var text = element.innerText;

        // Diviser le texte en mots
        var words = text.split(' ');

        // Calculer la plage de mots à surligner
        var startWordIndex = block['StartToken'];
        var endWordIndex = block['EndToken'];

        // Remplacer les mots dans la plage par des spans
        for (let i = startWordIndex; i <= endWordIndex; i++) {
          // Créer le span avec la classe appropriée
          var span = document.createElement('span');
          span.textContent = words[i];
          span.classList.add(colorClasses[block['ColorIndex']]);

          // Remplacer le mot par le span
          words[i] = span.outerHTML;
        }

        // Réassembler le texte avec les spans insérés
        element.innerHTML = words.join(' ');
      }
    });

    // Ajout d'un gestionnaire de clic sur chaque paragraphe
    element.addEventListener('click', function(event) {
      // Si on clique sur un lien, ne pas afficher la toolbar
      if (event.target.tagName.toLowerCase() === 'a') {
        return;
      }
      showToolbar(event.target);
    });
  });

  // Fonction pour afficher la barre d'outils
  function showToolbar(paragraph) {
    // Vérifier si la barre d'outils existe déjà
    var existingToolbar = document.querySelector('.toolbar');
    if (existingToolbar) {
      existingToolbar.remove();
    }

    // Créer la barre d'outils
    var toolbar = document.createElement('div');
    toolbar.classList.add('toolbar');
    toolbar.style.position = 'absolute';
    toolbar.style.top = (paragraph.getBoundingClientRect().top + window.scrollY - 50) + 'px';
    toolbar.style.backgroundColor = '#333';  // Fond sombre
    toolbar.style.padding = '2px';
    toolbar.style.borderRadius = '5px';
    toolbar.style.color = 'white';
    toolbar.style.boxShadow = '0 2px 10px rgba(0, 0, 0, 0.3)';
    toolbar.style.whiteSpace = 'nowrap'; // Éviter que les boutons passent à la ligne
    toolbar.style.display = 'flex'; // Afficher les boutons en ligne

    // Ajouter la barre avant de calculer la largeur
    document.body.appendChild(toolbar);

    // Calculer la largeur de la toolbar après ajout des boutons
    var toolbarWidth = toolbar.offsetWidth;
    var paragraphRect = paragraph.getBoundingClientRect();
    var paragraphWidth = paragraphRect.width;

    // Centrer horizontalement par rapport au paragraphe
    var leftPosition = paragraphRect.left + window.scrollX + (paragraphWidth / 2) - (toolbarWidth / 2);

    // S'assurer que la position ne dépasse pas les bords de l'écran
    var screenWidth = window.innerWidth;
    if (leftPosition < 0) {
      leftPosition = 0;
    } else if (leftPosition + toolbarWidth > screenWidth) {
      leftPosition = screenWidth - toolbarWidth;
    }

    toolbar.style.left = leftPosition + 'px';

    var shareButton = document.createElement('button');
    shareButton.innerHTML = '&#xE6BA;';
    shareButton.style.fontFamily = 'jw-icons-external';
    shareButton.style.fontSize = '20px';
    shareButton.style.padding = '6px';
    shareButton.style.borderRadius = '5px';
    shareButton.style.margin = '0 5px';
    shareButton.addEventListener('click', function() {
      shareText(paragraph);
    });

    var copyButton = document.createElement('button');
    copyButton.innerHTML = '&#xE652;';
    copyButton.style.fontFamily = 'jw-icons-external';
    copyButton.style.fontSize = '20px';
    copyButton.style.padding = '6px';
    copyButton.style.borderRadius = '5px';
    copyButton.style.margin = '0 5px';
    copyButton.addEventListener('click', function() {
      copyText(paragraph);
    });

    var listenButton = document.createElement('button');
    listenButton.innerHTML = '&#xE663;';
    listenButton.style.fontFamily = 'jw-icons-external';
    listenButton.style.fontSize = '20px';
    listenButton.style.padding = '6px';
    listenButton.style.borderRadius = '5px';
    listenButton.style.margin = '0 5px';
    listenButton.addEventListener('click', function() {
      listenToText(paragraph);
    });

    toolbar.appendChild(shareButton);
    toolbar.appendChild(copyButton);
    toolbar.appendChild(listenButton);

    // Ajouter un gestionnaire de clic pour fermer la toolbar si on clique ailleurs
    document.addEventListener('click', function(event) {
      if (!toolbar.contains(event.target) && !paragraph.contains(event.target)) {
        toolbar.remove();
      }
    }, { once: true });

    // Ajouter un gestionnaire de défilement pour enlever la barre d'outils lors du scroll
    window.addEventListener('scroll', function() {
      toolbar.remove();
    });
  }

  // Fonction pour partager le texte
  function shareText(paragraph) {
    var text = paragraph.innerText;
    console.log('Text to share:', text);

    // Enlever la barre d'outils après la copie
    var toolbar = document.querySelector('.toolbar');
    if (toolbar) {
      toolbar.remove();
    }
  }

  // Fonction pour copier le texte
  function copyText(paragraph) {
    var text = paragraph.innerText;
    navigator.clipboard.writeText(text).then(() => {
      // Ne rien faire après la copie
    }).catch(err => {
      console.error('Erreur lors de la copie du texte', err);
    });

    // Enlever la barre d'outils après la copie
    var toolbar = document.querySelector('.toolbar');
    if (toolbar) {
      toolbar.remove();
    }
  }

  // Fonction pour écouter le texte
  function listenToText(paragraph) {
    var text = paragraph.innerText;

    // Enlever la barre d'outils après l'écoute
    var toolbar = document.querySelector('.toolbar');
    if (toolbar) {
      toolbar.remove();
    }
  }
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
            ) : Container(),
          ),
          ),
        ) : Container(),
        if (_showNotes) PublicationNotesView(docId: _document['MepsDocumentId']),
        if (!_isLoadingPageController || !_isLoadingDatabase || !_isLoadingWebView) const Center(child: CircularProgressIndicator()),
        if ((_isLoadingDatabase && _controlsVisible) || _showNotes)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _document['DisplayTitle'] ?? _document['Title'] ?? '',
                      style: textStyleTitle
                  ),
                  Text(
                      widget.publication['IssueTitle'] != null && widget.publication['IssueTitle'] != '' ? widget.publication['IssueTitle'] : widget.publication['ShortTitle'] ?? '',
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
                    if(_handleBackPress())
                    {
                      JwLifeView.toggleNavBarVisibility.call(true);
                      Navigator.pop(context);
                    }
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
                  },
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      child: Text('Ajouter une note'),
                      onTap: () async {
                        String title = _document['Title'] ?? '';
                        int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                        var note = await JwLifeApp.userdata.addNote(title, '', 0, [], mepsDocumentId, widget.publication['IssueTagNumber'], widget.publication['KeySymbol'], widget.publication['MepsLanguageId']);

                        showPage(context, NoteView(note: note)).then((_) => {
                          //_toggleNotesView()
                        });
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
                )
              ],
            ),
          ),
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