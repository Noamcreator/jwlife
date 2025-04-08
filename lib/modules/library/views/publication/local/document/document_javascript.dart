import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/data/databases/Audio.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';

Future<void> loadJavascriptScrolling(InAppWebViewController controller) async {
  // Ajout de l'événement scrollStart (début du défilement)
  await controller.evaluateJavascript(source: """
  let startX = 0;
  let startY = 0;
  let threshold = 60; // Seuil de mouvement pour considérer comme un swipe

  // Fonction pour détecter le swipe horizontal
  window.addEventListener('touchstart', function(e) {
    // Vérifier si l'élément touché est un tableau ou un élément déplaçable
    let target = e.target;
    if (target.tagName.toLowerCase() === 'table' || target.closest('table')) {
      return; // Ne pas initier un swipe si c'est un tableau
    }

    // On enregistre la position de départ du touché
    const touchStart = e.touches[0];
    startX = touchStart.pageX;
    startY = touchStart.pageY;
  });

  window.addEventListener('touchmove', function(e) {
    // Vérifier à nouveau si l'élément touché est un tableau ou un élément déplaçable
    let target = e.target;
    if (target.tagName.toLowerCase() === 'table' || target.closest('table')) {
      return; // Ne pas initier un swipe si c'est un tableau
    }
    
    // Empêcher le scroll vertical quand il y a un swipe horizontal
    e.preventDefault();
  });

  window.addEventListener('touchend', function(e) {
    // Vérifier si l'élément touché est un tableau ou un élément déplaçable
    let target = e.target;
    if (target.tagName.toLowerCase() === 'table' || target.closest('table')) {
      return; // Ne pas initier un swipe si c'est un tableau
    }

    const touchEnd = e.changedTouches[0];
    const deltaX = touchEnd.pageX - startX; // Mouvement horizontal
    const deltaY = touchEnd.pageY - startY; // Mouvement vertical

    // Si le mouvement horizontal dépasse le seuil, on considère un swipe
    if (Math.abs(deltaX) > threshold && Math.abs(deltaY) < threshold) {
      if (deltaX > 0) {
        // Swipe vers la droite (page précédente)
        window.flutter_inappwebview.callHandler('onChangePageLeft');
      } else {
        // Swipe vers la gauche (page suivante)
        window.flutter_inappwebview.callHandler('onChangePageRight');
      }
    }
  });
  """);
}

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

Future<void> loadJavascriptParagraph(InAppWebViewController controller, List<Audio> audios, Document document, bool isDark) async {
  String audioMarkersJson = '[]';  // Valeur par défaut (si aucun audio n'est trouvé)
  if (audios.isNotEmpty) {
    Audio? audio = audios.firstWhereOrNull((audio) => audio.documentId == document.mepsDocumentId);
    if (audio != null) {
      if (audio.markers.isNotEmpty) {
        audioMarkersJson = jsonEncode(audio.markers.map((marker) => marker.toJson()).toList());
      }
    }
  }

  await controller.evaluateJavascript(source: """
  // Fonction pour restaurer la couleur normale des paragraphes
  function restoreParagraphColors() {
    document.querySelectorAll('[data-pid]').forEach((p) => {
      p.style.opacity = '1';
    });
  }

  document.querySelectorAll('[data-pid]').forEach((paragraph) => {
    paragraph.addEventListener('click', function(event) {
      let isBible = false;
      let paragraphId = paragraph.getAttribute('data-pid'); // Initialiser avec l'ID du paragraphe parent
      let isLink = false;
    
      // Remonter l'arbre DOM jusqu'à ce qu'on trouve un élément avec data-pid
      let targetElement = event.target;
      while (targetElement && !targetElement.hasAttribute('data-pid')) {
        if (targetElement.tagName.toLowerCase() === 'a' || targetElement.classList.contains('fn')) {
            isLink = true;
            break;
        }
        targetElement = targetElement.parentElement;
      }
      
      // Vérifier si le paragraphe a un audio associé
      let hasAudio = JSON.parse('$audioMarkersJson').some((marker) => marker['mepsParagraphId'] == paragraphId);
      
      // Appeler la fonction Flutter showToolbar (en utilisant une méthode spécifique à Flutter pour passer l'événement)
      if (typeof showToolbar !== 'undefined' && !isLink) {
        showToolbar(targetElement, event.target, hasAudio, false, isBible);
      }
    });
  });
""");

  await controller.evaluateJavascript(source: """
  const isDark = $isDark;
  // Fonction utilitaire pour créer des boutons
  function createToolbarButton(innerHTML, onClick) {
    var button = document.createElement('button');
    button.innerHTML = innerHTML;
    button.style.fontFamily = 'jw-icons-external'; // Utilisation de la police des icônes
    button.style.fontSize = '26px'; // Taille de la police
    button.style.padding = '3px'; // Espacement interne
    button.style.borderRadius = '5px'; // Bordure arrondie
    button.style.margin = '0 7px'; // Espacement horizontal
    button.style.color = isDark ? 'white' : '#4f4f4f'; // Couleur du texte
    button.addEventListener('click', onClick); // Ajouter l'événement au clic
    return button; // Retourner le bouton créé
  }

  // Fonction pour afficher la barre d'outils principale avec effet fade
function showToolbar(paragraph, clickedElement, hasAudio, isHighlighted, isBible) {
  var paragraphId = paragraph.getAttribute('data-pid'); // Récupérer l'ID du paragraphe

  restoreParagraphColors();

  var existingToolbar = document.querySelector('.toolbar');
  if (existingToolbar) {
    // Si la barre d'outils existe déjà, la supprimer avec un effet fade-out
    existingToolbar.style.opacity = '0'; // Démarrer le fade-out
    setTimeout(function() {
      existingToolbar.remove(); // Supprimer après le fade-out
    }, 300); // Délai pour laisser l'animation se jouer
    if (existingToolbar.getAttribute('data-pid') === paragraphId) {
      return;
    }
  }

  if (clickedElement.tagName.toLowerCase() === 'a' || clickedElement.hasAttribute('href')) {
    return;
  }

  if (!existingToolbar) {
    // Griser les autres paragraphes
    document.querySelectorAll('[data-pid]').forEach((p) => {
      if (p !== paragraph) {
        p.style.opacity = '0.5';
      }
    });

    // Créer la barre d'outils
    var toolbar = document.createElement('div');
    toolbar.classList.add('toolbar');
    toolbar.style.position = 'absolute';
    toolbar.style.top = (paragraph.getBoundingClientRect().top + window.scrollY - 50) + 'px';
    toolbar.style.left = 100 + 'px';
    toolbar.style.backgroundColor = isDark ? '#424242' : '#ffffff';  // Fond sombre
    toolbar.style.padding = '1px';
    toolbar.style.borderRadius = '5px';
    toolbar.style.boxShadow = '0 2px 10px rgba(0, 0, 0, 0.3)';
    toolbar.style.whiteSpace = 'nowrap'; // Éviter que les boutons passent à la ligne
    toolbar.style.display = 'flex'; // Afficher les boutons en ligne
    toolbar.style.opacity = '0'; // Initialiser l'opacité à 0 pour commencer le fade-in
    toolbar.style.transition = 'opacity 0.2s ease'; // Transition de fade-in
    toolbar.setAttribute('data-pid', paragraphId);

    // Ajouter la barre avant de calculer la largeur
    document.body.appendChild(toolbar);

    // Délai pour démarrer le fade-in
    setTimeout(function() {
      toolbar.style.opacity = '1'; // Définir l'opacité à 1 pour afficher la barre
    }, 10); // Petit délai pour que le style d'opacité initial soit pris en compte

    if (!isHighlighted) {
      // Créer les boutons avec la fonction utilitaire
      var addNoteButton = createToolbarButton('&#xE688;', function() {
        addNote(paragraph, paragraphId);
      });

      var bookmarkButton = createToolbarButton('&#xE62C;', function() {
        addBookmark(paragraph, paragraphId);
      });

      var shareButton = createToolbarButton('&#xE6BA;', function() {
        shareText(paragraph, paragraphId);
      });

      var copyButton = createToolbarButton('&#xE652;', function() {
        copyText(paragraph);
      });

      toolbar.appendChild(addNoteButton);
      toolbar.appendChild(bookmarkButton);
      toolbar.appendChild(shareButton);
      toolbar.appendChild(copyButton);

      if (isBible) {
        var searchButton = createToolbarButton('&#xE67D;', function() {
          var verseId = paragraph.getAttribute('id');
          searchVerse(verseId);
        });
        toolbar.appendChild(searchButton);
      }

      if (hasAudio) {
        var listenButton = createToolbarButton('&#xE662;', function() {
            listenToText(paragraph, paragraphId);
        });
        toolbar.appendChild(listenButton);
      }
    } else {
      // Créer les boutons pour la section "highlighted"
      var addNoteButton = createToolbarButton('&#xE688;', function() {});
    
      var removeButton = createToolbarButton('&#xE6DD;', function() {
        removeHighlight(paragraph);
      });

      var copyButton = createToolbarButton('&#xE652;', function() {
        copyText(paragraph);
      });

      var searchButton = createToolbarButton('&#xE67D;', function() {
        searchText(paragraph);
      });

      var referenceButton = createToolbarButton('&#xE6A4;', function() {
        copyText(paragraph);
      });

      toolbar.appendChild(addNoteButton);
      toolbar.appendChild(removeButton);
      toolbar.appendChild(copyButton);
      toolbar.appendChild(searchButton);
      toolbar.appendChild(referenceButton);
    }
  }
}

// Fonction pour fermer la barre d'outils
function closeToolbar() {
  restoreParagraphColors();
  var toolbar = document.querySelector('.toolbar');
  if (toolbar) {
    toolbar.remove();
  }
}

// Fonction pour supprimer le surlignage
function removeHighlight(spanElement) {
  spanElement.classList.remove('highlight-yellow');  // Retirer la classe de surlignage
  closeToolbar(); // Fermer la barre d'outils après suppression du surlignage
}

// Fonction pour partager le texte
function addNote(paragraph, paragraphId) {
  window.flutter_inappwebview.callHandler('addNote', {
    paragraphId: paragraphId,  // Passer paragraphId à Flutter
  });

  closeToolbar(); // Fermer la barre d'outils après l'ajout de la note
}

// Fonction pour ajouter un favori
function addBookmark(paragraph, paragraphId) {
  window.flutter_inappwebview.callHandler('bookmark', {
    snippet: paragraph.innerText,
    paragraphId: paragraphId,  // Passer paragraphId à Flutter
  });

  closeToolbar(); // Fermer la barre d'outils après l'ajout du favori
}

// Fonction pour partager le texte
function shareText(paragraph, paragraphId) {
  window.flutter_inappwebview.callHandler('share', {
    paragraphId: paragraphId,  // Passer paragraphId à Flutter
  });

  closeToolbar(); // Fermer la barre d'outils après le partage
}

// Fonction pour copier le texte
function copyText(paragraph) {
  window.flutter_inappwebview.callHandler('copyText', {
    text: paragraph.innerText
  });

  closeToolbar(); // Fermer la barre d'outils après la copie
}

// Fonction pour écouter le texte
function listenToText(paragraph, paragraphId) {
  window.flutter_inappwebview.callHandler('playAudio', {
    paragraphId: paragraphId
  });

  closeToolbar(); // Fermer la barre d'outils après l'écoute
}

// Fonction pour ajouter un favori
function searchText(paragraph) {
  window.flutter_inappwebview.callHandler('search', {
    query: paragraph.innerText
  });

  closeToolbar(); // Fermer la barre d'outils après la recherche
}

// Fonction pour ajouter un favori
function searchVerse(verseId) {
  closeToolbar(); // Fermer la barre d'outils après la recherche de verset
}
""");
}

Future<void> loadJavascriptUserdata(InAppWebViewController controller, Document document, bool isDark) async {
  await controller.evaluateJavascript(source: """
    // Ajouter les événements 'input' ou 'change' aux champs input et textarea
    document.querySelectorAll('input, textarea').forEach((input) => {
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
        const element = document.getElementById(input.tag);
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
    document.querySelectorAll('textarea').forEach((textarea) => {
      textarea.addEventListener('input', () => adjustHeight(textarea));  // Ajuster lors de la saisie
      adjustHeight(textarea);
    });
  """);

  await controller.evaluateJavascript(source: """
    const bookmarks = ${jsonEncode(document.bookmarks)};

    // Chemin relatif car baseUrl est déjà défini
    const slotAssets = Array.from({ length: 10 }, (_, i) => `images/bookmark\${i}_margin.png`);

    bookmarks.forEach(bookmark => {
        const blockId = bookmark['BlockIdentifier'];
        const element = document.querySelector(`[data-pid='\${blockId}']`);
        
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