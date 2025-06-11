import 'dart:convert';

import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../../app/jwlife_app.dart';
import '../../../../../../core/utils/utils_jwpub.dart';
import '../../../../../../core/utils/webview_data.dart';

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
      database = await openDatabase(publication.databasePath);
      await fetchDocuments();
    }
    catch (e) {
      print('Error initializing database: $e');
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
      print('Error fetching all documents: $e');
    }
  }

  String createReaderHtmlShell() {
    final webViewData = JwLifeApp.settings.webViewData;
    final fontSize = webViewData.fontSize;
    final backgroundColor = webViewData.backgroundColor;
    final colorIndex = webViewData.colorIndex;
    bool isDarkMode = webViewData.theme == 'cc-theme--dark';

    String wordSelectingColor = isDarkMode ? '#215457' : '#c5f8fa';
    String highlightYellowColor = isDarkMode ? '#86761d' : '#fff9bb';
    String highlightGreenColor = isDarkMode ? '#4a6831' : '#dbf2c8';
    String highlightBlueColor = isDarkMode ? '#3a6381' : '#cbecff';
    String highlightPurpleColor = isDarkMode ? '#524169' : '#e0d3ef';
    String highlightPinkColor = isDarkMode ? '#783750' : '#facbdd';
    String highlightOrangeColor = isDarkMode ? '#894c1f' : '#ffddc4';

    String searchColor = isDarkMode ? '#d09828' : '#ffc757';

    String theme = isDarkMode ? 'dark' : 'light';

    return '''
<!DOCTYPE html>
<html style="overflow-x: hidden; height: 100%;">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
    <link rel="stylesheet" href="jw-styles.css" />
    <style>
      body {
        user-select: none;
        font-size: ${fontSize}px;
        background-color: $backgroundColor;
        margin: 0;
        overflow: hidden;
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
     
        .word.selected {
            background-color: $wordSelectingColor;
        }
        
        .word.searched {
            background-color: $searchColor;
        }
        
        .punctuation.selected {
            background-color: $wordSelectingColor;
        }
        
        .highlight-transparent { background-color: transparent; }
        .highlight-yellow    { background-color: $highlightYellowColor; }
        .highlight-green     { background-color: $highlightGreenColor; }
        .highlight-blue      { background-color: $highlightBlueColor; }
        .highlight-pink      { background-color: $highlightPinkColor; }
        .highlight-orange    { background-color: $highlightOrangeColor; }
        .highlight-purple    { background-color: $highlightPurpleColor; }


    </style>
  </head>
  <body class="${webViewData.theme}">
    <div id="container">
      <div id="page-left" class="page"></div>
      <div id="page-center" class="page"></div>
      <div id="page-right" class="page"></div>
    </div>

    <script>
      let currentIndex = $documentIndex;
      let container = document.getElementById("container");
      let cachedPages = {};
      let highlightColorIndex = $colorIndex;
      const bookmarkAssets = Array.from({ length: 10 }, (_, i) => `bookmarks/$theme/bookmark\${i + 1}.png`);
      const highlightAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}.png`);
      const highlightSelectedAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}.png`);

      const maxIndex = ${documents.length - 1};

      async function fetchPage(index) {
        if (index < 0 || index > maxIndex) return { html: "", className: "" };
        if (cachedPages[index]) return cachedPages[index];
        const page = await window.flutter_inappwebview.callHandler('getPage', index);
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
            playButton.innerHTML = "&#xE69D;";
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
    let wordIndex = 0;
    let punctuationIndex = 0;
    let escapeIndex = 0;
    
    function walkNodes(node) {
        if (node.nodeType === Node.TEXT_NODE) {
            const text = node.textContent;
            if (text.trim()) {
                const newHTML = processText(text, wordIndex, punctuationIndex, escapeIndex);
                
                const temp = document.createElement('div');
                temp.innerHTML = newHTML.html;
                
                const parent = node.parentNode;
                while (temp.firstChild) {
                    parent.insertBefore(temp.firstChild, node);
                }
                parent.removeChild(node);
                
                wordIndex = newHTML.wordIndex;
                punctuationIndex = newHTML.punctuationIndex;
                escapeIndex = newHTML.escapeIndex;
            }
        } 
        else if (node.nodeType === Node.ELEMENT_NODE) {
          // Skip elements with 'fn' or 'm' classes
          if (node.classList && (node.classList.contains('fn') || node.classList.contains('m') || node.classList.contains('parNum'))) {
              return;
          }
          const children = Array.from(node.childNodes);
          children.forEach(child => walkNodes(child));
        }
    }
    
    walkNodes(element);
}

function processText(text, startWordIndex, startPunctuationIndex, startEscapeIndex) {
    let html = '';
    let wordIndex = startWordIndex;
    let punctuationIndex = startPunctuationIndex;
    let escapeIndex = startEscapeIndex;
    
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
            html += `<span id="\${escapeIndex}" class="escape">\${spaceSequence}</span>`;
            escapeIndex++;
        }
        else if (isLetter(currentChar) || isDigit(currentChar)) {
            // C'est le début d'un mot (incluant la ponctuation intégrée)
            let word = '';
            while (i < text.length && !isSpace(text[i]) && !isStandalonePunctuation(text, i)) {
                word += text[i];
                i++;
            }
            html += `<span id="\${wordIndex}" class="word">\${word}</span>`;
            wordIndex++;
        }
        else {
            // C'est de la ponctuation standalone
            html += `<span id="\${punctuationIndex}" class="punctuation">\${currentChar}</span>`;
            punctuationIndex++;
            i++;
        }
    }
    
    return {
        html: html,
        wordIndex: wordIndex,
        punctuationIndex: punctuationIndex,
        escapeIndex: escapeIndex
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
    
    // Vérifier si c'est de la ponctuation qui fait partie d'un mot
    const prevChar = index > 0 ? text[index - 1] : '';
    const nextChar = index < text.length - 1 ? text[index + 1] : '';
    
    // Cas spéciaux pour l'apostrophe et autres signes intégrés aux mots
    if (char === "’" || char === '/' || char === '\' || char === "'" || char === '-' || char === '–' || char === '—') {
        // Si il y a une lettre avant ET après, c'est intégré au mot
        if (isLetter(prevChar) && isLetter(nextChar)) {
            return false;
        }
    }
    
    // Autres cas de ponctuation intégrée (comme les points dans les nombres)
    if ((char === ':' || char === '.' || char === '-') && isDigit(prevChar) && isDigit(nextChar)) {
        return false;
    }
    
    // Sinon, c'est de la ponctuation standalone
    return true;
}
      
      function adjustHeight(element) {
          element.style.height = 'auto';
          element.style.height = (element.scrollHeight+4) + 'px';
      }

      async function loadPages(index) {
        const curr = await fetchPage(index);
        document.getElementById("page-center").innerHTML = `<article id="article-center" class="\${curr.className}">\${curr.html}</article>`;
        adjustArticle('article-center');
        addVideoCover('article-center');
        wrapWordsWithSpan('article-center');

        const prev = await fetchPage(index - 1);
        const next = await fetchPage(index + 1);

        document.getElementById("page-left").innerHTML = `<article id="article-left" class="\${prev.className}">\${prev.html}</article>`;
        document.getElementById("page-right").innerHTML = `<article id="article-right" class="\${next.className}">\${next.html}</article>`;

        adjustArticle('article-left');
        addVideoCover('article-left');
        adjustArticle('article-right');
        addVideoCover('article-right');

        container.style.transition = "none";
        container.style.transform = "translateX(-100%)";
        void container.offsetWidth;
        container.style.transition = "transform 0.3s ease-in-out";
      }
      
      async function jumpToPage(index) {
        closeToolbar();
        if (index < 0 || index > maxIndex) return;

        currentIndex = index;
        await loadPages(index);
      }
      
      function jumpToIdSelector(selector, idAttr, begin, end) {
        closeToolbar();
        
        const paragraphs = pageCenter.querySelectorAll(selector);
        let targetParagraph = null;
        
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
          const paragraphTop = targetParagraph.offsetTop;
          const elementHeight = targetParagraph.offsetHeight;
          const screenHeight = pageCenter.clientHeight;

          let scrollToY;

          if (elementHeight < screenHeight) {
            // Centrer l'élément
            scrollToY = paragraphTop - (screenHeight / 2) + (elementHeight / 2);
          } else {
            // Afficher le haut de l'élément
            scrollToY = paragraphTop;
          }

          pageCenter.scrollTop = scrollToY;
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
            if (words.some(searchWord => searchWord.toLowerCase() === wordText)) {
                element.classList.add('searched');
            }
        });
      }

      loadPages(currentIndex);
      
      function isBible() {
        // Vérifie si le contenu contient la classe "bible"
        const article = pageCenter?.querySelector('#article-center');
        if (!article) {
          return false; // Retourne false si l'élément n'existe pas
        }
  
        return article.classList.contains('bible');
      }

      // Scroll vertical
      const pageCenter = document.getElementById("page-center");
      let lastScrollTop = 0;
 
      function restoreOpacity() {
        selector = isBible() ? '.v' : '[data-pid]';
        pageCenter.querySelectorAll(selector).forEach(e => e.style.opacity = '1');
      }

      function dimOthers(currents, selector) {
        pageCenter.querySelectorAll(selector).forEach(e => {
          if (!currents.includes(e)) {
            e.style.opacity = '0.5';
          }
        });
      }
      
      function createToolbarButton(icon, onClick) {
        const button = document.createElement('button');
        button.innerHTML = icon;
        button.style.cssText = \`
          font-family: jw-icons-external;
          font-size: 26px;
          padding: 3px;
          border-radius: 5px;
          margin: 0 7px;
          color: \${${webViewData.theme == 'cc-theme--dark'} ? 'white' : '#4f4f4f'};
        \`;
        button.addEventListener('click', onClick);
        return button;
      }
      
      function createToolbarButtonColor(paragraphs, type) {
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
  `;

  // Créer la toolbar de couleurs
  function createColorToolbar(paragraphs, type) {
    const paragraph = paragraphs[0];
    const colorToolbar = document.createElement('div');
    colorToolbar.classList.add('toolbar-colors');
    colorToolbar.style.cssText = `
      position: absolute;
      top: \${paragraph.getBoundingClientRect().top + window.scrollY - 90}px;
      left: \${(type === 'paragraph') ? '90px' : '50px'};
      background-color: \${${webViewData.theme == 'cc-theme--dark'} ? '#424242' : '#ffffff'};
      padding: 1px;
      border-radius: 6px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
      white-space: nowrap;
      display: flex;
      opacity: 0;
      transition: opacity 0.1s ease;
    `;

    // Créer un bouton pour chaque couleur
    highlightAssets.forEach((assetPath, index) => {
      const colorButton = document.createElement('button');
      const colorImg = document.createElement('img');
      
      colorImg.src = assetPath;
      colorImg.style.cssText = `
        width: 24px;
        height: 24px;
        display: block;
      `;
      
      colorButton.appendChild(colorImg);
      colorButton.style.cssText = `
        padding: 3px;
        border-radius: 5px;
        margin: 0 7px;
      `;

      // Ajouter l'événement de clic pour chaque couleur
      colorButton.addEventListener('click', (e) => {
        e.stopPropagation();
        highlightColorIndex = index+1;
        changeHighlightColor(paragraph.getAttribute('data-highlight-id'), highlightColorIndex);
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
    
    // Vérifier s'il y a déjà une toolbar-colors ouverte
    const existingColorToolbar = document.querySelector('.toolbar-colors');
    if (existingColorToolbar) {
      existingColorToolbar.remove();
      return;
    }

    // Créer et afficher la toolbar de couleurs
    const colorToolbar = createColorToolbar(paragraphs, type);
    document.body.appendChild(colorToolbar);

    // Afficher avec animation
    setTimeout(() => {
      colorToolbar.style.opacity = '1';
    }, 10);

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
        restoreOpacity();
        const toolbar = document.querySelector('.toolbar');
        if (toolbar) toolbar.remove();
      }

      function removeAllSelected() {
        pageCenter.querySelectorAll('.selected').forEach(elem => {
          elem.classList.remove('selected');
        });
      }

      function showToolbar(paragraphs, id, selector, isHighlighted, hasAudio, type) {
        const paragraph = paragraphs[0];
        const isSelected = paragraph.classList.contains('selected');
        restoreOpacity();
        const existingToolbar = document.querySelector('.toolbar');
        if (existingToolbar && paragraph) {
          existingToolbar.style.opacity = '0';
          setTimeout(() => existingToolbar.remove(), 300);
          if (existingToolbar.getAttribute('data-id') === id) return;
        }
       

        if(!isHighlighted) {
          dimOthers(paragraphs, selector);
        }
  
        const toolbar = document.createElement('div');
        toolbar.classList.add('toolbar');
        toolbar.setAttribute('data-id', id);
        toolbar.style.cssText = \`
          position: absolute;
          top: \${paragraph.getBoundingClientRect().top + window.scrollY - 50}px;
          left: \${(type === 'paragraph') ? '90px' : '50px'};
          background-color: \${${webViewData.theme == 'cc-theme--dark'} ? '#424242' : '#ffffff'};
          padding: 1px;
          border-radius: 6px;
          box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
          white-space: nowrap;
          display: flex;
          opacity: 0;
          transition: opacity 0.1s ease;
        \`;

        document.body.appendChild(toolbar);
        setTimeout(() => toolbar.style.opacity = '1', 10);

        let buttons = [];

        if (isHighlighted) {
          toolbar.appendChild(createToolbarButtonColor(paragraphs, type));
          buttons = [
            ['&#xE688;', () => {}],
            ...(!isSelected ? [['&#xE6DD;', () => removeHighlight(paragraph.getAttribute('data-highlight-id'))]] : []),
            ['&#xE652;', () => callHandler('copyText', { text: paragraphs.map(p => p.innerText).join(' ') })],
            ['&#xE67D;', () => callHandler('search', { query: paragraphs.map(p => p.innerText).join(' ') })],
            ['&#xE6A4;', () => callHandler('copyText', { text: paragraphs.map(p => p.innerText).join(' ') })],
          ];
        } 
        else {
          if (type === 'verse') {
            buttons = [
              ['&#xE65C;', () => callHandler('showVerse', { paragraphId: id })],
              ['&#xE688;', () => callHandler('addNote', { paragraphId: id, isBible: true })],
              ['&#xE621;', () => callHandler('showOtherTranslations', { paragraphId: id })],
              ['&#xE62C;', () => callHandler('bookmark', { snippet: paragraph.innerText, paragraphId: id, isBible: true })],
              ['&#xE652;', () => callHandler('copyText', { text: paragraph.innerText })],
              ['&#xE67D;', () => callHandler('searchVerse', { query: id })],
              ['&#xE6BA;', () => callHandler('share', { paragraphId: id, isBible: true })],
            ];
          } 
          else {
            buttons = [
              ['&#xE688;', () => callHandler('addNote', { paragraphId: id, isBible: false })],
              ['&#xE62C;', () => callHandler('bookmark', { snippet: paragraph.innerText, paragraphId: id })],
              ['&#xE6BA;', () => callHandler('share', { paragraphId: id, isBible: false })],
              ['&#xE652;', () => callHandler('copyText', { text: paragraph.innerText })],
            ];
          }
       }
        buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));

        if (!isHighlighted && hasAudio) {
          toolbar.appendChild(createToolbarButton('&#xE662;', () => callHandler('playAudio', { paragraphId: id })));
        }
      }
      
      function removeHighlight(uuid) {
        removeHighlightByGuid(uuid);
        closeToolbar();
        removeAllSelected();
      }

      function callHandler(name, args) {
        window.flutter_inappwebview.callHandler(name, args);
        closeToolbar();
        removeAllSelected();
      }
    
      function whenClickOnParagraph(target, selector, idAttr, classFilter) {
        // Remonte dans le DOM pour détecter un lien cliquable
        let isLink = false;
        let current = target[0];
        
        const hasHighlightOrSelectedClass = Array.from(current.classList).some(cls =>
           cls.includes('highlight-') || cls.includes('selected')
        );
        
        if(classFilter == 'paragraph') {
          while (current && !current.hasAttribute(idAttr)) {
            if (
              current.tagName.toLowerCase() === 'a' ||
              current.classList.contains('fn') ||
              current.classList.contains('v') ||
              current.classList.contains('gen-field')
            ) {
              isLink = true;
              break;
            }
            current = current.parentElement;
          }
          
          const id = current?.getAttribute(idAttr);
          
          if (!isLink && id) {
            if(hasHighlightOrSelectedClass) {
              showToolbar(target, 'data-pid', '[data-pid]', true, false, 'paragraph');
            } 
            else {
              const hasAudio = cachedPages[currentIndex] && cachedPages[currentIndex].audiosMarkers? cachedPages[currentIndex].audiosMarkers.some(m => String(m.mepsParagraphId) === String(id)) : false;
              showToolbar([current], id, selector, false, hasAudio, classFilter);
            }
          }
        }
        else {
          while (current && !current.hasAttribute(idAttr) && !current.classList.contains('v')) {
            if (['a', 'p'].includes(current.tagName.toLowerCase()) ||
                current.classList.contains('fn') ||
                current.classList.contains('m') ||
                current.classList.contains('sb')) {
                closeToolbar();
                return; // Sortir si c'est un lien ou un élément non pertinent
            }
            current = current.parentElement;
          }

          let id = current?.getAttribute(idAttr);

          // Extraire l'ID de base (v40-1-2)
          if (id && id.startsWith('v') && current?.classList.contains('v')) {
              const segments = id.split('-');
              if (segments.length >= 3) {
                  id = segments.slice(0, 3).join('-'); // Garder seulement v40-1-2
              }
          }

          if (!id) {
            closeToolbar();
            return;
          }

          // Sélectionner tous les éléments du verset
          const verseElements = Array.from(document.querySelectorAll('span.v[id]')).filter(el => {
              const elId = el.getAttribute('id');
              return elId && elId.startsWith(id);
          });

          // Trier les éléments par leur dernier segment
          verseElements.sort((a, b) => {
              const aLast = parseInt(a.getAttribute('id').split('-').pop()) || 0;
              const bLast = parseInt(b.getAttribute('id').split('-').pop()) || 0;
              return aLast - bLast;
          });

          console.log('Éléments du verset trouvés:', verseElements.map(el => el.getAttribute('id')));

          // Afficher la toolbar sur le premier élément du verset
          if (verseElements.length > 0) {
              if(hasHighlightClass) {
                showToolbar(target, 'data-pid', '[data-pid]', true, false, 'paragraph');
              } else {
                showToolbar(verseElements, id, selector, false, false, classFilter);
              }
          }
          else {
              closeToolbar();
          }
        }
      }

      async function loadUserdata() {
        let selector = isBible() ? '.v' : '[data-pid]';
        let idAttr = isBible() ? 'id' : 'data-pid';
        const userdata = await window.flutter_inappwebview.callHandler('getUserdata', '');

        const bookmarks = userdata.bookmarks;
        const inputFields = userdata.inputFields;
        const highlights = userdata.highlights;
        
        console.log('Bookmarks:', bookmarks);
        console.log('Input Fields:', inputFields);
        console.log('Highlights:', highlights);
        
        pageCenter.querySelectorAll(selector).forEach(p => {
          const id = p.getAttribute(idAttr);
          
          if (isBible() && id && id.startsWith('v')) {
            const segments = id.split('-');
            if (segments.length >= 3) {
              id = segments[2]; // Garder seulement le 3ème segment
            }
          }

          const bookmark = bookmarks.find(bookmark => Number(bookmark?.BlockIdentifier) === Number(id));
          if(bookmark) {
            addBookmark(p, bookmark?.BlockType, bookmark?.BlockIdentifier, bookmark?.Slot);
          }
          
          const matchingHighlights = highlights.filter(highlight => Number(highlight?.Identifier) === Number(id));
          matchingHighlights.forEach(highlight => {
            addHighlight(p, highlight.BlockType, highlight.Identifier, highlight.StartToken, highlight.EndToken, highlight.UserMarkGuid, highlight.ColorIndex);
          });
        });
        
        // Ajouter les événements 'input' ou 'change' aux champs input et textarea
        pageCenter.querySelectorAll('input, textarea').forEach((input) => {
          const id = input.getAttribute('id');
          if(id) {
            const inputField = inputFields.find(input => input?.TextTag === id);
            if(inputField) {
              if (input.type === 'checkbox') {
                input.checked = inputField.Value === '1';
              } 
              else if (input.tagName === 'TEXTAREA' || input.type === 'text') {
                input.value = inputField.Value;
              }
            }
          }
          
          const eventType = input.tagName === 'TEXTAREA' ? 'input' : 'change';
          input.addEventListener(eventType, () => {
            const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
            window.flutter_inappwebview.callHandler('onInputChange', {
              tag: input.id || '',
              value: value
            });
          });
          
          if(eventType === 'input') {
            input.addEventListener('input', () => adjustHeight(input));  // Ajuster lors de la saisie
            adjustHeight(input);
          }
        });
      }
      
      function addBookmark(target, blockType, blockIdentifier, slot) {
        if(!target) {
          target = pageCenter.querySelector(`[data-pid="\${blockIdentifier}"]`);
        }
        const imgSrc = bookmarkAssets[slot];
        if (imgSrc) {
            const img = document.createElement('img');
            img.src = imgSrc;
            img.classList.add('bookmark-icon');
            img.style.position = 'absolute';
            img.style.left = '-16px';
            img.style.top = '5px';
            img.style.width = '18px';
            img.style.height = '25px';

            target.style.position = 'relative'; 
            target.appendChild(img);
        }
      }
      
      function addHighlight(target, blockType, blockIdentifier, startToken, endToken, guid, colorIndex) {
  if (!target) {
    target = pageCenter.querySelector(`[data-pid="\${blockIdentifier}"]`);
  }

  const highlightClass = `highlight-${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][colorIndex]}`;

  // Récupérer tous les enfants word + punctuation dans le bon ordre
  const tokens = Array.from(target.querySelectorAll('.word, .punctuation'));

  // Récupérer les éléments à surligner
  const selectedTokens = tokens.slice(startToken, endToken + 1);

  selectedTokens.forEach((token, index) => {
    token.classList.add(highlightClass);
    // Ajouter l'UUID comme attribut data pour identifier le surlignage
    token.setAttribute('data-highlight-id', guid);

    // On surligne l'espace juste après sauf si c'est le dernier token
    const next = token.nextElementSibling;
    if (next && next.classList.contains('escape') && index !== selectedTokens.length - 1) {
      next.classList.add(highlightClass);
      // Ajouter l'UUID à l'espace aussi
      next.setAttribute('data-highlight-id', guid);
    }
  });
}

// Fonction utilitaire pour supprimer un surlignage spécifique par son UUID
function removeHighlightByGuid(guid) {
  const highlightedElements = document.querySelectorAll(`[data-highlight-id="\${guid}"]`);
  highlightedElements.forEach(element => {
    // Supprimer toutes les classes de surlignage
    element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 
                             'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
    // Supprimer l'attribut UUID
    element.removeAttribute('data-highlight-id');
  });
}

// Fonction utilitaire pour changer la couleur d'un surlignage spécifique
function changeHighlightColor(guid, newColorIndex) {
  const highlightedElements = document.querySelectorAll(`[data-highlight-id="\${guid}"]`);
  const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][newColorIndex]}`;
  
  highlightedElements.forEach(element => {
    // Supprimer toutes les classes de surlignage existantes
    element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 
                             'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
    // Ajouter la nouvelle classe de couleur
    element.classList.add(newHighlightClass);
  });
}

      // Clics images et références
      pageCenter.addEventListener('click', (event) => {
        let target = event.target;   
        
        closeToolbar();
        
        if(target.tagName === 'TEXTAREA' || target.tagName === 'INPUT') {
          return;
        }     

        if (target.tagName === 'IMG') {
          window.flutter_inappwebview.callHandler('onImageClick', target.src);
        }

        if (target.classList.contains('fn')) {
          const fnid = target.getAttribute('data-fnid');
          window.flutter_inappwebview.callHandler('fetchFootnote', fnid);
        }

        if (target.classList.contains('m')) {
          const mid = target.getAttribute('data-mid');
          window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
        }
        
        if(isBible()) {
          whenClickOnParagraph([target], '.v', 'id', 'verse');
        }
        else {
          whenClickOnParagraph([target], '[data-pid]', 'data-pid', 'paragraph');
        }
      });
      
      let pressTimer;
      let firstLongPressTarget = null;
      let lastLongPressTarget = null;
      let isLongTouchFix = false;
      let isLongPressing = false;
      let startX = 0;
      let startY = 0;
      let currentTranslate = -100;
      let isDragging = false;
      let isVerticalScroll = false;
      
      function setLongPressing(value) {
        isLongPressing = value;
        if (isLongPressing) {
          pageCenter.style.overflow = 'hidden'; // bloque le scroll
        } else {
          pageCenter.style.overflow = 'auto'; // rétablit le scroll
        }
      }
      
      pageCenter.addEventListener("scroll", () => {
        if (isLongPressing) return;
        const scrollTop = pageCenter.scrollTop;
        const scrollDirection = scrollTop > lastScrollTop ? "down" : scrollTop < lastScrollTop ? "up" : "none";
        lastScrollTop = scrollTop;
        window.flutter_inappwebview.callHandler('onScroll', scrollTop, scrollDirection);
      });
      
      pageCenter.addEventListener('touchstart', (event) => {
        firstLongPressTarget = event.target; // Capture l'élément touché
        pressTimer = setTimeout(() => {
          setLongPressing(true);
          isLongTouchFix = true;
        }, 300); // Délai en millisecondes
      });
      
      pageCenter.addEventListener('touchmove', (event) => {
        isLongTouchFix = false;
        clearTimeout(pressTimer);
      });

      pageCenter.addEventListener('touchend', (event) => {
          const touch = event.changedTouches[0];
          const x = touch.clientX;
          const y = touch.clientY;

          lastLongPressTarget = document.elementFromPoint(x, y);
          
          clearTimeout(pressTimer);
          if(isLongPressing) {
            onLongPressEnd();
          }
          isLongTouchFix = false;
      });
      
      async function onLongPressEnd() {
        let firstTarget = firstLongPressTarget;
        let lastTarget = lastLongPressTarget;
        let allTargets = null;
        
        if (isLongTouchFix) {
            lastTarget.classList.add('selected');
            allTargets = [lastTarget];
        }
        else {
          const parent = firstTarget.parentElement;
          const id = parent.getAttribute('data-pid');
          const allWords = Array.from(parent.querySelectorAll('.word, .punctuation'));
      
          // Trouver les indices des deux cibles
          const startIndex = allWords.indexOf(firstTarget);
          const endIndex = allWords.indexOf(lastTarget);
          
          allTargets = allWords.slice(startIndex, endIndex + 1);
          
          if (startIndex === -1 || endIndex === -1) return;

          // S'assurer que l'index de départ est inférieur à celui de fin
          const [from, to] = startIndex < endIndex ? [startIndex, endIndex] : [endIndex, startIndex];
          
          const guid = await window.flutter_inappwebview.callHandler('getGuid');
          const uuid = guid.uuid;
          addHighlight(parent, 1, id, startIndex, endIndex, uuid, highlightColorIndex);
        }
        // Appeler la fonction selon le type de texte
        if (isBible()) {
          whenClickOnParagraph(allTargets, '.v', 'id', 'verse');
        } else {
          whenClickOnParagraph(allTargets, '[data-pid]', 'data-pid', 'paragraph');
        }
      }

      container.addEventListener('touchstart', (e) => {
        if (isLongPressing) return;
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
        isDragging = true;
        isVerticalScroll = false;
        container.style.transition = "none";
      });

      container.addEventListener('touchmove', (e) => {
        if (isLongPressing) return;
        if (!isDragging) return;
        const x = e.touches[0].clientX;
        const y = e.touches[0].clientY;
        const dx = x - startX;
        const dy = y - startY;
        
        closeToolbar();

        if (!isVerticalScroll && Math.abs(dy) > Math.abs(dx)) {
          isVerticalScroll = true;
        }

        if (!isVerticalScroll) {
          const percentage = dx / window.innerWidth * 100;
          if ((currentIndex === 0 && dx > 0) || (currentIndex === maxIndex && dx < 0)) {
            container.style.transform = \`translateX(\${currentTranslate}%)\`;
          } else {
            container.style.transform = \`translateX(\${currentTranslate + percentage}%)\`;
          }
        }
      });

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
          container.style.transform = \`translateX(\${currentTranslate}%)\`;
          return;
        }

        const dx = e.changedTouches[0].clientX - startX;
        const percentage = dx / window.innerWidth;
        container.style.transition = "transform 0.3s ease-in-out";

        if (percentage < -0.15 && currentIndex < maxIndex) {
          currentTranslate = -200;
          container.style.transform = "translateX(-200%)";
          setTimeout(async () => {
            currentIndex++;
            currentTranslate = -100;
            await loadPages(currentIndex);
            pageCenter.scrollTop = 0;
            await window.flutter_inappwebview.callHandler('onSwipe', 'next');
            loadUserdata();
          }, 300);
        } else if (percentage > 0.15 && currentIndex > 0) {
          currentTranslate = 0;
          container.style.transform = "translateX(0%)";
          setTimeout(async () => {
            currentIndex--;
            currentTranslate = -100;
            await loadPages(currentIndex);
            pageCenter.scrollTop = 0;
            await window.flutter_inappwebview.callHandler('onSwipe', 'prev');
            loadUserdata();
          }, 300);
        } else {
          container.style.transform = "translateX(-100%)";
        }
      });
      
       
        loadUserdata();
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
