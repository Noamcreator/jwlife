import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_page.dart';
import 'package:jwlife/features/publication/pages/document/data/models/dated_text.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_page.dart';
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
import '../../../data/controller/block_ranges_controller.dart';
import '../../../data/controller/notes_controller.dart';
import '../../../data/controller/tags_controller.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/userdata/bookmark.dart';
import '../../../data/models/userdata/note.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/models/video.dart';
import '../../../data/realm/catalog.dart';
import '../../../i18n/i18n.dart';
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

  final GlobalKey<_LoadingWidgetState> loadingKey = GlobalKey<_LoadingWidgetState>();
  final GlobalKey<_ControlsOverlayState> controlsKey = GlobalKey<_ControlsOverlayState>();

  /* LOADING */
  bool _isLoadingData = false;

  /* OTHER VIEW */
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  late BlockRangesController _blockRangesController;
  late NotesController _notesController;
  late TagsController _tagsController;

  @override
  void initState() {
    super.initState();
    _blockRangesController = context.read<BlockRangesController>();
    _notesController = context.read<NotesController>();
    _tagsController = context.read<TagsController>();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _notesController.removeListener(_updateNotesListener);
    _tagsController.removeListener(_updateTagsListener);
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

  String? _lastSentNotes;

  // Dans init ou onLoadStop, tu crées des fonctions pour pouvoir les retirer :
  void _updateNotesListener() {
    if (!mounted) return;
    final notes = _notesController.getNotesByDocument(datedText: widget.publication.datedTextManager!.getCurrentDatedText()).map((note) => note.toMap()).toList();
    final jsonNotes = jsonEncode(notes);
    if (jsonNotes == _lastSentNotes) return;
    _lastSentNotes = jsonNotes;

    _controller.callAsyncJavaScript(
        functionBody: "updateAllNotesUI($jsonNotes);"
    );
  }

  void _updateTagsListener() {
    if (!mounted) return;
    final tags = _tagsController.tags.map((t) => t.toMap()).toList();
    final jsonTags = jsonEncode(tags);_controller.callAsyncJavaScript(functionBody: "updateTags($jsonTags);"
    );
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
        ), baseUrl: WebUri('file://${JwLifeSettings.instance.webViewData.webappPath}/'));
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

  Future<void> changeReadingMode(bool isReading) async {
    await _controller.evaluateJavascript(source: "changeReadingMode($isReading);");
  }

  Future<void> changePreparingMode(bool isPreparing) async {
    await _controller.evaluateJavascript(source: "changePreparingMode($isPreparing);");
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
    return AppPage(
        isWebview: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
        body: Stack(
            children: [
              _isLoadingData ? SafeArea(
                  child:  InAppWebView(
                    initialSettings: InAppWebViewSettings(
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
                        baseUrl: WebUri('file://${JwLifeSettings.instance.webViewData.webappPath}/')
                    ),
                    onWebViewCreated: (controller) async {
                      _controller = controller;

                      controlsKey.currentState?.initInAppWebViewController(controller);

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
                          final webViewData = JwLifeSettings.instance.webViewData;

                          return {
                            'isDark': webViewData.theme == 'cc-theme--dark',
                            'isFullScreenMode': webViewData.isFullScreenMode,
                            'isReadingMode': webViewData.isReadingMode,
                            'isBlockingHorizontallyMode': webViewData.isBlockingHorizontallyMode,
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
                                    label: i18n().action_no.toUpperCase(),
                                    closeDialog: false,
                                    onPressed: (buildContext) async {
                                      Navigator.of(buildContext).pop(false);
                                    }
                                ),
                                JwDialogButton(
                                    label: i18n().action_yes.toUpperCase(),
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
                            return {'title': '', 'html': '', 'className': '', 'audiosMarkers': '', 'isBibleChapter': false};
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
                            JwLifeSettings.instance.webViewData.theme,
                          ].join(' ');

                          if(loadingKey.currentState!.isLoadingFonts) {
                            loadingKey.currentState!.loadingFinish();
                          }

                          return {
                            'title': datedText.getTitle(),
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

                      controller.addJavaScriptHandler(
                        handlerName: 'getFilteredTags',
                        callback: (args) {
                          String query = args[0] as String;

                          List<dynamic> dynamicTags = args[1] as List<dynamic>;
                          List<int> tagsId = dynamicTags.where((e) => e is int).cast<int>().toList();
                          return getFilteredTags(query, tagsId).map((t) => t.toMap()).toList();
                        },
                      );

                      // Récupérer un guid
                      controller.addJavaScriptHandler(
                        handlerName: 'getGuid',
                        callback: (args) {
                          return {
                            'Guid': Uuid().v4()
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getUserdata',
                        callback: (args) {
                          DatedText datedText = widget.publication.datedTextManager!.getCurrentDatedText();
                          return {
                            'blockRanges': _blockRangesController.getBlockRangesByDocument(datedText: datedText).map((blockRange) => blockRange.toMap()).toList(),
                            'notes': _notesController.getNotesByDocument(datedText: datedText).map((note) => note.toMap()).toList(),
                            'tags': _tagsController.tags.map((tag) => tag.toMap()).toList(),
                            'inputFields': [],
                            'bookmarks': widget.publication.datedTextManager!.getCurrentDatedText().bookmarks,
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addBlockRanges',
                        callback: (args) {
                          String guid = args[0];
                          int styleIndex = args[1];
                          int colorIndex = args[2];
                          List<dynamic> blockRangeParagraphs = args[3];

                          _blockRangesController.addBlockRanges(guid, styleIndex, colorIndex, blockRangeParagraphs, datedText: widget.publication.datedTextManager!.getCurrentDatedText());
                        },
                      );

                      // Quand on clique supprime le highlight
                      controller.addJavaScriptHandler(
                          handlerName: 'removeBlockRange',
                          callback: (args) async {
                            DatedText datedText = widget.publication.datedTextManager!.getCurrentDatedText();
                            String userMarkGuid = args[0]['UserMarkGuid'];
                            String? newUserMarkGuid = args[0]['NewUserMarkGuid'];
                            bool showAlertDialog = args[0]['ShowAlertDialog'];

                            _blockRangesController.removeBlockRange(userMarkGuid);

                            final note = _notesController.getNotesByDocument(datedText: datedText).firstWhereOrNull((n) => n.guid == userMarkGuid);

                            if(note != null) {
                              if(showAlertDialog) {
                                final String title = i18n().action_delete;
                                final String message = 'Voulez-vous supprimer la note "${note.title}" associé à votre surlignage ?';

                                // Affiche un dialog Flutter et retourne la réponse
                                final bool? confirmed = await showJwDialog(
                                    context: context,
                                    titleText: title,
                                    contentText: message,
                                    buttonAxisAlignment: MainAxisAlignment.end,
                                    buttons: [
                                      JwDialogButton(
                                          label: i18n().action_no,
                                          closeDialog: false,
                                          onPressed: (buildContext) async {
                                            Navigator.of(buildContext).pop(false);
                                          }
                                      ),
                                      JwDialogButton(
                                          label: i18n().action_yes,
                                          closeDialog: false,
                                          onPressed: (buildContext) async {
                                            Navigator.of(buildContext).pop(true);
                                          }
                                      ),
                                    ]
                                );

                                if(confirmed == true) {
                                  controller.evaluateJavascript(source: 'removeNote("${note.guid}", false)');
                                  _notesController.removeNote(note.guid);
                                }
                                else {
                                  controller.evaluateJavascript(source: 'removeNote("${note.guid}", false)');
                                }
                              }
                              else if (newUserMarkGuid != null) {
                                final blockRange = _blockRangesController.getBlockRangesByDocument(datedText: datedText).firstWhereOrNull((h) => h.userMarkGuid == userMarkGuid);
                                if(blockRange != null) {
                                  _notesController.changeNoteUserMark(note.guid, newUserMarkGuid, blockRange.styleIndex, blockRange.colorIndex);
                                }
                              }
                            }
                          }
                      );

                      // On change le color index d'un highlight
                      controller.addJavaScriptHandler(
                          handlerName: 'changeBlockRangeStyle',
                          callback: (args) {
                            String userMarkGuid = args[0]['UserMarkGuid'];
                            int styleIndex = args[0]['StyleIndex'];
                            int colorIndex = args[0]['ColorIndex'];

                            _blockRangesController.changeBlockRangeStyle(userMarkGuid, styleIndex, colorIndex);
                          }
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'getNoteByGuid',
                        callback: (args) {
                          String guid = args[0] as String;
                          Note? note = _notesController.getNoteByGuid(guid);

                          return {
                            'Title': note == null ? '' : note.title,
                            'Content': note == null ? '' : note.content,
                            'TagsId': note == null ? [] : note.tagsId.join(','),
                            'ColorIndex': note == null ? 0 : note.colorIndex,
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addNote',
                        callback: (args) async {
                          String guid = Uuid().v4();
                          String title = args[0]['Title'];
                          String? userMarkGuid = args[0]['UserMarkGuid'];
                          int blockType = args[0]['BlockType'];
                          int blockIdentifier = args[0]['BlockIdentifier'];
                          int colorIndex = args[0]['ColorIndex'];

                          await _notesController.addNote(
                              guid,
                              title,
                              userMarkGuid,
                              blockType,
                              blockIdentifier,
                              0,
                              colorIndex,
                              datedText: widget.publication.datedTextManager!.getCurrentDatedText()
                          );

                          return {
                            'uuid': guid
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'removeNote',
                        callback: (args) {
                          String guid = args[0]['Guid'];

                          _notesController.removeNote(guid);
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'updateNote',
                        callback: (args) {
                          String guid = args[0]['Guid'];
                          String title = args[0]['Title'];
                          String content = args[0]['Content'];

                          _notesController.updateNote(guid, title, content);
                        },
                      );

                      controller.addJavaScriptHandler(
                          handlerName: 'changeNoteColor',
                          callback: (args) {
                            String guid = args[0]['Guid'];
                            int styleIndex = args[0]['StyleIndex'];
                            int colorIndex = args[0]['ColorIndex'];

                            _notesController.changeNoteColor(guid, styleIndex, colorIndex);
                          }
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addTagIdToNote',
                        callback: (args) {
                          String guid = args[0]['Guid'];
                          int tagId = args[0]['TagId'];

                          _notesController.addTagIdToNote(guid, tagId);
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'removeTagIdFromNote',
                        callback: (args) {
                          String guid = args[0]['Guid'];
                          int tagId = args[0]['TagId'];

                          _notesController.removeTagIdFromNote(guid, tagId);
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'openTagPage',
                        callback: (args) {
                          int tagId = args[0]['TagId'];
                          Tag tag = _tagsController.tags.firstWhere((tag) => tag.id == tagId);
                          showPage(TagPage(tag: tag));
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addTag',
                        callback: (args) async {
                          String tagName = args[0]['Name'];
                          Tag tag = await _tagsController.addTag(tagName);
                          return {
                            'Tag': tag.toMap()
                          };
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'addTag',
                        callback: (args) async {
                          String tagName = args[0]['Name'];
                          Tag tag = await _tagsController.addTag(tagName);
                          return {
                            'Tag': tag.toMap()
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
                              int? mepsDocumentId = document['mepsDocumentId'] is int ? document['mepsDocumentId'] : int.tryParse(document['mepsDocumentId'].toString());
                              int? mepsLanguageId = document['mepsLanguageId'] is int ? document['mepsLanguageId'] : int.tryParse(document['mepsLanguageId'].toString());

                              int? startParagraphId = document['startParagraphId'] != null
                                  ? (document['startParagraphId'] is int ? document['startParagraphId'] : int.tryParse(document['startParagraphId'].toString()))
                                  : null;

                              int? endParagraphId = document['endParagraphId'] != null
                                  ? (document['endParagraphId'] is int ? document['endParagraphId'] : int.tryParse(document['endParagraphId'].toString()))
                                  : null;

                              // Appel de la vue de document avec les IDs convertis
                              await showDocumentView(
                                  context,
                                  mepsDocumentId!,
                                  mepsLanguageId!,
                                  startParagraphId: startParagraphId,
                                  endParagraphId: endParagraphId
                              );
                            }
                            else if ((document['firstBookNumber'] != null && document['firstChapterNumber'] != null) || (document['bookNumber'] != null && document['chapterNumber'] != null)) {
                              int bookNumber1 = document['firstBookNumber'] ?? document['bookNumber'];
                              int bookNumber2 = document['lastBookNumber'] ?? bookNumber1;
                              int chapterNumber1 = document['firstChapterNumber'] ?? document['chapterNumber'];
                              int chapterNumber2 = document['lastChapterNumber'] ?? chapterNumber1;

                              int? firstVerseNumber = document['firstVerseNumber'] ?? document['verseNumber'];
                              int? lastVerseNumber = document['lastVerseNumber'] ?? firstVerseNumber;


                              await showChapterView(
                                context,
                                document["keySymbol"],
                                document["mepsLanguageId"],
                                bookNumber1,
                                chapterNumber1,
                                lastBookNumber: bookNumber2,
                                lastChapterNumber: chapterNumber2,
                                firstVerseNumber: firstVerseNumber,
                                lastVerseNumber: lastVerseNumber,
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

                            Publication? publication = await CatalogDb.instance.searchPub(pub!, issueTagNumber, wtlocale!);
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
                    onLoadStop: (controller, url) {
                      _notesController.addListener(_updateNotesListener);
                      _tagsController.addListener(_updateTagsListener);
                    }
                  )
              ) : Container(),

              LoadingWidget(key: loadingKey),

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

class LoadingWidget extends StatefulWidget {
  const LoadingWidget({super.key});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget> {
  bool isLoadingFonts = true; // L'état qui change et déclenche setState

  void loadingFinish() {
    // Vérifiez que le widget est encore monté avant d'appeler setState
    if (mounted) {
      setState(() {
        isLoadingFonts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le loader doit être enveloppé dans un Positioned.fill pour le Stack
    if (!isLoadingFonts) {
      // 3. Ne rien afficher si le chargement est terminé
      return const SizedBox.shrink();
    }

    // Affiche la surcouche de chargement
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111111)
            : Colors.white,
        child: Center(
          // Assurez-vous que getLoadingWidget existe et est accessible
          child: getLoadingWidget(Theme.of(context).primaryColor),
        ),
      ),
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
                child: JwLifeAppBar(
                  title: widget.publication.datedTextManager!.getCurrentDatedText().getTitle(),
                  subTitle: widget.publication.shortTitle,
                  handleBackPress: widget.handleBackPress,
                  actions: [
                    IconTextButton(
                      text: i18n().action_languages,
                      icon: Icon(JwIcons.language),
                      onPressed: (anchorContext) async {
                        showLanguagePubDialog(context, widget.publication).then((languagePub) async {
                          if(languagePub != null) {
                            languagePub.showMenu(context);
                          }
                        });
                      },
                    ),
                    IconTextButton(
                      icon: Icon(JwIcons.calendar),
                      text: i18n().label_select_a_week,
                      onPressed: (anchorContext) async {
                        DateTime currentDate = widget.publication.datedTextManager!.getCurrentDatedText().getDate();

                        DateTime? selectedDay = await showMonthCalendarDialog(context, currentDate);

                        if (selectedDay != null) {
                          // Vérifie si on est dans la même année
                          bool sameYear = selectedDay.year == currentDate.year;

                          if (!sameYear) {
                            List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: selectedDay);

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
                      text: i18n().action_history,
                      icon: const Icon(JwIcons.arrow_circular_left_clock),
                      onPressed: (anchorContext) {
                        History.showHistoryDialog(context);
                      },
                    ),
                    IconTextButton(
                      text: i18n().action_open_in_share,
                      icon: Icon(JwIcons.share),
                      onPressed: (anchorContext) {
                        widget.publication.datedTextManager!.getCurrentDatedText().share();
                      },
                    ),
                    IconTextButton(
                      text: i18n().action_text_settings,
                      icon: const Icon(Icons.text_increase),
                      onPressed: (anchorContext) {
                        showFontSizeDialog(context, _controller);
                      },
                    ),
                    IconTextButton(
                      text: i18n().action_full_screen,
                      icon: Icon(JwIcons.square_stack),
                      isSwitch: JwLifeSettings.instance.webViewData.isFullScreenMode,
                      onSwitchChange: (value) async {
                        if(value != JwLifeSettings.instance.webViewData.isFullScreenMode) {
                          await AppSharedPreferences.instance.setFullscreenMode(value);
                          JwLifeSettings.instance.webViewData.updateFullscreen(value);
                          setState(() {

                          });
                        }
                      },
                    ),
                    IconTextButton(
                        text: i18n().action_reading_mode,
                        icon: Icon(JwIcons.scroll),
                        isSwitch: JwLifeSettings.instance.webViewData.isReadingMode,
                        onSwitchChange: (value) async {
                          if(value != JwLifeSettings.instance.webViewData.isReadingMode) {
                            await AppSharedPreferences.instance.setReadingMode(value);
                            setState(() {
                              JwLifeSettings.instance.webViewData.updateReadingMode(value);
                            });
                          }
                        }
                    ),
                    IconTextButton(
                        text: i18n().action_blocking_horizontally_mode,
                        icon: Icon(Icons.block),
                        isSwitch: JwLifeSettings.instance.webViewData.isBlockingHorizontallyMode,
                        onSwitchChange: (value) async {
                          if(value != JwLifeSettings.instance.webViewData.isBlockingHorizontallyMode) {
                            await AppSharedPreferences.instance.setBlockingHorizontallyMode(value);
                            setState(() {
                              JwLifeSettings.instance.webViewData.updatePreparingMode(value);
                            });
                          }
                        }
                    ),
                  ],
                )
            )
        ),
      ],
    );
  }
}
