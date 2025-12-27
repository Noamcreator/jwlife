import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/services/file_handler_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/databases/mepsunit.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../features/document/data/models/document.dart';

import '../../features/publication/pages/local/publication_menu_view.dart';
import '../../i18n/i18n.dart';
import '../shared_preferences/shared_preferences_utils.dart';
import '../uri/jworg_uri.dart';

bool hideDialog = false;

Future<void> showDownloadPublicationDialog(BuildContext context, Publication publication, {int? mepsDocId, int? bookNumber, int? chapterNumber, DateTime? date, int? startParagraphId, int? endParagraphId, String? textTag, List<String>? wordsSelected}) async {
  String title = publication.getTitle();

  hideDialog = false;

  await showJwDialog<void>(
    context: context,
    titleText: i18n().message_item_download_title(title),
    contentText: i18n().message_item_download(title),
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
      ),
      JwDialogButton(
        label: i18n().action_download_uppercase,
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
    titleText: i18n().message_item_downloading(publication.getTitle()),
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
        label: i18n().action_cancel_uppercase,
        closeDialog: false,
        onPressed: (buildContext) async {
          await publication.cancelDownload(context);
        },
      ),
      // ⭐ AJOUT DU BOUTON MASQUER
      JwDialogButton(
        label: i18n().action_hide.toUpperCase(),
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

Future<void> showImportPublication(BuildContext context, String keySymbol, int issueTagNumber, int mepsLanguageId) async {
  await showJwDialog<void>(
    context: context,
    titleText: i18n().message_publication_unavailable_title,
    contentText: i18n().message_publication_unavailable,
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
      ),
      JwDialogButton(
        label: i18n().label_import_uppercase,
        closeDialog: false,
        onPressed: (buildContext) async {
          Navigator.of(buildContext).pop(); // Ferme le 1er dialog
          // Demander un fichier à l'utilisateur
          FilePicker.platform.pickFiles(allowMultiple: true).then((result) async {
            if (result != null) {
              for (PlatformFile f in result.files) {
                File file = File(f.path!);
                if (file.path.endsWith('.jwpub')) {
                  FileHandlerService().processJwPubFile(file.path, keySymbol: keySymbol, issueTagNumber: issueTagNumber, mepsLanguageId: mepsLanguageId);
                }
              }
            }
          });
        },
      ),
    ],
  );
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
    if(await hasInternetConnection(context: context)) {
      publication = await CatalogDb.instance.searchPubFromMepsDocumentId(mepsDocId, currentLanguageId);
      if (publication != null) {
        await showDownloadPublicationDialog(context, publication, mepsDocId: mepsDocId, startParagraphId: startParagraphId, endParagraphId: endParagraphId, textTag: textTag, wordsSelected: wordsSelected);
      }
      else {
        String? symbol = await Mepsunit.getMepsLanguageSymbolFromId(currentLanguageId);
        String uri = JwOrgUri.document(
            wtlocale: symbol ?? '',
            docid: mepsDocId,
            par: startParagraphId?.toString()
        ).toString();


        await launchUrl(Uri.parse(uri));
      }
    }
  }
}

Future<void> showChapterView(BuildContext context, String keySymbol, int currentLanguageId, int bookNumber, int chapterNumber, {int? lastBookNumber, int? lastChapterNumber, firstVerseNumber, int? lastVerseNumber, List<String>? wordsSelected}) async {
  Publication? bible = PublicationRepository().getAllBibles().firstWhereOrNull((p) => p.keySymbol == keySymbol && p.mepsLanguage.id == currentLanguageId);

  if (bible != null) {
    if (bible.isDownloadedNotifier.value) {
      await showPageBibleChapter(bible, bookNumber, chapterNumber, lastBookNumber: lastBookNumber, lastChapterNumber: lastChapterNumber, firstVerse: firstVerseNumber, lastVerse: lastVerseNumber, wordsSelected: wordsSelected);
    }
    else {
      await showDownloadPublicationDialog(context, bible, bookNumber: bookNumber, chapterNumber: chapterNumber, startParagraphId: firstVerseNumber, endParagraphId: lastVerseNumber, wordsSelected: wordsSelected);
    }
  }
  else {
    if(await hasInternetConnection(context: context)) {
      bible = await CatalogDb.instance.searchPub(keySymbol, 0, currentLanguageId);
      if (bible != null) {
        await showDownloadPublicationDialog(context, bible, bookNumber: bookNumber, chapterNumber: chapterNumber, startParagraphId: firstVerseNumber, endParagraphId: lastVerseNumber, wordsSelected: wordsSelected);
      }
    }
  }
}

Future<void> showDailyText(BuildContext context, Publication publication, {DateTime? date}) async {
  if (publication.isDownloadedNotifier.value) {
    await showPageDailyText(publication, date: date);
  }
  else {
    if(await hasInternetConnection(context: context)) {
      await showDownloadPublicationDialog(context, publication, date: date);
    }
  }
}

String createHtmlContent(String html, String articleClasses, String javascript) {
  WebViewData webViewData = JwLifeSettings.instance.webViewData;
  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
      </head>
      <body class="${webViewData.theme}"> 
        <style>
          body {
            user-select: none;
            font-size: ${webViewData.fontSize}px;
          }
          
          /* Sélecteurs pour cibler le body avec la classe du thème */
          body.cc-theme--dark {
            background-color: #000000;
          }
          
          body.cc-theme--light {
            background-color: #f1f1f1;
          }
          
          /* Ajout du padding à l'élément article */
          #article {
            padding-top: 20px;    // Marge intérieure en haut
            padding-bottom: 20px; // Marge intérieure en bas
          }
          
        </style>
        <article id="article" class="$articleClasses">
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

String getArticleClass(Publication publication, Document document) {
  final isBible = document.isBibleChapter();
  final type = isBible ? 'bible' : 'document';
  final keySymbol = publication.keySymbol;
  final docClass = document.classType;
  final docId = document.documentId;
  final scriptName = publication.mepsLanguage.internalScriptName;
  final languageSymbol = publication.mepsLanguage.symbol;
  final direction = publication.mepsLanguage.isRtl ? 'rtl' : 'ltr';

  String showRuby = '';
  if(document.hasPronunciationGuide) {
    final languageCode = publication.mepsLanguage.primaryIetfCode;
    if (languageCode == 'ja' && JwLifeSettings.instance.webViewData.isFuriganaActive) {
      showRuby = 'showRuby';
    }
    else if (languageCode.contains('cmn') && JwLifeSettings.instance.webViewData.isPinyinActive) {
      showRuby = 'showRuby';
    }
    else if (JwLifeSettings.instance.webViewData.isYaleActive) {
      showRuby = 'showRuby';
    }
  }

  String classString = [
    type,
    'jwac',
    'pub-$keySymbol',
    'docClass-$docClass',
    'docId-$docId',
    'ms-$scriptName',
    'ml-$languageSymbol',
    'dir-$direction',
    'layout-reading',
    'layout-sidebar',
    showRuby
  ].join(' ');

  return classString;
}

Future<void> showFontSizeDialog(BuildContext context, InAppWebViewController? controller) async {
  double fontSize = JwLifeSettings.instance.webViewData.fontSize;
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
                      Text(i18n().action_text_settings, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                          JwLifeSettings.instance.webViewData.updateFontSize(fontSize);
                          AppSharedPreferences.instance.setFontSize(fontSize);
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
                        i18n().action_done_uppercase,
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
                            i18n().action_close_upper,
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

void showAudioPopupMenu(BuildContext context, Publication publication, int audioIndex) async {
  // Définition d'un décalage vertical
  const double verticalOffset = 50.0;

  // 1. Calcul de la position du menu
  final RenderBox button = context.findRenderObject() as RenderBox;

  // Point supérieur gauche décalé de 50 pixels vers le bas
  final Offset topLeft = button.localToGlobal(Offset.zero).translate(0.0, verticalOffset);

  // Point inférieur droit décalé de 50 pixels vers le bas
  final Offset bottomRight = button.localToGlobal(button.size.bottomRight(Offset.zero)).translate(0.0, verticalOffset);

  // Création du RelativeRect avec les points décalés
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      topLeft,
      bottomRight,
    ),
    Offset.zero & MediaQuery.of(context).size,
  );

  // 2. Affichage du menu et attente du choix de l'utilisateur
  // Nous utilisons String comme type de retour pour le showMenu.
  final String? result = await showMenu<String>(
    context: context,
    position: position,
    items: <PopupMenuEntry<String>>[
      // Écouter l'audio
      PopupMenuItem<String>(
        value: 'listen', // Utilisation de la constante String
        child: ListTile(
          dense: true,
          leading: Icon(JwIcons.play, color: Theme.of(context).primaryColor),
          title: Text(i18n().action_play_audio),
        ),
      ),
      // Télécharger l'audio
      PopupMenuItem<String>(
        value: 'download', // Utilisation de la constante String
        child: ListTile(
          dense: true,
          leading: Icon(publication.audiosNotifier.value.elementAt(audioIndex).isDownloadedNotifier.value ? JwIcons.trash : JwIcons.cloud_arrow_down, color: Theme.of(context).primaryColor),
          title: Text(publication.audiosNotifier.value.elementAt(audioIndex).isDownloadedNotifier.value ? i18n().action_delete_audio : i18n().action_download_audio),
        ),
      ),
    ],
  );

  // 3. Gestion du résultat
  if (result != null) {
    switch (result) {
      case 'listen':
        showAudioPlayerPublicationLink(context, publication, audioIndex);
        break;

      case 'download':
        if(publication.audiosNotifier.value.elementAt(audioIndex).isDownloadedNotifier.value) {
          publication.audiosNotifier.value.elementAt(audioIndex).remove(context);
        }
        else {
          publication.audiosNotifier.value.elementAt(audioIndex).download(context);
        }
        break;

      default:
        return;
    }
  }
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
                      '${i18n().action_bookmarks} - ${publication.getShortTitle()}',
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
                                              Icons.more_horiz,
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
                                                  child: Text(i18n().action_delete),
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
                                                  child: Text(i18n().action_replace),
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
                          i18n().action_done_uppercase,
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

Future<void> showImportVideo(BuildContext context, String keySymbol, int issueTagNumber, int mepsLanguageId) async {
  await showJwDialog<void>(
    context: context,
    titleText: i18n().message_publication_unavailable_title,
    contentText: i18n().action_import_file,
    buttons: [
      JwDialogButton(
        label: i18n().action_close_upper,
        closeDialog: true,
      ),
      JwDialogButton(
        label: i18n().label_import.toUpperCase(),
        closeDialog: false,
        onPressed: (buildContext) async {
          Navigator.of(buildContext).pop(); // Ferme le 1er dialog
          // Demander un fichier à l'utilisateur
          FilePicker.platform.pickFiles(allowMultiple: true).then((result) async {
            if (result != null) {
              for (PlatformFile f in result.files) {
                File file = File(f.path!);
                if (file.path.endsWith('.jwpub')) {
                  FileHandlerService().processJwPubFile(file.path, keySymbol: keySymbol, issueTagNumber: issueTagNumber, mepsLanguageId: mepsLanguageId);
                }
              }
            }
          });
        },
      ),
    ],
  );
}