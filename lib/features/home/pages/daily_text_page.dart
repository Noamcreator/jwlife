import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_page.dart';
import 'package:uuid/uuid.dart';

import '../../../app/jwlife_app.dart';
import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/directory_helper.dart';
import '../../../core/utils/shared_preferences_helper.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_video.dart';
import '../../../core/utils/widgets_utils.dart';
import '../../../core/webview/webview_javascript.dart';
import '../../../core/webview/webview_utils.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../data/realm/catalog.dart';
import '../../../widgets/dialog/language_dialog_pub.dart';
import '../../../widgets/dialog/publication_dialogs.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../../widgets/searchfield/searchfield_widget.dart';
import '../../personal/pages/tag_page.dart';
import '../../publication/pages/document/local/dated_text_manager.dart';
import '../../publication/pages/document/local/document_medias_page.dart';
import '../../publication/pages/document/local/documents_manager.dart';
import '../../publication/pages/document/local/full_screen_image_page.dart';

class DailyTextPage extends StatefulWidget {
  final Publication publication;

  const DailyTextPage({super.key, required this.publication});

  @override
  DailyTextPageState createState() => DailyTextPageState();
}

class DailyTextPageState extends State<DailyTextPage> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late InAppWebViewController _controller;

  /* SEARCH */
  bool _isSearching = false;
  List<Map<String, dynamic>> suggestions = [];

  /* LOADING */
  bool _isLoadingData = false;
  bool _isLoadingWebView = false;
  bool _isLoadingFonts = false;

  /* OTHER VIEW */
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _controlsVisibleSave = true; // Variable pour contrôler la visibilité des contrôles
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> init() async {
    if(widget.publication.datedTextManager != null) {
      int index = widget.publication.datedTextManager!.convertDateToInt(DateTime.now());
      widget.publication.datedTextManager!.selectedDatedTextIndex = widget.publication.datedTextManager!.datedTexts.indexWhere((element) => element.firstDateOffset == index);
    }
    else {
      widget.publication.datedTextManager = DatedTextManager(publication: widget.publication, dateTime: DateTime.now());
      await widget.publication.datedTextManager!.initializeDatabaseAndData();
    }

    setState(() {
      _isLoadingData = true;
    });

    await widget.publication.datedTextManager!.getCurrentDatedText().changePageAt();
  }

  Future<void> changePageAt(int index) async {
    if (index <= widget.publication.datedTextManager!.datedTexts.length - 1 && index >= 0) {
      setState(() {
        widget.publication.datedTextManager!.selectedDatedTextIndex = index;
      });

      await widget.publication.datedTextManager!.getCurrentDatedText().changePageAt();
    }
  }

  Future<void> _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('[data-pid]', 'data-pid', $beginParagraphOrdinal, $endParagraphOrdinal);");
  }

  Future<void> _jumpToPage(int page) async {
    if (page != widget.publication.datedTextManager!.selectedDatedTextIndex) {
      _pageHistory.add(widget.publication.datedTextManager!.selectedDatedTextIndex); // Ajouter la page actuelle à l'historique
      _currentPageHistory = page;

      widget.publication.datedTextManager!.selectedDatedTextIndex = page;
      await _controller.evaluateJavascript(source: 'jumpToPage($page);');

      setControlsVisible(true);

      setState(() {});
    }
  }

  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility.call(_controlsVisible);
  }

  Future<bool> _canHandleBackPress() async {
    if (_pageHistory.isNotEmpty) {
      if(_currentPageHistory == -1) {
        _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
        await _controller.loadData(data: createReaderHtmlShell(
            widget.publication,
            widget.publication.datedTextManager!.selectedDatedTextIndex,
            widget.publication.datedTextManager!.datedTexts.length - 1
        ), baseUrl: WebUri('file://${JwLifeSettings().webViewData.webappPath}/'));
      }
      else {
        _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
        await _controller.evaluateJavascript(source: 'jumpToPage($_currentPageHistory);');
      }
      return false; // Ne pas quitter l'application
    }
    return true; // Quitter la vue si aucun historique
  }

  Future<void> handleBackPress() async {
    if(_isSearching) {
      setState(() {
        _isSearching = false;
      });
    }
    else if(_showDialog) {
      _showDialog = false;
      _controller.evaluateJavascript(source: "removeDialog();");
      setState(() {
        setControlsVisible(_controlsVisibleSave);
      });
    }
    else {
      if (await _canHandleBackPress()) {
        final jwLifeState = GlobalKeyService.jwLifePageKey.currentState;
        if (jwLifeState == null) return;

        final currentIndex = jwLifeState.currentIndex;
        final webViewStack = jwLifeState.webViewPageKeys[currentIndex];

        if (webViewStack.isNotEmpty) {
          webViewStack.removeLast();
        }

        if (webViewStack.isEmpty) {
          jwLifeState.handleBack(context);
        }
        else {
          final currentNavigator = jwLifeState.navigatorKeys[currentIndex].currentState;
          if (currentNavigator?.canPop() ?? false) {
            currentNavigator!.pop();
          }
        }
      }
    }
  }

  /*
  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last.toLowerCase().trim();

    Multimedia? multimedia = widget.publication.datedTextManager!.getCurrentDatedText().multimedias.firstWhereOrNull((img) => img.filePath.toLowerCase().trim().contains(newPath));

    if(multimedia == null) return;
    if (!multimedia.hasSuppressZoom) {
      showPage(context, FullScreenImagePage(
          publication: widget.publication,
          multimedias: widget.publication.datedTextManager!.getCurrentDatedText().multimedias,
          multimedia: multimedia
      ));
    }
  }

   */

  void changeTheme(ThemeMode themeMode) {
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
      body: Stack(children: [
        Visibility(
          visible: _isLoadingWebView,
          maintainState: true,
          child: _isLoadingData ? InAppWebView(
              initialSettings: InAppWebViewSettings(
                scrollBarStyle: null,
                verticalScrollBarEnabled: false,
                horizontalScrollBarEnabled: false,
                disableContextMenu: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                useOnLoadResource: false,
                allowUniversalAccessFromFileURLs: true,
                allowFileAccess: true,
                allowContentAccess: true,
                useHybridComposition: true,
                hardwareAcceleration: true,
                databaseEnabled: false,
              ),
              initialData: InAppWebViewInitialData(
                  data: createReaderHtmlShell(
                      widget.publication,
                      widget.publication.datedTextManager!.selectedDatedTextIndex,
                      widget.publication.datedTextManager!.datedTexts.length - 1
                  ),
                  baseUrl: WebUri('file://${JwLifeSettings().webViewData.webappPath}/')
              ),
              onWebViewCreated: (controller) async {
                _controller = controller;

                controller.addJavaScriptHandler(
                    handlerName: 'fontsLoaded',
                    callback: (args) {
                      setState(() {
                        _isLoadingFonts = true;
                      });
                    }
                );

                controller.addJavaScriptHandler(
                  handlerName: 'showDialog',
                  callback: (args) {
                    bool isShowDialog = args[0] as bool;
                    _showDialog = isShowDialog;
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'showFullscreenDialog',
                  callback: (args) {
                    bool isMaximized = args[0] as bool;
                    setState(() {
                      if(isMaximized) {
                        setControlsVisible(true);
                      }
                      else {
                        setControlsVisible(_controlsVisibleSave);
                      }
                    });
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'getPage',
                  callback: (args) async {
                    final index = args[0] as int;
                    if (index < 0 || index >= widget.publication.datedTextManager!.datedTexts.length) {
                      return {'html': '', 'className': '', 'audiosMarkers': '', 'isBibleChapter': false};
                    }

                    final datedText = widget.publication.datedTextManager!.datedTexts[index];
                    String html = decodeBlobContent(datedText.content!, widget.publication.hash!);

                    final className = [
                      'document',
                      'jwac',
                      'pub-${widget.publication.symbol}',
                      'docClass-${widget.publication.datedTextManager!.datedTexts[index].classType}',
                      'docId-${widget.publication.datedTextManager!.datedTexts[index].mepsDocumentId}',
                      'ms-${widget.publication.mepsLanguage.internalScriptName}',
                      'ml-${widget.publication.mepsLanguage.symbol}',
                      'dir-${widget.publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'}',
                      'layout-reading',
                      'layout-sidebar',
                      JwLifeSettings().webViewData.theme,
                    ].join(' ');

                    return {
                      'html': html,
                      'className': className,
                      'audiosMarkers': [],
                      'isBibleChapter': false,
                      'link': 'jwpub://${datedText.link}'
                    };
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'changePageAt',
                  callback: (args) async {
                    await changePageAt(args[0] as int);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'getUserdata',
                  callback: (args) {
                    for(var note in widget.publication.datedTextManager!.getCurrentDatedText().notes) {
                      printTime('note: $note');
                    }
                    return {
                      'highlights': widget.publication.datedTextManager!.getCurrentDatedText().highlights,
                      'notes': widget.publication.datedTextManager!.getCurrentDatedText().notes,
                      'inputFields': [],
                      'bookmarks': widget.publication.datedTextManager!.getCurrentDatedText().bookmarks,
                    };
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'getTags',
                  callback: (args) {
                    return {
                      'tags': JwLifeApp.userdata.tags.map((t) => t.toMap()).toList(),
                    };
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'onScroll',
                  callback: (args) async {
                    if (JwLifeSettings().webViewData.isFullScreen) {
                      if (args[1] == "down") {
                        setState(() {
                          _controlsVisible = false;
                          _controlsVisibleSave = false;
                        });
                        // enelever la barre de noti en haut de l'ecran
                        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(false);
                      }
                      else if (args[1] == "up") {
                        setState(() {
                          _controlsVisible = true;
                          _controlsVisibleSave = true;
                        });
                        // remettre la barre de noti en haut de l'ecran
                        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarVisibility(true);
                      }
                    }
                  },
                );

                // Récupérer un guid pour un highlight
                controller.addJavaScriptHandler(
                  handlerName: 'getHighlightGuid',
                  callback: (args) {
                    var uuid = Uuid();
                    return {
                      'guid': uuid.v4()
                    };
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'addHighlights',
                  callback: (args) {
                    printTime('addHighlights ${args[0]} ${args[1]} ${args[2]}');
                    widget.publication.datedTextManager!.getCurrentDatedText().addHighlights(
                        args[0],
                        args[1],
                        args[2]
                    );
                  },
                );

                // Quand on clique supprime le highlight
                controller.addJavaScriptHandler(
                    handlerName: 'removeHighlight',
                    callback: (args) {
                      widget.publication.datedTextManager!.getCurrentDatedText().removeHighlight(args[0]['guid']);
                    }
                );

                // Quand on change le color index d'un highlight
                controller.addJavaScriptHandler(
                    handlerName: 'changeHighlightColor',
                    callback: (args) {
                      widget.publication.datedTextManager!.getCurrentDatedText().changeHighlightColor(args[0]['guid'], args[0]['newColorIndex']);
                    }
                );


                controller.addJavaScriptHandler(
                  handlerName: 'addNote',
                  callback: (args) {
                    var uuid = Uuid();
                    String uuidV4 = uuid.v4();

                    widget.publication.datedTextManager!.getCurrentDatedText().addNoteWithUserMarkGuid(
                      args[0]['blockType'],
                      int.parse(args[0]['identifier']),
                      args[0]['title'],
                      uuidV4,
                      args[0]['userMarkGuid'],
                      args[0]['colorIndex'],
                    );
                    return {
                      'uuid': uuidV4
                    };
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'removeNote',
                  callback: (args) {
                    String guid = args[0]['guid'];
                    widget.publication.datedTextManager!.getCurrentDatedText().removeNote(guid);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'updateNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    String title = args[0]['title'];
                    String content = args[0]['content'];
                    widget.publication.datedTextManager!.getCurrentDatedText().updateNote(uuid, title, content);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'addTagToNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    int tagId = args[0]['tagId'];
                    widget.publication.datedTextManager!.getCurrentDatedText().addTagToNote(uuid, tagId);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'removeTagToNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    int tagId = args[0]['tagId'];
                    widget.publication.datedTextManager!.getCurrentDatedText().removeTagToNote(uuid, tagId);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'openTagPage',
                  callback: (args) {
                    int tagId = args[0]['tagId'];
                    showPage(context, TagPage(tag: JwLifeApp.userdata.tags.firstWhere((tag) => tag.id == tagId)));
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'addTag',
                  callback: (args) {
                    String tagName = args[0]['tagName'];
                    JwLifeApp.userdata.addTag(tagName, 1);
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchVerses',
                  callback: (args) async {
                    Map<String, dynamic>? verses = await fetchVerses(context, args[0]);
                    printTime('fetchVerses $verses');
                    return verses;
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchExtractPublication',
                  callback: (args) async {
                    Map<String, dynamic>? extractPublication = await fetchExtractPublication(context, 'daily', widget.publication.datedTextManager!.database, widget.publication, args[0], _jumpToPage, _jumpToParagraph);
                    if (extractPublication != null) {
                      printTime('fetchExtractPublication $extractPublication');
                      return extractPublication;
                    }
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchFootnote',
                  callback: (args) async {
                    Map<String, dynamic> footnote = await fetchFootnote(context, widget.publication, args[0]);
                    printTime('fetchFootnote $footnote');
                    return footnote;
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchVersesReference',
                  callback: (args) async {
                    Map<String, dynamic> versesReference = await fetchVersesReference(context, widget.publication, controller, args[0]);
                    return versesReference;
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'openMepsDocument',
                  callback: (args) async {
                    Map<String, dynamic>? document = args[0];
                    if (document != null) {
                      if (document['mepsDocumentId'] != null) {
                        bool saveControlsVisible = _controlsVisible;

                        if (!saveControlsVisible) {
                          GlobalKeyService.jwLifePageKey.currentState?.toggleNavBarVisibility(true);
                        }

                        await showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);

                        GlobalKeyService.jwLifePageKey.currentState?.toggleNavBarVisibility(saveControlsVisible);
                      }
                      else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                        bool saveControlsVisible = _controlsVisible;

                        if (!saveControlsVisible) {
                          GlobalKeyService.jwLifePageKey.currentState?.toggleNavBarVisibility(true);
                        }

                        await showChapterView(
                          context,
                          'nwtsty',
                          document["mepsLanguageId"],
                          document["bookNumber"],
                          document["chapterNumber"],
                          firstVerseNumber: document["firstVerseNumber"],
                          lastVerseNumber: document["lastVerseNumber"],
                        );

                        GlobalKeyService.jwLifePageKey.currentState?.toggleNavBarVisibility(saveControlsVisible);
                      }
                    }
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'bookmark',
                  callback: (args) async {
                    final arg = args[0];

                    final bool isBible = arg['isBible'];
                    final String id = arg['id'];
                    final String snippet = arg['snippet'];

                    final docManager = widget.publication.datedTextManager!;
                    final currentDoc = docManager.getCurrentDatedText();

                    // Cas d’un paragraphe classique
                    int? blockIdentifier = int.tryParse(id);
                    int blockType = blockIdentifier != null ? 1 : 0;

                    printTime('blockIdentifier: $blockIdentifier');
                    printTime('blockType: $blockType');
                    printTime('mepsDocumentId: ${currentDoc.mepsDocumentId}');
                    printTime('title: ${currentDoc.getTitle()}');

                    Bookmark? bookmark = await showBookmarkDialog(
                      context,
                      widget.publication,
                      webViewController: _controller,
                      mepsDocumentId: currentDoc.mepsDocumentId,
                      title: currentDoc.getTitle(),
                      snippet: snippet.trim(),
                      blockType: blockType,
                      blockIdentifier: blockIdentifier,
                    );

                    if(bookmark != null) {
                      if (bookmark.location.mepsDocumentId != null) {
                        final page = docManager.datedTexts.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);
                        if (page != widget.publication.datedTextManager!.selectedDatedTextIndex) {
                          await _jumpToPage(page);
                        }
                      }

                      // Aller au paragraphe dans la même page
                      if (bookmark.blockIdentifier != null) {
                        _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                      }
                    }
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'share',
                  callback: (args) async {
                    final arg = args[0];

                    final String id = arg['id'];

                    widget.publication.datedTextManager!.getCurrentDatedText().share(id: id);
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'copyText',
                  callback: (args) async {
                    Clipboard.setData(ClipboardData(text: args[0]['text']));
                    showBottomMessage(context, 'Texte copié dans le presse-papier');
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'search',
                  callback: (args) async {
                    String query = args[0]['query'];
                    showPage(context, SearchPage(query: query));
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'onVideoClick',
                  callback: (args) async {
                    String link = args[0];

                    printTime('Link: $link');
                    // Extraire les paramètres
                    Uri uri = Uri.parse(link);
                    String? pub = uri.queryParameters['pub'];
                    int? issue = uri.queryParameters['issue'] != null ? int.parse(uri.queryParameters['issue']!) : null;
                    int? docId = uri.queryParameters['docid'] != null ? int.parse(uri.queryParameters['docid']!) : null;
                    int? track = uri.queryParameters['track'] != null ? int.parse(uri.queryParameters['track']!) : null;

                    MediaItem? mediaItem = getVideoItem(pub, track, docId, issue, null);

                    if(mediaItem != null) {
                      showVideoDialog(context, mediaItem).then((result) {
                        if (result == 'play') { // Vérifiez si le résultat est 'play'
                          showFullScreenVideo(context, mediaItem);
                        }
                      });
                    }
                    else {

                    }
                  },
                );
              },
              shouldInterceptRequest: (controller, request) async {
                String requestedUrl = '${request.url}';

                /*
                if (requestedUrl.startsWith('jwpub-media://')) {
                  printTime('Requested URL: $requestedUrl');
                  final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                  return await widget.publication.datedTextManager!.getCurrentDatedText().getImagePathFromDatabase(filePath);
                }

                 */
                return null;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                WebUri uri = navigationAction.request.url!;
                String url = uri.uriValue.toString();

                if(url.startsWith('jwpub://')) {
                  return NavigationActionPolicy.CANCEL;
                }
                else if (url.startsWith('webpubdl://')) {
                  final uri = Uri.parse(url);

                  final pub = uri.queryParameters['pub'];
                  final docId = uri.queryParameters['docid'];
                  final track = uri.queryParameters['track'];
                  final fileformat = uri.queryParameters['fileformat'];
                  final langwritten = uri.queryParameters['langwritten'] ?? widget.publication.mepsLanguage.symbol;

                  if ((pub != null || docId != null) && fileformat != null) {
                    showDocumentDialog(context, pub, docId, track, langwritten, fileformat);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                else if (uri.host == 'www.jw.org' && uri.path == '/finder') {
                  if(uri.queryParameters.containsKey('wtlocale')) {
                    final wtlocale = uri.queryParameters['wtlocale'];
                    if (uri.queryParameters.containsKey('lank')) {
                      MediaItem? mediaItem;
                      if(uri.queryParameters.containsKey('lank')) {
                        final lank = uri.queryParameters['lank'];
                        mediaItem = getVideoItemFromLank(lank!, wtlocale!);
                      }

                      showVideoDialog(context, mediaItem!).then((result) {
                        if (result == 'play') { // Vérifiez si le résultat est 'play'
                          showFullScreenVideo(context, mediaItem!);
                        }
                      });
                    }
                    else if (uri.queryParameters.containsKey('pub')) {
                      // Récupère les paramètres
                      final pub = uri.queryParameters['pub'];
                      final issueTagNumber = uri.queryParameters.containsKey('issueTagNumber') ? int.parse(uri.queryParameters['issueTagNumber']!) : 0;

                      Publication? publication = await PubCatalog.searchPub(pub!, issueTagNumber, wtlocale!);
                      if (publication != null) {
                        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarPositioned(false);
                        await publication.showMenu(context);
                        GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarPositioned(true);
                      }
                    }
                    else if(uri.queryParameters.containsKey('docID')) {
                      _pageHistory.add(widget.publication.datedTextManager!.selectedDatedTextIndex); // Ajouter la page actuelle à l'historique
                      _currentPageHistory = -1;

                      setState(() {
                        setControlsVisible(true);
                      });
                      return NavigationActionPolicy.ALLOW;
                    }
                  }

                  // Annule la navigation pour gérer le lien manuellement
                  return NavigationActionPolicy.CANCEL;
                }

                _pageHistory.add(widget.publication.datedTextManager!.selectedDatedTextIndex); // Ajouter la page actuelle à l'historique
                _currentPageHistory = -1;

                setState(() {
                  setControlsVisible(true);
                });
                // Permet la navigation pour tous les autres liens
                return NavigationActionPolicy.ALLOW;
              },
              onProgressChanged: (controller, progress) {
                if(progress == 100) {
                  setState(() {
                    _isLoadingWebView = true;
                  });
                }
              }
          ) : Container(),
        ),

        if (!_isLoadingFonts)
          getLoadingWidget(Theme.of(context).primaryColor),


        if (_controlsVisible)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                title: !_isLoadingData ? Container() : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.publication.datedTextManager!.getCurrentDatedText().getTitle(),
                      style: textStyleTitle,
                    ),
                    Text(
                      widget.publication.shortTitle,
                      style: textStyleSubtitle,
                    ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    handleBackPress();
                  },
                ),
                actions: [
                  if (!_isSearching)
                    !_isLoadingData ? Container() : ResponsiveAppBarActions(
                      allActions: [
                        IconTextButton(
                          text: "Marque-pages",
                          icon: Icon(JwIcons.bookmark),
                          onPressed: () async {
                            Bookmark? bookmark = await showBookmarkDialog(context, widget.publication, webViewController: _controller, mepsDocumentId: widget.publication.datedTextManager!.getCurrentDatedText().mepsDocumentId, title: widget.publication.datedTextManager!.getCurrentDatedText().getTitle(), snippet: '', blockType: 0, blockIdentifier: null);
                            if (bookmark != null) {
                              if(bookmark.location.mepsDocumentId != widget.publication.datedTextManager!.getCurrentDatedText().mepsDocumentId) {
                                int page = widget.publication.datedTextManager!.datedTexts.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);

                                if (page != widget.publication.datedTextManager!.selectedDatedTextIndex) {
                                  await _jumpToPage(page);
                                }

                                if (bookmark.blockIdentifier != null) {
                                  _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                                }
                              }
                            }
                          },
                        ),
                        IconTextButton(
                          text: "Langues",
                          icon: Icon(JwIcons.language),
                          onPressed: () async {
                            LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: widget.publication);
                            showDialog(
                              context: context,
                              builder: (context) => languageDialog,
                            ).then((value) {
                              if (value != null) {
                                widget.publication.showMenu(context, mepsLanguage: value);
                              }
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Historique",
                          icon: const Icon(JwIcons.arrow_circular_left_clock),
                          onPressed: () {
                            History.showHistoryDialog(context);
                          },
                        ),
                        IconTextButton(
                          text: "Envoyer le lien",
                          icon: Icon(JwIcons.share),
                          onPressed: () {
                            widget.publication.datedTextManager!.getCurrentDatedText().share();
                          },
                        ),
                        IconTextButton(
                          text: "Taille de police",
                          icon: Icon(JwIcons.device_text),
                          onPressed: () {
                            showFontSizeDialog(context, _controller);
                          },
                        ),
                        IconTextButton(
                          text: "Plein écran",
                          icon: Icon(JwIcons.square_stack),
                          onPressed: () async {
                            bool isFullscreen = await showFullscreenDialog(context);
                            await setFullscreen(isFullscreen);
                            JwLifeSettings().webViewData.updateFullscreen(isFullscreen);
                          },
                        ),
                      ],
                    ),
                ],
              )
          ),
      ]),
    );
  }
}
