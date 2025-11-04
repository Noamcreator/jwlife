
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../core/utils/utils_search.dart';
import '../../../core/utils/utils_video.dart';
import '../../../core/utils/widgets_utils.dart';
import '../../../core/webview/webview_javascript.dart';
import '../../../core/webview/webview_utils.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/models/video.dart';
import '../../../data/realm/catalog.dart';
import '../../../widgets/dialog/publication_dialogs.dart';
import '../../../core/utils/utils_dialog.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../personal/pages/tag_page.dart';
import '../../publication/pages/document/local/dated_text_manager.dart';

class DailyTextPage extends StatefulWidget {
  final Publication publication;
  final DateTime? date;

  const DailyTextPage({super.key, required this.publication, this.date});

  @override
  DailyTextPageState createState() => DailyTextPageState();
}

class DailyTextPageState extends State<DailyTextPage> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late InAppWebViewController _controller;

  final GlobalKey<_ControlsOverlayState> controlsKey = GlobalKey<_ControlsOverlayState>();

  /* LOADING */
  bool _isLoadingData = false;
  bool _isLoadingFonts = false;

  /* OTHER VIEW */
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
      int index = convertDateTimeToIntDate(widget.date ?? DateTime.now());
      widget.publication.datedTextManager!.selectedDatedTextIndex = widget.publication.datedTextManager!.datedTexts.indexWhere((element) => element.firstDateOffset == index);
    }
    else {
      widget.publication.datedTextManager = DatedTextManager(publication: widget.publication, dateTime: widget.date ?? DateTime.now());
      await widget.publication.datedTextManager!.initializeDatabaseAndData();
    }

    setState(() {
      _isLoadingData = true;
    });
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

      controlsKey.currentState?.toggleControls(true);
    }
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

  Future<bool> handleBackPress({bool fromPopScope = false}) async {
    if(_showDialog) {
      _controller.evaluateJavascript(source: "closeDialog();");
      controlsKey.currentState?.setControlsBySave();
      return false;
    }
    else {
      if (await _canHandleBackPress()) {
        if(fromPopScope) {
          return true;
        }
        else {
          GlobalKeyService.jwLifePageKey.currentState!.handleBack(context);
          return false;
        }
      }
    }
    return true;
  }

  Future<void> changeTheme(bool isDark) async {
    await _controller.evaluateJavascript(source: "changeTheme($isDark);");
  }

  Future<void> changeStyleAndColorIndex(int styleIndex, colorIndex) async {
    await _controller.evaluateJavascript(source: "changeStyleAndColorIndex($styleIndex, $colorIndex);");
  }

  Future<void> changeFullScreenMode(bool isFullScreen) async {
    await _controller.evaluateJavascript(source: "changeFullScreenMode($isFullScreen);");
  }

  Future<void> changePrimaryColor(Color lightColor, Color darkColor) async {
    final lightPrimaryColor = toHex(lightColor);
    final darkPrimaryColor = toHex(darkColor);

    await _controller.evaluateJavascript(source: "changePrimaryColor($lightPrimaryColor, $darkPrimaryColor);");
  }

  Future<void> toggleAudioPlayer(bool visible) async {
    await _controller.evaluateJavascript(source: "toggleAudioPlayer($visible);");
    updateBottomBar();
  }

  Future<void> updateBottomBar() async {
    controlsKey.currentState?.refreshWidget();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
        body: Stack(
            children: [
              _isLoadingData ? SafeArea(
                  child:  InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      scrollBarStyle: null,
                      verticalScrollBarEnabled: false,
                      horizontalScrollBarEnabled: false,
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      useOnLoadResource: false,
                      allowUniversalAccessFromFileURLs: true,
                      allowFileAccess: true,
                      allowContentAccess: true,
                      useHybridComposition: true,
                      hardwareAcceleration: true,
                      forceDark: ForceDark.OFF,
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

                      controlsKey.currentState?.initInAppWebViewController(controller);

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
                          controlsKey.currentState?.toggleMaximized(isMaximized);
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getSettings',
                        callback: (args) {
                          final webViewData = JwLifeSettings().webViewData;

                          return {
                            'isDark': webViewData.theme == 'cc-theme--dark',
                            'isFullScreen': webViewData.isFullScreenMode,
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'showConfirmationDialog',
                        callback: (args) async {
                          // Récupérer les paramètres envoyés depuis JS
                          final Map<String, dynamic> params = args.isNotEmpty ? args[0] : {};
                          final String title = params['title'] ?? 'Confirmation';
                          final String message = params['message'] ?? 'Êtes-vous sûr ?';

                          // Affiche un dialog Flutter et retourne la réponse
                          final bool? confirmed = await showJwDialog(
                              context: context,
                              titleText: title,
                              contentText: message,
                              buttonAxisAlignment: MainAxisAlignment.end,
                              buttons: [
                                JwDialogButton(
                                    label: 'NON',
                                    closeDialog: false,
                                    onPressed: (buildContext) async {
                                      Navigator.of(buildContext).pop(false);
                                    }
                                ),
                                JwDialogButton(
                                    label: 'OUI',
                                    closeDialog: false,
                                    onPressed: (buildContext) async {
                                      Navigator.of(buildContext).pop(true);
                                    }
                                ),
                              ]
                          );

                          return confirmed ?? false; // Retourne false si null
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
                          return {
                            'blockRanges': widget.publication.datedTextManager!.getCurrentDatedText().blockRanges,
                            'notes': widget.publication.datedTextManager!.getCurrentDatedText().notes,
                            'inputFields': [],
                            'bookmarks': widget.publication.datedTextManager!.getCurrentDatedText().bookmarks,
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getNoteByGuid',
                        callback: (args) {
                          String guid = args[0] as String;
                          Map<String, dynamic>? note = widget.publication.datedTextManager!.getCurrentDatedText().notes.firstWhereOrNull((n) => n['Guid'] == guid) ?? widget.publication.datedTextManager!.getCurrentDatedText().extractedNotes.firstWhereOrNull((n) => n['Guid'] == guid);

                          return {
                            'title': note == null ? '' : note['Title'],
                            'content': note == null ? '' : note['Content'],
                            'tagsId': note == null ? [] : note['TagsId'],
                            'tags': JwLifeApp.userdata.tags.map((t) => t.toMap()).toList(),
                            'colorIndex': note == null ? 0 : note['ColorIndex'],
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getNotes',
                        callback: (args) {
                          // 1. Récupération des listes de notes (Notes + Notes extraites)
                          // On suppose ici que toutes les notes sont des Maps<String, dynamic>.
                          final List<Map<String, dynamic>> datedTextNotes = widget.publication.datedTextManager!.getCurrentDatedText().notes;

                          // 3. Récupération et formatage de la liste de tags disponibles
                          final List<Map<String, dynamic>> availableTags =
                          JwLifeApp.userdata.tags.map((t) => t.toMap()).toList();

                          // Trier en fonction de la valeur de BlockIdentifier
                          datedTextNotes.sort((a, b) => a['BlockIdentifier'].compareTo(b['BlockIdentifier']));

                          // 4. Mappage des notes pour inclure la liste de tous les tags dans chaque objet.
                          final List<Map<String, dynamic>> notesWithTags = datedTextNotes.map((note) {
                            return {
                              // Champs spécifiques à la note
                              'guid': note['Guid'],
                              'title': note['Title'] ?? '',
                              'content': note['Content'] ?? '',
                              'tagsId': note['TagsId'] ?? [],
                              'colorIndex': note['ColorIndex'] ?? 0,

                              // Liste de tous les tags disponibles (la même pour toutes les notes)
                              'tags': availableTags,
                            };
                          }).toList();

                          // 5. Retourne la liste complète des notes formatées
                          return notesWithTags;
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getFilteredTags',
                        callback: (args) {
                          String query = args[0] as String;
                          // Récupérer la liste brute
                          List<dynamic> dynamicTags = args[1] as List<dynamic>;

                          // ➡️ Ligne corrigée pour gérer les valeurs null ou non-entiers
                          List<int> tagsId = dynamicTags.where((e) => e is int).cast<int>().toList();

                          // Reste du code inchangé
                          return getFilteredTags(query, tagsId).map((t) => t.toMap()).toList();
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onScroll',
                        callback: (args) async {
                          if (args[1] == "down") {
                            controlsKey.currentState?.toggleOnScroll(false);
                          }
                          else if (args[1] == "up") {
                            controlsKey.currentState?.toggleOnScroll(true);
                          }
                        },
                      );

                      // Récupérer un guid pour un highlight
                      controller.addJavaScriptHandler(
                        handlerName: 'getGuid',
                        callback: (args) {
                          var uuid = Uuid();
                          return {
                            'guid': uuid.v4()
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addBlockRange',
                        callback: (args) {
                          printTime('addBlockRange ${args[0]} ${args[1]} ${args[2]} ${args[3]}');
                          widget.publication.datedTextManager!.getCurrentDatedText().addBlockRange(args[0], args[1], args[2], args[3]);
                        },
                      );

                      // Quand on clique supprime le highlight
                      controller.addJavaScriptHandler(
                          handlerName: 'removeBlockRange',
                          callback: (args) async {
                            bool showAlertDialog = args[0]['showAlertDialog'];
                            final blockRange = widget.publication.datedTextManager!.getCurrentDatedText().blockRanges.firstWhereOrNull((h) => h['UserMarkGuid'] == args[0]['guid']);
                            widget.publication.datedTextManager!.getCurrentDatedText().removeBlockRange(args[0]['guid']);
                            final note = widget.publication.datedTextManager!.getCurrentDatedText().notes.firstWhereOrNull((n) => n['UserMarkGuid'] == args[0]['guid']);

                            if(note != null) {
                              if(showAlertDialog) {
                                final String title = 'Supprimer';
                                final String message = 'Voulez-vous supprimer la note "${note['Title']}" associé à votre surlignage ?';

                                // Affiche un dialog Flutter et retourne la réponse
                                final bool? confirmed = await showJwDialog(
                                    context: context,
                                    titleText: title,
                                    contentText: message,
                                    buttonAxisAlignment: MainAxisAlignment.end,
                                    buttons: [
                                      JwDialogButton(
                                          label: 'NON',
                                          closeDialog: false,
                                          onPressed: (buildContext) async {
                                            Navigator.of(buildContext).pop(false);
                                          }
                                      ),
                                      JwDialogButton(
                                          label: 'OUI',
                                          closeDialog: false,
                                          onPressed: (buildContext) async {
                                            Navigator.of(buildContext).pop(true);
                                          }
                                      ),
                                    ]
                                );

                                if(confirmed == true) {
                                  controller.evaluateJavascript(source: 'removeNote("${note['Guid']}", false)');
                                  widget.publication.datedTextManager!.getCurrentDatedText().removeNote(note['Guid']);
                                }
                                else {
                                  controller.evaluateJavascript(source: 'removeNote("${note['Guid']}", false)');
                                }
                              }
                              else {
                                widget.publication.datedTextManager!.getCurrentDatedText().changeNoteUserMark(note['Guid'], args[0]['newGuid'], blockRange?['StyleIndex'] ?? 0, blockRange?['ColorIndex'] ?? 0);
                              }
                            }
                          }
                      );

                      // Quand on change le color index d'un highlight
                      controller.addJavaScriptHandler(
                          handlerName: 'changeBlockRangeStyle',
                          callback: (args) {
                            widget.publication.datedTextManager!.getCurrentDatedText().changeBlockRangeStyle(args[0]['guid'], args[0]['newStyleIndex'], args[0]['newColorIndex']);
                          }
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addNote',
                        callback: (args) {
                          var uuid = Uuid();
                          String uuidV4 = uuid.v4();

                          widget.publication.datedTextManager!.getCurrentDatedText().addNoteWithUserMarkGuid(
                            args[0]['blockType'],
                            args[0]['identifier'],
                            args[0]['title'],
                            uuidV4,
                            args[0]['userMarkGuid'],
                            0,
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
                          handlerName: 'changeNoteColor',
                          callback: (args) {
                            widget.publication.datedTextManager!.getCurrentDatedText().changeNoteColor(args[0]['guid'], args[0]['newStyleIndex'], args[0]['newColorIndex']);
                          }
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
                          showPage(TagPage(tag: JwLifeApp.userdata.tags.firstWhere((tag) => tag.id == tagId)));
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addTag',
                        callback: (args) async {
                          String tagName = args[0]['tagName'];
                          Tag? tag = await JwLifeApp.userdata.addTag(tagName, 1);
                          if (tag == null) return {};
                          return {
                            'tag': tag.toMap()
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'fetchVerses',
                        callback: (args) async {
                          Map<String, dynamic>? verses = await fetchVerses(widget.publication, args[0]);
                          return verses;
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'fetchGuideVerse',
                        callback: (args) async {
                          Map<String, dynamic>? extractPublication = await fetchGuideVerse(context, widget.publication, args[0]);
                          if (extractPublication != null) {
                            return extractPublication;
                          }
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'fetchExtractPublication',
                        callback: (args) async {
                          Map<String, dynamic>? extractPublication = await fetchExtractPublication(context, 'daily', widget.publication.datedTextManager!.database, widget.publication, args[0], _jumpToPage, _jumpToParagraph);
                          if (extractPublication != null) {
                            return extractPublication;
                          }
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'fetchFootnote',
                        callback: (args) async {
                          Map<String, dynamic> footnote = await fetchFootnote(context, widget.publication, args[0]);
                          printTime('fetchFootnote $footnote');
                          return footnote;
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'fetchVersesReference',
                        callback: (args) async {
                          Map<String, dynamic> versesReference = await fetchVersesReference(context, widget.publication, args[0]);
                          return versesReference;
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'openMepsDocument',
                        callback: (args) async {
                          Map<String, dynamic>? document = args[0];
                          if (document != null) {
                            if (document['mepsDocumentId'] != null) {
                              await showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);
                            }
                            else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                              await showChapterView(
                                context,
                                document["keySymbol"],
                                document["mepsLanguageId"],
                                document["bookNumber"],
                                document["chapterNumber"],
                                firstVerseNumber: document["firstVerseNumber"],
                                lastVerseNumber: document["lastVerseNumber"],
                              );
                            }
                          }
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'bookmark',
                        callback: (args) async {
                          final arg = args[0];

                          final bool isBible = arg['isBible'];
                          final int? id = arg['id'];
                          final String snippet = arg['snippet'];

                          final docManager = widget.publication.datedTextManager!;
                          final currentDoc = docManager.getCurrentDatedText();

                          // Cas d’un paragraphe classique
                          int? blockIdentifier = id;
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
                          final int id = arg['id'];

                          widget.publication.datedTextManager!.getCurrentDatedText().share(id: id);
                        },
                      );

                      // Gestionnaire pour les modifications des champs de formulaire
                      controller.addJavaScriptHandler(
                        handlerName: 'copyText',
                        callback: (args) async {
                          Clipboard.setData(ClipboardData(text: args[0]['text']));
                          showBottomMessage('Texte copié dans le presse-papier');
                        },
                      );

                      // Gestionnaire pour les modifications des champs de formulaire
                      controller.addJavaScriptHandler(
                        handlerName: 'search',
                        callback: (args) async {
                          String query = args[0]['query'];
                          showPage(SearchPage(query: query));
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
                          String? pub = uri.queryParameters['pub']?.toLowerCase();
                          int? issue = uri.queryParameters['issue'] != null ? int.parse(uri.queryParameters['issue']!) : null;
                          int? docId = uri.queryParameters['docid'] != null ? int.parse(uri.queryParameters['docid']!) : null;
                          int? track = uri.queryParameters['track'] != null ? int.parse(uri.queryParameters['track']!) : null;

                          MediaItem? mediaItem = getMediaItem(pub, track, docId, issue, null);

                          if(mediaItem != null) {
                            Video video = Video.fromJson(mediaItem: mediaItem);
                            video.showPlayer(context);
                          }
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'openCustomizeVersesDialog',
                        callback: (args) async {
                          bool hasChanges = await showCustomizeVersesDialog(context);
                          return hasChanges;
                        },
                      );
                    },
                    shouldInterceptRequest: (controller, request) async {

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

                        final pub = uri.queryParameters['pub']?.toLowerCase();
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
                        printTime('Requested URL: $url');
                        if(uri.queryParameters.containsKey('wtlocale')) {
                          final wtlocale = uri.queryParameters['wtlocale'];
                          if (uri.queryParameters.containsKey('lank')) {
                            MediaItem? mediaItem;
                            if(uri.queryParameters.containsKey('lank')) {
                              final lank = uri.queryParameters['lank'];
                              mediaItem = getMediaItemFromLank(lank!, wtlocale!);
                            }

                            Video video = Video.fromJson(mediaItem: mediaItem!);
                            video.showPlayer(context);
                          }
                          else if (uri.queryParameters.containsKey('pub')) {
                            // Récupère les paramètres
                            final pub = uri.queryParameters['pub']?.toLowerCase();
                            final issueTagNumber = uri.queryParameters.containsKey('issueTagNumber') ? int.parse(uri.queryParameters['issueTagNumber']!) : 0;

                            Publication? publication = await PubCatalog.searchPub(pub!, issueTagNumber, wtlocale!);
                            if (publication != null) {
                              await publication.showMenu(context);
                            }
                          }
                          else {
                            _pageHistory.add(widget.publication.datedTextManager!.selectedDatedTextIndex); // Ajouter la page actuelle à l'historique
                            _currentPageHistory = -1;

                            controlsKey.currentState?.toggleControls(true);

                            return NavigationActionPolicy.ALLOW;
                          }
                        }

                        // Annule la navigation pour gérer le lien manuellement
                        return NavigationActionPolicy.CANCEL;
                      }

                      _pageHistory.add(widget.publication.datedTextManager!.selectedDatedTextIndex); // Ajouter la page actuelle à l'historique
                      _currentPageHistory = -1;

                      controlsKey.currentState?.toggleControls(true);
                      // Permet la navigation pour tous les autres liens
                      return NavigationActionPolicy.ALLOW;
                    },
                    onProgressChanged: (controller, progress) async {
                      if (progress == 100) {
                        setState(() {
                          _isLoadingFonts = true;
                        });
                      }
                    },
                  )
              ) : Container(),

              if (!_isLoadingFonts)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                    child: Center(
                      child: getLoadingWidget(Theme.of(context).primaryColor),
                    ),
                  ),
                ),

              !_isLoadingData ? Container()
                  : ControlsOverlay(key: controlsKey,
                  publication: widget.publication,
                  handleBackPress: handleBackPress,
                  jumpToPage: _jumpToPage,
                  jumpToParagraph: _jumpToParagraph
              ),
            ]
        )
    );
  }
}


class ControlsOverlay extends StatefulWidget {
  final Publication publication;
  final Function() handleBackPress;
  final Function(int page) jumpToPage;
  final Function(int beginParagraphOrdinal, int endParagraphOrdinal) jumpToParagraph;

  const ControlsOverlay({super.key, required this.publication, required this.handleBackPress, required this.jumpToPage, required this.jumpToParagraph});

  @override
  _ControlsOverlayState createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  late InAppWebViewController _controller;

  bool _controlsVisible = true;
  bool _controlsVisibleSave = true;

  void initInAppWebViewController(InAppWebViewController controller) {
    _controller = controller;
  }

  void toggleControls(bool visible) {
    setState(() {
      _controlsVisible = visible;
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void toggleOnScroll(bool visible) {
    setState(() {
      _controlsVisible = visible;
      _controlsVisibleSave = visible;
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void setControlsBySave() {
    if(_controlsVisibleSave == _controlsVisible) return;
    setState(() {
      _controlsVisible = _controlsVisibleSave;
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void toggleMaximized(bool isMaximized) {
    setState(() {
      if(isMaximized) {
        _controlsVisible = true;
      }
      else {
        _controlsVisible = _controlsVisibleSave;
      }
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void changePageAt(int index) {
    setState(() {
      widget.publication.datedTextManager!.selectedDatedTextIndex = index;
      _controlsVisible = true;
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void refreshWidget() {
    setState(() {});
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

    return Stack(
      children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
                visible: _controlsVisible,
                child: AppBar(
                  title: Column(
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
                      widget.handleBackPress();
                    },
                  ),
                  actions: [
                    ResponsiveAppBarActions(
                      allActions: [
                        /*
                        IconTextButton(
                          text: "Marque-pages",
                          icon: Icon(JwIcons.bookmark),
                          onPressed: () async {
                            Bookmark? bookmark = await showBookmarkDialog(context, widget.publication, webViewController: _controller, mepsDocumentId: widget.publication.datedTextManager!.getCurrentDatedText().mepsDocumentId, title: widget.publication.datedTextManager!.getCurrentDatedText().getTitle(), snippet: '', blockType: 0, blockIdentifier: null);
                            if (bookmark != null) {
                              if(bookmark.location.mepsDocumentId != widget.publication.datedTextManager!.getCurrentDatedText().mepsDocumentId) {
                                int page = widget.publication.datedTextManager!.datedTexts.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);

                                if (page != widget.publication.datedTextManager!.selectedDatedTextIndex) {
                                  await widget.jumpToPage(page);
                                }

                                if (bookmark.blockIdentifier != null) {
                                  widget.jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                                }
                              }
                            }
                          },
                        ),

                         */
                        IconTextButton(
                          text: "Langues",
                          icon: Icon(JwIcons.language),
                          onPressed: () async {
                            showLanguagePubDialog(context, widget.publication).then((languagePub) async {
                              if(languagePub != null) {
                                languagePub.showMenu(context);
                              }
                            });
                          },
                        ),
                        IconTextButton(
                          icon: Icon(JwIcons.calendar),
                          text: 'Sélectionner une semaine',
                          onPressed: () async {
                            DateTime currentDate = widget.publication.datedTextManager!.getCurrentDatedText().getDate();

                            DateTime? selectedDay = await showMonthCalendarDialog(context, currentDate);

                            if (selectedDay != null) {
                              // Vérifie si on est dans la même année
                              bool sameYear = selectedDay.year == currentDate.year;

                              if (!sameYear) {
                                List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: selectedDay);

                                // Si Publication a un champ 'symbol' à tester
                                Publication? dailyTextPub = dayPubs.firstWhereOrNull((p) => p.keySymbol.contains('es'));

                                if (dailyTextPub == null) return;

                                showDailyText(context, dailyTextPub, date: selectedDay);
                              }
                              else {
                                int dateInt = convertDateTimeToIntDate(selectedDay);
                                int index = widget.publication.datedTextManager!.datedTexts.indexWhere((element) => element.firstDateOffset == dateInt);
                                widget.jumpToPage(index);
                              }
                            }
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
            )
        ),
      ],
    );
  }
}
