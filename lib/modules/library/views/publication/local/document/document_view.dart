import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/Audio.dart';
import 'package:jwlife/data/databases/Media.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/modules/home/views/search_views/search_view.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_medias_view.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../../../core/utils/directory_helper.dart';
import '../full_screen_image_view_local.dart';
import '../publication_notes_view.dart';
import 'document_javascript.dart';

class DocumentView extends StatefulWidget {
  final Publication publication;
  final int mepsDocumentId;
  final int? book;
  final int? chapter;
  final List<Audio> audios;
  final int? startParagraphId;
  final int? endParagraphId;

  const DocumentView({
    super.key,
    required this.publication,
    required this.mepsDocumentId,
    this.book,
    this.chapter,
    this.audios = const [],
    this.startParagraphId,
    this.endParagraphId,
  });

  // Constructeur nommé pour une Bible
  const DocumentView.bible({
    Key? key,
    required Publication bible,
    required int book,
    required int chapter,
    List<Audio> audios = const [],
    int? blockIdentifier,
  }) : this(
    key: key,
    publication: bible,
    mepsDocumentId: 0,
    book: book,
    chapter: chapter,
    audios: audios,
    startParagraphId: blockIdentifier,
  );

  @override
  _DocumentViewState createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late PageController _pageController;
  late InAppWebViewController _controller;

  String webappPath = '';

  /* MODES */
  bool _isImageMode = false;
  bool _isSearching = false;
  bool _isFullscreen = true;

  /* LOADING */
  bool _isLoadingPageController = false;
  bool _isLoadingDatabase = false;
  bool _isLoadingWebView = false;

  /* OTHER VIEW */
  bool _showNotes = false;
  bool _isProgrammaticScroll = false; // Variable pour éviter l'interférence
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles

  /* ANIMATION FADE */
  late AnimationController _controllerAnimation;
  late Animation<double> _animation;

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  @override
  void initState() {
    super.initState();
    _controllerAnimation = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controllerAnimation, curve: Curves.easeIn);

    init();
  }

  @override
  void dispose() {
    _controllerAnimation.dispose();
    super.dispose();
  }

  Future<void> init() async {
    Directory webApp = await getAppWebViewDirectory();
    webappPath = '${webApp.path}/webapp';

    if(widget.publication.documentsManager != null) {
      if(widget.book != null && widget.chapter != null) {
        widget.publication.documentsManager!.documentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.bookNumber == widget.book && element.chapterNumberBible == widget.chapter);
      }
      else {
        widget.publication.documentsManager!.documentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.mepsDocumentId == widget.mepsDocumentId);
      }
    }
    else {
      widget.publication.documentsManager = DocumentsManager(publication: widget.publication, mepsDocumentId: widget.mepsDocumentId, bookNumber: widget.book, chapterNumber: widget.chapter);
      await widget.publication.documentsManager!.initializeDatabaseAndData();
    }
    _pageController = PageController(initialPage: widget.publication.documentsManager!.documentIndex);

    setState(() {
      _isLoadingPageController = true;
    });

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt(widget.publication.documentsManager!, () {
      setState(() {
        _isLoadingDatabase = true;
      });
    });

    _isFullscreen = await getFullscreen();
  }

  Future<void> changePageAt(int index) async {
    widget.publication.documentsManager!.documentIndex = index;

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt(widget.publication.documentsManager!, () {
      setState(() {
        _isLoadingDatabase = true;
      });
    });
  }

  Future<void> _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) async {
    _isProgrammaticScroll = true; // Indique qu'un scroll programmatique est en cours

    final javascriptCode = """
    restoreParagraphColors();
  
    var existingToolbar = document.querySelector('.toolbar');
    if (existingToolbar) {
      existingToolbar.remove();
    }
  
    // Griser les autres paragraphes
    document.querySelectorAll('[data-pid]').forEach((p) => {
      const pid = parseInt(p.getAttribute('data-pid'), 10);
      if (pid < $beginParagraphOrdinal || pid > $endParagraphOrdinal) {
        p.style.opacity = '0.5'; // Réduire l'opacité pour les paragraphes hors de la plage
      } 
      else {
        p.style.opacity = '1'; // Assurer que les paragraphes ciblés restent visibles
      }
    });
  
    // Défilement vers l'élément cible
    var targetElement = document.querySelector('[data-pid="$beginParagraphOrdinal"]');
    if (targetElement) {
      var elementPosition = targetElement.getBoundingClientRect().top + window.scrollY;
      var offset = 100;
      window.scrollTo({ top: elementPosition - offset, behavior: 'instant' });
    }
  """;

    await _controller.evaluateJavascript(source: javascriptCode);

    // Réactiver onScrollChanged après un délai
    Future.delayed(Duration(milliseconds: 100), () {
      _isProgrammaticScroll = false;
    });

    setState(() {
      _controlsVisible = true;
    });
  }

  void _jumpToPage(int page) {
    setState(() {
      _pageHistory.add(_pageController.page!.round()); // Ajouter la page actuelle à l'historique
      _currentPageHistory = page;
    });
    _pageController.jumpToPage(page);

    setState(() {
      _controlsVisible = true;
    });
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

  Future<void> fetchHyperlink(String link) async {
    if (link.startsWith('jwpub://b')) {
      await fetchVerses(link);
    }
    else if (link.startsWith('jwpub://p')) {
      await fetchPublication(link);
    }
  }

  Future<void> fetchVerses(String link) async {
    String verses = link.split('/').last;
    int book1 = int.parse(verses.split('-').first.split(':')[0]);
    int chapter1 = int.parse(verses.split('-').first.split(':')[1]);
    int verse1 = int.parse(verses.split('-').first.split(':')[2]);

    int book2 = int.parse(verses.split('-').last.split(':')[0]);
    int chapter2 = int.parse(verses.split('-').last.split(':')[1]);
    int verse2 = int.parse(verses.split('-').last.split(':')[2]);

    String versesDisplay = JwLifeApp.bibleCluesInfo.getVerses(book1, chapter1, verse1, book2, chapter2, verse2);

    try {
      List<Map<String, dynamic>> results = await JwLifeApp.pubCollections.getBibles().first.documentsManager!.database.rawQuery("""
    WITH Chapitre1 AS (
        SELECT FirstVerseId, LastVerseId 
        FROM BibleChapter 
        WHERE BookNumber = ? AND ChapterNumber = ?
    ), 
    Chapitre2 AS (
        SELECT FirstVerseId, LastVerseId 
        FROM BibleChapter 
        WHERE BookNumber = ? AND ChapterNumber = ?
    )
    SELECT DISTINCT BibleVerseId, Label, Content
    FROM BibleVerse
    WHERE BibleVerse.BibleVerseId BETWEEN 
        (SELECT FirstVerseId + (? - 1) FROM Chapitre1) 
        AND 
        (SELECT FirstVerseId + (? - 1) FROM Chapitre2)
    AND BibleVerse.Label != ''
    ORDER BY BibleVerse.BibleVerseId;
""", [book1, chapter1, book1, chapter2, verse1, verse2]);

      String htmlContent = '';
      for (Map<String, dynamic> row in results) {
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
            'type': 'verse',
            'content': htmlContent,
            'subtitle': JwLifeApp.pubCollections.getBibles().first.mepsLanguage.vernacular,
            'imageUrl': JwLifeApp.pubCollections.getBibles().first.imageSqr,
            'publicationTitle': JwLifeApp.pubCollections.getBibles().first.shortTitle,
            'class': "bibleCitation html5 pub-nwtsty jwac showRuby ml-F ms-ROMAN dir-ltr layout-reading layout-sidebar",
            'bookNumber': book1,
            'chapterNumber': chapter1,
            'mepsLanguageId': JwLifeApp.pubCollections.getBibles().first.mepsLanguage.id,
            'verse': versesDisplay
          }
        ],
        'title': results.length > 1 ? 'Versets' : 'Verset',
      };

      print(versesJson);

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(versesJson);
    }
    catch (e) {
      print('Error fetching verses: $e');
    }
  }

  Future<void> fetchPublication(String link) async {
    String newLink = link.replaceAll('jwpub://', '');

    File mepsFile = await getMepsFile();

    widget.publication.documentsManager!.database.rawQuery('ATTACH DATABASE ? AS meps', [mepsFile.path]);

    List<Map<String, dynamic>> response = await widget.publication.documentsManager!.database.rawQuery('''
  SELECT 
    Extract.*,
    RefPublication.*,
    meps.Language.VernacularName,
    meps.Language.Symbol
  FROM Extract
  LEFT JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
  LEFT JOIN meps.Language ON RefPublication.MepsLanguageIndex = meps.Language.LanguageId
  WHERE Extract.Link = ?
''', [newLink]);

    widget.publication.documentsManager!.database.rawQuery('DETACH DATABASE meps');

    if (response.isNotEmpty) {
      final extract = response.first;

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(
          extract['Content'] as Uint8List,
          widget.publication.hash
      );

      Publication? publication = await PubCatalog.searchPub(extract['UndatedSymbol'], int.parse(extract['IssueTagNumber']), extract['MepsLanguageIndex']);

      var doc = parse(extract['Caption']);
      String caption = doc.querySelector('.etitle')?.text ?? '';

      String image = (await ImageDatabase.getOrDownloadImage(publication!.imageSqr))!.path;

      dynamic document = {
        'items': [
          {
            'type': 'publication',
            'content': decodedHtml,
            'subtitle': caption,
            'imageUrl': image,
            'class': "publicationCitation html5 html5 pub-${extract['UndatedSymbol']} docId-${extract['RefMepsDocumentId']} pub-${extract['Symbol']} docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${extract['Symbol']} ms-ROMAN dir-ltr layout-reading layout-sidebar",
            'mepsDocumentId': extract['RefMepsDocumentId'],
            'mepsLanguageId': extract['MepsLanguageIndex'],
            'startParagraphId': extract['RefBeginParagraphOrdinal'],
            'endParagraphId': extract['RefEndParagraphOrdinal'],
            'publicationTitle': publication.issueTagNumber == 0 ? publication.shortTitle : publication.issueTitle,
          }
        ],
        'title': 'Extrait de publication',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(document);
    }
    else {
      List<String> parts = newLink.split('/');

      int mepsDocumentId = int.parse(parts[1].split(':')[1]);

      String lastPart = parts.last.split(':')[0]; // Ignore tout après ":"
      int? startParagraph;
      int? endParagraph;

      if (lastPart.contains('-')) {
        List<String> paragraphParts = lastPart.split('-');
        startParagraph = int.tryParse(paragraphParts[0]);
        endParagraph = int.tryParse(paragraphParts[1]);
      }
      else if (RegExp(r'^\d+$').hasMatch(lastPart)) {
        startParagraph = int.tryParse(lastPart);
      }

      if (mepsDocumentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
        int index = widget.publication.documentsManager!.getIndexFromMepsDocumentId(mepsDocumentId);
        _jumpToPage(index);
      }

      // Appeler _jumpToParagraph uniquement si un paragraphe est présent
      if (startParagraph != null) {
        _jumpToParagraph(startParagraph, endParagraph ?? startParagraph);
      }
    }
  }

  Future<void> fetchFootnote(String footNoteId) async {
    List<Map<String, dynamic>> response = await widget.publication.documentsManager!.database.rawQuery(
        '''
          SELECT * FROM Footnote WHERE DocumentId = ? AND FootnoteIndex = ?
        ''',
        [widget.publication.documentsManager!.documentIndex, footNoteId]);

    if (response.isNotEmpty) {
      final footNote = response.first;

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(
          footNote['Content'] as Uint8List,
          widget.publication.hash
      );

      dynamic document = {
        'items': [
          {
            'type': 'note',
            'class': "docId-${widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId} pub-${widget.publication.keySymbol} docClass-13 jwac showRuby ml-${widget.publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar",
            'content': decodedHtml,
          }
        ],
        'title': 'Note',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(document);
    }
  }

  Future<void> injectHtmlDialog(dynamic document) async {
    final html = await createHtmlVerseContent(
      document["items"][0]["content"],
      document["items"][0]["class"],
    );

    // Encodez le contenu HTML en échappant les caractères spéciaux
    await _controller.evaluateJavascript(source: """
  {
    // Supprimez le dialogue existant s'il y en a un
    const existingDialog = document.getElementById('customDialog');
    if (existingDialog) {
      existingDialog.remove(); // Supprimez le dialogue existant
    }

    // Créez un nouveau dialogue
    const dialog = document.createElement('div');
    dialog.id = 'customDialog';
    dialog.style.cssText = 'position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #121212; padding: 0; border-radius: 0px; box-shadow: 0 4px 20px rgba(0.8,0.8,1,1); z-index: 1000; width: 80%; max-width: 800px;';

    // Définir les thèmes en fonction de la variable isDark
    const isDark = ${Theme.of(context).brightness == Brightness.dark}; // Cette variable doit être passée depuis Flutter
    
    // Créer le header (barre supérieure du dialogue)
    const header = document.createElement('div');
    
    // Style pour le theme
    const headerStyle = isDark ? 'background: #333; color: white;' : 'background: #d8d7d5; color: #333333;';

    // Appliquer le style à l'en-tête
    header.style.cssText = `\${headerStyle} padding: 5px; padding-left: 10px; padding-right: 10px; font-size: 18px; font-weight: bold; display: flex; align-items: center; border-top-left-radius: 0px; border-top-right-radius: 0px;`;
    // **Création du conteneur pour déplacer**
    const dragArea = document.createElement('div');
    dragArea.style.cssText = 'flex-grow: 1; cursor: move;';

    // Ajout du titre du verset
    dragArea.innerHTML = `${document['items'][0]["verse"] ?? document["title"]}`;

    // **Variables pour le déplacement**
    let isDragging = false;
    let offsetX = 0, offsetY = 0;

    function startDrag(event) {
      event.preventDefault();
      isDragging = true;

      let clientX = event.clientX ?? event.touches[0].clientX;
      let clientY = event.clientY ?? event.touches[0].clientY;

      offsetX = clientX - dialog.getBoundingClientRect().left;
      offsetY = clientY - dialog.getBoundingClientRect().top;
    }

    function onDrag(event) {
      if (!isDragging) return;
      event.preventDefault();

      let clientX = event.clientX ?? event.touches[0].clientX;
      let clientY = event.clientY ?? event.touches[0].clientY;

      let left = clientX - offsetX;
      let top = clientY - offsetY;

      dialog.style.left = left + 'px';
      dialog.style.top = top + 'px';
      dialog.style.transform = 'none';
    }

    function stopDrag() {
      isDragging = false;
    }

    // **Événements pour déplacer le dialog uniquement via dragArea**
    dragArea.addEventListener('mousedown', startDrag);
    document.addEventListener('mousemove', onDrag);
    document.addEventListener('mouseup', stopDrag);

    dragArea.addEventListener('touchstart', startDrag);
    document.addEventListener('touchmove', onDrag);
    document.addEventListener('touchend', stopDrag);

    // **Création du conteneur des boutons**
    const buttonContainer = document.createElement('div');
    buttonContainer.style.cssText = 'display: flex; align-items: center; margin-left: auto;';

    // **Bouton plein écran**
    const fullscreenButton = document.createElement('button');
    fullscreenButton.innerHTML = '&#xE6C7;';
    fullscreenButton.style.cssText = 'font-family: jw-icons-external; font-size: 20px; padding: 6px;';
    fullscreenButton.onclick = function(event) {
      event.stopPropagation();
      event.preventDefault();
      if (dialog.style.position === 'fixed') {
        dialog.style.position = 'absolute';
        dialog.style.top = '0';
        dialog.style.left = '0';
        dialog.style.width = '100%';
        dialog.style.height = '100%';
        dialog.style.transform = 'none';
        dialog.scrollIntoView({ behavior: 'instant', block: 'start' });
        dialog.style.marginTop = '90px';  
      } else {
        dialog.style.position = 'fixed';
        dialog.style.top = '50%';
        dialog.style.left = '50%';
        dialog.style.transform = 'translate(-50%, -50%)';
        dialog.style.width = '80%';
        dialog.style.height = 'auto';
        dialog.style.marginTop = '0'; 
      }
    };

    // **Bouton fermer**
    const closeButton = document.createElement('button');
    closeButton.innerHTML = '&#xE6F0;';
    closeButton.style.cssText = 'font-family: jw-icons-external; font-size: 20px; padding: 6px;';
    closeButton.onclick = function(event) {
      event.stopPropagation();
      event.preventDefault();
      dialog.remove();
      document.body.classList.remove('noscroll');
    };

    // **Ajout des boutons dans le conteneur**
    buttonContainer.appendChild(fullscreenButton);
    buttonContainer.appendChild(closeButton);

    // **Ajout du dragArea et du buttonContainer dans le header**
    header.appendChild(dragArea);
    header.appendChild(buttonContainer);

    // **Ajout du header au dialog**
    dialog.appendChild(header);

    // Style pour le theme
    const infoBarStyle = isDark 
      ? 'background: black; color: white;' // Thème sombre
      : 'background: #f2f1ef; color: black;'; // Thème clair

    // Créer la barre d'information (infoBar)
    const infoBar = document.createElement('div');
    infoBar.style.cssText = 'display: flex; align-items: center; ' + infoBarStyle;

    // Créer l'image pour la barre d'information
    const img = document.createElement('img');
    img.src = 'file://${document['items'][0]["imageUrl"]}';
    img.alt = 'Bible';
    img.style.cssText = 'height: 55px; margin: 0; padding: 0;';

    // Créer le conteneur de texte pour la barre d'information
    const textContainer = document.createElement('div');
    textContainer.style.cssText = 'text-align: left; margin-left: 10px;';
    const pubText = document.createElement('div');
    pubText.textContent = '${document['items'][0]["publicationTitle"]}';
    pubText.style.cssText = 'font-size: 16px; font-weight: bold;';
    
    // Créer le texte du sous-titre
    const subtitleText = document.createElement('div');
    subtitleText.textContent = `${document['items'][0]["subtitle"]}`;
    subtitleText.style.cssText = `
      font-size: 13px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    `;

    textContainer.appendChild(pubText);
    textContainer.appendChild(subtitleText);

    // Ajouter l'image et le texte à la barre d'information
    infoBar.appendChild(img);
    infoBar.appendChild(textContainer);

    // Ajout d'un écouteur d'événements pour ouvrir une fenêtre Flutter
    infoBar.addEventListener('click', function() {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('openMepsDocument', ${json.encode(document)});
      } 
      else {
        console.log('Flutter handler non disponible');
      }
    });

    // Ajouter la barre d'information au dialogue si le type n'est pas 'note'
    if(${document['items'][0]["type"] != 'note'}) {
      dialog.appendChild(infoBar);
    }

    // Créer le contenu principal (content) du dialogue
    const content = document.createElement('div');
    content.innerHTML = `$html`;
    content.style.cssText = 'max-height: 500px; overflow-y: auto; padding: 15px; background-color: ${JwLifeApp.settings.webViewData.backgroundColor};';
    dialog.appendChild(content);

    // Ajouter le dialogue au body et activer le défilement de la page
    document.body.appendChild(dialog);
    document.body.classList.add('noscroll');
  }
""");
  }

  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last.toLowerCase();

    int indexImage = widget.publication.documentsManager!.getCurrentDocument().multimedias.indexWhere((img) => img.filePath.toLowerCase() == newPath);

    if (!widget.publication.documentsManager!.getCurrentDocument().multimedias.elementAt(indexImage).hasSuppressZoom) {
      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

      showPage(context, FullScreenImageViewLocal(
          publication: widget.publication,
          multimedias: widget.publication.documentsManager!.getCurrentDocument().multimedias,
          index: indexImage
      ));
    }
  }

  Future<void> switchImageMode() async {
    if (_isImageMode) {
      _controller.loadData(data: widget.publication.documentsManager!.getCurrentDocument().htmlContent, baseUrl: WebUri('file://$webappPath/'));

      setState(() {
        _isImageMode = false;
      });
    }
    else {
      String path = '${widget.publication.path}/${widget.publication.documentsManager!.getCurrentDocument().svgs[0]['FilePath']}';
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
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: changePageAt,
          children: List<Widget>.generate(widget.publication.documentsManager!.documents.length, (index) => FadeTransition(
            opacity: _animation,
            child: _isLoadingDatabase && widget.publication.documentsManager!.getDocumentAt(index).htmlContent.isNotEmpty
                ? InAppWebView(
                initialSettings: InAppWebViewSettings(
                  cacheMode: CacheMode.LOAD_NO_CACHE,
                  verticalScrollbarThumbColor: Theme.of(context).primaryColor,
                  verticalScrollBarEnabled: false,
                  allowUniversalAccessFromFileURLs: true,
                  cacheEnabled: false,
                ),
                initialData: InAppWebViewInitialData(
                  data: widget.publication.documentsManager!.getDocumentAt(index).htmlContent,
                  mimeType: 'text/html',
                  baseUrl: WebUri('file://$webappPath/'),
                ),
                onScrollChanged: (controller, x, y) {
                  if (!_isProgrammaticScroll) {
                    if (y > widget.publication.documentsManager!.getCurrentDocument().scrollPosition) {
                      if (_controlsVisible) {
                        setState(() {
                          _controlsVisible = false;
                        });
                      }
                    }
                    else if (y < widget.publication.documentsManager!.getCurrentDocument().scrollPosition) {
                      if (!_controlsVisible) {
                        setState(() {
                          _controlsVisible = true;
                        });
                      }
                    }
                    widget.publication.documentsManager!.getCurrentDocument().scrollPosition = y;
                  }
                },
                onWebViewCreated: (controller) async {
                  _controller = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'onChangePageRight',
                    callback: (args) async {
                      await _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                      setState(() {
                        _controlsVisible = true;
                      });
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'onChangePageLeft',
                    callback: (args) async {
                      await _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                      setState(() {
                        _controlsVisible = true;
                      });
                    },
                  );

                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'onImageClick',
                    callback: (args) {
                      _openFullScreenImageView(args[0]); // Gérer l'affichage de l'image
                    },
                  );

                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'openFootNote',
                    callback: (args) {
                      fetchFootnote(args[0]);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'openMepsDocument',
                    callback: (args) {
                      Map<String, dynamic>? document = args[0]['items'][0];
                      if (document != null) {
                        if (document['mepsDocumentId'] != null) {
                          showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);
                        }
                        else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                          showChapterView(
                            context,
                            'nwtsty',
                            document["bookNumber"],
                            document["chapterNumber"],
                            document["mepsLanguageId"],
                          );
                        }
                      }
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onInputChange',
                    callback: (args) async {
                      updateFieldValue(widget.publication, widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, args[0]); // Fonction pour mettre à jour la liste _textInputs
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'bookmark',
                    callback: (args) async {
                      Map<String, dynamic>? bookmark = await showBookmarkDialog(context, widget.publication, mepsDocumentId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, title: widget.publication.documentsManager!.getCurrentDocument().displayTitle, snippet: args[0]['snippet'], blockType: 1, blockIdentifier: int.parse(args[0]['paragraphId']));
                      if (bookmark != null) {
                        if(bookmark['BookNumber'] != null && bookmark['ChapterNumber'] != null) {
                          /*
                          int page = _documentsManager.documents.indexWhere((doc) => doc['BookNumber'] == bookmark['BookNumber'] && doc['ChapterNumber'] == bookmark['ChapterNumber']);
                          if (page != _pageController.page!.round()) {
                            _jumpToPage(page);
                          }

                           */
                        }
                        else {
                          if(bookmark['MepsDocumentId'] != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                            int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark['DocumentId']);
                            if (page != _pageController.page!.round()) {
                              _jumpToPage(page);
                            }
                          }
                          if (bookmark['BlockIdentifier'] != null) {
                            _jumpToParagraph(bookmark['BlockIdentifier'], bookmark['BlockIdentifier']);
                          }
                        }
                      }
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'addNote',
                    callback: (args) async {
                      int paragraphId = int.parse(args[0]['paragraphId']);
                      Map<String, dynamic> note = await JwLifeApp.userdata.addNote('', '', 0, [], widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, widget.publication.issueTagNumber, widget.publication.keySymbol, widget.publication.mepsLanguage.id, blockType: 1, blockIdentifier: paragraphId);
                      showPage(context, NoteView(note: note));
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'share',
                    callback: (args) async {
                      widget.publication.documentsManager!.getCurrentDocument().share(paragraphId: args[0]['paragraphId']);
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'copyText',
                    callback: (args) async {
                      Clipboard.setData(ClipboardData(text: args[0]['text']));
                      showBottomMessage(context, 'Texte copié dans le presse-papier');
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'playAudio',
                    callback: (args) async {
                      try {
                        // Trouver l'audio correspondant au document dans une liste
                        Audio? audio = widget.audios.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);

                        if(audio != null) {
                          // Trouver le marqueur correspondant au paragraphId dans la liste des marqueurs
                          Marker marker = audio.markers.firstWhere((marker) => marker.mepsParagraphId == int.tryParse(args[0]['paragraphId'].toString()));

                          // Extraire le startTime du marqueur et vérifier s'il est valide
                          String startTime = marker.startTime;
                          if (startTime.isEmpty) {
                            print('Le startTime est invalide');
                            return;
                          }

                          // Analyser la durée
                          Duration duration = parseDuration(startTime);

                          print('duration: $duration');

                          // Trouver l'index du document
                          int? index = widget.audios.indexWhere((audio) =>
                          audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);

                          if (index != -1) {
                            // Afficher le lien du lecteur audio et se positionner au bon startTime
                            showAudioPlayerLink(context, widget.publication, widget.audios, index, start: duration);
                          }
                        }
                      }
                      catch (e) {
                        print('Erreur lors de la lecture de l\'audio : $e');
                      }
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'search',
                    callback: (args) async {
                      String query = args[0]['query'];
                      showPage(context, SearchView(query: query));
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onVideoClick',
                    callback: (args) async {
                      String link = args[0];

                      print('Link: $link');
                      // Extraire les paramètres
                      Uri uri = Uri.parse(link);
                      String? pub = uri.queryParameters['pub'];
                      int? docId = uri.queryParameters['docid'] != null ? int.parse(uri.queryParameters['docid']!) : null;
                      String track = uri.queryParameters['track'] ?? '';

                      MediaItem? mediaItem = getVideoItem(pub, int.parse(track), docId, null, null);

                      if(mediaItem != null) {
                        showVideoDialog(context, mediaItem).then((result) {
                          if (result == 'play') { // Vérifiez si le résultat est 'play'
                            showFullScreenVideo(context, mediaItem);
                          }
                        });
                      }
                      else {

                      }
                    },
                  );
                },
                shouldInterceptRequest: (controller, request) async {
                  String requestedUrl = '${request.url}';

                  if (requestedUrl.startsWith('jwpub-media://')) {
                    final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                    return await widget.publication.documentsManager!.getCurrentDocument().getImagePathFromDatabase(filePath);
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
                    final langwritten = uri.queryParameters.containsKey('langwritten') ? uri.queryParameters['langwritten'] : widget.publication.mepsLanguage.symbol;
                    final fileformat = uri.queryParameters['fileformat'];

                    showDocumentDialog(context, docId!, track!, langwritten!, fileformat!);

                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
                    if(uri.queryParameters.containsKey('wtlocale')) {
                      final wtlocale = uri.queryParameters['wtlocale'];
                      if (uri.queryParameters.containsKey('lank')) {
                        MediaItem? mediaItem;
                        if(uri.queryParameters.containsKey('lank')) {
                          final lank = uri.queryParameters['lank'];
                          mediaItem = getVideoItemFromLank(lank!, wtlocale!);
                        }

                        showVideoDialog(context, mediaItem!).then((result) {
                          if (result ==
                              'play') { // Vérifiez si le résultat est 'play'
                            showFullScreenVideo(context, mediaItem!);
                          }
                        });
                      }
                      else if (uri.queryParameters.containsKey('pub')) {
                        // Récupère les paramètres
                        final pub = uri.queryParameters['pub'];
                        final issueTagNumber = uri.queryParameters.containsKey('issueTagNumber') ? int.parse(uri.queryParameters['issueTagNumber']!) : 0;

                        Publication? publication = await PubCatalog
                            .searchPub(pub!, issueTagNumber, wtlocale!);
                        if (publication != null) {
                          publication.showMenu(context);
                        }
                      }
                    }

                    // Annule la navigation pour gérer le lien manuellement
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Permet la navigation pour tous les autres liens
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStart: (controller, url) async {
                  await loadJavascriptScrolling(controller);
                },
                onLoadStop: (controller, url) async {
                  await loadJavascriptParagraph(controller, widget.audios, widget.publication.documentsManager!.getCurrentDocument(), Theme.of(context).brightness == Brightness.dark);
                  await loadJavascriptUserdata(controller, widget.publication.documentsManager!.getCurrentDocument(), Theme.of(context).brightness == Brightness.dark);
                  await loadJavascriptHighlight(controller, widget.publication.documentsManager!.getCurrentDocument(), Theme.of(context).brightness == Brightness.dark);

                  if (widget.startParagraphId != null && widget.endParagraphId != null) {
                    _jumpToParagraph(widget.startParagraphId!, widget.endParagraphId!);
                  }
                },
                onProgressChanged: (controller, progress) async {
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
        if (_showNotes) PublicationNotesView(docId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId),
        if (!_isLoadingPageController || !_isLoadingDatabase || !_isLoadingWebView) const Center(child: CircularProgressIndicator()),
        if (!_isFullscreen || (_isFullscreen && _controlsVisible) || _showNotes)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                title: _isSearching
                    ? Container(
                  decoration: BoxDecoration(
                    color: Colors.black, // Fond noir pour la barre de recherche
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          style: TextStyle(color: Colors.white), // Texte en blanc
                          decoration: InputDecoration(
                            hintText: 'Recherche...',
                            hintStyle: TextStyle(color: Colors.white54), // Texte de l'astuce en gris
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          onChanged: (value) {
                            print(value);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isSearching = false; // Fermer la barre de recherche
                          });
                        },
                      ),
                    ],
                  ),
                )
                    : !_isLoadingDatabase ? Container() : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.publication.documentsManager!.getCurrentDocument().chapterNumber != null && widget.book != null
                          ? '${widget.publication.documentsManager!.getCurrentDocument().displayTitle} ${widget.publication.documentsManager!.getCurrentDocument().chapterNumber} '
                          : widget.publication.documentsManager!.getCurrentDocument().displayTitle.isNotEmpty ? widget.publication.documentsManager!.getCurrentDocument().displayTitle.trim() : widget.publication.documentsManager!.getCurrentDocument().title),
                      style: textStyleTitle,
                    ),
                    Text(
                      widget.publication.issueTitle.isNotEmpty ? widget.publication.issueTitle : widget.publication.shortTitle,
                      style: textStyleSubtitle,
                    ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_showNotes) {
                      _toggleNotesView();
                    }
                    else {
                      if (_handleBackPress()) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
                actions: [
                  if (!_isSearching)
                    !_isLoadingDatabase ? Container() : ResponsiveAppBarActions(
                      allActions: [
                        if (widget.audios.any((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId))
                          IconTextButton(
                            text: "Écouter l'audio",
                            icon: Icon(JwIcons.headphones),
                            onPressed: () {
                              int? index = widget.audios.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                              if (index != -1) {
                                showAudioPlayerLink(context, widget.publication, widget.audios, index);
                              }
                            },
                          ),
                        IconTextButton(
                          text: "Rechercher",
                          icon: Icon(JwIcons.magnifying_glass),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Marque-pages",
                          icon: Icon(JwIcons.bookmark),
                          onPressed: () async {
                            Map<String, dynamic>? bookmark = await showBookmarkDialog(context, widget.publication, mepsDocumentId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, title: widget.publication.documentsManager!.getCurrentDocument().displayTitle, snippet: '', blockType: 0, blockIdentifier: null);
                            if (bookmark != null) {
                              if(bookmark['BookNumber'] != null && bookmark['ChapterNumber'] != null) {
                                /*
                                int page = _documentsManager.documents.indexWhere((doc) => doc['BookNumber'] == bookmark['BookNumber'] && doc['ChapterNumber'] == bookmark['ChapterNumber']);
                                if (page != _pageController.page!.round()) {
                                  _jumpToPage(page);
                                }

                                 */
                              }
                              else {
                                if(bookmark['MepsDocumentId'] != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                                  int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark['DocumentId']);
                                  if (page != _pageController.page!.round()) {
                                    _jumpToPage(page);
                                  }
                                }
                                if (bookmark['BlockIdentifier'] != null) {
                                  _jumpToParagraph(bookmark['BlockIdentifier'], bookmark['BlockIdentifier']);
                                }
                              }
                            }
                          },
                        ),
                        IconTextButton(
                          text: "Langues",
                          icon: Icon(JwIcons.language),
                          onPressed: () async {
                            LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: widget.publication);
                            showDialog(
                              context: context,
                              builder: (context) => languageDialog,
                            ).then((value) {
                              if (value != null) {
                                widget.publication.showMenu(context, mepsLanguage: value, update: null);
                              }
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Ajouter une note",
                          icon: const Icon(JwIcons.note_plus),
                          onPressed: () async {
                            String title = widget.publication.documentsManager!.getCurrentDocument().title;
                            int mepsDocumentId = widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId;
                            var note = await JwLifeApp.userdata.addNote(
                                title, '', 0, [], mepsDocumentId,
                                widget.publication.issueTagNumber,
                                widget.publication.keySymbol,
                                widget.publication.mepsLanguage.id, blockType: 0, blockIdentifier: null
                            );
                            showPage(context, NoteView(note: note));
                          },
                        ),
                        if(widget.publication.documentsManager!.getCurrentDocument().hasMediaLinks)
                          IconTextButton(
                            text: "Voir les médias",
                            icon: const Icon(JwIcons.video_music),
                            onPressed: () {
                              showPage(context, PublicationMediasView(document: widget.publication.documentsManager!.getCurrentDocument()));
                            },
                          ),
                        IconTextButton(
                          text: "Historique",
                          icon: const Icon(JwIcons.arrow_circular_left_clock),
                          onPressed: () {
                            History.showHistoryDialog(context);
                          },
                        ),
                        IconTextButton(
                          text: "Envoyer le lien",
                          icon: Icon(JwIcons.share),
                          onPressed: () {
                            widget.publication.documentsManager!.getCurrentDocument().share();
                          },
                        ),
                        if (widget.publication.documentsManager!.getCurrentDocument().svgs.isNotEmpty)
                          IconTextButton(
                            text: _isImageMode ? "Mode Texte" : "Mode Image",
                            icon: Icon(_isImageMode ? JwIcons.outline : JwIcons.image),
                            onPressed: () {
                              switchImageMode();
                            },
                          ),
                        IconTextButton(
                          text: "Taille de police",
                          icon: Icon(JwIcons.device_text),
                          onPressed: () {
                            showFontSizeDialog(context, _controller);
                          },
                        ),
                        IconTextButton(
                          text: "Plein écran",
                          icon: Icon(JwIcons.square_stack),
                          onPressed: () async {
                            bool isFullscreen = await showFullscreenDialog(context);
                            setState(() {
                              _isFullscreen = isFullscreen;
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Voir le html",
                          icon: Icon(JwIcons.square_stack),
                          onPressed: () async {
                            await showHtmlDialog(context, decodeBlobContent(widget.publication.documentsManager!.getCurrentDocument().content!, widget.publication.hash));
                          },
                        ),
                      ],
                    ),
                ],
              )
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