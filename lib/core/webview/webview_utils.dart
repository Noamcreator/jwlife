import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../data/databases/catalog.dart';
import '../../data/databases/tiles_cache.dart';
import '../../data/models/publication.dart';
import '../../data/models/publication_category.dart';
import '../../data/repositories/PublicationRepository.dart';
import '../utils/files_helper.dart';

/*
  String verseAudioLink = 'https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?pub=NWT&langwritten=F&fileformat=mp3&booknum=$book1&track=$chapter1';

  dynamic audio = {};
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

Future<Map<String, dynamic>> fetchVerses(BuildContext context, String link) async {
  print('fetchVerses $link');
  List<String> linkSplit = link.split('/');
  String verses = linkSplit.last;

  String bibleInfoName = linkSplit[linkSplit.length - 2];

  int book1 = int.parse(verses.split('-').first.split(':')[0]);
  int chapter1 = int.parse(verses.split('-').first.split(':')[1]);
  int verse1 = int.parse(verses.split('-').first.split(':')[2]);

  int book2 = int.parse(verses.split('-').last.split(':')[0]);
  int chapter2 = int.parse(verses.split('-').last.split(':')[1]);
  int verse2 = int.parse(verses.split('-').last.split(':')[2]);

  String versesDisplay = JwLifeApp.bibleCluesInfo.getVerses(book1, chapter1, verse1, book2, chapter2, verse2);

  List<Map<String, dynamic>> items = [];
  File mepsFile = await getMepsFile();

  try {
    Database db = await openDatabase(mepsFile.path);
    List<Map<String, dynamic>> versesIds = await db.rawQuery("""
      SELECT
      (
        SELECT 
          FirstBibleVerseId + (? - 1) + 
          CASE 
            WHEN EXISTS (
              SELECT 1 FROM BibleSuperscriptionLocation
              WHERE BookNumber = ? AND ChapterNumber = ?
            ) AND ? > 1 THEN 1 ELSE 0
          END
        FROM BibleRange
        INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
        WHERE BibleInfo.Name = ? AND BookNumber = ? AND ChapterNumber = ?
      ) AS FirstVerseId,
    
      (
        SELECT 
          FirstBibleVerseId + (? - 1) + 
          CASE 
            WHEN EXISTS (
              SELECT 1 FROM BibleSuperscriptionLocation
              WHERE BookNumber = ? AND ChapterNumber = ?
            ) AND ? > 1 THEN 1 ELSE 0
          END
        FROM BibleRange
        INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
        WHERE BibleInfo.Name = ? AND BookNumber = ? AND ChapterNumber = ?
      ) AS LastVerseId;
      """, [
      verse1, book1, chapter1, verse1, bibleInfoName, book1, chapter1,
      verse2, book2, chapter2, verse2, bibleInfoName, book2, chapter2,
    ]);
    db.close();

    for (var bible in PublicationRepository().getAllBibles()) {
      Database? bibleDb;
      if(bible.documentsManager == null) {
        bibleDb = await openDatabase(bible.databasePath!);
      }
      else {
        bibleDb = bible.documentsManager!.database;
      }

      List<Map<String, dynamic>> results = await bibleDb.rawQuery("""
        SELECT *
        FROM BibleVerse
        WHERE BibleVerseId BETWEEN ? AND ?
      """, [versesIds.first['FirstVerseId'], versesIds.first['LastVerseId']]);

      String htmlContent = '';
      for (Map<String, dynamic> row in results) {
        String label = row['Label'].replaceAllMapped(
          RegExp(r'<span class="cl">(.*?)<\/span>'),
              (match) => '<span class="cl"><strong>${match.group(1)}</strong> </span>',
        );

        htmlContent += label;
        final decodedHtml = decodeBlobContent(
          row['Content'] as Uint8List,
          bible.hash!,
        );
        htmlContent += decodedHtml;
      }

      print(htmlContent);

      List<Map<String, dynamic>> highlights = await JwLifeApp.userdata.getHighlightsFromChapterNumber(book1, chapter1, bible.mepsLanguage.id);
      List<Map<String, dynamic>> notes = await JwLifeApp.userdata.getNotesFromChapterNumber(book1, chapter1, bible.mepsLanguage.id);

      items.add({
        'type': 'verse',
        'content': htmlContent,
        'className': "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar",
        'subtitle': bible.mepsLanguage.vernacular,
        'imageUrl': bible.imageSqr,
        'publicationTitle': bible.shortTitle,
        'bookNumber': book1,
        'chapterNumber': chapter1,
        'firstVerseNumber': verse1,
        'lastVerseNumber': verse2,
        'audio': {},
        'mepsLanguageId': bible.mepsLanguage.id,
        'highlights': highlights,
        'notes': notes
      });
    }

    return {
      'items': items,
      'title': versesDisplay,
    };
  }
  catch (e) {
    printTime('Error fetching verses: $e');
    return {
      'items': [],
      'title': versesDisplay,
    };
  }
}

Future<Map<String, dynamic>?> fetchExtractPublication(BuildContext context, String type, Database database, Publication publication, String link, Function(int) jumpToPage, Function(int, int) jumpToParagraph) async {
  String newLink = link.replaceAll('jwpub://', '');
  List<String> links = newLink.split("\$");

  List<Map<String, dynamic>> response = await database.rawQuery('''
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
      Publication? refPub = PublicationRepository().getPublicationWithSymbol(extract['UndatedSymbol'], int.parse(extract['IssueTagNumber']), extract['MepsLanguageIndex']);
      refPub ??= await PubCatalog.searchPub(extract['UndatedSymbol'], int.parse(extract['IssueTagNumber']), extract['MepsLanguageIndex']);

      var doc = parse(extract['Caption']);
      String caption = doc.querySelector('.etitle')?.text ?? '';

      String image = refPub?.imageSqr ?? refPub?.networkImageSqr ?? '';
      if (image.isNotEmpty) {
        if(image.startsWith('https')) {
          image = (await TilesCache().getOrDownloadImage(image))!.file.path;
        }
      }
      if (refPub == null || refPub.imageSqr == null) {
        String type = PublicationCategory.all.firstWhere((element) => element.type == extract['PublicationType']).image;
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        String path = isDark ? 'assets/images/${type}_gray.png' : 'assets/images/$type.png';
        image = '/android_asset/flutter_assets/$path';
      }

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(extract['Content'] as Uint8List, publication.hash!);

      List<Map<String, dynamic>> highlights = await JwLifeApp.userdata.getHighlightsFromDocId(extract['RefMepsDocumentId'], extract['MepsLanguageIndex']);
      List<Map<String, dynamic>> notes = await JwLifeApp.userdata.getNotesFromDocId(extract['RefMepsDocumentId'], extract['MepsLanguageIndex']);

      dynamic article = {
        'type': 'publication',
        'content': decodedHtml,
        'className': "publicationCitation html5 pub-${extract['UndatedSymbol']} docId-${extract['RefMepsDocumentId']} docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${extract['Symbol']} ms-ROMAN dir-ltr layout-reading layout-sidebar",
        'subtitle': caption,
        'imageUrl': image,
        'mepsDocumentId': extract['RefMepsDocumentId'],
        'mepsLanguageId': extract['MepsLanguageIndex'],
        'startParagraphId': extract['RefBeginParagraphOrdinal'],
        'endParagraphId': extract['RefEndParagraphOrdinal'],
        'publicationTitle': refPub == null ? extract['ShortTitle'] : refPub.getShortTitle(),
        'highlights': highlights,
        'notes': notes
      };

      // Ajouter l'élément document à la liste versesItems
      extractItems.add(article);
    }

    return {
      'items': extractItems,
      'title': 'Extrait de publication',
    };
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

    if(type == 'document') {
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
        //JwLifePage.toggleNavBarVisibility(controlsIsVisible);
        //JwLifePage.toggleNavBarPositioned(true);
      }
    }
    else {
      await showDocumentView(context, mepsDocumentId, publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
    }

    return null;
  }
}

Future<Map<String, dynamic>> fetchFootnote(BuildContext context, Publication publication, String footNoteId, {String? bibleVerseId}) async {
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
        [publication.documentsManager!.selectedDocumentIndex, footNoteId]);

  }

  if (response.isNotEmpty) {
    final footNote = response.first;

    /// Décoder le contenu
    final decodedHtml = decodeBlobContent(
        footNote['Content'] as Uint8List,
        publication.hash!
    );

    return {
      'type': 'note',
      'content': decodedHtml,
      'className': "document html5 pub-${publication.keySymbol} docId-${publication.documentsManager!.getCurrentDocument().mepsDocumentId} docClass-13 jwac showRuby ml-${publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar",
      'title': 'Note',
    };
  }
  return {
    'type': 'note',
    'content': '',
    'className': '',
    'title': 'Note',
  };
}

Future<Map<String, dynamic>> fetchVersesReference(BuildContext context, Publication publication, InAppWebViewController controller, String versesReferenceId) async {
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
        'content': htmlContent,
        'className': "bibleCitation html5 pub-${publication.keySymbol} jwac showRuby ml-${publication.mepsLanguage.symbol} ms-ROMAN dir-ltr layout-reading layout-sidebar",
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

    return {
      'items': versesItems,
      'title': 'Renvois',
    };
  }
  return {
    'items': [],
    'title': 'Renvois',
  };
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