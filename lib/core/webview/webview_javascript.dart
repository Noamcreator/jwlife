import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../app/services/settings_service.dart';

String createReaderHtmlShell(Publication publication, int firstIndex, int maxIndex, {int? bookNumber, int? chapterNumber, int? lastBookNumber, int? lastChapterNumber, int? startParagraphId, int? endParagraphId, int? startVerseId, int? endVerseId, String? textTag, List<String> wordsSelected = const []}) {
  String publicationPath = publication.path ?? '';
  final webViewData = JwLifeSettings.instance.webViewData;
  final fontSize = webViewData.fontSize;
  final styleIndex = webViewData.styleIndex;
  final colorIndex = webViewData.colorIndex;
  bool isDarkMode = webViewData.theme == 'cc-theme--dark';
  String direction = publication.mepsLanguage.isRtl ? 'rtl' : 'ltr';
  bool isFullscreenMode = webViewData.isFullScreenMode;
  bool isReadingMode = webViewData.isReadingMode;
  bool isBlockingHorizontallyMode = webViewData.isBlockingHorizontallyMode;
  bool audioPlayerVisible = GlobalKeyService.jwLifePageKey.currentState?.audioWidgetVisible.value ?? false;

  final lightPrimaryColor = toHex(JwLifeSettings.instance.lightPrimaryColor);
  final darkPrimaryColor = toHex(JwLifeSettings.instance.darkPrimaryColor);

  String theme = isDarkMode ? 'dark' : 'light';

  return '''
    <!DOCTYPE html>
    <html style="overflow: hidden;">
      <meta content="text/html" charset="UTF-8">
      <meta name="viewport" content="initial-scale=1.0">
      <link rel="stylesheet" href="jw-styles.css" />
      <head>
        <meta charset="utf-8">
        <style>
          :root {
            /* =======================================
               DÉFINITION DES COULEURS (Mode Clair)
               ======================================= */
            
            /* Palette de couleurs de base (RGB sans opacité) */
            --color-yellow-rgb: 255, 243, 122; 
            --color-green-rgb: 183, 228, 146;
            --color-blue-rgb: 152, 216, 255;
            --color-pink-rgb: 246, 152, 188;
            --color-orange-rgb: 255, 186, 138;
            --color-purple-rgb: 193, 167, 226;
            --color-red-rgb: 255, 150, 150; 
            --color-brown-rgb: 200, 175, 145;
            
            /* Couleur de Bordure Grise */
            --color-gray-rgb: 220, 220, 220;
          }
          
          /* =======================================
             DÉFINITION DES COULEURS (Mode Sombre)
             ======================================= */
          .cc-theme--dark {
            --color-yellow-rgb: 250, 217, 41;
            --color-green-rgb: 129, 189, 79;
            --color-blue-rgb: 95, 180, 239;
            --color-pink-rgb: 219, 93, 141;
            --color-orange-rgb: 255, 134, 46;
            --color-purple-rgb: 146, 111, 189;
            --color-red-rgb: 255, 80, 80; 
            --color-brown-rgb: 145, 100, 50;
            
            --color-gray-rgb: 80, 80, 80;
          }
          
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
            will-change: transform; /* ➜ améliore la fluidité */
          }
          
          .page {
            flex: 0 0 100%;
            height: 100%;
            overflow-y: auto;
            margin: 0;
            padding: 0;
          }
          
          #page-center {
            position: relative;
            height: 100%;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.35s ease-in-out; 
          }
          
          #page-center.visible {
            opacity: 1;
            pointer-events: auto;
          }

          .scroll-bar {
            position: absolute;
            top: 56px;
            right: 0px;
            width: 30px;
            height: 55px;
            z-index: 999;
            left: auto;
          }
          
          /* 2. Surcharge RTL (à gauche) */
          body.rtl .scroll-bar {
            right: auto;
            left: 0px;
            transform: scaleX(-1);
          }
          
          .floating-button {
            position: fixed;
            inset-inline-end: 20px;
            /* Ancien : right: 20px; */
            right: 20px
            left: auto;
            width: 56px;
            height: 56px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: jw-icons-external;
            font-size: 25px;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            z-index: 9999; 
            transition: all 0.3s ease;
            user-select: none;
            opacity: 0; 
          }
          
          /* 2. Surcharge RTL (à gauche) */
          body.rtl .floating-button {
            right: auto;
            left: 20px;
          }
          
          /* Styles pour la loupe */
          #magnifier {
            position: fixed;
            width: 130px;
            height: 50px;
            border: 3px solid #333;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
            z-index: 9999;
            pointer-events: none;
            transition: opacity 0.2s ease;
          }
          
           /* Classe pour masquer l'élément */
          .hide {
              opacity: 0;
              pointer-events: none;
          }
  
          .magnifier-content {
            position: absolute;
            transform-origin: 0 0;
            pointer-events: none;
            width: 100vw;
            height: 100vh;
          }
          
          /* Le contenu cloné à l'intérieur */
          #magnifier-content > * {
            position: absolute;
            top: 0;
            left: 0;
            transform-origin: 0 0;
            pointer-events: none;
          }
          
          body.cc-theme--dark #magnifier {
            background-color: #121212;
            border: 2px solid #ffffff;
          }
          
          body.cc-theme--light #magnifier {
            background-color: #ffffff;
            border: 2px solid #5f5a57;
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
          
          .note-title:focus,
          .note-content:focus,
          .note-tags:focus {
            outline: none !important;
            box-shadow: none !important;
            border: none !important;
          }
          
          ::selection {
            background-color: rgba(66, 236, 241, 0.3) !important; /* Couleur de fond de la sélection */
            background-size: auto 75%; /* La hauteur est de 75% de la hauteur de l'élément, la largeur est automatique */
          }
          
          .word.searched {
            background-color: rgba(255, 185, 46, 0.8);
          }
          
          body.selection-active .word,
          body.selection-active .punctuation,
          body.selection-active .escape {
            user-select: text;
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
            left: 50%; 
            transform: translateX(-50%);
            width: max-content;
            max-width: 100vw;
          }
          
          /* Thème clair */
          body.cc-theme--light .toolbar {
            background-color: #ffffff;
          }
          
          /* Thème sombre */
          body.cc-theme--dark .toolbar {
            background-color: #424242;
          }
            
          .highlight-yellow      { background-color: rgba(var(--color-yellow-rgb), 0.5); }
          .highlight-green       { background-color: rgba(var(--color-green-rgb), 0.5); }
          .highlight-blue        { background-color: rgba(var(--color-blue-rgb), 0.5); }
          .highlight-pink        { background-color: rgba(var(--color-pink-rgb), 0.5); }
          .highlight-orange      { background-color: rgba(var(--color-orange-rgb), 0.5); }
          .highlight-purple      { background-color: rgba(var(--color-purple-rgb), 0.5); }
          .highlight-red         { background-color: rgba(var(--color-red-rgb), 0.5); }
          .highlight-brown       { background-color: rgba(var(--color-brown-rgb), 0.5); }
          
          /* Définition de base commune aux deux thèmes pour le style amélioré */
          [class*="underline-"] {
            text-decoration: underline;
            text-underline-offset: 0.15em;
            text-decoration-thickness: 0.15em;
            text-decoration-skip-ink: none; 
          }
          
          /* L'opacité (0.85) est appliquée ici, une seule fois pour tous les thèmes/couleurs */
          .underline-yellow { text-decoration-color: rgba(var(--color-yellow-rgb), 0.8); }
          .underline-green { text-decoration-color: rgba(var(--color-green-rgb), 0.8); }
          .underline-blue { text-decoration-color: rgba(var(--color-blue-rgb), 0.8); }
          .underline-pink { text-decoration-color: rgba(var(--color-pink-rgb), 0.8); }
          .underline-orange { text-decoration-color: rgba(var(--color-orange-rgb), 0.8); }
          .underline-purple { text-decoration-color: rgba(var(--color-purple-rgb), 0.8); }
          .underline-red { text-decoration-color: rgba(var(--color-red-rgb), 0.8); }
          .underline-brown { text-decoration-color: rgba(var(--color-brown-rgb), 0.8); }
          
          /* Application du style à toutes les classes utilisant la variable --c */
          [class*="text-"] {
            color: color-mix(in srgb, rgba(var(--c), 1) 80%, #555 20%);
          }
          
          .text-gray { --c: var(--color-gray-rgb); } 
          .text-yellow { --c: var(--color-yellow-rgb); }
          .text-green { --c: var(--color-green-rgb); }
          .text-blue { --c: var(--color-blue-rgb); }
          .text-pink { --c: var(--color-pink-rgb); }
          .text-orange { --c: var(--color-orange-rgb); }
          .text-purple { --c: var(--color-purple-rgb); }
          .text-red { --c: var(--color-red-rgb); }
          .text-brown { --c: var(--color-brown-rgb); }

          .cc-theme--light .note-indicator-gray      { background-color: #bfbfbf; }
          .cc-theme--light .note-indicator-yellow    { background-color: #fff379; }
          .cc-theme--light .note-indicator-green     { background-color: #b7e492; }
          .cc-theme--light .note-indicator-blue      { background-color: #98d8fe; }
          .cc-theme--light .note-indicator-pink      { background-color: #f698bc; }
          .cc-theme--light .note-indicator-orange    { background-color: #feba89; }
          .cc-theme--light .note-indicator-purple    { background-color: #c0a7e1; }
          .cc-theme--light .note-indicator-red       { background-color: #ff9696; }
          .cc-theme--light .note-indicator-brown     { background-color: #c8af91; }
          
          .cc-theme--dark .note-indicator-gray      { background-color: #808080; }
          .cc-theme--dark .note-indicator-yellow    { background-color: #eac600; }
          .cc-theme--dark .note-indicator-green     { background-color: #67a332; }
          .cc-theme--dark .note-indicator-blue      { background-color: #4ba1de; }
          .cc-theme--dark .note-indicator-pink      { background-color: #c64677; }
          .cc-theme--dark .note-indicator-orange    { background-color: #ea6d01; }
          .cc-theme--dark .note-indicator-purple    { background-color: #7a57a7; }
          .cc-theme--dark .note-indicator-red       { background-color: #ff5050; }
          .cc-theme--dark .note-indicator-brown     { background-color: #916432; }
          
          .cc-theme--light .note-gray      { background-color: #f1f1f1; }
          .cc-theme--light .note-yellow    { background-color: #fffce6; }
          .cc-theme--light .note-green     { background-color: #effbe6; }
          .cc-theme--light .note-blue      { background-color: #e6f7ff; }
          .cc-theme--light .note-pink      { background-color: #ffe6f0; }
          .cc-theme--light .note-orange    { background-color: #fff0e6; }
          .cc-theme--light .note-purple    { background-color: #f1eafa; }
          .cc-theme--light .note-red       { background-color: #ffd6d6; }
          .cc-theme--light .note-brown     { background-color: #F2E0CE; }
          
          .cc-theme--dark .note-gray      { background-color: #292929; }
          .cc-theme--dark .note-yellow    { background-color: #49400e; }
          .cc-theme--dark .note-green     { background-color: #233315; }
          .cc-theme--dark .note-blue      { background-color: #203646; }
          .cc-theme--dark .note-pink      { background-color: #401f2c; }
          .cc-theme--dark .note-orange    { background-color: #49290e; }
          .cc-theme--dark .note-purple    { background-color: #2d2438; }
          .cc-theme--dark .note-red       { background-color: #441a1a; }
          .cc-theme--dark .note-brown     { background-color: #382c18; }
        </style>
      </head>
      <body class="${webViewData.theme} $direction">
        <div id="container">
          <div id="page-left" class="page"></div>
          <div id="page-center" class="page"></div>
          <div id="page-right" class="page"></div>
        </div>
        
        <div id="magnifier" class="hide">
            <div class="magnifier-content" id="magnifier-content"></div>
        </div>
    
        <script>
          let currentIndex = $firstIndex;
          const maxIndex = $maxIndex;
          
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
          let isReadingMode = $isReadingMode;
          let isBlockingHorizontallyMode = $isBlockingHorizontallyMode;
          let controlsVisible = true;
          let audioPlayerVisible = $audioPlayerVisible;
          
          let imageMode = true;

          let cachedPages = {};
          let scrollTopPages = {};
          
          let isChangingParagraph = false;
          
          const bookmarkAssets = Array.from({ length: 10 }, (_, i) => `bookmarks/$theme/bookmark\${i + 1}.png`);
          
          const handleLeft = `images/handle_left.png`;
          const handleRight = `images/handle_right.png`;
          
          const speedBarScroll = `images/speedbar_thumb_regular.png`;
          let scrollBar = null;
          
          // Valeurs fixes de hauteur des barres
          const APPBAR_FIXED_HEIGHT = 56;
          const BOTTOMNAVBAR_FIXED_HEIGHT = $kBottomNavigationBarHeight;
          const AUDIO_PLAYER_HEIGHT = 80;
          
          const MAGNIFIER_SIZE = 130;
          const ZOOM_FACTOR = 1;
          
          let paragraphsData = new Map();

          /**************
           * CONFIG STYLES
           **************/
           
          const colorsList = ['gray', 'yellow', 'green', 'blue', 'pink', 'orange', 'purple', 'red', 'brown'];
          
          const STYLE = {
            highlight: {
              styleName: 'highlight',
              icon: '&#xE6DC',
              classes: [
                'highlight-gray','highlight-yellow','highlight-green',
                'highlight-blue','highlight-pink','highlight-orange','highlight-purple', 'highlight-red', 'highlight-brown'
              ],
              options: colorsList,
              colorIndex: $colorIndex
            },
            underline: {
              styleName: 'underline',
              icon: '&#xE6DD',
              classes: [
                'underline-gray','underline-yellow','underline-green',
                'underline-blue','underline-pink','underline-orange','underline-purple', 'underline-red', 'underline-brown'
              ],
              options: colorsList,
              colorIndex: $colorIndex
            },
            text: {
              styleName: 'text',
              icon: '&#xE6DE',
              classes: [
                'text-gray','text-yellow','text-green', // Changé de 'border-couleur' à 'text-couleur'
                'text-blue','text-pink','text-orange','text-purple', 'text-red', 'text-brown'
              ],
              options: colorsList,
              colorIndex: $colorIndex
            }
          };
          
          const blockRangeAttr = 'block-range-id';
          const noteBlockRangeAttr = 'note-block-range-id';
          
          const noteAttr = 'note-id';
          
          let currentStyleIndex = $styleIndex;
          
          const alphabet = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'];
          
          const getFootnoteLetter = (index) => {
            // Assurez-vous que l'index est valide et décrémentez-le pour le 0-basé
            const zeroBasedIndex = index - 1;
            
            // Applique l'opérateur modulo pour cycler
            const letterIndex = zeroBasedIndex % alphabet.length;
            
            return alphabet[letterIndex];
          };
          
          let blockRanges;
          let notes;
          let tags;
          let inputFields;
          let bookmarks;
          
          function updateTags(tags) {
            this.tags = tags;
          }
          
          function updateNoteUI(note, silent = true) {
              const dialogIndex = dialogHistory.findIndex(item => 
                  item.type === 'note' && 
                  item.options?.noteData?.noteGuid === note.Guid
              );
              if (dialogIndex === -1) return false;
          
              const dialogData = dialogHistory[dialogIndex];
              const dialog = document.getElementById(dialogData.dialogId);
              if (!dialog) return false;
          
              const titleElement = dialog.querySelector(".note-title");
              const contentElement = dialog.querySelector(".note-content");
              const tagsContainer = dialog.querySelector(".tags-container");
              const noteWrapper = dialog.querySelector(".note-dialog") || dialog;
          
              if (note.Title !== undefined && titleElement) {
                  titleElement.value = note.Title;
                  if (!silent) titleElement.dispatchEvent(new Event("input"));
              }
          
              if (note.Content !== undefined && contentElement) {
                  contentElement.value = note.Content;
                  if (!silent) contentElement.dispatchEvent(new Event("input"));
              }
              
              // 5. Mise à jour de la couleur
              if (note.ColorIndex !== undefined && noteWrapper) {
                  // Supprimer toutes les classes de couleur existantes
                  colorsList.forEach((_, index) => {
                      const className = getNoteClass(index, false);
                      if (className) noteWrapper.classList.remove(className);
                  });
                  noteWrapper.classList.add(getNoteClass(note.ColorIndex, false));
              }
          
              // 6. Mise à jour des tags
              if (note.TagsId !== undefined && tagsContainer) {
                  const newTags = note.TagsId
                      .split(",")
                      .map(id => parseInt(id))
                      .filter(id => !isNaN(id));
          
                  // Effacer les tags actuels (sauf l'input)
                  [...tagsContainer.children].forEach(child => {
                      if (!child.classList.contains("tag-input-wrapper")) {
                          child.remove();
                      }
                  });
          
                  // Recréer les tags UI
                  newTags.forEach(tagId => {
                      const tag = tags.find(t => t.TagId === tagId);
                      if (tag) {
                          const tagEl = createTagElement(tag);
                          const inputWrapper = tagsContainer.querySelector(".tag-input-wrapper");
                          if (inputWrapper) {
                              tagsContainer.insertBefore(tagEl, inputWrapper);
                          } else {
                              tagsContainer.appendChild(tagEl);
                          }
                      }
                  });
              }
          
              return true;
          }
          
          function updateAllNotesUI(notesList) {
              notes = notesList;
              notes.forEach(note => {
                  const currentNote = document.querySelector(`[\${noteAttr}="\${note.Guid}"]`);
                  if (currentNote) {
                     updateNoteUI(note, true); // silent = true
                  }
                  else {
                    const paragraphInfo = paragraphsDataDialog.get(note.BlockIdentifier);
                    const isBible = isBible();
             
                    addNoteWithGuid(pageCenter, paragraphInfo.paragraphs[0], null, note.Guid, 0, isBible, true);
                  }
              });
          }
         
          function changeTheme(isDarkMode) {
            isDark = isDarkMode;
            document.body.classList.remove('cc-theme--dark', 'cc-theme--light');
            document.body.classList.add(isDarkMode ? 'cc-theme--dark' : 'cc-theme--light');
          }
          
          function isDarkTheme() {
            return document.body.classList.contains('cc-theme--dark');
          }
          
          function changeStyleAndColorIndex(styleIndex, colorIndex) {
            currentStyleIndex = styleIndex;
            setColorIndex(styleIndex, colorIndex); 
          }
          
          function changeFullScreenMode(isFullscreen) {
            isFullscreenMode = isFullscreen;
          }
          
          function changeReadingMode(isReading) {
            isReadingMode = isReading;
          }
          
          function changePreparingMode(isPreparing) {
            isBlockingHorizontallyMode = isPreparing;
          }
          
          function updateAudios(audios, index) {
            cachedPages[index].audiosMarkers = audios;
          }
          
          function changePrimaryColor(lightColor, darkColor) {
            lightPrimaryColor = lightColor;
            darkPrimaryColor = darkColor;
            
            const floatingButton = document.getElementById('dialogFloatingButton');
            floatingButton.style.backgroundColor = isDarkTheme() ? darkPrimaryColor : lightPrimaryColor;
          }
          
          function toggleAudioPlayer(visible) {
            const floatingButton = document.getElementById('dialogFloatingButton');
            audioPlayerVisible = visible;
            floatingButton.style.bottom = `\${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 15}px`;

            const curr = cachedPages[currentIndex];
            adjustArticle('article-center', curr.link);
          }
          
          async function fetchPage(index) {
            if (index < 0 || index > maxIndex) return { html: "", className: "" };
            if (cachedPages[index]) return cachedPages[index];
            const page = await window.flutter_inappwebview.callHandler('getPage', index);
            cachedPages[index] = page;
            return page;
          }
          
          async function loadImageSvg(article, svgPath) {
            const colorBackground = isDarkTheme() ? '#202020' : '#ecebe7';
          
            // Supprimer un ancien container si déjà présent
            const existingSvgContainer = article.querySelector('#svg-container');
            if (existingSvgContainer) {
              existingSvgContainer.remove();
            }
          
            // Création du conteneur
            const svgContainer = document.createElement('div');
            svgContainer.id = 'svg-container';
            svgContainer.style.position = 'absolute';
            svgContainer.style.width = '100%';
            svgContainer.style.height = '100%';
            svgContainer.style.zIndex = '10';
            svgContainer.style.backgroundColor = colorBackground;
            svgContainer.style.display = 'flex';
            svgContainer.style.alignItems = 'center';
            svgContainer.style.justifyContent = 'center';
          
            // Container interne type "carte"
            const innerBox = document.createElement('div');
            innerBox.style.backgroundColor = '#ffffff';
            innerBox.style.height = '65%';
            innerBox.style.boxShadow = '0 4px 10px rgba(0,0,0,0.2)';
            innerBox.style.display = 'flex';
            innerBox.style.alignItems = 'center';
            innerBox.style.justifyContent = 'center';
          
            // Image en base64
            const svgImage = document.createElement('img');
            svgImage.src = 'file://' + svgPath;
            svgImage.style.width = '100%';
            svgImage.style.height = '100%';
            svgImage.style.objectFit = 'contain';
          
            innerBox.appendChild(svgImage);
            svgContainer.appendChild(innerBox);
            article.appendChild(svgContainer);
          }

          function switchImageMode(mode) {
            imageMode = mode;
            const curr = cachedPages[currentIndex];
            const prev = cachedPages[currentIndex-1];
            const next = cachedPages[currentIndex+1];
            
            function renderPage(container, item, position) {
              if (item.preferredPresentation === 'image' && imageMode) {
                container.innerHTML = ""; // vider avant de charger
                loadImageSvg(container, item.svgs);
                
                // Désactiver le zoom
                let viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                  viewport = document.createElement('meta');
                  viewport.name = 'viewport';
                  document.head.appendChild(viewport);
                }
                viewport.content = 'width=device-width, initial-scale=1.0';
              } 
              else {
                container.innerHTML = `<article id="article-\${position}" class="\${item.className}">\${item.html}</article>`;
                adjustArticle(`article-\${position}`, item.link);
                addVideoCover(`article-\${position}`);
                
                // Désactiver le zoom
                let viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                  viewport = document.createElement('meta');
                  viewport.name = 'viewport';
                  document.head.appendChild(viewport);
                }
                viewport.content = 'width=device-width, initial-scale=1.0, user-scalable=no';
                
                wrapWordsWithSpan(container, false);
                paragraphsData = fetchAllParagraphsOfTheArticle(article);
                loadUserdata();
              }
            }
            
            renderPage(pageCenter, curr, "center");
            renderPage(pageLeft, prev, "left");
            renderPage(pageRight, next, "right");
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
              article.style.paddingBottom = `\${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 30}px`;
            }
            
            transformFlipbookHtml(article);
          }
          
          function transformFlipbookHtml(articleElement) {
            // Sélectionner tous les conteneurs flipbook dans l’article
            const flipbookDivs = articleElement.querySelectorAll('div.gen-flipbook.pm-flipbook-gallery');
          
            flipbookDivs.forEach(div => {
              const figure = div.querySelector('figure.gen-flipbook.pm-flipbook-gallery');
              if (!figure) return;
          
              // Ajouter les classes supplémentaires au figure
              figure.classList.add(
                'cc-flipbookGallery--initialized',
                'cc-flipbookGallery',
                'cc-flipbookGallery--js'
              );
              figure.setAttribute('data-has-client-components', 'true');
          
              // Récupérer toutes les images existantes
              const imgs = Array.from(figure.querySelectorAll('img.gen-flipbook'));
              if (imgs.length === 0) return;
          
              // Construire le markup slick dynamique
              const slickSlides = imgs.map((img, index) => {
                const src = img.getAttribute('src');
                const alt = img.getAttribute('alt') || '';
                const width = img.getAttribute('width') || '';
                const height = img.getAttribute('height') || '';
          
                // *** MODIFICATION ICI : Suppression des styles de position et d'opacité dans le markup initial ***
                return `
                  <div class="slick-slide cc-flipbookGallery-slide \${index === 0 ? 'slick-current slick-active' : ''}" 
                       data-slick-index="\${index}" 
                       aria-hidden="\${index === 0 ? 'false' : 'true'}" 
                       role="tabpanel" 
                       id="slick-slide0\${index}" 
                       aria-describedby="slick-slide-control0\${index}"
                       style="display: \${index === 0 ? 'block' : 'none'}; transition: opacity 800ms;">
                    <div>
                      <img class="gen-flipbook" src="\${src}" alt="\${alt}" width="\${width}" height="\${height}" style="width: 100%; display: inline-block;">
                    </div>
                  </div>`;
              }).join('');
          
              // Structure complète slick
              const slickHTML = `
                <div class="slick-initialized slick-slider slick-dotted">
                  <div class="cc-flipbookGallery-navigation-previous slick-arrow" style="cursor:pointer;">
                    <svg class="svg-inline--fa jwi-chevron-left fa-w-16" focusable="false" aria-hidden="true" data-prefix="jwf-jw-icons-external" data-icon="chevron-left" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M15.5 19a.493.493 0 01-.315-.112l-8-6.5a.5.5 0 010-.776l8-6.5a.5.5 0 11.63.776L8.293 12l7.522 6.112A.5.5 0 0115.5 19z"></path></svg>
                  </div>
                  <div class="slick-list draggable">
                    <div class="slick-track" style="opacity: 1; width: 100%;">
                      \${slickSlides}
                    </div>
                  </div>
                  <div class="cc-flipbookGallery-navigation-next slick-arrow" style="cursor:pointer;">
                    <svg class="svg-inline--fa jwi-chevron-right fa-w-16" focusable="false" aria-hidden="true" data-prefix="jwf-jw-icons-external" data-icon="chevron-right" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M8.5 19a.5.5 0 01-.39-.18.52.52 0 01.07-.71L15.71 12 8.18 5.89a.5.5 0 01.64-.78l8 6.5a.51.51 0 010 .78l-8 6.5a.56.56 0 01-.32.11z"></path></svg>
                  </div>
                  <ul class="cc-flipbookGallery-navigation-dots" role="tablist">
                    \${imgs.map((_, i) => `
            <li class="\${i === 0 ? 'slick-active' : ''}" role="presentation">
            <button type="button" role="tab" id="slick-slide-control0\${i}" aria-controls="slick-slide0\${i}" aria-label="\${i + 1} of \${imgs.length}" tabindex="\${i === 0 ? 0 : -1}" \${i === 0 ? 'aria-selected="true"' : ''}>\${i + 1}</button>
            </li>`).join('')}
                  </ul>
                </div>`;
          
              // Remplacer le contenu du figure par la structure complète
              figure.innerHTML = slickHTML;
          
              // === AJOUT LOGIQUE DE NAVIGATION ===
              const slides = Array.from(figure.querySelectorAll('.slick-slide'));
              const dots = Array.from(figure.querySelectorAll('.cc-flipbookGallery-navigation-dots button'));
              const prevBtn = figure.querySelector('.cc-flipbookGallery-navigation-previous');
              const nextBtn = figure.querySelector('.cc-flipbookGallery-navigation-next');
          
              let currentIndex = 0;
          
              function updateSlides() {
                slides.forEach((slide, i) => {
                  const isActive = i === currentIndex;
                  
                  slide.classList.toggle('slick-current', isActive);
                  slide.classList.toggle('slick-active', isActive);
                  
                  // *** MODIFICATION CRUCIALE ICI : Gestion du display pour la superposition ***
                  // L'image active est affichée ('block'), les autres sont cachées ('none').
                  slide.style.display = isActive ? 'block' : 'none';
                  
                  // Mise à jour de l'accessibilité
                  slide.setAttribute('aria-hidden', !isActive);
                });
          
                dots.forEach((btn, i) => {
                  const li = btn.parentElement;
                  li.classList.toggle('slick-active', i === currentIndex);
                  btn.setAttribute('aria-selected', i === currentIndex);
                  btn.tabIndex = i === currentIndex ? 0 : -1;
                });
              }
          
              prevBtn.addEventListener('click', () => {
                currentIndex = (currentIndex - 1 + slides.length) % slides.length;
                updateSlides();
              });
          
              nextBtn.addEventListener('click', () => {
                currentIndex = (currentIndex + 1) % slides.length;
                updateSlides();
              });
          
              dots.forEach((btn, i) => {
                btn.addEventListener('click', () => {
                  currentIndex = i;
                  updateSlides();
                });
              });
              
              // Initialiser la première vue (au cas où le style initial ait été ignoré)
              updateSlides();
            });
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
            const skipClasses = new Set(["fn", "m", "cl", "vl", "dc-button--primary", "gen-field"]);
           
            function walkNodes(node) {
              if (node.nodeType === Node.TEXT_NODE) {
                // VÉRIFIER SI UN PARENT A UNE CLASSE INTERDITE
                let parent = node.parentElement;
                while (parent) {
                  if (parent.classList && [...skipClasses].some(c => parent.classList.contains(c))) {
                    return; // Skip ce text node
                  }
                  parent = parent.parentElement;
                }
                
                const text = node.textContent;
                const newHTML = processText(text);
                const temp = document.createElement('div');
                temp.innerHTML = newHTML.html;
                        
                const nodeParent = node.parentNode;
                while (temp.firstChild) {
                  nodeParent.insertBefore(temp.firstChild, node);
                }
                nodeParent.removeChild(node);
              } 
              else if (node.nodeType === Node.ELEMENT_NODE) {
                if (node.classList && [...skipClasses].some(c => node.classList.contains(c))) {
                  return;
                }
                
                if ((node.closest && node.closest("sup")) || 
                    (node.classList && (node.classList.contains('word') || 
                                       node.classList.contains('escape') || 
                                       node.classList.contains('punctuation')))) {
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
            return (
              // Latin A-Z, a-z
              (code >= 65 && code <= 90) ||
              (code >= 97 && code <= 122) ||
              // Latin Extended (À-ÿ)
              (code >= 192 && code <= 255) ||
              // Ligatures
              char === 'œ' || char === 'Œ' ||
              char === 'æ' || char === 'Æ' ||
              // Arabic (0600-06FF, 0750-077F, 08A0-08FF, FB50-FDFF, FE70-FEFF)
              (code >= 0x0600 && code <= 0x06FF) ||
              (code >= 0x0750 && code <= 0x077F) ||
              (code >= 0x08A0 && code <= 0x08FF) ||
              (code >= 0xFB50 && code <= 0xFDFF) ||
              (code >= 0xFE70 && code <= 0xFEFF) ||
              // Hiragana (3040-309F)
              (code >= 0x3040 && code <= 0x309F) ||
              // Katakana (30A0-30FF)
              (code >= 0x30A0 && code <= 0x30FF) ||
              // Kanji/CJK Unified Ideographs (4E00-9FFF)
              (code >= 0x4E00 && code <= 0x9FFF) ||
              // CJK Extensions A (3400-4DBF)
              (code >= 0x3400 && code <= 0x4DBF) ||
              // CJK Extensions B-F (20000-2FA1F)
              (code >= 0x20000 && code <= 0x2FA1F) ||
              // Halfwidth Katakana (FF65-FF9F)
              (code >= 0xFF65 && code <= 0xFF9F) ||
              // Hebrew (0590-05FF)
              (code >= 0x0590 && code <= 0x05FF) ||
              // Cyrillic (0400-04FF)
              (code >= 0x0400 && code <= 0x04FF)
            );
          }
          
          function isDigit(char) {
            const code = char.charCodeAt(0);
            return (
              // ASCII digits 0-9
              (code >= 48 && code <= 57) ||
              // Arabic-Indic digits (٠-٩)
              (code >= 0x0660 && code <= 0x0669) ||
              // Extended Arabic-Indic digits (۰-۹)
              (code >= 0x06F0 && code <= 0x06F9) ||
              // Fullwidth digits (０-９)
              (code >= 0xFF10 && code <= 0xFF19)
            );
          }
          
          function isSpace(char) {
            return char === ' ' || char === '\u00A0' || char === '\u3000'; // Added ideographic space
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
              char === '\u200C' ||  // Zero Width Non-Joiner (important for Arabic/Persian)
              char === '\u200D' ||  // Zero Width Joiner
              char === '\uFEFF' ||  // Zero Width No-Break Space (BOM)
              char === '\u00AD' ||  // Soft Hyphen
              (code >= 0x2000 && code <= 0x200F) || // Various Unicode spaces
              (code >= 0x202A && code <= 0x202E)    // Directional formatting characters (RTL/LTR marks)
            );
          }
         
          // Fonction pour charger une page de manière optimisée
          async function loadIndexPage(index, isFirst) {
            const curr = await fetchPage(index);
            const isImageMode = curr.preferredPresentation === 'image' && imageMode
            if (isImageMode) {
              loadImageSvg(pageCenter, curr.svgs);
            }
            else {
              pageCenter.innerHTML = `<article id="article-center" class="\${curr.className}">\${curr.html}</article>`;
                                     
              adjustArticle('article-center', curr.link);
              addVideoCover('article-center');
              
              // Désactiver le zoom
              let viewport = document.querySelector('meta[name="viewport"]');
              if (!viewport) {
                viewport = document.createElement('meta');
                viewport.name = 'viewport';
                document.head.appendChild(viewport);
              }
              viewport.content = 'width=device-width, initial-scale=1.0, user-scalable=no';
            }
           
            container.style.transition = "none";
            container.style.transform = "translateX(-100%)";
            void container.offsetWidth;
            container.style.transition = "transform 0.3s ease-in-out";
            
            if (!isFirst && !isImageMode) {
              const article = document.getElementById("article-center");
              wrapWordsWithSpan(article, isBible());
              paragraphsData = fetchAllParagraphsOfTheArticle(article);
            }
          }
          
          async function loadPrevAndNextPages(index) {
            const prev = await fetchPage(index - 1);
            const next = await fetchPage(index + 1);
            
            if (prev.preferredPresentation === 'image' && imageMode) {
              loadImageSvg(pageLeft, prev.svgs);
            }
            else {
              pageLeft.innerHTML = `<article id="article-left" class="\${prev.className}">\${prev.html}</article>`;
              adjustArticle('article-left', prev.link);
              addVideoCover('article-left');
            }
            
            if (next.preferredPresentation === 'image' && imageMode) {
              loadImageSvg(pageRight, next.svgs);
            } 
            else {
              pageRight.innerHTML = `<article id="article-right" class="\${next.className}">\${next.html}</article>`;
              adjustArticle('article-right', next.link);
              addVideoCover('article-right');
            }
          }
    
          // Fonction de chargement optimisée avec gestion des états
           async function loadPages(currentIndex) {
            await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
            
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
            isDragging = false;
            isVerticalScroll = false;
            startX = 0;
            startY = 0;
            currentTranslate = -100;
          
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
          if (paragraphs.length === 0) {
            console.error(`No paragraphs found for selector: \${selector}`);
            return;
          }
        
          // --- Modification: Determine the maximum paragraph ID ---
          let maxParagraphId = null; 
          paragraphs.forEach(p => {
            let id = getParagraphId(p, selector, idAttr);
            if (id !== null) {
              if (maxParagraphId === null || id > maxParagraphId) {
                maxParagraphId = id;
              }
            }
          });
          // ---------------------------------------------------------
          
          // Helper function to extract ID (moved logic out for cleanliness)
          function getParagraphId(p, selector, idAttr) {
            let id;
            if (selector === '[data-pid]') {
              id = parseInt(p.getAttribute(idAttr), 10);
              if (isNaN(id)) return null;
            } else {
              const attrValue = p.getAttribute(idAttr)?.trim();
              if (!attrValue) return null;
              const idParts = attrValue.split('-');
              if (idParts.length < 4) return null;
              id = parseInt(idParts[2], 10);
              if (isNaN(id)) return null;
            }
            return id;
          }
        
          // --- Modification: Handle 'end' being null/undefined or -1 (if -1 is intended as a special value) ---
          let effectiveEnd = end;
          if (end === null || end === undefined || (end === -1 && begin !== -1)) {
            // If end is null/undefined, or if it's -1 but we're not in the "show all" mode (begin also -1), 
            // set effectiveEnd to the max ID found.
            effectiveEnd = maxParagraphId; 
          }
        
          // Original check for full document visibility (begin === -1 && end === -1)
          if (begin === -1 && end === -1) {
            paragraphs.forEach(p => {
              p.style.opacity = '1';
            });
            return;
          }
          // -----------------------------------------------------------------------------------------------------
        
          let targetParagraph = null;
          let firstParagraphId = null;
        
          paragraphs.forEach(p => {
            // Use the helper function to get the ID
            const id = getParagraphId(p, selector, idAttr);
            if (id === null) return;
        
            if (firstParagraphId === null) {
              firstParagraphId = id;
            }
        
            // Note: maxParagraphId (calculated earlier) now handles what 'endParagraphId' used to track, 
            // ensuring we know the absolute last ID before the loop finishes.
        
            // Use effectiveEnd for the comparison
            if (id >= begin && id <= effectiveEnd && !targetParagraph) {
              targetParagraph = p;
            }
        
            p.style.opacity = (id >= begin && id <= effectiveEnd) ? '1' : '0.5';
          });
        
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
        
            // Cas 1 : On commence au tout début du document.
            if (begin === firstParagraphId) {
              scrollToY = 0;
            }
            // Cas 2 : La sélection tient entièrement dans l'écran, on la centre.
            else if (totalHeight < visibleHeight) {
              scrollToY = firstTop - appBarHeight - 20 - (visibleHeight / 2) + (totalHeight / 2);
            }
            // Cas par défaut : On affiche la sélection à partir du haut.
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
          
          function createToolbarButtonColor(styleIndex, targets, target, styleToolbar, isSelected) {
            const style = getStyleConfig(styleIndex);
            const button = document.createElement('button');
          
            button.innerHTML = style.icon;
          
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
            
            if (isSelected) {
              button.addEventListener('mousedown', (e) => e.preventDefault());
            }
          
            // --- Fonction interne : Création de la barre de couleurs ---
            function createColorToolbar() {
              const colorToolbar = document.createElement('div');
              colorToolbar.classList.add('toolbar', 'toolbar-colors');
              
              colorToolbar.style.top = styleToolbar.style.top;
              
              // Fonction utilitaire pour obtenir la valeur RGB d'une variable CSS
              const getRgbValue = (colorName) => {
                // Lis la valeur de la variable CSS --color-[name]-rgb à partir du document
                // (Cette valeur change automatiquement entre :root et .cc-theme--dark)
                return getComputedStyle(document.documentElement).getPropertyValue(`--color-\${colorName}-rgb`).trim();
              };
              
              // Détermination de l'icône de retour
              const isDark = isDarkTheme(); // Supposée fonction pour vérifier le thème
              
              // Bouton retour (Symbole: E639)
              const backButton = document.createElement('button');
              backButton.innerHTML = '&#xE639;';
              backButton.style.cssText = `
                font-family: jw-icons-external;
                font-size: 26px;
                padding: 3px;
                border-radius: 5px;
                margin: 0 3px;
                color: \${isDark ? 'white' : '#4f4f4f'};
                background: none;
                -webkit-tap-highlight-color: transparent;
              `;
              
              // ✅ Empêche aussi la perte de sélection pour le backButton en mode sélection
              if (isSelected) {
                backButton.addEventListener('mousedown', (e) => e.preventDefault());
              }
              
              backButton.addEventListener('click', (e) => {
                e.stopPropagation();
                colorToolbar.remove();
                styleToolbar.style.opacity = 1; // Rendre l'ancienne toolbar visible instantanément
              });
              colorToolbar.appendChild(backButton);
              
              // Détermination de l'index de couleur actif
              const { 
                  styleIndex: targetStyleIndex, 
                  colorIndex: targetColorIndex 
              } = getActiveStyleAndColorIndex(target, currentStyleIndex, getColorIndex);
                        
              // Créer un bouton pour chaque couleur
              colorsList.forEach((colorName, index) => {
                if(index == 0) return;
                const colorButton = document.createElement('button');
                const colorIndex = index; // Les index de couleur commencent à 1
                const rgbValue = getRgbValue(colorName);
                
                // 🎨 CRÉATION DU CERCLE DE COULEUR 🎨
                const colorCircle = document.createElement('div');
                colorCircle.style.cssText = `
                  width: 25px;
                  height: 25px;
                  border-radius: 50%;
                  /* Utilise l'opacité 1.0 car c'est un bouton/aperçu */
                  background-color: rgba(\${rgbValue}, 1.0);
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  box-shadow: 0 0 0 1px \${isDark ? 'rgba(255, 255, 255, 0.3)' : 'rgba(0, 0, 0, 0.15)'}; /* Bordure légère */
                `;
                
                // --- Logique d'icône sélectionnée (Symbole: E634) ---
                // Si la couleur actuelle est la couleur de l'élément sélectionné ET nous sommes en mode "highlight existant"
                if (colorIndex === targetColorIndex && styleIndex === targetStyleIndex && !isSelected) {
                  const selectedIcon = document.createElement('span');
                  // UTILISATION DE E634 POUR LA FLÈCHE DE SÉLECTION
                  selectedIcon.innerHTML = '&#xE634;'; 
                  selectedIcon.style.cssText = `
                    font-family: jw-icons-external; /* Même famille que le bouton retour */
                    font-size: 19px;
                    color: rgba(100, 100, 100, 0.5); /* Couleur semi-transparente souhaitée */
                  `;
                  colorCircle.appendChild(selectedIcon);
                } 
                
                colorButton.appendChild(colorCircle);
                
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
            
                  // 1. Mettre à jour l'index de couleur global pour le style actuel
                  setColorIndex(styleIndex, colorIndex); 
                  
                  if (isSelected) {
                    const blockRangesToSend = [];
                    const newClass = getStyleClass(styleIndex, colorIndex);
                    
                    let currentParagraphId = null;
                    let firstTarget = null;
                    let lastTarget = null;
                    let currentParagraphInfo = null;
          
                    // **********************************************
                    // ✅ FIX : Déplacer la définition de la fonction ici pour qu'elle soit dans la bonne portée
                    // **********************************************
                    function addBlockRangeForParagraph(firstEl, lastEl, paragraphInfo, blockRangesArray) {
                      const pid = paragraphInfo.id;
                      const isVerse = paragraphInfo.isVerse; // Supposée propriété dans paragraphInfo
          
                      // NOTE: 'paragraphsData' doit être accessible (variable globale ou passée en argument)
                      const paragraphData = paragraphsData.get(pid); 
                      if (!paragraphData) return;
                      
                      const { wordAndPunctTokens } = paragraphData;
                    
                      const idxFirst = wordAndPunctTokens.indexOf(firstEl);
                      const idxLast  = wordAndPunctTokens.indexOf(lastEl);
                    
                      // 🔒 Si un token n'est pas trouvé → sécurité
                      if (idxFirst === -1 || idxLast === -1) {
                        console.error(`❌ Token(s) not found in paragraph \${pid}`, { firstEl, lastEl });
                        return;
                      }
                    
                      // ✅ Toujours ordonner
                      const startIdx = Math.min(idxFirst, idxLast);
                      const endIdx   = Math.max(idxFirst, idxLast);
                    
                      blockRangesArray.push({
                        BlockType: isVerse ? 2 : 1, // Assurez-vous que isVerse est bien géré
                        Identifier: pid,
                        StartToken: startIdx,
                        EndToken: endIdx,
                      });
                    }
                    // **********************************************
                    
                    targets.forEach(element => {
                      // NOTE: 'getTheFirstTargetParagraph' doit retourner { id, isVerse, ... }
                      const info = getTheFirstTargetParagraph(element); 
                      if (!info) return;
            
                      // Appliquer le style au token immédiatement
                      element.classList.add(newClass);
                      // NOTE: 'blockRangeAttr' et 'currentGuid' doivent être accessibles
                      element.setAttribute(blockRangeAttr, currentGuid);
                      
                      // Logique de regroupement
                      if (info.id !== currentParagraphId) {
                        // S'il y avait un paragraphe précédent, on sauvegarde le highlight
                        if (firstTarget && lastTarget) {
                          // Appel : utilisation de la fonction déplacée
                          addBlockRangeForParagraph(firstTarget, lastTarget, currentParagraphInfo, blockRangesToSend);
                        }
                    
                        // On commence un nouveau paragraphe
                        currentParagraphId = info.id;
                        currentParagraphInfo = info;
                        firstTarget = element;
                        lastTarget = element;
                      } 
                      else {
                        // Même paragraphe, on met à jour la fin
                        lastTarget = element;
                      }
                    });
                    
                    // Enregistrer le dernier paragraphe
                    if (firstTarget && lastTarget) {
                      // Appel : utilisation de la fonction déplacée
                      addBlockRangeForParagraph(firstTarget, lastTarget, currentParagraphInfo, blockRangesToSend);
                    }
                    
                    
                    // Appel unique à Flutter pour tous les blockRanges
                    const finalColorIndex = getColorIndex(styleIndex);
                    // NOTE: 'window.flutter_inappwebview' doit être accessible
                    window.flutter_inappwebview.callHandler('addBlockRanges', currentGuid, styleIndex, finalColorIndex, blockRangesToSend);
                    removeAllSelected();
                  } 
                  else {
                    // --- LOGIQUE DE CHANGEMENT DE COULEUR POUR HIGHLIGHT EXISTANT ---
                    // NOTE: 'changeBlockRangeStyle' et 'blockRangeAttr' doivent être accessibles
                    changeBlockRangeStyle(target.getAttribute(blockRangeAttr), styleIndex, colorIndex);
                  }
                  
                  currentStyleIndex = styleIndex;
                  
                  // Fermeture instantanée
                  colorToolbar.remove();
                  closeToolbar(); // Supposée fonction pour fermer la toolbar principale
                });
            
                colorToolbar.appendChild(colorButton);
              });
              
              return colorToolbar; 
            }
          
            // --- Événement de clic sur le bouton principal (immédiat) ---
            button.addEventListener('click', (e) => {
              e.stopPropagation();
              
              // Supprimer l'ancienne toolbar de couleur si elle existe (pour éviter le clignotement)
              document.querySelector('.toolbar-colors')?.remove();
              
              // Créer et afficher la toolbar de couleurs (instantanné)
              const colorToolbar = createColorToolbar();
              document.body.appendChild(colorToolbar);
              
              // Rendre la toolbar principale invisible (immédiat)
              styleToolbar.style.opacity = '0';
          
              // Fermer la toolbar si on clique ailleurs (logique simplifiée)
              const closeColorToolbar = (event) => {
                // Vérifie si le clic est en dehors de la toolbar de couleur ET en dehors du bouton de couleur
                if (!colorToolbar.contains(event.target) && !button.contains(event.target)) {
                  // Fermeture instantanée
                  colorToolbar.remove();
                  styleToolbar.style.opacity = '1';
                  document.removeEventListener('click', closeColorToolbar);
                }
              };
          
              // ✅ FIX : Utiliser setTimeout(0) au lieu de requestAnimationFrame 
              // pour garantir que l'écouteur n'est pas déclenché par l'événement de clic actuel
              setTimeout(() => {
                  document.addEventListener('click', closeColorToolbar);
              }, 0);
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
            firstLongPressTarget = null;
            lastLongPressTarget = null;
            toggleSelection(false);
            isSelecting = false;
            currentGuid = '';
            pressTimer = null;
            setLongPressing(false);
            
            const selection = window.getSelection();
            selection.removeAllRanges();
          }
          
          function createToolbarBase({targets, highlightId, isSelected, target }) {
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight');
          
            // Masquer les toolbars existantes
            toolbars.forEach(toolbar => toolbar.style.opacity = '0');
          
            setTimeout(() => {
              toolbars.forEach(toolbar => toolbar.remove());
            }, 200);
          
            // Ne rien faire si la bonne toolbar existe déjà
            const existing = Array.from(toolbars).find(toolbar =>
              toolbar.getAttribute(blockRangeAttr) === highlightId
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
              toolbar.setAttribute(blockRangeAttr, highlightId);
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
          
            toolbar.appendChild(createToolbarButtonColor(0, targets, target, toolbar, isSelected));
            toolbar.appendChild(createToolbarButtonColor(1, targets, target, toolbar, isSelected));
            toolbar.appendChild(createToolbarButtonColor(2, targets, target, toolbar, isSelected));
          
            const buttons = [
              ['&#xE681;', () => isSelected ? addNote(paragraphs[0], id, isVerse, text) : addNoteWithBlockRange(text, target, highlightId)],
              ...(!isSelected && highlightId ? [['&#xE6C5;', () => removeBlockRange(highlightId)]] : []),
              ['&#xE651;', () => callHandler('copyText', { text })],
              ['&#xE676;', () => callHandler('search', { query: text })]
            ];
          
            buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));
          }
    
          function showToolbarHighlight(target, highlightId) {
            const targets = pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${highlightId}"]`);
            if (targets.length === 0) return;
            
            createToolbarBase({ targets, highlightId, isSelected: false, target });
          }
          
          function showSelectedToolbar() {
            const targets = getAllSelectedTargets('.word, .punctuation, .escape');
            if (targets.length === 0) return;
          
            createToolbarBase({
              targets,
              highlightId: null,
              isSelected: true,
              target: targets[0],
            });
          }
                    
          function showToolbar(paragraphs, pid, selector, hasAudio, type) {
            const paragraph = paragraphs[0];
            const toolbars = document.querySelectorAll('.toolbar, .toolbar-highlight, .toolbar-colors');
            
            // Chercher la toolbar correspondante au pid
            const matchingToolbar = Array.from(toolbars).find(toolbar => toolbar.getAttribute('data-pid') === pid.toString());
            
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
            // const scrollX = window.scrollX; // Pas nécessaire si on se base sur rect.left pour le calcul horizontal initial
            
            const toolbarHeight = 40; 
            const safetyMargin = 10;
            const viewportWidth = window.innerWidth;
          
            // 1. Préparation de la toolbar et des boutons
            const toolbar = document.createElement('div');
            toolbar.classList.add('toolbar');
            toolbar.setAttribute('data-pid', pid);
            
            // On s'assure que transform n'est jamais utilisé pour le centrage
            toolbar.style.transform = 'none'; 
            
            // ... (Logique pour déterminer les boutons et le texte, inchangée) ...
            let buttons = [];
            let allParagraphsText = '';
            paragraphs.forEach((paragraph, pIndex) => {
                const relevantElements = paragraph.querySelectorAll('.word, .punctuation, .escape');
                let paragraphText = '';
                relevantElements.forEach((elem, index) => {
                    const text = index === 0 ? elem.textContent.trim() : elem.textContent;
                    if (!text) return;
                    paragraphText += text;
                });
                if (paragraphText) {
                    if (allParagraphsText) allParagraphsText += ' ';
                    allParagraphsText += paragraphText;
                }
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
          
            if (hasAudio) {
              buttons.push(['&#xE65E;', () => callHandler('playAudio', { id: pid, isBible: type === 'verse' })]);
            }
            
            buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));
          
            // 2. Positionnement initial pour la mesure
            toolbar.style.visibility = 'hidden';
            toolbar.style.opacity = '0'; 
            // Position temporaire pour la mesure, sans affecter le flux de la page (important pour .offsetWidth)
            toolbar.style.position = 'absolute'; 
            
            document.body.appendChild(toolbar);
            
            // 3. Correction horizontale (Centrage et débordement)
            const toolbarWidth = toolbar.offsetWidth;
            const toolbarHalfWidth = toolbarWidth / 2;
            
            // Centre absolu du paragraphe dans le document
            const paragraphCenter = rect.left + scrollX + (rect.width / 2);
            
            // Position de départ (bord gauche de la toolbar) si elle était centrée sur le paragraphe
            let newLeft = paragraphCenter - toolbarHalfWidth; 
          
            // Correction du débordement gauche
            if (newLeft < safetyMargin) {
              newLeft = safetyMargin;
            }
            
            // Correction du débordement droit
            const rightEdge = newLeft + toolbarWidth;
            if (rightEdge > viewportWidth - safetyMargin) {
              newLeft = viewportWidth - toolbarWidth - safetyMargin;
            }
          
            // S'assurer que la correction droite n'a pas repoussé newLeft trop loin à gauche (cas d'une très longue toolbar sur petit écran)
            // On prend la plus grande des positions minimales: newLeft (corrigé) ou safetyMargin.
            newLeft = Math.max(newLeft, safetyMargin);
            
            toolbar.style.left = `\${newLeft}px`; // Application du positionnement horizontal
          
            // 4. Correction verticale (Logique inchangée, elle est robuste)
            
            // Position verticale au-dessus du paragraphe (par défaut)
            let top = rect.top + scrollY - toolbarHeight - safetyMargin;
            
            // Limite supérieure (sous l'AppBar)
            const minVisibleY = scrollY + appBarHeight + safetyMargin;
            
            // Position verticale sous le paragraphe
            const positionUnderneath = rect.bottom + scrollY + safetyMargin;
            
            if (top < minVisibleY) {
              top = positionUnderneath;
              
              // Limite inférieure 
              const maxVisibleY = scrollY + window.innerHeight - toolbarHeight - safetyMargin;
              
              if (top > maxVisibleY) {
                  top = minVisibleY; 
              }
            } 
            
            toolbar.style.top = `\${top}px`; 
          
            // 5. Affichage final
            toolbar.style.visibility = 'visible';
            toolbar.style.opacity = '1';
          }
          
          async function fetchVerseInfo(paragraph, pid) {
            const verseInfo = await window.flutter_inappwebview.callHandler('fetchVerseInfo', { id: pid });
            showVerseInfoDialog(pageCenter, verseInfo, 'verse-info-\$pid');
            closeToolbar();
          }
          
          const HEADER_HEIGHT = 45; // Hauteur fixe du header
          const PADDING_CONTENT_VERTICAL = 0; // 16px top + 16px bottom padding dans contentContainer (si padding: 16px est utilisé)
          const MIN_RESIZE_HEIGHT = 150; // Hauteur minimale de redimensionnement
          
          function applyDialogStyles(type, dialog, isFullscreen, savedPosition = null) {
              const isDark = isDarkTheme();
              const backgroundColor = type == 'note' ? null : (isDarkTheme() ? '#121212' : '#ffffff');
              
              const baseStyles = `
                position: fixed;
                box-shadow: 0 15px 50px rgba(0, 0, 0, 0.60); 
                z-index: 1000;
                background-color: \${backgroundColor};
                border: \${isFullscreen ? 'none' : '1px solid rgba(0, 0, 0, 0.1)'};
              `;
          
              if (isFullscreen) {
                  const bottomOffset = BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0);
              
                  dialog.classList.add('fullscreen');
                  // ✅ CORRECTION: S'assurer que le positionnement est basé sur top/bottom/left/right et non translate
                  dialog.style.cssText = `
                      \${baseStyles}
                      top: \${APPBAR_FIXED_HEIGHT}px;
                      left: 0;
                      right: 0;
                      bottom: \${bottomOffset}px;
                      width: 100vw;
                      height: calc(100vh - \${APPBAR_FIXED_HEIGHT + bottomOffset}px);
                      transform: none !important; /* Annuler toute transformation */
                      margin: 0;
                      border-radius: 0px;
                  `;
                  const resizeHandle = dialog.querySelector('.resize-handle');
                  if (resizeHandle) resizeHandle.style.display = 'none';
          
                  window.flutter_inappwebview?.callHandler('showFullscreenDialog', true);
              }
              else {
                  dialog.classList.remove('fullscreen');
                  const resizeHandle = dialog.querySelector('.resize-handle');
                  if (resizeHandle) resizeHandle.style.display = 'block';
          
                  // Styles de taille initiaux
                  const windowDialogStyles = `
                      width: 85%;
                      height: fit-content;
                      max-width: 600px;
                      border-radius: 16px;
                  `;
                  
                  dialog.style.cssText = baseStyles + windowDialogStyles; 
                  
                  const currentLeft = dialog.style.left;
                  const currentTop = dialog.style.top;
                  
                  if (currentLeft && currentTop && currentLeft !== '50%' && currentTop !== '50%') {
                      dialog.style.left = currentLeft;
                      dialog.style.top = currentTop;
                      dialog.style.transform = 'none';
                      
                      const resizedHeight = dialog.getAttribute('data-resized-height');
                      const resizedWidth = dialog.getAttribute('data-resized-width');
          
                      if (resizedHeight) {
                           dialog.style.height = resizedHeight;
                           
                           const contentContainer = dialog.querySelector('#contentContainer');
                           if (contentContainer) {
                              const newHeight = parseFloat(resizedHeight);
                              const contentMaxHeight = newHeight - HEADER_HEIGHT - PADDING_CONTENT_VERTICAL;
                              contentContainer.style.maxHeight = `\${Math.max(0, contentMaxHeight)}px`;
                           }
                      } else {
                           dialog.style.height = 'fit-content';
                      }
          
                      if(resizedWidth) {
                           dialog.style.width = resizedWidth;
                      } else {
                           dialog.style.width = '85%';
                      }
          
                  } else {
                      // Position de base (centrée)
                      dialog.style.top = '50%';
                      dialog.style.left = '50%';
                      dialog.style.transform = 'translate(-50%, -50%)';
                  }
          
                  window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
              }
          }
          
          function applyContentContainerStyles(type, contentContainer, isFullscreen) {
              const paddingStyle = '0px'; 
              
              // MaxHeight par défaut pour le scroll si le dialogue n'est pas redimensionné
              const maxHeight = isFullscreen 
                  ? `calc(100vh - \${APPBAR_FIXED_HEIGHT + BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + HEADER_HEIGHT}px)` 
                  : '60vh'; 
                  
              const backgroundColor = type === 'note' ? null : (isDarkTheme() ? '#121212' : '#ffffff');
              
              contentContainer.style.cssText = `
                  max-height: \${maxHeight}; 
                  overflow-y: auto;
                  background-color: \${backgroundColor};
                  user-select: text;
                  border-radius: \${isFullscreen ? '0px' : '0 0 16px 16px'};
                  padding: \${paddingStyle}; 
                  box-sizing: border-box; 
              `;
          }
          
          function setupFullscreenToggle(type, fullscreenButton, dialog, contentContainer) {
              fullscreenButton.onclick = function(event) {
                  document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
               
                  event.stopPropagation();
                  
                  const currentScroll = contentContainer.scrollTop;
                  
                  if (!globalFullscreenPreference) {
                      // Sauvegarder la taille actuelle (en pixels) avant de passer en fullscreen
                      const rect = dialog.getBoundingClientRect();
                      dialog.setAttribute('data-resized-width', `\${rect.width}px`);
                      dialog.setAttribute('data-resized-height', `\${rect.height}px`);
                  } else {
                       // Retirer les attributs de taille lors du retour du fullscreen
                       dialog.removeAttribute('data-resized-width');
                       dialog.removeAttribute('data-resized-height');
                  }
          
                  if (globalFullscreenPreference) {
                      // Sortir du fullscreen
                      applyDialogStyles(type, dialog, false);
                      applyContentContainerStyles(type, contentContainer, false);
                      fullscreenButton.innerHTML = '⛶';
                      
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
                      
                      const header = dialog.querySelector('div');
                      if (header) {
                          header.style.borderRadius = '0px';
                      }
                      
                      globalFullscreenPreference = true;
                  }
                  
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
                  if (e.target.closest('.dialog-button') || e.target.closest('.resize-handle')) return; 
          
                  isDragging = true;
                  startX = e.clientX || (e.touches && e.touches[0].clientX);
                  startY = e.clientY || (e.touches && e.touches[0].clientY);
          
                  const rect = dialog.getBoundingClientRect();
                  startLeft = rect.left;
                  startTop = rect.top;
          
                  dialog.style.transform = 'none';
                  dialog.style.left = `\${startLeft}px`;
                  dialog.style.top = `\${startTop}px`;
                  
                  // Si le dialogue était centré, la taille était relative, on la fixe avant de commencer le drag
                  if (dialog.style.width === '85%') {
                       dialog.style.width = `\${rect.width}px`;
                       dialog.style.height = `\${rect.height}px`;
                  }
          
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
              
                  const dialogRect = dialog.getBoundingClientRect();
                  const headerRect = dialog.querySelector('div:first-child').getBoundingClientRect();
          
                  const minTop = controlsVisible ? APPBAR_FIXED_HEIGHT : 0;
                  const maxLeft = window.innerWidth - dialogRect.width;
          
                  let maxDialogTop = window.innerHeight - headerRect.height;
                  if (controlsVisible) {
                      maxDialogTop -= BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0);
                  }
          
                  dialog.style.left = `\${Math.max(0, Math.min(newLeft, maxLeft))}px`;
                  dialog.style.top = `\${Math.max(minTop, Math.min(newTop, maxDialogTop))}px`;
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
          
          // ===========================================
          // FONCTION: Système de redimensionnement (CORRIGÉ POUR LA HAUTEUR)
          // ===========================================
          function setupResizeSystem(handle, dialog, contentContainer) {
              let isResizing = false;
              let startX, startY, startWidth, startHeight, startTop, startLeft;
              const MIN_WIDTH = 300;
              const MIN_HEIGHT = MIN_RESIZE_HEIGHT;
          
              const startResize = (e) => {
                  if (dialog.classList.contains('fullscreen')) return;
          
                  isResizing = true;
                  
                  dialog.style.transition = 'none';
                  dialog.style.maxWidth = 'none'; 
          
                  startX = e.clientX || (e.touches && e.touches[0].clientX);
                  startY = e.clientY || (e.touches && e.touches[0].clientY);
          
                  const rect = dialog.getBoundingClientRect();
                  startWidth = rect.width;
                  startHeight = rect.height;
                  startTop = rect.top;
                  startLeft = rect.left;
                  
                  dialog.style.transform = 'none'; 
                  dialog.style.left = `\${startLeft}px`;
                  dialog.style.top = `\${startTop}px`;
                  dialog.style.width = `\${startWidth}px`; 
                  dialog.style.height = `\${startHeight}px`;
          
                  const initialContentMaxHeight = startHeight - HEADER_HEIGHT - PADDING_CONTENT_VERTICAL;
                  contentContainer.style.maxHeight = `\${Math.max(0, initialContentMaxHeight)}px`;
                  contentContainer.style.height = `\${Math.max(0, initialContentMaxHeight)}px`;
                  contentContainer.style.overflowY = 'auto';
          
          
                  document.addEventListener('mousemove', resize);
                  document.addEventListener('mouseup', stopResize);
                  document.addEventListener('touchmove', resize);
                  document.addEventListener('touchend', stopResize);
          
                  e.preventDefault();
                  e.stopPropagation(); 
              };
          
              const resize = (e) => {
                  if (!isResizing) return;
              
                  const currentX = e.clientX || (e.touches && e.touches[0].clientX);
                  const currentY = e.clientY || (e.touches && e.touches[0].clientY);
                  
                  const deltaX = currentX - startX;
                  const deltaY = currentY - startY;
          
                  let newWidth = startWidth + deltaX;
                  let newHeight = startHeight + deltaY;
          
                  const maxBottom = window.innerHeight - (controlsVisible ? BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) : 0);
          
                  newWidth = Math.max(MIN_WIDTH, newWidth);
                  newWidth = Math.min(newWidth, window.innerWidth - startLeft);
          
                  newHeight = Math.max(MIN_HEIGHT, newHeight);
                  newHeight = Math.min(newHeight, maxBottom - startTop);
          
                  dialog.style.width = `\${newWidth}px`;
                  dialog.style.height = `\${newHeight}px`;
          
                  const contentMaxHeight = newHeight - HEADER_HEIGHT - PADDING_CONTENT_VERTICAL;
                  contentContainer.style.maxHeight = `\${Math.max(0, contentMaxHeight)}px`;
                  contentContainer.style.height = `\${Math.max(0, contentMaxHeight)}px`; 
              };
          
              const stopResize = () => {
                  isResizing = false;
                  
                  dialog.style.transition = '';
                  dialog.style.maxWidth = '600px'; 
                  
                  const currentHeight = dialog.clientHeight;
          
                  if (currentHeight >= MIN_HEIGHT) { 
                       dialog.setAttribute('data-resized-height', dialog.style.height);
                       dialog.setAttribute('data-resized-width', dialog.style.width);
                       
                       contentContainer.style.height = ''; 
                  } else {
                       dialog.style.height = 'fit-content';
                       dialog.removeAttribute('data-resized-height');
                       dialog.removeAttribute('data-resized-width'); 
          
                       applyContentContainerStyles(dialog.getAttribute('data-type'), contentContainer, false); 
                  }
          
                  document.removeEventListener('mousemove', resize);
                  document.removeEventListener('mouseup', stopResize);
                  document.removeEventListener('touchmove', resize);
                  document.removeEventListener('touchend', stopResize);
              };
          
              handle.addEventListener('mousedown', startResize);
              handle.addEventListener('touchstart', startResize);
          }
          
          // NOTE: La fonction createHeader est laissée telle quelle car elle n'a pas été modifiée dans sa logique.
          function createHeader(options, isDark, dialog, isFullscreen, canGoBack) {
              const header = document.createElement('div');
              
              const type = options.type;
              const title = options.title;
              
              const backgroundColor = type === 'note' ? 'transparent' : isDark ? '#2a2a2a' : '#f8f9fa';
            
              const borderRadius = isFullscreen ? '0px' : '16px 16px 0 0';
              
              const paddingLeftValue = type === 'base' ? '10px' : '5px';
              
              header.style.cssText = `
                  background: \${backgroundColor};
                  color: \${isDark ? '#ffffff' : '#333333'};
                  padding-left: \${paddingLeftValue};
                  padding-right: 10px;
                  font-size: 15px;
                  font-weight: 400;
                  display: flex;
                  align-items: center;
                  justify-content: space-between;
                  height: \${HEADER_HEIGHT}px;
                  border-bottom: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
                  border-radius: \${borderRadius};
              `;
              
              header.addEventListener('touchstart', (e) => {
                  document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
              });
              
          
              // Left area: back button + title
              const leftArea = document.createElement('div');
              leftArea.style.cssText = 'display: flex; align-items: center; gap: 8px;';
          
              if (canGoBack) {
                  const backButton = document.createElement('button');
                  backButton.classList.add('dialog-button', 'back-button', 'jwf-jw-icons-external', 'jwi-chevron-left');
                  backButton.style.cssText = `
                      font-size: 20px;
                      padding: 0px;
                      border: none;
                      color: inherit;
                      cursor: pointer;
                      transition: all 0.2s ease;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      width: 30px;
                      height: 30px;
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
                    padding: 0px;
                    border: none;
                    color: inherit;
                    cursor: pointer;
                    transition: all 0.2s ease;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    width: 30px;
                    height: 30px;
                `;
                
                moreButton.onclick = (event) => {
                    document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
                
                    const popup = header.closest('.customDialog');
                    const { element: optionsMenu, colorMenu } = createOptionsMenu(options.noteData.noteGuid, popup, isDark);
                
                    document.body.appendChild(optionsMenu);
                    document.body.appendChild(colorMenu);
                
                    const rect = event.target.getBoundingClientRect();
                    optionsMenu.style.top = `\${rect.bottom + 8}px`;
                    optionsMenu.style.left = `\${rect.right - optionsMenu.offsetWidth - moreButton.offsetWidth - 20}px`;
                    optionsMenu.style.display = 'flex';
                
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
                  padding: 0px;
                  border: none;
                  color: inherit;
                  cursor: pointer;
                  transition: all 0.2s ease;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  width: 30px;
                  height: 30px;
              `;
          
              const closeButton = document.createElement('button');
              closeButton.innerHTML = '✕';
              closeButton.className = 'dialog-button';
              closeButton.style.cssText = `
                  font-family: jw-icons-external;
                  font-size: 18px;
                  padding: 0px;
                  border: none;
                  border-radius: 8px;
                  color: inherit;
                  cursor: pointer;
                  transition: all 0.2s ease;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  width: 30px;
                  height: 30px;
              `;
          
              closeButton.onclick = (event) => {
                  event.stopPropagation();
                  event.preventDefault();
                  
                  closeDialog();
              };
          
              rightArea.appendChild(fullscreenButton);
              rightArea.appendChild(closeButton);
          
              header.appendChild(leftArea);
              header.appendChild(rightArea);
          
              return {
                  element: header,
                  dragArea: titleArea,
                  fullscreenButton,
                  closeButton
              };
          }

          let dialogHistory = [];
          let currentDialogIndex = -1;
          let lastClosedDialog = null; 
          let globalFullscreenPreference = false; 
          let dialogIdCounter = 0; 
          let baseDialog = null; 
          
          // --- Constantes d'Icônes ---
          const ICON_BACK_HISTORY = 'jwi-chevron-left'; 
          const ICON_REOPEN_CLOSED = 'jwi-chevron-right'; 
          const ARROW_BACK = '&#xE60B;'; 
          const DIAMOND = '&#xE658;'; 
          
          // Icônes pour les différents types de dialogue
          const DIALOG_ICONS = {
              'base': DIAMOND, 
              'verse': '&#xE61D;', 
              'verse-references': '&#xE61F;', 
              'verse-info': '&#xE620;', 
              'publication': '&#xE629;', 
              'footnote': '&#xE69B;', 
              'note': '&#xE6BF;', 
              'default': DIAMOND 
          };
          
          async function createNotesDashboardContent(container, opt) {
              const isBibleMode = isBible(); 
          
              container.innerHTML = '';
              const innerContainer = document.createElement('div');
              container.appendChild(innerContainer);
          
              if (!notes || notes.length === 0) {
                  innerContainer.style.display = 'flex';
                  innerContainer.style.justifyContent = 'center';
                  innerContainer.style.height = '100%';
                  innerContainer.innerHTML = '<p>Aucune notes</p>';
                  return;
              }
          
              // -----------------------------------------
              // 🔥 TRIER LES NOTES PAR BlockIdentifier
              // -----------------------------------------
              const sortedNotes = [...notes].sort((a, b) => {
                  const A = a.BlockIdentifier || '';
                  const B = b.BlockIdentifier || '';
                  if (A < B) return -1;
                  if (A > B) return 1;
                  return (a.Guid || "").localeCompare(b.Guid || "");
              });
          
              // -----------------------------------------
              // 🔥 CRÉER L'INDEX EN HAUT (CARRÉS)
              // -----------------------------------------
              const indexContainer = document.createElement('div');
              indexContainer.style.display = 'flex';
              indexContainer.style.flexWrap = 'wrap';
              indexContainer.style.gap = '8px';
              indexContainer.style.marginBottom = '16px';
              innerContainer.appendChild(indexContainer);
          
              const blockIdSet = new Set();
          
              sortedNotes.forEach(note => {
                  if (isBibleMode && note.BlockIdentifier && !blockIdSet.has(note.BlockIdentifier)) {
                      blockIdSet.add(note.BlockIdentifier);
          
                      // Carré pour accéder à ce groupe
                      const square = document.createElement('div');
                      square.textContent = note.BlockIdentifier; // texte à l’intérieur
                      square.style.cursor = 'pointer';
                      square.style.width = '50px';       // largeur uniforme
                      square.style.height = '50px';      // hauteur uniforme
                      square.style.display = 'flex';
                      square.style.alignItems = 'center';
                      square.style.justifyContent = 'center';
                      square.style.backgroundColor = '#757575'; // couleur demandée
                      square.style.color = '#fff';              // texte en blanc pour contraste
                      square.style.borderRadius = '4px';        // coins légèrement arrondis
                      square.style.fontSize = '0.85em';
                      square.style.fontWeight = 'bold';
          
                      // Scroll vers le groupe
                      square.onclick = () => {
                          const target = document.getElementById(`block-\${note.BlockIdentifier}`);
                          if (target) {
                              target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                          }
                      };
          
                      indexContainer.appendChild(square);
                  }
              });
          
              // -----------------------------------------
              // 🔥 AFFICHAGE DES NOTES PAR GROUPES
              // -----------------------------------------
              let lastBlockIdentifier = null;
          
              sortedNotes.forEach(note => {
          
                  // Si nouveau BlockIdentifier → ajouter titre avec id
                  if (isBibleMode && note.BlockIdentifier && note.BlockIdentifier !== lastBlockIdentifier) {
          
                      const blockElem = document.createElement('div');
                      blockElem.textContent = cachedPages[currentIndex].title + ':' + note.BlockIdentifier;
          
                      blockElem.id = `block-\${note.BlockIdentifier}`; // pour le scroll
                      blockElem.style.fontWeight = 'bold';
                      blockElem.style.margin = '40px 0 6px 8px';
          
                      innerContainer.appendChild(blockElem);
                      lastBlockIdentifier = note.BlockIdentifier;
                  }
          
                  // Note
                  const noteData = {
                      noteGuid: note.Guid,
                      title: note.Title,
                      content: note.Content,
                      tagsId: note.TagsId,
                      colorIndex: note.ColorIndex
                  };
          
                  const newNote = { noteData };
                  const noteElement = createNoteContent(innerContainer, newNote);
          
                  if (noteElement) {
                      noteElement.style.marginBottom = '16px';
                      innerContainer.appendChild(noteElement);
                  }
              });
          }
          
          /**
           * Initialise le dialogue de base
           */
          function initializeBaseDialog() {
              if (baseDialog) return; 
          
              baseDialog = {
                  options: {
                      title: 'Notes', // Mis à jour pour refléter le contenu
                      type: 'base', 
                      // 🚨 Utilisation de la nouvelle fonction pour le contenu
                      contentRenderer: createNotesDashboardContent
                  },
                  canGoBack: false, 
                  type: 'base',
                  dialogId: 'customDialog-base',
              };
          }
          initializeBaseDialog(); // Initialisation déplacée ici pour la clarté.
          
          function hideAllDialogs() {
              document.querySelectorAll('.customDialog').forEach(dialog => {
                  dialog.style.display = 'none';
              });
          }
          
          function closeDialog() {
              document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
              
              // Ferme l'historique complet, SAUF si le seul élément est le baseDialog
              if (currentDialogIndex < 0 || dialogHistory.length === 0) return;
          
              const currentDialogData = dialogHistory[currentDialogIndex];
              const dialog = document.getElementById(currentDialogData.dialogId);
              
              if (dialog) {
                  dialog.style.display = 'none';
              }
          
              // Le baseDialog n'est jamais le lastClosedDialog
              if (currentDialogData.type !== 'base') {
                  lastClosedDialog = {
                      ...currentDialogData,
                      historyIndex: currentDialogIndex,
                      fullHistory: [...dialogHistory],
                  };
              }
              
              // On vide tout l'historique
              dialogHistory = [];
              currentDialogIndex = -1;
          
              showFloatingButton(); 
          
              window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
              window.flutter_inappwebview?.callHandler('showDialog', false);
          }
          
          function removeCurrentDialog() {
              // Correction: On ne peut pas retirer le baseDialog (index 0)
              if (currentDialogIndex <= 0 || dialogHistory.length === 0) return; 
          
              const dialogData = dialogHistory[currentDialogIndex];
              const dialog = document.getElementById(dialogData.dialogId);
          
              if (dialog) {
                  dialog.remove();
              }
              
              dialogHistory.splice(currentDialogIndex, 1);
              currentDialogIndex = dialogHistory.length - 1;
          
              if (currentDialogIndex >= 0) {
                  showDialogFromHistory(dialogHistory[currentDialogIndex]);
              } else {
                  // Cela ne devrait jamais arriver car le baseDialog est toujours le premier
                  window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
                  window.flutter_inappwebview?.callHandler('showDialog', false);
                  showFloatingButton(); 
              }
          }
          
          
          function removeDialogByNoteGuid(noteGuid) {
              if (!noteGuid) return false;
              
              const dialogIndex = dialogHistory.findIndex(item => 
                  item.type === 'note' && 
                  item.options?.noteData?.noteGuid === noteGuid
              );
              
              if (dialogIndex === -1) return false;
              
              const dialogData = dialogHistory[dialogIndex];
              const dialog = document.getElementById(dialogData.dialogId);
              
              if (dialog) {
                  dialog.remove();
              }
              
              dialogHistory.splice(dialogIndex, 1);
              
              if (dialogIndex <= currentDialogIndex) {
                  currentDialogIndex = Math.max(-1, currentDialogIndex - 1);
              }
              
              if (dialogIndex === currentDialogIndex + 1 && dialogHistory.length > 0) {
                  if (currentDialogIndex >= 0) {
                      showDialogFromHistory(dialogHistory[currentDialogIndex]);
                  } else {
                      window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
                      window.flutter_inappwebview?.callHandler('showDialog', false);
                  }
              } else if (dialogHistory.length === 0) {
                  currentDialogIndex = -1;
                  window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
                  window.flutter_inappwebview?.callHandler('showDialog', false);
              }
              
              return true;
          }
          
          function goBackDialog() {
              // Correction: On ne peut reculer que si l'index actuel est > 0 (pour éviter le baseDialog)
              if (currentDialogIndex > 0 && dialogHistory.length > 1) {
                  const currentDialog = dialogHistory[currentDialogIndex];
                  const dialogElement = document.getElementById(currentDialog.dialogId);
                  
                  if (dialogElement) {
                      // Retirer l'élément DOM du dialogue que l'on quitte
                      dialogElement.remove(); 
                  }
                  
                  // Retirer l'élément de l'historique
                  dialogHistory.splice(currentDialogIndex, 1);
                  currentDialogIndex--;
                  
                  const previousDialog = dialogHistory[currentDialogIndex];
                  showDialogFromHistory(previousDialog);
                  
                  // Mettre à jour la capacité de reculer pour le nouveau dialogue actuel
                  // C'est true si l'index actuel > 0 (c'est-à-dire s'il n'est pas le baseDialog)
                  previousDialog.canGoBack = currentDialogIndex > 0;
                  return true;
              }
              return false;
          }
          
          function showDialogFromHistory(historyItem) {
              hideAllDialogs();
          
              const existingDialog = document.getElementById(historyItem.dialogId);
              let dialog;
          
              if (existingDialog) {
                  dialog = existingDialog;
                  dialog.style.display = 'block';
              } 
              else {
                  // Note: Ici, on passe le 'canGoBack' de l'historique
                  dialog = createDialogElement(historyItem.options, historyItem.canGoBack, globalFullscreenPreference, 0, historyItem.dialogId);
                  document.body.appendChild(dialog);
              }
          
              if (typeof applyDialogStyles === 'function') {
                  applyDialogStyles(historyItem.type, dialog, globalFullscreenPreference);
              }
              
              if (historyItem.type === 'note' && typeof getNoteClass === 'function') {
                  const noteClass = getNoteClass(historyItem.options.noteData.colorIndex, false);
                  dialog.classList.add(noteClass);
              }
          
              const isFullscreen = historyItem.type !== 'base' && globalFullscreenPreference;
              window.flutter_inappwebview?.callHandler('showFullscreenDialog', isFullscreen);
              window.flutter_inappwebview?.callHandler('showDialog', true);
          
              updateFloatingButtonForClose();
              
              return dialog;
          }
          
          function showDialog(options) {
              if (!baseDialog) initializeBaseDialog();
          
              // 1. Assurer que le baseDialog est le premier élément si on ouvre un nouveau dialogue
              if (dialogHistory.length === 0) {
                  dialogHistory.push(baseDialog);
                  currentDialogIndex = 0;
              }
              
              updateFloatingButtonForClose();
              
              // CHAÎNE LITTÉRALE : \${options.noteData.noteGuid}
              const currentUniqueKey = options.href 
                  || (options.type === 'note' && options.noteData?.noteGuid ? `noteGuid-\${options.noteData.noteGuid}` : null);
                  
              let existingDialogIndex = -1;
          
              // 2. Vérifier l'existence (en ignorant le baseDialog à l'index 0)
              if (currentUniqueKey) {
                  existingDialogIndex = dialogHistory.findIndex((item, index) => {
                      // Ne jamais considérer le baseDialog (index 0) pour la réactivation/remplacement
                      if (index === 0) return false; 
                      // CHAÎNE LITTÉRALE : \${item.options.noteData.noteGuid}
                      const historyItemKey = item.options.href 
                          || (item.options.type === 'note' && item.options.noteData?.noteGuid ? `noteGuid-\${item.options.noteData.noteGuid}` : null);
                      return historyItemKey === currentUniqueKey;
                  });
              }
          
              // 3. Logique de Remplacement (`replace: true`)
              if (existingDialogIndex !== -1 && options.replace === true) {
                  const dialogToRemove = dialogHistory[existingDialogIndex];
                  const dialogElement = document.getElementById(dialogToRemove.dialogId);
                  
                  if (dialogElement) {
                      dialogElement.remove();
                  }
                  
                  dialogHistory.splice(existingDialogIndex, 1);
                  
                  // Mettre à jour l'index actuel après la suppression
                  if (existingDialogIndex === currentDialogIndex) {
                      // L'élément remplacé était le dernier, on recule
                      currentDialogIndex = Math.max(0, currentDialogIndex - 1); 
                  } else if (existingDialogIndex < currentDialogIndex) {
                      // L'élément supprimé était avant le dernier, on décale l'index
                      currentDialogIndex--;
                  }
                  
                  // Maintenant, on ajoute le nouveau dialogue à la fin de l'historique, comme d'habitude.
                  // On continue au point 5.
              }
              // 4. Logique de Réactivation d'un dialogue existant
              else if (existingDialogIndex !== -1) {
                  const existingHistoryItem = dialogHistory[existingDialogIndex];
                  
                  if (existingDialogIndex === currentDialogIndex) {
                      const existingDialogElement = document.getElementById(existingHistoryItem.dialogId);
                      if (existingDialogElement) {
                          existingDialogElement.style.display = 'block';
                      }
                      return existingDialogElement;
                  }
          
                  // On le déplace à la fin de l'historique
                  dialogHistory.splice(existingDialogIndex, 1);
                  dialogHistory.push(existingHistoryItem);
                  currentDialogIndex = dialogHistory.length - 1;
                  
                  // Correction: canGoBack est true si on n'est pas le baseDialog (index 0)
                  existingHistoryItem.canGoBack = currentDialogIndex > 0; 
                  
                  return showDialogFromHistory(existingHistoryItem);
              }
              
              // 5. Création et Ajout d'un Nouveau Dialogue
              
              dialogIdCounter++;
              // CHAÎNE LITTÉRALE : \${dialogIdCounter}
              const newDialogId = `customDialog-\${dialogIdCounter}`;
              
              const newHistoryItem = {
                  options: options,
                  // Correction: canGoBack est true si on n'est pas le baseDialog (donc s'il y a plus d'un élément au total)
                  canGoBack: dialogHistory.length > 0, 
                  type: options.type || 'default',
                  dialogId: newDialogId,
              };
          
              // Si on était sur le baseDialog et qu'on ouvre un nouveau dialogue,
              // on doit d'abord masquer le baseDialog pour ne pas avoir deux dialogues actifs
              if (currentDialogIndex === 0) {
                  hideAllDialogs();
              }
              
              dialogHistory.push(newHistoryItem);
              currentDialogIndex = dialogHistory.length - 1;
              
              // hideAllDialogs() est appelé dans showDialogFromHistory
              // hideAllDialogs(); 
             
              return showDialogFromHistory(newHistoryItem);
          }
          
          /**
           * Crée l'élément DOM du dialogue.
           */
          function createDialogElement(options, canGoBack, isFullscreenInit = false, scrollTopInit = 0, newDialogId = null) {
              let isFullscreen = isFullscreenInit;
              
              // CHAÎNE LITTÉRALE : \${dialogIdCounter}
              const dialog = document.createElement('div');
              dialog.id = newDialogId || `customDialog-\${dialogIdCounter}`;
              dialog.classList.add('customDialog');
              dialog.setAttribute('data-type', options.type || 'default');
              
              if (typeof applyDialogStyles === 'function') {
                  applyDialogStyles(options.type, dialog, isFullscreen);
              }
              dialog.style.display = 'block';
          
              const header = createHeader(options, isDarkTheme(), dialog, isFullscreen, canGoBack);
              if (typeof setupDragSystem === 'function') {
                  setupDragSystem(header.element, dialog);
              }
          
              const contentContainer = document.createElement('div');
              contentContainer.id = 'contentContainer';
              if (typeof applyContentContainerStyles === 'function') {
                  applyContentContainerStyles(options.type, contentContainer, isFullscreen);
              }
              
              contentContainer.style.cssText += `
                  flex-grow: 1;
                  min-height: 0;
                  overflow-y: auto;
              `;
          
              if (options.type === 'note' && options.noteData && options.noteData.colorIndex && typeof getNoteClass === 'function') {
                  const noteClass = getNoteClass(options.noteData.colorIndex, false);
                  dialog.classList.add(noteClass);
              }
          
              if (options.contentRenderer) {
                  options.contentRenderer(contentContainer, options);
              }
          
              setTimeout(() => {
                  contentContainer.scrollTop = scrollTopInit;
              }, 10);
          
              if (typeof setupFullscreenToggle === 'function') {
                  setupFullscreenToggle(
                      options.type,
                      header.fullscreenButton,
                      dialog,
                      contentContainer
                  );
              }
          
              dialog.appendChild(header.element);
              dialog.appendChild(contentContainer);
          
              const resizeHandle = document.createElement('div');
              resizeHandle.classList.add('resize-handle');
          
              // CHAÎNES LITTÉRALES
              resizeHandle.style.cssText = `
                  position: absolute;
                  bottom: 0;
                  right: 0;
                  width: 20px;
                  height: 20px;
                  cursor: nwse-resize;
                  z-index: 1001;
                  border-right: 2px solid \${isDarkTheme() ? 'rgba(255, 255, 255, 0.5)' : 'rgba(0, 0, 0, 0.5)'};
                  border-bottom: 2px solid \${isDarkTheme() ? 'rgba(255, 255, 255, 0.5)' : 'rgba(0, 0, 0, 0.5)'};
                  border-bottom-right-radius: 16px;
              `;
              dialog.appendChild(resizeHandle);
          
              if (typeof setupResizeSystem === 'function') {
                  setupResizeSystem(resizeHandle, dialog, contentContainer);
              }
              return dialog;
          }
          
          function restoreLastDialog() {
              if (!lastClosedDialog) return;
              
              // Correction: Si l'historique est vide, on restaure l'historique complet,
              // en s'assurant que le baseDialog est le premier.
              if (dialogHistory.length === 0) {
                  dialogHistory = lastClosedDialog.fullHistory;
                  currentDialogIndex = lastClosedDialog.historyIndex;
                  
                  // Assurer que le baseDialog est à l'index 0 et que l'index actuel est au moins 0
                  if (dialogHistory[0].type !== 'base') {
                      dialogHistory.unshift(baseDialog);
                      currentDialogIndex++;
                  }
                  currentDialogIndex = Math.max(0, currentDialogIndex);
                  
                  showDialogFromHistory(dialogHistory[currentDialogIndex]);
              } 
              else {
                  // Si l'historique est déjà ouvert, on ouvre juste le dernier dialogue fermé
                  // (il sera ajouté au-dessus de l'historique existant)
                  showDialog(lastClosedDialog.options);
              }
              
              lastClosedDialog = null; 
          
              updateFloatingButtonForClose(); 
          
              window.flutter_inappwebview?.callHandler('showDialog', true);
          }
          
          /**
           * Affiche le baseDialog lorsque l'historique est vide.
           */
          function showBaseDialog() {
              if (!baseDialog) initializeBaseDialog();
          
              hideAllDialogs();
              dialogHistory = [];
              currentDialogIndex = -1;
              
              dialogHistory.push(baseDialog);
              currentDialogIndex = 0;
              
              showDialogFromHistory(baseDialog);
              
              updateFloatingButtonForClose();
          }
          // ... (Reste des fonctions utilitaires inchangé, à l'exception des chaînes littérales que je ne peux pas garantir)
          
          function createFloatingButton() {
              let floatingButton = document.getElementById('dialogFloatingButton');
              if (floatingButton) return floatingButton;
              
              const isDark = isDarkTheme();
              const backgroundColor = isDark ? darkPrimaryColor : lightPrimaryColor;
              
              floatingButton = document.createElement('div');
              floatingButton.classList.add('floating-button');
              floatingButton.id = 'dialogFloatingButton';
              floatingButton.innerHTML = DIAMOND;
              // Positionnement dynamique
              floatingButton.style.bottom = `\${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 25}px`;
              
              // Couleur du texte ou icône
              floatingButton.style.color = isDark ? '#333333' : '#ffffff';
              
              // Couleur de fond (si nécessaire)
              floatingButton.style.backgroundColor = backgroundColor;
              document.body.appendChild(floatingButton);
              return floatingButton;
          }
          
          function showFloatingButton() {
              const floatingButton = createFloatingButton();
              
              if (dialogHistory.length === 0) {
                  if (lastClosedDialog) {
                      // État 1: Restaurer
                      const dialogType = lastClosedDialog.type || 'default';
                      floatingButton.innerHTML = DIALOG_ICONS[dialogType] || DIALOG_ICONS['default'];
                      floatingButton.onclick = restoreLastDialog;
                  } else {
                      // État 2: Ouvrir le baseDialog
                      floatingButton.innerHTML = DIALOG_ICONS['base'];
                      floatingButton.onclick = showBaseDialog;
                  }
              } else {
                  // Le dialogue est actif, le FAB sert à fermer
                  updateFloatingButtonForClose();
                  return; 
              }
              
              // Animation d'apparition
              if(controlsVisible) {
                  floatingButton.style.opacity = '1';
              } else {
                  floatingButton.style.opacity = '0';
              }
          }
          
          function updateFloatingButtonForClose() {
              const floatingButton = createFloatingButton();
              
              if (dialogHistory.length > 0) {
                  // Le FAB sert à Fermer/Revenir à la base, même si c'est le baseDialog qui est affiché.
                  // C'est la fonction closeDialog qui gère l'effacement de l'historique.
                  floatingButton.innerHTML = ARROW_BACK; 
                  floatingButton.onclick = closeDialog; 
                  
                  if(controlsVisible) {
                      floatingButton.style.opacity = '1';
                  }
              } 
              else {
                  hideFloatingButton();
              }
          }
          
          function hideFloatingButton() {
              const floatingButton = document.getElementById('dialogFloatingButton');
              if (floatingButton) {
                  floatingButton.style.opacity = '0';
              }
          }
          
          // =============================================================================
          // V. Initialisation
          // =============================================================================
          
          // Initialiser le FAB au chargement
          showFloatingButton();

          async function openNoteDialog(noteGuid, userMarkGuid) {
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
                      title: note.Title,
                      content: note.Content,
                      tagsId: note.TagsId, 
                      colorIndex: note.ColorIndex,
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
          
              const { noteGuid, title, content, tagsId, colorIndex } = options.noteData;
              const isDark = isDarkTheme();
              const isEditMode = true;
              
              const noteClass = getNoteClass(colorIndex, false);
          
              const dialogElement = contentContainer.closest('.customDialog');
              if (dialogElement) {
                  dialogElement.classList.add('note-dialog');
              }
          
              // 🎯 CONTENEUR DE CONTENU DE LA NOTE (pour le padding)
              const noteContentWrapper = document.createElement('div');
              noteContentWrapper.classList.add('note-content-wrapper');
              noteContentWrapper.id = `data-note-guid-\${noteGuid}`;
              noteContentWrapper.style.cssText = `
                  padding: 16px;
                  box-sizing: border-box;
              `;
              noteContentWrapper.classList.add(noteClass);
          
              // 📝 TITRE
              const titleElement = document.createElement('textarea');
              titleElement.className = 'note-title';
              titleElement.value = title || '';
              titleElement.placeholder = 'Titre de la note';
              titleElement.style.cssText = `
                  border: none;
                  outline: none;
                  resize: none;
                  font-size: 20px;
                  font-weight: bold;
                  line-height: 1.3;
                  background: transparent;
                  color: inherit;
                  padding: 4px 0;
                  /* Le titre ne doit pas défiler, il doit s'étendre verticalement jusqu'à ce que overflow:hidden le coupe s'il n'y a pas assez de place, 
                     mais comme nous désactivons l'auto-resize, il agira comme un textarea classique (qui scroll en interne s'il ne peut pas grandir) */
                  overflow: hidden; 
                  width: 100%;
                  box-sizing: border-box;
                  display: block;
                  margin-bottom: 12px;
              `;
              
              const autoResizeTitle = () => {
                  const initialScrollTop = contentContainer.scrollTop;
                  titleElement.style.height = 'auto';
                  titleElement.style.height = titleElement.scrollHeight + 'px';
                  contentContainer.scrollTop = initialScrollTop; // Tente de maintenir la position
              };
          
              titleElement.addEventListener('input', () => {
                  // L'utilisateur a demandé de ne PAS auto-réajuster le titre.
                  autoResizeTitle(); 
                  saveChanges();
              });
          
              // SÉPARATEUR
              const separator1 = document.createElement('div');
              separator1.style.cssText = `
                  height: 1px;
                  background: \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)'};
                  margin: 12px 0;
              `;
          
              // 📄 CONTENU
              const contentElement = document.createElement('textarea');
              contentElement.className = 'note-content';
              contentElement.value = content || '';
              contentElement.placeholder = 'Écrivez votre note ici...';
              contentElement.style.cssText = `
                  border: none;
                  outline: none;
                  resize: none;
                  font-size: inherit;
                  line-height: 1.5;
                  background: transparent;
                  color: inherit;
                  overflow: hidden; /* Important : le conteneur parent (contentContainer) gère le scroll */
                  padding: 8px 0;
                  width: 100%;
                  box-sizing: border-box;
                  display: block;
                  margin-bottom: 12px;
                  min-height: 200px;
              `;
              
              const autoResizeContent = () => {
                  const initialScrollTop = contentContainer.scrollTop;
                  contentElement.style.height = 'auto';
                  contentElement.style.height = contentElement.scrollHeight + 'px';
                  contentContainer.scrollTop = initialScrollTop; // Tente de maintenir la position
              };
          
              contentElement.addEventListener('input', () => {
                  autoResizeContent();
                  saveChanges();
              });
          
              // SÉPARATEUR
              const separator2 = document.createElement('div');
              separator2.style.cssText = `
                  height: 1px;
                  background: \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)'};
                  margin: 12px 0;
              `;
          
              // 🏷️ GESTION DES TAGS
             const currentTagIds = (typeof tagsId === 'string' && tagsId !== '')
              ? tagsId.split(',')
                      .map(id => parseInt(id))
                      .filter(id => !isNaN(id))
              : [];
                  
              const createTagElement = (tag) => {
                  const tagElement = document.createElement('span');
                  tagElement.style.cssText = `
                      display: inline-flex;
                      align-items: center;
                      background: \${isDark ? '#4a4a4a' : 'rgba(52, 152, 219, 0.1)'};
                      color: \${isDark ? '#fff' : '#2c3e50'};
                      padding: 6px 10px;
                      border-radius: 20px;
                      font-size: 14px;
                      font-weight: 500;
                      white-space: nowrap;
                      box-shadow: 0 2px 6px rgba(0,0,0,0.1);
                      border: 1px solid \${isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0, 0, 0, 0.1)'};
                      cursor: pointer;
                  `;
                  
                  const text = document.createElement('span');
                  text.textContent = tag.Name;
                  text.style.pointerEvents = 'none';
                  tagElement.appendChild(text);
          
                  const closeBtn = document.createElement('span');
                  closeBtn.textContent = '×';
                  closeBtn.style.cssText = `
                      margin-left: 6px;
                      cursor: pointer;
                      font-weight: bold;
                      color: \${isDark ? '#e0e0e0' : 'inherit'};
                      font-size: 18px;
                      line-height: 1;
                      padding: 0 2px;
                  `;
                  
                  closeBtn.onclick = (e) => {
                      e.preventDefault();
                      tagsContainer.removeChild(tagElement);
                      const index = currentTagIds.indexOf(tag.TagId);
                      if (index > -1) currentTagIds.splice(index, 1);
                      window.flutter_inappwebview.callHandler('removeTagIdFromNote', { Guid: noteGuid, TagId: tag.TagId });
                      setTimeout(() => tagInput.focus(), 10);
                  };
                  
                  tagElement.appendChild(closeBtn);
                  tagElement.onclick = (e) => {
                      if (e.target === closeBtn) return;
                      window.flutter_inappwebview.callHandler('openTagPage', { TagId: tag.TagId });
                  };
                  
                  return tagElement;
              };
          
              const addTagToUI = (tag) => {
                  if (!currentTagIds.includes(tag.TagId)) {
                      const tagElement = createTagElement(tag);
                      tagsContainer.insertBefore(tagElement, tagInputWrapper);
                      currentTagIds.push(tag.TagId);
                      window.flutter_inappwebview.callHandler('addTagIdToNote', { Guid: noteGuid, TagId: tag.TagId });
                  }
              };
          
              // 🏷️ CONTENEUR DE TAGS
              const tagsContainer = document.createElement('div');
              tagsContainer.style.cssText = `
                  display: flex;
                  flex-wrap: wrap;
                  gap: 8px;
                  padding: 12px 0;
                  padding-bottom: 20px;
                  min-height: auto;
              `;
              
              // Charger les tags existants
              (() => {
                  if (!Array.isArray(currentTagIds) || currentTagIds.length === 0) return;
                  try {
                      currentTagIds.forEach(tagId => {
                          const tag = tags?.find(t => t.TagId === tagId);
                          if (!tag) return;
                          const el = createTagElement(tag);
                          if (el) tagsContainer.appendChild(el);
                      });
                  } catch (error) {
                      console.error('Erreur lors du chargement des tags :', error);
                  }
              })();
          
              const tagInputWrapper = document.createElement('div');
              tagInputWrapper.style.cssText = `
                  display: flex;
                  align-items: center;
                  gap: 10px;
                  min-width: 150px;
                  position: relative;
              `;
          
              const tagInput = document.createElement('input');
              tagInput.className = 'note-tags';
              tagInput.type = 'text';
              tagInput.placeholder = 'Ajouter une catégorie...';
              tagInput.style.cssText = `
                  border: none;
                  outline: none;
                  font-size: 14px;
                  flex: 1;
                  min-width: 100px;
                  padding: 4px;
                  background: transparent;
                  color: inherit;
              `;
              
              // 💡 SUGGESTIONS OVERLAY (FIXED)
              const suggestionsList = document.createElement('div');
              suggestionsList.className = 'suggestions-list';
              
              suggestionsList.style.cssText = `
                  position: fixed;
                  z-index: 100001; /* Z-index élevé pour être au premier plan */
                  background: \${isDark ? '#333' : 'rgba(255, 255, 255, 0.95)'};
                  border: 1px solid \${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
                  border-radius: 8px;
                  box-shadow: 0 4px 16px rgba(0,0,0,0.15);
                  backdrop-filter: blur(10px);
                  max-height: 250px;
                  overflow-y: auto; 
                  -webkit-overflow-scrolling: touch; 
                  overscroll-behavior: contain; 
                  display: none;
              `;
          
              // 🚀 AJOUT CRUCIAL : Isolation du défilement de la liste de suggestions
              // ----------------------------------------------------------------------
          
              // 1. Isolation pour la souris (molette)
              suggestionsList.addEventListener('wheel', (e) => {
                  e.stopPropagation(); // Empêche le défilement de remonter aux parents (contentContainer/body)
              });
          
              // 2. Isolation pour le tactile (touchmove)
              suggestionsList.addEventListener('touchstart', (e) => {
                  // Enregistre la position de départ pour calculer la direction du défilement
                  suggestionsList._startY = e.touches[0].pageY;
              }, { passive: true }); // Lecture seule
          
              suggestionsList.addEventListener('touchmove', (e) => {
                  if (suggestionsList.scrollHeight <= suggestionsList.offsetHeight) {
                      // Si la liste n'a pas besoin de défilement, on ne fait rien
                      return;
                  }
          
                  const currentY = e.touches[0].pageY;
                  const delta = suggestionsList._startY - currentY; // Delta positif = défilement vers le bas
                  
                  const isAtTop = suggestionsList.scrollTop === 0 && delta < 0; 
                  const isAtBottom = (suggestionsList.scrollHeight - suggestionsList.offsetHeight - suggestionsList.scrollTop) <= 1 && delta > 0;
          
                  if (!isAtTop && !isAtBottom) {
                      // Si l'utilisateur est au milieu de la liste, on arrête la propagation du mouvement
                      e.stopPropagation();
                  } else {
                       // Si l'utilisateur est aux extrémités ET essaie de défiler au-delà, on empêche le défilement par défaut (qui irait sur le parent)
                       e.preventDefault();
                  }
              }, { passive: false }); // 'passive: false' est CRUCIAL pour que preventDefault fonctionne
          
              async function addTagToDatabase(value) {
                  const result = await window.flutter_inappwebview.callHandler('addTag', { Name: value });    
                  if (result && result.Tag) addTagToUI(result.Tag);
              }
          
              const showSuggestions = async (filteredTags, query) => {
                  suggestionsList.innerHTML = '';
                  const value = query.trim();
                  const exactMatch = filteredTags.some(tag => tag.Name.toLowerCase() === value.toLowerCase());
          
                  if (value !== '' && !exactMatch) {
                      const addNew = document.createElement('div');
                      addNew.textContent = `Ajouter la catégorie: "\${value}"`;
                      addNew.style.cssText = `
                          padding: 12px 16px;
                          cursor: pointer;
                          font-size: 14px;
                          color: \${isDark ? '#fff' : '#2c3e50'};
                          border-bottom: \${filteredTags.length > 0 ? '1px solid ' + (isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)') : 'none'};
                          white-space: nowrap;
                          user-select: none;
                          -webkit-user-select: none;
                      `;
                      
                      addNew.onmousedown = async (e) => {
                          e.preventDefault();
                          await addTagToDatabase(value);
                          tagInput.value = '';
                          const updatedTags = await window.flutter_inappwebview.callHandler('getFilteredTags', '', currentTagIds);
                          showSuggestions(updatedTags, '');
                          setTimeout(() => tagInput.focus(), 10);
                      };
          
                      suggestionsList.appendChild(addNew);
                  }
          
                  filteredTags.forEach(tag => {
                      const item = document.createElement('div');
                      item.textContent = tag.Name;
                      item.style.cssText = `
                          padding: 12px 16px;
                          cursor: pointer;
                          font-size: 14px;
                          color: \${isDark ? '#fff' : '#2c3e50'};
                          transition: background-color 0.2s ease;
                          white-space: nowrap;
                          user-select: none;
                          -webkit-user-select: none;
                      `;
                      
                      item.onmouseenter = () => item.style.backgroundColor = isDark ? '#4a4a4a' : 'rgba(52, 152, 219, 0.1)';
                      item.onmouseleave = () => item.style.backgroundColor = 'transparent';
                      
                      item.onmousedown = async (e) => {
                          e.preventDefault();
                          addTagToUI(tag);
                          tagInput.value = '';
                          const updatedTags = await window.flutter_inappwebview.callHandler('getFilteredTags', '', currentTagIds);
                          showSuggestions(updatedTags, '');
                          setTimeout(() => tagInput.focus(), 10);
                      };
                      
                      suggestionsList.appendChild(item);
                  });
          
                  suggestionsList.style.display = (suggestionsList.children.length > 0) ? 'block' : 'none';
                  updateSuggestionsPosition();
              };
          
              const updateSuggestionsPosition = () => {
                  if(suggestionsList.style.display === 'none') return;
                  
                  const rect = tagInput.getBoundingClientRect();
                  
                  // 🚀 CORRECTION: Positionnement strict sous l'input
                  suggestionsList.style.top = `\${rect.bottom + 5}px`;
                  suggestionsList.style.bottom = 'auto'; // Force la position sous l'élément
                  
                  suggestionsList.style.left = `\${rect.left}px`;
                  suggestionsList.style.width = `\${Math.max(250, tagInput.offsetWidth)}px`;
          
                  // Suppression de la logique de basculement au-dessus, comme demandé
              };
          
              // Événements Input Tags
              tagInput.addEventListener('input', async () => {
                  const value = tagInput.value.trim();
                  try {
                      const filteredTags = await window.flutter_inappwebview.callHandler('getFilteredTags', value, currentTagIds);
                      showSuggestions(filteredTags, value);
                  } catch (error) {
                      console.error('Erreur lors de la récupération des tags filtrés', error);
                  }
              });
          
              tagInput.addEventListener('focus', async () => {
                  const value = tagInput.value.trim();
                  try {
                      const filteredTags = await window.flutter_inappwebview.callHandler('getFilteredTags', value, currentTagIds);
                      showSuggestions(filteredTags, value);
                  } catch (error) {
                      console.error('Erreur lors de la récupération des tags filtrés', error);
                  }
                  // Scroll pour s'assurer que l'input tag est visible
                  if (dialogElement && contentContainer) {
                      const rect = tagInput.getBoundingClientRect();
                      // Défilement pour amener l'élément en vue (avec un petit décalage de 50px)
                      const targetScrollTop = contentContainer.scrollTop + (rect.top - contentContainer.getBoundingClientRect().top - 50);
                      contentContainer.scrollTop = targetScrollTop; 
                  }
              });
          
              tagInput.addEventListener('blur', () => {
                  setTimeout(() => { 
                      if (document.activeElement !== tagInput) {
                          suggestionsList.style.display = 'none'; 
                      }
                  }, 200);
              });
          
              tagInput.addEventListener('keypress', async (e) => {
                  if (e.key === 'Enter') {
                      e.preventDefault();
                      const value = tagInput.value.trim();
                      if (value !== '') {
                          try {
                              const filteredTags = await window.flutter_inappwebview.callHandler('getFilteredTags', value, currentTagIds);
                              const exactMatch = filteredTags.find(tag => tag.Name.toLowerCase() === value.toLowerCase());
                              if (exactMatch) {
                                  addTagToUI(exactMatch);
                              } else {
                                  await addTagToDatabase(value);
                              }
                              tagInput.value = '';
                              const updatedTags = await window.flutter_inappwebview.callHandler('getFilteredTags', '', currentTagIds);
                              showSuggestions(updatedTags, '');
                              setTimeout(() => tagInput.focus(), 10);
                          } catch (error) {
                              console.error("Erreur lors de l'ajout du tag", error);
                          }
                      }
                  }
              });
          
              // 🔨 ASSEMBLAGE FINAL
              if (isEditMode) {
                  tagInputWrapper.appendChild(tagInput);
                  tagsContainer.appendChild(tagInputWrapper);
              }
          
              noteContentWrapper.appendChild(titleElement);
              noteContentWrapper.appendChild(separator1);
              noteContentWrapper.appendChild(contentElement);
              noteContentWrapper.appendChild(separator2);
              noteContentWrapper.appendChild(tagsContainer);
              
              // Le contentContainer est le conteneur de défilement du dialogue
              contentContainer.appendChild(noteContentWrapper);
              document.body.appendChild(suggestionsList);
          
              // Sauvegarde
              const saveChanges = () => {
                  window.flutter_inappwebview.callHandler('updateNote', {
                      Guid: noteGuid,
                      Title: titleElement.value,
                      Content: contentElement.value
                  });
              };
          
              // Initialisation
              setTimeout(() => {
                  // L'utilisateur a demandé de ne PAS auto-réajuster le titre.
                  autoResizeTitle(); 
                  autoResizeContent();
              }, 0);
              
              contentContainer.addEventListener('scroll', updateSuggestionsPosition);
          
              window.addEventListener('resize', () => {
                  if (suggestionsList.style.display === 'block') {
                      updateSuggestionsPosition();
                  }
              });
          
              // Cleanup
              const cleanup = () => {
                  if (suggestionsList && suggestionsList.parentNode) {
                      suggestionsList.remove();
                  }
                  contentContainer.removeEventListener('scroll', updateSuggestionsPosition);
              };
          
              if (dialogElement) {
                  dialogElement.addEventListener('close', cleanup);
                  dialogElement.addEventListener('dialogClosed', cleanup);
              }
              
              return noteContentWrapper;
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
                      const note = pageCenter.querySelector(`[\${noteAttr}="\${noteGuid}"]`);
                      if (note) {
                          note.remove();
                      }
              
                      // Supprime côté Flutter
                      window.flutter_inappwebview.callHandler('removeNote', {
                          Guid: noteGuid
                      });
              
                      removeDialogByNoteGuid(noteGuid);
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
          
              colorsList.forEach((colorName, index) => {
                  if(index == 0) return;
                  const colorOption = document.createElement('div');
                  const colorIndex = index; // Les index de couleur commencent à 1
                  const colorClass = getNoteClass(colorIndex, false);
                  colorOption.className = `color-option \${colorClass}`;
                  colorOption.innerHTML = `<span style="background: var(--\${colorClass}); width: 16px; height: 16px; border-radius: 50%; border: 1px solid rgba(0,0,0,0.2);"></span>`;
                  colorOption.style.cssText = `
                      padding: 8px;
                      cursor: pointer;
                      display: flex;
                      justify-content: center;
                  `;
                  colorOption.onclick = () => {
                      changeNoteColor(noteGuid, colorIndex);
                                  
                      if (popup) {
                          removeNoteClasses(popup);
                          popup.classList.add(colorClass);
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
          function showVerseDialog(article, verses, href, replace) {
              showDialog({
                  title: verses.title,
                  type: 'verse',
                  article: article,
                  replace: replace,
                  href: href,
                  contentRenderer: (contentContainer) => {
                      verses.items.forEach((item, index) => {
                          const infoBar = document.createElement('div');
                          infoBar.style.cssText = `
                              display: flex;
                              align-items: center;
                              padding-inline: 8px;
                              padding-block: 3px;
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
                            position: relative;
                            padding-top: 10px;
                            padding-bottom: 16px;
                          `;
          
                          wrapWordsWithSpan(article, true);
                          
                          const paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article);
                          
                          item.highlights.forEach(h => {
                            if (h.Identifier >= item.firstVerseNumber && h.Identifier <= item.lastVerseNumber) {
                               addBlockRange(paragraphsDataDialog, h.BlockType, h.Identifier, h.StartToken, h.EndToken, h.UserMarkGuid, h.StyleIndex, h.ColorIndex);
                            }
                          });
                          
                          item.notes.forEach(note => {
                            if (note.BlockIdentifier >= item.firstVerseNumber && note.BlockIdentifier <= item.lastVerseNumber) {
                              const matchingHighlight = item.highlights.find(h => h.UserMarkGuid === note.UserMarkGuid);
                              const paragraphInfo = paragraphsDataDialog.get(note.BlockIdentifier)
                          
                              addNoteWithGuid(
                                article,
                                paragraphInfo.paragraphs[0],
                                matchingHighlight?.UserMarkGuid || null, // null si pas de highlight
                                note.Guid,
                                note.ColorIndex ?? 0,
                                true,
                                false
                              );
                            }
                          });
                          
                          contentContainer.appendChild(infoBar);
                          contentContainer.appendChild(article);
                      }); // Fin de forEach
                      
                      // CRÉATION DU BOUTON "PERSONNALISER"
                      const customizeButton = document.createElement('button');
                      customizeButton.textContent = 'Personnaliser';
                      
                      // Détermination des couleurs selon le thème
                      const bgColor = isDarkTheme() ? '#8e8e8e' : '#757575';
                      const textColor = isDarkTheme() ? 'black' : 'white';
                      
                      customizeButton.style.cssText = `
                          display: block;
                          padding: 8px 25px;
                          margin: 16px auto 20px; /* marge supérieure + inférieure */
                          border: none;
                          border-radius: 8px;
                          cursor: pointer;
                          font-size: 16px;
                          text-align: center;
                          background-color: \${bgColor};
                          color: \${textColor};
                          transition: background-color 0.2s ease;
                          box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
                      `;
                      
                      // Ajouter le listener quand on clique sur le bouton
                      customizeButton.addEventListener('click', async () => { 
                        const hasChanges = await window.flutter_inappwebview.callHandler('openCustomizeVersesDialog');
                        
                        // 2. Vérification si des changements ont eu lieu AVANT de recharger les versets
                        if (hasChanges === true) {
                          const verses = await window.flutter_inappwebview.callHandler('fetchVerses', href);
                          showVerseDialog(article, verses, href, true);
                        } else {
                          console.log("Aucun changement de version, les versets ne sont pas rechargés.");
                        }
                      });
                      
                      // Ajout du bouton au bas du contentContainer
                      contentContainer.appendChild(customizeButton);
                      
                      contentContainer.addEventListener('click', async (event) => {
                        onClickOnPage(contentContainer, event.target);
                      });
                          
                      repositionAllNotes(contentContainer);
                  }
              });
          }
          
          function showVerseReferencesDialog(article, verseReferences, href) {
            showDialog({
                title: verseReferences.title || 'Références bibliques',
                type: 'verse-references',
                article: article,
                href: href,
                contentRenderer: (contentContainer) => {
                    verseReferences.items.forEach((item, index) => {
                        const infoBar = document.createElement('div');
                        // CORRECTION : Utilisation des backticks (`) pour le template literal
                        // afin d'interpoler \${isDarkTheme() ? '...' : '...'}
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
                        // CORRECTION : Utilisation des backticks (`) pour le template literal
                        // afin d'interpoler \${item.className} et \${item.content}
                        article.innerHTML = `<article id="verse-dialog" class="\${item.className}">\${item.content}</article>`;
                        article.style.cssText = `
                          position: relative;
                          padding-top: 10px;
                          padding-bottom: 16px;
                        `;
        
                        wrapWordsWithSpan(article, true);
                        
                        const paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article);
                        
                        article.addEventListener('click', async (event) => {
                            onClickOnPage(article, event.target);
                        });
                        
                        contentContainer.appendChild(infoBar);
                        contentContainer.appendChild(article);
                        
                        repositionAllNotes(article);
                    });
                }
            });
        }
          
        /**
 * Compteur global pour assurer l'unicité des ID à travers les multiples
 * ouvertures de dialogue.
 */
let globalIdCounter = 0;

function showVerseInfoDialog(article, verseInfo, href) {
  showDialog({
      title: verseInfo.title,
      type: 'verse-info',
      article: article,
      href: href,
      contentRenderer: (contentContainer) => {

          // Définir les onglets et leurs icônes.
          // On ajoute une propriété 'label' pour les messages d'erreur.
          const tabsDefinition = [
              { key: 'commentary', iconClass: 'jwi-bible-speech-balloon', label: "commentaire" },
              { key: 'medias', iconClass: 'jwi-image-stack', label: "medias" },
              { key: 'guide', iconClass: 'jwi-publications-pile', label: "guide" },
              { key: 'footnotes', iconClass: 'jwi-bible-quote', label: "notes de bas de page" },
              { key: 'notes', iconClass: 'jwi-text-pencil', label: "notes personnelles" },
              { key: 'versions', iconClass: 'jwi-bible-comparison', label: "versions" },
          ];

          // 1. Filtrer les onglets pour n'afficher que ceux qui ont du contenu.
          const filteredTabs = tabsDefinition.filter(tab => {
              const items = verseInfo[tab.key] || [];
              return items.length > 0;
          });
          
          // Si le dialogue ne contient qu'un seul onglet (ou aucun),
          // on ne crée pas la barre d'onglets.
          const hasTabBar = filteredTabs.length > 1;
          let currentTab = filteredTabs.length > 0 ? filteredTabs[0].key : null;

          // Si une barre d'onglets est nécessaire, on la crée.
          if (hasTabBar) {
              // Crée l'en-tête d'onglets
              const tabBar = document.createElement('div');
              tabBar.style.cssText = `
                  display: flex;
                  border-bottom: 1px solid \${isDarkTheme() ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)'};
                  background-color: \${isDarkTheme() ? '#111' : '#f9f9f9'};
              `;

              // Crée les boutons d'onglets basés sur le tableau filtré.
              const tabButtons = filteredTabs.map(({ key, iconClass }) => {
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
                      // Met à jour le style de tous les boutons pour marquer l'onglet actif.
                      tabButtons.forEach(b => {
                          b.style.borderBottom = '2px solid transparent';
                      });
                      btn.style.borderBottom = `2px solid \${isDarkTheme() ? '#fff' : '#000'}`;
                  });

                  tabBar.appendChild(btn);
                  return btn;
              });
              contentContainer.appendChild(tabBar);
          }

          // Conteneur pour le contenu dynamique
          const dynamicContent = document.createElement('div');
          dynamicContent.style.padding = '10px';
          contentContainer.appendChild(dynamicContent);

          /**
           * Met à jour le contenu affiché en fonction de l'onglet actif.
           */
          function updateTabContent() {
              dynamicContent.innerHTML = ''; // Réinitialise le conteneur

              if (!currentTab) {
                  // Gère le cas où aucun onglet n'est disponible (verseInfo vide).
                  const emptyDiv = document.createElement('div');
                  emptyDiv.textContent = "Aucun contenu disponible.";
                  emptyDiv.style.cssText = `
                      padding: 15px;
                      font-style: italic;
                      opacity: 0.7;
                  `;
                  dynamicContent.appendChild(emptyDiv);
                  return;
              }

              const key = currentTab;
              const items = verseInfo[key] || [];

              // Si le contenu est un tableau non vide, on l'affiche.
              if (Array.isArray(items) && items.length > 0) {
                  items.forEach((item) => {
                      const articleDiv = document.createElement('div');
                      articleDiv.id = 'verse-info-dialog-id';
                      let contentHtml = '';

                      if (key === 'medias') {
                        contentHtml = `
                          <div id="verse-info-dialog" class="mediaItem \${item.isVideo ? 'hasVideo' : ''}">
                            <div class="mediaImgWrapper">
                              <img class="\${item.isVideo ? 'video' : 'image'}" src="\${item.imagePath}">
                            </div>
                            <div class="mediaBody">
                              <a class="mediaTitle">
                                \${item.label}    
                              </a>
                            </div>
                          </div>
                        `;
                        
                        articleDiv.addEventListener("click", event => {
                            event.preventDefault();
                            if(item.isVideo) {
                              window.flutter_inappwebview.callHandler('onVideoClick', item.href);
                            }
                            else {
                            }
                          });
                      } 
                      else if (key === 'notes') {
                          const noteData = {
                              noteGuid: item.Guid,
                              title: item.Title,
                              content: item.Content,
                              tagsId: item.TagsId,
                              colorIndex: item.ColorIndex,
                          };
                          
                          const newNote = { 'noteData': noteData };
                          
                          const noteElement = createNoteContent(articleDiv, newNote);
                          
                          if (noteElement) {
                              noteElement.style.marginBottom = '16px'; 
                              
                              if (items.indexOf(item) === items.length - 1) {
                                  noteElement.style.marginBottom = '0';
                              }
                              
                              articleDiv.appendChild(noteElement);
                          }
                      } 
                      else if (key === 'guide') {    
                        
                        articleDiv.id = 'verse-info-dialog-guide-id';
                        contentHtml = `<article id="verse-info-dialog" style="display: flex; flex-direction: column; gap: 8px;">`;

                        const backgroundColor = isDarkTheme() ? '#000000' : '#f1f1f1';
                        const color = isDarkTheme() ? '#000000' : '#f1f1f1';
                         
                        // Écris Tous les articles de guide avec une balise a
                        item.items.forEach((guideItem) => {
                          
                          // *** Utilisation du compteur global pour l'ID ***
                          const itemId = `guide-item-\${globalIdCounter++}`; 
                          
                          const color = guideItem.color || '#1e855c';
                          
                          // Style pour le carré ou l'icône
                          const iconStyle = `
                            width: 40px; 
                            height: 40px; 
                            margin-right: 12px; 
                            flex-shrink: 0; 
                            display: flex; 
                            justify-content: center; 
                            align-items: center; 
                            overflow: hidden;
                            background-color: \${guideItem.imageUrl ? 'transparent' : color};
                            border-radius: 2px;
                          `;
                        
                          // Générer l'icône/le carré
                          const iconHtml = guideItem.imageUrl ? `<img src="\${guideItem.imageUrl}" style="max-width: 100%; max-height: 100%; object-fit: cover;">` : '';
                        
                          // Échapper le contenu avant de le stocker dans data-content-html
                          const contentToStore = `<article id='extract-content' class='\${guideItem.className || ''}'>\${guideItem.content || ''}</article>`;
                          const encodedContent = contentToStore
                              .replace(/"/g, '&quot;')
                              .replace(/</g, '&lt;')
                              .replace(/>/g, '&gt;')
                              .replace(/'/g, '&#39;');

                          // Style du bouton d'expansion (logo)
                          const expandButtonStyle = `
                            font-family: jw-icons-external; 
                            color: #999999; 
                            font-size: 1.1em; 
                            cursor: pointer; 
                            margin-left: 10px; 
                            flex-shrink: 0;
                          `;
                          
                          // LOGIQUE DE CLIC FLUTTER/MEPS : 
                          const flutterCall = `
                            window.flutter_inappwebview.callHandler('openMepsDocument', {
                              mepsDocumentId: '\${guideItem.mepsDocumentId}',
                              mepsLanguageId: '\${guideItem.mepsLanguageId}',
                              startParagraphId: '\${guideItem.startParagraphId}',
                              endParagraphId: '\${guideItem.endParagraphId}'
                            });
                            return false; // Empêche le comportement de lien par défaut
                          `;
                          
                          const mainLinkOnClick = guideItem.mepsDocumentId ? `onclick="\${flutterCall}"` : '';
                            
                        
                          // Générer le HTML (SANS ONCLICK sur le bouton d'expansion)
                          contentHtml += `
                            <div id="\${itemId}" \${mainLinkOnClick} data-content-html="\${encodedContent}"
                               style="text-decoration: none; color: inherit; display: block; background-color: \${backgroundColor}; border-radius: 4px;">
                              
                              <div style="display: flex; align-items: center; padding: 8px 12px;">
                                
                                <div style="\${iconStyle}">
                                  \${iconHtml}
                                </div>
                                
                                <div style="flex-grow: 1; display: flex; flex-direction: column; justify-content: center;">
                                  <div style="font-weight: bold; font-size: 0.8em; line-height: 1.3;">
                                    \${guideItem.publicationTitle || ''}
                                  </div>
                                  <div style="font-size: 0.65em; line-height: 1.4; opacity: 0.8;">
                                    \${guideItem.subtitle || ''}
                                  </div>
                                </div>
                                
                                <div style="\${expandButtonStyle}" 
                                     data-expansion-button="true" 
                                     data-state="closed"
                                     data-item-id="\${itemId}"> 
                                  &#xE639;
                                </div>
                              </div>
                            </div>
                            
                            <div id="content-expand-\${itemId}" style="display: none; padding: 0; margin: 0; color: #ffffff;"></div>
                          `;
                        });
                        
                        contentHtml += `</article>`;
                      }
                      else if (key === 'versions') {
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
                            font-size: 15px;
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
                          position: relative;
                          padding-top: 10px;
                          padding-bottom: 16px;
                        `;
                        
                        dynamicContent.appendChild(infoBar);
                        dynamicContent.appendChild(article);
                      }
                      else if (key === 'footnotes') {
                          if(item.type === 'footnote') {
                            const letter = getFootnoteLetter(items.indexOf(item)+1);
                            contentHtml = `
                                <div id="footnote\${item.footnoteIndex}" data-fnid="\${item.footnoteIndex}" class="fcc fn-ref \${item.className}">
                                    <p>
                                    <a href="#footnotesource\${item.footnoteIndex}" class="fn-symbol">\${letter}</a>
                                    \${item.content}
                                    </p>
                                </div>
                            `;
                          }
                          else if(item.type === 'versesReference') {
                              
                            // *** Utilisation du compteur global pour l'ID ***
                            const itemId = `xref-item-\${globalIdCounter++}`; 
                            
                            // 1. Concaténation des références de versets pour l'affichage initial
                              const combinedVerse = item.verses
                                  .map(verse => verse.bookDisplay)
                                  .join('; ');
                              
                              const combinedVersesDisplay = `<span class="xRefCitation">\${combinedVerse}</span>`;
                              
                              // 2. Construction du contenu riche pour l'expansion (Rich Content)
                              const verseContentHtml = item.verses.map(verse => {
                                  return `
                                      <div style="
                                          display: flex; 
                                          align-items: center; 
                                          padding-inline: 10px; 
                                          padding-block: 6px; 
                                          background: \${isDarkTheme() ? '#000000' : '#f1f1f1'};
                                          border-bottom: 1px solid \${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)'};
                                      ">
                                          <img src="file://\${item.imageUrl}" style="
                                              height: 50px;
                                              width: 50px;
                                              border-radius: 8px;
                                              object-fit: cover;
                                              margin-right: 8px;
                                              box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                                          ">
                                          
                                          <div style="flex-grow: 1; margin-left: 8px; padding: 8px 0;">
                                              <div style="
                                                  font-size: 15px;
                                                  font-weight: 700;
                                                  margin-bottom: 4px;
                                                  line-height: 1.3;
                                                  white-space: nowrap;
                                                  overflow: hidden;
                                                  text-overflow: ellipsis;
                                              ">
                                                  \${verse.bibleVerseDisplay || 'Référence non disponible'}
                                              </div>
                                              
                                              <div style="
                                                  font-size: 12px;
                                                  opacity: 0.8;
                                                  line-height: 1.4;
                                                  white-space: nowrap;
                                                  overflow: hidden;
                                                  text-overflow: ellipsis;
                                              ">
                                                  \${item.subtitle}
                                              </div>
                                          </div>
                                      </div>
                              
                                      <div style="
                                        position: relative;
                                        padding: 10px 10px 16px 10px;
                                      ">
                                          <article class="\${item.className || ''}">
                                              \${verse.content || 'Contenu non disponible'}
                                          </article>
                                      </div>
                                      <hr style="border: none; border-top: 1px solid rgba(0,0,0,0.1); margin: 0;">
                                  `;
                              }).join('');
                              
                              // 3. Encapsulation et Encoded Combined Verse
                              const contentToStore = `<div style="padding: 0;">` + verseContentHtml + `</div>`;
                              
                              const encodedCombinedVerse = contentToStore
                                  .replace(/"/g, '&quot;')
                                  .replace(/</g, '&lt;')
                                  .replace(/>/g, '&gt;')
                                  .replace(/'/g, '&#39;');
                              
                              
                              // --- Définition des Styles ---
                              const expandButtonStyle = `
                                  font-family: jw-icons-external; 
                                  color: #999999; 
                                  font-size: 1.1em; 
                                  cursor: pointer; 
                                  margin-left: 10px; 
                                  flex-shrink: 0;
                              `;
                              
                              const xRefContainerStyle = `
                                  display: flex;
                                  align-items: center;
                                  justify-content: space-between;
                                  width: 100%;
                                  padding: 10px 10px 10px 0;
                              `;
                              
                              
                              // --- Construction du HTML final (SANS ONCLICK sur le bouton d'expansion) ---
                              contentHtml = `
                                  <div id="\${itemId}" 
                                       class="jwac xRef"
                                       data-content-html="\${encodedCombinedVerse}"
                                       style="\${xRefContainerStyle}">
                                      
                                      <div style="display: flex; align-items: center; flex-grow: 1;">
                                          <a class="xRefID expanderText">\${item.marginalSymbol}</a>
                                          \${combinedVersesDisplay}
                                      </div>
                                      
                                      <div style="\${expandButtonStyle}"
                                           data-expansion-button="true" 
                                           data-state="closed"
                                           data-item-id="\${itemId}">
                                           
                                           &#xE639;
                                      </div>
                                      
                                  </div>
                                  
                                  <div id="content-expand-\${itemId}" 
                                       style="display: none; padding: 0; margin: 0; color: inherit;">
                                       </div>
                              `;
                          }    
                             
                      }
                      else {
                          contentHtml = `
                              <article id="verse-info-dialog" class="\${item.className || ''}">
                                  \${item.content}
                              </article>
                          `;
                      }
                      
                      
                      if(key === 'notes') {
                        dynamicContent.appendChild(articleDiv);
                      }
                      else if(key !== 'versions') {
                        articleDiv.innerHTML = contentHtml;
                        articleDiv.addEventListener('click', async (event) => {
                            onClickOnPage(articleDiv, event.target);
                        });
                        dynamicContent.appendChild(articleDiv);
                        
                        // LIAISON DES ÉVÉNEMENTS D'EXPANSION DYNAMIQUEMENT APRÈS L'INSERTION
                        if (key === 'guide' || (key === 'footnotes' && item.type === 'versesReference')) {
                            const expandButtons = articleDiv.querySelectorAll('[data-expansion-button]');
                            expandButtons.forEach(button => {
                                button.addEventListener('click', event => {
                                    event.preventDefault(); 
                                    event.stopPropagation();
                                    // Utiliser l'ID stocké dans l'attribut data-item-id
                                    const targetId = button.getAttribute('data-item-id'); 
                                    handleExpand(targetId);
                                });
                            });
                        }
                      }
                  });
              } 
              else {
                  // Cas où l'onglet est vide 
                  const emptyMessage = tabsDefinition.find(t => t.key === key)?.label || "Contenu";
                  const emptyDiv = document.createElement('div');
                  emptyDiv.textContent = `Il n'y a pas de \${emptyMessage} pour ce verset.`;
                  emptyDiv.style.cssText = `
                      padding: 15px;
                      font-style: italic;
                      opacity: 0.7;
                  `;
                  dynamicContent.appendChild(emptyDiv);
              }
          }

          // Affiche le premier onglet disponible lors de l'ouverture du dialogue.
          updateTabContent();
      }
  });
}

// Pas de changement dans handleExpand, elle est générique et globale.
function handleExpand(itemId) {
    const itemElement = document.getElementById(itemId);
    const contentContainer = document.getElementById(`content-expand-\${itemId}`); 
    
    // Cibler le bouton d'expansion dans le conteneur principal
    const expandButton = itemElement.querySelector('[data-expansion-button]');
    
    if (itemElement && contentContainer && expandButton) {
        
        const isVisible = contentContainer.style.display !== 'none';
        
        if (!isVisible) {
            // Ouvrir
            const encodedContent = itemElement.getAttribute('data-content-html'); 
            // La fonction de décodage doit gérer tous les échappements effectués
            const decodedContent = encodedContent.replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#39;/g, "'");

            contentContainer.innerHTML = decodedContent;
            contentContainer.style.display = 'block';
            
            // Basculer l'icône sur OUVERT (E638)
            expandButton.innerHTML = '&#xE638;'; 
            expandButton.setAttribute('data-state', 'open');

        } else {
            // Fermer
            contentContainer.style.display = 'none';
            contentContainer.innerHTML = '';
            
            // Basculer l'icône sur FERMÉ (E639)
            expandButton.innerHTML = '&#xE639;'; 
            expandButton.setAttribute('data-state', 'closed');
        }
    }
}
                                               
          function showExtractPublicationDialog(article, extractData, href) {
              showDialog({
                  title: extractData.title || 'Extrait de publication',
                  type: 'publication',
                  article: article,
                  href: href,
                  contentRenderer: (contentContainer) => {
                      extractData.items.forEach((item, index) => {
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
                            position: relative;
                            padding-block: 16px;
                            line-height: 1.7;
                            font-size: inherit;
                          `;
                       
                          wrapWordsWithSpan(article, false);
                          
                          const paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article);
                          
                          item.highlights.forEach(h => {
                            if ((item.startParagraphId == null || h.Identifier >= item.startParagraphId) && (item.endParagraphId == null || h.Identifier <= item.endParagraphId)) {
                              addBlockRange(
                                paragraphsDataDialog,
                                h.BlockType,
                                h.Identifier,
                                h.StartToken,
                                h.EndToken,
                                h.UserMarkGuid,
                                h.StyleIndex,
                                h.ColorIndex
                              );
                            }
                          });
                          
                          item.notes.forEach(note => {
                            const matchingHighlight = item.highlights.find(h => h.UserMarkGuid === note.UserMarkGuid);                 
                            const paragraphInfo = paragraphsDataDialog.get(note.BlockIdentifier)
                          
                            addNoteWithGuid(
                              article,
                              paragraphInfo.paragraphs[0],
                              matchingHighlight?.UserMarkGuid || null,
                              note.Guid,
                              note.ColorIndex ?? 0,
                              false,
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
                          contentContainer.appendChild(headerBar);
                          contentContainer.appendChild(article);
                          
                          repositionAllNotes(article);
                          
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
          
          function showVerseCommentaryDialog(article, commentaries, href) {
              showDialog({
                  title: commentaries.title,
                  type: 'commentary',
                  article: article,
                  href: href,
                  contentRenderer: (contentContainer) => {
                      commentaries.items.forEach((item, index) => {
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
                          article.innerHTML = `<article id="commentary-dialog" class="\${item.className}">\${item.content}</article>`;
                          article.style.cssText = `
                            padding-top: 10px;
                            padding-bottom: 16px;
                          `;
                      
                          contentContainer.appendChild(infoBar);
                          contentContainer.appendChild(article);
                      });
                  }
              });
          }
          
          function showFootNoteDialog(article, footnote, href) {
              showDialog({
                  title: footnote.title,
                  type: 'footnote',
                  article: article,
                  href: href,
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
         
          function getAllBlockRanges(guid) {
            return pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${guid}"]`);
          }
          
          function removeBlockRange(guid) {
            removeBlockRangeByGuid(guid);
            closeToolbar();
          }
          
          function getAllSelectedTargets(allowedSelector = null) {
            const selection = window.getSelection();
            if (!selection.rangeCount || selection.isCollapsed) return [];
          
            const range = selection.getRangeAt(0);
            const selectedElements = [];
          
            let ancestorContainer = range.commonAncestorContainer;
            if (ancestorContainer.nodeType === Node.TEXT_NODE) {
              ancestorContainer = ancestorContainer.parentElement;
            }
          
            // Si l'ancestor lui-même correspond au sélecteur
            if (allowedSelector && ancestorContainer.matches?.(allowedSelector)) {
              console.log('length', 1);
              return [ancestorContainer];
            }
          
            if (!allowedSelector) {
              console.log('length', 1);
              return [ancestorContainer];
            }
          
            // Récupérer tous les éléments correspondants dans l'ancestor
            const candidates = ancestorContainer.querySelectorAll(allowedSelector);
            
            // Filtrer ceux qui intersectent avec la sélection
            for (const node of candidates) {
              // Vérifier si le range intersecte le node
              if (range.intersectsNode(node)) {
                selectedElements.push(node);
              }
            }
            
            console.log('length', selectedElements.length);
            return selectedElements;
          }
          
          async function addNote(paragraph, id, isBible, title) {
              const noteGuid = await window.flutter_inappwebview.callHandler('addNote', {
                  Title: title,
                  BlockType: (id != null) ? (isBible ? 2 : 1) : 1,
                  BlockIdentifier: id,
                  UserMarkGuid: null,
                  ColorIndex: 0
              });
              
              addNoteWithGuid(pageCenter, paragraph, null, noteGuid.uuid, 0, isBible, true);
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
          
            const note = pageCenter.querySelector(`[\${noteAttr}="\${noteGuid}"]`);
            if (note) {
              note.remove();
            }
          
            await window.flutter_inappwebview.callHandler('removeNote', {
              Guid: noteGuid
            });
            
            removeDialogByNoteGuid(noteGuid);
          }
          
          async function addNoteWithBlockRange(title, blockRangeTarget, userMarkGuid) {
            // Détermination de l'index de couleur actif
              const { 
                  styleIndex: targetStyleIndex, 
                  colorIndex: targetColorIndex 
              } = getActiveStyleAndColorIndex(blockRangeTarget, currentStyleIndex, getColorIndex);
            
            // Utilisation de la config STYLE au lieu d’un tableau en dur
            const cfg = getStyleConfig(targetStyleIndex);
            
            const paragraphInfo = getTheFirstTargetParagraph(blockRangeTarget);
            const id = paragraphInfo.id;
            const paragraphs = paragraphInfo.paragraphs;
            const isVerse = paragraphInfo.isVerse;
                      
            // Trouver l’index de la couleur appliquée en cherchant dans cfg.classes
            let colorIndex = cfg.classes.findIndex(cls => blockRangeTarget.classList.contains(cls));
          
            const noteGuid = await window.flutter_inappwebview.callHandler('addNote', {
              Title: title,
              BlockType: isVerse ? 2 : 1,
              BlockIdentifier: id,
              UserMarkGuid: userMarkGuid,
              ColorIndex: colorIndex
            });
            
            addNoteWithGuid(
              pageCenter,
              paragraphs[0],
              userMarkGuid,
              noteGuid.uuid,
              colorIndex,
              isVerse,
              true
            );
          
            closeToolbar();
          }
          
          function repositionNote(noteGuid) {
            if (!noteGuid) return; // Sécurité
          
            const note = pageCenter.querySelector(`[\${noteAttr}="\${noteGuid}"]`);
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
          
            const matchedElement = target.closest(`[\${idAttr}]`);
            
            if (!matchedElement) {
              closeToolbar();
              return;
            }
          
            if (classFilter === 'paragraph') {
              const pid = matchedElement.getAttribute(idAttr);
              
              if (!pid) {
                closeToolbar();
                return;
              }
          
              // Convertir pid en nombre pour correspondre à la clé dans paragraphsData
              const pidNumber = parseInt(pid, 10);
              
              // Récupérer les données du paragraphe depuis paragraphsData
              const paragraphData = paragraphsData.get(pidNumber);
              
              if (!paragraphData) {
                closeToolbar();
                return;
              }
          
              // Optimisation avec optional chaining et court-circuit
              const hasAudio = cachedPages[currentIndex]?.audiosMarkers?.some(m => 
                String(m.mepsParagraphId) === pid
              ) ?? false;
              
              showToolbar(paragraphData.paragraphs, pidNumber, selector, hasAudio, classFilter);
            }
            else {
              // Traitement des versets
              let vid = matchedElement.getAttribute(idAttr);
            
              if (!vid) {
                closeToolbar();
                return;
              }
            
              // Extraire le numéro de verset (3ème partie) de vid
              // vid format: v1-3-5-1 -> on veut récupérer "5"
              const vidParts = vid.split('-');
              const verseNumber = parseInt(vidParts[2], 10); // Convertir en nombre
              
              // Récupérer les données du verset depuis paragraphsData
              const verseData = paragraphsData.get(verseNumber);
              
              if (!verseData) {
                closeToolbar();
                return;
              }
          
              // Utiliser le numéro de verset pour la vérification audio
              const hasAudio = cachedPages[currentIndex]?.audiosMarkers?.some(m => 
                String(m.verseNumber) === String(verseNumber)
              ) ?? false;
          
              showToolbar(verseData.paragraphs, verseNumber, selector, hasAudio, classFilter);
            }
          }
    
          async function loadUserdata() {
            const userdata = await window.flutter_inappwebview.callHandler('getUserdata');
           
            const blockTypeInt = isBible() ? 2 : 1; // 2 pour Verset, 1 pour Paragraphe (basé sur le code Flutter supposé)
          
            blockRanges = userdata.blockRanges;
            notes = userdata.notes;
            tags = userdata.tags;
            inputFields = userdata.inputFields;
            bookmarks = userdata.bookmarks;
          
            // Pré-indexation des données pour un accès plus rapide
            const blockRangeMap = new Map();
            const notesMap = new Map();
            const bookmarksMap = new Map();
          
            // Indexation des surlignages (BlockRanges)
            blockRanges.forEach(h => {
              // La clé utilise le format string "BlockType-Identifier" (ex: "2-15" ou "1-12")
              const key = `\${h.BlockType}-\${h.Identifier}`;
              if (!blockRangeMap.has(key)) blockRangeMap.set(key, []);
              blockRangeMap.get(key).push(h);
            });
          
            // Indexation des notes - CLÉ MODIFIÉE POUR UTILISER DES ENTIERS
            notes.forEach(n => {
              // Le BlockIdentifier est désormais un nombre (int)
              const key = n.BlockIdentifier; 
              if (!notesMap.has(key)) notesMap.set(key, []);
              notesMap.get(key).push(n);
            });
          
            // Indexation des signets (Bookmarks)
            bookmarks.forEach(b => {
              // La clé utilise le format string "BlockType-Identifier"
              const key = `\${b.BlockType}-\${b.BlockIdentifier}`;
              bookmarksMap.set(key, b);
            });
          
            const processedNoteGuids = new Set(); // Pour éviter les doublons
            
            // -----------------------------------------------------------------
            // Remplacement de l'itération DOM par l'itération sur paragraphsData
            // -----------------------------------------------------------------
            
            // Itérer sur paragraphsData (Map<int ID, { paragraphs: HTMLElement[], id: int, isVerse: boolean, ... }>)
            paragraphsData.forEach((paragraphInfo, numericId) => {
              
              // 1. Récupération des données du paragraphe
              const { paragraphs, isVerse } = paragraphInfo;
              
              const blockIdentifier = numericId; 
              // blockType sera 2 pour 'v' (verset) ou 1 pour 'p' (paragraphe)
              const blockType = isVerse ? 2 : 1; 
          
              // Clé utilisée pour les Maps indexées par chaîne (BlockType-Identifier)
              const idKey = `\${blockType}-\${blockIdentifier}`; 
              
              // 2. Gérer les signets (Bookmarks)
              const bookmark = bookmarksMap.get(idKey);
              if (bookmark) {
                addBookmark(pageCenter, paragraphInfo, bookmark.BlockType, bookmark.BlockIdentifier, bookmark.Slot);
              }
          
              // 3. Gérer les surlignages (Highlights/BlockRanges)
              const matchingHighlights = blockRangeMap.get(idKey) || [];
              matchingHighlights.forEach(h => {
                addBlockRange(paragraphsData, h.BlockType, h.Identifier, h.StartToken, h.EndToken, h.UserMarkGuid, h.StyleIndex, h.ColorIndex);
              });
          
              // 4. Gérer les notes (Notes)
              // notesMap est indexée par l'ID numérique (blockIdentifier)
              const matchingNotes = notesMap.get(blockIdentifier) || []; 
              matchingNotes.forEach(note => {
                if (processedNoteGuids.has(note.Guid)) return;
          
                const matchingHighlight = matchingHighlights.find(h => h.UserMarkGuid === note.UserMarkGuid);
          
                addNoteWithGuid(
                  pageCenter,
                  paragraphInfo.paragraphs[0],
                  matchingHighlight?.UserMarkGuid || null,
                  note.Guid,
                  note.ColorIndex ?? 0,
                  isBible(),
                  false
                );
          
                processedNoteGuids.add(note.Guid);
              });      
            });  
          
            // -----------------------------------------------------------------
            // Traitement des champs input/textarea (inchangé)
            // -----------------------------------------------------------------
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
                
                repositionAllNotes(pageCenter);
                repositionAllBookmarks(pageCenter);
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
          
          function addBookmark(article, paragraphInfo, blockType, blockIdentifier, slot) {
            if(!article) {
              article = pageCenter;
            }
            if (!paragraphInfo) {
              paragraphInfo = paragraphsData.get(blockIdentifier);
              if (!paragraphInfo) return; 
            }
          
            const imgSrc = bookmarkAssets[slot];
            const p = paragraphInfo.paragraphs[0];
            if (imgSrc && p) {
              requestAnimationFrame(() => {
                const bookmark = document.createElement('img');
                bookmark.setAttribute('bookmark-id', blockIdentifier);
                bookmark.setAttribute('slot', slot);
                bookmark.src = imgSrc;
                bookmark.classList.add('bookmark-icon');
          
                getBookmarkPosition(pageCenter, p, bookmark);
                pageCenter.appendChild(bookmark);
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
          
          function addBlockRange(paragraphsDataMap, blockType, blockIdentifier, startToken, endToken, guid, styleIndex, colorIndex) {
            const paragraphInfo = paragraphsDataMap.get(blockIdentifier);
            
            if (!paragraphInfo) return; 

            // Extraire les tableaux de tokens de l'objet de données complet
            const allTokens = paragraphInfo.allTokens;
            const wordAndPunctTokens = paragraphInfo.wordAndPunctTokens;
            const indexInAll = paragraphInfo.indexInAll; // Utilisez la map d'indexation
          
            // Déterminer la classe CSS
            const styleClass = getStyleClass(styleIndex, colorIndex);
          
            // Prendre les bons tokens par tranche (word/punct seulement)
            // endToken est l'index exclusif ou inclusif ? On suppose inclusif (+1)
            const selectedTokens = wordAndPunctTokens.slice(startToken, endToken + 1);
          
            selectedTokens.forEach((element, index) => { // ⚠️ CORRECTION : 'element' est le token DOM
              element.classList.add(styleClass);
              element.setAttribute(blockRangeAttr, guid);
          
              // ⚠️ CORRECTION : Utiliser indexInAll Map pour trouver l'index
              const tokenIndexInAll = indexInAll.get(element);
              
              // Le jeton suivant dans la liste ALLTOKENS
              const next = allTokens[tokenIndexInAll + 1];
          
              // Inclure le jeton d'échappement juste après, s'il existe et si ce n'est pas le DERNIER token sélectionné
              if (
                next && 
                next.classList.contains("escape") && 
                index !== selectedTokens.length - 1 // Pas le dernier jeton de la plage sélectionnée
              ) {
                next.classList.add(styleClass);
                next.setAttribute(blockRangeAttr, guid);
              }
            });
          }
          
          // Les variables globales (noteAttr, blockRangeAttr, isBible, colorsList, etc.) sont présumées définies ailleurs.
          function getNotePosition(article, element, noteIndicator) {
              if(!element.classList.contains('word') && !element.classList.contains('punctuation')) {
                element = element.querySelector('.word, .punctuation');
              }
              
              // Chercher un élément word/punctuation si nécessaire
               if (!element.classList.contains('word') && !element.classList.contains('punctuation')) {
                   const found = element.querySelector('.word, .punctuation');
                   if (found) element = found;
               }
           
               if (!element) return;
           
               // Coordonnées relatives à l'article
               const targetRect = element.getBoundingClientRect();
               const articleRect = article.getBoundingClientRect();
           
               // Note: J'ai conservé le style d'échappement des template literals pour correspondre à votre code original.
               const topOffset = targetRect.top - articleRect.top + article.scrollTop + (targetRect.height - 15) / 2; // 15 = noteHeight
           
               noteIndicator.style.top = `\${topOffset}px`;
           }
           
           function repositionAllNotes(article) {
             const notes = document.querySelectorAll(`[\${noteAttr}]`);
             notes.forEach(note => {
               let target = null;
               if(note.hasAttribute(noteBlockRangeAttr)) {
                  const userMarkGuid = note.getAttribute(noteBlockRangeAttr);
                  target = article.querySelector(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
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
           
           function addNoteWithGuid(article, target, userMarkGuid, noteGuid, colorIndex, isBible, open) {
             if (!target) {
               const highlightTarget = article.querySelector(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
               if (highlightTarget) {
                 target = isBible ? highlightTarget.closest('.v') : highlightTarget.closest('p');
               }
             }
             
             if (!target) {
               return;
             }
             
             const idAttr = isBible ? 'id' : 'data-pid';
           
             // Chercher le premier élément surligné si userMarkGuid est donné
             let firstBlockRangeElement = null;
             if (userMarkGuid) {
                 firstBlockRangeElement = target.querySelector(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
             }
             
             // Créer le carré de note
             const noteIndicator = document.createElement('div');
             noteIndicator.className = 'note-indicator';
             noteIndicator.setAttribute(noteAttr, noteGuid);
             if(userMarkGuid) {
               noteIndicator.setAttribute(noteBlockRangeAttr, userMarkGuid);
             }
             noteIndicator.setAttribute('data-note-block-id', target.getAttribute(idAttr));
           
             // Couleurs
             const colorName = colorsList[colorIndex] || "gray";
             noteIndicator.classList.add(`note-indicator-\${colorName}`);
           
             // Détecter si le target (paragraphe) est dans une liste ul/ol
             const targetUl = target.closest('ul');
             const isInList = target.tagName === 'P' && target.hasAttribute(idAttr) && targetUl && targetUl.classList.contains('source');
           
             // Clic pour afficher la note
             noteIndicator.addEventListener('click', (e) => {
                 e.stopPropagation();
                 openNoteDialog(noteGuid, userMarkGuid);
             });
             
             // Clic pour supprimer la note
             noteIndicator.addEventListener('contextmenu', (e) => {
                 e.preventDefault();
                 removeNote(noteGuid, true);
             });
           
             article.appendChild(noteIndicator);
           
             setTimeout(() => {
               // Calcul de position différent si pas de firstBlockRangeElement
               if (firstBlockRangeElement) {
                   getNotePosition(article, firstBlockRangeElement, noteIndicator);
           
                   // Positionner à droite si élément est à droite
                   const elementRect = firstBlockRangeElement.getBoundingClientRect();
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
             }, 0);
             // ----------------------------------------------------------------------
           
             if(open) {
               openNoteDialog(noteGuid, userMarkGuid);
             }
           }

          // Fonction utilitaire pour supprimer un surlignage spécifique par son UUID
          function removeBlockRangeByGuid(userMarkGuid) {
            const blockRangeElements = document.querySelectorAll(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
            blockRangeElements.forEach(element => {
              // Supprimer toutes les classes de style
              removeAllStylesClasses(element);
              // Supprimer l'attribut UUID
              element.removeAttribute(blockRangeAttr);
            });
            
            window.flutter_inappwebview.callHandler('removeBlockRange', {
              UserMarkGuid: userMarkGuid,
              ShowAlertDialog: true
            });
          }
    
          // Fonction utilitaire pour changer la couleur d'un surlignage spécifique
          function changeBlockRangeStyle(userMarkGuid, styleIndex, colorIndex) {
            const blockRangeElements = pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
            const newStyleClass = getStyleClass(styleIndex, colorIndex);
            const newNoteClass = getNoteClass(colorIndex, true);
            
            blockRangeElements.forEach(element => {
              removeAllStylesClasses(element);
              element.classList.add(newStyleClass);
            });
            
            const noteElements = pageCenter.querySelectorAll(`[\${noteBlockRangeAttr}="\${userMarkGuid}"]`);
            
            if (noteElements.length !== 0) {
              noteElements.forEach(element => {
                removeNoteClasses(element);
                element.classList.add(newNoteClass);
              });
            }
            
            // Appel Flutter
            window.flutter_inappwebview.callHandler('changeBlockRangeStyle', {
              UserMarkGuid: userMarkGuid,
              StyleIndex: styleIndex,
              ColorIndex: colorIndex
            });
          }
          
          // Fonction utilitaire &pour changer la couleur d'une note
          function changeNoteColor(noteGuid, newColorIndex) {
            const note = pageCenter.querySelector(`[\${noteAttr}="\${noteGuid}"]`);
            const newNoteClass = getNoteClass(newColorIndex, true);

            removeNoteClasses(note);
            note.classList.add(newNoteClass);
            
            const { 
                  styleIndex: targetStyleIndex, 
                  colorIndex: targetColorIndex 
              } = getActiveStyleAndColorIndex(note, currentStyleIndex, newColorIndex);
            
            if(note.hasAttribute(noteBlockRangeAttr)) {
              const userMarkGuid = note.getAttribute(noteBlockRangeAttr);
              blockRangeElements = pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${userMarkGuid}"]`);
              const styleClass = getStyleClass(targetStyleIndex, newColorIndex);
              
              blockRangeElements.forEach(element => {
                removeAllStylesClasses(element);
                element.classList.add(styleClass);
              });
            }
            
            window.flutter_inappwebview.callHandler('changeNoteColor', {
              Guid: noteGuid,
              StyleIndex: targetStyleIndex,
              ColorIndex: newColorIndex
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
          
          // Variable globale pour stocker l'ID du timer
          let scrollBarTimeout;
          
          function hideScrollBar() {
            scrollBar.style.opacity = '0';
            scrollBar.addEventListener('transitionend', function handler() {
              scrollBar.style.display = 'none';
              scrollBar.removeEventListener('transitionend', handler);
            });
          }
          
          function showScrollBar() {
            clearTimeout(scrollBarTimeout);
            
            // 1. Rendre l'élément visible de façon instantanée, sans opacité
            scrollBar.style.transition = 'none';
            scrollBar.style.display = 'block';
            
            // 2. Forcer un "reflow" du navigateur pour qu'il reconnaisse le changement de 'display'.
            // C'est l'étape clé pour que l'opacité ne soit pas animée.
            // En accédant à une propriété comme offsetHeight, on force le navigateur à recalculer la mise en page.
            scrollBar.offsetHeight; 
            
            // 3. Réactiver la transition et changer l'opacité
            scrollBar.style.transition = 'opacity 0.5s ease-in-out';
            scrollBar.style.opacity = '1';
          
            // 4. Relance le minuteur pour cacher la barre après un court délai
            scrollBarTimeout = setTimeout(hideScrollBar, 500); 
          }
          
          function setupScrollBar() {
            // Ajouter la scrollBar
            scrollBar = document.createElement('img');
            scrollBar.className = 'scroll-bar';
            scrollBar.src = speedBarScroll;
            scrollBar.style.transition = 'opacity 0.5s ease-in-out'; // Pour une disparition en douceur
          
            scrollBar.addEventListener("touchstart", (e) => {
              if (e.touches.length !== 1) return;
              isTouchDragging = true;
              e.preventDefault(); // bloque le scroll natif
            }, { passive: false });
            
            scrollBar.addEventListener("touchmove", (e) => {
              if (!isTouchDragging) return;
            
              const touchY = controlsVisible ? e.touches[0].clientY - scrollBar.offsetHeight : e.touches[0].clientY;
            
              // Calcul des hauteurs de barres en fonction de l'état des contrôles
              const currentAppBarHeight = APPBAR_FIXED_HEIGHT;
              const currentBottomNavBarHeight = controlsVisible ? (BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0)) : 0;
              
              // La hauteur visible dépend maintenant de l'état des contrôles
              const visibleHeight = window.innerHeight - currentAppBarHeight - currentBottomNavBarHeight;
              
              // Les positions min et max de la scrollbar dépendent aussi de l'état des contrôles
              const minTop = currentAppBarHeight;
              const maxTop = currentAppBarHeight + (visibleHeight - scrollBar.offsetHeight); 
            
              const clampedTop = Math.max(minTop, Math.min(touchY, maxTop));
            
              // Le ratio de défilement doit être calculé par rapport à la zone visible
              const scrollRatio = (clampedTop - minTop) / (maxTop - minTop);
              
              const scrollableHeight = pageCenter.scrollHeight - pageCenter.clientHeight;
              pageCenter.scrollTop = scrollRatio * scrollableHeight;
              e.preventDefault();
            }, { passive: false });
            
            scrollBar.addEventListener("touchend", () => {
              isTouchDragging = false;
            });
            
            scrollBar.addEventListener("touchcancel", () => {
              isTouchDragging = false;
            });
            
            document.body.appendChild(scrollBar);
            
            // Appelle la fonction une première fois pour cacher la barre au chargement
            scrollBarTimeout = setTimeout(hideScrollBar, 3000);
          }
          
          async function init() {
            // Masquer le contenu avant le chargement
            pageCenter.classList.remove('visible');
          
            // Charger la page principale
            await loadIndexPage(currentIndex, true);
            pageCenter.scrollTop = 0;
            pageCenter.scrollLeft = 0;
              
            pageCenter.classList.add('visible');
            
            const curr = cachedPages[currentIndex];
            if (curr.preferredPresentation !== 'image' || !imageMode) {
              const article = document.getElementById("article-center");
              wrapWordsWithSpan(article, isBible());
              paragraphsData = fetchAllParagraphsOfTheArticle(article);
            } 
          
            setupScrollBar();
            createFloatingButton();
            
            //const bodyClone = pageCenter.cloneNode(true);
            //magnifierContent.appendChild(bodyClone);  
            
            // Informer Flutter que la page principale est chargée
            await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
          
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
              const hasSameChapter = $bookNumber === $lastBookNumber && $chapterNumber === $lastChapterNumber;
              const endIdForJump = hasSameChapter ? $endVerseId : null;
              jumpToIdSelector('.v', 'id', $startVerseId, endIdForJump);
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
          let appBarHeight = APPBAR_FIXED_HEIGHT;    // hauteur de l'AppBar
          let bottomNavBarHeight = BOTTOMNAVBAR_FIXED_HEIGHT; // hauteur de la BottomBar
          
          const DIRECTION_CHANGE_THRESHOLD_MS = 250;
          const DIRECTION_CHANGE_THRESHOLD_PX = 40;
   
          pageCenter.addEventListener("scroll", () => {
            // Appelle la fonction pour afficher la barre et relancer le minuteur
            showScrollBar();
            
            // Votre code existant pour le défilement commence ici
            closeToolbar();
            if (isLongPressing || isChangingParagraph) return;
          
            const scrollTop = pageCenter.scrollTop;
            const scrollHeight = pageCenter.scrollHeight;
            const clientHeight = pageCenter.clientHeight;
          
            const scrollDelta = scrollTop - lastScrollTop;
            let scrollDirection = scrollDelta > 0 ? "down" : scrollDelta < 0 ? "up" : "none";
            const now = Date.now();
          
            // If we reach the top of the page, force the direction to 'up' to show the controls.
            if (scrollTop === 0) {
              scrollDirection = "up";
            }
          
            // Détection de changement de direction pour la gestion des contrôles
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
          
            // Validation d’un geste franc pour afficher/masquer les contrôles et appeler l'handler Flutter
            if (directionChangePending && scrollDirection === directionChangeTargetDirection) {
              const timeDiff = now - directionChangeStartTime;
              const scrollDiff = Math.abs(scrollTop - directionChangeStartScroll);
          
              // Si on est à scrollTop = 0, on force l'affichage
              const isAtTop = scrollTop === 0;
          
              if (isAtTop || (timeDiff < DIRECTION_CHANGE_THRESHOLD_MS && scrollDiff > DIRECTION_CHANGE_THRESHOLD_PX)) {
                if(isFullscreenMode) {
                  window.flutter_inappwebview.callHandler('onScroll', scrollTop, scrollDirection);
                  lastDirection = scrollDirection;
                  directionChangePending = false;
                  
                  const floatingButton = document.getElementById('dialogFloatingButton');
                  
                  if(scrollDirection === 'down') {
                     controlsVisible = false;
                     if (floatingButton) {
                        floatingButton.style.opacity = '0';
                        floatingButton.style.pointerEvents = 'none';
                     }
                  }
                  else if (scrollDirection === 'up') {
                    controlsVisible = true;
                    if (floatingButton) {
                        floatingButton.style.opacity = '1';
                        floatingButton.style.pointerEvents = 'auto';
                    }
                  }
                }
              } 
              else if (timeDiff >= DIRECTION_CHANGE_THRESHOLD_MS) {
                directionChangePending = false;
              }
            } 
          
            // Mise à jour de la position de défilement à chaque scroll
            lastScrollTop = scrollTop;
            scrollTopPages[currentIndex] = scrollTop;
          
            // Calcul des hauteurs de barres en fonction de l'état des contrôles
            const currentAppBarHeight = APPBAR_FIXED_HEIGHT;
            const currentBottomNavBarHeight = controlsVisible ? (BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0)) : 0;
          
            // Mise à jour de la scrollbar en utilisant les hauteurs de barres dynamiques
            const visibleHeight = window.innerHeight - currentAppBarHeight - currentBottomNavBarHeight;
            const scrollableHeight = scrollHeight - clientHeight;
            
            let scrollBarTop = currentAppBarHeight;
            if (scrollableHeight > 0) {
              const scrollRatio = scrollTop / scrollableHeight;
              scrollBarTop = currentAppBarHeight + (visibleHeight - scrollBar.offsetHeight) * scrollRatio;
            }
            
            scrollBar.style.top = `\${scrollBarTop}px`;
            // Votre code existant pour le défilement se termine ici
          });
            
          // Variables globales pour éviter les redéclarations
          let currentGuid = '';
          let pressTimer = null;
          let firstLongPressTarget = null;
          let lastLongPressTarget = null;
          let isLongPressing = false;
          let isLongTouchFix = false;
          let isSelecting = false;
          let isDragging = false;
          let isVerticalScroll = false;
          let startX = 0;
          let startY = 0;
          let currentTranslate = -100;
         
          /**************
           * THROTTLE (si tu n’en as pas déjà un)
           **************/
          const throttle = (func) => {
            let scheduled = false;
            let lastArgs, lastContext;
          
            return function(...args) {
              lastArgs = args;
              lastContext = this;
          
              if (!scheduled) {
                // ✅ Exécuter tout de suite
                func.apply(lastContext, lastArgs);
                scheduled = true;
          
                requestAnimationFrame(() => {
                  scheduled = false;
                  if (lastArgs) {
                    func.apply(lastContext, lastArgs);
                    lastArgs = lastContext = null;
                  }
                });
              }
            };
          };
          
          async function onClickOnPage(article, target) {
            const tagName = target.tagName;
            
            if(document.body.classList.contains('selection-active') || isSelecting) {
              removeAllSelected();
              closeToolbar();
              return;
            }
            
            // Early returns pour les cas simples
            if (tagName === 'TEXTAREA' || tagName === 'INPUT') {
              closeToolbar();
              return;
            }

            if (tagName === 'IMG') {
              // 1. Tente de trouver l'élément parent <a> qui contient l'attribut 'data-video'
              //    (target.closest('a') recherche l'ancêtre <a> le plus proche)
              const videoLink = target.closest('a[data-video]');
            
              // 2. Vérifie si un tel élément parent a été trouvé
              const isVideoThumbnail = videoLink !== null;
            
              if (isVideoThumbnail) {
                // Si c'est une miniature de vidéo, on récupère la valeur de l'attribut
                const videoData = videoLink.getAttribute('data-video');
                
                closeToolbar();
                return; // Sortie : on ne traite PAS comme une simple image
              }
              
              // Si ce n'est pas un lien vidéo, on le traite comme une image normale
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
                showVerseDialog(article, verses, href, false);
                closeToolbar();
                return;
              }
              
              if(href.startsWith('jwpub://p/')) { 
                  if(article.id === 'verse-info-dialog-guide-id') { 
                      const dataXtId = matchedElement.getAttribute('data-xtid'); 
              
                      if (dataXtId) { 
                          const extract = await window.flutter_inappwebview.callHandler('fetchGuideVerse', dataXtId); 
              
                          if(extract != null) { 
                              showExtractPublicationDialog(article, extract, href); 
                              closeToolbar(); 
                          } 
                      } 
                  } 
                  else {
                      const extract = await window.flutter_inappwebview.callHandler('fetchExtractPublication', href); 
                      if (extract != null) { 
                          showExtractPublicationDialog(article, extract, href); 
                          closeToolbar(); 
                      } 
                  } 
                  return; 
              }
              
              if(href.startsWith('jwpub://c/')) {
                const commentary = await window.flutter_inappwebview.callHandler('fetchCommentaries', href);
                if (commentary != null) {
                  showVerseCommentaryDialog(article, commentary, href);
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
              showFootNoteDialog(article, footnote, 'footnote-' + fnid);
              closeToolbar();
              return;
            }
            
            if (classList.contains('m')) {
              const mid = target.getAttribute('data-mid');
              const versesReference = await window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
              showVerseReferencesDialog(article, versesReference, 'verse-references-' + mid);
              closeToolbar();
              return;
            }
            
            if (classList.contains('gen-field')) {
              closeToolbar();
              return;
            }
            
            const highlightId = target.getAttribute(blockRangeAttr);
            if (highlightId) {
              showToolbarHighlight(target, highlightId);
              return;
            }
            
            //removeAllSelected();
            
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
          
          function selectWord(range, textNode, offset) {
              const text = textNode.textContent;
          
              // Détermine le point de départ du balayage (offset est la position du curseur/doigt)
              let left = offset;
              let right = offset;
          
              // 1. Recherche de la limite gauche du mot
              // On recule tant qu'on rencontre des caractères non-espace/non-séparateur
              while (left > 0 && /\w/.test(text[left - 1])) {
                  left--;
              }
          
              // 2. Recherche de la limite droite du mot
              // On avance tant qu'on rencontre des caractères non-espace/non-séparateur
              while (right < text.length && /\w/.test(text[right])) {
                  right++;
              }
              
              // 3. Applique les limites à la Range
              range.setStart(textNode, left);
              range.setEnd(textNode, right);
          }
          
          function toggleSelection(active) {
            if(active) {
              document.body.classList.add('selection-active');
            }
            else {
               document.body.classList.remove('selection-active');
            }
          }
          
          // Variable pour ignorer le premier selectionchange lors de l'appui long
          let isInitialSelectionChange = false;
          
          // Empêche le menu contextuel du navigateur (qui apparaît suite à un clic droit ou un appui long)
          pageCenter.addEventListener('contextmenu', (event) => {
              if((isLongTouchFix || isSelecting) && !isReadingMode) {
                isLongTouchFix = false;
                isSelecting = true;
                event.preventDefault();
                
                // NOUVEAU : On indique qu'on est en train de créer la sélection initiale
                isInitialSelectionChange = true;
              
                closeToolbar();
                
                const selection = window.getSelection();
            
                // Vérifie qu'il y a bien une sélection valide
                if (!selection.rangeCount || selection.isCollapsed) return;
              
                const range = selection.getRangeAt(0);
              
                // Récupère les nœuds de début et de fin
                const startNode = range.startContainer;
                const endNode = range.endContainer;
              
                // Si les nœuds sont des TextNodes, on veut leur élément parent
                const startEl = startNode.nodeType === Node.TEXT_NODE ? startNode.parentElement : startNode;
                const endEl = endNode.nodeType === Node.TEXT_NODE ? endNode.parentElement : endNode;
              
                // Affecte les variables globales
                firstLongPressTarget = startEl;
                lastLongPressTarget = endEl;
                
                if (firstLongPressTarget) {
                    showSelectedToolbar(firstLongPressTarget);
                }
                
                // NOUVEAU : On réactive la surveillance après un court délai
                setTimeout(() => {
                  isInitialSelectionChange = false;
                }, 100);
              }
              else {
                // 1. Vérifie si l'élément cliqué est une image ou l'un de ses parents
                const target = event.target.closest('img');
            
                if (target) {
                    // Empêche le menu contextuel par défaut du navigateur d'apparaître
                    event.preventDefault();
            
                    const imageUrl = target.src;
                    window.flutter_inappwebview.callHandler('imageLongPressHandler', imageUrl, event.clientX, event.clientY);
                }
              }
          }, false);
          
          document.addEventListener('selectionchange', () => {
            // NOUVEAU : Ignore le selectionchange si c'est la sélection initiale
            if (isInitialSelectionChange) {
              return;
            }
            
            closeToolbar();
          });
          
          // Gestionnaire d'événements click optimisé
          pageCenter.addEventListener('click', async (event) => {
            // NOUVEAU : Si on était en mode isSelecting et qu'on clique, on nettoie les targets
            firstLongPressTarget = null;
            lastLongPressTarget = null;
            
            onClickOnPage(pageCenter, event.target);
          });
          
          /**************
           * TOUCH HANDLERS
           **************/
          pageCenter.addEventListener('touchstart', (event) => {
            if(isReadingMode) return;
            
            // Handles de sélection
            if (!isSelecting) {
              if (pressTimer) clearTimeout(pressTimer);
          
              firstLongPressTarget = event.target;
          
              pressTimer = setTimeout(async () => {
                closeToolbar();
                toggleSelection(true);
          
                const firstTargetClassList = firstLongPressTarget?.classList;
                if (firstLongPressTarget && firstTargetClassList && (firstTargetClassList.contains('word') || firstTargetClassList.contains('punctuation'))) {
                  try {
                    // GUID pour le style courant
                    const response = await window.flutter_inappwebview.callHandler('getGuid');
                    currentGuid = response.Guid;
          
                    setLongPressing(true);
                    isLongTouchFix = true;
                  } 
                  catch (error) {
                    console.error('Error getting style GUID:', error);
                  }
                }
              }, 230);
            }
          }, { passive: false });
          
          // --- Touchmove optimisé ---
          const handleTouchMove = throttle((event) => {
            if(isReadingMode) return;
            
            isLongTouchFix = false;
            
            if(document.body.classList.contains('selection-active') && !isSelecting) {
              document.body.classList.remove('selection-active');
            }
          
            if (isLongPressing && currentGuid && !isSelecting) {
              if (event.cancelable) event.preventDefault();
          
              const touch = event.touches[0];
              const x = touch.clientX;
              const y = touch.clientY;
          
              updateMagnifier(x, y);
          
              const closestElement = getClosestElementHorizontally(x, y);
              const cl = closestElement?.classList;
              if (closestElement && cl && (cl.contains('word') || cl.contains('punctuation'))) {
                if (closestElement !== lastLongPressTarget) {
                  lastLongPressTarget = closestElement;
                  updateTempStyle();
                }
              }
            }
          
            else if (pressTimer) {
              clearTimeout(pressTimer);
              pressTimer = null;
            }
          });
          
          pageCenter.addEventListener('touchmove', handleTouchMove, { passive: false });
          
          pageCenter.addEventListener('touchend', (event) => {
            if(isReadingMode) return;
            
            if (isLongPressing) {
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
          
          /**************
           * GET CLOSEST ELEMENT (inchangé)
           **************/
          function getClosestElementHorizontally(x, y) {
            const allElements = getAllWordsAndPuncts();
            let closest = null;
            let minDistance = Infinity;
          
            for (const el of allElements) {
              const rect = el.getBoundingClientRect();
              if (rect.height === 0 || rect.width === 0) continue;
              if (y >= rect.top && y <= rect.bottom) {
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
  
          let oldStylesMap = new Map();    // Map<Element, Map<styleIndex, { styleIndex, styleClass }>>
          let tempTokensByGuid = new Map(); // Map<guid, Set<Element>>
          
          /**************
           * UTILS STYLE
           **************/
           
          function getColorIndex(styleIndex = currentStyleIndex) {
            const style = getStyleConfig(styleIndex);
            return style ? style.colorIndex : 1;
          }
          
          function setColorIndex(styleIndex = currentStyleIndex, colorIndex) {
            const style = getStyleConfig(styleIndex);
            style.colorIndex = colorIndex;
          }
          
          function getActiveStyleAndColorIndex(target) {
            // Résultat par défaut
            let result = {
                styleIndex: currentStyleIndex,
                colorIndex: getColorIndex()    
            };
        
            // 1. Récupérer les clés de STYLE sous forme de tableau
            const styleKeys = Object.keys(STYLE);
        
            // 2. Parcourir les clés, en ayant accès à leur index de position (styleIndex)
            for (let i = 0; i < styleKeys.length; i++) {
                const styleKey = styleKeys[i]; // ex: 'highlight', 'underline'
                const style = STYLE[styleKey];
                const classes = style.classes; 
        
                // 3. Itérer sur les classes de l'élément cible
                for (const className of target.classList) {
                    const colorIndex = classes.indexOf(className);
                    
                    // Si la classe de couleur est trouvée
                    if (colorIndex !== -1) {
                        result.styleIndex = i; 
                        result.colorIndex = colorIndex;
                        
                        // Retourner immédiatement les deux index
                        return result; 
                    }
                }
            }
          
            // Si aucun style n'est trouvé, on retourne le résultat par défaut (null pour styleIndex)
            return result;
          }
           
          function getStyleConfig(styleIndex = currentStyleIndex) {
            const styleTypes = Object.keys(STYLE);
            const styleType = styleTypes[styleIndex] || "highlight";
            return STYLE[styleType];
          }
          
          function getStyleClass(styleIndex = currentStyleIndex, colorIndex = 1) {
            const cfg = getStyleConfig(styleIndex);
            const opts = cfg.options;
            const idx = ((colorIndex % opts.length) + opts.length) % opts.length; // safe modulo
            return cfg.styleName + '-' + opts[idx];
          }
          
          function setCurrentStyle(styleIndex = 0, colorIndex = 0) {
            currentStyleIndex = styleIndex;
            setColorIndex(currentStyleIndex);
          }
    
          function removeStyleClasses(token, styleIndex) {
            const cfg = getStyleConfig(styleIndex);
            cfg.classes.forEach(c => token.classList.remove(c));
          }
          
          function removeAllStylesClasses(token) {
            Object.keys(STYLE).forEach((styleKey, index) => { // styleKey est 'highlight', 'underline', etc. ; index est 0, 1, etc.
              removeStyleClasses(token, index);
            });
          }
          
          function removeNoteClasses(token) {
            // Assuming colorsList is accessible in this scope
            colorsList.forEach(color => {
              // Correct usage of template literals (backticks) for interpolation
              token.classList.remove(`note-\${color}`); 
              token.classList.remove(`note-indicator-\${color}`);
            });
          }
          
          function getNoteClass(colorIndex, isIndicator) {
            console.log('noteClass = \${colorIndex}');
            const colorName = colorsList[colorIndex ?? 0]; 
          
            if (colorName) {
              // Utilisation des template literals (accents graves) pour construire la classe
              return isIndicator ? `note-indicator-\${colorName}` : `note-\${colorName}`
            }
          
            // Si l'index est 0 ou en dehors des limites du tableau
            return isIndicator ? `note-indicator-gray` : `note-gray`;
          }
          
          function applyTempStyle(token, styleIndex, styleClass) {
            const cfg = getStyleConfig(styleIndex);
            const existingId = token.getAttribute(blockRangeAttr);
          
            // Sauvegarde l’ancien style une seule fois (par token et par styleIndex)
            if (existingId && existingId !== currentGuid) {
              let perToken = oldStylesMap.get(token);
              if (!perToken) {
                perToken = new Map();
                oldStylesMap.set(token, perToken);
              }
              if (!perToken.has(styleIndex)) {
                const oldClass = Array.from(token.classList).find(c => cfg.classes.includes(c));
                perToken.set(styleIndex, { styleId: existingId, styleClass: oldClass || null });
              }
            }
          
            // 🎯 CORRECTION : N'enlève QUE les classes associées à styleIndex (pour l'imbrication)
            removeStyleClasses(token, styleIndex); 
            
            // Applique le style temporaire
            token.classList.add(styleClass);
            token.setAttribute(blockRangeAttr, currentGuid);
          }
          
          // --------------------------------------------------------------------------------
          
          function restoreTokenIfNeeded(token, styleIndex) {
            const cfg = getStyleConfig(styleIndex);
          
            const perToken = oldStylesMap.get(token);
            if (perToken && perToken.has(styleIndex)) {
              const { styleId, styleClass } = perToken.get(styleIndex);
              perToken.delete(styleIndex);
              if (perToken.size === 0) oldStylesMap.delete(token);
          
              // Déjà correct : On retire SEULEMENT les classes liées à styleIndex
              removeStyleClasses(token, styleIndex); 
              
              token.removeAttribute(blockRangeAttr);
          
              if (styleId) token.setAttribute(blockRangeAttr, styleId);
              if (styleClass) token.classList.add(styleClass); 
            } else {
              // aucun ancien style → on nettoie
              removeStyleClasses(token, styleIndex);
              
              token.removeAttribute(blockRangeAttr);
            }
          }
                    
                    /**************
           * UPDATE TEMP (générique)
           **************/
          function updateTempStyle() {
            if (!firstLongPressTarget && !lastLongPressTarget) return;
          
            const firstParagraphInfo = getTheFirstTargetParagraph(firstLongPressTarget);
            const lastParagraphInfo = getTheFirstTargetParagraph(lastLongPressTarget);
            if (!firstParagraphInfo || !lastParagraphInfo) return;
          
            // =========================================================================
            // LOGIQUE STYLE : Déterminer le style à manipuler (pour gérer l'effacement/modification)
            // =========================================================================
            const { 
                styleIndex: targetStyleIndex, 
                colorIndex: targetColorIndex 
            } = getActiveStyleAndColorIndex(firstLongPressTarget, currentStyleIndex, getColorIndex());
          
            const tempStyleIndex = targetStyleIndex;
            const tempColorIndex = targetColorIndex;
            // =========================================================================
          
            const firstId = firstParagraphInfo.id;
            const lastId  = lastParagraphInfo.id;
          
            // LOGIQUE DOM (Ordre d'itération et de sélection)
            const orderedIds = Array.from(paragraphsData.keys()); 
            
            let startDOMIndex = orderedIds.indexOf(firstId); 
            let endDOMIndex   = orderedIds.indexOf(lastId);  
          
            if (startDOMIndex === -1 || endDOMIndex === -1) return;
          
            let fromIndex = Math.min(startDOMIndex, endDOMIndex); 
            let toIndex   = Math.max(startDOMIndex, endDOMIndex);
            
            const isForwardSelection = (startDOMIndex <= endDOMIndex); 
          
            // Utiliser les infos de paragraphe complètes, ordonnées par leur apparition dans le DOM
            const startParagraphInfoDOM = isForwardSelection ? firstParagraphInfo : lastParagraphInfo;
            const endParagraphInfoDOM   = isForwardSelection ? lastParagraphInfo  : firstParagraphInfo;
            
            // Utiliser les index temporaires pour obtenir la classe et la configuration
            const styleClass = getStyleClass(tempStyleIndex, tempColorIndex); 
            const cfg = getStyleConfig(tempStyleIndex);
          
            requestAnimationFrame(() => {
              const newTokens = new Set();
          
              // ITÉRATION : Sur les paragraphes dans l'ordre du DOM
              for (let i = fromIndex; i <= toIndex; i++) {
                const currentId = orderedIds[i]; 
                const paragraphData = paragraphsData.get(currentId);
                
                if (!paragraphData) continue; 
                
                const { allTokens, wordAndPunctTokens, indexInAll } = paragraphData;
                
                let startTokenIndex = 0;
                let endTokenIndex   = wordAndPunctTokens.length - 1;
          
                const isStartParagraph = (paragraphData === startParagraphInfoDOM);
                const isEndParagraph   = (paragraphData === endParagraphInfoDOM);
                
                // LOGIQUE DES TOKENS CORRIGÉE (Gère l'inversion de glisser)
                const indexOfFirst = wordAndPunctTokens.indexOf(firstLongPressTarget);
                const indexOfLast  = wordAndPunctTokens.indexOf(lastLongPressTarget);
          
                if (isStartParagraph && isEndParagraph) {
                  // Début et Fin dans le MÊME paragraphe
                  if (indexOfFirst === -1 || indexOfLast === -1) continue;
                  
                  startTokenIndex = Math.min(indexOfFirst, indexOfLast);
                  endTokenIndex   = Math.max(indexOfFirst, indexOfLast);
                  
                } else if (isStartParagraph) {
                  // C'est le paragraphe de début DOM
                  const index = (indexOfFirst !== -1) ? indexOfFirst : indexOfLast;
                  if (index === -1) continue; 
                  startTokenIndex = index;
                  
                } else if (isEndParagraph) {
                  // C'est le paragraphe de fin DOM
                  const index = (indexOfFirst !== -1) ? indexOfFirst : indexOfLast;
                  if (index === -1) continue;
                  endTokenIndex = index;
                  
                }
          
                for (let j = startTokenIndex; j <= endTokenIndex; j++) {
                  const token = wordAndPunctTokens[j];
                  newTokens.add(token);
          
                  // Inclure l'élément .escape juste après
                  const idxInAll = indexInAll.get(token);
                  if (idxInAll != null) {
                    const next = allTokens[idxInAll + 1];
                    if (next?.classList.contains('escape') && j < endTokenIndex) {
                      newTokens.add(next);
                    }
                  }
                }
              }
          
              // Récupérer l'ancien set de tokens pour ce guid
              let oldTokens = tempTokensByGuid.get(currentGuid);
              if (!oldTokens) {
                // 🎯 CORRECTION DE LA SYNTAXE
                oldTokens = new Set(pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${currentGuid}"]`)); 
                tempTokensByGuid.set(currentGuid, oldTokens);
              }
          
              // ➕ Ajouter les nouveaux
              newTokens.forEach(token => {
                if (!oldTokens.has(token)) {
                  applyTempStyle(token, tempStyleIndex, styleClass);
                  oldTokens.add(token);
                }
              });
          
              // ➖ Retirer ceux qui ne font plus partie
              Array.from(oldTokens).forEach(token => {
                if (!newTokens.has(token)) {
                  restoreTokenIfNeeded(token, tempStyleIndex);
                  oldTokens.delete(token);
                }
              });
            });
          }

          // Fonction onLongPressEnd optimisée avec gestion d'erreurs et cache tokens
          async function onLongPressEnd() {
            try {
              // Déterminer le style réellement utilisé
              const { 
                styleIndex: tempStyleIndex,
                colorIndex: targetColorIndex 
              } = getActiveStyleAndColorIndex(firstLongPressTarget, currentStyleIndex, getColorIndex());
          
              const finalStyleIndex = tempStyleIndex;
              const finalColorIndex = targetColorIndex;
          
              // Récupération des tokens temporaires depuis le cache (ou fallback DOM)
              let tempBlockRangesElements = tempTokensByGuid.get(currentGuid);
              if (!tempBlockRangesElements) {
                tempBlockRangesElements = new Set(
                  pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${currentGuid}"]`)
                );
                tempTokensByGuid.set(currentGuid, tempBlockRangesElements);
              }
          
              // ✅ Convertir en tableau trié selon l’ordre DOM
              const tempArray = Array.from(tempBlockRangesElements).sort((a, b) =>
                a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
              );
          
              // Fusion / nettoyage des anciens styles sauvegardés
              oldStylesMap.forEach((perToken, token) => {
                if (!tempBlockRangesElements.has(token)) return;
          
                perToken.forEach((value) => {
                  if (value.styleId) {
                    const newClass = getStyleClass(finalStyleIndex, finalColorIndex); 
                    const elems = Array.from(
                      pageCenter.querySelectorAll(`[\${blockRangeAttr}="\${value.styleId}"]`)
                    );
                    elems.forEach(el => {
                      removeAllStylesClasses(el);
                      el.classList.add(newClass);
                      el.setAttribute(blockRangeAttr, currentGuid);
                      tempBlockRangesElements.add(el);
                    });
          
                    // Demander à Flutter de supprimer l’ancien block range
                    window.flutter_inappwebview.callHandler('removeBlockRange', {
                      UserMarkGuid: value.styleId,
                      NewUserMarkGuid: currentGuid,
                      ShowAlertDialog: false
                    });
                  }
                });
              });
          
              // Nettoyer la map
              oldStylesMap.clear();
          
              // Afficher la toolbar si sélection valide
              if (tempArray.length > 0) {
                showToolbarHighlight(tempArray[0], currentGuid);
              }
          
              // Construction des données à envoyer
              const blockRangesToSend = [];
              let currentParagraphId = -1;
              let currentIsVerse = false;
              let tokensBuffer = [];
          
              function flushParagraphBuffer() {
                if (tokensBuffer.length === 0) return;
                addBlockRangeForParagraph(tokensBuffer, currentParagraphId, currentIsVerse);
                tokensBuffer = [];
              }
          
              for (let i = 0; i < tempArray.length; i++) {
                const element = tempArray[i];
                const { id, isVerse } = getTheFirstTargetParagraph(element);
                if (id == null) continue;
          
                if (id !== currentParagraphId) {
                  // Nouveau paragraphe → flush précédent
                  flushParagraphBuffer();
          
                  currentParagraphId = id;
                  currentIsVerse = isVerse;
                  tokensBuffer = [element];
                } else {
                  tokensBuffer.push(element);
                }
              }
          
              // Sauvegarder le dernier paragraphe
              flushParagraphBuffer();
          
              // ✅ Ajoute un block range par paragraphe à partir des tokens réellement sélectionnés
              function addBlockRangeForParagraph(tokenArray, pid, isVerse) {
                const paragraphData = paragraphsData.get(pid);
                if (!paragraphData) return;
          
                const { wordAndPunctTokens } = paragraphData;
                const tokensInParagraph = tokenArray.filter(t => wordAndPunctTokens.includes(t));
                if (tokensInParagraph.length === 0) return;
          
                const firstEl = tokensInParagraph[0];
                const lastEl  = tokensInParagraph[tokensInParagraph.length - 1];
          
                const startIdx = wordAndPunctTokens.indexOf(firstEl);
                const endIdx   = wordAndPunctTokens.indexOf(lastEl);
          
                if (startIdx === -1 || endIdx === -1) {
                  console.error(`❌ Impossible de retrouver les bornes dans le paragraphe \${pid}`);
                  return;
                }
          
                blockRangesToSend.push({
                  BlockType: isVerse ? 2 : 1,
                  Identifier: pid,
                  StartToken: Math.min(startIdx, endIdx),
                  EndToken: Math.max(startIdx, endIdx),
                });
              }
          
              // Envoi unique à Flutter
              await window.flutter_inappwebview.callHandler(
                'addBlockRanges',
                currentGuid,
                finalStyleIndex,
                finalColorIndex,
                blockRangesToSend
              );
          
              // Nettoyage final du cache
              tempTokensByGuid.delete(currentGuid);
          
            } catch (err) {
              console.error('Error in onLongPressEnd:', err);
            } finally {
              // Reset état global
              firstLongPressTarget = null;
              lastLongPressTarget = null;
            }
          }
          
          function updateMagnifier(x, y) {
            const magnifierSize = 130;
            const zoomFactor = 1;
            
            // Position de la loupe (décalée vers le haut pour ne pas être sous la souris)
            const offsetX = x - magnifierSize / 2;
            const offsetY = y - magnifierSize + 40;
            
            magnifier.style.left = `\${offsetX}px`;
            magnifier.style.top = `\${offsetY}px`;
            magnifier.classList.remove('hide'); // Assurez-vous qu'elle est visible

            // Calcul de la position pour centrer la zone zoomée
            const centerX = magnifierSize / 2;
            const centerY = magnifierSize / 2;
            const scrollY = pageCenter.scrollTop;
            
            // Position du contenu zoomé
            //magnifierContent.style.transform = `scale(\${zoomFactor})`;
            //magnifierContent.style.left = `\${centerX - x * zoomFactor}px`;
            //magnifierContent.style.top = `\${centerY - y - 40 - scrollY * zoomFactor}px`;
          }
        
          function hideMagnifier() {
              magnifier.classList.add('hide');
          }
            
          // Votre fonction actuelle est la bonne méthode.
          function getTheFirstTargetParagraph(target) {
            let targetIdValue = null; 
            
            // 1. Navigation DOM optimisée
            const verse = target.closest('.v[id]');
            if (verse) {
              targetIdValue = verse.id.split('-')[2]; 
            } else {
              const paragraph = target.closest('[data-pid]');
              if (paragraph) {
                targetIdValue = paragraph.getAttribute('data-pid');
              }
            }
          
            // 2. Accès instantané O(1)
            if (targetIdValue) {
              const targetIdInt = parseInt(targetIdValue, 10);
              if (paragraphsData.has(targetIdInt)) {
                return paragraphsData.get(targetIdInt);
              }
            }
            
            return null;
          }
          
          function getAllWordsAndPuncts() {
            let allTokens = [];
            
            // Parcourir tous les paragraphes dans la Map
            paragraphsData.forEach(paragraphData => {
              // Ajouter les wordAndPunctTokens de chaque paragraphe
              allTokens = allTokens.concat(paragraphData.wordAndPunctTokens);
            });
            
            return allTokens;
          }
          
          function fetchAllParagraphsOfTheArticle(article) {
            const paragraphsDataMap = new Map();
                        
            // 1. Récupérer les paragraphes/versets groupés avec leurs métadonnées
            const fetchedParagraphs = fetchAllParagraphs(article);
            
            // 2. Indexer les tokens pour chaque groupe
            const indexedTokens = indexTokens(fetchedParagraphs);
            
            // 3. Fusionner les deux et stocker le résultat final dans paragraphsDataMap
            fetchedParagraphs.forEach(group => {
              
              // CHANGEMENT ICI : La clé pour récupérer les tokens est le tableau 'group.paragraphs'
              const tokens = indexedTokens.get(group.paragraphs) || { 
                  allTokens: [], 
                  wordAndPunctTokens: [], 
                  indexInAll: new Map() 
              }; 
              
              // Fusion des objets
              paragraphsDataMap.set(group.id, {
                paragraphs: group.paragraphs, // Les éléments DOM du paragraphe/verset
                id: group.id,                // L'ID unique (ex: "15" ou data-pid)
                isVerse: group.isVerse,      // Booléen indiquant si c'est un verset
                allTokens: tokens.allTokens, // Tous les tokens (mots, ponctuation, échappements)
                wordAndPunctTokens: tokens.wordAndPunctTokens, // Mots et ponctuation uniquement
                indexInAll: tokens.indexInAll // Map pour trouver l'index global d'un token
              });
            });
            
            return paragraphsDataMap;
          }
          
          function fetchAllParagraphs(article) {
            const finalList = [];
            // Sélectionne tous les éléments qui ressemblent à une partie de verset
            const verses = Array.from(article.querySelectorAll('.v[id]'));
          
            if (verses.length > 0) {
              // Cas 1: L'article contient des versets (plusieurs parties peuvent former un verset)
              const grouped = {};
              verses.forEach(verse => {
                const parts = verse.id.split('-'); // ex: ["v1","3","15","1"]
                const verseUniqueKey = parts[2];   // L'ID unique du verset (ex: "15")
                if (!grouped[verseUniqueKey]) grouped[verseUniqueKey] = [];
                grouped[verseUniqueKey].push(verse);
              });
          
              Object.entries(grouped).forEach(([id, group]) => {
                // Tri des parties du verset par leur index final (la partie du verset)
                group.sort((a, b) => parseInt(a.id.split('-')[3], 10) - parseInt(b.id.split('-')[3], 10));
                
                // Création de la structure d'objet demandée
                finalList.push({
                  paragraphs: group, // toutes les parties du verset, dans l'ordre
                  // CONVERSION EN ENTIER ICI
                  id: parseInt(id, 10), // ID unique du verset converti en nombre
                  isVerse: true
                });
              });
          
            } 
            else {
              // Cas 2: L'article contient des paragraphes normaux (non-versets)
              const paras = Array.from(article.querySelectorAll('[data-pid]'));
              paras.forEach(p => {
                // Création de la structure d'objet demandée
                // La valeur de data-pid doit également être convertie en nombre si elle est numérique
                const pid = p.getAttribute('data-pid');
                
                finalList.push({
                  paragraphs: [p], // tableau avec uniquement ce paragraphe
                  // CONVERSION EN ENTIER ICI
                  id: parseInt(pid, 10), // ID unique du paragraphe converti en nombre
                  isVerse: false
                });
              });
            }
            
            return finalList;
          }
          
          // La fonction indexTokens doit être modifiée pour utiliser 'paragraphs' directement comme clé dans la Map
          function indexTokens(groups) {
            const map = new Map();
            groups.forEach(group => {
              // La clé de la Map est le tableau 'paragraphs'
              const p = group.paragraphs; 
              
              // ... votre code actuel de calcul des tokens ...
              const allTokens = p.flatMap(el =>
                Array.from(el.querySelectorAll('.word, .punctuation, .escape'))
              );
              const wordAndPunctTokens = allTokens.filter(
                t => t.classList.contains('word') || t.classList.contains('punctuation')
              );
              const indexInAll = new Map();
              for (let i = 0; i < allTokens.length; i++) indexInAll.set(allTokens[i], i);
          
              // Stockage en utilisant le tableau de paragraphes comme clé
              map.set(p, { allTokens, wordAndPunctTokens, indexInAll });
            });
            return map;
          }
          
          async function changePage(direction) {
            try {
              if (direction === 'right') {
                currentTranslate = -200;
                container.style.transform = "translateX(-200%)";
                
                setTimeout(async () => {
                  currentIndex++;
                  currentTranslate = -100;
                  closeToolbar();
                  await loadPages(currentIndex);
                }, 200);
                
              } 
              else if (direction === 'left') {
                currentTranslate = 0;
                container.style.transform = "translateX(0%)";
                
                setTimeout(async () => {
                  currentIndex--;
                  currentTranslate = -100;
                  closeToolbar();
                  await loadPages(currentIndex);
                }, 200);
                
              } 
              else {
                container.style.transform = "translateX(-100%)";
              }
              
            } catch (error) {
              console.error('Error in changePage function:', error);
            }  
          }
          
          // Gestionnaire touchstart modifié pour détecter 2 doigts
          container.addEventListener('touchstart', (e) => {
            if (isLongPressing || isBlockingHorizontallyMode) return;
            
            document.querySelectorAll('.options-menu, .color-menu').forEach(el => el.remove());
            
            startX = e.touches[0].clientX;
            startY = e.touches[0].clientY;
            isDragging = true;
            isVerticalScroll = false;
          
            container.style.transition = "none";
          }, { passive: true });
          
          // Gestionnaire touchmove modifié
          const handleContainerTouchMove = throttle((e) => {
            if (isLongPressing || !isDragging || isBlockingHorizontallyMode) {
              return;
            }
            
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
          
          // Gestionnaire touchend modifié
          container.addEventListener('touchend', async (e) => {
            isLongTouchFix = false;
            
            if (isLongPressing) {
              setLongPressing(false);
              isDragging = false;
              return;
            }
            
            if(isBlockingHorizontallyMode) return;

            if (!isDragging) return;
            
            isDragging = false;
          
            if (isVerticalScroll) {
              container.style.transition = "transform 0.2s ease-in-out";
              container.style.transform = `translateX(\${currentTranslate}%)`;
              return;
            }
            
            const dx = e.changedTouches[0].clientX - startX;
            const percentage = dx / window.innerWidth;
            container.style.transition = "transform 0.2s ease-in-out";
          
            if (percentage < -0.15 && currentIndex < maxIndex) {
              changePage('right');
            } 
            else if (percentage > 0.15 && currentIndex > 0) {
              changePage('left');
            } 
            else {
              container.style.transform = "translateX(-100%)";
            }
          }, { passive: true });
        </script>
      </body>
    </html>
''';
}