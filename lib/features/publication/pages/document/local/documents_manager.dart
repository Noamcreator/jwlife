import 'dart:convert';

import 'package:jwlife/data/models/publication.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../app/services/settings_service.dart';
import '../../../../../core/utils/utils.dart';
import '../data/models/document.dart';
import 'document_page.dart';

class DocumentsManager {
  Publication publication;
  int mepsDocumentId;
  int? bookNumber;
  int? chapterNumber;
  late Database database;
  int documentIndex = 0;
  List<Document> documents = [];
  String html = '';

  DocumentsManager({required this.publication, required this.mepsDocumentId, this.bookNumber, this.chapterNumber});

  // Méthode privée pour initialiser la base de données
  Future<void> initializeDatabaseAndData() async {
    try {
      database = await openDatabase(publication.databasePath!);
      await fetchDocuments();
    }
    catch (e) {
      printTime('Error initializing database: $e');
    }
  }

  Future<void> fetchDocuments() async {
    try {
      List<Map<String, dynamic>> result = [];
      if (publication.category.id == 1) {
        result = await database.rawQuery("""
          SELECT 
            Document.*, 
            (SELECT Title 
             FROM PublicationViewItem pvi 
             JOIN PublicationViewSchema pvs 
               ON pvi.SchemaType = pvs.SchemaType
             WHERE pvi.DefaultDocumentId = Document.DocumentId 
               AND pvs.DataType = 'name'
             LIMIT 1
            ) AS DisplayTitle,
            BibleChapter.BookNumber,
            BibleChapter.ChapterNumber,
            BibleChapter.Content AS ChapterContent,
            BibleChapter.PreContent,
            BibleChapter.PostContent,
            BibleChapter.FirstVerseId,
            BibleChapter.LastVerseId
          FROM Document
          LEFT JOIN BibleChapter 
              ON Document.Type = 2 
              AND BibleChapter.BookNumber = Document.ChapterNumber
          WHERE Document.Class <> 118;
        """);
      }
      else {
        result = await database.rawQuery("""
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
      }

      documents = result.map((e) => Document.fromMap(database, publication, e)).toList();
      if (mepsDocumentId != -1) {
        if(bookNumber != null && chapterNumber != null) {
          documentIndex = documents.indexWhere((element) => element.bookNumber == bookNumber && element.chapterNumberBible == chapterNumber);
        }
        else {
          documentIndex = documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
        }
      }
    }
    catch (e) {
      printTime('Error fetching all documents: $e');
    }
  }

  String createReaderHtmlShell(DocumentPage widget) {
    final webViewData = JwLifeSettings().webViewData;
    final fontSize = webViewData.fontSize;
    final colorIndex = webViewData.colorIndex;
    bool isDarkMode = webViewData.theme == 'cc-theme--dark';

    int? startParagraphId = widget.startParagraphId;
    int? endParagraphId = widget.endParagraphId;
    int? startVerseId = widget.firstVerse;
    int? endVerseId = widget.lastVerse;
    List<String> wordsSelected = widget.wordsSelected;

    //String highlightYellowColor = isDarkMode ? '#86761d' : '#fff9bb';
    //String highlightGreenColor = isDarkMode ? '#4a6831' : '#dbf2c8';
    //String highlightBlueColor = isDarkMode ? '#3a6381' : '#cbecff';
    //String highlightPurpleColor = isDarkMode ? '#524169' : '#e0d3ef';
    //String highlightPinkColor = isDarkMode ? '#783750' : '#facbdd';
    //String highlightOrangeColor = isDarkMode ? '#894c1f' : '#ffddc4';

    String noteIndicatorGrayColor = isDarkMode ? '#808080' : '#bfbfbf';
    String noteIndicatorYellowColor = isDarkMode ? '#eac600' : '#fff379';
    String noteIndicatorGreenColor = isDarkMode ? '#67a332' : '#b7e492';
    String noteIndicatorBlueColor = isDarkMode ? '#4ba1de' : '#98d8fe';
    String noteIndicatorPurpleColor = isDarkMode ? '#7a57a7' : '#c0a7e1';
    String noteIndicatorPinkColor = isDarkMode ? '#c64677' : '#f698bc';
    String noteIndicatorOrangeColor = isDarkMode ? '#ea6d01' : '#feba89';

    String noteGrayColor = isDarkMode ? '#292929' : '#f1f1f1';
    String noteYellowColor = isDarkMode ? '#49400e' : '#fffce6';
    String noteGreenColor = isDarkMode ? '#233315' : '#effbe6';
    String noteBlueColor = isDarkMode ? '#203646' : '#e6f7ff';
    String notePurpleColor = isDarkMode ? '#2d2438' : '#f1eafa';
    String notePinkColor = isDarkMode ? '#401f2c' : '#ffe6f0';
    String noteOrangeColor = isDarkMode ? '#49290e' : '#fff0e6';

    //String searchColor = isDarkMode ? '#d09828' : '#ffc757';

    String theme = isDarkMode ? 'dark' : 'light';

    return '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; overflow-y: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
        <style>
          body {
            user-select: none;
            font-size: ${fontSize}px;
            overflow: hidden;
            -webkit-tap-highlight-color: transparent;
          }
          
          body.cc-theme--dark {
            background-color: #121212;
          }
          
          body.cc-theme--light {
            background-color: #ffffff;
          }

          #container {
            display: flex;
            transform: translateX(-100%);
            transition: transform 0.3s ease-in-out;
            height: 100vh;
          }
          .page {
            flex: 0 0 100%;
            height: 100vh;
            overflow-y: auto;
            box-sizing: border-box;
          }

          #page-center {
            position: relative;
            opacity: 0;
            transition: opacity 0.5s ease;
            pointer-events: none;
          }
          
          #page-center.visible {
            opacity: 1;
            pointer-events: auto;
          }
          
          .scroll-bar {
            position: absolute;
            top: 90px;
            right: 0px;
            width: 30px;
            height: 55px;
            z-index: 999;
          }
          
          #magnifier {
            position: fixed;
            width: 130px;
            height: 50px;
            border-radius: 8px;
            overflow: hidden;
            pointer-events: none;
            z-index: 9999;
          }
          
          body.cc-theme--dark #magnifier {
            background-color: #121212;
            border: 2px solid #ffffff;
          }
          
          body.cc-theme--light #magnifier {
            background-color: #ffffff;
            border: 2px solid #5f5a57;
          }
          
          #magnifier .zoomed {
            position: absolute;
            transform-origin: 0 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
          }
  
          .magnifier-content {
            transform-origin: 0 0;
            position: absolute;
          }

          .bookmark-icon {
            position: absolute;
            left: -3.5px;
            width: 20px;
            height: 25px;
            z-index: 999;
          }
          
          .note-indicator {
            position: absolute;
            left: 2px;
            right: 2px;
            width: 12px;
            height: 12px;
            z-index: 999;
          }
         
          .word.selected {
            background-color: rgba(66, 236, 241, 0.3);
          }
            
          .punctuation.selected {
            background-color: rgba(66, 236, 241, 0.3);
          }
            
          .word.searched {
            background-color: rgba(255, 185, 46, 0.8);
          }
            
          a:hover, a:active, a:visited, a:focus {
            border: none;
            background: rgba(175, 175, 175, 0.3);
            outline: none;
          }
            
          /* Light mode (cc-theme--light) */
          .cc-theme--light .highlight-yellow      { background-color: rgba(255, 243, 122, 0.5); }
          .cc-theme--light .highlight-green       { background-color: rgba(183, 228, 146, 0.5); }
          .cc-theme--light .highlight-blue        { background-color: rgba(152, 216, 255, 0.5); }
          .cc-theme--light .highlight-pink        { background-color: rgba(246, 152, 188, 0.5); }
          .cc-theme--light .highlight-purple      { background-color: rgba(193, 167, 226, 0.5); }
          .cc-theme--light .highlight-orange      { background-color: rgba(255, 186, 138, 0.5); }
            
          /* Dark mode (cc-theme--dark) */
          .cc-theme--dark .highlight-yellow       { background-color: rgba(250, 217, 41, 0.5); }
          .cc-theme--dark .highlight-green        { background-color: rgba(129, 189, 79, 0.5); }
          .cc-theme--dark .highlight-blue         { background-color: rgba(95, 180, 239, 0.5); }
          .cc-theme--dark .highlight-pink         { background-color: rgba(219, 93, 141, 0.5); }
          .cc-theme--dark .highlight-purple       { background-color: rgba(146, 111, 189, 0.5); }
          .cc-theme--dark .highlight-orange       { background-color: rgba(255, 134, 46, 0.5); }


          .note-indicator-gray      { background-color: $noteIndicatorGrayColor; }
          .note-indicator-yellow    { background-color: $noteIndicatorYellowColor; }
          .note-indicator-green     { background-color: $noteIndicatorGreenColor; }
          .note-indicator-blue      { background-color: $noteIndicatorBlueColor; }
          .note-indicator-pink      { background-color: $noteIndicatorPinkColor; }
          .note-indicator-orange    { background-color: $noteIndicatorOrangeColor; }
          .note-indicator-purple    { background-color: $noteIndicatorPurpleColor; }
            
          .note-gray      { background-color: $noteGrayColor; }
          .note-yellow    { background-color: $noteYellowColor; }
          .note-green     { background-color: $noteGreenColor; }
          .note-blue      { background-color: $noteBlueColor; }
          .note-pink      { background-color: $notePinkColor; }
          .note-orange    { background-color: $noteOrangeColor; }
          .note-purple    { background-color: $notePurpleColor; }
        </style>
      </head>
      <body class="${webViewData.theme}">
        <div id="container">
          <div id="page-left" class="page"></div>
          <div id="page-center" class="page"></div>
          <div id="page-right" class="page"></div>
        </div>
        
        <div id="magnifier">
          <div class="zoomed">
              <div class="magnifier-content" id="magnifier-content"></div>
          </div>
        </div>
    
        <script>
          let currentIndex = $documentIndex;
          let container = document.getElementById("container");
          const pageCenter = document.getElementById("page-center");
          const pageLeft = document.getElementById("page-left");
          const pageRight = document.getElementById("page-right");
          
          const magnifier = document.getElementById('magnifier');
          const magnifierContent = document.getElementById('magnifier-content');

          let cachedPages = {};
          let scrollTopPages = {};
          let highlightColorIndex = $colorIndex;
          
          let lastScrollTop = 0;
          
          let isChangingParagraph = false;
          
          const bookmarkAssets = Array.from({ length: 10 }, (_, i) => `bookmarks/$theme/bookmark\${i + 1}.png`);
          const highlightAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}.png`);
          const highlightSelectedAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}_selected.png`);
          
          const speedBarScroll = `images/speedbar_thumb_regular.png`;
          let scrollBar = null;
    
          const maxIndex = ${documents.length - 1};
          
          let appBarHeight = 90;    // hauteur de l'AppBar
          let bottomNavBarHeight = 55; // hauteur de la BottomBar
          
          let highlights;
          let notes;
          let inputFields;
          let bookmarks;
         
          async function fetchPage(index) {
            if (index < 0 || index > maxIndex) return { html: "", className: "" };
            if (cachedPages[index]) return cachedPages[index];
            const page = await window.flutter_inappwebview.callHandler('getPage', index);
            console.log("fetchPage", index, page.className);
            cachedPages[index] = page;
            return page;
          }
    
          function adjustArticle(articleId) {
            const article = document.getElementById(articleId);
            if (!article) return;
    
            const header = article.querySelector('header');
            const firstImage = article.querySelector('div#f1.north_center');
            let paddingTop = '110px';
    
            if (firstImage && header && !header.contains(firstImage)) {
              header.insertBefore(firstImage, header.firstChild);
              paddingTop = '90px';
            }
    
            if (firstImage) {
              paddingTop = '90px';
            }
    
            article.style.paddingTop = paddingTop;
            article.style.paddingBottom = '50px';
          }
    
          function addVideoCover(articleId) {
            const article = document.getElementById(articleId);
            if (!article) return;
    
            // Gestion des vidéos <video data-video>
            const videoElements = article.querySelectorAll("video[data-video]");
            videoElements.forEach(videoElement => {
              const imageName = videoElement.getAttribute("data-image");
              if (imageName) {
                const imagePath = `${publication.path}/\${imageName}`;
                const imgElement = document.createElement("img");
                imgElement.src = imagePath;
                imgElement.style.width = "100%";
                imgElement.style.height = "auto";
    
                const container = document.createElement("div");
                container.style.position = "relative";
                container.style.width = "100%";
                container.style.height = "auto";
                container.appendChild(imgElement);
    
                const playButton = document.createElement("div");
                playButton.style = `
                  position: absolute;
                  bottom: 10px;
                  left: 10px;
                  width: 40px;
                  height: 40px;
                  background-color: rgba(0, 0, 0, 0.7);
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  font-size: 24px;
                  color: white;
                  font-family: jw-icons-external;
                `;
                playButton.innerHTML = "&#xE690;";
                container.appendChild(playButton);
    
                container.addEventListener("click", () => {
                  window.flutter_inappwebview.callHandler('onVideoClick', videoElement.getAttribute("data-video"));
                });
    
                videoElement.parentNode.replaceChild(container, videoElement);
              }
            });
    
            // Gestion des liens <a data-video>
            const videoLinks = article.querySelectorAll("a[data-video]");
            videoLinks.forEach(link => {
              link.addEventListener("click", event => {
                event.preventDefault();
                window.flutter_inappwebview.callHandler('onVideoClick', link.getAttribute("data-video"));
              });
            });
          }
          
          function wrapWordsWithSpan(articleId) {
            let selector = isBible() ? '.v' : '[data-pid]';
            const article = document.getElementById(articleId);
            if (!article) return;
          
            const paragraphs = article.querySelectorAll(selector);
            paragraphs.forEach((p) => {
                processTextNodes(p);
            });
          }
          
          function processTextNodes(element) {
              function walkNodes(node) {
                  if (node.nodeType === Node.TEXT_NODE) {
                      const text = node.textContent;
                      if (text.trim()) {
                          const newHTML = processText(text);
                          
                          const temp = document.createElement('div');
                          temp.innerHTML = newHTML.html;
                          
                          const parent = node.parentNode;
                          while (temp.firstChild) {
                              parent.insertBefore(temp.firstChild, node);
                          }
                          parent.removeChild(node);
                      }
                  } 
                  else if (node.nodeType === Node.ELEMENT_NODE) {
                    // Skip elements with 'fn' or 'm' classes ou si il est sup
                    if ((node.closest && node.closest('sup')) || (node.classList && (node.classList.contains('fn') || node.classList.contains('m') || node.classList.contains('cl') || node.classList.contains('vl')))) {
                        return;
                    }
                    const children = Array.from(node.childNodes);
                    children.forEach(child => walkNodes(child));
                  }
              }
              
              walkNodes(element);
          }

          function processText(text) {
              let html = '';
   
              let i = 0;
              while (i < text.length) {
                  let currentChar = text[i];
                  
                  if (currentChar === ' ' || currentChar === '\u00A0') {
                      // C'est un espace
                      let spaceSequence = '';
                      while (i < text.length && (text[i] === ' ' || text[i] === '\u00A0')) {
                          spaceSequence += text[i];
                          i++;
                      }
                      html += `<span class="escape">\${spaceSequence}</span>`;
                  }
                  else if (isLetter(currentChar) || isDigit(currentChar)) {
                      // C'est le début d'un mot (incluant la ponctuation intégrée)
                      let word = '';
                      while (i < text.length && !isSpace(text[i]) && !isStandalonePunctuation(text, i)) {
                          word += text[i];
                          i++;
                      }
                      html += `<span class="word">\${word}</span>`;
                  }
                  else {
                      // C'est de la ponctuation standalone
                      html += `<span class="punctuation">\${currentChar}</span>`;
                      i++;
                  }
              }
              
              return {
                  html: html
              };
          }
          
          function isLetter(char) {
              const code = char.charCodeAt(0);
              return (code >= 65 && code <= 90) || // A-Z
                     (code >= 97 && code <= 122) || // a-z
                     (code >= 192 && code <= 255) || // À-ÿ
                     char === 'œ' || char === 'Œ' ||
                     char === 'æ' || char === 'Æ';
          }
          
          function isDigit(char) {
              const code = char.charCodeAt(0);
              return code >= 48 && code <= 57; // 0-9
          }
          
          function isSpace(char) {
              return char === ' ' || char === '\u00A0';
          }
          
          function isStandalonePunctuation(text, index) {
              const char = text[index];
              
              // Si ce n'est pas de la ponctuation, retourner false
              if (isLetter(char) || isDigit(char) || isSpace(char)) {
                  return false;
              }
              
              // Fonction helper pour trouver le prochain/précédent caractère visible
              function findPrevVisibleChar(text, startIndex) {
                  for (let i = startIndex - 1; i >= 0; i--) {
                      const c = text[i];
                      if (!isInvisibleChar(c)) {
                          return c;
                      }
                  }
                  return '';
              }
              
              function findNextVisibleChar(text, startIndex) {
                  for (let i = startIndex + 1; i < text.length; i++) {
                      const c = text[i];
                      if (!isInvisibleChar(c)) {
                          return c;
                      }
                  }
                  return '';
              }
              
              // Vérifier si c'est de la ponctuation qui fait partie d'un mot
              const prevChar = findPrevVisibleChar(text, index);
              const nextChar = findNextVisibleChar(text, index);
              
              if ((isLetter(prevChar) && isLetter(nextChar)) || (isDigit(prevChar) && isDigit(nextChar))) {
                  return false;
              }
  
              // Sinon, c'est de la ponctuation standalone
              return true;
          }
        
          // Fonction pour détecter les caractères invisibles
          function isInvisibleChar(char) {
              const code = char.charCodeAt(0);
              return (
                  char === '\u200B' ||  // Zero Width Space
                  char === '\u200C' ||  // Zero Width Non-Joiner
                  char === '\u200D' ||  // Zero Width Joiner
                  char === '\uFEFF' ||  // Zero Width No-Break Space
                  char === '\u00AD' ||  // Soft Hyphen
                  (code >= 0x2000 && code <= 0x200F) || // Various Unicode spaces
                  (code >= 0x202A && code <= 0x202E)    // Directional formatting characters
              );
          }
         
          async function loadIndexPage(index) {
            const curr = await fetchPage(index);
            document.getElementById("page-center").innerHTML = `<article id="article-center" class="\${curr.className}">\${curr.html}</article>`;
            adjustArticle('article-center');
            addVideoCover('article-center');
           
            container.style.transition = "none";
            container.style.transform = "translateX(-100%)";
            void container.offsetWidth;
            container.style.transition = "transform 0.3s ease-in-out";
            
            wrapWordsWithSpan('article-center');
            
            //console.log(document.getElementById("page-center").innerHTML);
          }
          
          async function loadPrevAndNextPages(index) {
            const prev = await fetchPage(index - 1);
            const next = await fetchPage(index + 1);
    
            document.getElementById("page-left").innerHTML = `<article id="article-left" class="\${prev.className}">\${prev.html}</article>`;
            document.getElementById("page-right").innerHTML = `<article id="article-right" class="\${next.className}">\${next.html}</article>`;
    
            adjustArticle('article-left');
            addVideoCover('article-left');
            adjustArticle('article-right');
            addVideoCover('article-right');
          }
    
          async function loadPages(currentIndex) {
            await loadIndexPage(currentIndex);
          
            // Restaurer la position de scroll verticale pour une page donnée
            function restoreScrollPosition(page, index) {
              const scroll = scrollTopPages[index] ?? 0;
              page.scrollTop = scroll;
              scrollTopPages[index] = scroll;
            }
          
            restoreScrollPosition(pageCenter, currentIndex);
            pageCenter.scrollLeft = 0;
          
            await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
            loadUserdata();
            await loadPrevAndNextPages(currentIndex);
          
            restoreScrollPosition(pageLeft, currentIndex - 1);
            restoreScrollPosition(pageRight, currentIndex + 1);
          }
          
          async function jumpToPage(index) {
            closeToolbar();
            if (index < 0 || index > maxIndex) return;
    
            currentIndex = index;
            await loadPages(index);
          }
          
          async function jumpToIdSelector(selector, idAttr, begin, end) {
            closeToolbar();
          
            const paragraphs = pageCenter.querySelectorAll(selector);
            let targetParagraph = null;
            
            if (begin === -1 && end === -1) {
              // Rétablir tous les paragraphes à l'opacité normale
              paragraphs.forEach(p => {
                p.style.opacity = '1';
              });
              return;
            }
          
            if(selector === '[data-pid]') {
              paragraphs.forEach(p => {
                const pid = parseInt(p.getAttribute(idAttr), 10);
          
                if (pid >= begin && pid <= end && !targetParagraph) {
                  targetParagraph = p;
                }
          
                console.log('targetParagraph', pid, begin, end, targetParagraph);
                p.style.opacity = (pid >= begin && pid <= end) ? '1' : '0.5';
              });
            }
            else {
              paragraphs.forEach(p => {
                const attrValue = p.getAttribute(idAttr).trim();
          
                const idParts = attrValue.split('-');
          
                if (idParts.length < 4) return; // Vérifie que le format est correct
          
                const verse = parseInt(idParts[2], 10); // Position 2 = 3ème élément (5)
          
          
                if (verse >= begin && verse <= end && !targetParagraph) {
                  targetParagraph = p;
                }
          
                p.style.opacity = (verse >= begin && verse <= end) ? '1' : '0.5';
              });
            }
          
            if (targetParagraph) {
              isChangingParagraph = true;
            
              // Récupère tous les paragraphes visibles (opacity === '1')
              const visibleParagraphs = Array.from(pageCenter.querySelectorAll(selector)).filter(p => p.style.opacity === '1');
            
              if (visibleParagraphs.length === 0) {
                isChangingParagraph = false;
                return;
              }
            
              // Trouver la position top du premier visible et bottom du dernier visible
              const firstTop = visibleParagraphs[0].offsetTop;
              const lastParagraph = visibleParagraphs[visibleParagraphs.length - 1];
              const lastBottom = lastParagraph.offsetTop + lastParagraph.offsetHeight;
            
              // Hauteur totale combinée des paragraphes sélectionnés
              const totalHeight = lastBottom - firstTop;
            
              const screenHeight = pageCenter.clientHeight;
            
              const visibleHeight = screenHeight - appBarHeight - bottomNavBarHeight;
            
              let scrollToY;
            
              if (totalHeight < visibleHeight) {
                // Centre la zone combinée
                scrollToY = firstTop - appBarHeight - (visibleHeight / 2) + (totalHeight / 2);
              } else {
                // Affiche le haut de la zone combinée sous l'app bar
                scrollToY = firstTop - appBarHeight;
              }
            
              scrollToY = Math.max(scrollToY, 0);
            
              pageCenter.scrollTop = scrollToY;
            
              // Attend la prochaine frame pour être sûr que c'est appliqué
              await new Promise(requestAnimationFrame);
            
              isChangingParagraph = false;
            }
          }

          
          function selectWords(words) {
            // Supprimer d'abord la classe 'searched' de tous les éléments
            pageCenter.querySelectorAll('.searched').forEach(element => {
                element.classList.remove('searched');
            });
            
            // Récupérer tous les éléments avec la classe 'word'
            const wordElements = document.querySelectorAll('.word');
        
            // Ajouter la classe 'searched' aux éléments dont le texte correspond
            wordElements.forEach(element => {
                const wordText = element.textContent.toLowerCase(); // Conversion en minuscules pour comparaison
                if (words.some(searchWord => wordText.includes(searchWord.toLowerCase()))) {
                    element.classList.add('searched');
                }
            });
          }

          function isBible() {
            return cachedPages[currentIndex]['isBibleChapter'];
          }
     
          function restoreOpacity() {
            selector = isBible() ? '.v' : '[data-pid]';
            pageCenter.querySelectorAll(selector).forEach(e => e.style.opacity = '1');
          }
    
          function dimOthers(paragraphs, selector) {
            // Convertir currents en tableau, si ce n'est pas déjà un tableau
            const paragraphsArray = Array.isArray(paragraphs) ? paragraphs : Array.from(paragraphs);
          
            const elements = pageCenter.querySelectorAll(selector);
          
            elements.forEach(element => {
              element.style.opacity = paragraphsArray.includes(element) ? '1' : '0.5';
            });
          }
          
          function createToolbarButton(icon, onClick) {
            const button = document.createElement('button');
            const isDark = ${webViewData.theme == 'cc-theme--dark'};
          
            button.innerHTML = icon;
          
            // Couleurs selon le thème
            const baseColor = isDark ? 'white' : '#4f4f4f';
            const hoverColor = isDark ? '#606060' : '#e6e6e6';
          
            button.style.cssText = `
              font-family: jw-icons-external;
              font-size: 26px;
              padding: 3px;
              border-radius: 5px;
              margin: 0 7px;
              color: \${baseColor};
              background: none;
              -webkit-tap-highlight-color: transparent;
            `;
          
            button.addEventListener('click', onClick);
          
            return button;
          }
          
          function createToolbarButtonColor(target, highlightToolbar, isSelected) {
            const button = document.createElement('button');
          
            // Créer l'élément image
            const img = document.createElement('img');
            img.src = `highlights/$theme/highlight.png`;
            img.style.cssText = `
              width: 40px;
              height: 24px;
              display: block;
            `;
          
            // Ajouter l'image au bouton
            button.appendChild(img);
          
            button.style.cssText = `
              padding: 3px;
              border-radius: 5px;
              margin: 0 7px;
              background: none;
              -webkit-tap-highlight-color: transparent;
            `;
          
            // Créer la toolbar de couleurs
            function createColorToolbar(target) {
              const colorToolbar = document.createElement('div');
              colorToolbar.classList.add('toolbar-colors');
              colorToolbar.style.cssText = `
                position: absolute;
                top: \${highlightToolbar.style.top};
                left: \${highlightToolbar.style.left};
                background-color: \${${webViewData.theme == 'cc-theme--dark'} ? '#424242' : '#ffffff'};
                padding: 1px;
                border-radius: 6px;
                box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
                white-space: nowrap;
                display: flex;
                opacity: 1;
                transform: translateX(-50%);
                width: max-content;
                max-width: 90vw; /* pour éviter qu'elle dépasse trop l'écran */
              `;
              
              // ajouter un bouton retour
              const backButton = document.createElement('button');
              backButton.innerHTML = '&#xE639;';
              backButton.style.cssText = `
                font-family: jw-icons-external;
                font-size: 26px;
                padding: 3px;
                border-radius: 5px;
                margin: 0 3px;
                color: \${${webViewData.theme == 'cc-theme--dark'} ? 'white' : '#4f4f4f'};
                background: none;
                -webkit-tap-highlight-color: transparent;
              `;
              backButton.addEventListener('click', () => {
                colorToolbar.remove();
                highlightToolbar.style.opacity = 1;
              });
              colorToolbar.appendChild(backButton);
              
              let colorIndex = highlightColorIndex;
              const highlightMap = {
                'highlight-yellow': 1,
                'highlight-green': 2,
                'highlight-blue': 3,
                'highlight-pink': 4,
                'highlight-orange': 5,
                'highlight-purple': 6
              };
              
              target.classList.forEach(className => {
                if (highlightMap.hasOwnProperty(className)) {
                  colorIndex = highlightMap[className];
                }
              });
                        
              // Créer un bouton pour chaque couleur
              highlightAssets.forEach((assetPath, index) => {
                const colorButton = document.createElement('button');
                const colorImg = document.createElement('img');
                
                if (index+1 == colorIndex) {
                  colorImg.src = highlightSelectedAssets[index];
                }
                else {
                  colorImg.src = assetPath;
                }
                
                colorImg.style.cssText = `
                  width: 25px;
                  height: 25px;
                  display: block;
                `;
                
                colorButton.appendChild(colorImg);
                colorButton.style.cssText = `
                  padding: 3px;
                  border-radius: 5px;
                  margin: 0 6px;
                  background: none;
                  -webkit-tap-highlight-color: transparent;
                `;
          
                // Ajouter l'événement de clic pour chaque couleur
                colorButton.addEventListener('click', (e) => {
                  e.stopPropagation();
                  highlightColorIndex = index+1;
                  if(isSelected) {
                    const paragraphInfo = getTheFirstTargetParagraph(target);
                    if (!paragraphInfo) return;
                    
                    const { id, paragraph, isVerse } = paragraphInfo;
                    const blockType = isVerse ? 2 : 1;
                    
                    const selectedElements = pageCenter.querySelectorAll('.selected');
                    
                      // Supprimer toutes les classes de surlignage existantes
                    const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
            
                    selectedElements.forEach(element => {
                      // Supprimer toutes les classes de surlignage existantes
                      element.classList.remove('selected');
                      // Ajouter la nouvelle classe de couleur
                      element.classList.add(newHighlightClass);
                    });
                    
                    const allWords = Array.from(paragraph.querySelectorAll('.word, .punctuation'));

                    const startToken = allWords.indexOf(selectedElements[0]);
                    const endToken = allWords.indexOf(selectedElements[selectedElements.length - 1]);
                    
                    window.flutter_inappwebview.callHandler('addHighlight', {
                      blockType: blockType,
                      identifier: id,
                      startToken: startToken,
                      endToken: endToken,
                      colorIndex: index + 1,
                      guid: target.getAttribute('data-highlight-id'),
                    });
                  }
                  else {
                    changeHighlightColor(target.getAttribute('data-highlight-id'), index+1);
                  }
                  colorToolbar.remove();
                  closeToolbar();
                });
          
                colorToolbar.appendChild(colorButton);
              });
          
              return colorToolbar;
            }
          
            // Événement de clic sur le bouton principal
            button.addEventListener('click', (e) => {
              e.stopPropagation();
              
              highlightToolbar.style.opacity = '0';
              
              // Vérifier s'il y a déjà une toolbar-colors ouverte
              const existingColorToolbar = document.querySelector('.toolbar-colors');
              if (existingColorToolbar) {
                existingColorToolbar.remove();
                return;
              }
          
              // Créer et afficher la toolbar de couleurs
              const colorToolbar = createColorToolbar(target);
              document.body.appendChild(colorToolbar);

              // Fermer la toolbar si on clique ailleurs
              const closeColorToolbar = (event) => {
                if (!colorToolbar.contains(event.target) && !button.contains(event.target)) {
                  colorToolbar.style.opacity = '0';
                  setTimeout(() => {
                    if (colorToolbar.parentNode) {
                      colorToolbar.remove();
                    }
                  }, 100);
                  document.removeEventListener('click', closeColorToolbar);
                }
              };
          
              setTimeout(() => {
                document.addEventListener('click', closeColorToolbar);
              }, 10);
            });
            
            return button;
          }
    
          function closeToolbar() {
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight, .toolbar-colors');
            const onlyToolbars = document.querySelectorAll('.toolbar');
          
            if (onlyToolbars.length >= 1) {
              restoreOpacity(); // Appel si au moins une .toolbar est présente
            }
          
            toolbars.forEach(toolbar => toolbar.style.opacity = '0');
          
            setTimeout(() => {
              toolbars.forEach(toolbar => toolbar.remove());
            }, 200);
          }

          function removeAllSelected() {
            pageCenter.querySelectorAll('.selected').forEach(elem => {
              elem.classList.remove('selected');
            });
          }
    
          function showToolbarHighlight(target, highlightId) {
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight');

            // Masquer les toolbars existantes
            toolbars.forEach(toolbar => {
              toolbar.style.opacity = '0';
            });
          
            setTimeout(() => {
              toolbars.forEach(toolbar => toolbar.remove());
            }, 200);
          
            // Ne rien faire si la bonne toolbar existe déjà
            const matchingToolbar = Array.from(toolbars).find(
              toolbar => toolbar.getAttribute('data-highlight-id') === highlightId
            );
            if (matchingToolbar) return;
            
            let left = 0;
            let top = 0;
            
            let targets = [];
   
            const isSelected = target.classList.contains('selected');
            if(isSelected) {
              targets = pageCenter.querySelectorAll('.selected');
              if (targets.length === 0) return;
            }
            else {
              targets = pageCenter.querySelectorAll(`[data-highlight-id="\${highlightId}"]`);
              if (targets.length === 0) return;
            }
            
            // Horizontal : centré sur tous les targets
            let minLeft = Infinity;
            let maxRight = -Infinity;
            targets.forEach(el => {
              const rect = el.getBoundingClientRect();
              minLeft = Math.min(minLeft, rect.left);
              maxRight = Math.max(maxRight, rect.right);
            });
              
            const scrollX = window.scrollX;
            left = minLeft + (maxRight - minLeft) / 2 + scrollX;
              
            // Obtenir les limites de pageCenter
            const pageRect = pageCenter.getBoundingClientRect();
            const pageLeft = pageRect.left + scrollX;
            const pageRight = pageRect.right + scrollX;
            const toolbarWidth = 200; // Estimation ou réelle largeur max
              
            // Clamp pour éviter les débordements
            left = Math.max(left, pageLeft + toolbarWidth / 2 + 10);  // +10 = marge
            left = Math.min(left, pageRight - toolbarWidth / 2 - 10);
              
            // Vertical : au-dessus du premier highlight
            const firstRect = targets[0].getBoundingClientRect();
            const scrollY = window.scrollY;
            const toolbarHeight = 40;
            const safetyMargin = 10;
              
            top = firstRect.top + scrollY - toolbarHeight - safetyMargin;
            const minVisibleY = scrollY + appBarHeight + safetyMargin;
            if (top < minVisibleY) {
              top = Math.max(firstRect.top + scrollY + safetyMargin, minVisibleY);
            }

            // Créer la toolbar
            const toolbar = document.createElement('div');
            toolbar.classList.add('toolbar-highlight');
            toolbar.setAttribute('data-highlight-id', highlightId);
            toolbar.style.cssText = `
              position: absolute;
              top: \${top}px;
              left: \${left}px;
              background-color: ${webViewData.theme == 'cc-theme--dark' ? '#424242' : '#ffffff'};
              padding: 1px;
              border-radius: 6px;
              box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
              white-space: nowrap;
              display: flex;
              opacity: 1;
              transform: translateX(-50%);
              width: max-content;
              max-width: 90vw; /* pour éviter qu'elle dépasse trop l'écran */
            `;

            document.body.appendChild(toolbar);

             // Attendre le rendu pour obtenir la vraie largeur
            requestAnimationFrame(() => {
              const toolbarRect = toolbar.getBoundingClientRect();
              const realWidth = toolbarRect.width;
            
              // Recalcule left avec limites
              left = Math.min(
                Math.max(left, pageLeft + realWidth / 2 + 10),
                pageRight - realWidth / 2 - 10
              );
              
              toolbar.style.left = `\${left}px`;
              toolbar.style.opacity = '1';
            });
            
            const paragraphInfo = getTheFirstTargetParagraph(target);
            const id = paragraphInfo.id;
            const paragraph = paragraphInfo.paragraph;
            const isVerse = paragraphInfo.isVerse;
            
            const text = Array.from(targets)
                .map(elem => elem.innerText)
                .filter(text => text.length > 0)
                .join('');

            toolbar.appendChild(createToolbarButtonColor(target, toolbar, isSelected));

            const buttons = [
              ['&#xE681;', () => isSelected ? addNote(paragraph, id, isVerse, text) : addNoteWithHighlight(target, target.getAttribute('data-highlight-id'))],
              ...(!isSelected ? [['&#xE6C5;', () => removeHighlight(target.getAttribute('data-highlight-id'))]] : []),
              ['&#xE651;', () => callHandler('copyText', { text })],
              ['&#xE676;', () => callHandler('search', { query: text })],
              ['&#xE696;', () => callHandler('copyText', { text })] // <== plus de virgule ici
            ];
          
            buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));
          }
          
          
          function showToolbar(paragraphs, pid, selector, hasAudio, type) {
            const paragraph = paragraphs[0];
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight');
                
            toolbars.forEach(toolbar => {
              toolbar.style.opacity = '0';
            });
            
            // Attendre que l'animation soit terminée, puis retirer les toolbars
            setTimeout(() => {
              toolbars.forEach(toolbar => toolbar.remove());
            }, 200);
            
            // Vérifier s'il y a une toolbar avec le bon highlightId
            const matchingToolbar = Array.from(toolbars).find(toolbar => toolbar.getAttribute('data-pid') === pid);
            
            if (matchingToolbar) {
              restoreOpacity();
              return;
            }
             
            // Ici on dim les autres si pas highlight
            dimOthers(paragraphs, selector);
            
            const rect = paragraph.getBoundingClientRect();
            const scrollY = window.scrollY;
            const scrollX = window.scrollX;
            
            const toolbarHeight = 40;
            const safetyMargin = 10;
            
            const pageCenter = document.getElementById('page-center');
            
            // Centrage horizontal absolu
            const left = rect.left + scrollX + (rect.width / 2);
            
            // Position verticale au-dessus du paragraphe (par défaut)
            let top = rect.top + scrollY - toolbarHeight - safetyMargin;
            
            // Si le haut du paragraphe n'est **pas visible** à cause de l'AppBar (ou du haut de l'écran)
            const minVisibleY = scrollY + appBarHeight + safetyMargin;
            if (top < minVisibleY) {
              // On place la toolbar **juste sous le haut du paragraphe**, visible
              top = Math.max(rect.top + scrollY + safetyMargin, minVisibleY);
            }

            const toolbar = document.createElement('div');
            toolbar.classList.add('toolbar');
            toolbar.setAttribute('data-pid', pid);
            toolbar.style.cssText = `
              position: absolute;
              top: \${top}px;
              left: \${left}px;
              background-color: ${webViewData.theme == 'cc-theme--dark' ? '#424242' : '#ffffff'};
              padding: 1px;
              border-radius: 6px;
              box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
              white-space: nowrap;
              display: flex;
              opacity: 1;
              transform: translateX(-50%)
            `;
          
            document.body.appendChild(toolbar);
          
            let buttons = [];
            
            let allParagraphsText = '';
            paragraphs.forEach(paragraph => {
              allParagraphsText += paragraph.innerText;
            });
            
            if (type === 'verse') {
              buttons = [
                ['&#xE658;', () => callHandler('showVerse', { id: pid })],
                ['&#xE681;', () => addNote(paragraph, pid, true, '')],
                ['&#xE61F;', () => callHandler('showOtherTranslations', { id: pid })],
                ['&#xE62A;', () => callHandler('bookmark', { snippet: allParagraphsText, id: pid, isBible: true })],
                ['&#xE651;', () => callHandler('copyText', { text: allParagraphsText })],
                ['&#xE620;', () => callHandler('searchVerse', { query: pid })],
                ['&#xE6A3;', () => callHandler('share', { id: pid, isBible: true })],
              ];
            } else {
              buttons = [
                ['&#xE681;', () => addNote(paragraph, pid, false, '')],
                ['&#xE62A;', () => callHandler('bookmark', { snippet: paragraph.innerText, id: pid, isBible: false })],
                ['&#xE6A3;', () => callHandler('share', { id: pid, isBible: false })],
                ['&#xE651;', () => callHandler('copyText', { text: paragraph.innerText })],
              ];
            }
          
            buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));
          
            if (hasAudio) {
              toolbar.appendChild(createToolbarButton('&#xE65E;', () => callHandler('playAudio', { id: pid, isBible: type === 'verse' })));
            }
          }

          function getAllHighlights(uuid) {
            return pageCenter.querySelectorAll(`[data-highlight-id="\${uuid}"]`);
          }
          
          function removeHighlight(uuid) {
            removeHighlightByGuid(uuid);
            closeToolbar();
            removeAllSelected();
          }
          
          async function addNote(paragraph, id, isBible, title) {
              const noteGuid = await window.flutter_inappwebview.callHandler('addNote', {
                  title: title,
                  blockType: (id != null) ? (isBible ? 2 : 1) : 1,
                  identifier: id,
                  userMarkGuid: null,
                  colorIndex: 0
              });
              
              addNoteWithGuid(paragraph, null, noteGuid.uuid, 0, title, '', '');
              closeToolbar();
              removeAllSelected();
          }
          
          async function removeNote(noteGuid) {
              const note = pageCenter.querySelector(`[data-note-id="\${noteGuid}"]`);
              if (note) {
                  note.remove();
              }
              await window.flutter_inappwebview.callHandler('removeNote', {
                  guid: noteGuid,
              });
          }
          
          async function addNoteWithHighlight(highlightTarget, highlightGuid) {
              const colorClasses = [
                  'highlight-transparent',
                  'highlight-yellow',
                  'highlight-green',
                  'highlight-blue',
                  'highlight-pink',
                  'highlight-orange',
                  'highlight-purple'
              ];
              
              const paragraphInfo = getTheFirstTargetParagraph(highlightTarget);
              const id = paragraphInfo.id;
              const paragraph = paragraphInfo.paragraph;
              const isVerse = paragraphInfo.isVerse;
          
              const allHighlights = getAllHighlights(highlightGuid);
              
              // Récupère le texte entre le premier et le dernier élément avec le même highlightGuid
              let title = '';
              if (allHighlights.length > 0) {
                  const first = allHighlights[0];
                  const last = allHighlights[allHighlights.length - 1];
                  
                  const range = document.createRange();
                  range.setStartBefore(first);
                  range.setEndAfter(last);
                  
                  const content = range.cloneContents();
                  const div = document.createElement('div');
                  div.appendChild(content);
                  title = div.textContent.trim(); // Le texte à utiliser dans le titre
              }
          
              let colorIndex = colorClasses.findIndex(cls => highlightTarget.classList.contains(cls));
          
              const noteGuid = await window.flutter_inappwebview.callHandler('addNote', {
                  title: title,
                  blockType: isVerse ? 2 : 1,
                  identifier: id,
                  userMarkGuid: highlightGuid,
                  colorIndex: colorIndex
              });
              
              addNoteWithGuid(paragraph, highlightGuid, noteGuid.uuid, colorIndex, title, '', '');
              closeToolbar();
              removeAllSelected();
          }

          function callHandler(name, args) {
            window.flutter_inappwebview.callHandler(name, args);
            closeToolbar();
            removeAllSelected();
          }
        
          function whenClickOnParagraph(target, selector, idAttr, classFilter) {
            if (!target) {
              closeToolbar();
              return;
            }
          
            if (classFilter === 'paragraph') {
              const matchedElement = target.closest(`[\${idAttr}]`);
              const pid = matchedElement?.getAttribute(idAttr);
              
              if (!pid) {
                closeToolbar();
                return;
              }

              // Optimisation avec optional chaining et court-circuit
              const hasAudio = cachedPages[currentIndex]?.audiosMarkers?.some(m => 
                String(m.mepsParagraphId) === pid
              ) ?? false;
              
              showToolbar([matchedElement], pid, selector, hasAudio, classFilter);
            }
            else {
              // Traitement des versets
              const matchedElement = target.closest(`[\${idAttr}]`);
              let vid = matchedElement?.getAttribute(idAttr);
            
              if (!vid) {
                closeToolbar();
                return;
              }
            
              // Extraire le numéro de verset (3ème partie) de vid
              // vid format: v1-3-5-1 -> on veut récupérer "5"
              const vidParts = vid.split('-');
              const verseNumber = vidParts[2]; // Index 2 pour la 3ème partie
              
              // Trouver tous les éléments qui correspondent au même verset
              // (même livre, même chapitre, même verset, peu importe la partie)
              const versePattern = `\${vidParts[0]}-\${vidParts[1]}-\${verseNumber}-`; // v1-3-5-
              console.log('versePattern', versePattern);
              const verseElements = pageCenter.querySelectorAll(`[\${idAttr}^="\${versePattern}"]`);
              
              console.log('verseElements', verseElements);
              
              console.log('verseNumber', verseNumber);
            
              // Utiliser le numéro de verset pour la vérification audio
              const hasAudio = cachedPages[currentIndex]?.audiosMarkers?.some(m => 
                  String(m.verseNumber) === verseNumber
                ) ?? false;

              if(verseElements.length > 0 && verseElements !== null) {
                showToolbar(verseElements, verseNumber, selector, hasAudio, classFilter)
              }
              else {
                closeToolbar();
              }
            }
          }
    
          async function loadUserdata() {
            const userdata = await window.flutter_inappwebview.callHandler('getUserdata', '');
            
            const bibleMode = isBible();
            const selector = bibleMode ? '.v' : '[data-pid]';
            const idAttr = bibleMode ? 'id' : 'data-pid';
            const blockType = bibleMode ? 2 : 1;
          
            highlights = userdata.highlights;
            notes = userdata.notes;
            inputFields = userdata.inputFields;
            bookmarks = userdata.bookmarks;
          
            console.log('Highlights:', highlights);
            console.log('Notes:', notes);
            console.log('Input Fields:', inputFields);
            console.log('Bookmarks:', bookmarks);
          
            // Pré-indexation des données pour un accès plus rapide
            const highlightsMap = new Map();
            const notesMap = new Map();
            const bookmarksMap = new Map();
          
            highlights.forEach(h => {
              const key = `\${blockType}-\${h.Identifier}`;
              if (!highlightsMap.has(key)) highlightsMap.set(key, []);
              highlightsMap.get(key).push(h);
            });
          
            notes.forEach(n => {
              const key = `\${n.BlockIdentifier}`;
              if (!notesMap.has(key)) notesMap.set(key, []);
              notesMap.get(key).push(n);
            });
          
            bookmarks.forEach(b => {
              const key = `\${b.BlockType}-\${b.BlockIdentifier}`;
              bookmarksMap.set(key, b);
            });
          
            const processedNoteGuids = new Set(); // Pour éviter les doublons
            
            const groupedParagraphs = new Map();

            pageCenter.querySelectorAll(selector).forEach(p => {
              let id = p.getAttribute(idAttr);
            
              if (bibleMode && id?.startsWith('v')) {
                const segments = id.split('-');
                if (segments.length >= 3) {
                  // clé = "v1-3-4", sans la partie
                  id = segments.slice(0, 3).join('-');
                }
              }
            
              if (!groupedParagraphs.has(id)) {
                groupedParagraphs.set(id, []);
              }
              groupedParagraphs.get(id).push(p);
            });
            
            // Pour chaque groupe, concaténer le contenu et appliquer les marques
            groupedParagraphs.forEach((paragraphs, id) => {
              // Modifier le premier paragraphe
              let blockIdentifier = id;
              if (bibleMode && id?.startsWith('v')) {
                blockIdentifier = id.split('-')[2];
              }
              
              const p = paragraphs[0];

              const idKey = `\${blockType}-\${blockIdentifier}`;
              const bookmark = bookmarksMap.get(idKey);
              if (bookmark) {
                addBookmark(p, bookmark.BlockType, bookmark.BlockIdentifier, bookmark.Slot);
              }
          
              const matchingHighlights = highlightsMap.get(idKey) || [];
              matchingHighlights.forEach(h => {
                addHighlight(paragraphs, h.BlockType, h.Identifier, h.StartToken, h.EndToken, h.UserMarkGuid, h.ColorIndex);
              });
          
              const matchingNotes = notesMap.get(blockIdentifier) || [];
              matchingNotes.forEach(note => {
                if (processedNoteGuids.has(note.Guid)) return; // Ne pas ajouter deux fois
          
                const matchingHighlight = matchingHighlights.find(h => h.UserMarkGuid === note.UserMarkGuid);
          
                addNoteWithGuid(
                  p,
                  matchingHighlight?.UserMarkGuid || null,
                  note.Guid,
                  note.ColorIndex ?? 0,
                  note.Title,
                  note.Content,
                  note.TagsId
                );
          
                processedNoteGuids.add(note.Guid);
              });      
            });  
          
            // Traitement des champs input/textarea
            pageCenter.querySelectorAll('input, textarea').forEach(input => {
              const id = input.getAttribute('id');
              const inputField = inputFields.find(field => field?.TextTag === id);
          
              if (inputField) {
                if (input.type === 'checkbox') {
                  input.checked = inputField.Value === '1';
                } else {
                  input.value = inputField.Value;
                  input.style.height = 'auto';
                  input.style.height = `\${input.scrollHeight + 4}px`;
                }
              }
          
              const adjustTextareaHeight = (textarea) => {
                textarea.rows = 1;
                textarea.style.height = 'auto';
                textarea.style.height = `\${textarea.scrollHeight + 4}px`;
                repositionAllNotes();
                repositionAllBookmarks();
              };
          
              const eventType = input.tagName === 'TEXTAREA' ? 'input' : 'change';
              input.addEventListener(eventType, () => {
                const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
                window.flutter_inappwebview.callHandler('onInputChange', {
                  tag: input.id || '',
                  value: value
                });
              });
          
              if (input.tagName === 'TEXTAREA') {
                input.addEventListener('input', () => adjustTextareaHeight(input));
                input.rows = 1;
              }
            });
            
            repositionAllNotes();
            repositionAllBookmarks();
          }
          
          function getTarget(id) {
            if (isBible()) {
              const elements = pageCenter.querySelectorAll('.v');
          
              for (const el of elements) {
                const idParts = el.id.split('-');
                const thirdPart = idParts[2];
          
                if (thirdPart === String(id)) {
                  return el;
                }
              }
            } else {
              return pageCenter.querySelector(`[data-pid="\${id}"]`);
            }
          
            return null;
          }
          
          function getBookmarkPosition(target, bookmark) {
             // Calculer la position après le rendu
             const targetRect = target.getBoundingClientRect();
             const pageRect = pageCenter.getBoundingClientRect();
             const topRelativeToPage = targetRect.top - pageRect.top + pageCenter.scrollTop;
          
             bookmark.style.top = `\${topRelativeToPage + 3}px`;
          }
          
          function repositionAllBookmarks() {
            const bookmarks = document.querySelectorAll('.bookmark-icon');
            bookmarks.forEach(bookmark => {
              const id = bookmark.getAttribute('id');
              let target = getTarget(id);
              getBookmarkPosition(target, bookmark);
            });
          }
          
          function addBookmark(target, blockType, blockIdentifier, slot) {
            if (!target) {
              target = getTarget(blockIdentifier);
            }
          
            const imgSrc = bookmarkAssets[slot];
            if (imgSrc && target) {
              requestAnimationFrame(() => {
                const bookmark = document.createElement('img');
                bookmark.setAttribute('id', blockIdentifier);
                bookmark.setAttribute('slot', slot);
                bookmark.src = imgSrc;
                bookmark.classList.add('bookmark-icon');
          
                getBookmarkPosition(target, bookmark);
          
                pageCenter.appendChild(bookmark);
              });
            }
          }
          
          function removeBookmark(blockIdentifier, slot) {
            const bookmark = pageCenter.querySelector(`.bookmark-icon[id="\${blockIdentifier}"]`);
            if (bookmark.getAttribute('slot') === slot.toString()) {
              bookmark.remove();
            }
          }
          
          function addHighlight(targets, blockType, blockIdentifier, startToken, endToken, guid, colorIndex) {
            if (!targets || targets.length === 0) {
              const fallback = pageCenter.querySelector(`[data-pid="\${blockIdentifier}"]`);
              if (fallback) targets = [fallback];
              else return;
            }
          
            const highlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][colorIndex]}`;
          
            // Rassembler tous les tokens de tous les targets
            const allTokens = targets.flatMap(target =>
              Array.from(target.querySelectorAll('.word, .punctuation, .escape')).map(token => ({
                element: token,
                parent: target,
              }))
            );
          
            // Filtrer pour ne garder que les mots et ponctuations
            const wordAndPunctTokens = allTokens.filter(({ element }) =>
              element.classList.contains('word') || element.classList.contains('punctuation')
            );
          
            // Prendre les bons tokens par tranche
            const selectedTokens = wordAndPunctTokens.slice(startToken, endToken + 1);
          
            selectedTokens.forEach(({ element }, index) => {
              element.classList.add(highlightClass);
              element.setAttribute('data-highlight-id', guid);
          
              const tokenIndexInAll = allTokens.findIndex(t => t.element === element);
              const next = allTokens[tokenIndexInAll + 1];
          
              if (next && next.element.classList.contains('escape') && index !== selectedTokens.length - 1) {
                next.element.classList.add(highlightClass);
                next.element.setAttribute('data-highlight-id', guid);
              }
            });
          }
          
          function getNotePosition(element, noteIndicator) {
             const targetRect = element.getBoundingClientRect();
             const pageRect = pageCenter.getBoundingClientRect();
             const topRelativeToPage = targetRect.top - pageRect.top + pageCenter.scrollTop;
              
             const targetHeight = targetRect.height;
             const noteHeight = 12; // hauteur du carré
             const topOffset = topRelativeToPage + (targetHeight - noteHeight) / 2;
              
             noteIndicator.style.top = `\${topOffset}px`;
          }
          
          function repositionAllNotes() {
            const notes = document.querySelectorAll('[data-note-id]');
            notes.forEach(note => {
              const highlightGuid = note.getAttribute('data-note-highlight-id');
              const highlight = document.querySelector(`[data-highlight-id="\${highlightGuid}"]`);
              if (highlight) {
                getNotePosition(highlight, note);
              }
            });
          }

          function addNoteWithGuid(target, highlightGuid, noteGuid, colorIndex, title, content, tagsId) {
            const idAttr = isBible() ? 'id' : 'data-pid';
        
            // Chercher le premier élément surligné si highlightGuid est donné
            let firstHighlightedElement = null;
            if (highlightGuid) {
                firstHighlightedElement = target.querySelector(`[data-highlight-id="\${highlightGuid}"]`);
                if (!firstHighlightedElement) {
                    console.log(`Aucun surlignage trouvé pour le guid: \${highlightGuid}`);
                    firstHighlightedElement = null; // on force null car on ne veut pas utiliser target comme élément
                }
            }
       
            // Créer le carré de note
            const noteIndicator = document.createElement('div');
            noteIndicator.className = 'note-indicator';
            noteIndicator.setAttribute('data-note-id', noteGuid);
            noteIndicator.setAttribute('data-note-highlight-id', highlightGuid || '');
        
            // Couleurs
            const colors = ["gray", "yellow", "green", "blue", "pink", "orange", "purple"];
            const colorName = colors[colorIndex] || "yellow";
            noteIndicator.classList.add(`note-indicator-\${colorName}`);
        
            // Détecter si le target (paragraphe) est dans une liste ul/ol
            const targetUl = target.closest('ul');
            const isInList = target.tagName === 'P' && target.hasAttribute(idAttr) && targetUl && targetUl.classList.contains('source');
        
            // Calcul de position différent si pas de firstHighlightedElement
            if (firstHighlightedElement) {
                getNotePosition(firstHighlightedElement, noteIndicator);
        
                // Positionner à droite si élément est à droite
                const elementRect = firstHighlightedElement.getBoundingClientRect();
                const windowWidth = window.innerWidth || document.documentElement.clientWidth;
        
                if (elementRect.left > windowWidth / 2) {
                    noteIndicator.style.right = '4px';
                    noteIndicator.style.left = 'auto';
                } 
                else if (isInList) {
                    noteIndicator.style.left = '10px';
                    noteIndicator.style.right = 'auto';
                }
            } 
            else {
                getNotePosition(target, noteIndicator);
        
                // Positionner à droite si élément est à droite
                const elementRect = target.getBoundingClientRect();
                const windowWidth = window.innerWidth || document.documentElement.clientWidth;
        
                if (elementRect.left > windowWidth / 2) {
                    noteIndicator.style.right = 'auto';
                } 
            }
        
            // Clic pour afficher la note
            noteIndicator.addEventListener('click', (e) => {
                e.stopPropagation();
                showNotePopup(highlightGuid, noteGuid, title, content, colorName, tagsId, e.pageX, e.pageY);
                window.flutter_inappwebview.callHandler('showDialog', true);
            });
            
            // Clic pour supprimer la note
            noteIndicator.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                removeNote(noteGuid);
            });
        
            // Ajouter le carré au container principal
            pageCenter.appendChild(noteIndicator);
          }
          
          async function showNotePopup(highlightGuid, noteGuid, title, content, colorName, tagsId, x, y) {
  const allTags = await window.flutter_inappwebview.callHandler('getTags');
  const tags = allTags.tags;

  const existingPopup = document.querySelector('.note-popup');
  if (existingPopup) existingPopup.remove();

  const safePadding = 20;
  const minWidth = 320;
  const maxWidth = window.innerWidth * 0.9;

  const tempTextarea = document.createElement('textarea');
  tempTextarea.style.cssText = `
    position: absolute;
    visibility: hidden;
    white-space: pre-wrap;
    word-wrap: break-word;
    font-size: inherit;
    line-height: 1.6;
    padding: 20px;
    border: none;
    width: auto;
    max-width: \${maxWidth - 40}px;
  `;
  tempTextarea.value = content;
  document.body.appendChild(tempTextarea);

  const contentWidth = Math.max(minWidth, Math.min(tempTextarea.scrollWidth + 80, maxWidth));
  tempTextarea.style.width = \`\${contentWidth - 40}px\`;
  const contentHeight = Math.max(60, Math.min(tempTextarea.scrollHeight, 300));
  document.body.removeChild(tempTextarea);

  const titleBarHeight = 60;
  const tagsContainerHeight = 120;
  const totalWidth = contentWidth;
  const totalHeight = titleBarHeight + contentHeight + tagsContainerHeight;

  let left = x - totalWidth / 2;
  let top = y - 50;

  if (left + totalWidth > window.innerWidth - safePadding) {
    left = window.innerWidth - totalWidth - safePadding;
  }
  if (left < safePadding) {
    left = safePadding;
  }
  if (top + totalHeight > window.innerHeight - bottomNavBarHeight - safePadding) {
    top = window.innerHeight - bottomNavBarHeight - totalHeight - safePadding;
  }
  if (top < appBarHeight + safePadding) {
    top = appBarHeight + safePadding;
  }

  const popup = document.createElement('div');
  popup.className = \`note-popup note-\${colorName}\`;
  popup.setAttribute('data-popup-id', noteGuid);

  const titleBar = document.createElement('div');
  titleBar.className = 'note-title-bar';

  const titleElement = document.createElement('input');
  titleElement.className = 'note-title-input';
  titleElement.type = 'text';
  titleElement.value = title;
  titleElement.placeholder = 'Titre de la note';

  const controlsContainer = document.createElement('div');
  controlsContainer.className = 'note-controls';

  const maximizeBtn = document.createElement('button');
  maximizeBtn.className = 'note-control-btn maximize-btn';
  maximizeBtn.innerHTML = '⛶';

  const closeBtn = document.createElement('button');
  closeBtn.className = 'note-control-btn close-btn';
  closeBtn.innerHTML = '✕';

  const contentElement = document.createElement('textarea');
  contentElement.className = 'note-content';
  contentElement.value = content;
  contentElement.placeholder = 'Écrivez votre note ici...';

  popup.style.cssText = \`
    position: fixed;
    left: \${Math.max(0, left)}px;
    top: \${Math.max(0, top)}px;
    width: \${totalWidth}px;
    height: \${totalHeight}px;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
    font-size: inherit;
    line-height: 1.5;
    z-index: 1000;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.2);
    backdrop-filter: blur(10px);
  \`;

  titleBar.style.cssText = \`
    display: flex;
    align-items: center;
    padding: 16px 20px 12px 20px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.08);
    background: rgba(255, 255, 255, 0.05);
    border-radius: 16px 16px 0 0;
    height: \${titleBarHeight}px;
    box-sizing: border-box;
  \`;

  titleElement.style.cssText = \`
    flex: 1;
    font-weight: 600;
    font-size: inherit;
    border: none;
    outline: none;
    background: transparent;
    color: inherit;
    padding: 0;
    margin: 0;
  \`;

  controlsContainer.style.cssText = \`
    display: flex;
    gap: 8px;
    margin-left: 16px;
  \`;

  [maximizeBtn, closeBtn].forEach(btn => {
    btn.style.cssText = \`
      width: 32px;
      height: 32px;
      border: none;
      background: rgba(0, 0, 0, 0.1);
      color: rgba(0, 0, 0, 0.6);
      cursor: pointer;
      font-size: 14px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
      font-weight: 500;
    \`;
  });

  maximizeBtn.addEventListener('mouseenter', () => {
    maximizeBtn.style.background = 'rgba(0, 0, 0, 0.15)';
    maximizeBtn.style.transform = 'scale(1.05)';
  });
  maximizeBtn.addEventListener('mouseleave', () => {
    maximizeBtn.style.background = 'rgba(0, 0, 0, 0.1)';
    maximizeBtn.style.transform = 'scale(1)';
  });

  closeBtn.addEventListener('mouseenter', () => {
    closeBtn.style.background = '#ff4757';
    closeBtn.style.color = 'white';
    closeBtn.style.transform = 'scale(1.05)';
  });
  closeBtn.addEventListener('mouseleave', () => {
    closeBtn.style.background = 'rgba(0, 0, 0, 0.1)';
    closeBtn.style.color = 'rgba(0, 0, 0, 0.6)';
    closeBtn.style.transform = 'scale(1)';
  });

  contentElement.style.cssText = \`
    border: none;
    outline: none;
    resize: none;
    font-size: inherit;
    line-height: 1.6;
    padding: 20px;
    background: transparent;
    color: inherit;
    overflow-y: auto;
    height: \${contentHeight}px;
    box-sizing: border-box;
  \`;

  const tagsContainer = document.createElement('div');
  tagsContainer.style.cssText = \`
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    gap: 8px;
    padding: 16px 20px 20px 20px;
    border-top: 1px solid rgba(0, 0, 0, 0.08);
    background: rgba(255, 255, 255, 0.03);
    border-radius: 0 0 16px 16px;
    height: \${tagsContainerHeight}px;
    overflow-y: auto;
    box-sizing: border-box;
    position: relative;
  \`;

  const tagStyle = \`
    background: rgba(255, 255, 255, 0.9);
    color: #2c3e50;
    padding: 7px 9px;
    border-radius: 20px;
    font-size: 14px;
    font-weight: 500;
    white-space: nowrap;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.3);
    backdrop-filter: blur(10px);
  \`;
  
  console.log('theUniqueTagsId', tagsId);

  const currentTagIds = !tagsId || tagsId === '' ? [] : tagsId.split(',').map(id => parseInt(id));
  currentTagIds.forEach(tagId => {
    const tag = tags.find(t => t.TagId === tagId);
    if (!tag) return;
    const tagElement = document.createElement('span');
    tagElement.textContent = tag.Name;
    tagElement.style.cssText = tagStyle;
    tagElement.addEventListener('click', () => {
      window.flutter_inappwebview.callHandler('openTagPage', {
        tagId: tag.TagId,
      });
    });
    tagElement.addEventListener('contextmenu', () => {
      tagsContainer.removeChild(tagElement);
      window.flutter_inappwebview.callHandler('removeTagToNote', {
        noteGuid: noteGuid,
        tagId: tag.TagId,
      });
    });
    tagsContainer.appendChild(tagElement);
  });

  const tagInputWrapper = document.createElement('div');
  tagInputWrapper.style.cssText = \`
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    flex-wrap: wrap;
  \`;

  const tagInput = document.createElement('input');
  tagInput.type = 'text';
  tagInput.style.cssText = \`
    display: none;
    flex: 1;
    min-width: 100px;
    border: none;
    padding: 4px;
    outline: none;
    font-size: 14px;
    background: transparent;
    color: inherit;
  \`;

  const addTagButton = document.createElement('button');
  addTagButton.textContent = '+';
  addTagButton.style.cssText = \`
    width: 32px;
    height: 32px;
    border-radius: 50%;
    border: none;
    background: rgba(255, 255, 255, 0.9);
    color: #2c3e50;
    font-size: 18px;
    font-weight: bold;
    cursor: pointer;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  \`;

  addTagButton.addEventListener('click', () => {
    tagInput.style.display = 'block';
    tagInput.focus();
  });

  const suggestionsList = document.createElement('div');
  suggestionsList.style.cssText = \`
    display: none;
    width: 100%;
    background: rgba(255, 255, 255, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 12px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
    max-height: 100px;
    overflow-y: auto;
    margin-top: 4px;
    backdrop-filter: blur(15px);
  \`;

  tagInput.addEventListener('input', () => {
    const value = tagInput.value.toLowerCase();
    suggestionsList.innerHTML = '';
    if (value === '') {
      suggestionsList.style.display = 'none';
      return;
    }
    const filtered = tags.filter(tag => tag.Name.toLowerCase().includes(value) && !currentTagIds.includes(tag.TagId));
    filtered.forEach((tag, index) => {
      const item = document.createElement('div');
      item.textContent = tag.Name;
      item.style.cssText = \`
        padding: 8px 12px; 
        cursor: pointer;
        font-size: 14px;
        color: #2c3e50;
        transition: background-color 0.2s ease;
        \${index === 0 ? 'border-radius: 12px 12px 0 0;' : ''}
        \${index === filtered.length - 1 ? 'border-radius: 0 0 12px 12px;' : ''}
      \`;
      item.addEventListener('mouseenter', () => {
        item.style.backgroundColor = 'rgba(52, 152, 219, 0.1)';
      });
      item.addEventListener('mouseleave', () => {
        item.style.backgroundColor = 'transparent';
      });
      item.addEventListener('click', () => {
        currentTagIds.push(tag.TagId);
        const tagElement = document.createElement('span');
        tagElement.textContent = tag.Name;
        tagElement.style.cssText = tagStyle;
        tagsContainer.insertBefore(tagElement, tagInputWrapper);
        tagInput.value = '';
        suggestionsList.innerHTML = '';
        suggestionsList.style.display = 'none';
        window.flutter_inappwebview.callHandler('addTagToNote', {
          noteGuid: noteGuid,
          tagId: tag.TagId
        });
      });
      suggestionsList.appendChild(item);
    });
    suggestionsList.style.display = filtered.length ? 'block' : 'none';
  });

  controlsContainer.appendChild(maximizeBtn);
  controlsContainer.appendChild(closeBtn);
  titleBar.appendChild(titleElement);
  titleBar.appendChild(controlsContainer);
  popup.appendChild(titleBar);
  popup.appendChild(contentElement);
  popup.appendChild(tagsContainer);

  tagInputWrapper.appendChild(addTagButton);
  tagInputWrapper.appendChild(tagInput);
  tagInputWrapper.appendChild(suggestionsList);
  tagsContainer.appendChild(tagInputWrapper);
  document.body.appendChild(popup);

  popup.style.transform = 'scale(0.9) translateY(20px)';
  popup.style.opacity = '0';
  popup.style.transition = 'all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)';
  setTimeout(() => {
    popup.style.transform = 'scale(1) translateY(0)';
    popup.style.opacity = '1';
  }, 10);
  setTimeout(() => {
    popup.style.transition = '';
  }, 300);

  closeBtn.addEventListener('click', () => {
    popup.style.transition = 'all 0.2s ease';
    popup.style.transform = 'scale(0.9)';
    popup.style.opacity = '0';
    setTimeout(() => {
      popup.remove();
    }, 200);
    window.flutter_inappwebview.callHandler('showDialog', false);
  });

  const saveChanges = () => {
    const title = titleElement.value;
    const content = contentElement.value;
    window.flutter_inappwebview.callHandler('updateNote', {
      noteGuid: noteGuid,
      title: title,
      content: content
    });
  };

  titleElement.addEventListener('input', saveChanges);
  contentElement.addEventListener('input', saveChanges);
}

          // Fonction utilitaire pour supprimer un surlignage spécifique par son UUID
          function removeHighlightByGuid(guid) {
            const highlightedElements = document.querySelectorAll(`[data-highlight-id="\${guid}"]`);
            highlightedElements.forEach(element => {
              // Supprimer toutes les classes de surlignage
              element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
              // Supprimer l'attribut UUID
              element.removeAttribute('data-highlight-id');
            });
            window.flutter_inappwebview.callHandler('removeHighlight', {
              guid: guid
            });
          }
    
          // Fonction utilitaire pour changer la couleur d'un surlignage spécifique
          function changeHighlightColor(guid, newColorIndex) {
            const highlightedElements = pageCenter.querySelectorAll(`[data-highlight-id="\${guid}"]`);
            const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][newColorIndex]}`;
            
            highlightedElements.forEach(element => {
              // Supprimer toutes les classes de surlignage existantes
              element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
              // Ajouter la nouvelle classe de couleur
              element.classList.add(newHighlightClass);
            });
            window.flutter_inappwebview.callHandler('changeHighlightColor', {
              guid: guid,
              newColorIndex: newColorIndex
            });
          }
          
          function resizeFont(size) {
            document.body.style.fontSize = size + 'px';
            repositionAllNotes();
            repositionAllBookmarks();
          }
          
          function setLongPressing(value) {
            isLongPressing = value;
            if (isLongPressing) {
              pageCenter.style.overflow = 'hidden'; // bloque le scroll
            } else {
              pageCenter.style.overflow = 'auto'; // rétablit le scroll
            }
          }
          
          let isTouchDragging = false;
          let dragTouchOffsetY = 0;

          document.addEventListener("touchmove", (e) => {
            if (!isTouchDragging) return;
          
            const touchY = e.touches[0].clientY;
            const newTop = touchY - dragTouchOffsetY;
          
            const visibleHeight = window.innerHeight - 110; // 90 top + 90 bottom
            const minTop = 90;
            const maxTop = 90 + (visibleHeight - scrollBar.offsetHeight); // position max réelle
          
            const clampedTop = Math.max(minTop, Math.min(newTop, maxTop));
            scrollBar.style.top = `\${clampedTop}px`;
          
            const scrollRatio = (clampedTop - 90) / (visibleHeight - scrollBar.offsetHeight);
            const scrollableHeight = pageCenter.scrollHeight - pageCenter.clientHeight;
          
            pageCenter.scrollTop = scrollRatio * scrollableHeight;
          
            e.preventDefault();
          }, { passive: false });
          
          document.addEventListener("touchend", () => {
            isTouchDragging = false;
          });
          
          document.addEventListener("touchcancel", () => {
            isTouchDragging = false;
          });
          
          async function init() {
            // Masquer le contenu avant le chargement
            pageCenter.classList.remove('visible');
            await loadIndexPage(currentIndex);
            pageCenter.scrollTop = 0;
            pageCenter.scrollLeft = 0;
            
            scrollBar = document.createElement('img');
            scrollBar.className = 'scroll-bar';
            scrollBar.src = speedBarScroll;
            scrollBar.addEventListener("touchstart", (e) => {
              if (e.touches.length !== 1) return;
              isTouchDragging = true;
            
              const touchY = e.touches[0].clientY;
              dragTouchOffsetY = touchY - scrollBar.getBoundingClientRect().top;
            
              e.preventDefault(); // bloque le scroll natif
            }, { passive: false });
          
            document.body.appendChild(scrollBar);
            
            await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
          
            await document.fonts.ready;
            loadUserdata();
      
            if($startParagraphId != null && $endParagraphId != null) {
              jumpToIdSelector('[data-pid]', 'data-pid', $startParagraphId, $endParagraphId);
            }
            else if($startVerseId != null && $endVerseId != null) {
              jumpToIdSelector('.v', 'id', $startVerseId, $endVerseId);
            }
            
            if(${wordsSelected.isNotEmpty}) {
              selectWords(${jsonEncode(widget.wordsSelected)});
            }
           
            // Double RAF pour garantir le rendu complet avant le fondu
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                repositionAllNotes();
                repositionAllBookmarks();
                pageCenter.classList.add('visible'); // Lancer le fondu
                window.flutter_inappwebview.callHandler('fontsLoaded');
              });
            });
  
            await loadPrevAndNextPages(currentIndex);
          }
          
          init();
          
          pageCenter.addEventListener("scroll", () => {
            if (isLongPressing || isChangingParagraph) return;
          
            const scrollTop = pageCenter.scrollTop;
            const scrollHeight = pageCenter.scrollHeight;
            const clientHeight = pageCenter.clientHeight;
          
            const scrollDirection = scrollTop > lastScrollTop ? "down" : scrollTop < lastScrollTop ? "up" : "none";
            lastScrollTop = scrollTop;
            
            if(scrollDirection == 'down') {
              appBarHeight = 0;    // hauteur de l'AppBar
              bottomNavBarHeight = 0; // hauteur de la BottomBar
            }
            else {
              appBarHeight = 90;    // hauteur de l'AppBar
              bottomNavBarHeight = 55; // hauteur de la BottomBar
            }
          
            scrollTopPages[currentIndex] = scrollTop;
            window.flutter_inappwebview.callHandler('onScroll', scrollTop, scrollDirection);
          
            // Mise à jour position de la scroll-bar
            const scrollableHeight = scrollHeight - clientHeight;
            const visibleHeight = window.innerHeight - bottomNavBarHeight - 90;
            const scrollRatio = scrollTop / scrollableHeight;
          
            const scrollBarTop = 90 + (visibleHeight - scrollBar.offsetHeight) * scrollRatio;
            scrollBar.style.top = `\${scrollBarTop}px`; // attention : backticks, pas échappé
          });
          
          // Variables globales pour éviter les redéclarations
          let currentGuid = '';
          let currentTempHighlight = null;
          let tempHighlightElements = []; 
          let pressTimer = null;
          let firstLongPressTarget = null;
          let lastLongPressTarget = null;
          let isLongPressing = false;
          let isLongTouchFix = false;
          let isDragging = false;
          let isVerticalScroll = false;
          let startX = 0;
          let startY = 0;
          let currentTranslate = -100;
          
          // Cache pour les sélecteurs fréquents
          const selectorCache = new Map();
          const getFromCache = (selector, parent = document) => {
            const key = `\${selector}-\${parent === document ? 'doc' : 'elem'}`;
            if (!selectorCache.has(key)) {
              selectorCache.set(key, parent.querySelector(selector));
            }
            return selectorCache.get(key);
          };
          
          // Debounce pour les événements fréquents
          const debounce = (func, wait) => {
            let timeout;
            return function executedFunction(...args) {
              const later = () => {
                clearTimeout(timeout);
                func(...args);
              };
              clearTimeout(timeout);
              timeout = setTimeout(later, wait);
            };
          };
          
          // Throttle pour les événements de mouvement
          const throttle = (func, limit) => {
            let inThrottle;
            return function() {
              const args = arguments;
              const context = this;
              if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
              }
            }
          };
          
          // Optimisation des classes CSS avec un Set pour éviter les répétitions
          const highlightClasses = new Set([
            'highlight-transparent', 'highlight-yellow', 'highlight-green', 
            'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple'
          ]);
          
          // Gestionnaire d'événements click optimisé
          pageCenter.addEventListener('click', (event) => {
            const target = event.target;
            const tagName = target.tagName;
            
            // Early returns pour les cas simples
            if (tagName === 'TEXTAREA' || tagName === 'INPUT') {
              closeToolbar();
              return;
            }
          
            if (tagName === 'IMG') {
              window.flutter_inappwebview.callHandler('onImageClick', target.src);
              closeToolbar();
              return;
            }
          
            // Utilisation de classList.contains avec cache
            const classList = target.classList;
            
            if (classList.contains('fn')) {
              const fnid = target.getAttribute('data-fnid');
              window.flutter_inappwebview.callHandler('fetchFootnote', fnid);
              closeToolbar();
              return;
            }
          
            if (classList.contains('m')) {
              const mid = target.getAttribute('data-mid');
              window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
              closeToolbar();
              return;
            }
            
            // Optimisation de closest() avec cache
            const matchedElement = target.closest('a');
            if (matchedElement || classList.contains('gen-field')) {
              closeToolbar();
              return;
            }
            
            const highlightId = target.getAttribute('data-highlight-id');
            if (classList.contains('selected')) {
              const selectedElement = getFromCache('.selected', pageCenter);
              showToolbarHighlight(selectedElement, highlightId);
              return;
            }
            else if (highlightId) {
              const highlightElement = pageCenter.querySelector(`[data-highlight-id="\${highlightId}"]`);
              showToolbarHighlight(highlightElement, highlightId);
              return;
            }
            
            // Optimisation de la logique conditionnelle
            if (isBible()) {
              whenClickOnParagraph(target, '.v', 'id', 'verse');
            } else {
              whenClickOnParagraph(target, '[data-pid]', 'data-pid', 'paragraph');
            }
          }, { passive: true });
          
          // Gestionnaire touchstart optimisé
          pageCenter.addEventListener('touchstart', async (event) => {
            // Utilisation de clearTimeout avant setTimeout pour éviter les fuites
            if (pressTimer) clearTimeout(pressTimer);
            
            pressTimer = setTimeout(async () => {
              firstLongPressTarget = event.target;
              currentGuid = '';
              
              const firstTargetClassList = firstLongPressTarget?.classList;
              if (firstTargetClassList && (firstTargetClassList.contains('word') || firstTargetClassList.contains('punctuation'))) {
                try {
                  const uuid = await window.flutter_inappwebview.callHandler('getHighlightGuid');
                  currentGuid = uuid.guid;
                  
                  setLongPressing(true);
                  isLongTouchFix = true;
                  tempHighlightElements.length = 0; // Plus rapide que = []
                } 
                catch (error) {
                  console.error('Error getting highlight GUID:', error);
                }
              }
            }, 250);
          }, { passive: true });
          
          // Gestionnaire touchmove optimisé avec throttle
          const handleTouchMove = throttle((event) => {
            isLongTouchFix = false;
            
            if (isLongPressing && currentGuid) {
              const touch = event.changedTouches[0];
              const x = touch.clientX;
              const y = touch.clientY;
              
              updateMagnifier(x, y);
                
              const closestElement = getClosestElementHorizontally(x, y);
              const elementClassList = closestElement?.classList;
                
              if (elementClassList && (elementClassList.contains('word') || elementClassList.contains('punctuation'))) {
                if(closestElement !== lastLongPressTarget) {
                  lastLongPressTarget = closestElement;
                  updateTempHighlight();
                }
              }
            } 
            else if (pressTimer) {
              clearTimeout(pressTimer);
              pressTimer = null;
            }
          }, 16); // ~60fps
          
          pageCenter.addEventListener('touchmove', handleTouchMove, { passive: true });
          
          // Gestionnaire touchend optimisé
          pageCenter.addEventListener('touchend', (event) => {
            if (pressTimer) {
              clearTimeout(pressTimer);
              pressTimer = null;
            }
            
            if (isLongPressing) {
              hideMagnifier();
              onLongPressEnd();
            }
            isLongTouchFix = false;
          }, { passive: true });
          
          function getClosestElementHorizontally(x, y) {
            const allElements = pageCenter.querySelectorAll('.word, .punctuation');
            let closest = null;
            let minDistance = Infinity;
          
            for (const el of allElements) {
              const rect = el.getBoundingClientRect();
          
              // Vérifie que l'élément est visible et à la même hauteur approximative (par ex. sur la même ligne)
              if (rect.height === 0 || rect.width === 0) continue;
              if (y >= rect.top && y <= rect.bottom) {
                // Calcule la distance horizontale par rapport à `x`
                const elCenterX = rect.left + rect.width / 2;
                const distance = Math.abs(x - elCenterX);
          
                if (distance < minDistance) {
                  minDistance = distance;
                  closest = el;
                }
              }
            }
          
            return closest;
          }
  
          const paragraphTokensMap = new Map();
          function updateTempHighlight() {
            if (!firstLongPressTarget || !lastLongPressTarget) return;
          
            const firstParagraphInfo = getTheFirstTargetParagraph(firstLongPressTarget);
            const lastParagraphInfo = getTheFirstTargetParagraph(lastLongPressTarget);
            if (!firstParagraphInfo || !lastParagraphInfo) return;
          
            const firstParagraph = firstParagraphInfo.paragraph;
            const lastParagraph = lastParagraphInfo.paragraph;
          
            const paragraphs = getAllParagraphs();
          
            const firstIndex = paragraphs.indexOf(firstParagraph);
            const lastIndex = paragraphs.indexOf(lastParagraph);
            if (firstIndex === -1 || lastIndex === -1) return;
          
            const fromIndex = Math.min(firstIndex, lastIndex);
            const toIndex = Math.max(firstIndex, lastIndex);
          
            // 🔄 Inverser les cibles si nécessaire
            const startTarget = firstIndex <= lastIndex ? firstLongPressTarget : lastLongPressTarget;
            const endTarget   = firstIndex <= lastIndex ? lastLongPressTarget  : firstLongPressTarget;
          
            // Nettoyer l'ancien surlignage
            removeTempHighlight();
          
            // Cache des tokens
            paragraphTokensMap.clear();
            for (let i = fromIndex; i <= toIndex; i++) {
              const paragraph = paragraphs[i];
              const tokens = Array.from(paragraph.querySelectorAll('.word, .punctuation'));
              paragraphTokensMap.set(paragraph, tokens);
            }
          
            const highlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
          
            requestAnimationFrame(() => {
              for (let i = fromIndex; i <= toIndex; i++) {
                const paragraph = paragraphs[i];
          
                const allTokens = Array.from(paragraph.querySelectorAll('.word, .punctuation, .escape'));
                const wordAndPunctTokens = allTokens.filter(token =>
                  token.classList.contains('word') || token.classList.contains('punctuation')
                );
          
                let startTokenIndex = 0;
                let endTokenIndex = wordAndPunctTokens.length - 1;
          
                if (paragraph.contains(startTarget) && paragraph.contains(endTarget)) {
                  const a = wordAndPunctTokens.indexOf(startTarget);
                  const b = wordAndPunctTokens.indexOf(endTarget);
                  if (a === -1 || b === -1) continue;
                  startTokenIndex = Math.min(a, b);
                  endTokenIndex = Math.max(a, b);
                } else if (paragraph.contains(startTarget)) {
                  const index = wordAndPunctTokens.indexOf(startTarget);
                  if (index === -1) continue;
                  startTokenIndex = index;
                } else if (paragraph.contains(endTarget)) {
                  const index = wordAndPunctTokens.indexOf(endTarget);
                  if (index === -1) continue;
                  endTokenIndex = index;
                }
          
                for (let j = startTokenIndex; j <= endTokenIndex; j++) {
                  const token = wordAndPunctTokens[j];
                  if (!token.hasAttribute('data-highlight-id')) {
                    token.classList.add(highlightClass);
                    token.setAttribute('data-highlight-id', currentGuid);
                    tempHighlightElements.push(token);
                  }
          
                  const tokenIndexInAll = allTokens.indexOf(token);
                  const next = allTokens[tokenIndexInAll + 1];
                  if (next?.classList.contains('escape') && j !== endTokenIndex) {
                    if (!next.hasAttribute('data-highlight-id')) {
                      next.classList.add(highlightClass);
                      next.setAttribute('data-highlight-id', currentGuid);
                      tempHighlightElements.push(next);
                    }
                  }
                }
              }
            });
          
            currentTempHighlight = true;
          }
          
          // Fonction removeTempHighlight optimisée
          function removeTempHighlight() {
            // Supprimer seulement les éléments temporaires qu'on a tracés
            tempHighlightElements.forEach(element => {
              element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
              element.removeAttribute('data-highlight-id');
            });
          
            tempHighlightElements = [];
            currentTempHighlight = null;
          }
          
          // Fonction onLongPressEnd optimisée avec gestion d'erreurs et cache tokens
          async function onLongPressEnd() {
            const firstTarget = firstLongPressTarget;
            const lastTarget = lastLongPressTarget;
          
            if (isLongTouchFix) {
              removeAllSelected();
              closeToolbar();
              firstTarget.classList.add('selected');
              firstTarget.setAttribute('data-highlight-id', currentGuid);
              showToolbarHighlight(firstTarget, currentGuid);
            }
            else {
              let currentParagraph = null;
              let currentParagraphId = -1;
              let currentIsVerse = false;
              let firstTarget = null;
              let lastTarget = null;
              
              const highlightsToSend = [];
              
              showToolbarHighlight(tempHighlightElements[0], currentGuid);
              
              for (let i = 0; i < tempHighlightElements.length; i++) {
                const element = tempHighlightElements[i];
                const { id, paragraph, isVerse } = getTheFirstTargetParagraph(element);
              
                if (id !== currentParagraphId) {
                  // S'il y avait un paragraphe précédent, on sauvegarde le highlight
                  if (firstTarget && lastTarget) {
                    addHighlightForParagraph(firstTarget, lastTarget, currentParagraph, currentParagraphId, currentIsVerse);
                  }
              
                  // On commence un nouveau paragraphe
                  currentParagraph = paragraph;
                  currentParagraphId = id;
                  currentIsVerse = isVerse;
                  firstTarget = element;
                  lastTarget = element;
                } 
                else {
                  // Même paragraphe, on met à jour la fin
                  lastTarget = element;
                }
              }
              
              // Enregistrer le dernier paragraphe
              if (firstTarget && lastTarget) {
                addHighlightForParagraph(firstTarget, lastTarget, currentParagraph, currentParagraphId, currentIsVerse);
              }
              
              // Fonction de préparation des highlights
              function addHighlightForParagraph(firstElement, lastElement, paragraph, paragraphId, isVerse) {
                const wordAndPunctTokens = Array.from(paragraph.querySelectorAll('.word, .punctuation'));
                const normalizedStartToken = wordAndPunctTokens.indexOf(firstElement);
                const normalizedEndToken = wordAndPunctTokens.indexOf(lastElement);
              
                highlightsToSend.push({
                  blockType: isVerse ? 2 : 1,
                  identifier: paragraphId,
                  startToken: normalizedStartToken,
                  endToken: normalizedEndToken,
                });
              }
              
              // Appel unique à Flutter pour tous les highlights
              await window.flutter_inappwebview.callHandler('addHighlights', highlightsToSend, highlightColorIndex, currentGuid);
            }
          }
          
          function updateMagnifier(x, y) {
            // Position de la loupe (120x50px)
            const magnifierWidth = 120;
            const magnifierHeight = 50;
            const offsetX = x - magnifierWidth / 2;
            const offsetY = y - magnifierHeight - 30; // Au-dessus du doigt

            magnifier.style.left = `\${offsetX}px`;
            magnifier.style.top = `\${offsetY}px`;
            magnifier.style.display = 'block';
            
            // Calculer la position relative dans la page
            //const pageRect = pageCenter.getBoundingClientRect();
            //const relativeX = x - pageRect.left;
            //const relativeY = y - pageRect.top;

            // Positionner le contenu pour montrer exactement ce qui est sous le doigt
            //const centerX = magnifierWidth / 2;
            //const centerY = magnifierHeight / 2;
            
            //magnifierContent.style.left = `\${centerX - relativeX}px`;
            //magnifierContent.style.top = `\${centerY - relativeY}px`;
        }
          
          function hideMagnifier() {
            magnifier.style.display = 'none';
          }
          
          // Fonction getTheFirstTargetParagraph optimisée avec cache
          const paragraphCache = new WeakMap();
          function getTheFirstTargetParagraph(target) {
            if (paragraphCache.has(target)) {
              return paragraphCache.get(target);
            }
            
            let result = null;
            
            // Recherche optimisée
            const verse = target.closest('.v[id]');
            if (verse) {
              result = {
                paragraph: verse,
                id: verse.id.split('-')[2],
                isVerse: true
              };
            } 
            else {
              const paragraph = target.closest('[data-pid]');
              if (paragraph) {
                result = {
                  paragraph: paragraph,
                  id: paragraph.getAttribute('data-pid'),
                  isVerse: false
                };
              }
            }
            
            if (result) {
              paragraphCache.set(target, result);
            }
            
            return result;
          }
          
          function getAllParagraphs() {
            const finalList = [];
          
            // Ajouter d'abord tous les versets
            const verses = pageCenter.querySelectorAll('.v[id]');
            verses.forEach(verse => {
              const id = verse.id.split('-')[2];
              finalList.push(verse);
            });
          
            if(verses.length === 0) {
              // Ajouter les paragraphes uniquement si aucun verset ne les couvre
              const paragraphs = pageCenter.querySelectorAll('[data-pid]');
              paragraphs.forEach(paragraph => {
                finalList.push(paragraph);
              });
            }
          
            return finalList;
          }
          
          // Gestionnaires d'événements pour le conteneur optimisés
          container.addEventListener('touchstart', (e) => {
            closeToolbar();
            if (isLongPressing) return;
            
            startX = e.touches[0].clientX;
            startY = e.touches[0].clientY;
            isDragging = true;
            isVerticalScroll = false;
          
            container.style.transition = "none";
          }, { passive: true });
          
          // Gestionnaire touchmove pour le conteneur avec throttle
          const handleContainerTouchMove = throttle((e) => {
            if (isLongPressing || !isDragging) return;
            
            const x = e.touches[0].clientX;
            const y = e.touches[0].clientY;
            const dx = x - startX;
            const dy = y - startY;
          
            if (!isVerticalScroll && Math.abs(dy) > Math.abs(dx)) {
              isVerticalScroll = true;
            }
          
            if (!isVerticalScroll) {
              const percentage = dx / window.innerWidth * 100;
              const newTransform = (currentIndex === 0 && dx > 0) || (currentIndex === maxIndex && dx < 0) 
                ? currentTranslate 
                : currentTranslate + percentage;
              
              container.style.transform = `translateX(\${newTransform}%)`;
            }
          }, 16);
          
          container.addEventListener('touchmove', handleContainerTouchMove, { passive: true });
          
          // Gestionnaire touchend pour le conteneur optimisé
          container.addEventListener('touchend', async (e) => {
            isLongTouchFix = false;
            
            if (isLongPressing) {
              setLongPressing(false);
              return;
            }
          
            if (!isDragging) return;
            isDragging = false;
          
            if (isVerticalScroll) {
              container.style.transition = "transform 0.3s ease-in-out";
              container.style.transform = `translateX(\${currentTranslate}%)`;
              return;
            }
          
            const dx = e.changedTouches[0].clientX - startX;
            const percentage = dx / window.innerWidth;
            container.style.transition = "transform 0.3s ease-in-out";
          
            try {
              if (percentage < -0.15 && currentIndex < maxIndex) {
                currentTranslate = -200;
                container.style.transform = "translateX(-200%)";
                setTimeout(async () => {
                  currentIndex++;
                  currentTranslate = -100;
                  await loadPages(currentIndex);
                }, 300);
              } else if (percentage > 0.15 && currentIndex > 0) {
                currentTranslate = 0;
                container.style.transform = "translateX(0%)";
                setTimeout(async () => {
                  currentIndex--;
                  currentTranslate = -100;
                  await loadPages(currentIndex);
                }, 300);
              } else {
                container.style.transform = "translateX(-100%)";
              }
            } catch (error) {
              console.error('Error in touch end handler:', error);
            }
          }, { passive: true });
        </script>
      </body>
    </html>
''';
  }


  Document getCurrentDocument() => documents[documentIndex];

  Document getPreviousDocument() => documents[documentIndex - 1];

  Document getNextDocument() => documents[documentIndex + 1];

  Document getDocumentAt(int index) => documents[index];

  Document getDocumentFromMepsDocumentId(int mepsDocumentId) {
    return documents.firstWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }

  int getIndexFromMepsDocumentId(int mepsDocumentId) {
    return documents.indexWhere((element) => element.mepsDocumentId == mepsDocumentId);
  }
}