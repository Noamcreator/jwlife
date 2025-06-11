import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/data/databases/Audio.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';

Future<void> loadJavascriptHighlight(InAppWebViewController controller, Document currentDocument, bool isDark) async {
  await controller.evaluateJavascript(source: """
document.querySelectorAll('[data-pid]').forEach(function(element) {
    // Diviser les mots en les entourant avec des <span>
    console.log(element.innerHTML);
    element.innerHTML = element.innerHTML.replace(/(^|<\/?[^>]+>|\s+|[.,:;!?()[\]{}])([^<>\s.,:;!?()[\]{}]+)/g, '\$1<span class="word">\$2</span>');
    element.innerHTML = element.innerHTML.replace(/([.,:;!?()[\]{}])/g, '<span class="word">\$1</span>');

    // Ajouter une logique d'appui long pour le surlignage
    element.addEventListener('mousedown', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Démarrer un timer lorsque l'utilisateur commence à appuyer
            ev.target.highlightTimer = setTimeout(function() {
                ev.target.classList.add('highlighted'); // Ajouter le surlignage après 500 ms
            }, 500); // Délai d'appui long : 500 ms
        }
    });

    element.addEventListener('mouseup', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Annuler le timer si l'utilisateur relâche trop tôt
            clearTimeout(ev.target.highlightTimer);
        }
    });

    element.addEventListener('mouseleave', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Annuler le timer si la souris quitte l'élément
            clearTimeout(ev.target.highlightTimer);
        }
    });

    element.addEventListener('touchstart', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Même logique pour les appareils tactiles
            ev.target.highlightTimer = setTimeout(function() {
                ev.target.classList.add('highlighted'); // Ajouter le surlignage après 500 ms
            }, 500);
        }
    });

    element.addEventListener('touchend', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Annuler le timer si l'utilisateur relâche trop tôt
            clearTimeout(ev.target.highlightTimer);
        }
    });

    element.addEventListener('touchcancel', function(ev) {
        if (ev.target.classList.contains('word')) {
            // Annuler le timer si le touch est annulé
            clearTimeout(ev.target.highlightTimer);
        }
    });
});
  """);

  String? text = await controller.getHtml();
  for (var line in text!.split('\n')) {
    print('line: $line');
  }
}

Future<void> loadJavascriptToolBars(InAppWebViewController controller, List<Audio> audios, Document document, bool isDark) async {
  loadJavascriptParagraph(controller, audios, document, isDark);
}

Future<void> loadJavascriptParagraph(
    InAppWebViewController controller,
    List<Audio> audios,
    Document document,
    bool isDark,
    ) async {
  String audioMarkersJson = '[]';

  if (audios.isNotEmpty) {
    final audio = audios.firstWhereOrNull((a) => a.documentId == document.mepsDocumentId);
    if (audio != null && audio.markers.isNotEmpty) {
      audioMarkersJson = jsonEncode(audio.markers.map((m) => m.toJson()).toList());
    }
  }

  final script = """
    const isDark = ${isDark.toString()};
    const audioMarkers = ${audioMarkersJson};
    const pageCenter = document.getElementById("page-center");


    function restoreOpacity(selector) {
      document.querySelectorAll(selector).forEach(e => e.style.opacity = '1');
    }

    function dimOthers(current, selector) {
      document.querySelectorAll(selector).forEach(e => {
        if (e !== current) e.style.opacity = '0.5';
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
        color: \${isDark ? 'white' : '#4f4f4f'};
      \`;
      button.addEventListener('click', onClick);
      return button;
    }

    function closeToolbar(selector) {
      const toolbar = document.querySelector('.toolbar');
      if (toolbar) toolbar.remove();
      restoreOpacity(selector);
    }

    function removeHighlight(elem, selector) {
      elem.classList.remove('highlight-yellow');
      closeToolbar(selector);
    }

    function showToolbar(paragraph, id, selector, isHighlighted, hasAudio, type) {
      restoreOpacity(selector);
      const existingToolbar = document.querySelector('.toolbar');
      if (existingToolbar) {
        existingToolbar.style.opacity = '0';
        setTimeout(() => existingToolbar.remove(), 300);
        if (existingToolbar.getAttribute('data-id') === id) return;
      }

      dimOthers(paragraph, selector);

      const toolbar = document.createElement('div');
      toolbar.classList.add('toolbar');
      toolbar.setAttribute('data-id', id);
      toolbar.style.cssText = \`
        position: absolute;
        top: \${paragraph.getBoundingClientRect().top + window.scrollY - 50}px;
        left: 100px;
        background-color: \${isDark ? '#424242' : '#ffffff'};
        padding: 1px;
        border-radius: 5px;
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
        white-space: nowrap;
        display: flex;
        opacity: 0;
        transition: opacity 0.2s ease;
      \`;

      document.body.appendChild(toolbar);
      setTimeout(() => toolbar.style.opacity = '1', 10);

      let buttons = [];

      if (isHighlighted) {
        buttons = [
          ['&#xE688;', () => {}],
          ['&#xE6DD;', () => removeHighlight(paragraph, selector)],
          ['&#xE652;', () => callHandler('copyText', { text: paragraph.innerText }, selector)],
          ['&#xE67D;', () => callHandler('search', { query: paragraph.innerText }, selector)],
          ['&#xE6A4;', () => callHandler('copyText', { text: paragraph.innerText }, selector)],
        ];
      } 
      else {
        if (type === 'verse') {
          buttons = [
            ['&#xE65C;', () => callHandler('showVerse', { paragraphId: id }, selector)],
            ['&#xE688;', () => callHandler('addNote', { paragraphId: id, isBible: true }, selector)],
            ['&#xE621;', () => callHandler('showOtherTranslations', { paragraphId: id }, selector)],
            ['&#xE62C;', () => callHandler('bookmark', { snippet: paragraph.innerText, paragraphId: id, isBible: true }, selector)],
            ['&#xE652;', () => callHandler('copyText', { text: paragraph.innerText }, selector)],
            ['&#xE67D;', () => callHandler('searchVerse', { query: id }, selector)],
            ['&#xE6BA;', () => callHandler('share', { paragraphId: id, isBible: true }, selector)],
          ];
        } 
        else {
          buttons = [
            ['&#xE688;', () => callHandler('addNote', { paragraphId: id, isBible: false }, selector)],
            ['&#xE62C;', () => callHandler('bookmark', { snippet: paragraph.innerText, paragraphId: id }, selector)],
            ['&#xE6BA;', () => callHandler('share', { paragraphId: id, isBible: false }, selector)],
            ['&#xE652;', () => callHandler('copyText', { text: paragraph.innerText }, selector)],
          ];
        }
      }

      buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));

      if (!isHighlighted && hasAudio) {
        toolbar.appendChild(createToolbarButton('&#xE662;', () => callHandler('playAudio', { paragraphId: id })));
      }
    }

    function callHandler(name, args, selector) {
      window.flutter_inappwebview.callHandler(name, args);
      closeToolbar(selector);
    }
    
    function setupClickEvents(rootElement, selector, idAttr, classFilter) {
      rootElement.querySelectorAll(selector).forEach(elem => {
        elem.addEventListener('click', function(event) {
          let target = event.target;
          let isLink = false;

          while (target && !target.hasAttribute(idAttr)) {
            if (
              target.tagName.toLowerCase() === 'a' ||
              target.classList.contains('fn') || target.classList.contains('m') ||
              target.classList.contains('v')
            ) {
              isLink = true;
              break;
            }
            target = target.parentElement;
          }

          if (target?.classList.contains('gen-field')) {
            isLink = true;
          }

          const id = elem.getAttribute(idAttr);
          const hasAudio = idAttr === 'data-pid' ? audioMarkers.some(m => m.mepsParagraphId === id) : false;

          if (!isLink) {
            showToolbar(elem, id, selector, false, hasAudio, classFilter);
          }
        });
      });
    }

    // Init listeners
    setupClickEvents(pageCenter, '[data-pid]', 'data-pid', 'paragraph');
    setupClickEvents(pageCenter, '.v', 'id', 'verse');
  """;

  await controller.evaluateJavascript(source: script);
}

Future<void> loadJavascriptUserdata(InAppWebViewController controller, Document document, bool isDark) async {
  controller.evaluateJavascript(source: """
    // Ajouter les événements 'input' ou 'change' aux champs input et textarea
    pageCenter.querySelectorAll('input, textarea').forEach((input) => {
      const eventType = input.type === 'checkbox' ? 'change' : 'input';
      input.addEventListener(eventType, () => {
        const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
        window.flutter_inappwebview.callHandler('onInputChange', {
          tag: input.id || '',
          value: value
        });
      });
    });

    // Fonction pour remplir les champs input avec les valeurs existantes
    (function populateInputs() {
      const inputs = [${document.inputFields.map((item) {
    final tag = item['TextTag'];
    final value = item['Value'] ?? '';
    return """{ tag: '$tag', value: `$value` }""";
  }).join(', ')}];

      // Remplir chaque champ input
      inputs.forEach((input) => {
        const element = pageCenter.getElementById(input.tag);
        if (element) {
          if (element.type === 'checkbox') {
            element.checked = input.value === '1';
          } 
          else if (element.tagName === 'TEXTAREA' || element.type === 'text') {
            element.value = input.value;
          }
        }
      });
    })();
    
    function adjustHeight(element) {
      element.style.height = 'auto';
      element.style.height = (element.scrollHeight+4) + 'px';
    }

    // Appliquer l'ajustement de hauteur à tous les textarea
    pageCenter.querySelectorAll('textarea').forEach((textarea) => {
      textarea.addEventListener('input', () => adjustHeight(textarea));  // Ajuster lors de la saisie
      adjustHeight(textarea);
    });
  """);

  controller.evaluateJavascript(source: """
    const bookmarks = ${jsonEncode(document.bookmarks)};

    // Chemin relatif car baseUrl est déjà défini
    const slotAssets = Array.from({ length: 10 }, (_, i) => `images/bookmark\${i}_margin.png`);

    bookmarks.forEach(bookmark => {
        const blockId = bookmark['BlockIdentifier'];
        const element = pageCenter.querySelector(`[data-pid='\${blockId}']`);
        
        if (element) {
            const imgSrc = slotAssets[bookmark.Slot];
            console.log("Loading image:", imgSrc);

            if (!element.parentElement.querySelector('.bookmark-icon')) {
                const img = document.createElement('img');
                img.src = imgSrc;
                img.classList.add('bookmark-icon');
                img.style.position = 'absolute';
                img.style.left = '-13px';
                img.style.top = '5px';
                img.style.width = '9px';
                img.style.height = '18px';

                // Vérifier si l'image charge correctement
                img.onerror = function() {
                    console.error("Image failed to load:", imgSrc);
                };

                element.style.position = 'relative';
                element.parentElement.style.position = 'relative'; 
                element.parentElement.insertBefore(img, element);
            }
        }
    });
""");
}


// SearchVerse
/*
var displayTitle = `${_document['DisplayTitle']}`;
  var chapterNumber = `${_document['ChapterNumber']}`;

  // Utiliser une expression régulière pour extraire le numéro du verset
  var verseNumber = verseId.split('-')[2]; // Prendre le 3ème élément après le split

  window.flutter_inappwebview.callHandler('search', {
    query: displayTitle + ' ' + chapterNumber + ':' + verseNumber
  });

 */