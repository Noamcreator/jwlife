import 'dart:convert';

import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../app/services/settings_service.dart';

String createReaderHtmlShell(Publication publication, int firstIndex, int maxIndex, {int? startParagraphId, int? endParagraphId, int? startVerseId, String? textTag, int? endVerseId, List<String> wordsSelected = const []}) {
  String publicationPath = publication.path!;
  final webViewData = JwLifeSettings().webViewData;
  final fontSize = webViewData.fontSize;
  final colorIndex = webViewData.colorIndex;
  bool isDarkMode = webViewData.theme == 'cc-theme--dark';
  bool isFullscreenMode = webViewData.isFullScreenMode;

  final lightPrimaryColor = toHex(JwLifeSettings().lightPrimaryColor);
  final darkPrimaryColor = toHex(JwLifeSettings().darkPrimaryColor);

  String theme = isDarkMode ? 'dark' : 'light';

  return '''
    <!DOCTYPE html>
    <html style="overflow: hidden;">
      <meta content="text/html" charset="UTF-8">
      <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no">
      <link rel="stylesheet" href="jw-styles.css" />
      <head>
        <meta charset="utf-8">
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
            height: 100vh;
            backface-visibility: hidden;
          }
          
          .page {
            flex: 0 0 100%;
            height: 100vh;
            overflow-y: auto;
            overflow-x: auto;
            box-sizing: border-box;
          }
          
          #page-center {
            position: relative;
            opacity: 0;
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
            width: 23px;
            height: 26px;
            z-index: 999;
          }
          
          .note-indicator {
            position: absolute;
            width: 15px;
            height: 15px;
            z-index: 999;
          }
         
          .word.selected,
          .punctuation.selected,
          .escape.selected {
            background-color: rgba(66, 236, 241, 0.3);
            position: relative; /* nécessaire pour handles positionnés en absolu */
          }
          
          .handle {
            position: absolute;
            width: 20px;
            height: 20px;
            pointer-events: auto;
          }
          
          .handle-left {
            bottom: -20px; /* Ajuste selon ton design */
            left: -20px;
          }
          
          .handle-right {
            bottom: -20px;
            right: -20px;
          }
          
          .word.searched {
            background-color: rgba(255, 185, 46, 0.8);
          }
            
          a:hover, a:active, a:visited, a:focus {
            border: none;
            background: rgba(175, 175, 175, 0.3);
            outline: none;
          }
          
          /* Style commun à la toolbar */
          .toolbar {
            position: absolute;
            padding: 1px;
            border-radius: 6px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
            white-space: nowrap;
            display: flex;
            opacity: 1;
            transform: translateX(-50%);
            width: max-content;
            max-width: 90vw;
          }
          
          /* Thème clair */
          body.cc-theme--light .toolbar {
            background-color: #ffffff;
          }
          
          /* Thème sombre */
          body.cc-theme--dark .toolbar {
            background-color: #424242;
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

          .cc-theme--light .note-indicator-gray      { background-color: #bfbfbf; }
          .cc-theme--light .note-indicator-yellow    { background-color: #fff379; }
          .cc-theme--light .note-indicator-green     { background-color: #b7e492; }
          .cc-theme--light .note-indicator-blue      { background-color: #98d8fe; }
          .cc-theme--light .note-indicator-pink      { background-color: #f698bc; }
          .cc-theme--light .note-indicator-orange    { background-color: #feba89; }
          .cc-theme--light .note-indicator-purple    { background-color: #c0a7e1; }
        
          .cc-theme--dark .note-indicator-gray      { background-color: #808080; }
          .cc-theme--dark .note-indicator-yellow    { background-color: #eac600; }
          .cc-theme--dark .note-indicator-green     { background-color: #67a332; }
          .cc-theme--dark .note-indicator-blue      { background-color: #4ba1de; }
          .cc-theme--dark .note-indicator-pink      { background-color: #c64677; }
          .cc-theme--dark .note-indicator-orange    { background-color: #ea6d01; }
          .cc-theme--dark .note-indicator-purple    { background-color: #7a57a7; }
          
          .cc-theme--light .note-gray      { background-color: #f1f1f1; }
          .cc-theme--light .note-yellow    { background-color: #fffce6; }
          .cc-theme--light .note-green     { background-color: #effbe6; }
          .cc-theme--light .note-blue      { background-color: #e6f7ff; }
          .cc-theme--light .note-pink      { background-color: #ffe6f0; }
          .cc-theme--light .note-orange    { background-color: #fff0e6; }
          .cc-theme--light .note-purple    { background-color: #f1eafa; }
          
          .cc-theme--dark .note-gray      { background-color: #292929; }
          .cc-theme--dark .note-yellow    { background-color: #49400e; }
          .cc-theme--dark .note-green     { background-color: #233315; }
          .cc-theme--dark .note-blue      { background-color: #203646; }
          .cc-theme--dark .note-pink      { background-color: #401f2c; }
          .cc-theme--dark .note-orange    { background-color: #49290e; }
          .cc-theme--dark .note-purple    { background-color: #2d2438; }
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
          let currentIndex = $firstIndex;
          const container = document.getElementById("container");
          const pageCenter = document.getElementById("page-center");
          const pageLeft = document.getElementById("page-left");
          const pageRight = document.getElementById("page-right");
          
          const magnifier = document.getElementById('magnifier');
          const magnifierContent = document.getElementById('magnifier-content');
          
          let isDark = $isDarkMode;
          let lightPrimaryColor = '$lightPrimaryColor';
          let darkPrimaryColor = '$darkPrimaryColor';

          let isFullscreenMode = $isFullscreenMode;
          let controlsVisible = true;

          let cachedPages = {};
          let scrollTopPages = {};
          let highlightColorIndex = $colorIndex;
          
          let isChangingParagraph = false;
          
          const bookmarkAssets = Array.from({ length: 10 }, (_, i) => `bookmarks/$theme/bookmark\${i + 1}.png`);
          const highlightAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}.png`);
          const highlightSelectedAssets = Array.from({ length: 6 }, (_, i) => `highlights/$theme/highlight\${i + 1}_selected.png`);
          
          const handleLeft = `images/handle_left.png`;
          const handleRight = `images/handle_right.png`;
          
          const speedBarScroll = `images/speedbar_thumb_regular.png`;
          let scrollBar = null;
    
          const maxIndex = $maxIndex;
          
          // Valeurs fixes de hauteur des barres
          const APPBAR_FIXED_HEIGHT = 56;
          const BOTTOMNAVBAR_FIXED_HEIGHT = 55;
          
          let highlights;
          let notes;
          let inputFields;
          let bookmarks;
          
          function changeTheme(isDarkMode) {
            isDark = isDarkMode;
            document.body.classList.remove('cc-theme--dark', 'cc-theme--light');
            document.body.classList.add(isDarkMode ? 'cc-theme--dark' : 'cc-theme--light');
          }
          
          function isDarkTheme() {
            return document.body.classList.contains('cc-theme--dark');
          }
          
          function changeFullScreenMode(isFullscreen) {
            isFullscreenMode = isFullscreen;
          }
          
          function changePrimaryColor(lightColor, darkColor) {
            lightPrimaryColor = lightColor;
            darkPrimaryColor = darkColor;
            
            const floatingButton = document.getElementById('dialogFloatingButton');
            floatingButton.style.backgroundColor = isDarkTheme() ? darkPrimaryColor : lightPrimaryColor;
          }

          async function fetchPage(index) {
            if (index < 0 || index > maxIndex) return { html: "", className: "" };
            if (cachedPages[index]) return cachedPages[index];
            const page = await window.flutter_inappwebview.callHandler('getPage', index);
            cachedPages[index] = page;
            return page;
          }
    
          function adjustArticle(articleId, link) {
            const article = document.getElementById(articleId);
            if (!article) return;
    
            const header = article.querySelector('header');
            const firstImage = article.querySelector('div#f1.north_center');
            // Par défaut, on ajoute 20px de marge en plus de la hauteur de l'appbar
            let paddingTop = `\${APPBAR_FIXED_HEIGHT + 20}px`;
            
            // Si la première image se trouve DANS le header, on enlève les 20px
            if (firstImage && article.contains(firstImage)) {
              paddingTop = `\${APPBAR_FIXED_HEIGHT}px`;
            }
            
            if(link !== '') {
              // Création du lien
              const linkElement = document.createElement('a');
              linkElement.href = link;
              linkElement.textContent = '${publication.shortTitle}';
            
              // Style du lien en bleu
              linkElement.style.fontSize = '1.3em';
              linkElement.style.marginTop = '10px'; // un petit espace au dessus du lien
            
              // Insérer le lien juste après l'article
              article.insertAdjacentElement('beforeend', linkElement);
              
              article.style.paddingTop = `\${APPBAR_FIXED_HEIGHT}px`;
              article.style.paddingBottom = `\${BOTTOMNAVBAR_FIXED_HEIGHT + 30}px`;
            }
            else {
              article.style.paddingTop = paddingTop;
              article.style.paddingBottom = '90px';
            }
          }
    
          function addVideoCover(articleId) {
            const article = document.getElementById(articleId);
            if (!article) return;
    
            // Gestion des vidéos <video data-video>
            const videoElements = article.querySelectorAll("video[data-video]");
            videoElements.forEach(videoElement => {
              const imageName = videoElement.getAttribute("data-image");
              if (imageName) {
                const imagePath = `$publicationPath/\${imageName}`;
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
          
          function wrapWordsWithSpan(article, isBible) {
            let selector = isBible ? '.v' : '[data-pid]';
            const paragraphs = article.querySelectorAll(selector);
            paragraphs.forEach((p) => {
                processTextNodes(p);
            });
          }

          function processTextNodes(element) {
              const skipClasses = new Set(["fn", "m", "cl", "vl", "dc-button--primary"]);
             
              function walkNodes(node) {
                  if (node.nodeType === Node.TEXT_NODE) {
                      const text = node.textContent;
                      const newHTML = processText(text);
                      const temp = document.createElement('div');
                      temp.innerHTML = newHTML.html;
                                  
                      const parent = node.parentNode;
                      while (temp.firstChild) {
                          parent.insertBefore(temp.firstChild, node);
                      }
                      parent.removeChild(node);
                  } 
                  else if (node.nodeType === Node.ELEMENT_NODE) {
                      // Skip elements with specified classes or if it's a sup element
                      if ((node.closest && node.closest("sup")) || (node.classList && [...skipClasses].some(c => node.classList.contains(c)))) {
                          return;
                      }
                      // Skip elements that already have our span classes to avoid double processing
                      if (node.classList && (node.classList.contains('word') || node.classList.contains('escape') || node.classList.contains('punctuation'))) {
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
                      // It's a space
                      let spaceSequence = '';
                      while (i < text.length && (text[i] === ' ' || text[i] === '\u00A0')) {
                          spaceSequence += text[i];
                          i++;
                      }
                      html += `<span class="escape">\${spaceSequence}</span>`;
                  }
                  else if (isLetter(currentChar) || isDigit(currentChar)) {
                      // It's the beginning of a word (including integrated punctuation)
                      let word = '';
                      while (i < text.length && !isSpace(text[i]) && !isStandalonePunctuation(text, i)) {
                          word += text[i];
                          i++;
                      }
                      html += `<span class="word">\${word}</span>`;
                  }
                  else {
                      // It's standalone punctuation
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
              
              // If it's not punctuation, return false
              if (isLetter(char) || isDigit(char) || isSpace(char)) {
                  return false;
              }
              
              // Helper function to find the next/previous visible character
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
              
              // Check if it's punctuation that's part of a word
              const prevChar = findPrevVisibleChar(text, index);
              const nextChar = findNextVisibleChar(text, index);
              
              if ((isLetter(prevChar) && isLetter(nextChar)) || (isDigit(prevChar) && isDigit(nextChar))) {
                  return false;
              }
          
              // Otherwise, it's standalone punctuation
              return true;
          }
          
          // Function to detect invisible characters
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
         
          // Fonction pour charger une page de manière optimisée
          async function loadIndexPage(index, isFirst) {
            const curr = await fetchPage(index);
            pageCenter.innerHTML = `<article id="article-center" class="\${curr.className}">\${curr.html}</article>`;
            adjustArticle('article-center', curr.link);
            addVideoCover('article-center');
           
            container.style.transition = "none";
            container.style.transform = "translateX(-100%)";
            void container.offsetWidth;
            container.style.transition = "transform 0.3s ease-in-out";
            
            if (!isFirst) {
              const article = document.getElementById("article-center");
              wrapWordsWithSpan(article, isBible());
            }
          }
          
          async function loadPrevAndNextPages(index) {
            const prev = await fetchPage(index - 1);
            const next = await fetchPage(index + 1);
    
            document.getElementById("page-left").innerHTML = `<article id="article-left" class="\${prev.className}">\${prev.html}</article>`;
            document.getElementById("page-right").innerHTML = `<article id="article-right" class="\${next.className}">\${next.html}</article>`;
    
            adjustArticle('article-left', prev.link);
            addVideoCover('article-left');
            adjustArticle('article-right', next.link);
            addVideoCover('article-right');
          }
    
          // Fonction de chargement optimisée avec gestion des états
           async function loadPages(currentIndex) {
            await loadIndexPage(currentIndex, false);
          
            function restoreScrollPosition(page, index) {
              const scroll = scrollTopPages[index] ?? 0;
              page.scrollTop = scroll;
              scrollTopPages[index] = scroll;
              
              // 🔄 Réinitialiser les états de direction
              lastScrollTop = scroll;
              lastDirection = null;
              directionChangePending = false;
              directionChangeStartTime = 0;
              directionChangeStartScroll = 0;
              directionChangeTargetDirection = null;
            
              if (scroll === 0) {
                appBarHeight = APPBAR_FIXED_HEIGHT;
                bottomNavBarHeight = BOTTOMNAVBAR_FIXED_HEIGHT;
              }
            }
          
            restoreScrollPosition(pageCenter, currentIndex);
            pageCenter.scrollLeft = 0;
            
            currentGuid = '';
            pressTimer = null;
            firstLongPressTarget = null;
            lastLongPressTarget = null;
            isLongPressing = false;
            isLongTouchFix = false;
            isSelecting = false;
            sideHandle = null;
            isDragging = false;
            isVerticalScroll = false;
            startX = 0;
            startY = 0;
            currentTranslate = -100;
          
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
        
          let firstParagraphId;
          let endParagraphId;
        
          if (begin === -1 && end === -1) {
            // Rétablir tous les paragraphes à l'opacité normale
            paragraphs.forEach(p => {
              p.style.opacity = '1';
            });
            return;
          }
        
          if (selector === '[data-pid]') {
            paragraphs.forEach(p => {
              const pid = parseInt(p.getAttribute(idAttr), 10);
              if (!firstParagraphId) firstParagraphId = pid;
              endParagraphId = pid;
        
              if (pid >= begin && pid <= end && !targetParagraph) {
                targetParagraph = p;
              }
        
              p.style.opacity = (pid >= begin && pid <= end) ? '1' : '0.5';
            });
          } else {
            paragraphs.forEach(p => {
              const attrValue = p.getAttribute(idAttr)?.trim();
              if (!attrValue) return;
        
              const idParts = attrValue.split('-');
              if (idParts.length < 4) return;
        
              const verse = parseInt(idParts[2], 10);
              if (!firstParagraphId) firstParagraphId = verse;
              endParagraphId = verse;
        
              if (verse >= begin && verse <= end && !targetParagraph) {
                targetParagraph = p;
              }
        
              p.style.opacity = (verse >= begin && verse <= end) ? '1' : '0.5';
            });
          }
        
          if (targetParagraph) {
            isChangingParagraph = true;
        
            const visibleParagraphs = Array.from(pageCenter.querySelectorAll(selector)).filter(p => p.style.opacity === '1');
        
            if (visibleParagraphs.length === 0) {
              isChangingParagraph = false;
              return;
            }
        
            const firstTop = visibleParagraphs[0].offsetTop;
            const lastParagraph = visibleParagraphs[visibleParagraphs.length - 1];
            const lastBottom = lastParagraph.offsetTop + lastParagraph.offsetHeight;
            const totalHeight = lastBottom - firstTop;
        
            const screenHeight = pageCenter.clientHeight;
            const visibleHeight = screenHeight - appBarHeight - bottomNavBarHeight - 40;
        
            let scrollToY;
        
            // Cas : on débute au tout début
            if (begin === firstParagraphId) {
              scrollToY = 0;
            }
            // Cas : on termine au dernier paragraphe
            else if (end === endParagraphId) {
              scrollToY = pageCenter.scrollHeight;
            }
            // Cas : tout tient dans l'écran, centrer
            else if (totalHeight < visibleHeight) {
              scrollToY = firstTop - appBarHeight - 20 - (visibleHeight / 2) + (totalHeight / 2);
            }
            // Cas par défaut : afficher à partir du haut du premier paragraphe visible
            else {
              scrollToY = firstTop - appBarHeight - 20;
            }
        
            scrollToY = Math.max(scrollToY, 0);
            pageCenter.scrollTop = scrollToY;
        
            await new Promise(requestAnimationFrame);
            isChangingParagraph = false;
          }
        }
        
        async function jumpToTextTag(textarea) {
          closeToolbar();
        
          if (!textarea) {
            console.warn(`Aucun élément avec l'id '\${textTag}' trouvé.`);
            return;
          }
        
          isChangingParagraph = true;
        
          // Calcul de la position verticale dans le container scrollable
          const pageCenterRect = pageCenter.getBoundingClientRect();
          const textareaRect = textarea.getBoundingClientRect();
        
          // Calculer la position relative de textarea dans pageCenter (scrollable)
          // scrollTop + (position textarea dans la fenêtre - position container dans la fenêtre)
          const offsetTop = pageCenter.scrollTop + (textareaRect.top - pageCenterRect.top);
        
          // Centrer le textarea dans la zone visible de pageCenter en tenant compte des barres
          const screenHeight = pageCenter.clientHeight;
          const visibleHeight = screenHeight - appBarHeight - bottomNavBarHeight - 40;
        
          let scrollToY = offsetTop - appBarHeight - 20 - (visibleHeight / 2) + (textarea.offsetHeight / 2);
          scrollToY = Math.max(scrollToY, 0);
          pageCenter.scrollTop = scrollToY;
        
          await new Promise(requestAnimationFrame);
          isChangingParagraph = false;
        }
          
          function selectWords(words, jumpToWord) {
            // Supprimer la classe 'searched' de tous les éléments
            pageCenter.querySelectorAll('.searched').forEach(element => {
                element.classList.remove('searched');
            });
        
            // Récupérer tous les éléments avec la classe 'word'
            const wordElements = pageCenter.querySelectorAll('.word');
        
            const normalizedSearchWords = words.map(w => w.toLowerCase());
        
            let firstMatchedElement = null;
        
            // Ajouter la classe 'searched' aux éléments correspondants
            wordElements.forEach(element => {
                const wordText = element.textContent.trim().toLowerCase();
                const isMatch = normalizedSearchWords.some(searchWord => wordText.includes(searchWord));
                if (isMatch) {
                    element.classList.add('searched');
                    if (!firstMatchedElement) {
                        firstMatchedElement = element;
                    }
                }
            });
        
            // Si demandé, faire défiler jusqu'au premier mot trouvé
            if (jumpToWord && firstMatchedElement) {
                firstMatchedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }

          function isBible() {
            return cachedPages[currentIndex]['isBibleChapter'];
          }
     
          function restoreOpacity() {
            const selector = isBible() ? '.v' : '[data-pid]';
            const elements = pageCenter.querySelectorAll(selector);
          
            // Déconnecter temporairement (optionnel)
            requestAnimationFrame(() => {
              elements.forEach(e => {
                e.style.opacity = '1';
              });
            });
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
          
            button.innerHTML = icon;
          
            // Couleurs selon le thème
            const baseColor = isDarkTheme() ? 'white' : '#4f4f4f';
            const hoverColor = isDarkTheme() ? '#606060' : '#e6e6e6';
          
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
              colorToolbar.classList.add('toolbar', 'toolbar-colors');
              colorToolbar.style.top = highlightToolbar.style.top;
              colorToolbar.style.left = highlightToolbar.style.left;
              
              // ajouter un bouton retour
              const backButton = document.createElement('button');
              backButton.innerHTML = '&#xE639;';
              backButton.style.cssText = `
                font-family: jw-icons-external;
                font-size: 26px;
                padding: 3px;
                border-radius: 5px;
                margin: 0 3px;
                color: isDarkTheme() ? 'white' : '#4f4f4f';
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
                    let currentParagraph = [];
                    let currentParagraphId = -1;
                    let currentIsVerse = false;
                    let firstTarget = null;
                    let lastTarget = null;
                    
                    const highlightsToSend = [];
                    const selectedElements = pageCenter.querySelectorAll('.selected');
                    for (let i = 0; i < selectedElements.length; i++) {
                      const element = selectedElements[i];
                      
                      const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
                      element.classList.remove('selected');
                      element.classList.add(newHighlightClass);
                      element.setAttribute('data-highlight-id', currentGuid);
                      
                      const { id, paragraphs, isVerse } = getTheFirstTargetParagraph(element);
                    
                      if (id !== currentParagraphId) {
                        // S'il y avait un paragraphe précédent, on sauvegarde le highlight
                        if (firstTarget && lastTarget) {
                          addHighlightForParagraph(firstTarget, lastTarget, currentParagraph, currentParagraphId, currentIsVerse);
                        }
                    
                        // On commence un nouveau paragraphe
                        currentParagraph = paragraphs;
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
                    function addHighlightForParagraph(firstElement, lastElement, paragraphs, paragraphId, isVerse) {
                      const wordAndPunctTokens = paragraphs.flatMap(p => Array.from(p.querySelectorAll('.word, .punctuation')));
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
                    window.flutter_inappwebview.callHandler('addHighlights', highlightsToSend, highlightColorIndex, currentGuid);
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
          
            if (toolbars.length === 0) return; // Ne rien faire s'il n'y a aucune toolbar
          
            restoreOpacity(); // Appel si des toolbars sont présentes
          
            toolbars.forEach(toolbar => {
              toolbar.remove();
            });
          }

          function removeAllSelected() {
            pageCenter.querySelectorAll('.selected').forEach(elem => {
              elem.classList.remove('selected');
            });
          }
          
          function createToolbarBase({ targets, highlightId, isSelected, target }) {
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight');
          
            // Masquer les toolbars existantes
            toolbars.forEach(toolbar => toolbar.style.opacity = '0');
          
            setTimeout(() => {
              toolbars.forEach(toolbar => toolbar.remove());
            }, 200);
          
            // Ne rien faire si la bonne toolbar existe déjà
            const existing = Array.from(toolbars).find(toolbar =>
              toolbar.getAttribute('data-highlight-id') === highlightId
              || toolbar.classList.contains('selected')
            );
            if (existing) return;
          
            if (!targets || targets.length === 0) return;
          
            // Horizontal : centré sur tous les targets
            let minLeft = Infinity;
            let maxRight = -Infinity;
            targets.forEach(el => {
              const rect = el.getBoundingClientRect();
              minLeft = Math.min(minLeft, rect.left);
              maxRight = Math.max(maxRight, rect.right);
            });
          
            const scrollX = window.scrollX;
            let left = minLeft + (maxRight - minLeft) / 2 + scrollX;
          
            const pageRect = pageCenter.getBoundingClientRect();
            const pageLeft = pageRect.left + scrollX;
            const pageRight = pageRect.right + scrollX;
            const toolbarWidth = 200;
          
            left = Math.max(left, pageLeft + toolbarWidth / 2 + 10);
            left = Math.min(left, pageRight - toolbarWidth / 2 - 10);
          
            const firstRect = targets[0].getBoundingClientRect();
            const scrollY = window.scrollY;
            const toolbarHeight = 40;
            const safetyMargin = 10;
          
            let top = firstRect.top + scrollY - toolbarHeight - safetyMargin;
            const minVisibleY = scrollY + appBarHeight + safetyMargin;
            if (top < minVisibleY) {
              top = Math.max(firstRect.top + scrollY + safetyMargin, minVisibleY);
            }
          
            // Créer la toolbar
            const toolbar = document.createElement('div');
            toolbar.classList.add('toolbar', 'toolbar-highlight');
            if (isSelected) {
              toolbar.classList.add('selected');
            }
            else {
              toolbar.setAttribute('data-highlight-id', highlightId);
            }
            toolbar.style.top = `\${top}px`;
            toolbar.style.left = `\${left}px`;
            
            document.body.appendChild(toolbar);
          
            requestAnimationFrame(() => {
              const toolbarRect = toolbar.getBoundingClientRect();
              const realWidth = toolbarRect.width;
              left = Math.min(
                Math.max(left, pageLeft + realWidth / 2 + 10),
                pageRight - realWidth / 2 - 10
              );
              toolbar.style.left = `\${left}px`;
              toolbar.style.opacity = '1';
            });
          
            const paragraphInfo = getTheFirstTargetParagraph(target);
            const id = paragraphInfo.id;
            const paragraphs = paragraphInfo.paragraphs;
            const isVerse = paragraphInfo.isVerse;
          
            const text = Array.from(targets)
              .map(elem => elem.innerText)
              .filter(text => text.length > 0)
              .join('');
          
            toolbar.appendChild(createToolbarButtonColor(target, toolbar, isSelected));
          
            const buttons = [
              ['&#xE681;', () => isSelected ? addNote(paragraphs[0], id, isVerse, text) : addNoteWithHighlight(target, highlightId)],
              ...(!isSelected && highlightId ? [['&#xE6C5;', () => removeHighlight(highlightId)]] : []),
              ['&#xE651;', () => callHandler('copyText', { text })],
              ['&#xE676;', () => callHandler('search', { query: text })],
              ['&#xE696;', () => callHandler('copyText', { text })]
            ];
          
            buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));
          }
    
          function showToolbarHighlight(target, highlightId) {
            const targets = pageCenter.querySelectorAll(`[data-highlight-id="\${highlightId}"]`);
            if (targets.length === 0) return;
            
            createToolbarBase({ targets, highlightId, isSelected: false, target });
          }
          
          function showSelectedToolbar(target) {
            const targets = pageCenter.querySelectorAll('.selected');
            if (targets.length === 0) return;
          
            createToolbarBase({ targets, highlightId: null, isSelected: true, target });
          }
                    
          function showToolbar(paragraphs, pid, selector, hasAudio, type) {
            const paragraph = paragraphs[0];
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight, .toolbar-colors');
            
            // Chercher la toolbar correspondante au pid
            const matchingToolbar = Array.from(toolbars).find(toolbar => toolbar.getAttribute('data-pid') === pid);
            
            // Supprimer les toolbars qui ne correspondent pas
            toolbars.forEach(toolbar => {
              toolbar.style.opacity = '0';
              toolbar.remove();
            });
            
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
            toolbar.style.top = `\${top}px`;
            toolbar.style.left = `\${left}px`;
          
            document.body.appendChild(toolbar);
          
            let buttons = [];
            
            let allParagraphsText = '';
            paragraphs.forEach(paragraph => {
              allParagraphsText += paragraph.innerText;
            });
            
            if (type === 'verse') {
              buttons = [
                ['&#xE658;', () => fetchVerseInfo(paragraph, pid)],
                ['&#xE681;', () => addNote(paragraph, pid, true, '')],
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
          
          async function fetchVerseInfo(paragraph, pid) {
            const verseInfo = await window.flutter_inappwebview.callHandler('fetchVerseInfo', { id: pid });
            showVerseInfoDialog(pageCenter, verseInfo);
            closeToolbar();
          }
          
// Système d'historique des dialogs avec sauvegarde complète d'état
let dialogHistory = [];
let currentDialogIndex = -1;
let lastClosedDialog = null; // Pour mémoriser le dernier dialogue fermé
let globalFullscreenPreference = false; // Préférence globale pour le fullscreen
let dialogIdCounter = 0; // Compteur pour les ID uniques des dialogues

// Icônes pour les différents types de dialog
const DIALOG_ICONS = {
    'verse': '&#xE61D;', // Icône Bible
    'verse-references': '&#xE61F;', // Icône Bible
    'verse-info': '&#xE620;', // Icône Bible
    'publication': '&#xE629;', // Icône Publication
    'footnote': '&#xE69B;', // Icône Footer
    'note': '&#xE6BF;', // Icône Note
    'default': '&#xE658;' // Icône par défaut
};

function hideAllDialogs() {
    const dialogs = document.querySelectorAll('.customDialog');
    dialogs.forEach(dialog => {
        dialog.style.display = 'none';
    });
}

function closeDialog() {
    const dialog = document.getElementById(dialogHistory[currentDialogIndex].dialogId);
    if (!dialog) return;
    
    // Cacher le dialog
    dialog.style.display = 'none';
    
    if (currentDialogIndex >= 0) {
        lastClosedDialog = {
            ...dialogHistory[currentDialogIndex],
            historyIndex: currentDialogIndex,
            fullHistory: [...dialogHistory],
            type: dialogHistory[currentDialogIndex].type,
        };
    }
    
    dialogHistory = [];
    currentDialogIndex = -1;

    // Afficher le bouton flottant si on a un dialogue à restaurer
    if (lastClosedDialog) {
        showFloatingButton();
    }

    window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
    window.flutter_inappwebview?.callHandler('showDialog', false);
}

function removeDialog() {
    if (currentDialogIndex < 0 || dialogHistory.length === 0) return;

    // Récupérer le dernier dialogue
    const dialogData = dialogHistory[currentDialogIndex];
    const dialog = document.getElementById(dialogData.dialogId);

    if (dialog) {
        // Supprimer le dialog du DOM
        dialog.remove();
    }
    
    // Supprimer l'entrée du tableau
    dialogHistory.splice(currentDialogIndex, 1);

    // Mettre à jour l'index
    currentDialogIndex = dialogHistory.length - 1;

    window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
    window.flutter_inappwebview?.callHandler('showDialog', false);
}

// Fonction pour naviguer vers le dialog précédent
function goBackDialog() {
    if (currentDialogIndex > 0 && dialogHistory.length > 1) {
        // Supprimer le dernier dialogue (celui qu'on quitte)
        dialogHistory.pop();

        // Décrémenter l'index pour pointer sur le précédent
        currentDialogIndex--;

        // Récupérer le précédent dialogue
        const previousDialog = dialogHistory[currentDialogIndex];

        // Afficher le dialogue précédent
        showDialogFromHistory(previousDialog);

        return true;
    }
    return false;
}

// Fonction pour créer ou restaurer un dialog depuis l'historique
function showDialogFromHistory(historyItem) {
    hideAllDialogs();

    const existingDialog = document.getElementById(historyItem.dialogId);
    let dialog;

    if (existingDialog) {
        dialog = existingDialog;
        dialog.style.display = 'block';
    } 
    else {
        dialog = createDialogElement(historyItem.options, historyItem.canGoBack, globalFullscreenPreference, historyItem.dialogId);
        document.body.appendChild(dialog);
    }

    applyDialogStyles(historyItem.type, dialog, globalFullscreenPreference);
    
    if (historyItem.type === 'note') {
        dialog.className = dialog.className.replace(/note-(yellow|green|blue|red|purple)/g, '').trim();
        dialog.classList.add(`note-\${historyItem.options.noteData.noteColor.toLowerCase()}`);
    }

    return dialog;
}

// Fonction principale pour créer et afficher un dialog
function showDialog(options) {
    removeFloatingButton();
    
    window.flutter_inappwebview?.callHandler('showDialog', true);
      
    dialogIdCounter++; // Incrémenter pour un nouvel ID
    const newDialogId = `customDialog-\${dialogIdCounter}`;
    
    // Créer et ajouter le nouveau dialogue à l'historique avec son ID
    const newHistoryItem = {
        options: options,
        canGoBack: dialogHistory.length > 0,
        type: options.type || 'default',
        dialogId: newDialogId,
    };
    dialogHistory.push(newHistoryItem);
    currentDialogIndex = dialogHistory.length - 1;
    
    // Créer et afficher le nouveau dialogue
    return showDialogFromHistory(newHistoryItem);
}

// Fonction pour créer l'élément dialog avec fullscreen et scroll
function createDialogElement(options, canGoBack, isFullscreenInit = false, scrollTopInit = 0, newDialogId = null) {
    let isFullscreen = isFullscreenInit;
    
    const dialog = document.createElement('div');
    dialog.id = newDialogId || `customDialog-\${dialogIdCounter}`;
    dialog.classList.add('customDialog');
    
    // Appliquer les styles selon le mode
    applyDialogStyles(options.type, dialog, isFullscreen);
    dialog.style.display = 'block';

    // Header
    const header = createHeader(options, isDarkTheme(), dialog, isFullscreen, canGoBack);
    setupDragSystem(header.element, dialog);

    // Content container
    const contentContainer = document.createElement('div');
    contentContainer.id = 'contentContainer';
    applyContentContainerStyles(options.type, contentContainer, isFullscreen);
    
    // **Modification ici : Appliquer la classe de couleur de la note à la création**
    if (options.type === 'note' && options.noteData && options.noteData.noteColor) {
        dialog.classList.add(`note-\${options.noteData.noteColor}`);
    }

    if (options.contentRenderer) {
        options.contentRenderer(contentContainer, options);
    }
    
    setTimeout(() => {
        contentContainer.scrollTop = scrollTopInit;
        console.log('Scroll restauré:', scrollTopInit);
    }, 10);

    // Setup du bouton fullscreen avec callback pour sauvegarder l'état
    setupFullscreenToggle(
        options.type,
        header.fullscreenButton,
        dialog,
        contentContainer
    );

    dialog.appendChild(header.element);
    dialog.appendChild(contentContainer);
    return dialog;
}

// Fonction pour appliquer les styles du dialog
function applyDialogStyles(type, dialog, isFullscreen, savedPosition = null) {
    const isDark = isDarkTheme();
    const backgroundColor = type == 'note' ? null : (isDarkTheme() ? '#121212' : '#ffffff');
    
    const baseStyles = `
        position: fixed;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
        z-index: 1000;
        background-color: \${backgroundColor};
    `;

    if (isFullscreen) {
        dialog.classList.add('fullscreen');
        dialog.style.cssText = baseStyles + `
            top: \${APPBAR_FIXED_HEIGHT}px;
            left: 0;
            right: 0;
            bottom: \${BOTTOMNAVBAR_FIXED_HEIGHT}px;
            width: 100vw;
            height: calc(100vh - \${APPBAR_FIXED_HEIGHT + BOTTOMNAVBAR_FIXED_HEIGHT}px);
            transform: none;
            margin: 0;
            border-radius: 0px;
        `;

        window.flutter_inappwebview?.callHandler('showFullscreenDialog', true);
    } 
    else {
        dialog.classList.remove('fullscreen');

        const windowDialogStyles = `
            width: 85%;
            max-width: 600px;
            border-radius: 16px;
        `;

        if (savedPosition && savedPosition.left && savedPosition.top) {
            dialog.style.cssText = baseStyles + windowDialogStyles + `
                left: \${savedPosition.left};
                top: \${savedPosition.top};
                transform: \${savedPosition.transform || 'none'};
            `;
        } else {
            dialog.style.cssText = baseStyles + windowDialogStyles + `
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
            `;
        }

        window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
    }
}

// Fonction pour appliquer les styles du container de contenu
function applyContentContainerStyles(type, contentContainer, isFullscreen) {
    const maxHeight = isFullscreen ? `calc(100vh - \${APPBAR_FIXED_HEIGHT + BOTTOMNAVBAR_FIXED_HEIGHT + 60}px)` : '60vh';
    const backgroundColor = type === 'note' ? 'transparent' : (isDarkTheme() ? '#121212' : '#ffffff');
    
    contentContainer.style.cssText = `
        max-height: \${maxHeight};
        overflow-y: auto;
        background-color: \${backgroundColor};
        user-select: text;
        border-radius: \${isFullscreen ? '0px' : '0 0 16px 16px'};
    `;
}

function createHeader(options, isDark, dialog, isFullscreen, canGoBack) {
    const header = document.createElement('div');
    const headerGradient = isDark 
        ? 'linear-gradient(135deg, #2a2a2a 0%, #1e1e1e 100%)' 
        : 'linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%)';
        
    const type = options.type;
    const title = options.title;
        
    const backgroundColor = type === 'note' ? 'transparent' : headerGradient;
    
    const borderRadius = isFullscreen ? '0px' : '16px 16px 0 0';
    
    header.style.cssText = `
        background: \${backgroundColor};
        color: \${isDark ? '#ffffff' : '#333333'};
        padding: 12px 16px;
        font-size: 18px;
        font-weight: 600;
        display: flex;
        align-items: center;
        justify-content: space-between;
        height: 50px;
        border-bottom: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
        border-radius: \${borderRadius};
    `;

    // Left area: back button + title
    const leftArea = document.createElement('div');
    leftArea.style.cssText = 'display: flex; align-items: center; gap: 8px;';

    if (canGoBack) {
        const backButton = document.createElement('button');
        backButton.innerHTML = '←';
        backButton.className = 'dialog-button back-button';
        backButton.style.cssText = `
            font-size: 18px;
            padding: 8px;
            background: \${isDark ? '#121212' : '#ffffff'};
            border: none;
            border-radius: 8px;
            color: inherit;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            opacity: 0.8;
        `;

        backButton.onclick = (event) => {
            event.stopPropagation();
            event.preventDefault();
            goBackDialog();
        };

        leftArea.appendChild(backButton);
    }

    const titleArea = document.createElement('div');
    titleArea.style.cssText = `
        user-select: none;
        cursor: move;
        font-weight: 600;
        letter-spacing: 0.5px;
    `;
    titleArea.innerHTML = title;
    leftArea.appendChild(titleArea);

    // Right area: fullscreen + close
    const rightArea = document.createElement('div');
    rightArea.style.cssText = 'display: flex; align-items: center; gap: 8px;';
    
    if(type === 'note' && options.noteData) {
      const moreButton = document.createElement('button');
      moreButton.innerHTML = '☰';
      moreButton.className = 'dialog-button';
      moreButton.style.cssText = `
          font-size: 18px;
          padding: 8px;
          background: \${isDark ? '#121212' : '#ffffff'};
          border: none;
          border-radius: 8px;
          color: inherit;
          cursor: pointer;
          transition: all 0.2s ease;
          display: flex;
          align-items: center;
          justify-content: center;
          width: 36px;
          height: 36px;
      `;
      
      moreButton.onclick = (event) => {
          // Supprime tout menu existant avant d'en créer un nouveau
          document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
      
          const popup = header.closest('.customDialog');
          const { element: optionsMenu, colorMenu } = createOptionsMenu(options.noteData.noteGuid, popup, isDark);
      
          document.body.appendChild(optionsMenu);
          document.body.appendChild(colorMenu);
      
          // Positionne le menu en dessous du bouton
          const rect = event.target.getBoundingClientRect();
          optionsMenu.style.top = `\${rect.bottom + 8}px`;
          optionsMenu.style.left = `\${rect.right - optionsMenu.offsetWidth - moreButton.offsetWidth - 20}px`;
          optionsMenu.style.display = 'flex';
      
          // Fermer si clic ailleurs
          const closeOnClickOutside = (e) => {
              if (!optionsMenu.contains(e.target) && !colorMenu.contains(e.target) && e.target !== moreButton) {
                  optionsMenu.remove();
                  colorMenu.remove();
                  document.removeEventListener('click', closeOnClickOutside);
                  moreButton.removeEventListener('click', closeOnClickOutside);
                  popup.removeEventListener('click', closeOnClickOutside);
              }
          };
          document.addEventListener('click', closeOnClickOutside);
          moreButton.addEventListener('click', closeOnClickOutside);
          popup.addEventListener('click', closeOnClickOutside);
      };
      
      rightArea.appendChild(moreButton);
    }

    const fullscreenButton = document.createElement('button');
    fullscreenButton.innerHTML = isFullscreen ? '⿻' : '⛶';
    fullscreenButton.className = 'dialog-button';
    fullscreenButton.style.cssText = `
        font-size: 18px;
        padding: 8px;
        background: \${isDark ? '#121212' : '#ffffff'};
        border: none;
        border-radius: 8px;
        color: inherit;
        cursor: pointer;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
    `;

    const closeButton = document.createElement('button');
    closeButton.innerHTML = '✕';
    closeButton.className = 'dialog-button';
    closeButton.style.cssText = `
        font-family: jw-icons-external;
        font-size: 18px;
        padding: 8px;
        background: rgba(220, 53, 69, 0.1);
        border: none;
        border-radius: 8px;
        color: #dc3545;
        cursor: pointer;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
    `;

    closeButton.onclick = (event) => {
        event.stopPropagation();
        event.preventDefault();
        
        closeDialog();
    };

    rightArea.appendChild(fullscreenButton);
    rightArea.appendChild(closeButton);

    // Ajouter les deux zones au header
    header.appendChild(leftArea);
    header.appendChild(rightArea);

    return {
        element: header,
        dragArea: titleArea,
        fullscreenButton,
        closeButton
    };
}

// Configuration du fullscreen avec sauvegarde d'état améliorée
function setupFullscreenToggle(type, fullscreenButton, dialog, contentContainer) {
    fullscreenButton.onclick = function(event) {
        event.stopPropagation();
        
        // Sauvegarder le scroll avant de changer d'état
        const currentScroll = contentContainer.scrollTop;
        
        if (globalFullscreenPreference) {
            // Sortir du fullscreen
            applyDialogStyles(type, dialog, false);
            applyContentContainerStyles(type, contentContainer, false);
            fullscreenButton.innerHTML = '⛶';
            
            // Mettre à jour le border-radius du header
            const header = dialog.querySelector('div');
            if (header) {
                header.style.borderRadius = '16px 16px 0 0';
            }
            
            globalFullscreenPreference = false;
        } 
        else {
            // Entrer en fullscreen
            applyDialogStyles(type, dialog, true);
            applyContentContainerStyles(type, contentContainer, true);
            fullscreenButton.innerHTML = '⿻';
            
            // Mettre à jour le border-radius du header
            const header = dialog.querySelector('div');
            if (header) {
                header.style.borderRadius = '0px';
            }
            
            globalFullscreenPreference = true;
        }
        
        // Restaurer le scroll après le changement d'état
        setTimeout(() => {
            contentContainer.scrollTop = currentScroll;
        }, 10);
    };
}

function setupDragSystem(header, dialog) {
    let isDragging = false;
    let startX, startY, startLeft, startTop;

    const startDrag = (e) => {
        if (globalFullscreenPreference) return;
        if (e.target.closest('.dialog-button')) return;

        isDragging = true;
        startX = e.clientX || (e.touches && e.touches[0].clientX);
        startY = e.clientY || (e.touches && e.touches[0].clientY);

        // Récupérer la position visuelle réelle du dialog
        const rect = dialog.getBoundingClientRect();
        startLeft = rect.left;
        startTop = rect.top;

        // Supprimer immédiatement la transformation pour passer en position absolue
        dialog.style.transform = 'none';
        dialog.style.left = `\${startLeft}px`;
        dialog.style.top = `\${startTop}px`;

        document.addEventListener('mousemove', drag);
        document.addEventListener('mouseup', stopDrag);
        document.addEventListener('touchmove', drag);
        document.addEventListener('touchend', stopDrag);

        dialog.style.cursor = 'grabbing';
        dialog.style.transition = 'none';
        e.preventDefault();
    };

    const drag = (e) => {
        if (!isDragging) return;
    
        const currentX = e.clientX || (e.touches && e.touches[0].clientX);
        const currentY = e.clientY || (e.touches && e.touches[0].clientY);
        
        const newLeft = startLeft + (currentX - startX);
        const newTop = startTop + (currentY - startY);
    
        // Limites de la fenêtre
        const dialogRect = dialog.getBoundingClientRect();
        
        // On prend en compte si l'appbar et le bottom navbar sont visibles
        const minTop = controlsVisible ? APPBAR_FIXED_HEIGHT : 0;
        const maxBottomLimit = window.innerHeight - (controlsVisible ? BOTTOMNAVBAR_FIXED_HEIGHT : 0);
        
        const maxLeft = window.innerWidth - dialogRect.width;
        
        dialog.style.left = `\${Math.max(0, Math.min(newLeft, maxLeft))}px`;
        dialog.style.top = `\${Math.max(minTop, Math.min(newTop, maxBottomLimit - dialogRect.height))}px`;
    };

    const stopDrag = () => {
        isDragging = false;
        dialog.style.cursor = '';
        
        document.removeEventListener('mousemove', drag);
        document.removeEventListener('mouseup', stopDrag);
        document.removeEventListener('touchmove', drag);
        document.removeEventListener('touchend', stopDrag);
    };

    header.addEventListener('mousedown', startDrag);
    header.addEventListener('touchstart', startDrag);
}

// Fonctions utilitaires pour gérer l'historique
function clearDialogHistory() {
    // Supprimer physiquement tous les dialogues du DOM
    const dialogs = document.querySelectorAll('.customDialog');
    dialogs.forEach(dialog => dialog.remove());
    
    dialogHistory = [];
    currentDialogIndex = -1;
    lastClosedDialog = null; // Nettoyer aussi le dernier dialogue fermé
    globalFullscreenPreference = false; // Reset de la préférence globale
    removeFloatingButton();
    dialogIdCounter = 0; // Réinitialiser le compteur d'ID
}

function getDialogHistoryLength() {
    return dialogHistory.length;
}

function canGoBack() {
    return currentDialogIndex > 0;
}

function restoreLastDialog() {
    if (!lastClosedDialog) return;

    // Mettre à jour l'index et l'historique
    currentDialogIndex = lastClosedDialog.historyIndex;
    dialogHistory = lastClosedDialog.fullHistory;

    removeFloatingButton();

    showDialogFromHistory(lastClosedDialog);

    lastClosedDialog = null;

    window.flutter_inappwebview?.callHandler('showDialog', true);
}

// ========== SYSTÈME DE BOUTON FLOTTANT ==========

function createFloatingButton() {
    const isDark = isDarkTheme();
    const floatingButton = document.createElement('div');
    floatingButton.id = 'dialogFloatingButton';
    const dialogType = lastClosedDialog.type || 'default';
    floatingButton.innerHTML = DIALOG_ICONS[dialogType]; // Utilise l'icône en fonction du type de dialogue
    const backgroundColor = isDark ? darkPrimaryColor : lightPrimaryColor;
    
    floatingButton.style.cssText = `
        position: fixed;
        bottom: \${BOTTOMNAVBAR_FIXED_HEIGHT + 15}px;
        right: 20px;
        width: 56px;
        height: 56px;
        background: \${backgroundColor};;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-family: jw-icons-external;
        font-size: 25px;
        color: \${isDark ? '#333333' : '#ffffff'};
        cursor: pointer;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        z-index: 999;
        transition: all 0.3s ease;
        opacity: 0;
        transform: scale(0.8);
        user-select: none;
    `;
    
    if(controlsVisible) {
      // Animation d'apparition
      setTimeout(() => {
          floatingButton.style.opacity = '1';
          floatingButton.style.transform = 'scale(1)';
      }, 100);
    }
    else {
      floatingButton.style.opacity = '0';
      floatingButton.style.transform = 'scale(1)';
    }

    // Action de clic
    floatingButton.onclick = () => {
        restoreLastDialog();
    };
    
    return floatingButton;
}

function showFloatingButton() {
    // Supprimer le bouton existant s'il y en a un
    const existingButton = document.getElementById('dialogFloatingButton');
    if (existingButton) existingButton.remove();
    
    if (lastClosedDialog) {
        const floatingButton = createFloatingButton();
        document.body.appendChild(floatingButton);
    }
}

function removeFloatingButton() {
    const existingButton = document.getElementById('dialogFloatingButton');
    if (existingButton) {
        // Animation de disparition
        existingButton.style.opacity = '0';
        existingButton.style.transform = 'scale(0.8)';
        setTimeout(() => {
            if (existingButton.parentNode) {
                existingButton.remove();
            }
        }, 300);
    }
}

// Fonction pour ouvrir un dialogue de note
async function openNoteDialog(highlightGuid, noteGuid) {
    const note = await window.flutter_inappwebview.callHandler('getNoteByGuid', noteGuid);
    
    if (!note) {
        console.error('Note non trouvée pour le GUID:', noteGuid);
        return;
    }

    const options = {
        title: 'Note',
        type: 'note',
        noteData: {
            noteGuid: noteGuid,
            title: note.title,
            content: note.content,
            tags: note.tags,
            tagsId: note.tagsId,
            noteColor: note.colorName
        },
        contentRenderer: (contentContainer, noteOptions) => {
            createNoteContent(contentContainer, noteOptions);
        }
    };
    
    showDialog(options);
}

function createNoteContent(contentContainer, options) {
    if (!options || !options.noteData) {
        console.error("Les données de la note sont manquantes. Impossible de charger le contenu.");
        contentContainer.innerHTML = "<p>Erreur: Contenu non disponible.</p>";
        return;
    }

    const { noteGuid, title, content, tags, tagsId, noteColor } = options.noteData;
    const isDark = isDarkTheme();
    const isEditMode = true;

    const dialogElement = contentContainer.closest('.customDialog');
    if (dialogElement) {
        dialogElement.classList.add('note-dialog');
    }

    // ✅ Conteneur principal
    const mainContainer = document.createElement('div');
    mainContainer.style.cssText = `
        display: flex;
        flex-direction: column;
        height: 100%;
        padding: 16px;
        box-sizing: border-box;
        overflow-y: auto;
        gap: 12px;
    `;

    // ✅ Champ titre
    const titleElement = document.createElement('input');
    titleElement.type = 'text';
    titleElement.className = 'note-title';
    titleElement.value = title;
    titleElement.placeholder = 'Titre de la note';
    titleElement.style.cssText = `
        border: none;
        outline: none;
        font-size: 20px;
        font-weight: bold;
        background: transparent;
        color: inherit;
        padding: 4px 0;
        flex-shrink: 0;
    `;

    // ✅ Zone de contenu (avec redimensionnement dynamique)
    const contentElement = document.createElement('textarea');
    contentElement.className = 'note-content';
    contentElement.value = content;
    contentElement.placeholder = 'Écrivez votre note ici...';
    contentElement.style.cssText = `
        border: none;
        outline: none;
        resize: none;
        font-size: inherit;
        line-height: 1.5;
        background: transparent;
        color: inherit;
        min-height: 200px;
        flex: 1;
        padding: 8px 0;
        overflow-y: auto;
    `;
    
    // Fonction de redimensionnement dynamique
    const autoResize = () => {
        const lineHeight = parseInt(window.getComputedStyle(contentElement).lineHeight);
        const maxHeight = lineHeight * 10;
        contentElement.style.height = 'auto';
        const newHeight = contentElement.scrollHeight;
        if (newHeight <= maxHeight) {
            contentElement.style.height = `\${newHeight}px`;
        } else {
            contentElement.style.height = `\${maxHeight}px`;
        }
    };
    
    // Écouteurs pour le redimensionnement
    contentElement.addEventListener('input', autoResize);
    contentElement.addEventListener('cut', autoResize);
    contentElement.addEventListener('paste', autoResize);

    // ✅ Lancement initial du redimensionnement
    setTimeout(autoResize, 0);

    // 🚀 Intégration des fonctionnalités de tags et suggestions
    const currentTagIds = !tagsId || tagsId === '' ? [] : tagsId.split(',').map(id => parseInt(id));

    const createTagElement = (tag) => {
        const tagElement = document.createElement('span');
        tagElement.style.cssText = `
            display: flex;
            align-items: center;
            background: \${isDark ? '#4a4a4a' : 'rgba(255,255,255,0.9)'};
            color: \${isDark ? '#fff' : '#2c3e50'};
            padding: 6px 10px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
            white-space: nowrap;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
            border: 1px solid \${isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)'};
            cursor: pointer;
        `;
        const text = document.createElement('span');
        text.textContent = tag.Name;
        tagElement.appendChild(text);

        const closeBtn = document.createElement('span');
        closeBtn.textContent = '×';
        closeBtn.style.cssText = `
            margin-left: 6px;
            cursor: pointer;
            font-weight: bold;
            color: \${isDark ? '#e0e0e0' : 'inherit'};
        `;
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            tagsContainer.removeChild(tagElement);
            const index = currentTagIds.indexOf(tag.TagId);
            if (index > -1) currentTagIds.splice(index, 1);
            window.flutter_inappwebview.callHandler('removeTagToNote', {
                noteGuid: noteGuid,
                tagId: tag.TagId
            });
        });
        tagElement.appendChild(closeBtn);

        tagElement.addEventListener('click', () => {
            window.flutter_inappwebview.callHandler('openTagPage', { tagId: tag.TagId });
        });
        return tagElement;
    };

    const addTagToUI = (tag) => {
        if (!currentTagIds.includes(tag.TagId)) {
            const tagElement = createTagElement(tag);
            tagsContainer.insertBefore(tagElement, tagInputWrapper);
            currentTagIds.push(tag.TagId);
            window.flutter_inappwebview.callHandler('addTagToNote', {
                noteGuid: noteGuid,
                tagId: tag.TagId
            });
        }
    };

    const tagsContainer = document.createElement('div');
    tagsContainer.style.cssText = `
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        max-height: 160px;
        overflow-y: auto;
        border-top: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)'};
        padding-top: 12px;
        flex-shrink: 0;
        position: relative;
    `;

    currentTagIds.forEach(tagId => {
        const tag = tags.find(t => t.TagId === tagId);
        if (tag) tagsContainer.appendChild(createTagElement(tag));
    });

    const tagInputWrapper = document.createElement('div');
    tagInputWrapper.style.cssText = `
        display: flex;
        align-items: center;
        gap: 10px;
        min-width: 150px;
        position: relative;
    `;

    const tagInput = document.createElement('input');
    tagInput.type = 'text';
    tagInput.placeholder = 'Ajouter une catégorie...';
    tagInput.style.cssText = `
        flex: 1;
        min-width: 100px;
        border: none;
        padding: 4px;
        outline: none;
        font-size: 14px;
        background: transparent;
        color: inherit;
    `;

    const suggestionsList = document.createElement('div');
    suggestionsList.className = 'suggestions-list';
    suggestionsList.style.cssText = `
        position: fixed;
        background: \${isDark ? '#333' : 'rgba(255, 255, 255, 0.95)'};
        border: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
        max-height: 150px;
        overflow-y: auto;
        z-index: 9000;
        backdrop-filter: blur(10px);
        display: none;
    `;

    const fuzzySearch = (query, text) => {
        if (!query) return true;
        const regex = new RegExp(query.split('').join('.*?'), 'i');
        return regex.test(text);
    };

    const showSuggestions = (filteredTags) => {
        suggestionsList.innerHTML = '';
        const value = tagInput.value.trim();
        const exactMatch = filteredTags.some(tag => tag.Name.toLowerCase() === value.toLowerCase());

        if (value !== '' && !exactMatch) {
            const addNew = document.createElement('div');
            addNew.textContent = `Ajouter la catégorie: "\${value}"`;
            addNew.style.cssText = `
                padding: 8px 12px;
                cursor: pointer;
                font-size: 14px;
                color: \${isDark ? '#fff' : '#2c3e50'};
                border-bottom: \${filteredTags.length > 0 ? '1px solid ' + (isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)') : 'none'};
                white-space: nowrap;
            `;
            addNew.addEventListener('click', async () => {
                const tagName = tagInput.value;
                tagInput.value = '';
                suggestionsList.style.display = 'none';
                const result = await window.flutter_inappwebview.callHandler('addTag', { tagName: tagName });
                if (result && result.tag) addTagToUI(result.tag);
                tagInput.focus();
            });
            suggestionsList.appendChild(addNew);
        }

        filteredTags.forEach(tag => {
            const item = document.createElement('div');
            item.textContent = tag.Name;
            item.style.cssText = `
                padding: 8px 12px;
                cursor: pointer;
                font-size: 14px;
                color: \${isDark ? '#fff' : '#2c3e50'};
                transition: background-color 0.2s ease;
                white-space: nowrap;
            `;
            item.addEventListener('mouseenter', () => item.style.backgroundColor = isDark ? '#4a4a4a' : 'rgba(52, 152, 219, 0.1)');
            item.addEventListener('mouseleave', () => item.style.backgroundColor = 'transparent');
            item.addEventListener('click', () => {
                addTagToUI(tag);
                tagInput.value = '';
                tagInput.focus();
                suggestionsList.style.display = 'none';
            });
            suggestionsList.appendChild(item);
        });

        suggestionsList.style.display = (suggestionsList.children.length > 0) ? 'block' : 'none';
    };

    const updateSuggestionsPosition = () => {
        const rect = tagInput.getBoundingClientRect();
        suggestionsList.style.left = `\${rect.left}px`;
        suggestionsList.style.top = `\${rect.bottom + 5}px`;
        suggestionsList.style.width = `\${Math.max(200, tagInput.offsetWidth)}px`;
    };

    tagInput.addEventListener('input', () => {
        const value = tagInput.value.trim();
        const availableTags = tags.filter(tag => !currentTagIds.includes(tag.TagId));
        let filteredTags = (value === '') ? availableTags : availableTags.filter(tag => fuzzySearch(value, tag.Name));
        showSuggestions(filteredTags);
        updateSuggestionsPosition();
    });

    tagInput.addEventListener('focus', () => {
        const value = tagInput.value.trim();
        const availableTags = tags.filter(tag => !currentTagIds.includes(tag.TagId));
        let filteredTags = (value === '') ? availableTags : availableTags.filter(tag => fuzzySearch(value, tag.Name));
        showSuggestions(filteredTags);
        updateSuggestionsPosition();
    });

    tagInput.addEventListener('blur', (e) => {
        setTimeout(() => {
            if (!suggestionsList.contains(document.activeElement)) {
                suggestionsList.style.display = 'none';
            }
        }, 100);
    });

    tagInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            const value = tagInput.value.trim();
            if (value !== '') {
                const exactMatch = tags.find(tag => tag.Name.toLowerCase() === value.toLowerCase());
                if (exactMatch) {
                    addTagToUI(exactMatch);
                } else {
                    window.flutter_inappwebview.callHandler('addTag', { tagName: value }).then(result => {
                        if (result && result.tag) addTagToUI(result.tag);
                    });
                }
                tagInput.value = '';
                suggestionsList.style.display = 'none';
                tagInput.focus();
            }
            e.preventDefault();
        }
    });

    // Assemblage
    if (isEditMode) {
        tagInputWrapper.appendChild(tagInput);
        tagsContainer.appendChild(tagInputWrapper);
    }

    mainContainer.appendChild(titleElement);
    mainContainer.appendChild(contentElement);
    mainContainer.appendChild(tagsContainer);
    contentContainer.appendChild(mainContainer);

    // 💡 Ajout de suggestionsList au body pour qu'elle soit en dehors du dialogue
    document.body.appendChild(suggestionsList);

    const saveChanges = () => {
        const titleVal = titleElement.value;
        const contentVal = contentElement.value;
        window.flutter_inappwebview.callHandler('updateNote', {
            noteGuid: noteGuid,
            title: titleVal,
            content: contentVal
        });
    };
    contentElement.addEventListener('input', saveChanges);
    titleElement.addEventListener('input', saveChanges);

    const addTag = () => {
        const tagName = tagInput.value.trim();
        if (tagName && tagName.length > 0) {
            window.flutter_inappwebview.callHandler('addTagToNote', {
                noteGuid: noteGuid,
                tagName: tagName
            });
            tagInput.value = '';
        }
    };

    tagInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            addTag();
        }
    });
    
    const cleanup = () => {
        if (suggestionsList && suggestionsList.parentNode) {
            suggestionsList.remove();
        }
    };

    if (dialogElement) {
        dialogElement.addEventListener('close', cleanup);
    }

    // ✅ Assurer que la suggestionList est retirée du DOM
    if(dialogElement) {
        dialogElement.addEventListener('dialogClosed', cleanup);
    }
}

// ✅ Fonction corrigée
function createOptionsMenu(noteGuid, popup, isDark) {
    const optionsMenu = document.createElement('div');
    optionsMenu.className = 'options-menu';
    optionsMenu.style.cssText = `
        position: absolute;
        width: 200px;
        background: \${isDark ? 'rgba(30, 30, 30, 0.95)' : 'rgba(255, 255, 255, 0.95)'};
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
        display: none;
        flex-direction: column;
        z-index: 2000;
        backdrop-filter: blur(10px);
        border: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
        padding: 5px 0;
    `;

    // Bouton Supprimer
    const deleteBtn = document.createElement('div');
    deleteBtn.className = 'menu-item';
    deleteBtn.innerHTML = '🗑 Supprimer la note';
    deleteBtn.style.cssText = `
        padding: 10px 15px;
        cursor: pointer;
        transition: background-color 0.2s ease;
        color: \${isDark ? '#fff' : '#333'};
    `;
    
    deleteBtn.onmouseenter = () => {
        deleteBtn.style.backgroundColor = isDark ? 'rgba(0, 123, 255, 0.2)' : 'rgba(0, 123, 255, 0.1)';
    };
    deleteBtn.onmouseleave = () => {
        deleteBtn.style.backgroundColor = 'transparent';
    };
    
    deleteBtn.onclick = async () => {
        // ✅ Ferme le menu immédiatement
        optionsMenu.style.display = 'none';
        colorMenu.style.display = 'none';
    
        // Confirmation
        const confirmed = await window.flutter_inappwebview.callHandler('showConfirmationDialog', {
            title: 'Supprimer la note',
            message: 'Êtes-vous sûr de vouloir supprimer cette note ?'
        });
    
        if (confirmed) {
            // Supprime la note visuellement
            const note = pageCenter.querySelector(`[data-note-id="\${noteGuid}"]`);
            if (note) {
                note.remove();
            }
    
            // Supprime côté Flutter
            window.flutter_inappwebview.callHandler('removeNote', {
                guid: noteGuid
            });
    
            removeDialog();
        }
    };

    // Bouton changer couleur
    const changeColorItem = document.createElement('div');
    changeColorItem.className = 'menu-item has-submenu';
    changeColorItem.innerHTML = '🎨 Changer la couleur';
    changeColorItem.style.cssText = `
        padding: 10px 15px;
        cursor: pointer;
        transition: background-color 0.2s ease;
        color: \${isDark ? '#fff' : '#333'};
    `;
    changeColorItem.onmouseenter = () => changeColorItem.style.backgroundColor = isDark ? 'rgba(0, 123, 255, 0.2)' : 'rgba(0, 123, 255, 0.1)';
    changeColorItem.onmouseleave = () => changeColorItem.style.backgroundColor = 'transparent';

    // Sous-menu couleurs
    const colorMenu = document.createElement('div');
    colorMenu.className = 'color-menu';
    colorMenu.style.cssText = `
        position: absolute;
        width: 120px;
        background: \${isDark ? 'rgba(30, 30, 30, 0.95)' : 'rgba(255, 255, 255, 0.95)'};
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
        display: none;
        flex-direction: column;
        z-index: 2001;
        backdrop-filter: blur(10px);
        border: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
    `;

    const colors = ['gray', 'yellow', 'green', 'blue', 'pink', 'orange', 'purple'];
    colors.forEach(color => {
        const colorOption = document.createElement('div');
        colorOption.className = `color-option note-\${color.toLowerCase()}`;
        colorOption.innerHTML = `<span style="background: var(--note-\${color.toLowerCase()}); width: 16px; height: 16px; border-radius: 50%; border: 1px solid rgba(0,0,0,0.2);"></span>`;
        colorOption.style.cssText = `
            padding: 8px;
            cursor: pointer;
            display: flex;
            justify-content: center;
        `;
        colorOption.onclick = () => {
            changeNoteColor(noteGuid, colors.indexOf(color));
                        
            if (popup) {
                popup.className = popup.className.replace(/note-(gray|yellow|green|blue|pink|orange|purple)/g, '').trim();
                popup.classList.add(`note-\${color.toLowerCase()}`);
            }
            optionsMenu.style.display = 'none';
            colorMenu.style.display = 'none';
        };
        colorMenu.appendChild(colorOption);
    });

    // Afficher le sous-menu
    changeColorItem.onclick = (e) => {
        const rect = e.target.getBoundingClientRect();
        colorMenu.style.top = `\${rect.top}px`;
        colorMenu.style.left = `\${rect.left - 130}px`;
        colorMenu.style.display = 'flex';
    };

    optionsMenu.appendChild(deleteBtn);
    optionsMenu.appendChild(changeColorItem);

    return { element: optionsMenu, colorMenu: colorMenu };
}
       
          // Fonctions spécialisées 
          function showVerseDialog(article, verses) {
              showDialog({
                  title: verses.title,
                  type: 'verse',
                  article: article,
                  contentRenderer: (contentContainer) => {
                      verses.items.forEach((item, index) => {
                          const infoBar = document.createElement('div');
                          infoBar.style.cssText = `
                              display: flex;
                              align-items: center;
                              padding-inline: 10px;
                              padding-block: 6px;
                              background: \${isDarkTheme() ? '#000000' : '#f1f1f1'};
                              border-bottom: 1px solid \${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)'};
                          `;
                         
                          const img = document.createElement('img');
                          img.src = 'file://' + item.imageUrl;
                          img.style.cssText = `
                              height: 50px;
                              width: 50px;
                              border-radius: 8px;
                              object-fit: cover;
                              margin-right: 8px;
                              box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                          `;
                          
                          const textContainer = document.createElement('div');
                          textContainer.style.cssText = 'flex-grow: 1; margin-left: 8px; padding: 8px 0;';
                          
                          const pubText = document.createElement('div');
                          pubText.textContent = item.publicationTitle;
                          pubText.style.cssText = `
                              font-size: 16px;
                              font-weight: 700;
                              margin-bottom: 4px;
                              line-height: 1.3;
                              white-space: nowrap;
                              overflow: hidden;
                              text-overflow: ellipsis;
                          `;
                          
                          const subtitleText = document.createElement('div');
                          subtitleText.textContent = item.subtitle;
                          subtitleText.style.cssText = `
                              font-size: 12px;
                              opacity: 0.8;
                              line-height: 1.4;
                              white-space: nowrap;
                              overflow: hidden;
                              text-overflow: ellipsis;
                          `;
                          
                          textContainer.appendChild(pubText);
                          textContainer.appendChild(subtitleText);
                          
                          infoBar.addEventListener('click', function() {
                              window.flutter_inappwebview?.callHandler('openMepsDocument', item);
                          });
                          
                          infoBar.appendChild(img);
                          infoBar.appendChild(textContainer);
                          
                          const article = document.createElement('div');
                          article.innerHTML = `<article id="verse-dialog" class="\${item.className}">\${item.content}</article>`;
                          article.style.cssText = `
                            padding-top: 10px;
                            padding-bottom: 16px;
                          `;
                       
                          wrapWordsWithSpan(article, true);
                          
                          item.highlights.forEach(h => {
                            if (h.Identifier >= item.firstVerseNumber && h.Identifier <= item.lastVerseNumber) {
                               const target = getTarget(article, true, h.Identifier);
                               addHighlight([target], h.BlockType, h.Identifier, h.StartToken, h.EndToken, h.UserMarkGuid, h.ColorIndex);
                            }
                          });
                          
                          item.notes.forEach(note => {
                            if (note.BlockIdentifier >= item.firstVerseNumber && note.BlockIdentifier <= item.lastVerseNumber) {
                              const matchingHighlight = item.highlights.find(h => h.UserMarkGuid === note.UserMarkGuid);
                              
                              // If no matching highlight is found, skip this note (faire pour ajouter les notes sans highlights)
                              if(!matchingHighlight) return;
                              
                              const target = getTarget(article, true, note.BlockIdentifier);
                              
                              addNoteWithGuid(
                                article,
                                target,
                                matchingHighlight?.UserMarkGuid || null,
                                note.Guid,
                                note.ColorIndex ?? 0,
                                true
                              );
                            }
                          });
                          
                          article.addEventListener('click', async (event) => {
                              onClickOnPage(article, event.target);
                          });
                          
                          repositionAllNotes(article);
                          
                          contentContainer.appendChild(infoBar);
                          contentContainer.appendChild(article);
                      });
                  }
              });
          }
          
          function showVerseReferencesDialog(article, verseReferences) {
              showDialog({
                  title: verseReferences.title || 'Références bibliques',
                  type: 'verse-references',
                  article: article,
                  contentRenderer: (contentContainer) => {
                      verseReferences.items.forEach((item, index) => {
                          // Conteneur principal pour chaque référence
                          const referenceItem = document.createElement('div');
                          referenceItem.style.cssText = `
                              background: transparent;
                              transition: all 0.2s ease;
                              cursor: pointer;
                          `;
                        
                          // Header avec référence biblique
                          const headerBar = document.createElement('div');
                          headerBar.style.cssText = `
                              display: flex;
                              align-items: center;
                              padding: 16px;
                              background: transparent;
                          `;
                          
                          // Icône Bible (optionnel)
                          const bibleIcon = document.createElement('div');
                          bibleIcon.innerHTML = '📖'; // Vous pouvez remplacer par votre icône JW
                          bibleIcon.style.cssText = `
                              font-size: 24px;
                              margin-right: 16px;
                              width: 40px;
                              height: 40px;
                              display: flex;
                              align-items: center;
                              justify-content: center;
                              background: \${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)'};
                              border-radius: 50%;
                          `;
                          headerBar.appendChild(bibleIcon);
                          
                          // Conteneur des textes
                          const textContainer = document.createElement('div');
                          textContainer.style.cssText = 'flex-grow: 1;';
                          
                          // Référence biblique (ex: "Jean 3:16")
                          const verseReference = document.createElement('div');
                          verseReference.textContent = item.reference || item.title;
                          verseReference.style.cssText = `
                              font-size: inherit;
                              margin-bottom: 4px;
                              color: \${isDarkTheme() ? '#ffffff' : '#333333'};
                              line-height: 1.3;
                          `;
                          
                          textContainer.appendChild(verseReference);
                          
                          // Version/traduction (optionnel)
                          if (item.version) {
                              const version = document.createElement('div');
                              version.textContent = item.version;
                              version.style.cssText = `
                                  font-size: inherit;
                                  line-height: 1.4;
                              `;
                              textContainer.appendChild(version);
                          }
                          
                          headerBar.appendChild(textContainer);
                        
                          // Contenu du verset
                          const content = document.createElement('div');
                          content.innerHTML = item.content || item.text;
                          content.style.cssText = `
                              padding: 0 16px 16px 16px;
                              line-height: 1.7;
                              font-size: inherit;
                              background: transparent;
                              position: relative;
                          `;
                          
                          content.className = item.className || '';
                          
                          // Contexte supplémentaire (livre, chapitre, etc.)
                          if (item.context) {
                              const contextInfo = document.createElement('div');
                              contextInfo.textContent = item.context;
                              contextInfo.style.cssText = `
                                  padding: 8px 16px;
                                  font-size: 12px;
                                  opacity: 0.6;
                                  text-align: right;
                                  font-style: normal;
                              `;
                              content.appendChild(contextInfo);
                          }
                          
                          // Gestionnaire de clic pour tout l'élément
                          referenceItem.addEventListener('click', function() {
                              if (window.flutter_inappwebview) {
                                  window.flutter_inappwebview.callHandler('openBibleVerse', {
                                      reference: item.reference,
                                      book: item.book,
                                      chapter: item.chapter,
                                      verse: item.verse,
                                      endVerse: item.endVerse
                                  });
                              }
                          });
                          
                          // Assemblage
                          referenceItem.appendChild(headerBar);
                          referenceItem.appendChild(content);
                          contentContainer.appendChild(referenceItem);
                          
                          // Barre de séparation entre les références (sauf le dernier)
                          if (index < verseReferences.items.length - 1) {
                              const separator = document.createElement('div');
                              separator.style.cssText = `
                                  height: 2px;
                                  background: \${isDarkTheme() ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.15)'};
                                  margin: 20px 16px;
                                  border-radius: 1px;
                              `;
                              contentContainer.appendChild(separator);
                          }
                      });
                  }
              });
          }
          
          function showVerseInfoDialog(article, verseInfo) {
              showDialog({
                  title: verseInfo.title,
                  type: 'verse-info',
                  article: article,
                  contentRenderer: (contentContainer) => {
                      // Crée l'en-tête d'onglets
                      const tabBar = document.createElement('div');
                      tabBar.style.cssText = `
                          display: flex;
                          border-bottom: 1px solid \${isDarkTheme() ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)'};
                          background-color: \${isDarkTheme() ? '#111' : '#f9f9f9'};
                      `;
          
                      const tabs = [
                        { key: 'commentary', iconClass: 'jwi-bible-speech-balloon' },
                        { key: 'versions', iconClass: 'jwi-bible-comparison' },
                        { key: 'guide', iconClass: 'jwi-publications-pile' },
                        { key: 'footnotes', iconClass: 'jwi-bible-quote' },
                        { key: 'notes', iconClass: 'jwi-text-pencil' },
                      ];
                      
                      let currentTab = 'commentary';
                      
                      const tabButtons = tabs.map(({ key, iconClass }) => {
                        const btn = document.createElement('button');
                        btn.classList.add('jwf-jw-icons-external', iconClass);
                      
                        btn.style.cssText = `
                          flex: 1;
                          padding: 10px;
                          border: none;
                          background: none;
                          cursor: pointer;
                          font-size: 30px;
                          color: \${isDarkTheme() ? '#fff' : '#000'};
                          border-bottom: 2px solid \${key === currentTab ? (isDarkTheme() ? '#fff' : '#000') : 'transparent'};
                        `;
                      
                        btn.addEventListener('click', () => {
                          currentTab = key;
                          updateTabContent();
                      
                          tabButtons.forEach(b => {
                            b.style.borderBottom = '2px solid transparent';
                          });
                          btn.style.borderBottom = `2px solid \${isDarkTheme() ? '#fff' : '#000'}`;
                        });
                      
                        return btn;
                      });
          
                      tabButtons.forEach(btn => tabBar.appendChild(btn));
                      contentContainer.appendChild(tabBar);
          
                      // Conteneur pour le contenu dynamique
                      const dynamicContent = document.createElement('div');
                      dynamicContent.style.padding = '10px';
                      contentContainer.appendChild(dynamicContent);
          
                      function updateTabContent() {
                        dynamicContent.innerHTML = ''; // reset
                    
                        const key = currentTab.toLowerCase();
                        const items = verseInfo[key] || [];
                    
                        // Textes pour message vide
                        const emptyMessages = {
                            commentary: "Il n'y a pas de commentaire pour ce verset.",
                            versions: "Il n'y a pas d'autres versions pour ce verset.",
                            guide: "Il n'y a pas de guide pour ce verset.",
                            footnotes: "Il n'y a pas de notes de bas de page pour ce verset.",
                            notes: "Il n'y a pas de notes personnelles pour ce verset."
                        };
                    
                        // Si vide → afficher message
                        if (items.length === 0) {
                            const emptyDiv = document.createElement('div');
                            emptyDiv.style.cssText = `
                                padding: 15px;
                                font-style: italic;
                                opacity: 0.7;
                            `;
                            emptyDiv.textContent = emptyMessages[key] || "Aucun contenu disponible.";
                            dynamicContent.appendChild(emptyDiv);
                            return;
                        }
                    
                        if (key === 'notes') {
                            items.forEach((item) => {
                                const article = document.createElement('div');
                                article.innerHTML = `
                                    <article id="verse-info-dialog" class="\${item.className || ''}">
                                        <h3>\${item.Title}</h3>
                                        <p>\${item.Content}</p>
                                    </article>
                                `;
                                article.addEventListener('click', async (event) => {
                                    onClickOnPage(article, event.target);
                                });
                                dynamicContent.appendChild(article);
                            });
                        } 
                        else {
                            items.forEach((item) => {
                                const article = document.createElement('div');
                                article.innerHTML = `
                                    <article id="verse-info-dialog" class="\${item.className}">
                                        \${item.content}
                                    </article>
                                `;
                                article.addEventListener('click', async (event) => {
                                    onClickOnPage(article, event.target);
                                });
                                dynamicContent.appendChild(article);
                            });
                        }
                    }
          
                      updateTabContent(); // initial display
                  }
              });
          }
          
          function showExtractPublicationDialog(article, extractData) {
              showDialog({
                  title: extractData.title || 'Extrait de publication',
                  type: 'publication',
                  article: article,
                  contentRenderer: (contentContainer) => {
                      extractData.items.forEach((item, index) => {
                          // Conteneur principal pour chaque extrait
                          const extractItem = document.createElement('div');
                          extractItem.style.cssText = `
                              overflow: hidden;
                              transition: all 0.2s ease;
                              cursor: pointer;
                          `;
                          
                          // Header avec image et infos
                          const headerBar = document.createElement('div');
                          headerBar.style.cssText = `
                              display: flex;
                              align-items: center;
                              padding-inline: 8px;
                              padding-block: 8px;
                              background: \${isDarkTheme() ? '#000000' : '#f1f1f1'};
                              border-bottom: 1px solid \${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)'};
                          `;
                          
                          // Image de la publication
                          if (item.imageUrl) {
                              const img = document.createElement('img');
                              img.src = 'file://' + item.imageUrl;
                              img.style.cssText = `
                                  height: 50px;
                                  width: 50px;
                                  border-radius: 8px;
                                  object-fit: cover;
                                  margin-right: 8px;
                                  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                              `;
                              headerBar.appendChild(img);
                          }
                          
                          headerBar.addEventListener('click', function() {
                              window.flutter_inappwebview.callHandler('openMepsDocument', {
                                      mepsDocumentId: item.mepsDocumentId,
                                      mepsLanguageId: item.mepsLanguageId,
                                      startParagraphId: item.startParagraphId,
                                      endParagraphId: item.endParagraphId
                                  });
                          });
                          
                          // Conteneur des textes
                          const textContainer = document.createElement('div');
                          textContainer.style.cssText = 'flex-grow: 1;';
                          
                          // Conteneur horizontal pour le titre et le sous-titre
                          const titleRow = document.createElement('div');
                          titleRow.style.cssText = `
                            display: flex;
                            align-items: center;
                            gap: 8px; /* espace entre titre et sous-titre */
                            overflow: hidden;
                          `;
                          
                          // Titre de la publication
                          const pubTitle = document.createElement('div');
                          pubTitle.textContent = item.publicationTitle;
                          pubTitle.style.cssText = `
                            font-size: 16px;
                            font-weight: 700;
                            margin-bottom: 4px;
                            color: \${isDarkTheme() ? '#ffffff' : '#333333'};
                            line-height: 1.3;
                            white-space: nowrap;
                            overflow: hidden;
                            text-overflow: ellipsis;
                          `;
                          
                          // Sous-titre (en dessous du titre)
                          if (item.subtitle) {
                            const subtitle = document.createElement('div');
                            subtitle.textContent = item.subtitle;
                            subtitle.style.cssText = `
                              font-size: 12px;
                              opacity: 0.8;
                              line-height: 1.4;
                              white-space: nowrap;
                              overflow: hidden;
                              text-overflow: ellipsis;
                            `;
                            textContainer.appendChild(pubTitle);
                            textContainer.appendChild(subtitle);
                          } else {
                            textContainer.appendChild(pubTitle);
                          }
                          
                          textContainer.appendChild(titleRow);
                         
                          headerBar.appendChild(textContainer);
                         
                          const article = document.createElement('div');
                          article.innerHTML = `<article id="publication-dialog" class="\${item.className}">\${item.content}</article>`;
                          article.style.cssText = `
                            padding-block: 16px;
                            line-height: 1.7;
                            font-size: inherit;
                          `;
                       
                          wrapWordsWithSpan(article, false);
                          
                          item.highlights.forEach(h => {
                            if ((item.startParagraphId == null || h.Identifier >= item.startParagraphId) && (item.endParagraphId == null || h.Identifier <= item.endParagraphId)) {
                              const target = getTarget(article, false, h.Identifier);
                              addHighlight(
                                [target],
                                h.BlockType,
                                h.Identifier,
                                h.StartToken,
                                h.EndToken,
                                h.UserMarkGuid,
                                h.ColorIndex
                              );
                            }
                          });
                          
                          item.notes.forEach(note => {
                            const matchingHighlight = item.highlights.find(h => h.UserMarkGuid === note.UserMarkGuid);
                        
                            addNoteWithGuid(
                              article,
                              null,
                              matchingHighlight?.UserMarkGuid || null,
                              note.Guid,
                              note.ColorIndex ?? 0,
                              false
                            );
                          });      
                          
                          article.addEventListener('click', async (event) => {
                              onClickOnPage(article, event.target);
                          });
                          
                          article.querySelectorAll('img').forEach(img => {
                            img.onerror = () => {
                              img.style.display = 'none';  // Cache l'image si elle ne charge pas
                            }
                          });

                          // Assemblage
                          extractItem.appendChild(headerBar);
                          extractItem.appendChild(article);
                          contentContainer.appendChild(extractItem);
                          
                          // Séparateur entre les éléments (sauf le dernier)
                          if (index < extractData.items.length - 1) {
                              const separator = document.createElement('div');
                              separator.style.cssText = `
                                  height: 3px;
                                  background: \${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
                                  margin: 12px 0px;
                              `;
                              contentContainer.appendChild(separator);
                          }
                      });
                  }
              });
          }
          
          function showFootNoteDialog(article, footnote) {
              showDialog({
                  title: footnote.title,
                  type: 'footnote',
                  article: article,
                  contentRenderer: (contentContainer) => {
                      const noteContainer = document.createElement('div');
                      noteContainer.style.cssText = `
                          padding-inline: 20px;
                      `;
                      
                      const noteContent = document.createElement('div');
                      noteContent.innerHTML = footnote.content;
                      noteContent.style.cssText = `
                          line-height: 1.7;
                          font-size: inherit;
                      `;
                      
                      noteContent.addEventListener('click', async (event) => {
                        onClickOnPage(noteContainer, event.target);
                      });
                      
                      noteContainer.appendChild(noteContent);
                      contentContainer.appendChild(noteContainer);
                  }
              });
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
              
              addNoteWithGuid(pageCenter, paragraph, null, noteGuid.uuid, 0, isBible);
              closeToolbar();
              removeAllSelected();
          }
          
          async function removeNote(noteGuid, dialog) {
            if (!noteGuid) return; // Sécurité
          
            let confirmed = true;
          
            if (dialog) {
              confirmed = await window.flutter_inappwebview.callHandler('showConfirmationDialog', {
                title: 'Supprimer la note',
                message: 'Êtes-vous sûr de vouloir supprimer cette note ?'
              });
          
              if (!confirmed) return; // Annulation
            }
          
            const note = pageCenter.querySelector(`[data-note-id="\${noteGuid}"]`);
            if (note) {
              note.remove();
            }
          
            await window.flutter_inappwebview.callHandler('removeNote', {
              guid: noteGuid
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
              const paragraphs = paragraphInfo.paragraphs;
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
              
              addNoteWithGuid(pageCenter, paragraphs[0], highlightGuid, noteGuid.uuid, colorIndex, isVerse);
              closeToolbar();
              removeAllSelected();
          }
          
          function repositionNote(noteGuid) {
            if (!noteGuid) return; // Sécurité
          
            const note = pageCenter.querySelector(`[data-note-id="\${noteGuid}"]`);
            if (note) {
              let target = null;
              const blockId = note.getAttribute('data-note-block-id');
              const idAttr = isBible() ? 'id' : 'data-pid';
              target = pageCenter.querySelector(`[\${idAttr}="\${blockId}"]`);
              
              if (target) {
                getNotePosition(pageCenter, target, note);
              }
            }
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
              const hasAudio = cachedPages[currentIndex]?.audiosMarkers?.some(m => String(m.mepsParagraphId) === pid) ?? false;
              
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
              const verseElements = pageCenter.querySelectorAll(`[\${idAttr}^="\${versePattern}"]`);
            
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
                addBookmark(pageCenter, p, bookmark.BlockType, bookmark.BlockIdentifier, bookmark.Slot);
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
                  pageCenter,
                  p,
                  matchingHighlight?.UserMarkGuid || null,
                  note.Guid,
                  note.ColorIndex ?? 0,
                  isBible()
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
            
            repositionAllNotes(pageCenter);
            repositionAllBookmarks(pageCenter);
          }
          
          function resizeAllTextAreaHeight(article) {
            const textAreas = article.querySelectorAll('textarea');
            textAreas.forEach(textarea => {
              textarea.rows = 1;
              textarea.style.height = 'auto';
              textarea.style.height = `\${textarea.scrollHeight + 4}px`;
            });
          }
          
          function getTarget(article, isBible, id) {
            if (isBible) {
              const elements = article.querySelectorAll('.v');
              
              for (const el of elements) {
                const idAttr = el.getAttribute('id');
                const idParts = idAttr.split('-');
                const thirdPart = idParts[2];
                
                if (thirdPart === String(id)) {
                  return el;
                }
              }
            } 
            else {
              return article.querySelector(`[data-pid="\${id}"]`);
            }
          
            return null;
          }
          
          function getBookmarkPosition(article, target, bookmark) {
             // Calculer la position après le rendu
             const targetRect = target.getBoundingClientRect();
             const pageRect = article.getBoundingClientRect();
             const topRelativeToPage = targetRect.top - pageRect.top + article.scrollTop;
          
             bookmark.style.top = `\${topRelativeToPage + 3}px`;
          }
          
          function repositionAllBookmarks(article) {
            const bookmarks = document.querySelectorAll('.bookmark-icon');
            bookmarks.forEach(bookmark => {
              const id = bookmark.getAttribute('bookmark-id');
              let target = getTarget(article, isBible(), id);
              getBookmarkPosition(article, target, bookmark);
            });
          }
          
          function addBookmark(article, target, blockType, blockIdentifier, slot) {
            if(!article) {
              article = pageCenter;
            }
            if (!target) {
              target = getTarget(article, isBible(), blockIdentifier);
            }
          
            const imgSrc = bookmarkAssets[slot];
            if (imgSrc && target) {
              requestAnimationFrame(() => {
                const bookmark = document.createElement('img');
                bookmark.setAttribute('bookmark-id', blockIdentifier);
                bookmark.setAttribute('slot', slot);
                bookmark.src = imgSrc;
                bookmark.classList.add('bookmark-icon');
          
                getBookmarkPosition(article, target, bookmark);
                article.appendChild(bookmark);
              });
            }
          }
          
          function removeBookmark(article, blockIdentifier, slot) {
            if(!article) {
              article = pageCenter;
            }
            const bookmark = article.querySelector(`.bookmark-icon[bookmark-id="\${blockIdentifier}"]`);
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
            const allTokens = targets
            .filter(target => target) // remove null/undefined
            .flatMap(target =>
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
          
          function getNotePosition(article, element, noteIndicator) {
             if(!element.classList.contains('word') && !element.classList.contains('punctuation')) {
               element = element.querySelector('.word, .punctuation');
             }
             const targetRect = element.getBoundingClientRect();
             const pageRect = article.getBoundingClientRect();
             const topRelativeToPage = targetRect.top - pageRect.top + article.scrollTop;
              
             const targetHeight = targetRect.height;
             const noteHeight = 15; // hauteur du carré
             const topOffset = topRelativeToPage + (targetHeight - noteHeight) / 2;
              
             noteIndicator.style.top = `\${topOffset}px`;
          }
          
          function repositionAllNotes(article) {
            const notes = document.querySelectorAll('[data-note-id]');
            notes.forEach(note => {
              let target = null;
              if(note.hasAttribute('data-note-highlight-id')) {
                 const highlightGuid = note.getAttribute('data-note-highlight-id');
                 target = article.querySelector(`[data-highlight-id="\${highlightGuid}"]`);
              }
              else {
                const blockId = note.getAttribute('data-note-block-id');
                const idAttr = isBible() ? 'id' : 'data-pid';
                target = article.querySelector(`[\${idAttr}="\${blockId}"]`);
              }
            
              if (target) {
                getNotePosition(article, target, note);
              }
            });
          }

          function addNoteWithGuid(article, target, highlightGuid, noteGuid, colorIndex, isBible) {
            if (!target) {
              const highlightTarget = article.querySelector(`[data-highlight-id="\${highlightGuid}"]`);
              if (highlightTarget) {
                target = isBible ? highlightTarget.closest('.v') : highlightTarget.closest('p');
              }
            }
            
            if (!target) {
              return;
            }
            
            const idAttr = isBible ? 'id' : 'data-pid';
        
            // Chercher le premier élément surligné si highlightGuid est donné
            let firstHighlightedElement = null;
            if (highlightGuid) {
                firstHighlightedElement = target.querySelector(`[data-highlight-id="\${highlightGuid}"]`);
            }
       
            // Créer le carré de note
            const noteIndicator = document.createElement('div');
            noteIndicator.className = 'note-indicator';
            noteIndicator.setAttribute('data-note-id', noteGuid);
            if(highlightGuid) {
              noteIndicator.setAttribute('data-note-highlight-id', highlightGuid);
            }
            noteIndicator.setAttribute('data-note-block-id', target.getAttribute(idAttr));
        
            // Couleurs
            const colors = ["gray", "yellow", "green", "blue", "pink", "orange", "purple"];
            const colorName = colors[colorIndex] || "gray";
            noteIndicator.classList.add(`note-indicator-\${colorName}`);
        
            // Détecter si le target (paragraphe) est dans une liste ul/ol
            const targetUl = target.closest('ul');
            const isInList = target.tagName === 'P' && target.hasAttribute(idAttr) && targetUl && targetUl.classList.contains('source');
        
            // Calcul de position différent si pas de firstHighlightedElement
            if (firstHighlightedElement) {
                getNotePosition(article, firstHighlightedElement, noteIndicator);
        
                // Positionner à droite si élément est à droite
                const elementRect = firstHighlightedElement.getBoundingClientRect();
                const windowWidth = window.innerWidth || document.documentElement.clientWidth;
        
                if (elementRect.left > windowWidth / 2) {
                    noteIndicator.style.right = '3.3px';
                    noteIndicator.style.left = 'auto';
                } 
                else {
                    noteIndicator.style.left = '3.3px';
                    noteIndicator.style.right = 'auto';
                }
            } 
            else {
                getNotePosition(article, target, noteIndicator);
        
                // Positionner à droite si élément est à droite
                const elementRect = target.getBoundingClientRect();
                const windowWidth = window.innerWidth || document.documentElement.clientWidth;
        
                if (elementRect.left > windowWidth / 2) {
                    noteIndicator.style.right = '3.3px';
                    noteIndicator.style.left = 'auto';
                } 
                else {
                    noteIndicator.style.left = '3.3px';
                    noteIndicator.style.right = 'auto';
                }
            }
        
            // Clic pour afficher la note
            noteIndicator.addEventListener('click', (e) => {
                e.stopPropagation();
                //showNotePopup(highlightGuid, noteGuid, e.pageX, e.pageY);
                openNoteDialog(highlightGuid, noteGuid);
            });
            
            // Clic pour supprimer la note
            noteIndicator.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                removeNote(noteGuid, true);
            });
        
            // Ajouter le carré au container principal
            article.appendChild(noteIndicator);
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
              guid: guid,
              showAlertDialog: true
            });
          }
    
          // Fonction utilitaire pour changer la couleur d'un surlignage spécifique
          function changeHighlightColor(guid, newColorIndex) {
            const colors = ["transparent", "yellow", "green", "blue", "pink", "orange", "purple"];
            const noteColors = ["gray", "yellow", "green", "blue", "pink", "orange", "purple"];
            
            const highlightedElements = pageCenter.querySelectorAll(`[data-highlight-id="\${guid}"]`);
            const newHighlightClass = `highlight-\${colors[newColorIndex] || "transparent"}`;
            
            highlightedElements.forEach(element => {
              // Supprimer toutes les classes de surlignage existantes
              element.classList.remove(
                'highlight-transparent', 'highlight-yellow', 'highlight-green',
                'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple'
              );
              // Ajouter la nouvelle classe de couleur
              element.classList.add(newHighlightClass);
            });
            
            const noteElements = pageCenter.querySelectorAll(`[data-note-highlight-id="\${guid}"]`);
            
            if (noteElements.length !== 0) {
              const colorName = noteColors[newColorIndex] || "gray";
              
              noteElements.forEach(element => {
                // Supprimer les anciennes classes note-indicator-*
                element.className = element.className.replace(/note-indicator-(gray|yellow|green|blue|pink|orange|purple)/g, '').trim();
                // Ajouter la nouvelle classe
                element.classList.add(`note-indicator-\${colorName}`);
              });
            }
            
            // Appel Flutter
            window.flutter_inappwebview.callHandler('changeHighlightColor', {
              guid: guid,
              newColorIndex: newColorIndex
            });
          }
          
          // Fonction utilitaire pour changer la couleur d'une note
          function changeNoteColor(noteGuid, newColorIndex) {
            const note = pageCenter.querySelector(`[data-note-id="\${noteGuid}"]`);
            const colors = ["gray", "yellow", "green", "blue", "pink", "orange", "purple"];
            const colorName = colors[newColorIndex] || "gray";

            note.className = note.className.replace(/note-indicator-(yellow|green|blue|pink|orange|purple)/g, '').trim();
            note.classList.add(`note-indicator-\${colorName}`);
            
            if(note.hasAttribute('data-note-highlight-id')) {
              const highlightGuid = note.getAttribute('data-note-highlight-id');
              highlightedElements = pageCenter.querySelectorAll(`[data-highlight-id="\${highlightGuid}"]`);
              const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][newColorIndex]}`;
              
              highlightedElements.forEach(element => {
                element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
                element.classList.add(newHighlightClass);
              });
            }
            
            window.flutter_inappwebview.callHandler('changeNoteColor', {
              guid: noteGuid,
              newColorIndex: newColorIndex
            });
          }
          
          function resizeFont(size) {
            document.body.style.fontSize = size + 'px';
            resizeAllTextAreaHeight(pageCenter);
            repositionAllNotes(pageCenter);
            repositionAllBookmarks(pageCenter);
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
          
            // Charger la page principale
            await loadIndexPage(currentIndex, true);
            pageCenter.scrollTop = 0;
            pageCenter.scrollLeft = 0;
            
            // Afficher la page (avec fondu)
            pageCenter.classList.add('visible');
            window.flutter_inappwebview.callHandler('fontsLoaded');
            
            const article = document.getElementById("article-center");
            wrapWordsWithSpan(article, isBible());

            // Ajouter la scrollBar
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
          
            // Informer Flutter que la page principale est chargée
            await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
          
            // Attendre que les polices soient prêtes
            await document.fonts.ready;
          
            // Charger les données utilisateur (notes/bookmarks, etc.)
            await loadUserdata();
            
            if (${wordsSelected.isNotEmpty}) {
              selectWords(${jsonEncode(wordsSelected)}, false);
            }
          
            // Appliquer les scrolls ou sélections APRÈS que tout est visible
            if ($startParagraphId != null && $endParagraphId != null) {
              jumpToIdSelector('[data-pid]', 'data-pid', $startParagraphId, $endParagraphId);
            } 
            else if ($startVerseId != null && $endVerseId != null) {
              jumpToIdSelector('.v', 'id', $startVerseId, $endVerseId);
            }
            else if($textTag != null) {
              jumpToTextTag($textTag);
            }
          
            // Charger les pages autour
            await loadPrevAndNextPages(currentIndex);
          }
          
          init();
          
          let lastScrollTop = 0;
          let lastDirection = null;
          
          let directionChangePending = false;
          let directionChangeStartTime = 0;
          let directionChangeStartScroll = 0;
          let directionChangeTargetDirection = null;
          let appBarHeight = 90;    // hauteur de l'AppBar
          let bottomNavBarHeight = 85; // hauteur de la BottomBar
          
          const DIRECTION_CHANGE_THRESHOLD_MS = 250;
          const DIRECTION_CHANGE_THRESHOLD_PX = 40;
   
          pageCenter.addEventListener("scroll", () => {
            closeToolbar();
            if (isLongPressing || isChangingParagraph) return;
          
            const scrollTop = pageCenter.scrollTop;
            const scrollHeight = pageCenter.scrollHeight;
            const clientHeight = pageCenter.clientHeight;
          
            const scrollDelta = scrollTop - lastScrollTop;
            const scrollDirection = scrollDelta > 0 ? "down" : scrollDelta < 0 ? "up" : "none";
            const now = Date.now();
          
            // Détection de changement de direction
            if (
              scrollDirection !== "none" &&
              scrollDirection !== lastDirection &&
              !directionChangePending
            ) {
              directionChangePending = true;
              directionChangeStartTime = now;
              directionChangeStartScroll = scrollTop;
              directionChangeTargetDirection = scrollDirection;
            }
          
            // Validation d’un geste franc
            if (directionChangePending && scrollDirection === directionChangeTargetDirection) {
              const timeDiff = now - directionChangeStartTime;
              const scrollDiff = Math.abs(scrollTop - directionChangeStartScroll);
          
              if (timeDiff < DIRECTION_CHANGE_THRESHOLD_MS && scrollDiff > DIRECTION_CHANGE_THRESHOLD_PX) {
                if(isFullscreenMode) {
                  window.flutter_inappwebview.callHandler('onScroll', scrollTop, scrollDirection);
                  lastDirection = scrollDirection;
                  directionChangePending = false;
                  
                  const floatingButton = document.getElementById('dialogFloatingButton');
                  
                  if(scrollDirection === 'down') {
                     controlsVisible = false;
                     if (!floatingButton) return;
                     floatingButton.style.opacity = '0';
                  }
                  else if(scrollDirection === 'up') {
                    controlsVisible = true;
                    if (!floatingButton) return;
                    floatingButton.style.opacity = '1';
                  }
                }
              } 
              else if (timeDiff >= DIRECTION_CHANGE_THRESHOLD_MS) {
                directionChangePending = false;
              }
            }
          
            lastScrollTop = scrollTop;
            scrollTopPages[currentIndex] = scrollTop;
          
            // Affichage automatique en haut de page
            if (scrollTop === 0) {
              appBarHeight = APPBAR_FIXED_HEIGHT;
              bottomNavBarHeight = BOTTOMNAVBAR_FIXED_HEIGHT;
            } else if (scrollDirection === 'down') {
              // Masquer les barres
              appBarHeight = 0;
              bottomNavBarHeight = 0;
            } else if (scrollDirection === 'up') {
              // Afficher les barres
              appBarHeight = APPBAR_FIXED_HEIGHT;
              bottomNavBarHeight = BOTTOMNAVBAR_FIXED_HEIGHT;
            }
          
            // Scroll-bar
            const scrollableHeight = scrollHeight - clientHeight;
            const visibleHeight = window.innerHeight - bottomNavBarHeight - APPBAR_FIXED_HEIGHT;
            const scrollRatio = scrollTop / scrollableHeight;
            const scrollBarTop = APPBAR_FIXED_HEIGHT + (visibleHeight - scrollBar.offsetHeight) * scrollRatio;
            scrollBar.style.top = `\${scrollBarTop}px`;
          });
          
          // Variables globales pour éviter les redéclarations
          let currentGuid = '';
          let pressTimer = null;
          let firstLongPressTarget = null;
          let lastLongPressTarget = null;
          let isLongPressing = false;
          let isLongTouchFix = false;
          let isSelecting = false;
          let sideHandle = null;
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
          
          async function onClickOnPage(article, target) {
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
          
            const classList = target.classList; 
                        
            // Utilisation de classList.contains avec cache
            const matchedElement = target.closest('a');
        
            if(matchedElement) {
              const linkClassList = matchedElement.classList; 
              const href = matchedElement.getAttribute('href');

              if (href.startsWith('#')) {
                const targetElement = pageCenter.querySelector(href);
              
                if (targetElement) {
                  targetElement.scrollIntoView({
                    behavior: 'smooth', // pour un défilement fluide
                    block: 'center',    // centre l'élément dans la vue
                  });
                }
              
                closeToolbar();
                return;
              }
              
              if (linkClassList.contains('b')) {
                const verses = await window.flutter_inappwebview.callHandler('fetchVerses', href);
                showVerseDialog(article, verses);
                closeToolbar();
                return;
              }
      
              if(href.startsWith('jwpub://p/')) {
                const extract = await window.flutter_inappwebview.callHandler('fetchExtractPublication', href);
                if (extract != null) {
                  showExtractPublicationDialog(article, extract);
                  closeToolbar();
                }
                return;
              }
              
              if(href.startsWith('jwpub://c/')) {
                const extract = await window.flutter_inappwebview.callHandler('fetchCommentaries', href);
                if (extract != null) {
                  //showExtractPublicationDialog(article, extract);
                  closeToolbar();
                }
                return;
              }
              
              closeToolbar();
              return;
            }
  
            if (classList.contains('fn')) {
              const fnid = target.getAttribute('data-fnid');
              const footnote = await window.flutter_inappwebview.callHandler('fetchFootnote', fnid);
              showFootNoteDialog(article, footnote);
              closeToolbar();
              return;
            }
            
            if (classList.contains('m')) {
              const mid = target.getAttribute('data-mid');
              const versesReference = await window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
              showVerseReferencesDialog(article, versesReference);
              closeToolbar();
              return;
            }
            
            if (classList.contains('gen-field')) {
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
              showToolbarHighlight(target, highlightId);
              return;
            }
            
            // Optimisation de la logique conditionnelle
            if (isBible()) {
              whenClickOnParagraph(target, '.v', 'id', 'verse');
              return;
            } 
            else {
              whenClickOnParagraph(target, '[data-pid]', 'data-pid', 'paragraph');
              return;
            }
          }
          
          // Gestionnaire d'événements click optimisé
          pageCenter.addEventListener('click', async (event) => {
            onClickOnPage(pageCenter, event.target);
          });
          
          // Gestionnaire touchstart optimisé
          pageCenter.addEventListener('touchstart', (event) => {
            // Vérification simple pour les handles
            if (event.target.classList.contains('handle-left') || event.target.classList.contains('handle-right')) {
              event.preventDefault();
              closeToolbar();
              isSelecting = true;
              sideHandle = event.target.classList.contains('handle-left') ? 'left' : 'right';
              setLongPressing(true);
            }
            else {
              if (pressTimer) clearTimeout(pressTimer);
              
              firstLongPressTarget = event.target;
              
              pressTimer = setTimeout(async () => {
                closeToolbar();
                removeAllSelected();
          
                const firstTargetClassList = firstLongPressTarget?.classList;
                if (firstLongPressTarget && firstTargetClassList && (firstTargetClassList.contains('word') || firstTargetClassList.contains('punctuation'))) {
                  try {
                    const uuid = await window.flutter_inappwebview.callHandler('getHighlightGuid');
                    currentGuid = uuid.guid;
                  
                    setLongPressing(true);
                    isLongTouchFix = true;
                  
                    const highlightId = firstLongPressTarget.getAttribute('data-highlight-id');
                    if (highlightId) {
                      const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
                  
                      // Récupérer tous les éléments avec l'ancien highlightId
                      const highlightElements = Array.from(pageCenter.querySelectorAll(`[data-highlight-id="\${highlightId}"]`));
                      
                      if (highlightElements.length > 0) {
                        // Mettre à jour tous les éléments avec le nouveau GUID et nouvelle classe
                        highlightElements.forEach(element => {
                          element.setAttribute('data-highlight-id', currentGuid);
                  
                          element.classList.remove(
                            'highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue',
                            'highlight-pink', 'highlight-orange', 'highlight-purple'
                          );
                          element.classList.add(newHighlightClass);
                        });
                  
                        // Mettre à jour les targets : le premier et le dernier élément du groupe
                        firstLongPressTarget = highlightElements[0];
                        lastLongPressTarget = highlightElements[highlightElements.length - 1];
                  
                        // Appeler la méthode pour supprimer l'ancien highlight dans Flutter
                        window.flutter_inappwebview.callHandler('removeHighlight', { 
                          guid: highlightId,
                          newGuid: currentGuid,
                          showAlertDialog: false
                        });
                      }
                    }
                  
                  } catch (error) {
                    console.error('Error getting highlight GUID:', error);
                  }
                }
              }, 200);
            }
          }, { passive: false });
          
          // Gestionnaire touchmove optimisé avec throttle
          const handleTouchMove = throttle((event) => {
            isLongTouchFix = false;
          
            if(isSelecting) {
              event.preventDefault(); // Empêche le scroll
              
              const touch = event.changedTouches[0];
              const x = touch.clientX;
              const y = touch.clientY;
              
              //updateMagnifier(x, y);
                
              const closestElement = getClosestElementHorizontally(x, y);
              const elementClassList = closestElement?.classList;
                
              if (closestElement && elementClassList && (elementClassList.contains('word') || elementClassList.contains('punctuation'))) {
                if(sideHandle === 'left') {
                  if(closestElement !== firstLongPressTarget) {
                    firstLongPressTarget = closestElement;
                    updateSelected();
                  }
                }
                else if(sideHandle === 'right') {
                  if(closestElement !== lastLongPressTarget) {
                    lastLongPressTarget = closestElement;
                    updateSelected();
                  }
                }
              }
            }
            else if (isLongPressing && currentGuid) {
              const touch = event.changedTouches[0];
              const x = touch.clientX;
              const y = touch.clientY;
              
              updateMagnifier(x, y);
                
              const closestElement = getClosestElementHorizontally(x, y);
              const elementClassList = closestElement?.classList;
                
              if (closestElement && elementClassList && (elementClassList.contains('word') || elementClassList.contains('punctuation'))) {
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
          
          pageCenter.addEventListener('touchmove', handleTouchMove, { passive: false });
          
          // Gestionnaire touchend optimisé
          pageCenter.addEventListener('touchend', (event) => {
            console.log('touchend');
            if (isLongTouchFix) {
              lastLongPressTarget = firstLongPressTarget;
              onLongPressEnd();
              isLongTouchFix = false;
            }
            else if (isSelecting) {
              isSelecting = false;
              sideHandle = null;
              //hideMagnifier();
              showSelectedToolbar(firstLongPressTarget);
              firstLongPressTarget = null;
              lastLongPressTarget = null;
            }
            else if (isLongPressing) {
              hideMagnifier();
              onLongPressEnd();
              firstLongPressTarget = null;
              lastLongPressTarget = null;
            }
            else if (pressTimer) {
              clearTimeout(pressTimer);
              pressTimer = null;
            }
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
  
          let oldHighlightsMap = new Map();
          
          function updateTempHighlight() {
            if (!firstLongPressTarget && !lastLongPressTarget) return;
          
            const firstParagraphInfo = getTheFirstTargetParagraph(firstLongPressTarget);
            const lastParagraphInfo = getTheFirstTargetParagraph(lastLongPressTarget);
            if (!firstParagraphInfo || !lastParagraphInfo) return;
            
            const firstParagraph = firstParagraphInfo.paragraphs[0];
            const lastParagraph = lastParagraphInfo.paragraphs[0];
            
            const paragraphs = getAllParagraphs(pageCenter);
            
            // Trouve l'index du groupe qui contient le paragraphe
            const firstIndex = paragraphs.findIndex(group => group.includes(firstParagraph));
            const lastIndex = paragraphs.findIndex(group => group.includes(lastParagraph));
            
            if (firstIndex === -1 || lastIndex === -1) return;
          
            const fromIndex = Math.min(firstIndex, lastIndex);
            const toIndex = Math.max(firstIndex, lastIndex);
          
            // 🔄 Inverser les cibles si nécessaire
            const startTarget = firstIndex <= lastIndex ? firstLongPressTarget : lastLongPressTarget;
            const endTarget = firstIndex <= lastIndex ? lastLongPressTarget  : firstLongPressTarget;
          
            const currentHighlightElements = Array.from(pageCenter.querySelectorAll(`[data-highlight-id="\${currentGuid}"]`));

            // Supprimer seulement les éléments temporaires qu'on a tracés
            currentHighlightElements.forEach(element => {
              element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
              element.removeAttribute('data-highlight-id');
            });
            
            oldHighlightsMap.forEach((value, token) => {
              if (value.highlightId) {
                token.setAttribute('data-highlight-id', value.highlightId);
              }
              if (value.highlightClass) {
                token.classList.add(value.highlightClass);
              }
            });
          
            const highlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
          
            requestAnimationFrame(() => {
              for (let i = fromIndex; i <= toIndex; i++) {
                const group = paragraphs[i]; // tableau d'éléments
            
                const allTokens = group.flatMap(paragraph =>
                  Array.from(paragraph.querySelectorAll('.word, .punctuation, .escape'))
                );
                const wordAndPunctTokens = allTokens.filter(token =>
                  token.classList.contains('word') || token.classList.contains('punctuation')
                );
            
                let startTokenIndex = 0;
                let endTokenIndex = wordAndPunctTokens.length - 1;
            
                const groupHasStart = group.some(p => p.contains(startTarget));
                const groupHasEnd = group.some(p => p.contains(endTarget));
            
                if (groupHasStart && groupHasEnd) {
                  const a = wordAndPunctTokens.indexOf(startTarget);
                  const b = wordAndPunctTokens.indexOf(endTarget);
                  if (a === -1 || b === -1) continue;
                  startTokenIndex = Math.min(a, b);
                  endTokenIndex = Math.max(a, b);
                } 
                else if (groupHasStart) {
                  const index = wordAndPunctTokens.indexOf(startTarget);
                  if (index === -1) continue;
                  startTokenIndex = index;
                } 
                else if (groupHasEnd) {
                  const index = wordAndPunctTokens.indexOf(endTarget);
                  if (index === -1) continue;
                  endTokenIndex = index;
                }
            
                for (let j = startTokenIndex; j <= endTokenIndex; j++) {
                  const token = wordAndPunctTokens[j];
                  if (!token.hasAttribute('data-highlight-id')) {
                    token.classList.add(highlightClass);
                    token.setAttribute('data-highlight-id', currentGuid);
                  } else {
                    oldHighlightsMap.set(token, {
                      highlightId: token.getAttribute('data-highlight-id'),
                      highlightClass: Array.from(token.classList).find(c => c.startsWith('highlight-'))
                    });
                    token.classList.remove(
                      'highlight-transparent',
                      'highlight-yellow',
                      'highlight-green',
                      'highlight-blue',
                      'highlight-pink',
                      'highlight-orange',
                      'highlight-purple'
                    );
                    token.removeAttribute('data-highlight-id');
                    token.classList.add(highlightClass);
                    token.setAttribute('data-highlight-id', currentGuid);
                  }
            
                  const tokenIndexInAll = allTokens.indexOf(token);
                  const next = allTokens[tokenIndexInAll + 1];
                  if (next?.classList.contains('escape') && j !== endTokenIndex) {
                    if (!next.hasAttribute('data-highlight-id')) {
                      next.classList.add(highlightClass);
                      next.setAttribute('data-highlight-id', currentGuid);
                    } else {
                      oldHighlightsMap.set(next, {
                        highlightId: next.getAttribute('data-highlight-id'),
                        highlightClass: Array.from(next.classList).find(c => c.startsWith('highlight-'))
                      });
                      next.classList.remove(
                        'highlight-transparent',
                        'highlight-yellow',
                        'highlight-green',
                        'highlight-blue',
                        'highlight-pink',
                        'highlight-orange',
                        'highlight-purple'
                      );
                      next.removeAttribute('data-highlight-id');
                      next.classList.add(highlightClass);
                      next.setAttribute('data-highlight-id', currentGuid);
                    }
                  }
                }
              }
            });
          }
          
          // Fonction optimisée pour mettre à jour l'affichage de la sélection
          function updateSelected() {
            if (!firstLongPressTarget || !lastLongPressTarget) return;
            
            const firstParagraphInfo = getTheFirstTargetParagraph(firstLongPressTarget);
            const lastParagraphInfo = getTheFirstTargetParagraph(lastLongPressTarget);
            if (!firstParagraphInfo || !lastParagraphInfo) return;
            
            const firstParagraph = firstParagraphInfo.paragraphs[0];
            const lastParagraph = lastParagraphInfo.paragraphs[0];
            
            const paragraphs = getAllParagraphs(pageCenter);
            
            // Trouve l'index du groupe qui contient le paragraphe
            const firstIndex = paragraphs.findIndex(group => group.includes(firstParagraph));
            const lastIndex = paragraphs.findIndex(group => group.includes(lastParagraph));
            
            if (firstIndex === -1 || lastIndex === -1) return;
            
            const fromIndex = Math.min(firstIndex, lastIndex);
            const toIndex = Math.max(firstIndex, lastIndex);
          
            const startTarget = firstIndex <= lastIndex ? firstLongPressTarget : lastLongPressTarget;
            const endTarget = firstIndex <= lastIndex ? lastLongPressTarget : firstLongPressTarget;
          
            // ❌ Clear previous selections and handles
            pageCenter.querySelectorAll('.word.selected, .punctuation.selected, .escape.selected').forEach(token => {
              token.classList.remove('selected');
            });
            pageCenter.querySelectorAll('.handle, .handle-left, .handle-right').forEach(handle => handle.remove());
            
            for (let i = fromIndex; i <= toIndex; i++) {
              const group = paragraphs[i]; // tableau d'éléments
          
              const allTokens = group.flatMap(paragraph =>
                Array.from(paragraph.querySelectorAll('.word, .punctuation, .escape'))
              );
              const wordAndPunctTokens = allTokens.filter(token =>
                token.classList.contains('word') || token.classList.contains('punctuation')
              );
              
              if (wordAndPunctTokens.length === 0) return;
          
              // Trouver les indices de début et fin dans l'ensemble
              let startIndex = 0;
              let endIndex = wordAndPunctTokens.length - 1;
            
              const groupHasStart = group.some(p => p.contains(startTarget));
              const groupHasEnd = group.some(p => p.contains(endTarget));
            
              if (groupHasStart && groupHasEnd) {
                const a = wordAndPunctTokens.indexOf(startTarget);
                const b = wordAndPunctTokens.indexOf(endTarget);
                if (a === -1 || b === -1) return;
                startIndex = Math.min(a, b);
                endIndex = Math.max(a, b);
              } 
              else if (groupHasStart) {
                const index = wordAndPunctTokens.indexOf(startTarget);
                if (index !== -1) startIndex = index;
              } 
              else if (groupHasEnd) {
                const index = wordAndPunctTokens.indexOf(endTarget);
                if (index !== -1) endIndex = index;
              }
            
              // ✅ Sélectionner les tokens
              for (let j = startIndex; j <= endIndex; j++) {
                const token = wordAndPunctTokens[j];
                if (!token.isConnected) continue;
                token.classList.add('selected');
            
                const tokenIndex = allTokens.indexOf(token);
                const next = allTokens[tokenIndex + 1];
                if (next?.classList.contains('escape') && j !== endIndex) {
                  next.classList.add('selected');
                }
              }
            
              // ✅ Ajouter les handles aux extrémités
              if (firstLongPressTarget && lastLongPressTarget) {
                const createHandle = (src, className) => {
                  const handle = document.createElement('img');
                  handle.src = src;
                  handle.classList.add('handle', className);
                  return handle;
                };
            
                try {
                  startTarget.appendChild(createHandle(handleLeft, 'handle-left'));
                  endTarget.appendChild(createHandle(handleRight, 'handle-right'));
                } catch (e) {
                  console.warn('Failed to add handles:', e);
                }
              }
            }
          }
           
          // Fonction onLongPressEnd optimisée avec gestion d'erreurs et cache tokens
          async function onLongPressEnd() {
            if (isLongTouchFix) {!
              updateSelected();
              showSelectedToolbar(firstLongPressTarget);
            }
            else {
              let currentParagraph = [];
              let currentParagraphId = -1;
              let currentIsVerse = false;
              let firstTarget = null;
              let lastTarget = null;
              
              const highlightsToSend = [];
              let tempHighlightElements = Array.from(pageCenter.querySelectorAll(`[data-highlight-id="\${currentGuid}"]`));
              
              oldHighlightsMap.forEach((value, token) => {
                if(token === tempHighlightElements[tempHighlightElements.length - 1] || token === tempHighlightElements[0]) {
                  const highlightId = value.highlightId;
                  if (highlightId) {
                    const newHighlightClass = `highlight-\${["transparent", "yellow", "green", "blue", "pink", "orange", "purple"][highlightColorIndex]}`;
                  
                    // Récupérer tous les éléments avec l'ancien highlightId
                    const highlightElements = Array.from(pageCenter.querySelectorAll(`[data-highlight-id="\${highlightId}"]`));
                      
                    if (highlightElements.length > 0) {
                      // Mettre à jour tous les éléments avec le nouveau GUID et nouvelle classe
                      highlightElements.forEach(element => {
                        element.setAttribute('data-highlight-id', currentGuid);
                  
                        element.classList.remove('highlight-transparent', 'highlight-yellow', 'highlight-green', 'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple');
                        element.classList.add(newHighlightClass);
                      });
                      
                      tempHighlightElements.push(...highlightElements);
                     
                      // Appeler la méthode pour supprimer l'ancien highlight dans Flutter
                      window.flutter_inappwebview.callHandler('removeHighlight', { 
                        guid: highlightId,
                        newGuid: currentGuid,
                        showAlertDialog: false
                      });
                    }
                  }
                }
                if(tempHighlightElements.indexOf(token) !== -1) {
                  window.flutter_inappwebview.callHandler('removeHighlight', {
                    guid: value.highlightId,
                    newGuid: currentGuid,
                    showAlertDialog: false
                  });
                }
              });
              
              oldHighlightsMap.clear();
              
              showToolbarHighlight(tempHighlightElements[0], currentGuid);

              for (let i = 0; i < tempHighlightElements.length; i++) {
                const element = tempHighlightElements[i];
                const { id, paragraphs, isVerse } = getTheFirstTargetParagraph(element);
              
                if (id !== currentParagraphId) {
                  // S'il y avait un paragraphe précédent, on sauvegarde le highlight
                  if (firstTarget && lastTarget) {
                    addHighlightForParagraph(firstTarget, lastTarget, currentParagraph, currentParagraphId, currentIsVerse);
                  }
              
                  // On commence un nouveau paragraphe
                  currentParagraph = paragraphs;
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
              function addHighlightForParagraph(firstElement, lastElement, paragraphs, paragraphId, isVerse) {
                const wordAndPunctTokens = paragraphs.flatMap(p => Array.from(p.querySelectorAll('.word, .punctuation')));
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
          
          const paragraphCache = new WeakMap();

          function getTheFirstTargetParagraph(target) {
            if (paragraphCache.has(target)) {
              return paragraphCache.get(target);
            }
          
            let result = null;
          
            // Si c'est un verset
            const verse = target.closest('.v[id]');
            if (verse) {
              // Découpe l'ID
              const parts = verse.id.split('-'); // ex: ["v20","28","1","2"]
              const chapterVerse = `\${parts[1]}-\${parts[2]}`; // ex: "28-1"
            
              // Sélectionne toutes les parties du verset
              let verses = Array.from(pageCenter.querySelectorAll(`.v[id*="-\${chapterVerse}-"]`));
            
              // Trie en fonction du dernier index de l'ID
              verses.sort((a, b) => {
                const aPart = parseInt(a.id.split('-')[3], 10);
                const bPart = parseInt(b.id.split('-')[3], 10);
                return aPart - bPart;
              });
            
              result = {
                paragraphs: verses, // toutes les parties du verset, dans l'ordre
                id: parts[2],    // chapitre-verset unique
                isVerse: true
              };
            }
            else {
              // Si c'est un paragraphe normal
              const paragraph = target.closest('[data-pid]');
              if (paragraph) {
                result = {
                  paragraphs: [paragraph], // tableau avec uniquement ce paragraphe
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
          
          function getAllParagraphs(article) {
            const finalList = [];
          
            // Cherche d'abord les versets
            const verses = Array.from(article.querySelectorAll('.v[id]'));
          
            if (verses.length > 0) {
              const grouped = {};
          
              verses.forEach(verse => {
                const parts = verse.id.split('-'); // ex: ["v1","3","15","1"]
                const key = parts[2]; // ici "15" (le verset)
          
                if (!grouped[key]) {
                  grouped[key] = [];
                }
                grouped[key].push(verse);
              });
          
              // Trie les parties à l'intérieur de chaque groupe
              Object.values(grouped).forEach(group => {
                group.sort((a, b) => {
                  const aPart = parseInt(a.id.split('-')[3], 10);
                  const bPart = parseInt(b.id.split('-')[3], 10);
                  return aPart - bPart;
                });
                finalList.push(group);
              });
          
            } else {
              // Si pas de versets → ajoute directement les paragraphes
              const paragraphs = Array.from(article.querySelectorAll('[data-pid]'));
              paragraphs.forEach(paragraph => {
                finalList.push([paragraph]); // Chaque paragraphe seul dans un tableau
              });
            }
          
            return finalList;
          }
          
          // Gestionnaires d'événements pour le conteneur optimisés
          container.addEventListener('touchstart', (e) => {
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