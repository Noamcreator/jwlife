// highlight.js
document.body.style.userSelect = 'text';

let toolbar;
let selection;
let longPressTimer;

// Détection d'un appui long
document.addEventListener('mousedown', (e) => {
  longPressTimer = setTimeout(() => {
    selection = window.getSelection();
    if (selection && selection.toString()) {
      createToolbar(e);
    }
  }, 1000); // 1 seconde pour la détection d'appui long
});

document.addEventListener('mouseup', () => {
  clearTimeout(longPressTimer);
});

// Fonction pour créer la barre d'outils
function createToolbar(e) {
  if (!toolbar) {
    toolbar = document.createElement('div');
    toolbar.style.position = 'absolute';
    toolbar.style.display = 'flex';
    toolbar.style.backgroundColor = '#333';
    toolbar.style.color = '#fff';
    toolbar.style.padding = '10px';
    toolbar.style.borderRadius = '5px';
    toolbar.style.boxShadow = '0 0 10px rgba(0, 0, 0, 0.5)';
    toolbar.innerHTML = `
      <button id="highlight" style="background-color: yellow; border: none; cursor: pointer;">Highlight</button>
      <button id="close" style="border: none; cursor: pointer;">Close</button>
    `;
    document.body.appendChild(toolbar);

    document.getElementById('highlight').addEventListener('click', () => {
      if (selection && selection.toString().length > 0) {
        const range = selection.getRangeAt(0);
        const span = document.createElement('span');
        span.style.backgroundColor = 'yellow';
        range.surroundContents(span);  // Surligner le texte sélectionné
      }
      hideToolbar();
    });

    document.getElementById('close').addEventListener('click', () => {
      hideToolbar();
    });
  }

  // Obtenir les coordonnées de la sélection
  const rect = selection.getRangeAt(0).getBoundingClientRect();
  toolbar.style.left = `${rect.left}px`;
  toolbar.style.top = `${rect.top - toolbar.offsetHeight - 5}px`;
  toolbar.style.display = 'flex';
  document.body.style.overflow = 'hidden'; // Désactiver le défilement pendant la sélection
}

// Fonction pour masquer la barre d'outils
function hideToolbar() {
  if (toolbar) {
    toolbar.style.display = 'none';
  }
  document.body.style.overflow = 'auto'; // Réactiver le défilement
}

// Prévenir le défilement pendant la sélection
document.addEventListener('touchmove', (e) => {
  if (toolbar && toolbar.style.display === 'flex') {
    e.preventDefault();
  }
});
