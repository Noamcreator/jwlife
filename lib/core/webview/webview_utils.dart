import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';

import '../../app/jwlife_app.dart';
import '../../app/jwlife_page.dart';
import '../../app/services/settings_service.dart';
import '../../data/databases/catalog.dart';
import '../../data/databases/tiles_cache.dart';
import '../../data/models/publication.dart';
import '../../data/models/publication_category.dart';
import '../../data/repositories/PublicationRepository.dart';

Future<void> fetchHyperlink(BuildContext context, InAppWebViewController controller, Publication publication, Function(int) jumpToPage, Function(int, int) jumpToParagraph, String link, bool controlsIsVisible) async {
  if (link.startsWith('jwpub://b')) {
    await fetchVerses(context, controller, link);
  }
  else if (link.startsWith('jwpub://p')) {
    await fetchPublication(context, controller, publication, jumpToPage, jumpToParagraph, link, controlsIsVisible);
  }
}

Future<void> fetchVerses(BuildContext context, InAppWebViewController controller, String link) async {
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
    injectHtmlDialog(context, controller, versesJson);
  }
  catch (e) {
    printTime('Error fetching verses: $e');
  }
}

Future<void> fetchPublication(BuildContext context, InAppWebViewController controller, Publication publication, Function(int) jumpToPage, Function(int, int) jumpToParagraph, String link, bool controlsIsVisible) async {
  String newLink = link.replaceAll('jwpub://', '');
  List<String> links = newLink.split("\$");

  List<Map<String, dynamic>> response = await publication.documentsManager!.database.rawQuery('''
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
          extract['Content'] as Uint8List, publication.hash!);
      var doc = parse(extract['Caption']);
      String caption = doc.querySelector('.etitle')?.text ?? '';

      String image = '';
      if (pub != null && pub['ImageSqr'] != null) {
        String imagePath = "https://app.jw-cdn.org/catalogs/publications/${pub['ImageSqr']}";
        image = (await TilesCache().getOrDownloadImage(imagePath))!.file.path;
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

      // Ajouter l'élément webview à la liste versesItems
      extractItems.add(article);
    }

    dynamic articlesJson = {
      'items': extractItems,
      'title': 'Extrait de publication',
    };

    // Inject HTML content in JavaScript dialog
    injectHtmlDialog(context, controller, articlesJson);
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

    if(publication.documentsManager!.documents.any((doc) => doc.mepsDocumentId == mepsDocumentId)) {
      if (mepsDocumentId != publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
        int index = publication.documentsManager!.getIndexFromMepsDocumentId(mepsDocumentId);
        jumpToPage(index);
      }

      // Appeler _jumpToParagraph uniquement si un paragraphe est présent
      if (startParagraph != null) {
        jumpToParagraph(startParagraph, endParagraph ?? startParagraph);
      }
    }
    else {
      await showDocumentView(context, mepsDocumentId, publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
      JwLifePage.toggleNavBarVisibility(controlsIsVisible);
      JwLifePage.toggleNavBarPositioned(true);
    }
  }
}

Future<void> fetchFootnote(BuildContext context, Publication publication, InAppWebViewController controller, String footNoteId, {String? bibleVerseId}) async {
  List<Map<String, dynamic>> response = [];

  if(bibleVerseId != null) {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT * FROM Footnote WHERE BibleVerseId = ? AND FootnoteIndex = ?
        ''',
        [bibleVerseId, footNoteId]);

  }
  else if(publication.documentsManager!.getCurrentDocument().chapterNumberBible != null) {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT Footnote.* FROM Footnote
          LEFT JOIN Document ON Footnote.DocumentId = Document.DocumentId
          WHERE Document.MepsDocumentId = ? AND FootnoteIndex = ?
        ''',
        [publication.documentsManager!.getCurrentDocument().mepsDocumentId, footNoteId]);
  }
  else {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT * FROM Footnote WHERE DocumentId = ? AND FootnoteIndex = ?
        ''',
        [publication.documentsManager!.documentIndex, footNoteId]);

  }

  if (response.isNotEmpty) {
    final footNote = response.first;

    /// Décoder le contenu
    final decodedHtml = decodeBlobContent(
        footNote['Content'] as Uint8List,
        publication.hash!
    );

    dynamic document = {
      'items': [
        {
          'type': 'note',
          'content': createHtmlDialogContent(
              decodedHtml,
              "document html5 pub-${publication.keySymbol} docId-${publication.documentsManager!.getCurrentDocument().mepsDocumentId} docClass-13 jwac showRuby ml-${publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar"
          ),
        }
      ],
      'title': 'Note',
    };

    // Inject HTML content in JavaScript dialog
    injectHtmlDialog(context, controller, document);
  }
}

Future<void> fetchVersesReference(BuildContext context, Publication publication, InAppWebViewController controller, String versesReferenceId) async {
  List<Map<String, dynamic>> response = await publication.documentsManager!.database.rawQuery(
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
      [publication.documentsManager!.getCurrentDocument().mepsDocumentId, versesReferenceId]);

  if (response.isNotEmpty) {
    List<Map<String, dynamic>> versesItems = [];

    // Process each verse in the response
    for (var verse in response) {
      String htmlContent = '';
      htmlContent += verse['Label'];
      final decodedHtml = decodeBlobContent(
          verse['Content'] as Uint8List,
          publication.hash!
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
            "bibleCitation html5 pub-${publication.keySymbol} jwac showRuby ml-${publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar"
        ),
        'subtitle': publication.mepsLanguage.vernacular,
        'imageUrl': publication.imageSqr,
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
    injectHtmlDialog(context, controller, versesJson);
  }
}

Future<void> injectHtmlDialog(BuildContext context, InAppWebViewController controller, dynamic content) async {
  // Encodez le contenu HTML en échappant les caractères spéciaux
  await controller.evaluateJavascript(source: """
        {
          // Création d'une variable locale webview pour accéder facilement aux données
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