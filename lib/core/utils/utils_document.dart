import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';

import '../../app/jwlife_app.dart';

Future<void> showDownloadPublicationDialog(BuildContext context, Publication publication) async {
  String publicationTitle = publication.getTitle();

  // Affichage du dialogue principal
  await showJwDialog<void>(
    context: context,
    titleText: "« $publicationTitle » n'est pas téléchargé",
    contentText: "Souhaitez-vous télécharger « $publicationTitle » ?",
    buttons: [
      JwDialogButton(
        label: 'ANNULER',
      ),
      JwDialogButton(
        label: 'TÉLÉCHARGER',
        closeDialog: false, // Ne ferme pas immédiatement
        onPressed: (buildContext) async {
          await showDownloadProgressDialog(context, publication);
          Navigator.pop(buildContext);
        },
      ),
    ],
  );
}

Future<void> showDownloadProgressDialog(BuildContext context, Publication publication) async {
  await showJwDialog<void>(
    context: context,
    titleText: "Téléchargement de « ${publication.getTitle()} »",
    content: _DownloadDialogContent(publication: publication),
    buttons: [
      JwDialogButton(
        label: 'ANNULER'
      ),
    ],
  );
}

class _DownloadDialogContent extends StatefulWidget {
  final Publication publication;

  const _DownloadDialogContent({required this.publication});

  @override
  __DownloadDialogContentState createState() => __DownloadDialogContentState();
}

class __DownloadDialogContentState extends State<_DownloadDialogContent> {
  double progress = 0.0;

  @override
  void initState() {
    super.initState();

    init();
  }

  Future<void> init() async {
    await widget.publication.download(context, update: (double newProgress) {
      if (mounted) {
        setState(() {
          progress = newProgress;
        });
      }
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress > 0)
            LinearProgressIndicator(
              value: progress,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              backgroundColor: Colors.grey[300],
            ),
          if (progress == 0)
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              backgroundColor: Colors.grey[300],
            ),
        ],
      )
    );
  }
}

void showDocumentView(BuildContext context, int mepsDocId, int currentLanguageId, {int? startParagraphId, int? endParagraphId}) async {
  Publication? publication = await JwLifeApp.pubCollections.getDocumentFromMepsDocumentId(mepsDocId, currentLanguageId);

  if (publication != null) {
    showPage(context, DocumentView(publication: publication, mepsDocumentId: mepsDocId, startParagraphId: startParagraphId, endParagraphId: endParagraphId));
  }
  else {
    if(await hasInternetConnection()) {
      publication = await PubCatalog.searchPubFromMepsDocumentId(mepsDocId, currentLanguageId);
      if (publication != null) {
        await showDownloadPublicationDialog(context, publication);
        Publication pub = JwLifeApp.pubCollections.getPublication(publication);
        if (pub.isDownloaded) {
          showPage(
            context,
            DocumentView(
              publication: pub,
              mepsDocumentId: mepsDocId,
              startParagraphId: startParagraphId,
              endParagraphId: endParagraphId,
            ),
          );
        }
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

void showChapterView(BuildContext context, String keySymbol, int currentLanguageId, int bookNumber, int chapterNumber, {int? firstVerseNumber, int? lastVerseNumber}) async {
  Publication? bible = JwLifeApp.pubCollections.publications.firstWhereOrNull((p) => p.keySymbol == keySymbol && p.mepsLanguage.id == currentLanguageId);

  if (bible != null) {
    showPage(context, DocumentView.bible(bible: bible, book: bookNumber, chapter: chapterNumber, firstVerse: firstVerseNumber, lastVerse: lastVerseNumber));
  }
  else {
    if(await hasInternetConnection()) {
      //showPage(context, PublicationMenu(publication: publication));
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

String createHtmlContent(String html, String articleClasses, Publication publication, bool hasAppBar) {
  WebViewData webViewData = JwLifeApp.settings.webViewData;
  // Dynamique pour paddingTop
  String headerAdjustmentScript = '''
    <script>
  var hasAppBar = $hasAppBar;
  var header = document.querySelector('header');
  var firstImage = document.querySelector('div#f1.north_center'); // On récupère la première image du document

  if (firstImage != null) {
    // Vérifier si l'image n'est pas dans le header ou si elle est avant le header
    if (!header.contains(firstImage)) {
      // Déplacer l'image dans le header si elle n'est pas déjà dedans ou si elle est avant le header
      header.insertBefore(firstImage, header.firstChild);
    }
    paddingTop = hasAppBar ? '90px' : '10px'; // Ajuster le padding si l'image existe
  } else {
    // Sinon, garder le padding par défaut
    paddingTop = hasAppBar ? '110px' : '20px';
  }

  // Appliquer paddingTop au body
  document.querySelector('#article').style.paddingTop = paddingTop;
  document.querySelector('#article').style.paddingBottom = '50px';
  
  document.body.addEventListener('click', (event) => {
    // Gérer les images
    if (event.target && event.target.tagName === 'IMG') {
      window.flutter_inappwebview.callHandler('onImageClick', event.target.src);
    }

    // Gérer les notes de bas de page
    if (event.target && event.target.classList.contains('fn')) {
      const fnid = event.target.getAttribute('data-fnid');
      window.flutter_inappwebview.callHandler('fetchFootnote', fnid);
    }
    
    // Gérer les notes de bas de page
    if (event.target && event.target.classList.contains('m')) {
      const mid = event.target.getAttribute('data-mid');
      window.flutter_inappwebview.callHandler('fetchVersesReference', mid);
    }
  });
  
    // Gestion des vidéos sous forme d'éléments <video>
    var videoElements = document.querySelectorAll("video[data-video]");
    videoElements.forEach(function(videoElement) {
        var imageName = videoElement.getAttribute("data-image");

        if (imageName) {
            var imagePath = `${publication.path}/\${imageName}`;
            
            var imgElement = document.createElement("img");
            imgElement.src = imagePath;
            imgElement.style.width = "100%";
            imgElement.style.height = "auto";

            var container = document.createElement("div");
            container.style.position = "relative"; 
            container.style.width = "100%";
            container.style.height = "auto"; 
            container.appendChild(imgElement); 

            var playButton = document.createElement("div");
            playButton.style.position = "absolute";
            playButton.style.bottom = "10px";
            playButton.style.left = "10px";
            playButton.style.width = "40px";
            playButton.style.height = "40px";
            playButton.style.backgroundColor = "rgba(0, 0, 0, 0.7)";
            playButton.style.display = "flex";
            playButton.style.alignItems = "center";
            playButton.style.justifyContent = "center";
            playButton.style.fontSize = "24px";
            playButton.style.color = "white";
            playButton.innerHTML = "&#xE69D;";
            playButton.style.fontFamily = "jw-icons-external"; 

            container.appendChild(playButton);

            container.addEventListener("click", function() {
                window.flutter_inappwebview.callHandler('onVideoClick', videoElement.getAttribute("data-video"));
            });

            videoElement.parentNode.replaceChild(container, videoElement);
        }
    });

    // Gestion des liens <a data-video>
    var videoLinks = document.querySelectorAll("a[data-video]");
    videoLinks.forEach(function(link) {
        link.addEventListener("click", function(event) {
            event.preventDefault(); // Empêche la navigation
            window.flutter_inappwebview.callHandler('onVideoClick', link.getAttribute("data-video"));
        });
    });
</script>
  ''';

  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
      </head>
      <body>
        <style>
          body {
            user-select: none;
            font-size: ${webViewData.fontSize}px;
            background-color: ${webViewData.backgroundColor};
          }
          
          /* Style du texte surligné (highlight) */
          .word.highlighted {
            background-color: yellow;
          }
         
          /* Définir les classes de surlignage */
          .highlight-yellow { background-color: #86761d; }
          .highlight-green { background-color: #4a6831; }
          .highlight-blue { background-color: #3a6381; }
          .highlight-purple { background-color: #524169; }
          .highlight-pink { background-color: #783750; }
          .highlight-orange { background-color: #894c1f; }
          .highlight-transparent { background-color: transparent; }
          
          .highlightingcolor1 { background-color: #ffeb3b80; }
          .highlightingcolor2 { background-color: #9ef95380; }
          .highlightingcolor3 { background-color: #29b6f680; }
          .highlightingcolor4 { background-color: #ffa1c880; }
          .highlightingcolor5 { background-color: #ffb97680; }
          .highlightingcolor6 { background-color: #af85ff80; }
        </style>
        <article id="article" class="$articleClasses ${webViewData.theme}">
          $html
        </article>
        $headerAdjustmentScript
      </body>
    </html>
  ''';

  return htmlContent;
}

String createHtmlDialogContent(String html, String articleClasses) {
  WebViewData webViewData = JwLifeApp.settings.webViewData;

  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
      </head>
      <body>
        <style>
          body {
            font-size: ${webViewData.fontSize}px;
            background-color: ${webViewData.backgroundColor};
          }
        </style>
        <article id="article" class="$articleClasses ${webViewData.theme}">
          $html
        </article>
      </body>
    </html>
  ''';

  return htmlContent;
}

Future<void> showFontSizeDialog(BuildContext context, InAppWebViewController? controller) async {
  double fontSize = JwLifeApp.settings.webViewData.fontSize;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(18), // Padding uniquement sur le titre et le contenu
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Taille de police', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Éloigne les éléments
                        children: [
                          Text('A', style: TextStyle(fontSize: 20)),
                          Text('A', style: TextStyle(fontSize: 27)),
                        ],
                      ),
                      Slider(
                        padding: EdgeInsets.all(0),
                        value: fontSize,
                        min: 11.0,
                        max: 28.0,
                        divisions: 17,
                        label: "${fontSize.toInt()} px",
                        onChanged: (value) {
                          setState(() {
                            fontSize = value;
                          });

                          // Mise à jour en temps réel dans la WebView
                          controller?.evaluateJavascript(source: "document.body.style.fontSize = '${fontSize}px';");
                          JwLifeApp.settings.webViewData.updateFontSize(fontSize);
                          setFontSize(fontSize);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text(
                        'FERMER',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(fontSize);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<bool> showFullscreenDialog(BuildContext context) async {
  bool isFullscreen = await getFullscreen();
  bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Empêche la fermeture en cliquant en dehors
    builder: (BuildContext context) {
      return Dialog(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Éloigne les éléments
                    children: [
                      Text('Plein écran', style: TextStyle(fontSize: 18)),
                      Switch(
                        value: isFullscreen,
                        onChanged: (value) {
                          setState(() {
                            isFullscreen = value;
                          });
                          setFullscreen(isFullscreen);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: Text('FERMER', style: TextStyle(
                          fontFamily: 'Roboto',
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(isFullscreen);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  return result ?? isFullscreen; // Retourne la dernière valeur connue si l'utilisateur ferme sans appuyer sur "FERMER"
}

Future<void> showHtmlDialog(BuildContext context, String html) async {
  TextEditingController htmlController = TextEditingController(text: html);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.zero, // Supprime les marges
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              width: MediaQuery.of(context).size.width, // Prend toute la largeur
              height: MediaQuery.of(context).size.height * 0.9, // Presque toute la hauteur
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Éditeur HTML', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: htmlController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Éditez le HTML ici',
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            'COPIER',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: htmlController.text));
                          },
                        ),
                        TextButton(
                          child: Text(
                            'FERMER',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(htmlController.text);
                          },
                        ),
                      ]
                    )
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Future<Map<String, dynamic>?> showBookmarkDialog(BuildContext context, Publication publication, {InAppWebViewController? webViewController, int? mepsDocumentId, int? bookNumber, int? chapterNumber, String? title, String? snippet, int? blockType, int? blockIdentifier}) async {
  List<Map<String, dynamic>> bookmarks = List<Map<String, dynamic>>.from(await JwLifeApp.userdata.getBookmarksFromPub(publication));
  bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  String bookmarkPath = isDarkMode
      ? 'assets/icons/bookmarks/dark/bookmark{number}.png'
      : 'assets/icons/bookmarks/light/bookmark{number}.png';

  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20), // Supprime les marges par défaut
            child: SizedBox(
              width: MediaQuery.of(context).size.width, // Prend toute la largeur de l'écran
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    child: Text(
                      'Marque-pages - ${publication.shortTitle}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(10, (index) {
                          int bookmarkNumber = index + 1;
                          Map<String, dynamic> bookmark = bookmarks.firstWhere(
                                (b) => b['Slot'] == index,
                            orElse: () => {},
                          );

                          return Column(
                            children: [
                              if (bookmarkNumber == 1)
                                Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),
                              InkWell(
                                onTap: () async {
                                  if (bookmark.isNotEmpty) {
                                    Navigator.pop(context, bookmark); // Retourne le bookmark sélectionné
                                  }
                                  else if (mepsDocumentId != null) {
                                    Map<String, dynamic> bookmark = await JwLifeApp.userdata.addBookmark(publication, mepsDocumentId, null, null, title!, snippet!, index, blockType!, blockIdentifier);
                                    setState(() {
                                      bookmarks.add(bookmark);
                                    });
                                    webViewController?.evaluateJavascript(source: 'addBookmark(null, ${bookmark['BlockType']}, ${bookmark['BlockIdentifier']}, ${bookmark['Slot']})');
                                  }
                                  else if (bookNumber != null && chapterNumber != null) {
                                    Map<String, dynamic> bookmark = await JwLifeApp.userdata.addBookmark(publication, null, bookNumber, chapterNumber, title!, snippet!, index, blockType!, blockIdentifier);
                                    setState(() {
                                      bookmarks.add(bookmark);
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 5),
                                  child: SizedBox(
                                    height: 44, // Définis une hauteur fixe pour chaque bookmark
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Image.asset(
                                          bookmarkPath.replaceAll('{number}', bookmarkNumber.toString().padLeft(2, '0')),
                                          width: 25,
                                          height: 30,
                                          fit: BoxFit.fill,
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center, // Centre le contenu verticalement
                                            children: [
                                              Text(
                                                bookmark['Title'] ?? '',
                                                style: TextStyle(
                                                  color: isDarkMode ? Colors.white : Colors.black,
                                                  fontSize: 17,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (bookmark['Snippet'] != null && bookmark['Snippet'].isNotEmpty)
                                                Text(
                                                  bookmark['Snippet'] ?? '',
                                                  style: TextStyle(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Color(0xFFc2c2c2)
                                                        : Color(0xFF626262),
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (bookmark.isNotEmpty)
                                          PopupMenuButton(
                                            icon: Icon(
                                              Icons.more_vert,
                                              color: Color(0xFF9d9d9d),
                                            ),
                                            itemBuilder: (context) {
                                              return [
                                                PopupMenuItem(
                                                  onTap: () async {
                                                    Map<String, dynamic> bookmark = bookmarks.firstWhere((b) => b['Slot'] == index);
                                                    await JwLifeApp.userdata.removeBookmark(publication, bookmark);

                                                    setState(() {
                                                      bookmarks.remove(bookmark);
                                                    });
                                                  },
                                                  child: Text('Supprimer'),
                                                ),
                                                if (mepsDocumentId != null)
                                                  PopupMenuItem(
                                                    onTap: () async {
                                                      Map<String, dynamic> updatedBookmark = await JwLifeApp.userdata.updateBookmark(publication, index, mepsDocumentId, title!, snippet!, blockType!, blockIdentifier);

                                                      setState(() {
                                                        bookmarks.remove(bookmark);
                                                        bookmarks.add(updatedBookmark);
                                                      });
                                                    },
                                                    child: Text('Remplacer'),
                                                  ),
                                              ];
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              ),
                              if (index < 10)
                                Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 10),
                      child: TextButton(
                        child: Text(
                          'FERMER',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor),
                        ),
                        onPressed: () {
                          Navigator.pop(context, null); // Retourne null si l'utilisateur ferme la boîte de dialogue
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> updateFieldValue(Publication publication, int docId, dynamic updatedField) async {
  try {
    // Extraire le tag et la valeur
    final String tag = updatedField['tag']?.toString() ?? '';
    final String value = updatedField['value']?.toString() ?? '';

    // Appel à la mise à jour ou insertion
    await JwLifeApp.userdata.updateOrInsertInputField(publication, docId, tag, value);
  }
  catch (e, stacktrace) {
    // Log l'erreur pour le debug
    print('Error in _updateFieldValue: $e');
    print('Stacktrace: $stacktrace');
  }
}