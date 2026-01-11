let currentIndex = {{CURRENT_INDEX}};
const maxIndex = {{MAX_INDEX}};

const isDebugMode = {{IS_DEBUG_MODE}};

let isDark = {{IS_DARK}};
let lightPrimaryColor = '{{LIGHT_PRIMARY_COLOR}}';
let darkPrimaryColor = '{{DARK_PRIMARY_COLOR}}';

let isFullscreenMode = {{IS_FULLSCREEN}};
let isReadingMode = {{IS_READING_MODE}};
let isBlockingHorizontallyMode = {{IS_BLOCKING}};
let controlsVisible = true;
let audioPlayerVisible = {{AUDIO_VISIBLE}};

const startParagraphId = {{START_PARAGRAPH_ID}};
const endParagraphId = {{END_PARAGRAPH_ID}};
const startVerseId = {{START_VERSE_ID}};
const endVerseId = {{END_VERSE_ID}};
const bookNumber = {{BOOK_NUMBER}};
const chapterNumber = {{CHAPTER_NUMBER}};
const lastBookNumber = {{LAST_BOOK_NUMBER}};
const lastChapterNumber = {{LAST_CHAPTER_NUMBER}};
const textTag = '{{TEXT_TAG}}';
const wordsSelected = {{WORDS_SELECTED}};

const isRtl = {{IS_RTL}};

const container = document.getElementById("container");
const pageCenter = document.getElementById("page-center");
const pageLeft = document.getElementById("page-left");
const pageRight = document.getElementById("page-right");

const magnifierWrapper = document.getElementById('magnifier-wrapper');
const magnifierContent = document.getElementById('magnifier-content');

let imageMode = false;

let cachedPages = {};
let scrollTopPages = {};

let isChangingParagraph = false;

let bookmarkAssets = Array.from({length: 10}, (_, i) => `bookmarks/${isDark ? 'dark' : 'light'}/bookmark${i + 1}.png`);

const handleLeft = `images/handle_left.png`;
const handleRight = `images/handle_right.png`;

const speedBarScroll = `images/speedbar_thumb_regular.png`;
let scrollBar = null;

// Valeurs fixes de hauteur des barres
const APPBAR_FIXED_HEIGHT = 56;
const BOTTOMNAVBAR_FIXED_HEIGHT = {{BOTTOM_NAVBAR_HEIGHT}};
const AUDIO_PLAYER_HEIGHT = 80;

let paragraphsData = new Map();
let paragraphsDataDialog = new Map();

const colorsList = ['gray', 'yellow', 'green', 'blue', 'pink', 'orange', 'purple', 'red', 'brown'];

const STYLE = {
    highlight: {
        styleName: 'highlight',
        icon: '&#xE6DC',
        classes: [
            'highlight-gray', 'highlight-yellow', 'highlight-green',
            'highlight-blue', 'highlight-pink', 'highlight-orange', 'highlight-purple', 'highlight-red', 'highlight-brown'
        ],
        options: colorsList,
        colorIndex: {{COLOR_INDEX}}
    },
    underline: {
        styleName: 'underline',
        icon: '&#xE6DD',
        classes: [
            'underline-gray', 'underline-yellow', 'underline-green',
            'underline-blue', 'underline-pink', 'underline-orange', 'underline-purple', 'underline-red', 'underline-brown'
        ],
        options: colorsList,
        colorIndex: {{COLOR_INDEX}}
    },
    text: {
        styleName: 'text',
        icon: '&#xE6DE',
        classes: [
            'text-gray', 'text-yellow', 'text-green', // Changé de 'border-couleur' à 'text-couleur'
            'text-blue', 'text-pink', 'text-orange', 'text-purple', 'text-red', 'text-brown'
        ],
        options: colorsList,
        colorIndex: {{COLOR_INDEX}}
    }
};

const blockRangeAttr = 'block-range-id';
const noteAttr = 'note-id';

const noteBlockRangeAttr = 'note-block-range-id';
const noteBlockIdAttr = 'note-block-id';
const notePubClassAttr = 'note-pub-class';
const noteMlClassAttr = 'note-ml-class';
const noteDocIdClassAttr = 'note-doc-id-class';

let currentStyleIndex = {{STYLE_INDEX}};

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
        const currentNote = document.querySelector(`[${noteAttr}="${note.Guid}"]`);
        if (currentNote) {
            updateNoteUI(note, true); // silent = true
        } else {
            const paragraphInfo = paragraphsDataDialog.get(note.BlockIdentifier);
            const isBible = isBible();

            addNoteWithGuid(pageCenter, paragraphInfo.paragraphs[0], null, note.Guid, 0, isBible, true);
        }
    });
}

function generateGuid() {
    return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
        (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
    );
}

function changeTheme(isDarkMode) {
    isDark = isDarkMode;
    document.body.classList.remove('cc-theme--dark', 'cc-theme--light');
    document.body.classList.add(isDarkMode ? 'cc-theme--dark' : 'cc-theme--light');

    // changer la couleur du logo dans le bouton flottant
    const floatingButton = document.getElementById('dialogFloatingButton');
    floatingButton.style.color = isDarkMode ? '#333333' : '#ffffff';

    bookmarkAssets = Array.from({length: 10}, (_, i) => `bookmarks/${isDarkMode ? 'dark' : 'light'}/bookmark${i + 1}.png`);
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
    floatingButton.style.bottom = `${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 15}px`;

    const curr = cachedPages[currentIndex];
    const prev = cachedPages[currentIndex - 1];
    const next = cachedPages[currentIndex + 1];

    adjustArticle('article-center', curr.link);
    adjustArticle('article-left', prev.link);
    adjustArticle('article-right', next.link);
}

async function fetchPage(index) {
    if (cachedPages[index]) return cachedPages[index];
    const page = await window.flutter_inappwebview.callHandler('getPage', index);
    cachedPages[index] = page;
    return page;
}

function loadImageSvg(pageElement, svgPaths) {
    const colorBackground = isDarkTheme() ? '#202020' : '#ecebe7';

    const existingContainer = pageElement.querySelector('.svg-wrapper-container');
    if (existingContainer) {
        existingContainer.remove();
    }

    pageElement.innerHTML = '';

    const svgContainer = document.createElement('div');
    svgContainer.className = 'svg-wrapper-container';
    Object.assign(svgContainer.style, {
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100%',
        width: '100%',
        backgroundColor: colorBackground,
        boxSizing: 'border-box',
        overflow: 'hidden',
        padding: `${APPBAR_FIXED_HEIGHT + 5}px 5px ${BOTTOMNAVBAR_FIXED_HEIGHT + 5}px 5px`
    });

    const innerBox = document.createElement('div');
    innerBox.className = 'zoomable-content';
    innerBox.dataset.scale = '1';
    innerBox.dataset.translateX = '0';
    innerBox.dataset.translateY = '0';
    
    Object.assign(innerBox.style, {
        backgroundColor: '#ffffff',
        width: '100%',
        height: 'auto',
        boxShadow: '0 4px 10px rgba(0,0,0,0.2)',
        lineHeight: '0',
        display: 'flex',
        flexDirection: 'column',
        transition: 'none',
        touchAction: 'pan-y',
        transformOrigin: 'center top',
        willChange: 'transform, width'
    });

    const pathsArray = typeof svgPaths === 'string' ? svgPaths.split(',') : svgPaths;

    pathsArray.forEach(path => {
        if (path.trim() === "") return;
        const svgImage = document.createElement('img');
        svgImage.src = 'file://' + path;
        Object.assign(svgImage.style, {
            width: '100%',
            height: 'auto',
            display: 'block',
            objectFit: 'contain',
            pointerEvents: 'none',
            userSelect: 'none'
        });
        innerBox.appendChild(svgImage);
    });

    svgContainer.appendChild(innerBox);
    pageElement.appendChild(svgContainer);
}

async function switchImageMode(mode) {
    imageMode = mode;
    const curr = cachedPages[currentIndex];
    const prev = cachedPages[currentIndex - 1];
    const next = cachedPages[currentIndex + 1];

    async function renderPage(page, item, position) {
        if (!item) return; // Sécurité si la page n'existe pas

        const isImageMode = item.preferredPresentation === 'text' ? imageMode : !imageMode;

        if (isImageMode && item.svgs && item.svgs.length > 0) {
            page.innerHTML = "";
            removeFloatingButton();
            loadImageSvg(page, item.svgs); // item.svgs peut être [path1, path2]
        }
        else {
            page.innerHTML = `<article id="article-${position}" class="${item.className}">${item.html}</article>`;
            adjustArticle(`article-${position}`, item.link);
            addVideoCover(`article-${position}`);

            if(position === "center") {
                showFloatingButton();

                const article = document.getElementById("article-center");
                wrapWordsWithSpan(article, isBible());
                paragraphsData = fetchAllParagraphsOfTheArticle(article);
                await loadUserdata();
                initializeBaseDialog();
            }
        }
    }

    // On réinitialise l'affichage pour les 3 conteneurs
    await renderPage(pageCenter, curr, "center");
    renderPage(pageLeft, prev, "left");
    renderPage(pageRight, next, "right");

    // Reset visuel du container
    container.style.transition = "none";
    container.style.transform = "translateX(-100%)";
    void container.offsetWidth; // Force le reflow
}

// Gestion de l'affichage des furigana (Prononciation)
function switchPronunciationGuideMode(mode) {
    const article = document.getElementById('article-center');
    const articleLeft = document.getElementById('article-left');
    const articleRight = document.getElementById('article-right');

    [article, articleLeft, articleRight].forEach(el => {
        if (!el) return; // ignore si l'élément n'existe pas
        if (mode) {
            el.classList.add("showRuby");
        } else {
            el.classList.remove("showRuby");
        }
    });

    for (let i = 0; i < cachedPages.length; i++) {
        let classes = cachedPages[i].className.split(' ').filter(c => c !== 'showRuby');
        if (mode) {
            // Ajoute showRuby uniquement si elle n'existe pas déjà
            classes.push('showRuby');
        }
        // Si mode === false, showRuby a déjà été retiré par filter
        cachedPages[i].className = classes.join(' ');
    }
}

function adjustArticle(articleId, link) {
    const article = document.getElementById(articleId);
    if (!article) return;

    const header = article.querySelector('header');
    const firstImage = article.querySelector('div#f1.north_center');
    // Par défaut, on ajoute 20px de marge en plus de la hauteur de l'appbar
    let paddingTop = `${APPBAR_FIXED_HEIGHT + 20}px`;

    // Si la première image se trouve DANS le header, on enlève les 20px
    if (firstImage && article.contains(firstImage)) {
        paddingTop = `${APPBAR_FIXED_HEIGHT}px`;
    }

    const hasLink = article.querySelector('a.publication-link');
    if (link !== '' && !hasLink) {
        // Création du lien
        const linkElement = document.createElement('a');
        linkElement.className = 'publication-link';
        linkElement.href = link;
        linkElement.textContent = "{{PUBLICATION_SHORT_TITLE}}";

        // Style du lien en bleu
        linkElement.style.fontSize = '1.3em';
        linkElement.style.marginTop = '10px'; // un petit espace au dessus du lien

        // Insérer le lien juste après l'article
        article.insertAdjacentElement('beforeend', linkElement);

        article.style.paddingTop = `${APPBAR_FIXED_HEIGHT}px`;
        article.style.paddingBottom = `${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 30}px`;
    } 
    else {
        article.style.paddingTop = paddingTop;
        article.style.paddingBottom = `${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 30}px`;
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
            <div class="slick-slide cc-flipbookGallery-slide ${index === 0 ? 'slick-current slick-active' : ''}"
                 data-slick-index="${index}"
                 aria-hidden="${index === 0 ? 'false' : 'true'}"
                 role="tabpanel"
                 id="slick-slide0${index}"
                 aria-describedby="slick-slide-control0${index}"
                 style="display: ${index === 0 ? 'block' : 'none'}; transition: opacity 800ms;">
              <div>
                <img class="gen-flipbook" src="${src}" alt="${alt}" width="${width}" height="${height}" style="width: 100%; display: inline-block;">
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
                ${slickSlides}
              </div>
            </div>
            <div class="cc-flipbookGallery-navigation-next slick-arrow" style="cursor:pointer;">
              <svg class="svg-inline--fa jwi-chevron-right fa-w-16" focusable="false" aria-hidden="true" data-prefix="jwf-jw-icons-external" data-icon="chevron-right" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M8.5 19a.5.5 0 01-.39-.18.52.52 0 01.07-.71L15.71 12 8.18 5.89a.5.5 0 01.64-.78l8 6.5a.51.51 0 010 .78l-8 6.5a.56.56 0 01-.32.11z"></path></svg>
            </div>
            <ul class="cc-flipbookGallery-navigation-dots" role="tablist">
              ${imgs.map((_, i) => `
      <li class="${i === 0 ? 'slick-active' : ''}" role="presentation">
      <button type="button" role="tab" id="slick-slide-control0${i}" aria-controls="slick-slide0${i}" aria-label="${i + 1} of ${imgs.length}" tabindex="${i === 0 ? 0 : -1}" ${i === 0 ? 'aria-selected="true"' : ''}>${i + 1}</button>
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
            const imagePath = `{{PUBLICATION_PATH}}/${imageName}`;
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

// ============= OPTIMISATIONS PRINCIPALES =============

const skipClasses = new Set(["fn", "m", "cl", "vl", "dc-button--primary", "gen-field", "parNum", "word", "escape", "punctuation"]);

function wrapWordsWithSpan(article, isBible) {
    const selector = isBible ? '.v' : '[data-pid]';
    const paragraphs = article.querySelectorAll(selector);
    for (let i = 0; i < paragraphs.length; i++) {
        processTextNodes(paragraphs[i]);
    }
}

function processTextNodes(element) {
    const isSkipped = [...skipClasses].some(className => 
        element.closest(`.${className}`)
    );

    if (!element || isSkipped) {
        return;
    }

    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, {
        acceptNode: (node) => {
            let parent = node.parentElement;
            while (parent && parent !== element) {
                if (parent.tagName.toLowerCase() === 'sup' || parent.tagName.toLowerCase() === 'rt') {
                    return NodeFilter.FILTER_REJECT;
                }
                if (parent.classList && [...parent.classList].some(c => skipClasses.has(c))) {
                    return NodeFilter.FILTER_REJECT;
                }
                parent = parent.parentElement;
            }
            return NodeFilter.FILTER_ACCEPT;
        }
    });

    const nodes = [];
    let currentNode;
    while (currentNode = walker.nextNode()) nodes.push(currentNode);

    const combinedRegex = /[\p{L}\p{N}]+(?:[^\p{L}\p{N}\s][\p{L}\p{N}]+)*|\s+|[^\p{L}\p{N}\s]/gu;

    for (let i = 0; i < nodes.length; i++) {
        const node = nodes[i];
        const text = node.textContent;
        const fragment = document.createDocumentFragment();
        
        let match;
        while ((match = combinedRegex.exec(text)) !== null) {
            const token = match[0];
            const span = document.createElement('span');
            
            if (/[\p{L}\p{N}]/u.test(token)) {
                span.className = 'word';
            } else if (/\s+/.test(token)) {
                span.className = 'escape';
            } else {
                span.className = 'punctuation';
            }
            
            span.textContent = token;
            fragment.appendChild(span);
        }
        
        node.parentNode.replaceChild(fragment, node);
    }
}

async function loadIndexPage(index) {
    const curr = await fetchPage(index);
    const isImageMode = curr.preferredPresentation === 'text' ? imageMode : !imageMode;
  
    if (isImageMode && curr.svgs && curr.svgs.length > 0) {
        loadImageSvg(pageCenter, curr.svgs);
        await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
    } 
    else {
        showFloatingButton();
        pageCenter.innerHTML = `<article id="article-center" class="${curr.className}">${curr.html}</article>`;
        adjustArticle('article-center', curr.link);
        addVideoCover('article-center');

        const article = document.getElementById("article-center");
        wrapWordsWithSpan(article, isBible());
        paragraphsData = fetchAllParagraphsOfTheArticle(article);
        await window.flutter_inappwebview.callHandler('changePageAt', currentIndex);
        await loadUserdata();
    }

    container.style.transition = "none";
    container.style.transform = "translateX(-100%)";
    void container.offsetWidth;
    container.style.transition = "transform 0.25s ease-in-out";
}

async function loadPrevAndNextPages(index) {
    const [prev, next] = await Promise.all([
        fetchPage(index - 1),
        fetchPage(index + 1)
    ]);
    
    const isImageModePrev = prev.preferredPresentation === 'text' ? imageMode : !imageMode;
    const isImageModeNext = next.preferredPresentation === 'text' ? imageMode : !imageMode;

    // Remplissage Page Gauche (pageLeft)
    if (isImageModePrev && prev.svgs && prev.svgs.length > 0) {
        loadImageSvg(pageLeft, prev.svgs);
    } 
    else {
        pageLeft.innerHTML = `<article id="article-left" class="${prev.className}">${prev.html}</article>`;
        adjustArticle('article-left', prev.link);
        addVideoCover('article-left');
        resizeAllTextAreaHeight(pageLeft);
    }

    // Remplissage Page Droite (pageRight)
    if (isImageModeNext && next.svgs && next.svgs.length > 0) {
        loadImageSvg(pageRight, next.svgs);
    } 
    else {
        pageRight.innerHTML = `<article id="article-right" class="${next.className}">${next.html}</article>`;
        adjustArticle('article-right', next.link);
        addVideoCover('article-right');
        resizeAllTextAreaHeight(pageRight);
    }
}

function restoreScrollPosition(page, index) {
    if (!page) return;

    // Récupération de la position sauvegardée pour cet index précis
    const scroll = scrollTopPages[index] ?? 0;
    
    // Application immédiate pour éviter les sauts visuels
    page.scrollTop = scroll;

    // Sécurité : Force la position au prochain cycle de rendu au cas où le contenu 
    // HTML vient juste d'être injecté et n'a pas encore sa hauteur finale.
    requestAnimationFrame(() => {
        if (page && page.scrollTop !== scroll) {
            page.scrollTop = scroll;
        }
    });

    // Réinitialisation des états de direction (évite que l'AppBar ne s'affole)
    lastScrollTop = 0;
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

async function loadPages(currentIndex) {
    // Verrouillage pour empêcher le listener de scroll d'écrire n'importe où
    isNavigating = true;

    // 1. Charger la page centrale
    await loadIndexPage(currentIndex);

    // 2. Reset des états d'interaction
    pageCenter.scrollLeft = 0;
    currentGuid = '';
    isLongPressing = false;
    isVerticalScroll = false;
    currentTranslate = -100;
    controlsVisible = true;

    // 3. Restaurer le scroll du centre (uniquement si déjà connu)
    restoreScrollPosition(pageCenter, currentIndex);

    initializeBaseDialog();

    // 4. Charger les voisins
    await loadPrevAndNextPages(currentIndex);

    // 5. Restaurer les scrolls des voisins seulement s'ils ont été enregistrés
    if (scrollTopPages[currentIndex - 1] !== undefined) {
        restoreScrollPosition(pageLeft, currentIndex - 1);
    } else {
        pageLeft.scrollTop = 0; // Force le haut de page si inconnu
    }

    if (scrollTopPages[currentIndex + 1] !== undefined) {
        restoreScrollPosition(pageRight, currentIndex + 1);
    } else {
        pageRight.scrollTop = 0; // Force le haut de page si inconnu
    }

    // 6. Déverrouillage après stabilisation du DOM
    setTimeout(() => {
        isNavigating = false;
    }, 150);
}

async function init() {
    pageCenter.scrollTop = 0;
    pageCenter.scrollLeft = 0;

    setupScrollBar();

    pageCenter.classList.add('visible');
    await loadIndexPage(currentIndex);

    showScrollBar(true);

    if (wordsSelected.length > 0) {
        selectWords(wordsSelected, false);
    }

    if (startParagraphId != null && endParagraphId != null) {
        jumpToBlockId(pageCenter.id, startParagraphId, endParagraphId);
    } 
    else if (startVerseId != null && endVerseId != null) {
        const hasSameChapter = (bookNumber === lastBookNumber && chapterNumber === lastChapterNumber) || lastBookNumber === null || lastChapterNumber === null;
        const endIdForJump = hasSameChapter ? endVerseId : null;
        console.log('startVerseId', startVerseId);
        console.log('endVerseId', endIdForJump);
        jumpToBlockId(pageCenter.id, startVerseId, endIdForJump);
    } 
    else if (textTag != null) {
        jumpToTextTag(textTag);
    }

    await loadPrevAndNextPages(currentIndex);
}

init();

async function jumpToPage(index, startBlockId, endBlockId, articleId) {
    closeToolbar();
    if (index < 0 || index > maxIndex) return;

    currentIndex = index;
    await loadPages(index);

    if (startBlockId !== null && endBlockId !== null) {
        jumpToBlockId(articleId, startBlockId, endBlockId);
    }
}

async function jumpToBlockId(articleId, begin, end) {
    closeToolbar();

    const selector = isBible() ? '.v' : '[data-pid]';
    const idAttr = isBible() ? 'id' : 'data-pid';

    const paragraphsDataTemp = articleId === 'page-center' ? paragraphsData : paragraphsDataDialog;

    const paragraphs = Array.from(paragraphsDataTemp.values()).flatMap(item => item.paragraphs);
    if (paragraphs.length === 0) {
        console.error(`No paragraphs found for selector: ${selector}`);
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
        effectiveEnd = maxParagraphId;
    }

    // Original check for full document visibility (begin === -1 && end === -1)
    if (begin === -1 && end === -1) {
        paragraphs.forEach(p => {
            p.style.opacity = '1';
        });
        return;
    }

    let targetParagraph = null;
    let firstParagraphId = null;

    // Stockage des IDs pour Flutter
    const selectedIds = [];

    paragraphs.forEach(p => {
        const id = getParagraphId(p, selector, idAttr);
        if (id === null) return;

        if (firstParagraphId === null) {
            firstParagraphId = id;
        }

        // Use effectiveEnd for the comparison
        if (id >= begin && id <= effectiveEnd && !targetParagraph) {
            targetParagraph = p;
        }

        p.style.opacity = (id >= begin && id <= effectiveEnd) ? '1' : '0.5';
    });

    // --- Récupérer les id correspondant à begin → effectiveEnd ---
    paragraphsDataTemp.forEach(data => {
        const hasElement = data.paragraphs.some(p => {
            const id = getParagraphId(p, selector, idAttr);
            return id !== null && id >= begin && id <= effectiveEnd;
        });

        if (hasElement) {
            selectedIds.push(data.id);
        }
    });

    // --- ENVOI À FLUTTER ---
    if(isBible()) {
        window.window.flutter_inappwebview.callHandler('verseClickNumber', selectedIds);
    }

    // --- Scroll & centrage ---
    if (targetParagraph) {
        isChangingParagraph = true;

        const visibleParagraphs = paragraphs.filter(p => p.style.opacity === '1');

        if (visibleParagraphs.length === 0) {
            isChangingParagraph = false;
            return;
        }

        const firstTop = visibleParagraphs[0].offsetTop;
        const lastParagraph = visibleParagraphs[visibleParagraphs.length - 1];
        const lastBottom = lastParagraph.offsetTop + lastParagraph.offsetHeight;
        const totalHeight = lastBottom - firstTop;

        const article = articleId === 'page-center' ? pageCenter : getCurrentDialogContainer();
        const screenHeight = article.clientHeight;
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
        article.scrollTop = scrollToY;

        await new Promise(requestAnimationFrame);
        isChangingParagraph = false;
    }
}

async function jumpToTextTag(textarea) {
    closeToolbar();

    if (!textarea) {
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
    const wordElements = getAllWords();

    const normalizedSearchWords = words.map(w => w.toLowerCase());

    let firstMatchedElement = null;

    // Ajouter la classe 'searched' aux éléments correspondants
    wordElements.forEach(element => {
        let wordText = element.textContent.trim().toLowerCase();

        if (wordText.includes("'")) {
            wordText = wordText.split("'")[1];
        }
        if (wordText.includes("’")) {
            wordText = wordText.split("’")[1];
        }

        const isMatch = normalizedSearchWords.some(searchWord => wordText === searchWord.toLowerCase());

        if (isMatch) {
            element.classList.add('searched');
            if (!firstMatchedElement) {
                firstMatchedElement = element;
            }
        }
    });

    // Si demandé, faire défiler jusqu'au premier mot trouvé
    if (jumpToWord && firstMatchedElement) {
        firstMatchedElement.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
        });
    }
}

// Détecte si la page actuelle (pageCenter) est un chapitre biblique ou un document
function isBible() {
    return cachedPages[currentIndex]['isBibleChapter'];
}

function restoreOpacity(article) {
    const elements = article == pageCenter ? Array.from(paragraphsData.values()).flatMap(item => item.paragraphs) : Array.from(paragraphsDataDialog.values()).flatMap(item => item.paragraphs);

    if(isBible()) {
        window.window.flutter_inappwebview.callHandler('verseClickNumber', null);
    }

    // Déconnecter temporairement (optionnel)
    requestAnimationFrame(() => {
        elements.forEach(e => {
            e.style.opacity = '1';
        });
    });
}

function dimOthers(article, paragraphs) {
    const paragraphsDataTemp = article === pageCenter ? paragraphsData : paragraphsDataDialog;
    // Convertir currents en tableau, si ce n'est pas déjà un tableau
    const paragraphsArray = Array.isArray(paragraphs) ? paragraphs : Array.from(paragraphs);

    const allParagraphElements = Array.from(paragraphsDataTemp.values()).flatMap(item => item.paragraphs);
    // Diminuer l'opacité des autres paragraphes
    allParagraphElements.forEach(element => {
        element.style.opacity = paragraphsArray.includes(element) ? '1' : '0.5';
    });

    // === Récupérer les ID correspondants ===
    const selectedIds = [];

    // On parcourt paragraphsData et non allParagraphElements
    paragraphsDataTemp.forEach((data) => {
        const hasElement = data.paragraphs.some(p => paragraphsArray.includes(p));
        if (hasElement) {
            selectedIds.push(data.id);
        }
    });

    // Envoyer à Flutter
    if(isBible()) {
        window.window.flutter_inappwebview.callHandler('verseClickNumber', selectedIds);
    }
}

function createToolbarButton(icon, onClick) {
    const button = document.createElement('button');

    button.innerHTML = icon;

    // Couleurs selon le thème
    const baseColor = isDarkTheme() ? 'white' : '#4f4f4f';
    const hoverColor = isDarkTheme() ? '#606060' : '#e6e6e6';

    // je veux de la couleur quand je clique dessus ou que je passe dessus
    button.style.cssText = `
        font-family: jw-icons-external;
        font-size: 24.5px;
        padding: 2px;
        border-radius: 5px;
        margin: 0 6.5px;
        color: ${baseColor};
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

    button.style.cssText = `
        font-family: jw-icons-external;
        font-size: 24.5px;
        padding: 3px;
        border-radius: 5px;
        margin: 0 6.5px;
        color: ${baseColor};
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

        // Détermination de l'icône de retour
        const isDark = isDarkTheme(); // Supposée fonction pour vérifier le thème

        // Fonction utilitaire pour obtenir la valeur RGB d'une variable CSS
        const getRgbValue = (colorName) => {
            const rawRgb = getComputedStyle(document.documentElement)
                .getPropertyValue(`--color-${colorName}-rgb`)
                .trim();
        
            if (!rawRgb) return { main: '128,128,128', border: '100,100,100' };
        
            let [r, g, b] = rawRgb.split(',').map(num => parseInt(num));
            const max = Math.max(r, g, b);
        
            if (isDark) {
                // Mode Dark : On sature pour le fond, et on assombrit pour la bordure
                const mainRgb = [r, g, b].map(v => (v === max ? v : Math.round(v * 0.87))).join(', ');
                const borderRgb = [r, g, b].map(v => Math.round(v * 0.65)).join(', ');
                return { main: mainRgb, border: borderRgb };
            } else {
                // Mode Light : On garde la couleur originale, bordure nettement plus foncée
                const mainRgb = [r, g, b].join(', ');
                const borderRgb = [r, g, b].map(v => Math.round(v * 0.8)).join(', ');
                return { main: mainRgb, border: borderRgb };
            }
        };

        // Bouton retour (Symbole: E639)
        const backButton = document.createElement('button');
        backButton.innerHTML = '&#xE639;';
        backButton.style.cssText = `
          font-family: jw-icons-external;
          font-size: 24.5px;
          padding: 3px;
          border-radius: 5px;
          margin: 0 3px;
          color: ${isDark ? 'white' : '#4f4f4f'};
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
            // Enlever le fade
            styleToolbar.style.transition = 'opacity 0.0s ease-out';
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
            if (index == 0) return;
            const colorButton = document.createElement('button');
            const colorIndex = index; // Les index de couleur commencent à 1
            const colors = getRgbValue(colorName);

            // 🎨 CRÉATION DU CERCLE DE COULEUR 🎨
            const colorCircle = document.createElement('div');
            colorCircle.style.cssText = `
                width: 25px;
                height: 25px;
                border-radius: 50%;
                background-color: rgb(${colors.main});
                border: 1px solid rgb(${colors.border});
                box-sizing: border-box;
                display: flex;
                justify-content: center;
                align-items: center;
            `;

            // --- Logique d'icône sélectionnée (Symbole: E634) ---
            // Si la couleur actuelle est la couleur de l'élément sélectionné ET nous sommes en mode "highlight existant"
            if (colorIndex === targetColorIndex && styleIndex === targetStyleIndex && !isSelected) {
                const selectedIcon = document.createElement('span');
                // UTILISATION DE E634 POUR LA FLÈCHE DE SÉLECTION
                selectedIcon.innerHTML = '&#xE634;';
                selectedIcon.style.cssText = `
              font-family: jw-icons-external; /* Même famille que le bouton retour */
              font-size: 16px;
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

                        const {
                            wordAndPunctTokens
                        } = paragraphData;

                        const idxFirst = wordAndPunctTokens.indexOf(firstEl);
                        const idxLast = wordAndPunctTokens.indexOf(lastEl);

                        // 🔒 Si un token n'est pas trouvé → sécurité
                        if (idxFirst === -1 || idxLast === -1) {
                            console.error(`❌ Token(s) not found in paragraph ${pid}`, {
                                firstEl,
                                lastEl
                            });
                            return;
                        }

                        // ✅ Toujours ordonner
                        const startIdx = Math.min(idxFirst, idxLast);
                        const endIdx = Math.max(idxFirst, idxLast);

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
                            // S'il y avait un paragraphe précédent, on sauvegarde le blockRange
                            if (firstTarget && lastTarget) {
                                // Appel : utilisation de la fonction déplacée
                                addBlockRangeForParagraph(firstTarget, lastTarget, currentParagraphInfo, blockRangesToSend);
                            }

                            // On commence un nouveau paragraphe
                            currentParagraphId = info.id;
                            currentParagraphInfo = info;
                            firstTarget = element;
                            lastTarget = element;
                        } else {
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
                } else {
                    // --- LOGIQUE DE CHANGEMENT DE COULEUR POUR LE BLOCKRANGE EXISTANT ---
                    // NOTE: 'changeBlockRangeStyle' et 'blockRangeAttr' doivent être accessibles
                    changeBlockRangeStyle(target.getAttribute(blockRangeAttr), styleIndex, colorIndex);
                }

                currentStyleIndex = styleIndex;
                closeToolbar(); // Supposée fonction pour fermer la toolbar principale
            });

            colorToolbar.appendChild(colorButton);
        });

        return colorToolbar;
    }

    // --- Événement de clic sur le bouton principal (immédiat) ---
    button.addEventListener('click', (e) => {
        e.stopPropagation();

        // Créer et afficher la toolbar de couleurs (instantanné)
        const colorToolbar = createColorToolbar();
        // afficher la toolbar de couleur
        colorToolbar.style.opacity = '1';
        document.body.appendChild(colorToolbar);

        // Rendre la toolbar principale invisible (immédiat)
        styleToolbar.style.opacity = '0';
    });

    return button;
}

function closeToolbar(article = pageCenter) {
    const toolbars = document.querySelectorAll('.toolbar');

    if (toolbars.length === 0) return false;

    let actionPrise = false;

    toolbars.forEach(toolbar => {
        // Si elle est déjà en train de fermer, on ignore
        if (toolbar.dataset.status === 'closing') return;

        // On marque la toolbar comme "en cours de fermeture"
        toolbar.dataset.status = 'closing';
        actionPrise = true;

        restoreOpacity(article);

        toolbar.style.transition = "opacity 0.3s ease-out";
        toolbar.style.opacity = '0';
        toolbar.style.pointerEvents = 'none';

        setTimeout(() => {
            toolbar.remove();
        }, 300);
    });

    return actionPrise;
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

function createToolbarBase({targets, blockRangeId, isSelected, target, whenCreateBlockRanges}) {
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
    toolbar.classList.add('toolbar', 'toolbar-blockRange');
    if (isSelected) {
        toolbar.classList.add('selected');
    } else {
        toolbar.setAttribute(blockRangeAttr, blockRangeId);
    }
    toolbar.style.top = `${top}px`;
    toolbar.style.left = `${left}px`;

    document.body.appendChild(toolbar);

    requestAnimationFrame(() => {
        const toolbarRect = toolbar.getBoundingClientRect();
        const realWidth = toolbarRect.width;
        left = Math.min(
            Math.max(left, pageLeft + realWidth / 2 + 10),
            pageRight - realWidth / 2 - 10
        );
        toolbar.style.left = `${left}px`;
        toolbar.style.opacity = '1';
    });

    const paragraphInfo = getTheFirstTargetParagraph(target);
    const id = paragraphInfo.id;
    const paragraphs = paragraphInfo.paragraphs;
    const isVerse = paragraphInfo.isVerse;

    const text = Array.from(targets).map(elem => elem.innerText).filter(text => text.length > 0).join('');

    toolbar.appendChild(createToolbarButtonColor(0, targets, target, toolbar, isSelected));
    toolbar.appendChild(createToolbarButtonColor(1, targets, target, toolbar, isSelected));
    toolbar.appendChild(createToolbarButtonColor(2, targets, target, toolbar, isSelected));

    const buttons = [
        ['&#xE681;', () => isSelected ? addNote(paragraphs[0], id, isVerse, text) : addNoteWithBlockRange(text, target, blockRangeId)],
        ...(!isSelected && blockRangeId ? [
            ['&#xE6C5;', () => removeBlockRange(blockRangeId)]
        ] : []),
        ['&#xE651;', () => callHandler('copyText', {
            text
        })],
        ['&#xE676;', () => callHandler('search', {
            query: text
        })]
    ];

    buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));

    if (whenCreateBlockRanges) {
        // On définit le timer
        let autoRemoveTimer = setTimeout(() => {
            if (toolbar.parentNode) {
                toolbar.style.transition = "opacity 0.3s ease-out";
                toolbar.style.opacity = '0';
                toolbar.style.pointerEvents = 'none';
                
                setTimeout(() => {
                    toolbar.remove();
                }, 300);
            }
        }, 3000);
    
        // Si on entre dans la toolbar, on annule la suppression
        toolbar.addEventListener('mouseenter', () => {
            clearTimeout(autoRemoveTimer);
        });
    }
}

function showToolbarBlockRange(target, blockRangeId, whenCreateBlockRanges) {
    const targets = pageCenter.querySelectorAll(`[${blockRangeAttr}="${blockRangeId}"]`);
    if (targets.length === 0) return;

    createToolbarBase({
        targets,
        blockRangeId,
        isSelected: false,
        target,
        whenCreateBlockRanges
    });
}

function showSelectedToolbar() {
    const targets = getAllSelectedTargets('.word, .punctuation, .escape');
    if (targets.length === 0) return;

    createToolbarBase({
        targets,
        blockRangeId: null,
        isSelected: true,
        target: targets[0],
        whenCreateBlockRanges: false
    });
}

function showToolbar(article, paragraphs, pid, hasAudio, type) {
    const paragraph = paragraphs[0];

    // Ici on dim les autres si pas de blockRange
    dimOthers(article, paragraphs);

    const rect = paragraph.getBoundingClientRect();
    const scrollY = window.scrollY;

    const toolbarHeight = 40;
    const safetyMargin = 10;
    const viewportWidth = window.innerWidth;

    // 1. Préparation de la toolbar et des boutons
    const toolbar = document.createElement('div');
    toolbar.classList.add('toolbar');
    toolbar.setAttribute('data-pid', pid);

    if(article !== pageCenter) {
        return;
    }

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
            ['&#xE62A;', () => callHandler('bookmark', {
                snippet: allParagraphsText,
                id: pid
            })],
            ['&#xE651;', () => callHandler('copyText', {
                text: allParagraphsText
            })],
            ['&#xE620;', () => callHandler('searchVerse', {
                query: pid
            })],
            ['&#xE6A3;', () => callHandler('share', {
                id: pid
            })],
            ['&#xE6DF;', () => callHandler('qrCode', {
                id: pid
            })],
        ];
    } else {
        buttons = [
            ['&#xE681;', () => addNote(paragraph, pid, false, '')],
            ['&#xE62A;', () => callHandler('bookmark', {
                snippet: paragraph.innerText,
                id: pid
            })],
            ['&#xE68E;', () => callHandler('visit', {
                id: pid,
                isBible: false
            })],
            ['&#xE68F;', () => callHandler('bibleStudy', {
                id: pid,
                isBible: false
            })],
            ['&#xE6A3;', () => callHandler('share', {
                id: pid
            })],
            ['&#xE6DF;', () => callHandler('qrCode', {
                id: pid
            })],
            ['&#xE651;', () => callHandler('copyText', {
                text: paragraph.innerText
            })],
        ];
    }

    if (hasAudio) {
        buttons.push(['&#xE65E;', () => callHandler('playAudio', {
            id: pid,
            isBible: type === 'verse'
        })]);
    }

    buttons.forEach(([icon, handler]) => toolbar.appendChild(createToolbarButton(icon, handler)));

    // Position temporaire pour la mesure, sans affecter le flux de la page (important pour .offsetWidth)
    toolbar.style.position = 'absolute';
    toolbar.style.zIndex = '9999';

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

    toolbar.style.left = `${newLeft}px`; // Application du positionnement horizontal

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

    toolbar.style.top = `${top}px`;

    // 5. Affichage final
    requestAnimationFrame(() => {
        toolbar.style.opacity = '1';
    });
}

async function fetchVerseInfo(paragraph, pid) {
    const verseInfo = await window.flutter_inappwebview.callHandler('fetchVerseInfo', {id: pid});
    showVerseInfoDialog(pageCenter, verseInfo, 'verse-info-$pid', pid, false);
    closeToolbar();
}

const HEADER_HEIGHT = 45; // Hauteur fixe du header
const PADDING_CONTENT_VERTICAL = 0; // 16px top + 16px bottom padding dans contentContainer (si padding: 16px est utilisé)
const MIN_RESIZE_HEIGHT = 150; // Hauteur minimale de redimensionnement

function applyDialogStyles(type, dialog, isFullscreen, savedPosition = null) {
    const backgroundColor = type == 'note' ? null : (isDarkTheme() ? '#121212' : '#ffffff');

    const baseStyles = `
          position: fixed;
          box-shadow: 0 15px 50px rgba(0, 0, 0, 0.60);
          z-index: 1000;
          background-color: ${backgroundColor};
          border: ${isFullscreen ? 'none' : '1px solid rgba(0, 0, 0, 0.1)'};
        `;

    if (isFullscreen) {
        const bottomOffset = type == 'note' ? 0 : BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0);

        dialog.classList.add('fullscreen');
        // ✅ CORRECTION: S'assurer que le positionnement est basé sur top/bottom/left/right et non translate
        dialog.style.cssText = `
                ${baseStyles}
                top: ${APPBAR_FIXED_HEIGHT}px;
                left: 0;
                right: 0;
                bottom: ${bottomOffset}px;
                width: 100vw;
                height: calc(100vh - ${APPBAR_FIXED_HEIGHT + bottomOffset}px);
                transform: none !important;
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
                    contentContainer.style.maxHeight = `${Math.max(0, contentMaxHeight)}px`;
                }
            } else {
                dialog.style.height = 'fit-content';
            }

            if (resizedWidth) {
                dialog.style.width = resizedWidth;
            } else {
                dialog.style.width = '85%';
            }

        } 
        else {
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
    const maxHeight = isFullscreen ?
        `calc(100vh - ${APPBAR_FIXED_HEIGHT + BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + HEADER_HEIGHT}px)` :
        '60vh';

    const backgroundColor = type === 'note' ? null : (isDarkTheme() ? '#121212' : '#ffffff');

    contentContainer.style.cssText = `
            max-height: ${maxHeight};
            overflow-y: auto;
            background-color: ${backgroundColor};
            user-select: text;
            border-radius: ${isFullscreen ? '0px' : '0 0 16px 16px'};
            padding: ${paddingStyle};
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
            dialog.setAttribute('data-resized-width', `${rect.width}px`);
            dialog.setAttribute('data-resized-height', `${rect.height}px`);
        } 
        else {
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

        if(type === 'note') {
            setTimeout(() => {
                // Appeler autoResizeTitle s'il s'agit d'une note
                const titleElement = dialog.querySelector('.note-title');
                const textElement = dialog.querySelector('.note-content');
                    
                if (titleElement) {
                    titleElement.style.height = 'auto';
                    titleElement.style.height = titleElement.scrollHeight + 'px';
                }
                if (textElement) {
                    textElement.style.height = 'auto';
                    textElement.style.height = textElement.scrollHeight + 'px';
                }
                
                contentContainer.scrollTop = currentScroll;
            }, 20);
        }
        else {
            setTimeout(() => {
                contentContainer.scrollTop = currentScroll;
            }, 10);

            optimizedResize(contentContainer);
        }
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
        dialog.style.left = `${startLeft}px`;
        dialog.style.top = `${startTop}px`;

        // Si le dialogue était centré, la taille était relative, on la fixe avant de commencer le drag
        if (dialog.style.width === '85%') {
            dialog.style.width = `${rect.width}px`;
            dialog.style.height = `${rect.height}px`;
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

        dialog.style.left = `${Math.max(0, Math.min(newLeft, maxLeft))}px`;
        dialog.style.top = `${Math.max(minTop, Math.min(newTop, maxDialogTop))}px`;
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

function setupResizeSystem(type, handle, dialog, contentContainer) {
    let isResizing = false;
    let startX, startY, startWidth, startHeight, startTop, startLeft;
    const MIN_WIDTH = 200;
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
        dialog.style.left = `${startLeft}px`;
        dialog.style.top = `${startTop}px`;
        dialog.style.width = `${startWidth}px`;
        dialog.style.height = `${startHeight}px`;

        const initialContentMaxHeight = startHeight - HEADER_HEIGHT - PADDING_CONTENT_VERTICAL;
        contentContainer.style.maxHeight = `${Math.max(0, initialContentMaxHeight)}px`;
        contentContainer.style.height = `${Math.max(0, initialContentMaxHeight)}px`;
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

        dialog.style.width = `${newWidth}px`;
        dialog.style.height = `${newHeight}px`;

        const contentMaxHeight = newHeight - HEADER_HEIGHT - PADDING_CONTENT_VERTICAL;
        contentContainer.style.maxHeight = `${Math.max(0, contentMaxHeight)}px`;
        contentContainer.style.height = `${Math.max(0, contentMaxHeight)}px`;

        if(type === 'note') {
            setTimeout(() => {
                // Appeler autoResizeTitle s'il s'agit d'une note
                const titleElement = dialog.querySelector('.note-title');
                const textElement = dialog.querySelector('.note-content');
                    
                if (titleElement) {
                    titleElement.style.height = 'auto';
                    titleElement.style.height = titleElement.scrollHeight + 'px';
                }
                if (textElement) {
                    textElement.style.height = 'auto';
                    textElement.style.height = textElement.scrollHeight + 'px';
                }
            }, 20); // 50ms suffit généralement pour le layout
        }

        optimizedResize(contentContainer);
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
            //dialog.style.height = 'fit-content';
            dialog.style.height = MIN_HEIGHTM;
            //dialog.removeAttribute('data-resized-height');
            //dialog.removeAttribute('data-resized-width');
            dialog.setAttribute('data-resized-height', dialog.style.height);
            dialog.setAttribute('data-resized-width', dialog.style.width);

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
            background: ${backgroundColor};
            color: ${isDark ? '#ffffff' : '#333333'};
            padding-left: ${paddingLeftValue};
            padding-right: 10px;
            font-size: 15px;
            font-weight: 400;
            display: flex;
            align-items: center;
            justify-content: space-between;
            height: ${HEADER_HEIGHT}px;
            border-bottom: 1px solid ${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
            border-radius: ${borderRadius};
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

    if (type === 'note' && options.noteData) {
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
            const {
                element: optionsMenu,
                colorMenu
            } = createOptionsMenu(options.noteData.noteGuid, popup, isDark);

            document.body.appendChild(optionsMenu);
            document.body.appendChild(colorMenu);

            const rect = event.target.getBoundingClientRect();
            optionsMenu.style.top = `${rect.bottom + 8}px`;
            optionsMenu.style.left = `${rect.right - optionsMenu.offsetWidth - moreButton.offsetWidth - 20}px`;
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

function getCurrentDialogContainer() {
    if (currentDialogIndex < 0 || dialogHistory.length === 0) {
        return null;
    }

    const currentDialogData = dialogHistory[currentDialogIndex];
    
    const dialogElement = document.getElementById(currentDialogData.dialogId);

    if (dialogElement) {
        return dialogElement.querySelector('#contentContainer');
    }

    return null;
}

async function createNotesDashboardContent(container) {
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

    const indexContainer = document.createElement('div');
    if(isBibleMode) {
        indexContainer.style.display = 'flex';
        indexContainer.style.flexWrap = 'wrap';
        indexContainer.style.gap = '8px';
        indexContainer.style.marginBottom = '16px';
        innerContainer.appendChild(indexContainer);
    }

    const sortedNotes = [...notes].sort((a, b) => {
        const A = a.BlockIdentifier || '';
        const B = b.BlockIdentifier || '';
        if (A < B) return -1;
        if (A > B) return 1;
        return (a.Guid || "").localeCompare(b.Guid || "");
    });

    const blockIdSet = new Set();

    if(isBibleMode) {
        sortedNotes.forEach(note => {
            if (isBibleMode && note.BlockIdentifier && !blockIdSet.has(note.BlockIdentifier)) {
                blockIdSet.add(note.BlockIdentifier);

                // Carré pour accéder à ce groupe
                const square = document.createElement('div');
                square.textContent = note.BlockIdentifier; // texte à l’intérieur
                square.style.cursor = 'pointer';
                square.style.width = '50px'; // largeur uniforme
                square.style.height = '50px'; // hauteur uniforme
                square.style.display = 'flex';
                square.style.alignItems = 'center';
                square.style.justifyContent = 'center';
                square.style.backgroundColor = '#757575'; // couleur demandée
                square.style.color = '#fff'; // texte en blanc pour contraste
                square.style.borderRadius = '4px'; // coins légèrement arrondis
                square.style.fontSize = '0.85em';
                square.style.fontWeight = 'bold';

                // Scroll vers le groupe
                square.onclick = () => {
                    const target = document.getElementById(`block-${note.BlockIdentifier}`);
                    if (target) {
                        target.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                };

                indexContainer.appendChild(square);
            }
        });
    }

    let lastBlockIdentifier = null;

    sortedNotes.forEach((note, index) => {
        // 1. Gestion du Titre (BlockIdentifier)
        if (isBibleMode && note.BlockIdentifier && note.BlockIdentifier !== lastBlockIdentifier) {
            const blockElem = document.createElement('div');
            blockElem.textContent = cachedPages[currentIndex].title + ':' + note.BlockIdentifier;
            blockElem.id = `block-${note.BlockIdentifier}`;
            blockElem.style.fontWeight = 'bold';

            // Si c'est le tout premier élément (index 0), on retire la marge du haut (40px -> 0)
            const marginTop = (index === 0) ? '0px' : '40px';
            blockElem.style.margin = `${marginTop} 0 6px 8px`;

            innerContainer.appendChild(blockElem);
            lastBlockIdentifier = note.BlockIdentifier;
        }

        // 2. Préparation de la Note
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
            // 3. Gestion de la marge du bas
            // Si c'est le dernier élément du tableau, on retire la marge du bas (16px -> 0)
            if (index === sortedNotes.length - 1) {
                noteElement.style.marginBottom = '0px';
            } else {
                noteElement.style.marginBottom = '16px';
            }

            innerContainer.appendChild(noteElement);
        }
    });
}

function initializeBaseDialog() {
    closeDialog();
    // On enlève tous les éléments de la page
    document.querySelectorAll('.customDialog').forEach(dialog => {
        dialog.remove();
    });

    baseDialog = {
        options: {
            title: 'Notes', // Mis à jour pour refléter le contenu
            type: 'base',
            contentRenderer: createNotesDashboardContent
        },
        canGoBack: false,
        type: 'base',
        dialogId: 'customDialog-base',
    };
}

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
    } 
    else {
        window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
        window.flutter_inappwebview?.callHandler('showDialog', false);
        showFloatingButton();
    }
}


function removeDialogByNoteGuid(noteGuid) {
    if (!noteGuid) return false;

    const dialogIndex = dialogHistory.findIndex(item => item.type === 'note' && item.options?.noteData?.noteGuid === noteGuid);

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
        } 
        else {
            window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
            window.flutter_inappwebview?.callHandler('showDialog', false);
        }
    } 
    else if (dialogHistory.length === 0) {
        currentDialogIndex = -1;
        window.flutter_inappwebview?.callHandler('showFullscreenDialog', false);
        window.flutter_inappwebview?.callHandler('showDialog', false);
    }

    return true;
}

function goBackDialog() {
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
        dialog = createDialogElement(historyItem.options, historyItem.canGoBack, globalFullscreenPreference, 0, historyItem.dialogId);
        document.body.appendChild(dialog);
    }

    applyDialogStyles(historyItem.type, dialog, globalFullscreenPreference);

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

    if (dialogHistory.length === 0) {
        dialogHistory.push(baseDialog);
        currentDialogIndex = 0;
    }

    updateFloatingButtonForClose();

    const currentUniqueKey = options.href || (options.type === 'note' && options.noteData?.noteGuid ? `noteGuid-${options.noteData.noteGuid}` : null);

    let existingDialogIndex = -1;

    if (currentUniqueKey) {
        existingDialogIndex = dialogHistory.findIndex((item, index) => {
            // Ne jamais considérer le baseDialog (index 0) pour la réactivation/remplacement
            if (index === 0) return false;
            // CHAÎNE LITTÉRALE : ${item.options.noteData.noteGuid}
            const historyItemKey = item.options.href ||
                (item.options.type === 'note' && item.options.noteData?.noteGuid ? `noteGuid-${item.options.noteData.noteGuid}` : null);
            return historyItemKey === currentUniqueKey;
        });
    }

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
    }
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

    dialogIdCounter++;
    // CHAÎNE LITTÉRALE : ${dialogIdCounter}
    const newDialogId = `customDialog-${dialogIdCounter}`;

    const newHistoryItem = {
        options: options,
        canGoBack: dialogHistory.length > 0,
        type: options.type || 'default',
        dialogId: newDialogId,
    };

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

    // CHAÎNE LITTÉRALE : ${dialogIdCounter}
    const dialog = document.createElement('div');
    dialog.id = newDialogId || `customDialog-${dialogIdCounter}`;
    dialog.classList.add('customDialog');
    dialog.setAttribute('data-type', options.type || 'default');

    if (typeof applyDialogStyles === 'function') {
        applyDialogStyles(options.type, dialog, isFullscreen);
    }
    dialog.style.display = 'block';

    const header = createHeader(options, isDarkTheme(), dialog, isFullscreen, canGoBack);
    setupDragSystem(header.element, dialog);

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

    setupFullscreenToggle(options.type, header.fullscreenButton, dialog, contentContainer);

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
            border-right: 4px solid ${isDarkTheme() ? 'rgba(255, 255, 255, 0.25)' : 'rgba(0, 0, 0, 0.25)'};
            border-bottom: 4px solid ${isDarkTheme() ? 'rgba(255, 255, 255, 0.25)' : 'rgba(0, 0, 0, 0.25)'};
            border-bottom-right-radius: 16px;
        `;
    dialog.appendChild(resizeHandle);

    setupResizeSystem(options.type, resizeHandle, dialog, contentContainer);
    return dialog;
}

function restoreLastDialog() {
    if (!lastClosedDialog) return;

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
        showDialog(lastClosedDialog.options);
    }

    lastClosedDialog = null;

    updateFloatingButtonForClose();

    window.flutter_inappwebview?.callHandler('showDialog', true);
}

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
    floatingButton.style.bottom = `${BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0) + 15}px`;

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
    } 
    else {
        // Le dialogue est actif, le FAB sert à fermer
        updateFloatingButtonForClose();
        return;
    }

    // Animation d'apparition
    if (controlsVisible) {
        floatingButton.style.opacity = '1';
    } 
    else {
        floatingButton.style.opacity = '0';
    }
}

function updateFloatingButtonForClose() {
    const floatingButton = createFloatingButton();

    if (dialogHistory.length > 0) {
        floatingButton.innerHTML = ARROW_BACK;
        floatingButton.onclick = closeDialog;

        if (controlsVisible) {
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

function removeFloatingButton() {
    const floatingButton = document.getElementById('dialogFloatingButton');
    if (floatingButton) {
        floatingButton.remove();
    }
}

async function openNoteDialog(noteGuid) {
    const note = await window.flutter_inappwebview.callHandler('getNoteByGuid', noteGuid);

    if (!note) {
        console.error('Note non trouvée pour le GUID:', noteGuid);
        return;
    }

    closeToolbar();

    const options = {
        title: note.DialogTitle || 'Note',
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

    const {
        noteGuid,
        title,
        content,
        tagsId,
        colorIndex
    } = options.noteData;
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
    noteContentWrapper.id = `data-note-guid-${noteGuid}`;
    noteContentWrapper.style.cssText = `
            padding: 1.1em;
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
            font-size: inherit;
            font-weight: bold;
            line-height: 1.3;
            background: transparent;
            color: inherit;
            overflow: hidden;
            padding: 8px 0;
            width: 100%;
            box-sizing: border-box;
            display: block;
        `;

    const autoResizeTitle = () => {
        const initialScrollTop = contentContainer.scrollTop;
        titleElement.rows = 1;
        titleElement.style.height = 'auto';
        titleElement.style.height = titleElement.scrollHeight + 'px';
        contentContainer.scrollTop = initialScrollTop; // Tente de maintenir la position
    };

    titleElement.addEventListener('input', () => {
        autoResizeTitle();
        saveChanges();
    });

    // SÉPARATEUR
    const separator1 = document.createElement('div');
    separator1.style.cssText = `
            height: 1px;
            background: ${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)'};
            margin: 4px 0;
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
            font-size: 0.95em;
            line-height: 1.5;
            background: transparent;
            color: inherit;
            overflow: hidden;
            padding: 8px 0;
            width: 100%;
            box-sizing: border-box;
            display: block;
        `;

    const autoResizeContent = () => {
        const initialScrollTop = contentContainer.scrollTop;
        contentElement.rows = 1;
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
            background: ${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)'};
            margin: 4px 0;
        `;

    // 🏷️ GESTION DES TAGS
    const currentTagIds = (typeof tagsId === 'string' && tagsId !== '') ?
        tagsId.split(',')
        .map(id => parseInt(id))
        .filter(id => !isNaN(id)) :
        [];

    const createTagElement = (tag) => {
        const tagElement = document.createElement('span');
        tagElement.style.cssText = `
                display: inline-flex;
                align-items: center;
                background: ${isDark ? '#4a4a4a' : 'rgba(210, 210, 210, 0.4)'};
                color: inherit;
                padding: 8px 12px;
                border-radius: 20px;
                font-size: 0.8em;
                white-space: nowrap;
                cursor: pointer;
            `;

        const text = document.createElement('span');
        text.textContent = tag.Name;
        text.style.pointerEvents = 'none';
        tagElement.appendChild(text);

        const closeBtn = document.createElement('span');
        closeBtn.classList.add('tag-close-btn', 'jwf-jw-icons-external', 'jwi-x');
        closeBtn.style.cssText = `
                margin-left: 8px;
                cursor: pointer;
                color: ${isDark ? '#e0e0e0' : 'inherit'};
                font-size: 1.4em;
                line-height: 1;
            `;

        closeBtn.onclick = (e) => {
            e.preventDefault();
            tagsContainer.removeChild(tagElement);
            const index = currentTagIds.indexOf(tag.TagId);
            if (index > -1) currentTagIds.splice(index, 1);
            window.flutter_inappwebview.callHandler('removeTagIdFromNote', {
                Guid: noteGuid,
                TagId: tag.TagId
            });
            setTimeout(() => tagInput.focus(), 10);
        };

        tagElement.appendChild(closeBtn);
        tagElement.onclick = (e) => {
            if (e.target === closeBtn) return;
            window.flutter_inappwebview.callHandler('openTagPage', {
                TagId: tag.TagId
            });
        };

        return tagElement;
    };

    const addTagToUI = (tag) => {
        if (!currentTagIds.includes(tag.TagId)) {
            const tagElement = createTagElement(tag);
            tagsContainer.insertBefore(tagElement, tagInputWrapper);
            currentTagIds.push(tag.TagId);
            window.flutter_inappwebview.callHandler('addTagIdToNote', {
                Guid: noteGuid,
                TagId: tag.TagId
            });
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
            position: relative;
        `;

    const tagInput = document.createElement('input');
    tagInput.className = 'note-tags';
    tagInput.type = 'text';
    tagInput.placeholder = 'Ajouter une catégorie...';
    tagInput.style.cssText = `
            border: none;
            outline: none;
            font-size: 0.8em;
            flex: 1;
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
            background: ${isDark ? '#333' : 'rgba(255, 255, 255, 1)'};
            border-radius: 8px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.15);
            backdrop-filter: blur(10px);
            max-height: 290px; /* Limite la hauteur à environ 7 éléments */
            overflow-y: auto;  /* Active le scroll vertical */
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
    }, {
        passive: true
    }); // Lecture seule

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
    }, {
        passive: false
    }); // 'passive: false' est CRUCIAL pour que preventDefault fonctionne

    async function addTagToDatabase(value) {
        const result = await window.flutter_inappwebview.callHandler('addTag', {
            Name: value
        });
        if (result && result.Tag) addTagToUI(result.Tag);
    }

    const showSuggestions = async (filteredTags, query) => {
        suggestionsList.innerHTML = '';
        const value = query.trim();
        const exactMatch = filteredTags.some(tag => tag.Name.toLowerCase() === value.toLowerCase());

        if (value !== '' && !exactMatch) {
            const addNew = document.createElement('div');
            addNew.textContent = `Ajouter la catégorie: "${value}"`;
            addNew.style.cssText = `
                    padding: 10px 14px;
                    cursor: pointer;
                    font-size: 0.8em;
                    color: inherit;
                    border-bottom: ${filteredTags.length > 0 ? '1px solid ' + (isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)') : 'none'};
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
                    padding: 8px 12px;
                    cursor: pointer;
                    font-size: 0.8em;
                    color: inherit;
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
        if (suggestionsList.style.display === 'none') return;

        const rect = tagInput.getBoundingClientRect();

        // 🚀 CORRECTION: Positionnement strict sous l'input
        suggestionsList.style.top = `${rect.bottom + 5}px`;
        suggestionsList.style.bottom = 'auto'; // Force la position sous l'élément

        suggestionsList.style.left = `${rect.left}px`;

        // Suppression de la logique de basculement au-dessus, comme demandé
    };

    // Événements Input Tags
    tagInput.addEventListener('input', async () => {
        const value = tagInput.value.trim();
        try {
            const filteredTags = await window.flutter_inappwebview.callHandler('getFilteredTags', value, currentTagIds);
            showSuggestions(filteredTags, value);
            tagsContainer.style.paddingBottom = '100px';
        } catch (error) {
            console.error('Erreur lors de la récupération des tags filtrés', error);
        }
    });

    tagInput.addEventListener('focus', async () => {
        const value = tagInput.value.trim();
        try {
            const filteredTags = await window.flutter_inappwebview.callHandler('getFilteredTags', value, currentTagIds);
            showSuggestions(filteredTags, value);
            // mettre un padding plus grand en bas du contentContainer pour éviter que la liste de suggestions soit coupée
            tagsContainer.style.paddingBottom = '100px';
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
            tagsContainer.style.paddingBottom = '20px';
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
    //noteContentWrapper.appendChild(separator1);
    noteContentWrapper.appendChild(contentElement);
    //noteContentWrapper.appendChild(separator2);
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
            background: ${isDark ? 'rgba(30, 30, 30, 1)' : 'rgba(255, 255, 255, 1)'};
            border-radius: 8px;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
            display: none;
            flex-direction: column;
            z-index: 2000;
            border: 1px solid ${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
            padding: 5px 0;
        `;

    // Bouton Supprimer
    const deleteBtn = document.createElement('div');
    deleteBtn.className = 'menu-item';
    deleteBtn.innerHTML = '🗑 Supprimer la note';
    deleteBtn.style.cssText = `
            padding: 8px 12px;
            cursor: pointer;
            transition: background-color 0.2s ease;
            color: ${isDark ? '#fff' : '#333'};
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
            const note = pageCenter.querySelector(`[${noteAttr}="${noteGuid}"]`);
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
            color: ${isDark ? '#fff' : '#333'};
        `;
    changeColorItem.onmouseenter = () => changeColorItem.style.backgroundColor = isDark ? 'rgba(0, 123, 255, 0.2)' : 'rgba(0, 123, 255, 0.1)';
    changeColorItem.onmouseleave = () => changeColorItem.style.backgroundColor = 'transparent';

    // Sous-menu couleurs
    const colorMenu = document.createElement('div');
    colorMenu.className = 'color-menu';
    colorMenu.style.cssText = `
            position: absolute;
            width: 120px;
            background: ${isDark ? 'rgba(30, 30, 30, 0.95)' : 'rgba(255, 255, 255, 0.95)'};
            border-radius: 8px;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
            display: none;
            flex-direction: column;
            z-index: 2001;
            backdrop-filter: blur(10px);
            border: 1px solid ${isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
        `;

    colorsList.forEach((colorName, index) => {
        if (index == 0) return;
        const colorOption = document.createElement('div');
        const colorIndex = index; // Les index de couleur commencent à 1
        const colorClass = getNoteClass(colorIndex, false);
        colorOption.className = `color-option ${colorClass}`;
        colorOption.innerHTML = `<span style="background: var(--${colorClass}); width: 16px; height: 16px; border-radius: 50%; border: 1px solid rgba(0,0,0,0.2);"></span>`;
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
        colorMenu.style.top = `${rect.top}px`;
        colorMenu.style.left = `${rect.left - 130}px`;
        colorMenu.style.display = 'flex';
    };

    optionsMenu.appendChild(deleteBtn);
    optionsMenu.appendChild(changeColorItem);

    return {
        element: optionsMenu,
        colorMenu: colorMenu
    };
}

// Fonction pour afficher le dialogue des différentes traductions de versets
function showVerseDialog(article, dialogData, payload, replace) {
    showDialog({
        title: dialogData.title,
        type: 'verse',
        article: article,
        replace: replace,
        href: payload.clicked,
        contentRenderer: (contentContainer) => {
            dialogData.verses.forEach((item) => {
                const headerBar = document.createElement('div');
                headerBar.style.cssText = `
                    display: flex;
                    align-items: center;
                    background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
                `;

                const img = document.createElement('img');
                img.src = 'file://' + item.imageUrl;
                img.style.cssText = `
                    height: 45px;
                    width: 45px;
                    object-fit: cover;
                    margin-right: 10px;
                    user-select: none;
                `;

                const textContainer = document.createElement('div');
                textContainer.style.cssText = 'flex-grow: 1;';

                const bibleTitle = document.createElement('div');
                bibleTitle.textContent = item.bibleTitle;
                bibleTitle.style.cssText = `
                    font-size: 14px;
                    font-weight: 700;
                    margin-top: 2px;
                    margin-bottom: 2px;
                    color: ${isDarkTheme() ? '#ffffff' : '#333333'};
                    line-height: 1.3;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    user-select: none;
                `;

                const languageText = document.createElement('div');
                languageText.textContent = item.languageText;
                languageText.style.cssText = `
                    font-size: 12px;
                    opacity: 0.9;
                    line-height: 1.4;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    user-select: none;
                `;

                textContainer.style.display = 'flex';
                textContainer.style.alignItems = 'center';
                textContainer.style.justifyContent = 'space-between';

                const textWrapper = document.createElement('div');
                textWrapper.style.overflow = 'hidden';
                textWrapper.appendChild(bibleTitle);
                textWrapper.appendChild(languageText);

                const icon = document.createElement('span');
                icon.innerHTML = '&#xE63A;';
                icon.style.fontFamily = 'jw-icons-external';
                icon.style.fontSize = '20px';
                icon.style.marginLeft = '10px';
                icon.style.marginRight = '5px';
                icon.style.flexShrink = '0';
                icon.style.userSelect = 'none';

                textContainer.appendChild(textWrapper);
                textContainer.appendChild(icon);

                headerBar.appendChild(img);
                headerBar.appendChild(textContainer);

                const article = document.createElement('div');
                article.style.cssText = `
                    position: relative;
                `;
                
                if(item.isVerseExisting) {
                    article.innerHTML = `<article id="verse-dialog" class="${item.className}">${item.content}</article>`;

                    wrapWordsWithSpan(article, true);

                    paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article, true);

                    item.blockRanges.forEach(b => {
                        const chapterNumber = b.Location?.ChapterNumber ?? null;

                        const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                            p.chapterId === chapterNumber &&
                            p.id === b.Identifier
                        );

                        if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                            return;
                        }
                        addBlockRange(paragraphInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
                    });

                    dialogData.notes.forEach(note => {
                        const matchingBlockRange = item.blockRanges.find(
                            b => b.UserMarkGuid === note.UserMarkGuid
                        );

                        const chapterNumber = note.Location?.ChapterNumber ?? null;

                        const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                            p.chapterId === chapterNumber &&
                            p.id === note.BlockIdentifier
                        );

                        if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                            return;
                        }

                        addNoteWithGuid(
                            article,
                            paragraphInfo.paragraphs[0],
                            matchingBlockRange?.UserMarkGuid ?? null,
                            note.Guid,
                            note.ColorIndex ?? 0,
                            true,
                            false
                        );
                    });

                    const infoBible = {
                        keySymbol: item.keySymbol,
                        mepsLanguageId: item.mepsLanguageId,
                        issueTagNumber: 0
                    };

                    article.addEventListener('click', async (event) => {
                        onClickOnPage(article, event, infoBible);
                    });

                    headerBar.addEventListener('click', function() {
                        window.flutter_inappwebview?.callHandler('openMepsDocument', item, dialogData);
                    });
                }
                else {
                    article.innerHTML = `<article id="verse-dialog" class="${item.className}">${dialogData.noVerseExistingText}</article>`;
                    article.style.cssText = `
                        padding: 15px 23px;
                    `;
                }

                contentContainer.appendChild(headerBar);
                contentContainer.appendChild(article);
            });

            // CRÉATION DU BOUTON "PERSONNALISER"
            const customizeButton = document.createElement('button');
            customizeButton.textContent = dialogData.personalizedText || 'Personalized';

            // Détermination des couleurs selon le thème
            const bgColor = isDarkTheme() ? '#8e8e8e' : '#757575';
            const textColor = isDarkTheme() ? 'black' : 'white';

            customizeButton.style.cssText = `
                    display: block;
                    padding: 6px 30px;
                    margin: 16px auto 20px;
                    border: none;
                    cursor: pointer;
                    font-size: 16px;
                    text-align: center;
                    background-color: ${bgColor};
                    color: ${textColor};
                    transition: background-color 0.2s ease;
                    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
                `;

            // Ajouter le listener quand on clique sur le bouton
            customizeButton.addEventListener('click', async () => {
                const hasChanges = await window.flutter_inappwebview.callHandler('openCustomizeVersesDialog');

                // 2. Vérification si des changements ont eu lieu AVANT de recharger les versets
                if (hasChanges === true) {
                    const dialogData = await window.flutter_inappwebview.callHandler('fetchVerses', payload);
                    showVerseDialog(article, dialogData, payload, true);
                } 
                else {
                    console.log("Aucun changement de version, les versets ne sont pas rechargés.");
                }
            });

            // Ajout du bouton au bas du contentContainer
            contentContainer.appendChild(customizeButton);
            repositionAllNotes(contentContainer);
        }
    });
}

// Fonction pour afficher les références des versets bibliques
function showVerseReferencesDialog(article, dialogData, href) {
    showDialog({
        title: dialogData.title,
        type: 'verse-references',
        article: article,
        href: href,
        contentRenderer: (contentContainer) => {
            dialogData.verseReferences.forEach((item) => {
                const headerBar = document.createElement('div');
                headerBar.style.cssText = `
                      display: flex;
                      align-items: center;
                      background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
                  `;

                const img = document.createElement('img');
                img.src = 'file://' + item.imageUrl;
                img.style.cssText = `
                      height: 45px;
                      width: 45px;
                      object-fit: cover;
                      margin-right: 10px;
                      user-select: none;
                  `;

                const textContainer = document.createElement('div');
                textContainer.style.cssText = 'flex-grow: 1;';

                const verseTitleDiaplay = document.createElement('div');
                verseTitleDiaplay.textContent = item.verseTitleDiaplay;
                verseTitleDiaplay.style.cssText = `
                      font-size: 14px;
                      font-weight: 700;
                      margin-top: 2px;
                      margin-bottom: 2px;
                      color: ${isDarkTheme() ? '#ffffff' : '#333333'};
                      line-height: 1.3;
                      white-space: nowrap;
                      overflow: hidden;
                      text-overflow: ellipsis;
                      user-select: none;
                  `;

                const languageText = document.createElement('div');
                languageText.textContent = item.languageText;
                languageText.style.cssText = `
                      font-size: 12px;
                      opacity: 0.9;
                      line-height: 1.4;
                      white-space: nowrap;
                      overflow: hidden;
                      text-overflow: ellipsis;
                      user-select: none;
                  `;

                textContainer.style.display = 'flex';
                textContainer.style.alignItems = 'center';
                textContainer.style.justifyContent = 'space-between';

                const textWrapper = document.createElement('div');
                textWrapper.style.overflow = 'hidden';
                textWrapper.appendChild(verseTitleDiaplay);
                textWrapper.appendChild(languageText);

                const icon = document.createElement('span');
                icon.innerHTML = '&#xE63A;';
                icon.style.fontFamily = 'jw-icons-external';
                icon.style.fontSize = '20px';
                icon.style.marginLeft = '10px';
                icon.style.marginRight = '5px';
                icon.style.flexShrink = '0';
                icon.style.userSelect = 'none';

                textContainer.appendChild(textWrapper);
                textContainer.appendChild(icon);
                
                headerBar.addEventListener('click', function() {
                    window.flutter_inappwebview?.callHandler('openMepsDocument', item);
                });

                headerBar.appendChild(img);
                headerBar.appendChild(textContainer);

                const article = document.createElement('div');
                article.innerHTML = `<article id="verse-references-dialog" class="${item.className}">${item.content}</article>`;
                article.style.cssText = `
                    position: relative;
                    padding-top: 10px;
                    padding-bottom: 16px;
                  `;

                wrapWordsWithSpan(article, true);

                paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article, true);

                item.blockRanges.forEach(b => {
                    const chapterNumber = b.Location?.ChapterNumber ?? null;

                    const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                        p.chapterId === chapterNumber &&
                        p.id === b.Identifier
                    );

                    if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                        return;
                    }
                    addBlockRange(paragraphInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
                });

                item.notes.forEach(note => {
                    const matchingBlockRange = item.blockRanges.find(
                        b => b.UserMarkGuid === note.UserMarkGuid
                    );

                    const chapterNumber = note.Location?.ChapterNumber ?? null;

                    const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                        p.chapterId === chapterNumber &&
                        p.id === note.BlockIdentifier
                    );

                    if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                        return;
                    }

                    addNoteWithGuid(
                        article,
                        paragraphInfo.paragraphs[0],
                        matchingBlockRange?.UserMarkGuid ?? null,
                        note.Guid,
                        note.ColorIndex ?? 0,
                        true,
                        false
                    );
                });

                contentContainer.appendChild(headerBar);
                contentContainer.appendChild(article);

                article.addEventListener('click', async (event) => {
                    onClickOnPage(article, event);
                });
            });
            repositionAllNotes(contentContainer);
        }
    });
}

let globalIdCounter = 0;

function showVerseInfoDialog(article, verseInfo, href, pid, replace) {
    showDialog({
        title: verseInfo.title,
        type: 'verse-info',
        article: article,
        replace: replace,
        href: href,
        contentRenderer: (contentContainer) => {
            const tabsDefinition = [{
                    key: 'commentary',
                    iconClass: 'jwi-bible-speech-balloon',
                    label: "commentaire"
                },
                {
                    key: 'medias',
                    iconClass: 'jwi-image-stack',
                    label: "medias"
                },
                {
                    key: 'guide',
                    iconClass: 'jwi-publications-pile',
                    label: "guide"
                },
                {
                    key: 'footnotes',
                    iconClass: 'jwi-bible-quote',
                    label: "notes de bas de page"
                },
                {
                    key: 'notes',
                    iconClass: 'jwi-text-pencil',
                    label: "notes personnelles"
                },
                {
                    key: 'versions',
                    iconClass: 'jwi-bible-comparison',
                    label: "versions"
                },
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
                    border-bottom: 1px solid ${isDarkTheme() ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)'};
                    background-color: ${isDarkTheme() ? '#111' : '#f9f9f9'};
                `;

                // Crée les boutons d'onglets basés sur le tableau filtré.
                const tabButtons = filteredTabs.map(({
                    key,
                    iconClass
                }) => {
                    const btn = document.createElement('button');
                    btn.classList.add('jwf-jw-icons-external', iconClass);
                    btn.style.cssText = `
                        flex: 1;
                        padding: 10px;
                        border: none;
                        background: none;
                        cursor: pointer;
                        font-size: 30px;
                        color: ${isDarkTheme() ? '#fff' : '#000'};
                        border-bottom: 2px solid ${key === currentTab ? (isDarkTheme() ? '#fff' : '#000') : 'transparent'};
                    `;

                    btn.addEventListener('click', () => {
                        currentTab = key;
                        updateTabContent();
                        // Met à jour le style de tous les boutons pour marquer l'onglet actif.
                        tabButtons.forEach(b => {
                            b.style.borderBottom = '2px solid transparent';
                        });
                        btn.style.borderBottom = `2px solid ${isDarkTheme() ? '#fff' : '#000'}`;
                    });

                    tabBar.appendChild(btn);
                    return btn;
                });
                contentContainer.appendChild(tabBar);
            }

            // Conteneur pour le contenu dynamique
            const dynamicContent = document.createElement('div');
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
                        let isLast = items.indexOf(item) === items.length - 1;

                        if (key === 'medias') {
                            contentHtml = `
                                <div id="verse-info-dialog" class="mediaItem ${item.isVideo ? 'hasVideo' : ''}">
                                <div class="mediaImgWrapper">
                                    <img class="${item.isVideo ? 'video' : 'image'}" src="${item.imagePath}">
                                </div>
                                <div class="mediaBody">
                                    <a class="mediaTitle">
                                    ${item.label}
                                    </a>
                                </div>
                                </div>
                            `;

                            articleDiv.addEventListener("click", event => {
                                event.preventDefault();
                                if (item.isVideo) {
                                    window.flutter_inappwebview.callHandler('onVideoClick', item.href);
                                } else {}
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

                            const newNote = {
                                'noteData': noteData
                            };

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
                            // --- VERSION FULL DOM CORRIGÉE POUR GUIDE ---
                            const container = document.createElement('article');
                            container.style.cssText = "display: flex; flex-direction: column; gap: 4px;";
                            
                            item.items.forEach(guideItem => {
                                const itemId = `guide-item-${globalIdCounter++}`;
                                const tempArticle = document.createElement('article');
                                tempArticle.className = guideItem.className || '';
                                tempArticle.innerHTML = guideItem.content || '';
                                
                                // Sécurité classList : on ne traite que si le contenu existe
                                try {
                                    wrapWordsWithSpan(tempArticle, false);
                                    const pData = fetchAllParagraphsOfTheArticle(tempArticle);
                                    if (guideItem.blockRanges) {
                                        guideItem.blockRanges.forEach(b => {
                                            const pInfo = pData.get(b.Identifier);
                                            // LA CORRECTION EST ICI : vérification du paragraphe avant classList
                                            if (pInfo && pInfo.paragraphs && pInfo.paragraphs[0]) {
                                                addBlockRange(pInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
                                            }
                                        });
                                    }

                                    if(guideItem.notes) {
                                        guideItem.notes.forEach(note => {
                                            const matchingBlockRange = item.blockRanges.find(b => b.UserMarkGuid === note.UserMarkGuid);
                                            const paragraphInfo = pData.get(note.BlockIdentifier);

                                            addNoteWithGuid(
                                                tempArticle, 
                                                paragraphInfo.paragraphs[0],
                                                matchingBlockRange?.UserMarkGuid ?? null,
                                                note.Guid,
                                                note.ColorIndex ?? 0,
                                                false,
                                                false
                                            );
                                        });
                                    }
                                } 
                                catch(e) { console.error("Erreur guide DOM", e); }

                                const row = document.createElement('div');
                                row.id = itemId;
                                row.setAttribute('data-content-html-processed', tempArticle.outerHTML);
                                row.style.cssText = `display: flex; align-items: center; background-color: ${isDarkTheme() ? '#000' : '#f1f1f1'}; cursor: pointer;`;
                                
                                row.innerHTML = `
                                    <div style="width: 45px; height: 45px; margin-right: 10px; flex-shrink: 0; background-color: ${guideItem.color || '#ccc'}">
                                        ${guideItem.imageUrl ? `<img src="${guideItem.imageUrl}" style="width:100%; height:100%; object-fit:cover;">` : ''}
                                    </div>
                                    <div style="flex: 1; overflow: hidden;">
                                        <div style="font-size:14px; font-weight:bold; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:${isDarkTheme()?'#fff':'#000'}">${guideItem.publicationTitle}</div>
                                        <div style="font-size:12px; opacity:0.8; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:${isDarkTheme()?'#fff':'#000'}">${guideItem.subtitle}</div>
                                    </div>
                                    <span style="font-family:jw-icons-external; font-size:20px; margin-left: 10px; margin-right: 5px; user-select:none;" data-expansion-button="true" data-item-id="${itemId}">&#xE639;</span>
                                `;

                                const expandArea = document.createElement('div');
                                expandArea.id = `content-expand-${itemId}`;
                                expandArea.style.display = 'none';
                                expandArea.addEventListener('click', async (event) => {
                                    onClickOnPage(expandArea, event);
                                });

                                row.addEventListener('click', (e) => {
                                    if (e.target.closest('[data-expansion-button]')) {
                                        e.stopPropagation();
                                        handleExpand(itemId);
                                    } else {
                                        window.flutter_inappwebview.callHandler('openMepsDocument', guideItem);
                                    }
                                });
                                container.append(row, expandArea);
                            });
                            dynamicContent.appendChild(container);
                        }
                        else if (key === 'versions') {
                            const headerBar = document.createElement('div');
                            headerBar.style.cssText = `
                                display: flex;
                                align-items: center;
                                background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
                            `;

                            const img = document.createElement('img');
                            img.src = 'file://' + item.imageUrl;
                            img.style.cssText = `
                                height: 45px;
                                width: 45px;
                                object-fit: cover;
                                margin-right: 10px;
                                user-select: none;
                            `;

                            const textContainer = document.createElement('div');
                            textContainer.style.cssText = 'flex-grow: 1;';

                            const pubTitle = document.createElement('div');
                            pubTitle.textContent = item.publicationTitle;
                            pubTitle.style.cssText = `
                                font-size: 14px;
                                font-weight: 700;
                                margin-top: 2px;
                                margin-bottom: 2px;
                                color: ${isDarkTheme() ? '#ffffff' : '#333333'};
                                line-height: 1.3;
                                white-space: nowrap;
                                overflow: hidden;
                                text-overflow: ellipsis;
                                user-select: none;
                            `;

                            const subtitleText = document.createElement('div');
                            subtitleText.textContent = item.subtitle;
                            subtitleText.style.cssText = `
                                font-size: 12px;
                                opacity: 0.9;
                                line-height: 1.4;
                                white-space: nowrap;
                                overflow: hidden;
                                text-overflow: ellipsis;
                                user-select: none;
                            `;

                            textContainer.style.display = 'flex';
                            textContainer.style.alignItems = 'center'; // Aligne verticalement l'icône et le texte
                            textContainer.style.justifyContent = 'space-between'; // Pousse l'icône à l'extrémité droite

                            const textWrapper = document.createElement('div');
                            textWrapper.style.overflow = 'hidden'; // Important pour l'ellipse du texte
                            textWrapper.appendChild(pubTitle);
                            textWrapper.appendChild(subtitleText);

                            const icon = document.createElement('span');
                            icon.innerHTML = '&#xE63A;'; // Utilisation de innerHTML pour l'entité HTML
                            icon.style.fontFamily = 'jw-icons-external';
                            icon.style.fontSize = '20px';
                            icon.style.marginLeft = '10px'; // Petit espace entre le texte et l'icône
                            icon.style.marginRight = '5px';
                            icon.style.flexShrink = '0';   // Empêche l'icône de s'écraser si le texte est long
                            icon.style.userSelect = 'none';

                            textContainer.appendChild(textWrapper);
                            textContainer.appendChild(icon);

                            headerBar.addEventListener('click', function() {
                                window.flutter_inappwebview?.callHandler('openMepsDocument', item);
                            });

                            headerBar.appendChild(img);
                            headerBar.appendChild(textContainer);

                            const article = document.createElement('div');
                            article.innerHTML = `<article id="verse-dialog" class="${item.className}">${item.content}</article>`;
                            article.style.cssText = `
                                position: relative;
                                padding-top: 10px;
                                padding-bottom: 16px;
                            `;

                            wrapWordsWithSpan(article, true);

                            paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article, true);

                            item.blockRanges.forEach(b => {
                                const chapterNumber = b.Location?.ChapterNumber ?? null;

                                const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                                    p.chapterId === chapterNumber &&
                                    p.id === b.Identifier
                                );

                                if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                                    return;
                                }
                                addBlockRange(paragraphInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
                            });

                            item.notes.forEach(note => {
                                const matchingBlockRange = item.blockRanges.find(
                                    h => h.UserMarkGuid === note.UserMarkGuid
                                );

                                const chapterNumber = note.Location?.ChapterNumber ?? null;

                                const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                                    p.chapterId === chapterNumber &&
                                    p.id === note.BlockIdentifier
                                );

                                if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                                    return;
                                }

                                addNoteWithGuid(
                                    article,
                                    paragraphInfo.paragraphs[0],
                                    matchingBlockRange?.UserMarkGuid ?? null,
                                    note.Guid,
                                    note.ColorIndex ?? 0,
                                    true,
                                    false
                                );
                            });

                            dynamicContent.appendChild(headerBar);
                            dynamicContent.appendChild(article);

                            if(isLast) {
                                // CRÉATION DU BOUTON "PERSONNALISER"
                                const customizeButton = document.createElement('button');
                                customizeButton.textContent = 'Personnaliser';

                                // Détermination des couleurs selon le thème
                                const bgColor = isDarkTheme() ? '#8e8e8e' : '#757575';
                                const textColor = isDarkTheme() ? 'black' : 'white';

                                customizeButton.style.cssText = `
                                        display: block;
                                        padding: 6px 30px;
                                        margin: 16px auto 20px; /* marge supérieure + inférieure */
                                        border: none;
                                        cursor: pointer;
                                        font-size: 16px;
                                        text-align: center;
                                        background-color: ${bgColor};
                                        color: ${textColor};
                                        transition: background-color 0.2s ease;
                                        box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
                                    `;

                                // Ajouter le listener quand on clique sur le bouton
                                customizeButton.addEventListener('click', async () => {
                                    const hasChanges = await window.flutter_inappwebview.callHandler('openCustomizeVersesDialog');

                                    // 2. Vérification si des changements ont eu lieu AVANT de recharger les versets
                                    if (hasChanges === true) {
                                        const verseInfo = await window.flutter_inappwebview.callHandler('fetchVerseInfo', {id: pid});
                                        showVerseInfoDialog(pageCenter, verseInfo, 'verse-info-$pid', true);
                                    } 
                                    else {
                                        console.log("Aucun changement de version, les versets ne sont pas rechargés.");
                                    }
                                });

                                // Ajout du bouton au bas du contentContainer
                                dynamicContent.appendChild(customizeButton);
                            }
                        } 
                        else if (key === 'footnotes') {
                            if (item.type === 'footnote') {
                                const letter = getFootnoteLetter(items.indexOf(item) + 1);
                                contentHtml = `
                                <div id="footnote${item.footnoteIndex}" data-fnid="${item.footnoteIndex}" class="fcc fn-ref ${item.className}">
                                    <p>
                                        <a href="#footnotesource${item.footnoteIndex}" class="fn-symbol">${letter}</a>
                                        ${item.content}
                                    </p>
                                </div>
                            `;
                            } 
                            else if (item.type === 'versesReference') {

                                // *** Utilisation du compteur global pour l'ID ***
                                const itemId = `xref-item-${globalIdCounter++}`;

                                // 1. Concaténation des références de versets pour l'affichage initial
                                const combinedVerse = item.verses
                                    .map(verse => verse.bookDisplay)
                                    .join('; ');

                                const combinedVersesDisplay = `<span class="xRefCitation">${combinedVerse}</span>`;

                                // 2. Construction du contenu riche pour l'expansion (Rich Content)
                                const verseContentHtml = item.verses.map(verse => {
                                    return `
                                    <div style="
                                        display: flex;
                                        align-items: center;
                                        background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
                                    ">
                                        <img src="file://${item.imageUrl}" style="
                                            height: 45px;
                                            width: 45px;
                                            object-fit: cover;
                                            margin-right: 10px;
                                            user-select: none;
                                        ">

                                        <div style="flex-grow: 1;">
                                            <div style="
                                                font-size: 14px;
                                                font-weight: 700;
                                                margin-top: 2px;
                                                margin-bottom: 2px;
                                                line-height: 1.3;
                                                white-space: nowrap;
                                                overflow: hidden;
                                                text-overflow: ellipsis;
                                                user-select: none;
                                            ">
                                                ${verse.bibleVerseDisplay || 'Référence non disponible'}
                                            </div>

                                            <div style="
                                                font-size: 12px;
                                                opacity: 0.9;
                                                line-height: 1.4;
                                                white-space: nowrap;
                                                overflow: hidden;
                                                text-overflow: ellipsis;
                                                user-select: none;
                                            ">
                                                ${item.subtitle}
                                            </div>
                                        </div>
                                    </div>

                                    <div style="position: relative; padding: 10px 10px 16px 10px;">
                                        <article class="${item.className || ''}">
                                            ${verse.content || 'Contenu non disponible'}
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
                            <div id="${itemId}"
                                 class="jwac xRef"
                                 data-content-html="${encodedCombinedVerse}"
                                 style="${xRefContainerStyle}">

                                <div style="display: flex; align-items: center; flex-grow: 1;">
                                    <a class="xRefID expanderText">${item.marginalSymbol}</a>
                                    ${combinedVersesDisplay}
                                </div>

                                <div style="${expandButtonStyle}"
                                     data-expansion-button="true"
                                     data-state="closed"
                                     data-item-id="${itemId}">

                                     &#xE639;
                                </div>

                            </div>

                            <div id="content-expand-${itemId}"
                                 style="display: none; padding: 0; margin: 0; color: inherit;">
                                 </div>
                        `;
                            }

                        } 
                        else {
                            contentHtml = `
                                <article id="verse-info-dialog" class="${item.className || ''}">
                                    ${item.content}
                                </article>
                            `;
                        }


                        if (key === 'notes') {
                            dynamicContent.appendChild(articleDiv);
                        } 
                        else if (key !== 'versions') {
                            articleDiv.innerHTML = contentHtml;
                            articleDiv.addEventListener('click', async (event) => {
                                onClickOnPage(articleDiv, event);
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
                    emptyDiv.textContent = `Il n'y a pas de ${emptyMessage} pour ce verset.`;
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
    const row = document.getElementById(itemId);
    const box = document.getElementById(`content-expand-${itemId}`);
    if (!row || !box) return;

    const btn = row.querySelector('[data-expansion-button]');
    const isHidden = box.style.display === 'none';

    if (isHidden) {
        // On privilégie le HTML déjà traité s'il existe (Full DOM), sinon on décode l'attribut standard
        const content = row.getAttribute('data-content-html-processed') || 
                        row.getAttribute('data-content-html')?.replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#39;/g, "'");
        
        box.innerHTML = content || '';
        box.style.display = 'block';
        if (btn) btn.innerHTML = '&#xE638;';
    } else {
        box.style.display = 'none';
        box.innerHTML = '';
        if (btn) btn.innerHTML = '&#xE639;';
    }
}

function showExtractPublicationDialog(article, dialogData, href) {
    showDialog({
        title: dialogData.title,
        type: 'publication',
        article: article,
        href: href,
        contentRenderer: (contentContainer) => {
            dialogData.extractsPublications.forEach((item, index) => {
                const headerBar = document.createElement('div');
                headerBar.style.cssText = `
                        display: flex;
                        align-items: center;
                        background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
                    `;

                if (item.imageUrl) {
                    const img = document.createElement('img');
                    img.src = 'file://' + item.imageUrl;
                    img.style.cssText = `
                            height: 45px;
                            width: 45px;
                            object-fit: cover;
                            margin-right: 10px;
                            user-select: none;
                        `;
                    headerBar.appendChild(img);
                }

                // Conteneur des textes
                const textContainer = document.createElement('div');
                textContainer.style.cssText = 'flex-grow: 1;';
                
                // Titre de la publication
                const pubTitle = document.createElement('div');
                pubTitle.textContent = item.publicationTitle;
                pubTitle.style.cssText = `
                      font-size: 14px;
                      font-weight: 700;
                      margin-top: 2px;
                      margin-bottom: 2px;
                      color: ${isDarkTheme() ? '#ffffff' : '#333333'};
                      line-height: 1.3;
                      white-space: nowrap;
                      overflow: hidden;
                      text-overflow: ellipsis;
                      user-select: none;
                    `;

                const subtitleText = document.createElement('div');
                    subtitleText.textContent = item.subtitleText;
                    subtitleText.style.cssText = `
                        font-size: 12px;
                        opacity: 0.9;
                        line-height: 1.4;
                        white-space: nowrap;
                        overflow: hidden;
                        text-overflow: ellipsis;
                        user-select: none;
                      `;
     
                textContainer.style.display = 'flex';
                textContainer.style.alignItems = 'center';
                textContainer.style.justifyContent = 'space-between';

                const textWrapper = document.createElement('div');
                textWrapper.style.overflow = 'hidden';
                textWrapper.appendChild(pubTitle);
                textWrapper.appendChild(subtitleText);

                const icon = document.createElement('span');
                icon.innerHTML = '&#xE63A;';
                icon.style.fontFamily = 'jw-icons-external';
                icon.style.fontSize = '20px';
                icon.style.marginLeft = '10px';
                icon.style.marginRight = '5px';
                icon.style.flexShrink = '0';
                icon.style.userSelect = 'none';

                textContainer.appendChild(textWrapper);
                textContainer.appendChild(icon);
                
                headerBar.addEventListener('click', function() {
                    window.flutter_inappwebview.callHandler('openMepsDocument', item);
                });

                headerBar.appendChild(textContainer);

                const article = document.createElement('div');
                article.innerHTML = `<article id="publication-dialog" class="${item.className}">${item.content}</article>`;
                article.style.cssText = `
                      position: relative;
                      padding-block: 16px;
                `;

                wrapWordsWithSpan(article, false);

                paragraphsDataDialog = fetchAllParagraphsOfTheArticle(article);

                item.blockRanges.forEach(b => {
                    if ((item.startParagraphId == null || b.Identifier >= item.startParagraphId) && (item.endParagraphId == null || b.Identifier <= item.endParagraphId)) {
                        paragraphInfo = paragraphsDataDialog.get(b.Identifier);
                        addBlockRange(
                            paragraphInfo,
                            b.StartToken,
                            b.EndToken,
                            b.UserMarkGuid,
                            b.StyleIndex,
                            b.ColorIndex
                        );
                    }
                });

                item.notes.forEach(note => {
                    const matchingBlockRange = item.blockRanges.find(b => b.UserMarkGuid === note.UserMarkGuid);
                    const paragraphInfo = paragraphsDataDialog.get(note.BlockIdentifier)

                    addNoteWithGuid(
                        article,
                        paragraphInfo.paragraphs[0],
                        matchingBlockRange?.UserMarkGuid || null,
                        note.Guid,
                        note.ColorIndex ?? 0,
                        false,
                        false
                    );
                });

                article.addEventListener('click', async (event) => {
                    onClickOnPage(article, event, item);
                });

                contentContainer.appendChild(headerBar);
                contentContainer.appendChild(article);

                // Séparateur entre les éléments (sauf le dernier)
                if (index < dialogData.extractsPublications.length - 1) {
                    const separator = document.createElement('div');
                    separator.style.cssText = `
                            height: 3px;
                            background: ${isDarkTheme() ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'};
                            margin: 12px 0px;
                        `;
                    contentContainer.appendChild(separator);
                }
            });

            contentContainer.querySelectorAll('img').forEach(img => {
                img.onerror = () => {
                    img.style.display = 'none';
                };
            });

            repositionAllNotes(contentContainer);
        }
    });
}

function showVerseCommentaryDialog(article, dialogData, href) {
    showDialog({
        title: dialogData.title,
        type: 'commentary',
        article: article,
        href: href,
        contentRenderer: (contentContainer) => {
            const headerBar = document.createElement('div');
            headerBar.style.cssText = `
                display: flex;
                align-items: center;
                background: ${isDarkTheme() ? '#000000' : '#f1f1f1'};
            `;

            const img = document.createElement('img');
            img.src = 'file://' + dialogData.imageUrl;
            img.style.cssText = `
                height: 45px;
                width: 45px;
                object-fit: cover;
                margin-right: 10px;
                user-select: none;
            `;

            const textContainer = document.createElement('div');
            textContainer.style.cssText = 'flex-grow: 1;';

            const verseTitleDiaplay = document.createElement('div');
            verseTitleDiaplay.textContent = dialogData.verseTitleDiaplay;
            verseTitleDiaplay.style.cssText = `
                font-size: 14px;
                font-weight: 700;
                margin-top: 2px;
                margin-bottom: 2px;
                line-height: 1.3;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                user-select: none;
            `;

            const bibleTitle = document.createElement('div');
            bibleTitle.textContent = dialogData.bibleTitle;
            bibleTitle.style.cssText = `
                font-size: 12px;
                opacity: 0.9;
                line-height: 1.4;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                user-select: none;
            `;

            textContainer.style.display = 'flex';
            textContainer.style.alignItems = 'center';
            textContainer.style.justifyContent = 'space-between';

            const textWrapper = document.createElement('div');
            textWrapper.style.overflow = 'hidden';
            textWrapper.appendChild(verseTitleDiaplay);
            textWrapper.appendChild(bibleTitle);

            const icon = document.createElement('span');
            icon.innerHTML = '&#xE63A;';
            icon.style.fontFamily = 'jw-icons-external';
            icon.style.fontSize = '20px';
            icon.style.marginLeft = '10px';
            icon.style.marginRight = '5px';
            icon.style.flexShrink = '0';
            icon.style.userSelect = 'none';

            textContainer.appendChild(textWrapper);
            textContainer.appendChild(icon);
                
            headerBar.addEventListener('click', function() {
                window.flutter_inappwebview?.callHandler('openMepsDocument', dialogData);
            });

            headerBar.appendChild(img);
            headerBar.appendChild(textContainer);

            const verse = document.createElement('div');
            verse.innerHTML = `<article id="verse-dialog" class="${dialogData.verseClassName}">${dialogData.verseContent}</article>`;
            verse.style.cssText = `
                position: relative;
                padding-top: 10px;
                padding-bottom: 5px;
            `;

            wrapWordsWithSpan(verse, true);

            paragraphsDataDialog = fetchAllParagraphsOfTheArticle(verse, true);

            dialogData.blockRanges.forEach(b => {
                const chapterNumber = b.Location?.ChapterNumber ?? null;

                const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                    p.chapterId === chapterNumber &&
                    p.id === b.Identifier
                );

                if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                    return;
                }
                addBlockRange(paragraphInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
            });

            dialogData.notes.forEach(note => {
                const matchingBlockRange = dialogData.blockRanges.find(
                    b => b.UserMarkGuid === note.UserMarkGuid
                );

                const chapterNumber = note.Location?.ChapterNumber ?? null;

                const paragraphInfo = [...paragraphsDataDialog.values()].find(p =>
                    p.chapterId === chapterNumber &&
                    p.id === note.BlockIdentifier
                );

                if (!paragraphInfo || !paragraphInfo.paragraphs?.length) {
                    return;
                }

                addNoteWithGuid(
                    verse,
                    paragraphInfo.paragraphs[0],
                    matchingBlockRange?.UserMarkGuid ?? null,
                    note.Guid,
                    note.ColorIndex ?? 0,
                    true,
                    false
                );
            });


            contentContainer.appendChild(headerBar);
            contentContainer.appendChild(verse);

            dialogData.commentaries.forEach((item) => {
                const articleCommentary = document.createElement('div');
                articleCommentary.innerHTML = `<article id="commentary-dialog" class="${item.className}">${item.content}</article>`;
                articleCommentary.style.cssText = `
                      padding-bottom: 16px;
                    `;

                articleCommentary.addEventListener('click', async (event) => {
                    onClickOnPage(articleCommentary, event, dialogData);
                });

                contentContainer.appendChild(articleCommentary);
            });
            repositionAllNotes(contentContainer);
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
            const footnoteContainer = document.createElement('div');
            footnoteContainer.style.cssText = `
                padding-inline: 20px;
            `;

            const footnoteContent = document.createElement('div');
            footnoteContent.innerHTML = footnote.content;
            footnoteContent.style.cssText = `
                line-height: 1.7;
                font-size: inherit;
            `;

            footnoteContent.addEventListener('click', async (event) => {
                onClickOnPage(footnoteContainer, event);
            });

            footnoteContainer.appendChild(footnoteContent);
            contentContainer.appendChild(footnoteContainer);
        }
    });
}

function getAllBlockRanges(guid) {
    return pageCenter.querySelectorAll(`[${blockRangeAttr}="${guid}"]`);
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

function addNoteToDocument(guid, isBible) {
    const firstParagraphEntry = Array.from(paragraphsData.values())[0];
    const firstParagraphElement = firstParagraphEntry ? firstParagraphEntry.paragraphs[0] : null;

    addNoteWithGuid(pageCenter, firstParagraphElement, null, guid, 0, isBible, true);
    closeToolbar();
    removeAllSelected();
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

    const note = pageCenter.querySelector(`[${noteAttr}="${noteGuid}"]`);
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

    const note = pageCenter.querySelector(`[${noteAttr}="${noteGuid}"]`);
    if (note) {
        let target = null;
        const blockId = note.getAttribute(noteBlockIdAttr);
        const idAttr = isBible() ? 'id' : 'data-pid';
        target = pageCenter.querySelector(`[${idAttr}="${blockId}"]`);

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

function whenClickOnParagraph(article, target, selector, idAttr, type) {
    const matched = target.closest(selector);

    const rawId = matched.getAttribute(idAttr);
    const parts = rawId.split('-');
    const finalId = (type === 'verse') ? parseInt(parts[2], 10) : parseInt(rawId, 10);

    const audioMarkers = article === pageCenter ? cachedPages[currentIndex]?.audiosMarkers : null;
    let hasAudio = false;
    if (audioMarkers) {
        for (let m of audioMarkers) {
            if ((type === 'verse' && m.verseNumber === finalId) || (type === 'paragraph' && m.mepsParagraphId === finalId)) {
                hasAudio = true; break;
            }
        }
    }

    const data = article === pageCenter ? paragraphsData.get(finalId) : paragraphsDataDialog.get(finalId);

    if (data) {
        showToolbar(article, data.paragraphs, finalId, hasAudio, type);
    }
}

function getTheFirstTargetParagraph(target) {
    if (!target || target.closest('#verse-dialog')) return null; // Ignore le dialogue
    const verse = target.closest('.v[id]');
    const idValue = verse ? verse.id.split('-')[2] : target.closest('[data-pid]')?.getAttribute('data-pid');
    return idValue ? paragraphsData.get(parseInt(idValue, 10)) : null;
}

async function loadUserdata() {
    const userdata = await window.flutter_inappwebview.callHandler('getUserdata');

    blockRanges = userdata.blockRanges;
    notes = userdata.notes;
    tags = userdata.tags;
    inputFields = userdata.inputFields;
    bookmarks = userdata.bookmarks;

    // Pré-indexation des données pour un accès plus rapide
    const blockRangeMap = new Map();
    const notesMap = new Map();
    const bookmarksMap = new Map();

    const firstParagraphEntry = Array.from(paragraphsData.values())[0];
    const firstParagraphElement = firstParagraphEntry ? firstParagraphEntry.paragraphs[0] : null;

    const processedNoteGuids = new Set(); // Pour éviter les doublons

    // Indexation des surlignages (BlockRanges)
    blockRanges.forEach(h => {
        // La clé utilise le format string "BlockType-Identifier" (ex: "2-15" ou "1-12")
        const key = `${h.BlockType}-${h.Identifier}`;
        if (!blockRangeMap.has(key)) blockRangeMap.set(key, []);
        blockRangeMap.get(key).push(h);
    });

    // Indexation des notes
    notes.forEach(n => {
        // GÉRER LE CAS BlockType === 0 (Notes générales)
        if (n.BlockIdentifier === null && n.BlockType === 0 && firstParagraphElement) {
            if (!processedNoteGuids.has(n.Guid)) {
                addNoteWithGuid(
                    pageCenter,
                    firstParagraphElement, // On attache au premier paragraphe
                    null,
                    n.Guid,
                    n.ColorIndex ?? 0,
                    isBible(),
                    false
                );
                processedNoteGuids.add(n.Guid);
            }
            return; // On passe à la note suivante
        }

        // Cas standard (BlockIdentifier présent)
        const key = n.BlockIdentifier;
        if (key !== null) {
            if (!notesMap.has(key)) notesMap.set(key, []);
            notesMap.get(key).push(n);
        }
    });

    // Indexation des signets (Bookmarks)
    bookmarks.forEach(b => {
        // CAS SPÉCIAL : BlockType 0 et Identifier null
        if (b.BlockIdentifier === null && b.BlockType === 0) {
            if (firstParagraphEntry) {
                // On l'ajoute directement au premier paragraphe disponible
                addBookmark(
                    pageCenter, 
                    firstParagraphEntry, 
                    b.BlockType, 
                    b.BlockIdentifier, 
                    b.Slot
                );
            }
            return; // On ne l'ajoute pas à la Map standard car il est déjà traité
        }

        // Cas standard : Clé "BlockType-Identifier"
        const key = `${b.BlockType}-${b.BlockIdentifier}`;
        bookmarksMap.set(key, b);
    });

    // Itérer sur paragraphsData (Map<int ID, { paragraphs: HTMLElement[], id: int, isVerse: boolean, ... }>)
    paragraphsData.forEach((paragraphInfo, numericId) => {

        // 1. Récupération des données du paragraphe
        const {paragraphs, isVerse} = paragraphInfo;

        const blockIdentifier = numericId;
        // blockType sera 2 pour 'v' (verset) ou 1 pour 'p' (paragraphe)
        const blockType = isVerse ? 2 : 1;

        // Clé utilisée pour les Maps indexées par chaîne (BlockType-Identifier)
        const idKey = `${blockType}-${blockIdentifier}`;

        // Gérer les signets (Bookmarks)
        const bookmark = bookmarksMap.get(idKey);
        if (bookmark) {
            addBookmark(pageCenter, paragraphInfo, bookmark.BlockType, bookmark.BlockIdentifier, bookmark.Slot);
        }

        // Gérer les surlignages (BlockRanges)
        const matchingBlockRanges = blockRangeMap.get(idKey) || [];
        matchingBlockRanges.forEach(b => {
            const paragraphInfo = paragraphsData.get(b.Identifier);
            addBlockRange(paragraphInfo, b.StartToken, b.EndToken, b.UserMarkGuid, b.StyleIndex, b.ColorIndex);
        });

        // Gérer les notes (Notes)
        const matchingNotes = notesMap.get(blockIdentifier) || [];
        matchingNotes.forEach(note => {
            if (processedNoteGuids.has(note.Guid)) return;

            const matchingBlockRange = matchingBlockRanges.find(h => h.UserMarkGuid === note.UserMarkGuid);

            addNoteWithGuid(
                pageCenter,
                paragraphs[0],
                matchingBlockRange?.UserMarkGuid || null,
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
                input.style.height = `${input.scrollHeight + 4}px`;
            }
        }

        const adjustTextareaHeight = (textarea) => {
            textarea.rows = 1;
            textarea.style.height = 'auto';
            textarea.style.height = `${textarea.scrollHeight + 4}px`;

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
        textarea.style.height = `${textarea.scrollHeight + 4}px`;
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
        return article.querySelector(`[data-pid="${id}"]`);
    }

    return null;
}

function getBookmarkPosition(article, target, bookmark) {
    // Calculer la position après le rendu
    const targetRect = target.getBoundingClientRect();
    const pageRect = article.getBoundingClientRect();
    const topRelativeToPage = targetRect.top - pageRect.top + article.scrollTop;

    bookmark.style.top = `${topRelativeToPage + 3}px`;
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
    if (!article) {
        article = pageCenter;
    }
    if (!paragraphInfo) {
        if(blockIdentifier != null) {
            paragraphInfo = paragraphsData.get(blockIdentifier);
            if (!paragraphInfo) return;
        }
        else {
            const firstParagraphEntry = Array.from(paragraphsData.values())[0];
            const firstParagraphElement = firstParagraphEntry ? firstParagraphEntry.paragraphs[0] : null;
            paragraphInfo = firstParagraphEntry;
            if (!paragraphInfo) return;
        }
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
    if (!article) {
        article = pageCenter;
    }
    const bookmark = article.querySelector(`.bookmark-icon[bookmark-id="${blockIdentifier}"]`);
    if (bookmark.getAttribute('slot') === slot.toString()) {
        bookmark.remove();
    }
}

function addBlockRange(paragraphInfo, startToken, endToken, guid, styleIndex, colorIndex) {
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
        if (next &&  next.classList.contains("escape") && index !== selectedTokens.length - 1) {
            next.classList.add(styleClass);
            next.setAttribute(blockRangeAttr, guid);
        }
    });
}

// Les variables globales (noteAttr, blockRangeAttr, isBible, colorsList, etc.) sont présumées définies ailleurs.
function getNotePosition(container, element, noteIndicator) {
    if (!element) return;

    if (!element.classList.contains('word') && !element.classList.contains('punctuation')) {
        element = element.querySelector('.word, .punctuation');
    }
    if (!element) return;

    // Trouver le parent positionné
    const positionedParent = noteIndicator.offsetParent;

    // Position réelle dans le flux
    let top = element.offsetTop;

    // Remonter la hiérarchie jusqu'au parent positionné
    let current = element.offsetParent;
    while (current && current !== positionedParent) {
        top += current.offsetTop;
        current = current.offsetParent;
    }

    // Centrage vertical
    top += (element.offsetHeight - 15) / 2;

    noteIndicator.style.top = `${top}px`;
}

function repositionAllNotes(container) {
    const notes = container.querySelectorAll(`[${noteAttr}]`);
    
    notes.forEach(note => {
        // 1. Initialiser l'article par défaut (le container)
        let article = container;

        // 2. Correction : hasAttribute au lieu de containsAttribute
        if (note.hasAttribute(notePubClassAttr) && note.hasAttribute(noteMlClassAttr)) {
            const pubClass = note.getAttribute(notePubClassAttr);
            const mlClass = note.getAttribute(noteMlClassAttr);
            const docIdClass = note.getAttribute(noteDocIdClassAttr);
            
            // On s'assure que les classes ne sont pas vides
            if (pubClass && mlClass) {
                const selector = docIdClass ? `article.${pubClass}.${mlClass}.${docIdClass}` : `article.${pubClass}.${mlClass}`;
                const foundArticle = container.querySelector(selector);
                
                // On ne remplace 'article' que si on a trouvé une correspondance
                if (foundArticle) {
                    article = foundArticle;
                }
            }
        }

        let target = null;
        
        // 3. Recherche de la cible (target) dans l'article trouvé
        if (note.hasAttribute(noteBlockRangeAttr)) {
            const userMarkGuid = note.getAttribute(noteBlockRangeAttr);
            target = article.querySelector(`[${blockRangeAttr}="${userMarkGuid}"]`);
        } 
        else if (note.hasAttribute(noteBlockIdAttr)) {
            const blockId = note.getAttribute(noteBlockIdAttr);
            // Vérification si l'article contient des data-pid pour choisir l'attribut de recherche
            const hasDataPid = article.querySelector('[data-pid]') !== null;
            const idAttr = hasDataPid ? 'data-pid' : 'id';
            target = article.querySelector(`[${idAttr}="${blockId}"]`);
        }

        // 4. Repositionnement si la cible existe
        if (target) {
            getNotePosition(article, target, note);
        }
    });
}

let resizeTimer;
function optimizedResize(contentContainer) {
    // On annule le repositionnement précédent s'il n'a pas encore eu lieu
    clearTimeout(resizeTimer);

    // On lance le repositionnement après 50ms de "calme"
    resizeTimer = setTimeout(() => {
        repositionAllNotes(contentContainer);
    }, 50); 
}

function addNoteWithGuid(article, target, userMarkGuid, noteGuid, colorIndex, isBible, open) {
    if (!target) {
        const blockRangeTarget = article.querySelector(`[${blockRangeAttr}="${userMarkGuid}"]`);
        if (blockRangeTarget) {
            target = isBible ? blockRangeTarget.closest('.v') : blockRangeTarget.closest('p');
        }
    }

    if (!target) {
        return;
    }

    const idAttr = isBible ? 'id' : 'data-pid';
    const articleElement = article.querySelector('article');
    const isRtl = articleElement.classList.contains('dir-rtl') ?? false;

    // Chercher le premier élément surligné si userMarkGuid est donné
    let firstBlockRangeElement = null;
    if (userMarkGuid) {
        firstBlockRangeElement = target.querySelector(`[${blockRangeAttr}="${userMarkGuid}"]`);
    }

    // Créer le carré de note
    const noteIndicator = document.createElement('div');
    noteIndicator.className = 'note-indicator';
    noteIndicator.setAttribute(noteAttr, noteGuid);
    if (userMarkGuid) {
        noteIndicator.setAttribute(noteBlockRangeAttr, userMarkGuid);
    }
    noteIndicator.setAttribute(noteBlockIdAttr, target.getAttribute(idAttr));
    const classes = Array.from(articleElement.classList);
    const pubClass = classes.find(cls => cls.startsWith('pub-'));
    const mlClass = classes.find(cls => cls.startsWith('ml-'));
    const docIdClass = classes.find(cls => cls.startsWith('docId-'));

    noteIndicator.setAttribute(notePubClassAttr, pubClass);
    noteIndicator.setAttribute(noteMlClassAttr, mlClass);
    noteIndicator.setAttribute(noteDocIdClassAttr, docIdClass);

    // Couleurs
    const colorName = colorsList[colorIndex] || "gray";
    noteIndicator.classList.add(`note-indicator-${colorName}`);

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
            } else {
                noteIndicator.style.left = '3.3px';
                noteIndicator.style.right = 'auto';
            }
        } else {
            getNotePosition(article, target, noteIndicator);

            // Positionner à droite si élément est à droite
            const elementRect = target.getBoundingClientRect();
            const windowWidth = window.innerWidth || document.documentElement.clientWidth;

            if (elementRect.left > windowWidth / 2) {
                noteIndicator.style.right = isRtl ? 'auto' : '3.3px';
                noteIndicator.style.left = isRtl ? '3.3px' : 'auto';
            } else {
                noteIndicator.style.left = isRtl ? 'auto' : '3.3px';
                noteIndicator.style.right = isRtl ? '3.3px' : 'auto';
            }
        }
    }, 0);
    // ----------------------------------------------------------------------

    if (open) {
        openNoteDialog(noteGuid, userMarkGuid);
    }
}

// Fonction utilitaire pour supprimer un surlignage spécifique par son UUID
function removeBlockRangeByGuid(userMarkGuid) {
    const blockRangeElements = document.querySelectorAll(`[${blockRangeAttr}="${userMarkGuid}"]`);
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
    const blockRangeElements = pageCenter.querySelectorAll(`[${blockRangeAttr}="${userMarkGuid}"]`);
    const newStyleClass = getStyleClass(styleIndex, colorIndex);
    const newNoteClass = getNoteClass(colorIndex, true);

    blockRangeElements.forEach(element => {
        removeAllStylesClasses(element);
        element.classList.add(newStyleClass);
    });

    const noteElements = pageCenter.querySelectorAll(`[${noteBlockRangeAttr}="${userMarkGuid}"]`);

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
    const note = pageCenter.querySelector(`[${noteAttr}="${noteGuid}"]`);
    const newNoteClass = getNoteClass(newColorIndex, true);

    removeNoteClasses(note);
    note.classList.add(newNoteClass);

    const {
        styleIndex: targetStyleIndex,
        colorIndex: targetColorIndex
    } = getActiveStyleAndColorIndex(note, currentStyleIndex, newColorIndex);

    if (note.hasAttribute(noteBlockRangeAttr)) {
        const userMarkGuid = note.getAttribute(noteBlockRangeAttr);
        blockRangeElements = pageCenter.querySelectorAll(`[${blockRangeAttr}="${userMarkGuid}"]`);
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

function resizeFont(page, size) {
    page = page ?? pageCenter;
    document.body.style.fontSize = size + 'px';
    resizeAllTextAreaHeight(page);
    repositionAllNotes(page);
    repositionAllBookmarks(page);
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

function showScrollBar(init = false) {
    clearTimeout(scrollBarTimeout);

    const scrollHeight = pageCenter.scrollHeight;
    const clientHeight = pageCenter.clientHeight;

    // --- 0. GESTION DU CONTENU NON SCROLLABLE ---
    // Si le contenu tient dans la page sans scroller
    if ((scrollHeight - 10) <= clientHeight) {
        hideScrollBar();
        return; // On stoppe tout
    }

    scrollBar.style.transition = 'none';
    scrollBar.style.display = 'block';
    scrollBar.offsetHeight;
    scrollBar.style.transition = 'opacity 0.5s ease-in-out';
    scrollBar.style.opacity = '1';

    if(!init) {
        scrollBarTimeout = setTimeout(hideScrollBar, 500);
    }
}

function setupScrollBar() {
    scrollBar = document.createElement('img');
    scrollBar.className = 'scroll-bar';
    scrollBar.src = speedBarScroll;
    scrollBar.style.transition = 'opacity 0.5s ease-in-out'; // Pour une disparition en douceur
    scrollBar.style.opacity = '0';

    scrollBar.addEventListener("touchstart", (e) => {
        if (e.touches.length !== 1) return;
        isTouchDragging = true;
        e.preventDefault(); // bloque le scroll natif
    }, {
        passive: false
    });

    scrollBar.addEventListener("touchmove", (e) => {
        if (!isTouchDragging) return;

        const touchY = controlsVisible ? e.touches[0].clientY - scrollBar.offsetHeight : e.touches[0].clientY;

        // Calcul des hauteurs de barres en fonction de l'état des contrôles
        const currentAppBarHeight = APPBAR_FIXED_HEIGHT;

        // La hauteur visible dépend maintenant de l'état des contrôles
        const visibleHeight = window.innerHeight - currentAppBarHeight - bottomNavBarHeight;

        // Les positions min et max de la scrollbar dépendent aussi de l'état des contrôles
        const minTop = currentAppBarHeight;
        const maxTop = currentAppBarHeight + (visibleHeight - scrollBar.offsetHeight);

        const clampedTop = Math.max(minTop, Math.min(touchY, maxTop));

        // Le ratio de défilement doit être calculé par rapport à la zone visible
        const scrollRatio = (clampedTop - minTop) / (maxTop - minTop);

        const scrollableHeight = pageCenter.scrollHeight - pageCenter.clientHeight;
        pageCenter.scrollTop = scrollRatio * scrollableHeight;
        e.preventDefault();
    }, {
        passive: false
    });

    scrollBar.addEventListener("touchend", () => {
        isTouchDragging = false;
    });

    scrollBar.addEventListener("touchcancel", () => {
        isTouchDragging = false;
    });

    document.body.appendChild(scrollBar);
}

// --- VARIABLES D'ÉTAT (Assure-toi qu'elles sont déclarées) ---
let lastScrollTop = 0;
let lastDirection = null;
let directionChangePending = false;
let directionChangeStartTime = 0;
let directionChangeStartScroll = 0;
let directionChangeTargetDirection = null;
let isNavigating = false;

let appBarHeight = APPBAR_FIXED_HEIGHT; // hauteur de l'AppBar
let bottomNavBarHeight = controlsVisible ? (BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0)) : 0;

const DIRECTION_CHANGE_THRESHOLD_MS = 250;
const DIRECTION_CHANGE_THRESHOLD_PX = 40;

function handleScroll(pageElement) {
    if (isNavigating || isLongPressing || isChangingParagraph || !isFullscreenMode) return;

    const scrollHeight = pageElement.scrollHeight;
    const clientHeight = pageElement.clientHeight;

    // --- 0. GESTION DU CONTENU NON SCROLLABLE ---
    // Si le contenu tient dans la page sans scroller

    if ((scrollHeight - 5) <= clientHeight) {
        hideScrollBar();
        return; // On stoppe tout
    }

    const targetIndex = currentIndex;
    const scrollTop = pageElement.scrollTop;

    // 2. SAUVEGARDE : On enregistre la position pour l'index correspondant
    if (targetIndex >= 0) {
        scrollTopPages[targetIndex] = scrollTop;
    }
    
    // Appelle ta fonction pour afficher et gérer le timer de la scrollbar
    showScrollBar();
    closeToolbar();

    // --- GESTION DE LA DIRECTION ET FLUTTER ---
    const scrollDelta = scrollTop - lastScrollTop;
    let scrollDirection = scrollDelta > 0 ? "down" : scrollDelta < 0 ? "up" : "none";
    const now = Date.now();

    if (scrollTop === 0) scrollDirection = "up";

    if (scrollDirection !== "none" && scrollDirection !== lastDirection && !directionChangePending) {
        directionChangePending = true;
        directionChangeStartTime = now;
        directionChangeStartScroll = scrollTop;
        directionChangeTargetDirection = scrollDirection;
    }

    if (directionChangePending && scrollDirection === directionChangeTargetDirection) {
        const timeDiff = now - directionChangeStartTime;
        const scrollDiff = Math.abs(scrollTop - directionChangeStartScroll);

        if (scrollTop === 0 || (timeDiff < DIRECTION_CHANGE_THRESHOLD_MS && scrollDiff > DIRECTION_CHANGE_THRESHOLD_PX)) {
            window.flutter_inappwebview.callHandler('onScroll', scrollTop, scrollDirection);
            lastDirection = scrollDirection;
            directionChangePending = false;

            const floatingButton = document.getElementById('dialogFloatingButton');
            if (scrollDirection === 'down') {
                controlsVisible = false;
                if (floatingButton) {
                    floatingButton.style.opacity = '0';
                    floatingButton.style.pointerEvents = 'none';
                }
            } else if (scrollDirection === 'up') {
                controlsVisible = true;
                if (floatingButton) {
                    floatingButton.style.opacity = '1';
                    floatingButton.style.pointerEvents = 'auto';
                }
            }
        } else if (timeDiff >= DIRECTION_CHANGE_THRESHOLD_MS) {
            directionChangePending = false;
        }
    }

    lastScrollTop = scrollTop;

    // --- MISE À JOUR DE LA POSITION DE TA SCROLLBAR IMAGE ---
    // On utilise exactement ta logique de calcul des hauteurs
    const currentAppBarHeight = APPBAR_FIXED_HEIGHT;
    bottomNavBarHeight = controlsVisible ? (BOTTOMNAVBAR_FIXED_HEIGHT + (audioPlayerVisible ? AUDIO_PLAYER_HEIGHT : 0)) : 0;
    const visibleHeight = window.innerHeight - currentAppBarHeight - bottomNavBarHeight;
    const scrollableHeight = scrollHeight - clientHeight;

    if (scrollableHeight > 0) {
        const scrollRatio = scrollTop / scrollableHeight;
        // On calcule la position Top pour que l'image de la scrollbar suive le document
        const scrollBarTop = currentAppBarHeight + (visibleHeight - scrollBar.offsetHeight) * scrollRatio;
        
        // On applique le style à l'élément image créé dans setupScrollBar
        scrollBar.style.top = `${scrollBarTop}px`;
    }
}

// Attachement des écouteurs
pageCenter.addEventListener("scroll", () => handleScroll(pageCenter));

// Variables globales
let currentGuid = '';
let pressTimer = null;
let pressTimerMagnifier = null;
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
let isZooming = false;

// Variables zoom/pan
let scale = 1;
let posX = 0;
let posY = 0;
let startPosX = 0;
let startPosY = 0;
let startTouchX = 0;
let startTouchY = 0;
let initialPinchDistance = 0;
let initialScale = 1;
let pinchCenterX = 0;
let pinchCenterY = 0;
let touchStartElement = null;

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

async function onClickOnPage(article, event, infoPublication = null) {
    const target = event.target;
    const tagName = target.tagName;

    const closeToolbarResult = closeToolbar(article);

    if (document.body.classList.contains('selection-active') || isSelecting) {
        removeAllSelected();
    }

    // 1. Ignorer les clics sur les champs de formulaire
    if (tagName === 'TEXTAREA' || tagName === 'INPUT') {
        return;
    }

    if (tagName === 'IMG') {
        const videoLink = target.closest('a[data-video]');

        // 2. Vérifie si un tel élément parent a été trouvé
        const isVideoThumbnail = videoLink !== null;

        if (isVideoThumbnail) {
            const videoData = videoLink.getAttribute('data-video');
            return; // Sortie : on ne traite PAS comme une simple image
        }

        // Si ce n'est pas un lien vidéo, on le traite comme une image normale
        window.flutter_inappwebview.callHandler('onImageClick', target.src);
        return;
    }

    const linkHandled = await onClickOnLink(article, target, event, infoPublication);

    if (linkHandled || closeToolbarResult || target.closest('.gen-field')) {
        return;
    }

    // Si on a une cible avec un blockRangeAttr, on affiche la toolbar de surlignage
    const blockRangeId = target.getAttribute(blockRangeAttr);
    if (blockRangeId && article === pageCenter) {
        showToolbarBlockRange(target, blockRangeId, false);
        return;
    }

    // Sinon, on gère le clic sur le paragraphe/verset
    if (isBible()) {
        whenClickOnParagraph(article, target, '.v', 'id', 'verse');
    } 
    else {
        whenClickOnParagraph(article, target, '[data-pid]', 'data-pid', 'paragraph');
    }
}

async function onClickOnLink(article, target, event, infoPublication = null) {
    const matchedElement = target.closest('a');
    const classList = target.classList;

    // 1. Gestion des liens <a>
    if (matchedElement) {
        const href = matchedElement.getAttribute('href') || '';
        const linkClass = matchedElement.classList;

        // Cas : Aller à une note en scrollant (#)
        if (href.startsWith('#')) {
            // empêche le comportement par défaut
            event.preventDefault();

            const targetElement = article.querySelector(href);
            if (targetElement) {
                const elementToScroll = (targetElement.tagName === 'SPAN' && targetElement.innerHTML === '') 
                    ? targetElement.parentElement 
                    : targetElement;

                elementToScroll.scrollIntoView({ 
                    behavior: 'smooth', 
                    block: 'center' 
                });
            }
        } 
        // Cas : Versets (b)
        else if (linkClass.contains('b') || href.startsWith('jwpub://b/')) {
            const clickedHref = href;
            const neighbors = [];
        
            // 1. Chercher tous les voisins PRÉCÉDENTS (à gauche)
            let prev = matchedElement.previousElementSibling;
            const leftNeighbors = [];
            while (prev && (prev.classList.contains('b') || prev.getAttribute('href')?.startsWith('jwpub://b/'))) {
                leftNeighbors.unshift(prev.getAttribute('href')); // unshift pour garder l'ordre chronologique
                prev = prev.previousElementSibling;
            }
            neighbors.push(...leftNeighbors);
        
            // 2. Chercher tous les voisins SUIVANTS (à droite)
            let next = matchedElement.nextElementSibling;
            while (next && (next.classList.contains('b') || next.getAttribute('href')?.startsWith('jwpub://b/'))) {
                neighbors.push(next.getAttribute('href'));
                next = next.nextElementSibling;
            }
        
            const payload = {
                'clicked': clickedHref,
                'others': neighbors
            };
        
            const verses = await window.flutter_inappwebview.callHandler('fetchVerses', payload); 
            if (verses) {
                showVerseDialog(article, verses, payload, false);
            }
        }
        // Cas : Extrait de commentaires (jwpub://c/)
        else if (href.startsWith('jwpub://c/')) {
            const commentary = await window.flutter_inappwebview.callHandler('fetchCommentaries', href);
            if (commentary) showVerseCommentaryDialog(article, commentary, href);
        }
        // Cas : Extraits de publications (xt)
        else if (linkClass.contains('xt') || href.startsWith('jwpub://p/')) {
            const extract = await window.flutter_inappwebview.callHandler('fetchExtractPublication', href, infoPublication);
            if (extract) showExtractPublicationDialog(article, extract, href);
        } 
        return true;
    }

    if (article !== pageCenter) {
        return false;
    }

    // 2. Gestion des éléments spécifiques (notes, références) via la cible directe
    let handled = false;

    if (classList.contains('fn')) {
        const fnid = target.getAttribute('data-fnid');
        const footnote = await window.flutter_inappwebview.callHandler('fetchFootnote', fnid);
        showFootNoteDialog(article, footnote, `footnote-${fnid}`);
        handled = true;
    } 
    else if (classList.contains('m')) {
        const mid = target.getAttribute('data-mid');
        const versesRef = await window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
        showVerseReferencesDialog(article, versesRef, `verse-references-${mid}`);
        handled = true;
    }

    if (handled) {
        return true;
    }

    return false;
}

function selectWord(range, textNode, offset) {
    const text = textNode.textContent;

    // Détermine le point de départ du balayage (offset est la position du curseur/doigt)
    let left = offset;
    let right = offset;

    // On recule tant qu'on rencontre des caractères non-espace/non-séparateur
    while (left > 0 && /\w/.test(text[left - 1])) {
        left--;
    }

    // On avance tant qu'on rencontre des caractères non-espace/non-séparateur
    while (right < text.length && /\w/.test(text[right])) {
        right++;
    }

    // 3. Applique les limites à la Range
    range.setStart(textNode, left);
    range.setEnd(textNode, right);
}

function toggleSelection(active) {
    if (active) {
        document.body.classList.add('selection-active');
    } else {
        document.body.classList.remove('selection-active');
    }
}

// Variable pour ignorer le premier selectionchange lors de l'appui long
let isInitialSelectionChange = false;

// Empêche le menu contextuel du navigateur (qui apparaît suite à un clic droit ou un appui long)
pageCenter.addEventListener('contextmenu', (event) => {
    const linkElement = event.target.closest('a');

    setLongPressing(false);

    if ((isLongTouchFix || isSelecting) && !isReadingMode && !linkElement) {
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
        if (linkElement) {
            event.preventDefault();
            event.stopPropagation();

            (async () => { await onClickOnLink(pageCenter, linkElement, event); })();
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
    }
}, false);

document.addEventListener('selectionchange', () => {
    // NOUVEAU : Ignore le selectionchange si c'est la sélection initiale
    if (isInitialSelectionChange) {
        return;
    }
});

pageCenter.addEventListener('click', (event) => {
    event.stopPropagation();

    firstLongPressTarget = null;
    lastLongPressTarget = null;
    isLongPressing = false;

    onClickOnPage(pageCenter, event);
});

/**************
 * SURLIGNAGE DES MOTS
 **************/
let oldStylesMap = new Map();
let tempTokensByGuid = new Map();
const magnifierSize = 120;
const zoomFactor = 1.15;
const visibleParagraphIds = new Set();
let magnifierElementMap = new Map();

pageCenter.addEventListener('touchstart', (event) => {
    if (isReadingMode || isSelecting) return;

    if (pressTimer) clearTimeout(pressTimer);
    firstLongPressTarget = event.target;

    const targetClass = firstLongPressTarget?.classList;

    pressTimer = setTimeout(() => {
        closeToolbar();
        toggleSelection(true);

        if (firstLongPressTarget && (targetClass.contains('word') || targetClass.contains('punctuation'))) {
            isDragging = false;
            setLongPressing(true);
            isLongTouchFix = true;
            currentGuid = generateGuid();

            requestAnimationFrame(() => {
                 prepareMagnifier();
            });
        }
    }, 250);
}, { passive: false });

const handleTouchMove = throttle((event) => {
    if (isReadingMode) return;

    isLongTouchFix = false;

    if (document.body.classList.contains('selection-active') && !isSelecting) {
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
    } else if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
    }
}, 16);

pageCenter.addEventListener('touchmove', handleTouchMove, {
    passive: false
});

pageCenter.addEventListener('touchend', () => {
    if (isReadingMode) return;

    if (isLongPressing) {
        hideMagnifier();
        onLongPressEnd();
        magnifierElementMap.clear();
        firstLongPressTarget = null;
        lastLongPressTarget = null;
    } 
    if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
    }
}, { passive: true });

const visibilityObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        // On récupère l'ID (pid ou verse id)
        const idAttr = entry.target.getAttribute('data-pid') || (entry.target.classList.contains('v') ? entry.target.id.split('-')[2] : null);
        
        if (!idAttr) return;
        const id = parseInt(idAttr, 10);

        if (entry.isIntersecting) {
            visibleParagraphIds.add(id);
        } else {
            visibleParagraphIds.delete(id);
        }
    });
}, { threshold: 0.1 }); // Déclenche dès que 10% du paragraphe est visible

// À appeler après fetchAllParagraphsOfTheArticle
function observeParagraphs(paragraphsData) {
    paragraphsData.forEach((data) => {
        data.paragraphs.forEach(p => visibilityObserver.observe(p));
    });
}

function getClosestElementHorizontally(x, y) {
    let closest = null;
    let minDistance = Infinity;

    // On ne boucle QUE sur les paragraphes de l'article principal qui sont visibles
    for (const id of visibleParagraphIds) {
        const pData = paragraphsData.get(id);
        if (!pData) continue;
        
        // On s'assure que ce paragraphe n'appartient PAS à un dialogue
        // (Normalement ton fetch ne les a pas mis dans paragraphsData, mais on sécurise)
        if (pData.paragraphs[0].closest('.dialog-content')) continue;

        ensureParagraphIndexed(pData);
        const result = findInTokens(pData.wordAndPunctTokens, x, y);
        if (result.distance < minDistance) {
            minDistance = result.distance;
            closest = result.el;
        }
    }

    return closest;
}

function findInTokens(tokens, x, y) {
    let bestEl = null;
    let minD = Infinity;
    
    for (const el of tokens) {
        const rects = el.getClientRects();
        for (const rect of rects) {
            // On vérifie si le Y du doigt est bien sur la ligne du mot
            if (y >= rect.top - 5 && y <= rect.bottom + 5) { // Marge de 5px pour le confort
                const elCenterX = rect.left + rect.width / 2;
                const d = Math.abs(x - elCenterX);
                if (d < minD) {
                    minD = d;
                    bestEl = el;
                }
            }
        }
    }
    return { el: bestEl, distance: minD };
}

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
        token.classList.remove(`note-${color}`);
        token.classList.remove(`note-indicator-${color}`);
    });
}

function getNoteClass(colorIndex, isIndicator) {
    console.log('noteClass = ${colorIndex}');
    const colorName = colorsList[colorIndex ?? 0];

    if (colorName) {
        // Utilisation des template literals (accents graves) pour construire la classe
        return isIndicator ? `note-indicator-${colorName}` : `note-${colorName}`
    }

    // Si l'index est 0 ou en dehors des limites du tableau
    return isIndicator ? `note-indicator-gray` : `note-gray`;
}

function applyTempStyle(token, styleIndex, styleClass) {
    const cfg = getStyleConfig(styleIndex);
    const existingId = token.getAttribute(blockRangeAttr);

    if (existingId && existingId !== currentGuid) {
        let perToken = oldStylesMap.get(token);
        if (!perToken) {
            perToken = new Map();
            oldStylesMap.set(token, perToken);
        }
        if (!perToken.has(styleIndex)) {
            const oldClass = Array.from(token.classList).find(c => cfg.classes.includes(c));
            perToken.set(styleIndex, {
                styleId: existingId,
                styleClass: oldClass || null
            });
        }
    }

    // Mise à jour de l'élément principal
    removeStyleClasses(token, styleIndex);
    token.classList.add(styleClass);
    token.setAttribute(blockRangeAttr, currentGuid);

    // SYNCHRO LOUPE : Mise à jour du jumeau
    const twin = magnifierElementMap.get(token);
    if (twin) {
        removeStyleClasses(twin, styleIndex);
        twin.classList.add(styleClass);
    }
}

function restoreTokenIfNeeded(token, styleIndex) {
    const perToken = oldStylesMap.get(token);
    const twin = magnifierElementMap.get(token);
    
    removeStyleClasses(token, styleIndex);
    if (twin) removeStyleClasses(twin, styleIndex);

    if (perToken && perToken.has(styleIndex)) {
        const { styleId, styleClass } = perToken.get(styleIndex);
        perToken.delete(styleIndex);
        if (perToken.size === 0) oldStylesMap.delete(token);

        token.setAttribute(blockRangeAttr, styleId || "");
        if (styleClass) {
            token.classList.add(styleClass);
            if (twin) twin.classList.add(styleClass);
        }
    } else {
        token.removeAttribute(blockRangeAttr);
    }
}

function updateTempStyle() {
    if (!isLongPressing || !firstLongPressTarget || !lastLongPressTarget || !currentGuid) return;

    const firstPInfo = getTheFirstTargetParagraph(firstLongPressTarget);
    const lastPInfo = getTheFirstTargetParagraph(lastLongPressTarget);
    if (!firstPInfo || !lastPInfo) return;

    const { styleIndex: tStyleIdx, colorIndex: tColorIdx } = getActiveStyleAndColorIndex(firstLongPressTarget);
    const styleClass = getStyleClass(tStyleIdx, tColorIdx);

    const orderedIds = Array.from(paragraphsData.keys());
    const firstIdxDOM = orderedIds.indexOf(firstPInfo.id);
    const lastIdxDOM = orderedIds.indexOf(lastPInfo.id);

    const fromIdx = Math.min(firstIdxDOM, lastIdxDOM);
    const toIdx = Math.max(firstIdxDOM, lastIdxDOM);

    // Utilisation de requestAnimationFrame pour grouper les changements visuels
    requestAnimationFrame(() => {
        if (!isLongPressing) return;

        const newTokens = new Set();

        for (let i = fromIdx; i <= toIdx; i++) {
            const pData = paragraphsData.get(orderedIds[i]);
            if (!pData) continue;

            ensureParagraphIndexed(pData);
            const { wordAndPunctTokens, allTokens, indexInAll } = pData;

            let startInP, endInP;
            if (firstIdxDOM === lastIdxDOM) {
                startInP = wordAndPunctTokens.indexOf(firstLongPressTarget);
                endInP = wordAndPunctTokens.indexOf(lastLongPressTarget);
            } else if (i === firstIdxDOM) {
                startInP = wordAndPunctTokens.indexOf(firstLongPressTarget);
                endInP = (firstIdxDOM < lastIdxDOM) ? wordAndPunctTokens.length - 1 : 0;
            } else if (i === lastIdxDOM) {
                startInP = (firstIdxDOM < lastIdxDOM) ? 0 : wordAndPunctTokens.length - 1;
                endInP = wordAndPunctTokens.indexOf(lastLongPressTarget);
            } else {
                startInP = 0;
                endInP = wordAndPunctTokens.length - 1;
            }

            const realStart = Math.min(startInP, endInP);
            const realEnd = Math.max(startInP, endInP);

            for (let j = realStart; j <= realEnd; j++) {
                const token = wordAndPunctTokens[j];
                if (!token) continue;
                newTokens.add(token);
                
                const idx = indexInAll.get(token);
                // Inclusion intelligente des espaces (tokens .escape)
                if (j < realEnd || (i < toIdx)) {
                    const next = allTokens[idx + 1];
                    if (next?.classList.contains('escape')) newTokens.add(next);
                }
            }
        }

        let currentTokens = tempTokensByGuid.get(currentGuid) || new Set();
        
        // On n'applique le style que sur ce qui est nouveau
        newTokens.forEach(t => {
            if (!currentTokens.has(t)) {
                applyTempStyle(t, tStyleIdx, styleClass); // Gère aussi la loupe
                currentTokens.add(t);
            }
        });

        // On restaure uniquement ce qui est sorti de la sélection
        currentTokens.forEach(t => {
            if (!newTokens.has(t)) {
                restoreTokenIfNeeded(t, tStyleIdx); // Gère aussi la loupe
                currentTokens.delete(t);
            }
        });

        tempTokensByGuid.set(currentGuid, currentTokens);
    });
}

async function onLongPressEnd() {
    try {
        const { styleIndex: finalStyleIndex, colorIndex: finalColorIndex } = getActiveStyleAndColorIndex(firstLongPressTarget);

        let tempBlockRangesElements = tempTokensByGuid.get(currentGuid);
        if (!tempBlockRangesElements) {
            tempBlockRangesElements = new Set(
                pageCenter.querySelectorAll(`[${blockRangeAttr}="${currentGuid}"]`)
            );
            tempTokensByGuid.set(currentGuid, tempBlockRangesElements);
        }

        const finalClass = getStyleClass(finalStyleIndex, finalColorIndex);

        tempBlockRangesElements.forEach(token => {
            // 1. On s'assure que le token principal a la classe et le GUID final
            token.classList.add(finalClass);
            token.setAttribute(blockRangeAttr, currentGuid);

            // 2. On fait de même pour le jumeau dans la loupe s'il existe encore
            const twin = magnifierElementMap.get(token);
            if (twin) {
                twin.classList.add(finalClass);
            }
        });

        // Tri des tokens pour garantir l'ordre logique (début -> fin)
        const tempArray = Array.from(tempBlockRangesElements).sort((a, b) =>
            a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
        );

        // Gestion de la fusion des styles (si on surligne par-dessus un ancien)
        oldStylesMap.forEach((perToken, token) => {
            if (!tempBlockRangesElements.has(token)) return;
            perToken.forEach((value) => {
                if (value.styleId) {
                    const newClass = getStyleClass(finalStyleIndex, finalColorIndex);
                    const elems = Array.from(
                        pageCenter.querySelectorAll(`[${blockRangeAttr}="${value.styleId}"]`)
                    );
                    elems.forEach(el => {
                        removeAllStylesClasses(el);
                        el.classList.add(newClass);
                        el.setAttribute(blockRangeAttr, currentGuid);
                        tempBlockRangesElements.add(el);
                    });

                    window.flutter_inappwebview.callHandler('removeBlockRange', {
                        UserMarkGuid: value.styleId,
                        NewUserMarkGuid: currentGuid,
                        ShowAlertDialog: false
                    });
                }
            });
        });

        oldStylesMap.clear();

        // Affichage de la toolbar à la position du premier mot
        if (tempArray.length > 0) {
            showToolbarBlockRange(tempArray[0], currentGuid, true);
        }

        // Groupement par paragraphe pour l'envoi Flutter
        const blockRangesToSend = [];
        let currentParagraphId = -1;
        let tokensBuffer = [];

        tempArray.forEach(element => {
            const pInfo = getTheFirstTargetParagraph(element);
            if (!pInfo) return;

            if (pInfo.id !== currentParagraphId) {
                if (tokensBuffer.length > 0) {
                    blockRangesToSend.push(createRangeData(tokensBuffer, currentParagraphId, paragraphsData.get(currentParagraphId)));
                }
                currentParagraphId = pInfo.id;
                tokensBuffer = [element];
            } else {
                tokensBuffer.push(element);
            }
        });

        // Dernier buffer
        if (tokensBuffer.length > 0) {
            blockRangesToSend.push(createRangeData(tokensBuffer, currentParagraphId, paragraphsData.get(currentParagraphId)));
        }

        await window.flutter_inappwebview.callHandler(
            'addBlockRanges',
            currentGuid,
            finalStyleIndex,
            finalColorIndex,
            blockRangesToSend
        );

        tempTokensByGuid.delete(currentGuid);

    } catch (err) {
        console.error('Error in onLongPressEnd:', err);
    } 
    finally {
        // Important : Nettoyer la map des jumeaux pour libérer la mémoire
        magnifierElementMap.clear();
        currentGuid = '';
        firstLongPressTarget = null;
        lastLongPressTarget = null;
    }
}

// Fonction utilitaire pour formater la donnée vers Flutter
function createRangeData(tokenArray, pid, pData) {
    const { wordAndPunctTokens, isVerse } = pData;
    const tokensInP = tokenArray.filter(t => wordAndPunctTokens.includes(t));
    const startIdx = wordAndPunctTokens.indexOf(tokensInP[0]);
    const endIdx = wordAndPunctTokens.indexOf(tokensInP[tokensInP.length - 1]);

    return {
        BlockType: isVerse ? 2 : 1,
        Identifier: pid,
        StartToken: Math.min(startIdx, endIdx),
        EndToken: Math.max(startIdx, endIdx),
    };
}

function prepareMagnifier() {
    // 1. Nettoyage
    magnifierContent.textContent = '';
    magnifierElementMap.clear();

    const articleCenter = document.getElementById('article-center');
    if (!articleCenter) return;

    // 2. Création du conteneur "fantôme" (Ghost)
    // On lui donne le même ID/Classe pour hériter exactement des mêmes styles CSS
    const ghostContainer = document.createElement('div');
    ghostContainer.id = articleCenter.id;
    ghostContainer.className = articleCenter.className;
    
    // Style pour simuler la zone de l'article sans tout cloner
    ghostContainer.style.cssText = `
        position: absolute;
        top: 0; 
        left: 0;
        width: ${articleCenter.offsetWidth}px;
        height: ${articleCenter.scrollHeight}px;
        pointer-events: none;
        background: transparent;
        border: none;
        margin: 0;
        padding: 0;
    `;

    // 3. Clonage sélectif (uniquement les éléments visibles)
    visibleParagraphIds.forEach(id => {
        // Récupération de l'élément réel dans le DOM via l'ID stocké
        // (S'adapte à ta structure data-pid ou id de verset)
        const originalEl = paragraphsData.get(id)?.paragraphs[0];
        
        if (originalEl) {
            const clone = originalEl.cloneNode(true);
            
            // On force le positionnement absolu pour respecter la place originale dans l'article
            clone.style.position = 'absolute';
            clone.style.top = `${originalEl.offsetTop}px`;
            clone.style.left = `${originalEl.offsetLeft}px`;
            clone.style.width = `${originalEl.offsetWidth}px`;
            
            // Important : on s'assure que les marges ne se cumulent pas
            clone.style.margin = getComputedStyle(originalEl).margin;

            // 4. Mapping des tokens (mots/ponctuation) pour la loupe
            const originalTokens = originalEl.querySelectorAll('.word, .punctuation, .escape');
            const clonedTokens = clone.querySelectorAll('.word, .punctuation, .escape');
            
            for (let i = 0; i < originalTokens.length; i++) {
                if (originalTokens[i] && clonedTokens[i]) {
                    magnifierElementMap.set(originalTokens[i], clonedTokens[i]);
                }
            }

            ghostContainer.appendChild(clone);
        }
    });

    // 5. Injection dans la loupe
    magnifierContent.appendChild(ghostContainer);
}

function updateMagnifier(x, y) {
    // 1. Position de la bulle sur l'écran (Fixed)
    const offsetX = x - magnifierSize / 2;
    const offsetY = y - magnifierSize + 20; // Positionnée au dessus du doigt

    magnifierWrapper.style.transform = `translate3d(${offsetX}px, ${offsetY}px, 0)`;
    magnifierWrapper.classList.remove("hide");

    // 2. Alignement du contenu INTERNE
    // On doit utiliser le rectangle de pageCenter pour être précis au pixel près
    const rect = pageCenter.getBoundingClientRect();
    const scrollY = pageCenter.scrollTop;

    const halfW = magnifierSize / 2;
    const halfH = 45 / 2; // Ta hauteur de loupe est de 45px dans ton CSS

    // On calcule la position relative du toucher par rapport au haut du contenu total
    // (Position du doigt dans le viewport) - (Position du conteneur) + (Scroll accumulé)
    const relativeX = (x - rect.left) * zoomFactor;
    const relativeY = (y - rect.top + scrollY + 20) * zoomFactor;

    const moveX = halfW - relativeX;
    const moveY = halfH - relativeY;

    if (magnifierContent) {
        const target = magnifierContent.firstElementChild;
        if (target) {
            target.style.transformOrigin = '0 0';
            // On utilise translate3d pour la performance
            target.style.transform = `translate3d(${moveX}px, ${moveY}px, 0) scale(${zoomFactor})`;
        }
    }
}

function hideMagnifier() {
    magnifierWrapper.classList.add("hide");
}

// Votre fonction actuelle est la bonne méthode.
function getTheFirstTargetParagraph(target) {
    if (!target) return null;

    // SÉCURITÉ : Si on touche un élément dans un dialogue, on ignore.
    // Ajuste '.dialog-content' ou '.modal' selon ta classe CSS.
    if (target.closest('.dialog-content') || target.closest('[role="dialog"]')) {
        return null;
    }

    let targetIdValue = null;

    // On ne cherche que dans l'article principal (versets ou paragraphes)
    const verse = target.closest('.v[id]');
    if (verse) {
        targetIdValue = verse.id.split('-')[2];
    } else {
        const paragraph = target.closest('[data-pid]');
        if (paragraph) {
            targetIdValue = paragraph.getAttribute('data-pid');
        }
    }

    if (targetIdValue) {
        const targetIdInt = parseInt(targetIdValue, 10);
        if (paragraphsData.has(targetIdInt)) {
            return paragraphsData.get(targetIdInt);
        }
    }
    return null;
}

function getAllWords() {
    let allTokens = [];

    // Parcourir tous les paragraphes dans la Map
    paragraphsData.forEach(paragraphData => {
        allTokens = allTokens.concat(paragraphData.wordAndPunctTokens.filter(t => t.classList.contains('word')));
    });

    return allTokens;
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

function getAllWordsPunctsAndEscape() {
    let allTokens = [];

    // Parcourir tous les paragraphes dans la Map
    paragraphsData.forEach(paragraphData => {
        // Ajouter les wordAndPunctTokens de chaque paragraphe
        allTokens = allTokens.concat(paragraphData.allTokens);
    });

    return allTokens;
}

function ensureParagraphIndexed(paragraphData) {
    if (!paragraphData || paragraphData.allTokens) return;

    const tokens = paragraphData.paragraphs.flatMap(el =>
        Array.from(el.querySelectorAll('.word, .punctuation, .escape'))
    );
    
    paragraphData.allTokens = tokens;
    paragraphData.wordAndPunctTokens = tokens.filter(t => 
        t.classList.contains('word') || t.classList.contains('punctuation')
    );
    
    const indexMap = new Map();
    tokens.forEach((t, i) => indexMap.set(t, i));
    paragraphData.indexInAll = indexMap;
}

function fetchAllParagraphsOfTheArticle(article, isVerseDialog = false) {
    const paragraphsDataMap = new Map();
    const fetchedParagraphs = fetchAllParagraphs(article);
    const indexedTokens = indexTokensOptimized(fetchedParagraphs);

    fetchedParagraphs.forEach(group => {
        const tokens = indexedTokens.get(group.paragraphs);

        const uniqueKey = isVerseDialog && group.chapterId 
            ? `${group.chapterId}_${group.id}` 
            : group.id;

        paragraphsDataMap.set(uniqueKey, {
            paragraphs: group.paragraphs,
            chapterId: group.chapterId || null,
            id: group.id,
            isVerse: group.isVerse,
            allTokens: tokens.allTokens,
            wordAndPunctTokens: tokens.wordAndPunctTokens,
            indexInAll: tokens.indexInAll 
        });
    });

    if(article === document.getElementById("article-center")) {
        observeParagraphs(paragraphsDataMap);
    }

    return paragraphsDataMap;
}

function fetchAllParagraphs(article) {
    const finalList = [];
    const verses = Array.from(article.querySelectorAll('.v[id]'));

    if (verses.length > 0) {
        const grouped = {};

        verses.forEach(verse => {
            const parts = verse.id.split('-'); 
            const chapterId = parts[1];
            const verseUniqueKey = parts[2];

            if (!grouped[verseUniqueKey]) {
                grouped[verseUniqueKey] = {
                    chapterId: chapterId,
                    paragraphs: []
                };
            }
            grouped[verseUniqueKey].paragraphs.push(verse);
        });

        Object.entries(grouped).forEach(([id, data]) => {
            data.paragraphs.sort((a, b) => {
                return parseInt(a.id.split('-')[3], 10) - parseInt(b.id.split('-')[3], 10);
            });

            finalList.push({
                paragraphs: data.paragraphs,
                chapterId: parseInt(data.chapterId, 10),
                id: parseInt(id, 10),
                isVerse: true
            });
        });
    } 
    else {
        const paras = Array.from(article.querySelectorAll('[data-pid]'));
        paras.forEach(p => {
            const pid = p.getAttribute('data-pid');

            finalList.push({
                paragraphs: [p],
                id: parseInt(pid, 10),
                isVerse: false
            });
        });
    }

    return finalList;
}

function indexTokensOptimized(groups) {
    const map = new Map();
    
    groups.forEach(group => {
        const p = group.paragraphs;
        
        const allTokens = [];
        p.forEach(el => {
            const tokens = el.querySelectorAll('.word, .punctuation, .escape');
            allTokens.push(...tokens);
        });
        
        const wordAndPunctTokens = [];
        const indexInAll = new Map();
        
        for (let i = 0; i < allTokens.length; i++) {
            const token = allTokens[i];
            indexInAll.set(token, i);
            
            if (token.classList.contains('word') || token.classList.contains('punctuation')) {
                wordAndPunctTokens.push(token);
            }
        }

        map.set(p, {
            allTokens,
            wordAndPunctTokens,
            indexInAll
        });
    });
    
    return map;
}

async function changePage(direction) {
    isNavigating = true;
    try {
        // Réinitialisation du zoom
        const currentPage = container.children[1];
        const zoomTarget = currentPage?.querySelector('.zoomable-content');
        if (zoomTarget) {
            zoomTarget.style.transform = 'translate3d(0px, 0px, 0px) scale(1)';
            zoomTarget.dataset.scale = '1';
            zoomTarget.dataset.translateX = '0';
            zoomTarget.dataset.translateY = '0';
        }
        scale = 1;
        posX = 0;
        posY = 0;

        if (direction === 'right') {
            closeToolbar();
            currentTranslate = -200;
            container.style.transform = "translateX(-200%)";
            setTimeout(async () => {
                isNavigating = false;
                currentIndex++;
                currentTranslate = -100;
                await loadPages(currentIndex);
            }, 200);
        } 
        else if (direction === 'left') {
            closeToolbar();
            currentTranslate = 0;
            container.style.transform = "translateX(0%)";
            setTimeout(async () => {
                isNavigating = false;
                currentIndex--;
                currentTranslate = -100;
                await loadPages(currentIndex);
            }, 200);
        } else {
            container.style.transform = "translateX(-100%)";
        }
    } catch (error) {
        console.error('Error in changePage function:', error);
    }
}

// Fonction utilitaire pour obtenir le contenu zoomable actuel
function getCurrentZoomableContent() {
    const currentPage = container.children[1];
    return currentPage?.querySelector('.zoomable-content');
}

// Calcule les limites - optimisé pour être appelé moins souvent
function getBoundaries(element, currentScale) {
    const container = element.parentElement;
    const containerWidth = container.clientWidth;
    const containerHeight = container.clientHeight;
    
    // Dimensions réelles de l'élément après scale
    const scaledWidth = element.offsetWidth * currentScale;
    const scaledHeight = element.offsetHeight * currentScale;
    
    const maxX = Math.max(0, (scaledWidth - containerWidth) / 2);
    const maxY = Math.max(0, (scaledHeight - containerHeight) / 2);
    
    return { maxX, maxY };
}

// Applique la transformation - OPTIMISÉ pour la performance
function applyTransform(element, x, y, s, withTransition = false) {
    // On utilise UNIQUEMENT transform pour être GPU-accéléré
    element.style.transform = `translate3d(${x}px, ${y}px, 0) scale(${s})`;
    element.style.transition = withTransition ? 'transform 0.3s ease' : 'none';
    
    element.dataset.scale = s.toString();
    element.dataset.translateX = x.toString();
    element.dataset.translateY = y.toString();
}

// Contraint la position dans les limites
function constrainPosition(element, x, y, s) {
    const { maxX, maxY } = getBoundaries(element, s);
    return {
        x: Math.min(Math.max(x, -maxX), maxX),
        y: Math.min(Math.max(y, -maxY), maxY)
    };
}

function getHorizontalScrollParent(el) {
    while (el && el !== pageCenter) {
        const style = window.getComputedStyle(el);
        const overflowX = style.getPropertyValue('overflow-x');
        const isScrollable = (overflowX === 'auto' || overflowX === 'scroll');
        
        if (isScrollable && el.scrollWidth > el.clientWidth) {
            return el;
        }
        el = el.parentElement;
    }
    return null;
}

// --- TOUCH START ---
container.addEventListener('touchstart', (e) => {
    if (isLongPressing || isBlockingHorizontallyMode) return;
    
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
    touchStartElement = e.target;
    isScrollLocked = false;
    isVerticalScroll = false;

    const zoomTarget = getCurrentZoomableContent();
    if (zoomTarget) {
        scale = parseFloat(zoomTarget.dataset.scale) || 1;
        posX = parseFloat(zoomTarget.dataset.translateX) || 0;
        posY = parseFloat(zoomTarget.dataset.translateY) || 0;
    }

    if (e.touches.length === 2 && zoomTarget) {
        // Mode pinch
        isZooming = true;
        isDragging = false;
        isPanning = false;
        
        const touch1 = e.touches[0];
        const touch2 = e.touches[1];
        
        initialPinchDistance = Math.hypot(
            touch2.clientX - touch1.clientX,
            touch2.clientY - touch1.clientY
        );
        initialScale = scale;
        
        // Centre du pinch en coordonnées écran
        const centerX = (touch1.clientX + touch2.clientX) / 2;
        const centerY = (touch1.clientY + touch2.clientY) / 2;
        
        // Converti en coordonnées relatives au container (en %)
        const rect = zoomTarget.parentElement.getBoundingClientRect();
        pinchOriginX = ((centerX - rect.left) / rect.width) * 100;
        pinchOriginY = ((centerY - rect.top) / rect.height) * 100;
        
        // Défini l'origine du transform pour que le zoom se fasse au point de pinch
        zoomTarget.style.transformOrigin = `${pinchOriginX}% ${pinchOriginY}%`;
        
    } else {
        isZooming = false;
        isDragging = true;
        isPanning = false;
        startPosX = posX;
        startPosY = posY;
    }

    container.style.transition = "none";
}, { passive: false });

// --- TOUCH MOVE ---
container.addEventListener('touchmove', (e) => {
    if (isLongPressing || isBlockingHorizontallyMode) {
        isDragging = false;
        return;
    }

    const zoomTarget = getCurrentZoomableContent();

    // PINCH-TO-ZOOM (2 doigts)
    if (e.touches.length === 2 && isZooming && zoomTarget) {
        if (e.cancelable) e.preventDefault();
        
        const touch1 = e.touches[0];
        const touch2 = e.touches[1];
        
        const currentDistance = Math.hypot(
            touch2.clientX - touch1.clientX,
            touch2.clientY - touch1.clientY
        );
        
        // Calcule le nouveau scale
        let newScale = initialScale * (currentDistance / initialPinchDistance);
        newScale = Math.min(Math.max(newScale, 1), 5); // Limite 1x à 5x
        
        // Le centre du pinch actuel
        const centerX = (touch1.clientX + touch2.clientX) / 2;
        const centerY = (touch1.clientY + touch2.clientY) / 2;
        
        // Calcule le décalage nécessaire pour garder le point fixe
        const rect = zoomTarget.parentElement.getBoundingClientRect();
        const currentOriginX = ((centerX - rect.left) / rect.width) * 100;
        const currentOriginY = ((centerY - rect.top) / rect.height) * 100;
        
        // Ajuste la position pour compenser le changement de scale et d'origine
        const deltaOriginX = (currentOriginX - pinchOriginX) / 100 * rect.width;
        const deltaOriginY = (currentOriginY - pinchOriginY) / 100 * rect.height;
        
        let newPosX = posX - deltaOriginX * (newScale - scale);
        let newPosY = posY - deltaOriginY * (newScale - scale);
        
        // Mise à jour
        scale = newScale;
        
        // Contraint dans les limites
        const constrained = constrainPosition(zoomTarget, newPosX, newPosY, scale);
        posX = constrained.x;
        posY = constrained.y;
        
        applyTransform(zoomTarget, posX, posY, scale);
        return;
    }

    // PAN (1 doigt)
    if (isDragging && e.touches.length === 1) {
        const x = e.touches[0].clientX;
        const y = e.touches[0].clientY;
        const dx = x - startX;
        const dy = y - startY;

        // Détecte scroll vertical
        if (!isVerticalScroll && !isPanning) {
            if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > 10) {
                isVerticalScroll = true;
                return;
            }
        }

        if (isVerticalScroll) return;

        const scrollableParent = getHorizontalScrollParent(touchStartElement);

        // PAN quand zoomé
        if (scale > 1 && zoomTarget) {
            isPanning = true;
            if (e.cancelable) e.preventDefault();
            
            const newPosX = startPosX + dx;
            const newPosY = startPosY + dy;
            
            // Vérifie les limites
            const { maxX, maxY } = getBoundaries(zoomTarget, scale);
            
            const isAtLeftEdge = newPosX >= maxX;
            const isAtRightEdge = newPosX <= -maxX;
            const wantsGoLeft = dx > 0;
            const wantsGoRight = dx < 0;
            
            // Si on veut changer de page ET qu'on est au bord de l'image
            const canChangePage = 
                (isAtLeftEdge && wantsGoLeft && currentIndex > 0) ||
                (isAtRightEdge && wantsGoRight && currentIndex < maxIndex);
            
            if (!canChangePage) {
                // On panne normalement
                const constrained = constrainPosition(zoomTarget, newPosX, newPosY, scale);
                posX = constrained.x;
                posY = constrained.y;
                applyTransform(zoomTarget, posX, posY, scale);
                isScrollLocked = true;
                return;
            }
            // Sinon on laisse passer pour le changement de page
        }

        // Tableaux scrollables
        const tableCanScroll = scrollableParent && (
            (dx > 0 && scrollableParent.scrollLeft > 2) || 
            (dx < 0 && scrollableParent.scrollLeft + scrollableParent.clientWidth < scrollableParent.scrollWidth - 2)
        );

        if (tableCanScroll) {
            isScrollLocked = true;
            return;
        }

        // Blocage aux extrémités
        const isTryingToGoBeforeFirst = (currentIndex === 0 && dx > 0);
        const isTryingToGoAfterLast = (currentIndex === maxIndex && dx < 0);

        if (isTryingToGoBeforeFirst || isTryingToGoAfterLast) {
            return;
        }

        // Changement de page
        if (Math.abs(dx) > 15 && !isScrollLocked && scale <= 1) {
            if (e.cancelable) e.preventDefault();
            const percentage = (dx / window.innerWidth) * 100;
            container.style.transform = `translateX(${currentTranslate + percentage}%)`;
        }
    }
}, { passive: false });

// --- TOUCH END ---
container.addEventListener('touchend', (e) => {
    if (isLongPressing || isBlockingHorizontallyMode) {
        setLongPressing(false);
        isDragging = false;
        isZooming = false;
        isPanning = false;
        return;
    }

    const zoomTarget = getCurrentZoomableContent();
    
    // Fin du pinch - remet l'origine au centre
    if (isZooming && zoomTarget) {
        zoomTarget.style.transformOrigin = 'center top';
        const constrained = constrainPosition(zoomTarget, posX, posY, scale);
        posX = constrained.x;
        posY = constrained.y;
        applyTransform(zoomTarget, posX, posY, scale);
    }

    isZooming = false;
    isPanning = false;

    const dx = e.changedTouches[0].clientX - startX;
    const isAtBoundary = (currentIndex === 0 && dx > 0) || (currentIndex === maxIndex && dx < 0);

    if (isScrollLocked || isVerticalScroll || isAtBoundary || scale > 1) {
        container.style.transition = "transform 0.2s ease-out";
        container.style.transform = `translateX(${currentTranslate}%)`;
        isScrollLocked = false;
        return;
    }

    const percentage = dx / window.innerWidth;
    container.style.transition = "transform 0.25s cubic-bezier(0.2, 0, 0, 1)";

    if (Math.abs(percentage) > 0.15) {
        if (percentage < 0 && currentIndex < maxIndex) {
            changePage('right');
        } else if (percentage > 0 && currentIndex > 0) {
            changePage('left');
        } else {
            container.style.transform = `translateX(${currentTranslate}%)`;
        }
    } else {
        container.style.transform = `translateX(${currentTranslate}%)`;
    }
}, { passive: true });

// Double-tap pour zoomer
let lastTap = 0;
container.addEventListener('touchend', (e) => {
    const currentTime = Date.now();
    const tapLength = currentTime - lastTap;
    
    if (tapLength < 300 && tapLength > 0) {
        const zoomTarget = getCurrentZoomableContent();
        if (zoomTarget && !isLongPressing && e.touches.length === 0) {
            e.preventDefault();
            
            if (scale > 1) {
                // Dézoome
                scale = 1;
                posX = 0;
                posY = 0;
                zoomTarget.style.transformOrigin = 'center top';
            } else {
                // Zoome au point du tap
                const touch = e.changedTouches[0];
                const rect = zoomTarget.parentElement.getBoundingClientRect();
                
                // Point du tap en %
                const tapXPercent = ((touch.clientX - rect.left) / rect.width) * 100;
                const tapYPercent = ((touch.clientY - rect.top) / rect.height) * 100;
                
                zoomTarget.style.transformOrigin = `${tapXPercent}% ${tapYPercent}%`;
                scale = 2.5;
                posX = 0;
                posY = 0;
            }
            
            applyTransform(zoomTarget, posX, posY, scale, true);
            
            setTimeout(() => {
                if (scale === 1) {
                    zoomTarget.style.transformOrigin = 'center top';
                }
            }, 300);
        }
    }
    
    lastTap = currentTime;
}, { passive: false });