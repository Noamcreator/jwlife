import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../features/publication/pages/document/data/models/document.dart';

import '../../features/publication/pages/menu/local/publication_menu_view.dart';
import '../shared_preferences/shared_preferences_utils.dart';

bool hideDialog = false;

Future<void> showDownloadPublicationDialog(BuildContext context, Publication publication, {int? mepsDocId, int? bookNumber, int? chapterNumber, DateTime? date, int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  String publicationTitle = publication.getTitle();

  hideDialog = false;

  await showJwDialog<void>(
    context: context,
    titleText: "« $publicationTitle » n'est pas téléchargé",
    contentText: "Souhaitez-vous télécharger « $publicationTitle » ?",
    buttons: [
      JwDialogButton(
        label: 'ANNULER',
        closeDialog: true,
      ),
      JwDialogButton(
        label: 'TÉLÉCHARGER',
        closeDialog: false,
        onPressed: (buildContext) async {
          Navigator.of(buildContext).pop(); // Ferme le 1er dialog
          // Ajout du paramètre `openOnSuccess: true` pour le comportement initial
          await showDownloadProgressDialog(context, publication, openOnSuccess: true, mepsDocId: mepsDocId, bookNumber: bookNumber, chapterNumber: chapterNumber, date: date, startParagraphId: startParagraphId, endParagraphId: endParagraphId, textTag: textTag, wordsSelected: wordsSelected); // Ouvre le 2nd proprement
        },
      ),
    ],
  );
}

Future<void> showDownloadProgressDialog(BuildContext context, Publication publication, {bool openOnSuccess = false, int? mepsDocId, int? bookNumber, int? chapterNumber, DateTime? date, int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  await showJwDialog<void>(
    context: context,
    titleText: "Téléchargement de « ${publication.getTitle()} »",
    // Passage du nouveau paramètre à _DownloadDialogContent
    content: _DownloadDialogContent(
        publication: publication,
        openOnSuccess: openOnSuccess,
        mepsDocId: mepsDocId,
        bookNumber: bookNumber,
        chapterNumber: chapterNumber,
        date: date,
        startParagraphId: startParagraphId,
        endParagraphId: endParagraphId,
        textTag: textTag,
        wordsSelected: wordsSelected
    ),
    buttons: [
      JwDialogButton(
        label: 'ANNULER',
        closeDialog: false,
        onPressed: (buildContext) async {
          await publication.cancelDownload(context);
        },
      ),
      // ⭐ AJOUT DU BOUTON MASQUER
      JwDialogButton(
        label: 'MASQUER',
        closeDialog: false,
        onPressed: (buildContext) {
          hideDialog = true;
          Navigator.of(buildContext).pop();
        }
      ),
    ],
  );
}

class _DownloadDialogContent extends StatefulWidget {
  final Publication publication;
  final bool openOnSuccess; // ⭐ Nouveau paramètre pour contrôler l'ouverture
  final int? mepsDocId;
  final int? bookNumber;
  final int? chapterNumber;
  final DateTime? date;
  final int? startParagraphId;
  final int? endParagraphId;
  final String? textTag;
  final List<String>? wordsSelected;

  const _DownloadDialogContent({
    required this.publication,
    this.openOnSuccess = false, // Valeur par défaut pour éviter les erreurs si non fourni
    this.mepsDocId,
    this.bookNumber,
    this.chapterNumber,
    this.date,
    this.startParagraphId,
    this.endParagraphId,
    this.textTag,
    this.wordsSelected
  });

  @override
  State<_DownloadDialogContent> createState() => __DownloadDialogContentState();
}

class __DownloadDialogContentState extends State<_DownloadDialogContent> {
  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasStarted) {
      _hasStarted = true;
      _startDownload(); // On appelle ici, plus sûr
    }
  }

  Future<void> _startDownload() async {
    await widget.publication.download(context); // ← maintenant dans un contexte sûr

    // Ferme le dialogue de progression UNIQUEMENT s'il est encore visible (mounted)
    if (mounted) {
      Navigator.pop(context);
    }

    if(!hideDialog) {
      // ⭐ Changement de comportement ici : l'ouverture de la publication n'a lieu que si `openOnSuccess` est vrai
      if (widget.publication.isDownloadedNotifier.value && widget.openOnSuccess) {
        if(widget.mepsDocId == null && widget.bookNumber == null && widget.chapterNumber == null && widget.date == null && widget.startParagraphId == null && widget.endParagraphId == null && widget.textTag == null && widget.wordsSelected == null) {
          await showPage(PublicationMenuView(publication: widget.publication));
        }
        else if (widget.bookNumber != null && widget.chapterNumber != null) {
          await showPageBibleChapter(widget.publication, widget.bookNumber!, widget.chapterNumber!, firstVerse: widget.startParagraphId, lastVerse: widget.endParagraphId);
        }
        else if (widget.date != null) {
          await showPageDailyText(widget.publication, date: widget.date!);
        }
        else {
          await showPageDocument(widget.publication, widget.mepsDocId!, startParagraphId: widget.startParagraphId, endParagraphId: widget.endParagraphId, textTag: widget.textTag, wordsSelected: widget.wordsSelected);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.publication.isDownloadingNotifier,
        builder: (context, isDownloading, _) {
          if (!isDownloading) return const SizedBox.shrink();

          return ValueListenableBuilder<double>(
            valueListenable: widget.publication.progressNotifier,
            builder: (context, progress, _) {
              return LinearProgressIndicator(
                value: progress == -1 ? null : progress,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                backgroundColor: Colors.grey.shade300,
                minHeight: 4,
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> showDocumentView(BuildContext context, int mepsDocId, int currentLanguageId, {int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  Publication? publication = await JwLifeApp.pubCollections.getDocumentFromMepsDocumentId(mepsDocId, currentLanguageId);

  if (publication != null) {
    if (publication.isDownloadedNotifier.value) {
      await showPageDocument(publication, mepsDocId, startParagraphId: startParagraphId, endParagraphId: endParagraphId, textTag: textTag, wordsSelected: wordsSelected);
    }
    else {
      await showDownloadPublicationDialog(context, publication, mepsDocId: mepsDocId, startParagraphId: startParagraphId, endParagraphId: endParagraphId, textTag: textTag, wordsSelected: wordsSelected);
    }
  }
  else {
    if(await hasInternetConnection()) {
      publication = await PubCatalog.searchPubFromMepsDocumentId(mepsDocId, currentLanguageId);
      if (publication != null) {
        await showDownloadPublicationDialog(context, publication, mepsDocId: mepsDocId, startParagraphId: startParagraphId, endParagraphId: endParagraphId, textTag: textTag, wordsSelected: wordsSelected);
      }
    }
    else {
      await showNoConnectionDialog(context);
    }
  }
}

Future<void> showChapterView(BuildContext context, String keySymbol, int currentLanguageId, int bookNumber, int chapterNumber, {int? firstVerseNumber, int? lastVerseNumber, List<String>? wordsSelected}) async {
  Publication? bible = PublicationRepository().getAllBibles().firstWhereOrNull((p) => p.keySymbol == keySymbol && p.mepsLanguage.id == currentLanguageId);

  if (bible != null) {
    if (bible.isDownloadedNotifier.value) {
      await showPageBibleChapter(bible, bookNumber, chapterNumber, firstVerse: firstVerseNumber, lastVerse: lastVerseNumber, wordsSelected: wordsSelected);
    }
    else {
      await showDownloadPublicationDialog(context, bible, bookNumber: bookNumber, chapterNumber: chapterNumber, startParagraphId: firstVerseNumber, endParagraphId: lastVerseNumber, wordsSelected: wordsSelected);
    }
  }
  else {
    if(await hasInternetConnection()) {
      bible = await PubCatalog.searchPub(keySymbol, 0, currentLanguageId);
      if (bible != null) {
        await showDownloadPublicationDialog(context, bible, bookNumber: bookNumber, chapterNumber: chapterNumber, startParagraphId: firstVerseNumber, endParagraphId: lastVerseNumber, wordsSelected: wordsSelected);
      }
    }
    else {
      await showNoConnectionDialog(context);
    }
  }
}

Future<void> showDailyText(BuildContext context, Publication publication, {DateTime? date}) async {
  if (publication.isDownloadedNotifier.value) {
    await showPageDailyText(publication, date: date);
  }
  else {
    if(await hasInternetConnection()) {
      await showDownloadPublicationDialog(context, publication, date: date);
    }
    else {
      await showNoConnectionDialog(context);
    }
  }
}

String createHtmlContent(String html, String articleClasses, String javascript) {
  WebViewData webViewData = JwLifeSettings().webViewData;
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
          
        </style>
        <article id="article" class="$articleClasses ${webViewData.theme}">
          $html
        </article>
        <script>
          $javascript
        </script>
      </body>
    </html>
  ''';

  return htmlContent;
}

String getArticleClass(Document document) {
  final isBible = document.isBibleChapter();
  final publication = isBible ? 'bible' : 'document';
  final keySymbol = document.publication.keySymbol;
  final docClass = document.classType;
  final docId = document.documentId;
  final scriptName = document.publication.mepsLanguage.internalScriptName;
  final languageSymbol = document.publication.mepsLanguage.symbol;
  final direction = document.publication.mepsLanguage.isRtl ? 'rtl' : 'ltr';

  return [
    publication,
    'jwac',
    'pub-$keySymbol',
    'docClass-$docClass',
    'docId-$docId',
    'ms-$scriptName',
    'ml-$languageSymbol',
    'dir-$direction',
    'layout-reading',
    'layout-sidebar'
  ].join(' ');
}

Future<void> showFontSizeDialog(BuildContext context, InAppWebViewController? controller) async {
  double fontSize = JwLifeSettings().webViewData.fontSize;
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
                          controller?.evaluateJavascript(source: "resizeFont($fontSize);");
                          JwLifeSettings().webViewData.updateFontSize(fontSize);
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

Future<Bookmark?> showBookmarkDialog(BuildContext context, Publication publication, {InAppWebViewController? webViewController, int? mepsDocumentId, int? bookNumber, int? chapterNumber, String? title, String? snippet, int? blockType, int? blockIdentifier}) async {
  List<Bookmark> bookmarks = await JwLifeApp.userdata.getBookmarksFromPub(publication);

  bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  String bookmarkPath = isDarkMode
      ? 'assets/icons/bookmarks/dark/bookmark{number}.png'
      : 'assets/icons/bookmarks/light/bookmark{number}.png';

  return await showDialog<Bookmark?>(
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
                      'Marque-pages - ${publication.getShortTitle()}',
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
                          Bookmark? bookmark = bookmarks.firstWhereOrNull((b) => b.slot == index);

                          return Column(
                            children: [
                              if (bookmarkNumber == 1)
                                Divider(color: isDarkMode ? Colors.black : Color(0xFFf1f1f1)),
                              InkWell(
                                onTap: () async {
                                  if (bookmark != null) {
                                    Navigator.pop(context, bookmark); // Retourne le bookmark sélectionné
                                  }
                                  else if (bookNumber != null && chapterNumber != null) {
                                    Bookmark? bookmark = await JwLifeApp.userdata.addBookmark(publication, null, bookNumber, chapterNumber, title!, snippet!, index, blockType!, blockIdentifier);
                                    if(bookmark != null) {
                                      setState(() {
                                        bookmarks.add(bookmark);
                                      });
                                      if(publication.documentsManager != null) {
                                        publication.documentsManager!.getCurrentDocument().addBookmark(bookmark);
                                      }
                                      if(webViewController != null) {
                                        webViewController.evaluateJavascript(source: 'addBookmark(null, null, ${bookmark.blockType}, ${bookmark.blockIdentifier}, ${bookmark.slot})');
                                      }
                                    }
                                  }
                                  else if (mepsDocumentId != null) {
                                    Bookmark? bookmark = await JwLifeApp.userdata.addBookmark(publication, mepsDocumentId, null, null, title!, snippet!, index, blockType!, blockIdentifier);
                                    if(bookmark != null) {
                                      setState(() {
                                        bookmarks.add(bookmark);
                                      });
                                      if(publication.documentsManager != null) {
                                        publication.documentsManager!.getCurrentDocument().addBookmark(bookmark);
                                      }
                                      if(webViewController != null) {
                                        webViewController.evaluateJavascript(source: 'addBookmark(null, null, ${bookmark.blockType}, ${bookmark.blockIdentifier}, ${bookmark.slot})');
                                      }
                                    }
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
                                        if(bookmark != null)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center, // Centre le contenu verticalement
                                              children: [
                                                Text(
                                                  bookmark.title,
                                                  style: TextStyle(
                                                    color: isDarkMode ? Colors.white : Colors.black,
                                                    fontSize: 17,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),

                                                if(bookmark.snippet.isNotEmpty)
                                                  Text(
                                                    bookmark.snippet,
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
                                        if (bookmark != null)
                                          PopupMenuButton(
                                            icon: Icon(
                                              Icons.more_vert,
                                              color: Color(0xFF9d9d9d),
                                            ),
                                            itemBuilder: (context) {
                                              return [
                                                PopupMenuItem(
                                                  onTap: () async {
                                                    bool deleted = await JwLifeApp.userdata.removeBookmark(publication, bookmark);
                                                    if(deleted) {
                                                      setState(() {
                                                        bookmarks.remove(bookmark);
                                                      });
                                                      if(publication.documentsManager != null) {
                                                        publication.documentsManager!.getCurrentDocument().removeBookmark(bookmark);
                                                      }
                                                      if(webViewController != null) {
                                                        webViewController.evaluateJavascript(source: 'removeBookmark(null, ${bookmark.blockIdentifier}, ${bookmark.slot})');
                                                      }
                                                    }
                                                  },
                                                  child: Text('Supprimer'),
                                                ),
                                                PopupMenuItem(
                                                  onTap: () async {
                                                    if (mepsDocumentId != null) {
                                                      Bookmark? updatedBookmark = await JwLifeApp.userdata.updateBookmark(publication, index, mepsDocumentId, null, null, title!, snippet!, blockType!, blockIdentifier);
                                                      if(updatedBookmark != null) {
                                                        setState(() {
                                                          bookmarks.remove(bookmark);
                                                          bookmarks.add(updatedBookmark);
                                                        });
                                                        if(publication.documentsManager != null) {
                                                          publication.documentsManager!.getCurrentDocument().removeBookmark(bookmark);
                                                          publication.documentsManager!.getCurrentDocument().addBookmark(updatedBookmark);
                                                        }
                                                        if(webViewController != null) {
                                                          webViewController.evaluateJavascript(source: 'removeBookmark(null, ${bookmark.blockIdentifier}, ${bookmark.slot})');
                                                          webViewController.evaluateJavascript(source: 'addBookmark(null, null, ${updatedBookmark.blockType}, ${updatedBookmark.blockIdentifier}, ${updatedBookmark.slot})');
                                                        }
                                                      }
                                                    }
                                                    else if (bookNumber != null && chapterNumber != null) {
                                                      Bookmark? updatedBookmark = await JwLifeApp.userdata.updateBookmark(publication, index, null, bookNumber, chapterNumber, title!, snippet!, blockType!, blockIdentifier);
                                                      if(updatedBookmark != null) {
                                                        setState(() {
                                                          bookmarks.remove(bookmark);
                                                          bookmarks.add(updatedBookmark);
                                                        });
                                                        if(publication.documentsManager != null) {
                                                          publication.documentsManager!.getCurrentDocument().removeBookmark(bookmark);
                                                          publication.documentsManager!.getCurrentDocument().addBookmark(updatedBookmark);
                                                        }
                                                        if(webViewController != null) {
                                                          webViewController.evaluateJavascript(source: 'removeBookmark(null, ${bookmark.blockIdentifier}, ${bookmark.slot})');
                                                          webViewController.evaluateJavascript(source: 'addBookmark(null, null, ${updatedBookmark.blockType}, ${updatedBookmark.blockIdentifier}, ${updatedBookmark.slot})');
                                                        }
                                                      }
                                                    }
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