import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
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
import 'package:jwlife/data/databases/PublicationCategory.dart';
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
import 'package:uuid/uuid.dart';

import '../../../../../../core/utils/directory_helper.dart';
import '../full_screen_image_view_local.dart';
import '../publication_notes_view.dart';
import 'document.dart';
import 'document_javascript.dart';

import 'package:audio_service/audio_service.dart' as audio_service;

class DocumentView extends StatefulWidget {
  final Publication publication;
  final int mepsDocumentId;
  final int? startParagraphId;
  final int? endParagraphId;
  final int? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;
  final List<Audio> audios;
  final List<String> wordsSelected;

  const DocumentView({
    super.key,
    required this.publication,
    required this.mepsDocumentId,
    this.startParagraphId,
    this.endParagraphId,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
    this.audios = const [],
    this.wordsSelected = const [],
  });

  // Constructeur nommé pour une Bible
  const DocumentView.bible({
    Key? key,
    required Publication bible,
    required int book,
    required int chapter,
    int? firstVerse,
    int? lastVerse,
    List<Audio> audios = const [],
  }) : this(
    key: key,
    publication: bible,
    mepsDocumentId: 0,
    book: book,
    chapter: chapter,
    firstVerse: firstVerse,
    lastVerse: lastVerse,
    audios: audios,
  );

  @override
  _DocumentViewState createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late InAppWebViewController _controller;

  String webappPath = '';

  /* MODES */
  bool _isImageMode = false;
  bool _isSearching = false;
  bool _isFullscreen = true;

  /* LOADING */
  bool _isLoadingData = false;
  bool _isLoadingWebView = false;

  bool _jumpToParagraphExecuted = false;

  /* OTHER VIEW */
  bool _showNotes = false;
  bool _isProgrammaticScroll = false; // Variable pour éviter l'interférence
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _controlsVisibleSave = true; // Variable pour contrôler la visibilité des contrôles
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    Directory webApp = await getAppWebViewDirectory();
    webappPath = '${webApp.path}/webapp';

    if(widget.publication.documentsManager != null) {
      if(widget.book != null && widget.chapter != null) {
        widget.publication.documentsManager!.bookNumber = widget.book!;
        widget.publication.documentsManager!.chapterNumber = widget.chapter!;
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

    setState(() {
      _isLoadingData = true;
    });

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt(widget.publication.documentsManager!);

    _isFullscreen = await getFullscreen();
  }

  Future<void> onSwipe(String direction) async {
    setState(() {
      if (direction == 'next' && widget.publication.documentsManager!.documentIndex < widget.publication.documentsManager!.documents.length - 1) {
        widget.publication.documentsManager!.documentIndex++;
      }
      else if (direction == 'prev' && widget.publication.documentsManager!.documentIndex > 0) {
        widget.publication.documentsManager!.documentIndex--;
      }
    });

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt(widget.publication.documentsManager!);
  }

  Future<void> _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('[data-pid]', 'data-pid', $beginParagraphOrdinal, $endParagraphOrdinal);");
  }

  Future<void> _jumpToVerse(int startVerseNumber, int lastVerseNumber) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('.v', 'id', $startVerseNumber, $lastVerseNumber);");
  }

  Future<void> _jumpToPage(int page) async {
    if (page == widget.publication.documentsManager!.documentIndex) {
      return;
    }

    setState(() {
      _pageHistory.add(widget.publication.documentsManager!.documentIndex); // Ajouter la page actuelle à l'historique
      _currentPageHistory = page;

      if (page != widget.publication.documentsManager!.documentIndex) {
        widget.publication.documentsManager!.documentIndex = page;
      }
    });
    await _controller.evaluateJavascript(source: 'jumpToPage($page);');

    setState(() {
      _controlsVisible = true;
    });
  }

  bool _handleBackPress() {
    if (_pageHistory.isNotEmpty) {
      setState(() {
        _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
      });
      _controller.evaluateJavascript(source: 'jumpToPage($_currentPageHistory);');
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

    String versesDisplay = JwLifeApp.bibleCluesInfo.getVerses(
        book1, chapter1, verse1,
        book2, chapter2, verse2
    );

    List<Map<String, dynamic>> items = [];

    String verseAudioLink = 'https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?pub=NWT&langwritten=F&fileformat=mp3&booknum=$book1&track=$chapter1';

    dynamic audio = {};
    /*
    try {
      final response = await http.get(Uri.parse(verseAudioLink));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        audio = {
          'url': data['files']['F']['MP3'][0]['file']['url'],
          'markers': data['files']['F']['MP3'][0]['markers']['markers'],
        };
      }
      else {
        print('Loading error: ${response.statusCode}');
      }
    }
    catch (e) {
      print('An exception occurred: $e');
    }

     */

    try {
      for (var bible in JwLifeApp.pubCollections.getBibles()) {
        List<Map<String, dynamic>> results = await bible.documentsManager!.database.rawQuery("""
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
            bible.hash,
          );
          htmlContent += decodedHtml;
        }

        items.add({
          'type': 'verse',
          'content': createHtmlDialogContent(
              htmlContent,
              "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar"
          ),
          'subtitle': bible.mepsLanguage.vernacular,
          'imageUrl': bible.imageSqr,
          'publicationTitle': bible.shortTitle,
          'bookNumber': book1,
          'chapterNumber': chapter1,
          'firstVerseNumber': verse1,
          'lastVerseNumber': verse2,
          'audio': audio,
          'mepsLanguageId': bible.mepsLanguage.id,
        });
      }

      final versesJson = {
        'items': items,
        'title': versesDisplay,
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(versesJson);
    }
    catch (e) {
      print('Error fetching verses: $e');
    }
  }

  Future<void> fetchPublication(String link) async {
    String newLink = link.replaceAll('jwpub://', '');
    List<String> links = newLink.split("\$");

    List<Map<String, dynamic>> response = await widget.publication.documentsManager!.database.rawQuery('''
  SELECT 
    Extract.*,
    RefPublication.*
  FROM Extract
  LEFT JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
  WHERE Extract.Link IN (${links.map((link) => "'$link'").join(',')})
''');

    if (response.isNotEmpty) {
      List<Map<String, dynamic>> extractItems = [];

      for (var extract in response) {
        dynamic pub = await PubCatalog.searchSqrImageForPub(
            extract['UndatedSymbol'],
            int.parse(extract['IssueTagNumber']),
            extract['MepsLanguageIndex']);

        /// Décoder le contenu
        final decodedHtml = decodeBlobContent(
            extract['Content'] as Uint8List, widget.publication.hash);
        var doc = parse(extract['Caption']);
        String caption = doc.querySelector('.etitle')?.text ?? '';

        String image = '';
        if (pub != null && pub['ImageSqr'] != null) {
          String imagePath = "https://app.jw-cdn.org/catalogs/publications/${pub['ImageSqr']}";
          image = (await JwLifeApp.tilesCache.getOrDownloadImage(imagePath))!.file.path;
        }
        else {
          String type = PublicationCategory.getCategories().firstWhere(
                  (element) => element.type == extract['PublicationType']).image;
          bool isDark = Theme.of(context).brightness == Brightness.dark;
          String path = isDark
              ? 'assets/images/${type}_gray.png'
              : 'assets/images/$type.png';
          image = '/android_asset/flutter_assets/$path';
        }

        dynamic article = {
          'type': 'publication',
          'content': createHtmlDialogContent(
              decodedHtml,
              "publicationCitation html5 pub-${extract['UndatedSymbol']} "
                  "docId-${extract['RefMepsDocumentId']} pub-${extract['Symbol']} "
                  "docClass-${extract['RefMepsDocumentClass']} jwac showRuby "
                  "ml-${extract['Symbol']} ms-ROMAN dir-ltr layout-reading layout-sidebar"),
          'subtitle': caption,
          'imageUrl': image,
          'mepsDocumentId': extract['RefMepsDocumentId'],
          'mepsLanguageId': extract['MepsLanguageIndex'],
          'startParagraphId': extract['RefBeginParagraphOrdinal'],
          'endParagraphId': extract['RefEndParagraphOrdinal'],
          'publicationTitle': extract['IssueTagNumber'] == '0' || pub == null
              ? extract['ShortTitle'] ?? extract['Title']
              : pub['IssueTitle'],
        };

        // Ajouter l'élément document à la liste versesItems
        extractItems.add(article);
      }

      dynamic articlesJson = {
        'items': extractItems,
        'title': 'Extrait de publication',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(articlesJson);
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

      if(widget.publication.documentsManager!.documents.any((doc) => doc.mepsDocumentId == mepsDocumentId)) {
        if (mepsDocumentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
          int index = widget.publication.documentsManager!.getIndexFromMepsDocumentId(mepsDocumentId);
          _jumpToPage(index);
        }

        // Appeler _jumpToParagraph uniquement si un paragraphe est présent
        if (startParagraph != null) {
          _jumpToParagraph(startParagraph, endParagraph ?? startParagraph);
        }
      }
      else {
        showDocumentView(context, mepsDocumentId, widget.publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
      }
    }
  }

  Future<void> fetchFootnote(String footNoteId, {String? bibleVerseId}) async {
    List<Map<String, dynamic>> response = [];

    if(bibleVerseId != null) {
      response = await widget.publication.documentsManager!.database.rawQuery(
          '''
          SELECT * FROM Footnote WHERE BibleVerseId = ? AND FootnoteIndex = ?
        ''',
          [bibleVerseId, footNoteId]);

    }
    else if(widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible != null) {
      response = await widget.publication.documentsManager!.database.rawQuery(
          '''
          SELECT Footnote.* FROM Footnote
          LEFT JOIN Document ON Footnote.DocumentId = Document.DocumentId
          WHERE Document.MepsDocumentId = ? AND FootnoteIndex = ?
        ''',
      [widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, footNoteId]);
    }
    else {
      response = await widget.publication.documentsManager!.database.rawQuery(
          '''
          SELECT * FROM Footnote WHERE DocumentId = ? AND FootnoteIndex = ?
        ''',
          [widget.publication.documentsManager!.documentIndex, footNoteId]);

    }

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
            'content': createHtmlDialogContent(
                decodedHtml,
                "document html5 pub-${widget.publication.keySymbol} docId-${widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId} docClass-13 jwac showRuby ml-${widget.publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar"
            ),
          }
        ],
        'title': 'Note',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(document);
    }
  }

  Future<void> fetchVersesReference(String versesReferenceId) async {
    List<Map<String, dynamic>> response = await widget.publication.documentsManager!.database.rawQuery(
    '''
      SELECT 
        BibleChapter.BookNumber, 
        BibleChapter.ChapterNumber,
        (BibleVerse.BibleVerseId - BibleChapter.FirstVerseId + 1) AS VerseNumber,
        BibleVerse.BibleVerseId,
        BibleVerse.Label,
        BibleVerse.Content
      FROM BibleCitation
      LEFT JOIN Document ON BibleCitation.DocumentId = Document.DocumentId
      LEFT JOIN BibleVerse ON BibleCitation.FirstBibleVerseId = BibleVerse.BibleVerseId
      LEFT JOIN BibleChapter ON BibleVerse.BibleVerseId BETWEEN BibleChapter.FirstVerseId AND BibleChapter.LastVerseId
      WHERE Document.MepsDocumentId = ? AND BlockNumber = ?;
      ''',
        [widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, versesReferenceId]);

    if (response.isNotEmpty) {
      List<Map<String, dynamic>> versesItems = [];

      // Process each verse in the response
      for (var verse in response) {
        String htmlContent = '';
        htmlContent += verse['Label'];
        final decodedHtml = decodeBlobContent(
          verse['Content'] as Uint8List,
          widget.publication.hash
        );
        htmlContent += decodedHtml;

        String verseDisplay = JwLifeApp.bibleCluesInfo.getVerses(
            verse['BookNumber'], verse['ChapterNumber'], verse['VerseNumber'],
            verse['BookNumber'], verse['ChapterNumber'], verse['VerseNumber']
        );

        versesItems.add({
          'type': 'verse',
          'content': createHtmlDialogContent(
              htmlContent,
              "bibleCitation html5 pub-${widget.publication.keySymbol} jwac showRuby ml-${widget.publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar"
          ),
          'subtitle': widget.publication.mepsLanguage.vernacular,
          'imageUrl': widget.publication.imageSqr,
          'publicationTitle': verseDisplay,
          'bookNumber': verse['BookNumber'],
          'chapterNumber': verse['ChapterNumber'],
          'verseNumber': verse['VerseNumber'],
          'mepsLanguageId': JwLifeApp.pubCollections.getBibles().first.mepsLanguage.id,
          'verse': verse['ElementNumber'],
        });
      }

      dynamic versesJson = {
        'items': versesItems,
        'title': 'Renvois',
      };

      // Inject HTML content in JavaScript dialog
      injectHtmlDialog(versesJson);
    }
  }

  Future<void> injectHtmlDialog(dynamic content) async {
    // Encodez le contenu HTML en échappant les caractères spéciaux
    await _controller.evaluateJavascript(source: """
  {
    // Création d'une variable locale document pour accéder facilement aux données
    const json = ${json.encode(content)};
    
    // Supprimez le dialogue existant s'il y en a un
    const existingDialog = document.getElementById('customDialog');
    if (existingDialog) {
      existingDialog.remove(); // Supprimez le dialogue existant
    }
    
    let isFullscreen = false; // Flag de statut
    
    // Créez un nouveau dialogue
    const dialog = document.createElement('div');
    dialog.id = 'customDialog';
    dialog.style.cssText = 'position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: ${JwLifeApp.settings.webViewData.backgroundColor}; padding: 0; border-radius: 0px; box-shadow: 0 4px 20px rgba(0.8,0.8,1,1); z-index: 1000; width: 80%; max-width: 800px;';
    
    // Définir les thèmes en fonction de la variable isDark
    const isDark = ${Theme.of(context).brightness == Brightness.dark}; // Cette variable doit être passée depuis Flutter
    
    // Créer le header (barre supérieure du dialogue)
    const header = document.createElement('div');
    
    // Style pour le theme
    const headerStyle = isDark ? 'background: #333; color: white;' : 'background: #d8d7d5; color: #333333;';
    // Appliquer le style à l'en-tête
    header.style.cssText = `\${headerStyle} padding: 5px; padding-left: 10px; padding-right: 10px; font-size: 18px; font-weight: bold; display: flex; align-items: center; border-top-left-radius: 0px; border-top-right-radius: 0px; height: 40px;`;
    
    // **Création du conteneur pour déplacer**
    const dragArea = document.createElement('div');
    dragArea.style.cssText = 'flex-grow: 1; cursor: move;';
    // Ajout du titre du verset
    dragArea.innerHTML = json.title;
    
    // **Variables pour le déplacement**
    let isDragging = false;
    let offsetX = 0, offsetY = 0;
    function startDrag(event) {
      if (isFullscreen) return;
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
      if (isFullscreen) {
        // Sortie du plein écran
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('showFullscreenDialog', {'isFullscreen': false, 'closeDialog': false});
        } 
        isFullscreen = false;
        dialog.style.position = 'fixed';
        dialog.style.top = '50%';
        dialog.style.left = '50%';
        dialog.style.transform = 'translate(-50%, -50%)';
        dialog.style.width = '80%';
        dialog.style.height = 'auto';
        dialog.style.marginTop = '0';
        
        contentContainer.style.cssText = 'max-height: 50vh; overflow-y: auto; background-color: ${JwLifeApp.settings.webViewData.backgroundColor};';
      } else {
        // Passage en plein écran
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('showFullscreenDialog', {'isFullscreen': true, 'closeDialog': false});
        } 
        isFullscreen = true;
        dialog.style.position = 'fixed';
        dialog.style.top = '0';
        dialog.style.left = '0';
        dialog.style.width = '100vw';
        dialog.style.height = '100vh';
        dialog.style.transform = 'none';
        dialog.style.marginTop = '90px';
        
        // Calcul de la hauteur disponible pour le content
        const dialogTopMargin = 190; // en pixels
        contentContainer.style.cssText = `
          overflow-y: auto;
          background-color: ${JwLifeApp.settings.webViewData.backgroundColor};
          max-height: calc(100vh - \${dialogTopMargin}px);`;
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
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('showFullscreenDialog', {'isFullscreen': false, 'closeDialog': true});
      }
    };
    
    // **Ajout des boutons dans le conteneur**
    buttonContainer.appendChild(fullscreenButton);
    buttonContainer.appendChild(closeButton);
    
    // **Ajout du dragArea et du buttonContainer dans le header**
    header.appendChild(dragArea);
    header.appendChild(buttonContainer);
    
    // **Ajout du header au dialog**
    dialog.appendChild(header);
    
    // Créer un conteneur pour tous les contenus
    const contentContainer = document.createElement('div');
    contentContainer.style.cssText = 'max-height: 50vh; overflow-y: auto; background-color: ${JwLifeApp.settings.webViewData.backgroundColor};';
    
    // Style commun pour les thèmes
const infoBarStyle = isDark 
  ? 'background: black; color: white;' 
  : 'background: #f2f1ef; color: black;';

// Parcourir tous les items et créer une barre d'info et un contenu pour chacun
json.items.forEach((item, index) => {
  // Créer la barre d'information (infoBar)
  const infoBar = document.createElement('div');
  infoBar.style.cssText = 'display: flex; align-items: center; ' + infoBarStyle;

  // Créer l'image pour la barre d'information
  const img = document.createElement('img');
  img.src = 'file://' + item.imageUrl;
  img.style.cssText = 'height: 50px; margin: 0; padding: 0;';

  // Créer le conteneur de texte pour la barre d'information
  const textContainer = document.createElement('div');
  textContainer.style.cssText = 'text-align: left; margin-left: 10px;';

  const pubText = document.createElement('div');
  pubText.textContent = item.publicationTitle;
  pubText.style.cssText = 'font-size: 16px; font-weight: bold;';

  // Créer le texte du sous-titre
  const subtitleText = document.createElement('div');
  subtitleText.textContent = item.subtitle;
  subtitleText.style.cssText = 'font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;';

  textContainer.appendChild(pubText);
  textContainer.appendChild(subtitleText);

  // Ajouter l'image et le texte à la barre d'information
  infoBar.appendChild(img);
  infoBar.appendChild(textContainer);

  // Créer un bouton audio à droite de la barre d'information
  const audioButton = document.createElement('button');
  audioButton.innerHTML = '&#xE69D;'; // Icône ou texte pour le bouton audio
  audioButton.style.cssText = `
  font-family: jw-icons-external;
  font-size: 25px;
  padding: 5px 10px;
  margin-left: auto;
  cursor: pointer;
  border: 1.5px solid #ccc; /* Ajoute un encadré de 2px de couleur gris clair */
  background-color: transparent; /* Fond transparent */
`;
  
  // Ajouter un événement au bouton audio pour jouer l'audio
  audioButton.addEventListener('click', function() {
    // Empêche la propagation de l'événement au parent (infoBar)
    event.stopPropagation();
    
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('playVerseAudio', {'verse': item, 'audio': item.audio});
    } 
  });

  // Ajouter le bouton audio à la barre d'info
  infoBar.appendChild(audioButton);

  // Ajout d'un écouteur d'événements pour ouvrir une fenêtre Flutter
  infoBar.addEventListener('click', function() {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('openMepsDocument', item);
    } else {
      console.log('Flutter handler non disponible');
    }
  });

  // Créer le contenu pour l'item
  const content = document.createElement('div');
  content.innerHTML = item.content;
  content.style.cssText = 'padding: 10px;';

  // Ajouter la barre d'information et le contenu au conteneur
  if(item.type !== 'note') {
    contentContainer.appendChild(infoBar);
  }
  contentContainer.appendChild(content);
});

// Ajouter le conteneur de contenu au dialogue
dialog.appendChild(contentContainer);

// Ajouter le dialogue au body
document.body.appendChild(dialog);
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

  Future<void> loadJavascriptData(InAppWebViewController controller) async {
    final document = widget.publication.documentsManager!.getCurrentDocument();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    await Future.wait([
      loadJavascriptToolBars(controller, widget.audios, document, isDarkMode),
      //loadJavascriptUserdata(controller, document, isDarkMode),
      // loadJavascriptHighlight(controller, document, isDarkMode),
    ]);
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
        _isLoadingData
            ? InAppWebView(
            initialSettings: InAppWebViewSettings(
              cacheMode: CacheMode.LOAD_DEFAULT,
              cacheEnabled: true,
              useOnLoadResource: true,
              clearCache: false,
              allowUniversalAccessFromFileURLs: true,
            ),
            initialData: InAppWebViewInitialData(
              data: widget.publication.documentsManager!.createReaderHtmlShell(),
              mimeType: 'text/html',
              baseUrl: WebUri('file://$webappPath/'),
            ),
            onWebViewCreated: (controller) async {
              _controller = controller;

              controller.addJavaScriptHandler(
                handlerName: 'getPage',
                callback: (args) async {
                  final index = args[0] as int;
                  if (index < 0 || index >= widget.publication.documentsManager!.documents.length) {
                    return {'html': '', 'className': '', 'audiosMarkers': ''};
                  }
                  final doc = widget.publication.documentsManager!.documents[index];

                  String html = '';
                  if(doc.isBibleChapter()) {
                    List<Uint8List> contentBlob = doc.getChapterContent();

                    for(dynamic content in contentBlob) {
                      html += decodeBlobContent(
                        content,
                        widget.publication.hash,
                      );
                    }
                  }
                  else {
                    html = decodeBlobContent(doc.content!, widget.publication.hash);
                  }
                  final className = getArticleClass(doc);

                  List<Map<String, dynamic>> audioMarkersJson = [];

                  if (widget.audios.isNotEmpty) {
                    final audio = widget.audios.firstWhereOrNull((a) => a.documentId == doc.mepsDocumentId);;
                    if (audio != null && audio.markers.isNotEmpty) {
                      audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                    }
                  }

                  return {
                    'html': html,
                    'className': className,
                    'audiosMarkers': audioMarkersJson,
                  };
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'onSwipe',
                callback: (args) async {
                  await onSwipe(args[0] as String);
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'getUserdata',
                callback: (args) {
                  return {
                    'bookmarks': widget.publication.documentsManager!.getCurrentDocument().bookmarks,
                    'inputFields': widget.publication.documentsManager!.getCurrentDocument().inputFields,
                    'highlights': widget.publication.documentsManager!.getCurrentDocument().highlights
                  };
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'onScroll',
                callback: (args) {
                  if(!_showDialog) {
                    if (!_isProgrammaticScroll) {
                      if (args[1] == "down") {
                        if (_controlsVisible) {
                          setState(() {
                            _controlsVisible = false;
                            _controlsVisibleSave = false;
                          });
                        }
                      }
                      else if (args[1] == "up") {
                        if (!_controlsVisible) {
                          setState(() {
                            _controlsVisible = true;
                            _controlsVisibleSave = true;
                          });
                        }
                      }
                    }
                  }
                },
              );

              // Gestionnaire pour les clics sur les images
              controller.addJavaScriptHandler(
                handlerName: 'getGuid',
                callback: (args) {
                  var uuid = Uuid();
                  return {
                    'uuid': uuid.v4()
                  };
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
                handlerName: 'fetchFootnote',
                callback: (args) {
                  fetchFootnote(args[0]);
                },
              );

              // Gestionnaire pour les clics sur les images
              controller.addJavaScriptHandler(
                handlerName: 'fetchVersesReference',
                callback: (args) {
                  fetchVersesReference(args[0]);
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'openMepsDocument',
                callback: (args) {
                  Map<String, dynamic>? document = args[0];
                  if (document != null) {
                    if (document['mepsDocumentId'] != null) {
                      showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);
                    }
                    else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                      showChapterView(
                        context,
                        'nwtsty',
                        document["mepsLanguageId"],
                        document["bookNumber"],
                        document["chapterNumber"],
                        firstVerseNumber: document["firstVerseNumber"],
                        lastVerseNumber: document["lastVerseNumber"],
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

              controller.addJavaScriptHandler(
                handlerName: 'bookmark',
                callback: (args) async {
                  final arg = args[0];
                  final String paragraphNumber = arg['paragraphId'];

                  final String snippet = arg['snippet'];

                  final docManager = widget.publication.documentsManager!;
                  final currentDoc = docManager.getCurrentDocument();

                  int? blockIdentifier;
                  int blockType = 0;

                  if (paragraphNumber.contains('v')) {
                    // Cas d’un verset
                    final parts = paragraphNumber.split('-');
                    int? blockIdentifier = int.tryParse(parts[2]);
                    blockType = blockIdentifier != null ? 2 : 0;

                    print('blockIdentifier: $blockIdentifier');
                    print('blockType: $blockType');
                    print('bookNumber: ${currentDoc.bookNumber}');
                    print('chapterNumber: ${currentDoc.chapterNumber}');

                    final bookmark = await showBookmarkDialog(
                      context,
                      widget.publication,
                      webViewController: _controller,
                      bookNumber: currentDoc.bookNumber,
                      chapterNumber: currentDoc.chapterNumber,
                      title: '${currentDoc.displayTitle} ${currentDoc.chapterNumber}',
                      snippet: snippet,
                      blockType: blockType,
                      blockIdentifier: blockIdentifier,
                    );

                    if(bookmark != null) {
                      if (bookmark['BookNumber'] != null && bookmark['ChapterNumber'] != null) {
                        final page = docManager.documents.indexWhere((doc) => doc.bookNumber == bookmark['BookNumber'] && doc.chapterNumberBible == bookmark['ChapterNumber']);

                        if (page != widget.publication.documentsManager!.documentIndex) {
                          await _jumpToPage(page);
                        }

                        if(bookmark['BlockIdentifier'] != null) {
                          _jumpToVerse(bookmark['BlockIdentifier'], bookmark['BlockIdentifier']);
                        }
                      }
                    }
                  }
                  else {
                    // Cas d’un paragraphe classique
                    blockIdentifier = int.tryParse(paragraphNumber);
                    blockType = blockIdentifier != null ? 1 : 0;

                    print('blockIdentifier: $blockIdentifier');
                    print('blockType: $blockType');
                    print('mepsDocumentId: ${currentDoc.mepsDocumentId}');
                    print('title: ${currentDoc.displayTitle}');

                    final bookmark = await showBookmarkDialog(
                      context,
                      widget.publication,
                      webViewController: _controller,
                      mepsDocumentId: currentDoc.mepsDocumentId,
                      title: currentDoc.displayTitle,
                      snippet: snippet,
                      blockType: blockType,
                      blockIdentifier: blockIdentifier,
                    );

                    if(bookmark != null) {
                      if (bookmark['MepsDocumentId'] != currentDoc.mepsDocumentId) {
                        final page = docManager.documents.indexWhere(
                              (doc) => doc.mepsDocumentId == bookmark['DocumentId'],
                        );
                        if (page != widget.publication.documentsManager!.documentIndex) {
                          await _jumpToPage(page);
                        }
                      }

                      // Aller au paragraphe dans la même page
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
                  bool isBible = args[0]['isBible'];
                  if(isBible) {
                    //int verseId = int.parse(args[0]['paragraphId']);
                    //Map<String, dynamic> note = await JwLifeApp.userdata.addNote('', '', 0, [], widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, widget.publication.issueTagNumber, widget.publication.keySymbol, widget.publication.mepsLanguage.id, blockType: 1, blockIdentifier: paragraphId);
                    //showPage(context, NoteView(note: note));
                  }
                  else {
                    int paragraphId = int.parse(args[0]['paragraphId']);
                    Map<String, dynamic> note = await JwLifeApp.userdata.addNote('', '', 0, [], widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, widget.publication.issueTagNumber, widget.publication.keySymbol, widget.publication.mepsLanguage.id, blockType: 1, blockIdentifier: paragraphId);
                    showPage(context, NoteView(note: note));
                  }
                },
              );

              // Gestionnaire pour les modifications des champs de formulaire
              controller.addJavaScriptHandler(
                handlerName: 'showFullscreenDialog',
                callback: (args) async {
                  bool isFullscreen = args[0]['isFullscreen'];
                  bool closeDialog = args[0]['closeDialog'];
                  setState(() {
                    if(closeDialog) {
                      _controlsVisible = _controlsVisibleSave;
                    }
                    else {
                      _controlsVisible = true;
                    }
                    _showDialog = isFullscreen;
                  });
                },
              );

              // Gestionnaire pour les modifications des champs de formulaire
              controller.addJavaScriptHandler(
                handlerName: 'share',
                callback: (args) async {
                  bool isBible = args[0]['isBible'];
                  widget.publication.documentsManager!.getCurrentDocument().share(isBible, paragraphId: args[0]['paragraphId']);
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

              controller.addJavaScriptHandler(
                handlerName: 'playVerseAudio',
                callback: (args) async {
                  dynamic audio = args[0]['audio'];
                  dynamic verse = args[0]['verse'];

                  int verseNumber = verse['verseNumber'];
                  String url = audio['url'];
                  Duration startDuration = Duration.zero;
                  Duration? endDuration;

                  dynamic markers = audio['markers'];

                  if (markers != null) {
                    for (int i = 0; i < markers.length; i++) {
                      if (markers[i]['verseNumber'] == verseNumber) {
                        startDuration = parseDuration(markers[i]['startTime']);
                        Duration duration = parseDuration(markers[i]['duration']);
                        endDuration = startDuration + duration;
                        break;
                      }
                    }
                  }

                  audio_service.MediaItem mediaItem = audio_service.MediaItem(
                      id: '0',
                      album: JwLifeApp.pubCollections.getBibles().first.title,
                      title: JwLifeApp.bibleCluesInfo.getVerse(verse['bookNumber'], verse['chapterNumber'], verseNumber),
                      artUri: Uri.file(JwLifeApp.pubCollections.getBibles().first.imageSqr!)
                  );

                  showAudioPlayerForLink(context, url, mediaItem, initialPosition: startDuration, endPosition: endDuration);
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
                handlerName: 'searchVerse',
                callback: (args) async {
                  String verse = args[0]['query'].toString().substring(1);
                  String book = verse.split(('-'))[0];
                  String chapter = verse.split(('-'))[1];
                  String verseNumber = verse.split(('-'))[2];

                  String query = JwLifeApp.bibleCluesInfo.getVerse(int.parse(book), int.parse(chapter), int.parse(verseNumber));
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

                    Publication? publication = await PubCatalog.searchPub(pub!, issueTagNumber, wtlocale!);
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
            onLoadStop: (controller, url) async {
              if(!_jumpToParagraphExecuted) {
                if (widget.startParagraphId != null && widget.endParagraphId != null) {
                  await _jumpToParagraph(widget.startParagraphId!, widget.endParagraphId!);
                }

                if(widget.firstVerse != null && widget.lastVerse != null) {
                  await _jumpToVerse(widget.firstVerse!, widget.lastVerse!);
                }
                setState(() {
                  _jumpToParagraphExecuted = true;
                });

                if(widget.wordsSelected.isNotEmpty) {
                  await _controller.evaluateJavascript(source: 'selectWords(${jsonEncode(widget.wordsSelected)});');
                }
              }
            },
            onProgressChanged: (controller, progress) async {
              if (progress == 100) {
                setState(() {
                  _isLoadingWebView = true;
                });
              }
            }
        ) : Container(),
        if (_showNotes) PublicationNotesView(docId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId),
        if (!_isLoadingData || !_isLoadingWebView) const Center(child: CircularProgressIndicator()),
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
                    : !_isLoadingData ? Container() : Column(
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
                    if(_showDialog) {
                      _showDialog = false;
                      _controller.evaluateJavascript(source: """
                        const existingDialog = document.getElementById('customDialog');
                        if (existingDialog) {
                          existingDialog.remove(); // Supprimez le dialogue existant
                        }
                      """);
                    }
                    else if (_showNotes) {
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
                    !_isLoadingData ? Container() : ResponsiveAppBarActions(
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
                                int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.bookNumber == bookmark['BookNumber'] && doc.chapterNumber == bookmark['ChapterNumber']);

                                if (page != widget.publication.documentsManager!.documentIndex) {
                                  await _jumpToPage(page);
                                }

                                if (bookmark['BlockIdentifier'] != null) {
                                   _jumpToVerse(bookmark['BlockIdentifier'], bookmark['BlockIdentifier']);
                                };
                              }
                              else {
                                if(bookmark['MepsDocumentId'] != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                                  int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark['DocumentId']);

                                  if (page != widget.publication.documentsManager!.documentIndex) {
                                    await _jumpToPage(page);
                                  }

                                  if (bookmark['BlockIdentifier'] != null) {
                                    _jumpToParagraph(bookmark['BlockIdentifier'], bookmark['BlockIdentifier']);
                                  }
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
                            widget.publication.documentsManager!.getCurrentDocument().share(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter());
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
                            Document document = widget.publication.documentsManager!.getCurrentDocument();
                            if(document.isBibleChapter()) {
                              await showHtmlDialog(context, decodeBlobContent(document.chapterContent!, widget.publication.hash));
                            }
                            else {
                              await showHtmlDialog(context, decodeBlobContent(document.content!, widget.publication.hash));
                            }
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

  String getArticleClass(Document document) {
    String publication = document.isBibleChapter() ? 'bible' : 'document';
    return '''$publication html5 pub-${widget.publication.keySymbol} jwac docClass-${document.classType} docId-${document.documentId} ms-ROMAN ml-${widget.publication.mepsLanguage.symbol} dir-ltr layout-reading layout-sidebar ${JwLifeApp.settings.webViewData.theme}''';
  }
}