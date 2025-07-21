import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/databases/publication_category.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/views/search_views/search_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import '../../../../../../../core/utils/directory_helper.dart';
import '../../../../../../../core/utils/widgets_utils.dart';
import '../../../../../../../data/models/userdata/bookmark.dart';
import '../../../../../app/services/settings_service.dart';
import 'document_medias_page.dart';
import '../data/models/document.dart';
import 'package:audio_service/audio_service.dart' as audio_service;

import 'documents_manager.dart';
import 'full_screen_image_page.dart';


class DocumentPage extends StatefulWidget {
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

  const DocumentPage({
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
  const DocumentPage.bible({
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
  _DocumentPageState createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> with SingleTickerProviderStateMixin {
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
  bool _isLoadingFonts = false;

  /* OTHER VIEW */
  bool _isProgrammaticScroll = false; // Variable pour éviter l'interférence
  String _lastDirectionScroll = ''; // Variable pour éviter l'interférence
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _controlsVisibleSave = true; // Variable pour contrôler la visibilité des contrôles
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  int? lastDocumentId;
  int lastParagraphId = 0;

  late StreamSubscription<SequenceState?> _streamSequenceStateSubscription;
  late StreamSubscription<Duration?> _streamSequencePositionSubscription;

  @override
  void initState() {
    super.initState();
    init();

    _streamSequenceStateSubscription = JwLifeApp.audioPlayer.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      if (JwLifeApp.audioPlayer.isSettingPlaylist && state.currentIndex == 0) return;

      final currentSource = state.currentSource;
      if (currentSource is! ProgressiveAudioSource) {
        if (lastParagraphId != -1) {
          _jumpToParagraph(-1, -1);
          lastParagraphId = -1;
        }
        return;
      }

      ProgressiveAudioSource source = currentSource;
      var tag = source.tag as audio_service.MediaItem?;

      lastDocumentId = tag?.extras?['documentId'];

      if(widget.publication.documentsManager!.documents.any((document) => document.mepsDocumentId == lastDocumentId)) {
        int? currentIndex = state.currentIndex;

        if(currentIndex == null || currentIndex == -1) {
          _jumpToParagraph(-1, -1);
        }
        else {
          Audio audio = widget.audios[currentIndex];
          if(audio.documentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
            _jumpToPage(widget.publication.documentsManager!.documents.indexWhere((document) => document.mepsDocumentId == audio.documentId));
          }
        }
      }
      else if (lastParagraphId != -1) {
        _jumpToParagraph(-1, -1);
        lastParagraphId = -1;
      }
    });

    _streamSequencePositionSubscription = JwLifeApp.audioPlayer.player.positionStream.listen((position) {
      if (!mounted) return;
      if(lastDocumentId != null && lastDocumentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
        Audio? audio = widget.audios.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
        if(audio != null) {
          Marker? marker = audio.markers.firstWhereOrNull((m) {
            final start = parseDuration(m.startTime).inSeconds;
            final end = start + parseDuration(m.duration).inSeconds;
            return position.inSeconds >= start && position.inSeconds <= end;
          });

          if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
            if (marker != null && marker.verseNumber != null) {
              if (marker.verseNumber != lastParagraphId) {
                _jumpToVerse(marker.verseNumber!, marker.verseNumber!);
                lastParagraphId = marker.verseNumber!;
              }
            }
          }
          else {
            if (marker != null && marker.mepsParagraphId != null) {
              if (marker.mepsParagraphId != lastParagraphId) {
                _jumpToParagraph(marker.mepsParagraphId!, marker.mepsParagraphId!);
                lastParagraphId = marker.mepsParagraphId!;
              }
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _streamSequenceStateSubscription.cancel();
    _streamSequencePositionSubscription.cancel();
    _controller.dispose();
  }

  Widget onAnimationUpdate () {
    printTime('didChangeDependencies');
    super.didChangeDependencies();
    return const Placeholder();
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

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt();

    _isFullscreen = await getFullscreen();

    JwLifePage.toggleNavBarPositioned.call(true);
    JwLifePage.toggleNavBarVisibility.call(true);
  }

  Future<void> changePageAt(int index) async {
    if (index <= widget.publication.documentsManager!.documents.length - 1 && index >= 0) {
      setState(() {
        widget.publication.documentsManager!.documentIndex = index;
      });

      await widget.publication.documentsManager!.getCurrentDocument().changePageAt();
    }
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

    _pageHistory.add(widget.publication.documentsManager!.documentIndex); // Ajouter la page actuelle à l'historique
    _currentPageHistory = page;

    setState(() async {
      if (page != widget.publication.documentsManager!.documentIndex) {
        widget.publication.documentsManager!.documentIndex = page;
      }

      await _controller.evaluateJavascript(source: 'jumpToPage($page);');

      setControlsVisible(true);
    });
  }

  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    JwLifePage.toggleNavBarVisibility(visible);
  }

  bool _handleBackPress() {
    if (_pageHistory.isNotEmpty) {
      _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
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
        printTime('Loading error: ${response.statusCode}');
      }
    }
    catch (e) {
      printTime('An exception occurred: $e');
    }

     */

    try {
      for (var bible in PublicationRepository().getAllBibles()) {
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
            bible.hash!,
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
      printTime('Error fetching verses: $e');
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
            extract['Content'] as Uint8List, widget.publication.hash!);
        var doc = parse(extract['Caption']);
        String caption = doc.querySelector('.etitle')?.text ?? '';

        String image = '';
        if (pub != null && pub['ImageSqr'] != null) {
          String imagePath = "https://app.jw-cdn.org/catalogs/publications/${pub['ImageSqr']}";
          image = (await JwLifeApp.tilesCache.getOrDownloadImage(imagePath))!.file.path;
        }
        else {
          String type = PublicationCategory.all.firstWhere(
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
        await showDocumentView(context, mepsDocumentId, widget.publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
        JwLifePage.toggleNavBarVisibility(_controlsVisible);
        JwLifePage.toggleNavBarPositioned(true);
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
          widget.publication.hash!
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
          widget.publication.hash!
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
          'mepsLanguageId': PublicationRepository().getAllBibles().first.mepsLanguage.id,
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
          dialog.style.cssText = 'position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: ${JwLifeSettings().webViewData.backgroundColor}; padding: 0; border-radius: 0px; box-shadow: 0 4px 20px rgba(0.8,0.8,1,1); z-index: 1000; width: 80%; max-width: 800px;';
          
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
          fullscreenButton.innerHTML = '&#xE6AF;';
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
              fullscreenButton.innerHTML = '&#xE6AF;';
              
              contentContainer.style.cssText = 'max-height: 50vh; overflow-y: auto; background-color: ${JwLifeSettings().webViewData.backgroundColor};';
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
              fullscreenButton.innerHTML = '&#xE6B3;';
              
              // Calcul de la hauteur disponible pour le content
              const dialogTopMargin = 190; // en pixels
              contentContainer.style.cssText = `
                overflow-y: auto;
                background-color: ${JwLifeSettings().webViewData.backgroundColor};
                max-height: calc(100vh - \${dialogTopMargin}px);`;
            }
          };
          
          // **Bouton fermer**
          const closeButton = document.createElement('button');
          closeButton.innerHTML = '&#xE6D8;';
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
          contentContainer.style.cssText = 'max-height: 50vh; overflow-y: auto; background-color: ${JwLifeSettings().webViewData.backgroundColor};';
          
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
        // infoBar.appendChild(audioButton);
      
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
    String newPath = path.split('//').last.toLowerCase().trim();

    int indexImage = widget.publication.documentsManager!.getCurrentDocument().multimedias.indexWhere((img) => img.filePath.toLowerCase().contains(newPath));

    if (!widget.publication.documentsManager!.getCurrentDocument().multimedias.elementAt(indexImage).hasSuppressZoom) {
      JwLifePage.toggleNavBarBlack.call(true);

      showPage(context, FullScreenImagePage(
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
      body: Stack(children: [
        Visibility(
            visible: _isLoadingWebView,
            maintainState: true,
            child: _isLoadingData ? InAppWebView(
                initialSettings: InAppWebViewSettings(
                  disableContextMenu: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  disableDefaultErrorPage: true,
                  useOnLoadResource: false,         // À désactiver sauf si tu surveilles les requêtes
                  allowUniversalAccessFromFileURLs: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  loadWithOverviewMode: true,
                  useHybridComposition: true,
                  offscreenPreRaster: true,
                  hardwareAcceleration: true,
                  databaseEnabled: false,
                  domStorageEnabled: true,
                ),
                initialData: InAppWebViewInitialData(
                    data: widget.publication.documentsManager!.createReaderHtmlShell(widget),
                    baseUrl: WebUri('file://$webappPath/')
                ),
                onWebViewCreated: (controller) async {
                  _controller = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'fontsLoaded',
                    callback: (args) {
                      setState(() {
                        _isLoadingFonts = true;
                      });
                    }
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'showDialog',
                    callback: (args) {
                      bool isShowDialog = args[0] as bool;
                      setState(() {
                        if(isShowDialog) {
                          _showDialog = true;
                        }
                        else {
                          setControlsVisible(_controlsVisibleSave);
                          _showDialog = false;
                        }
                      });
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'showFullscreenPopup',
                    callback: (args) {
                      bool isMaximized = args[0] as bool;
                      setState(() {
                        if(isMaximized) {
                          setControlsVisible(true);
                        }
                        else {
                          setControlsVisible(_controlsVisibleSave);
                        }
                      });
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'getPage',
                    callback: (args) async {
                      final index = args[0] as int;
                      if (index < 0 || index >= widget.publication.documentsManager!.documents.length) {
                        return {'html': '', 'className': '', 'audiosMarkers': '', 'isBibleChapter': false};
                      }

                      final doc = widget.publication.documentsManager!.documents[index];

                      String html = '';
                      List<Map<String, dynamic>> audioMarkersJson = [];

                      if(doc.isBibleChapter()) {
                        List<Uint8List> contentBlob = doc.getChapterContent();

                        for(dynamic content in contentBlob) {
                          html += decodeBlobContent(
                            content,
                            widget.publication.hash!,
                          );
                        }

                        if (widget.audios.isNotEmpty) {
                          final audio = widget.audios.firstWhereOrNull((a) => a.bookNumber == doc.bookNumber && a.track == doc.chapterNumberBible);
                          if (audio != null && audio.markers.isNotEmpty) {
                            audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                          }
                        }
                      }
                      else {
                        html = decodeBlobContent(doc.content!, widget.publication.hash!);

                        if (widget.audios.isNotEmpty) {
                          final audio = widget.audios.firstWhereOrNull((a) => a.documentId == doc.mepsDocumentId);;
                          if (audio != null && audio.markers.isNotEmpty) {
                            audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                          }
                        }
                      }
                      final className = getArticleClass(doc);

                      return {
                        'html': html,
                        'className': className,
                        'audiosMarkers': audioMarkersJson,
                        'isBibleChapter': doc.isBibleChapter(),
                      };
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'changePageAt',
                    callback: (args) async {
                      await changePageAt(args[0] as int);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'getUserdata',
                    callback: (args) {
                      for(var note in widget.publication.documentsManager!.getCurrentDocument().notes) {
                        printTime('note: $note');
                      }
                      return {
                        'highlights': widget.publication.documentsManager!.getCurrentDocument().highlights,
                        'notes': widget.publication.documentsManager!.getCurrentDocument().notes,
                        'inputFields': widget.publication.documentsManager!.getCurrentDocument().inputFields,
                        'bookmarks': widget.publication.documentsManager!.getCurrentDocument().bookmarks,
                      };
                    },
                  );

                  /*

                  controller.addJavaScriptHandler(
                    handlerName: 'onScrollStart',
                    callback: (args) async {
                      printTime('onScrollStart');
                      if(!_useHybridComposition) {
                        InAppWebViewSettings? settings = await _controller.getSettings();
                        if (settings != null) {
                          printTime('onScrollStart to true');
                          settings.useHybridComposition = true;
                          _useHybridComposition = true;
                        }
                      }
                    }
                  );

                  controller.addJavaScriptHandler(
                      handlerName: 'onScrollEnd',
                      callback: (args) async {
                        printTime('onScrollStart');
                        if(_useHybridComposition) {
                          InAppWebViewSettings? settings = await _controller.getSettings();
                          if (settings != null) {
                            printTime('onScrollEnd to false');
                            settings.useHybridComposition = false;
                            _useHybridComposition = false;
                          }
                        }
                      }
                  );

                   */

                  controller.addJavaScriptHandler(
                    handlerName: 'onScroll',
                    callback: (args) async {
                      if(!_showDialog) {
                        if (!_isProgrammaticScroll) {
                          if (args[1] == "down" && _lastDirectionScroll != "down") {
                            setState(() {
                              _controlsVisible = false;
                              _controlsVisibleSave = false;
                            });
                            // enelever la barre de noti en haut de l'ecran
                            //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
                            JwLifePage.toggleNavBarVisibility.call(false);
                          }
                          else if (args[1] == "up" && _lastDirectionScroll != "up") {
                            setState(() {
                              _controlsVisible = true;
                              _controlsVisibleSave = true;
                            });
                            // remettre la barre de noti en haut de l'ecran
                            //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
                            JwLifePage.toggleNavBarVisibility.call(true);
                          }
                          _lastDirectionScroll = args[1];
                        }
                      }
                    },
                  );

                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'getHighlightGuid',
                    callback: (args) {
                      var uuid = Uuid();
                      return {
                        'guid': uuid.v4()
                      };
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'addHighlights',
                    callback: (args) {
                      printTime('addHighlights ${args[0]} ${args[1]} ${args[2]}');
                      widget.publication.documentsManager!.getCurrentDocument().addHighlights(
                        args[0],
                        args[1],
                        args[2]
                      );
                    },
                  );

                  // Quand on clique supprime le highlight
                  controller.addJavaScriptHandler(
                      handlerName: 'removeHighlight',
                      callback: (args) {
                        widget.publication.documentsManager!.getCurrentDocument().removeHighlight(args[0]['guid']);
                      }
                  );

                  // Quand on change le color index d'un highlight
                  controller.addJavaScriptHandler(
                      handlerName: 'changeHighlightColor',
                      callback: (args) {
                        widget.publication.documentsManager!.getCurrentDocument().changeHighlightColor(args[0]['guid'], args[0]['newColorIndex']);
                      }
                  );


                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'addNote',
                    callback: (args) {
                      var uuid = Uuid();
                      String uuidV4 = uuid.v4();

                      widget.publication.documentsManager!.getCurrentDocument().addNoteWithUserMarkGuid(
                        args[0]['blockType'],
                        int.parse(args[0]['identifier']),
                        args[0]['title'],
                        uuidV4,
                        args[0]['userMarkGuid'],
                        args[0]['colorIndex'],
                      );
                      return {
                        'uuid': uuidV4
                      };
                    },
                  );

                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'removeNote',
                    callback: (args) {
                      String guid = args[0]['guid'];
                      widget.publication.documentsManager!.getCurrentDocument().removeNote(guid);
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
                    callback: (args) async {
                      Map<String, dynamic>? document = args[0];
                      if (document != null) {
                        if (document['mepsDocumentId'] != null) {
                          await showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);
                          JwLifePage.toggleNavBarVisibility(_controlsVisible);
                          JwLifePage.toggleNavBarPositioned(true);
                        }
                        else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                          await showChapterView(
                            context,
                            'nwtsty',
                            document["mepsLanguageId"],
                            document["bookNumber"],
                            document["chapterNumber"],
                            firstVerseNumber: document["firstVerseNumber"],
                            lastVerseNumber: document["lastVerseNumber"],
                          );
                          JwLifePage.toggleNavBarVisibility(_controlsVisible);
                          JwLifePage.toggleNavBarPositioned(true);
                        }
                      }
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onInputChange',
                    callback: (args) {
                      String tag = args[0]['tag'];
                      String value = args[0]['value'];
                      widget.publication.documentsManager!.getCurrentDocument().updateOrInsertInputFieldValue(tag, value);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'updateNote',
                    callback: (args) {
                      String uuid = args[0]['noteGuid'];
                      String title = args[0]['title'];
                      String content = args[0]['content'];
                      widget.publication.documentsManager!.getCurrentDocument().updateNote(uuid, title, content);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'bookmark',
                    callback: (args) async {
                      final arg = args[0];

                      final bool isBible = arg['isBible'];
                      final String id = arg['id'];
                      final String snippet = arg['snippet'];

                      final docManager = widget.publication.documentsManager!;
                      final currentDoc = docManager.getCurrentDocument();

                      if (isBible) {
                        // Cas d’un verset
                        int? blockIdentifier = int.tryParse(id);
                        int blockType = blockIdentifier != null ? 2 : 0;

                        printTime('blockIdentifier: $blockIdentifier');
                        printTime('blockType: $blockType');
                        printTime('bookNumber: ${currentDoc.bookNumber}');
                        printTime('chapterNumber: ${currentDoc.chapterNumber}');

                        Bookmark? bookmark = await showBookmarkDialog(
                          context,
                          widget.publication,
                          webViewController: _controller,
                          bookNumber: currentDoc.bookNumber,
                          chapterNumber: currentDoc.chapterNumber,
                          title: '${currentDoc.displayTitle} ${currentDoc.chapterNumber}',
                          snippet: snippet.trim(),
                          blockType: blockType,
                          blockIdentifier: blockIdentifier,
                        );

                        if(bookmark != null) {
                          if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                            final page = docManager.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumberBible == bookmark.location.chapterNumber);

                            if (page != widget.publication.documentsManager!.documentIndex) {
                              await _jumpToPage(page);
                            }

                            if(bookmark.blockIdentifier != null) {
                              _jumpToVerse(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                            }
                          }
                        }
                      }
                      else {
                        // Cas d’un paragraphe classique
                        int? blockIdentifier = int.tryParse(id);
                        int blockType = blockIdentifier != null ? 1 : 0;

                        printTime('blockIdentifier: $blockIdentifier');
                        printTime('blockType: $blockType');
                        printTime('mepsDocumentId: ${currentDoc.mepsDocumentId}');
                        printTime('title: ${currentDoc.displayTitle}');

                        Bookmark? bookmark = await showBookmarkDialog(
                          context,
                          widget.publication,
                          webViewController: _controller,
                          mepsDocumentId: currentDoc.mepsDocumentId,
                          title: currentDoc.displayTitle,
                          snippet: snippet.trim(),
                          blockType: blockType,
                          blockIdentifier: blockIdentifier,
                        );

                        if(bookmark != null) {
                          if (bookmark.location.mepsDocumentId != null) {
                            final page = docManager.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);
                            if (page != widget.publication.documentsManager!.documentIndex) {
                              await _jumpToPage(page);
                            }
                          }

                          // Aller au paragraphe dans la même page
                          if (bookmark.blockIdentifier != null) {
                            _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                          }
                        }
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
                          setControlsVisible(_controlsVisibleSave);
                        }
                        else {
                          setControlsVisible(true);
                        }
                        _showDialog = isFullscreen;
                      });
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'share',
                    callback: (args) async {
                      final arg = args[0];

                      final bool isBible = arg['isBible'];
                      final String id = arg['id'];

                      widget.publication.documentsManager!.getCurrentDocument().share(isBible, id: id);
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
                      final arg = args[0];

                      final bool isBible = arg['isBible'];
                      final String id = arg['id'];

                      try {
                        // Trouver l'audio correspondant au document dans une liste
                        Audio? audio;

                        if(isBible) {
                          audio = widget.audios.firstWhereOrNull((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                        }
                        else {
                          audio = widget.audios.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                        }

                        if(audio != null) {
                          // Trouver le marqueur correspondant au paragraphId dans la liste des marqueurs
                          Marker? marker;
                          if(isBible) {
                            marker = audio.markers.firstWhereOrNull((marker) => marker.verseNumber == int.tryParse(id));
                          }
                          else {
                            marker = audio.markers.firstWhereOrNull((marker) => marker.mepsParagraphId == int.tryParse(id));
                          }

                          if(marker != null) {
                            // Extraire le startTime du marqueur et vérifier s'il est valide
                            String startTime = marker.startTime;
                            if (startTime.isEmpty) {
                              printTime('Le startTime est invalide');
                              return;
                            }

                            // Analyser la durée
                            Duration duration = parseDuration(startTime);

                            printTime('duration: $duration');

                            // Trouver l'index du document
                            int? index;
                            if(isBible) {
                              index = widget.audios.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                            }
                            else {
                              index = widget.audios.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                            }

                            if (index != -1) {
                              // Afficher le lien du lecteur audio et se positionner au bon startTime
                              showAudioPlayerPublicationLink(context, widget.publication, widget.audios, index, start: duration);
                            }
                          }
                        }
                      }
                      catch (e) {
                        printTime('Erreur lors de la lecture de l\'audio : $e');
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

                      Publication bible = PublicationRepository().getAllBibles().first;

                      audio_service.MediaItem mediaItem = audio_service.MediaItem(
                          id: '0',
                          album: bible.title,
                          title: JwLifeApp.bibleCluesInfo.getVerse(verse['bookNumber'], verse['chapterNumber'], verseNumber),
                          artUri: Uri.file(bible.imageSqr!)
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
                      String book = widget.publication.documentsManager!.getCurrentDocument().bookNumber.toString();
                      String chapter = widget.publication.documentsManager!.getCurrentDocument().chapterNumber.toString();
                      String verseNumber = args[0]['query'].toString();

                      String query = JwLifeApp.bibleCluesInfo.getVerse(int.parse(book), int.parse(chapter), int.parse(verseNumber));
                      showPage(context, SearchView(query: query));
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onVideoClick',
                    callback: (args) async {
                      String link = args[0];

                      printTime('Link: $link');
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
                onProgressChanged: (controller, progress) {
                  if(progress == 100) {
                    setState(() {
                      _isLoadingWebView = true;
                    });
                  }
                }
            ) : Container(),
        ),

        if (!_isLoadingFonts)
          getLoadingWidget(Theme.of(context).primaryColor),


        if (!_isFullscreen || (_isFullscreen && _controlsVisible))
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
                            printTime(value);
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
                    else {
                      if (_handleBackPress()) {
                        setState(() {
                          _isLoadingWebView = false;
                        });
                        JwLifePage.toggleNavBarPositioned.call(false);
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
                actions: [
                  if (!_isSearching)
                    !_isLoadingData ? Container() : ResponsiveAppBarActions(
                      allActions: [
                        if (widget.audios.any((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) || widget.audios.any((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible))
                          IconTextButton(
                            text: "Écouter l'audio",
                            icon: Icon(JwIcons.headphones),
                            onPressed: () {
                              int? index;
                              if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
                                index = widget.audios.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                              }
                              else {
                                index = widget.audios.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                              }
                              if (index != -1) {
                                showAudioPlayerPublicationLink(context, widget.publication, widget.audios, index);
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
                            Bookmark? bookmark = await showBookmarkDialog(context, widget.publication, webViewController: _controller, mepsDocumentId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, title: widget.publication.documentsManager!.getCurrentDocument().displayTitle, snippet: '', blockType: 0, blockIdentifier: null);
                            if (bookmark != null) {
                              if(bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                                int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumber == bookmark.location.chapterNumber);

                                if (page != widget.publication.documentsManager!.documentIndex) {
                                  await _jumpToPage(page);
                                }

                                if (bookmark.blockIdentifier != null) {
                                   _jumpToVerse(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                                };
                              }
                              else {
                                if(bookmark.location.mepsDocumentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                                  int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);

                                  if (page != widget.publication.documentsManager!.documentIndex) {
                                    await _jumpToPage(page);
                                  }

                                  if (bookmark.blockIdentifier != null) {
                                    _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
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
                                widget.publication.showMenu(context, mepsLanguage: value);
                              }
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Ajouter une note",
                          icon: const Icon(JwIcons.note_plus),
                          onPressed: () async {
                            String title = widget.publication.documentsManager!.getCurrentDocument().title;
                            Document document = widget.publication.documentsManager!.getCurrentDocument();
                            var note = await JwLifeApp.userdata.addNote(
                                title, '', 0, [], document.mepsDocumentId,
                                document.bookNumber,
                                document.chapterNumberBible,
                                widget.publication.issueTagNumber,
                                widget.publication.keySymbol,
                                widget.publication.mepsLanguage.id, blockType: 0, blockIdentifier: null
                            );
                          },
                        ),
                        if(widget.publication.documentsManager!.getCurrentDocument().hasMediaLinks)
                          IconTextButton(
                            text: "Voir les médias",
                            icon: const Icon(JwIcons.video_music),
                            onPressed: () {
                              showPage(context, DocumentMediasView(document: widget.publication.documentsManager!.getCurrentDocument()));
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
                              await showHtmlDialog(context, decodeBlobContent(document.chapterContent!, widget.publication.hash!));
                            }
                            else {
                              await showHtmlDialog(context, decodeBlobContent(document.content!, widget.publication.hash!));
                            }
                          },
                        ),
                      ],
                    ),
                ],
              )
          ),
      ]),
    );
  }

  String getArticleClass(Document document) {
    String publication = document.isBibleChapter() ? 'bible' : 'document';
    return '''$publication html5 pub-${widget.publication.keySymbol} jwac docClass-${document.classType} docId-${document.documentId} ms-ROMAN ml-${widget.publication.mepsLanguage.symbol} dir-ltr layout-reading layout-sidebar ${JwLifeSettings().webViewData.theme}''';
  }
}