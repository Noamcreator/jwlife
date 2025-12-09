import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/app_page.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_search.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/controller/block_ranges_controller.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_page.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/widgets/qr_code_dialog.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../../../../core/utils/widgets_utils.dart';
import '../../../../../../../data/models/userdata/bookmark.dart';
import '../../../../../app/services/global_key_service.dart';
import '../../../../../app/services/settings_service.dart';
import '../../../../../core/uri/jworg_uri.dart';
import '../../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../../core/utils/utils_language_dialog.dart';
import '../../../../../core/webview/html_template_service.dart';
import '../../../../../core/webview/webview_javascript.dart';
import '../../../../../core/webview/webview_utils.dart';
import '../../../../../data/controller/notes_controller.dart';
import '../../../../../data/models/meps_language.dart';
import '../../../../../data/models/userdata/note.dart';
import '../../../../../data/models/userdata/tag.dart';
import '../../../../../data/models/video.dart';
import '../../../../../i18n/i18n.dart';
import '../../../../../widgets/searchfield/searchfield_widget.dart';
import '../../../../personal/pages/tag_page.dart';
import '../../../models/menu/local/words_suggestions_model.dart';
import '../data/models/multimedia.dart';
import 'document_medias_page.dart';
import '../data/models/document.dart';

import 'documents_manager.dart';
import 'full_screen_image_page.dart';

class DocumentPage extends StatefulWidget {
  final Publication publication;
  final int mepsDocumentId;
  final int? startBlockIdentifierId;
  final int? endBlockIdentifierId;
  final String? textTag;
  final int? bookNumber;
  final int? chapterNumber;
  final int? lastBookNumber;
  final int? lastChapterNumber;
  final int? firstVerseNumber;
  final int? lastVerseNumber;
  final List<String> wordsSelected;

  const DocumentPage({
    super.key,
    required this.publication,
    required this.mepsDocumentId,
    this.startBlockIdentifierId,
    this.endBlockIdentifierId,
    this.textTag,
    this.bookNumber,
    this.chapterNumber,
    this.lastBookNumber,
    this.lastChapterNumber,
    this.firstVerseNumber,
    this.lastVerseNumber,
    this.wordsSelected = const [],
  });

  // Constructeur nommé pour une Bible
  const DocumentPage.bible({
    Key? key,
    required Publication bible,
    required int bookNumber,
    required int chapterNumber,
    int? lastBookNumber,
    int? lastChapterNumber,
    int? firstVerseNumber,
    int? lastVerseNumber,
    List<String> wordsSelected = const [],
  }) : this(
    key: key,
    publication: bible,
    mepsDocumentId: 0,
    bookNumber: bookNumber,
    chapterNumber: chapterNumber,
    lastBookNumber: lastBookNumber,
    lastChapterNumber: lastChapterNumber,
    firstVerseNumber: firstVerseNumber,
    lastVerseNumber: lastVerseNumber,
    wordsSelected: wordsSelected,
  );

  @override
  DocumentPageState createState() => DocumentPageState();
}

class DocumentPageState extends State<DocumentPage> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late InAppWebViewController _controller;

  final GlobalKey<_LoadingWidgetState> loadingKey = GlobalKey<_LoadingWidgetState>();
  final GlobalKey<_ControlsOverlayState> controlsKey = GlobalKey<_ControlsOverlayState>();

  /* LOADING */
  bool _isLoadedData = false;

  /* OTHER VIEW */
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  int? lastDocumentId;
  int? lastBookId;
  int? lastChapterId;
  int lastBlockId = 0;

  bool insertBlockIdentifier = false;

  late StreamSubscription<SequenceState?> _streamSequenceStateSubscription;
  late StreamSubscription<Duration?> _streamSequencePositionSubscription;

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
    _streamSequenceStateSubscription.cancel();
    _streamSequencePositionSubscription.cancel();
    //_notesController.removeListener(_updateNotesListener);
    _tagsController.removeListener(_updateTagsListener);
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (kDebugMode) {
      HtmlTemplateService().reload().then((_) {
        setState(() {});
      });
    }
  }

  Future<void> init() async {
    if(widget.publication.documentsManager != null) {
      if(widget.bookNumber != null && widget.chapterNumber != null) {
        widget.publication.documentsManager!.bookNumber = widget.bookNumber!;
        widget.publication.documentsManager!.chapterNumber = widget.chapterNumber!;
        widget.publication.documentsManager!.selectedDocumentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.bookNumber == widget.bookNumber && element.chapterNumberBible == widget.chapterNumber);
      }
      else {
        widget.publication.documentsManager!.selectedDocumentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.mepsDocumentId == widget.mepsDocumentId);
      }
    }
    else {
      widget.publication.documentsManager = DocumentsManager(publication: widget.publication, mepsDocumentId: widget.mepsDocumentId, bookNumber: widget.bookNumber, chapterNumber: widget.chapterNumber);
      await widget.publication.documentsManager!.initializeDatabaseAndData();

      widget.publication.wordsSuggestionsModel = WordsSuggestionsModel(widget.publication);
    }

    setState(() {
      _isLoadedData = true;
    });

    if (widget.publication.audiosNotifier.value.isEmpty) {
      widget.publication.fetchAudios().then((value) {
        controlsKey.currentState?.refreshWidget();

        Document? doc;
        if(widget.bookNumber != null && widget.chapterNumber != null) {
          doc = widget.publication.documentsManager!.documents.firstWhereOrNull((document) => document.bookNumber == widget.bookNumber && document.chapterNumberBible == widget.chapterNumber);
        }
        else {
          doc = widget.publication.documentsManager!.documents.firstWhereOrNull((document) => document.mepsDocumentId == widget.mepsDocumentId);
        }

        if(doc != null) {
          List<Map<String, dynamic>> audioMarkersJson = [];

          if(doc.isBibleChapter()) {
            if (widget.publication.audiosNotifier.value.isNotEmpty) {
              final audio = widget.publication.audiosNotifier.value.firstWhereOrNull((a) => a.bookNumber == doc!.bookNumber && a.track == doc!.chapterNumberBible);
              if (audio != null && audio.markers.isNotEmpty) {
                audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
              }
            }
          }
          else {
            if (widget.publication.audiosNotifier.value.isNotEmpty) {
              final audio = widget.publication.audiosNotifier.value.firstWhereOrNull((a) => a.documentId == doc!.mepsDocumentId);
              if (audio != null && audio.markers.isNotEmpty) {
                audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
              }
            }
          }

          if(!_isLoadedData) {
            _controller.evaluateJavascript(source: "updateAudios($audioMarkersJson, ${widget.publication.documentsManager!.getIndexFromMepsDocumentId(widget.mepsDocumentId)});");
          }
        }
      });
    }

    _streamSequenceStateSubscription = JwLifeApp.audioPlayer.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      if (JwLifeApp.audioPlayer.isSettingPlaylist && state.currentIndex == 0) return;
      if(loadingKey.currentState!.isLoadingPage) return;
      if(!_isLoadedData) return;

      final currentSource = state.currentSource;
      if (currentSource is! ProgressiveAudioSource) {
        if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
          if (lastBookId != -1 && lastChapterId != -1) {
            _jumpToVerse(-1, -1);
            lastBookId = -1;
            lastChapterId = -1;
          }
        }
        else {
          if (lastBlockId != -1) {
            _jumpToParagraph(-1, -1);
            lastBlockId = -1;
          }
        }
        return;
      }

      ProgressiveAudioSource source = currentSource;
      var tag = source.tag as audio_service.MediaItem?;

      if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
        lastBookId = tag?.extras?['bookNumber'];
        lastChapterId = tag?.extras?['track'];

        if(widget.publication.documentsManager!.documents.any((document) => document.bookNumber == lastBookId && document.chapterNumberBible == lastChapterId)) {
          int? currentIndex = state.currentIndex;

          if(currentIndex == null || currentIndex == -1) {
            _jumpToVerse(-1, -1);
          }
          else {
            Audio audio = widget.publication.audiosNotifier.value[currentIndex];
            if(audio.bookNumber != widget.publication.documentsManager!.getCurrentDocument().bookNumber || audio.track != widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible) {
              _jumpToPage(widget.publication.documentsManager!.documents.indexWhere((document) => document.bookNumber == audio.bookNumber && document.chapterNumberBible == audio.track));
            }
          }
        }
        else if (lastBlockId != -1) {
          _jumpToVerse(-1, -1);
          lastBlockId = -1;
        }
      }
      else {
        lastDocumentId = tag?.extras?['documentId'];

        if(widget.publication.documentsManager!.documents.any((document) => document.mepsDocumentId == lastDocumentId)) {
          int? currentIndex = state.currentIndex;

          if(currentIndex == null || currentIndex == -1) {
            _jumpToParagraph(-1, -1);
          }
          else {
            Audio audio = widget.publication.audiosNotifier.value[currentIndex];
            if(audio.documentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
              _jumpToPage(widget.publication.documentsManager!.documents.indexWhere((document) => document.mepsDocumentId == audio.documentId));
            }
          }
        }
        else if (lastBlockId != -1) {
          _jumpToParagraph(-1, -1);
          lastBlockId = -1;
        }
      }
    });

    _streamSequencePositionSubscription = JwLifeApp.audioPlayer.player.positionStream.listen((position) {
      if (!mounted) return;
      if(loadingKey.currentState!.isLoadingPage) return;

      if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
        if(lastBookId != null && lastChapterId != null && lastBookId == widget.publication.documentsManager!.getCurrentDocument().bookNumber && lastChapterId == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible) {
          Audio? audio = widget.publication.audiosNotifier.value.firstWhereOrNull((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
          if(audio != null) {
            Marker? marker = audio.markers.firstWhereOrNull((m) {
              final start = parseDuration(m.startTime).inSeconds;
              final end = start + parseDuration(m.duration).inSeconds;
              return position.inSeconds >= start && position.inSeconds <= end;
            });

            if (marker != null && marker.verseNumber != null) {
              if (marker.verseNumber != lastBlockId) {
                _jumpToVerse(marker.verseNumber!, marker.verseNumber!);
                lastBlockId = marker.verseNumber!;
              }
            }
          }
        }
      }
      else {
        if(lastDocumentId != null && lastDocumentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
          Audio? audio = widget.publication.audiosNotifier.value.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
          if(audio != null) {
            Marker? marker = audio.markers.firstWhereOrNull((m) {
              final start = parseDuration(m.startTime).inSeconds;
              final end = start + parseDuration(m.duration).inSeconds;
              return position.inSeconds >= start && position.inSeconds <= end;
            });

            if (marker != null && marker.mepsParagraphId != null) {
              if (marker.mepsParagraphId != lastBlockId) {
                _jumpToParagraph(marker.mepsParagraphId!, marker.mepsParagraphId!);
                lastBlockId = marker.mepsParagraphId!;
              }
            }
          }
        }
      }
    });
  }

  String? _lastSentNotes;

  // Dans init ou onLoadStop, tu crées des fonctions pour pouvoir les retirer :
  void _updateNotesListener() {
    if (!mounted) return;
    final notes = _notesController.getNotesByDocument(document: widget.publication.documentsManager!.getCurrentDocument()).map((note) => note.toMap()).toList();
    final jsonNotes = jsonEncode(notes);
    if (jsonNotes == _lastSentNotes) return;
    _lastSentNotes = jsonNotes;

    _controller.callAsyncJavaScript(functionBody: "updateAllNotesUI($jsonNotes);"
    );
  }

  void _updateTagsListener() {
    if (!mounted) return;
    final tags = _tagsController.tags.map((t) => t.toMap()).toList();
    final jsonTags = jsonEncode(tags);_controller.callAsyncJavaScript(functionBody: "updateTags($jsonTags);"
    );
  }

  Future<void> changePageAt(int index) async {
    if (index <= widget.publication.documentsManager!.documents.length - 1 && index >= 0) {
      controlsKey.currentState?.changePageAt(index, false);

      int? startBlockIdentifier;
      int? endBlockIdentifier;
      String? textTag;
      if(!insertBlockIdentifier) {
        if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
          startBlockIdentifier = widget.firstVerseNumber;
          endBlockIdentifier = widget.lastVerseNumber;
        }
        else {
          startBlockIdentifier = widget.startBlockIdentifierId;
          endBlockIdentifier = widget.endBlockIdentifierId;
          textTag = widget.textTag;
        }
        insertBlockIdentifier = true;
      }

      Document currentDocument = widget.publication.documentsManager!.getCurrentDocument();
      await currentDocument.changePageAt(startBlockIdentifier, endBlockIdentifier);
      bool imageMode = currentDocument.preferredPresentation == null && currentDocument.svgs.isNotEmpty ? true : false;
      controlsKey.currentState?.changePageAt(index, imageMode);
    }
  }

  Future<void> _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('[data-pid]', 'data-pid', $beginParagraphOrdinal, $endParagraphOrdinal);");
  }

  Future<void> _jumpToVerse(int startVerseNumber, int? lastVerseNumber) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('.v', 'id', $startVerseNumber, $lastVerseNumber);");
  }

  Future<void> _jumpToPage(int page) async {
    if (page != widget.publication.documentsManager!.selectedDocumentIndex) {
      _pageHistory.add(widget.publication.documentsManager!.selectedDocumentIndex); // Ajouter la page actuelle à l'historique
      _currentPageHistory = page;

      widget.publication.documentsManager!.selectedDocumentIndex = page;
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
            widget.publication.documentsManager!.selectedDocumentIndex,
            widget.publication.documentsManager!.documents.length - 1
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
    if(controlsKey.currentState!.isSearching()) {
      return false;
    }
    else if(_showDialog) {
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

  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last.toLowerCase().trim();

    Multimedia? multimedia = widget.publication.documentsManager!.getCurrentDocument().multimedias.firstWhereOrNull((img) => img.filePath.toLowerCase().trim().contains(newPath));

    if(multimedia == null) return;
    if (!multimedia.hasSuppressZoom) {
      showPage(FullScreenImagePage(
          publication: widget.publication,
          multimedias: widget.publication.documentsManager!.getCurrentDocument().multimedias,
          multimedia: multimedia
      ));
    }
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

  Future<void> changePronunciationGuideMode(bool isPronunciationGuideActive) async {
    await _controller.evaluateJavascript(source: "switchPronunciationGuideMode($isPronunciationGuideActive);");
  }

  Future<void> changePrimaryColor(Color lightColor, Color darkColor) async {
    final lightPrimaryColor = toHex(lightColor);
    final darkPrimaryColor = toHex(darkColor);

    await _controller.evaluateJavascript(source: "changePrimaryColor('$lightPrimaryColor', '$darkPrimaryColor');");
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
        _isLoadedData ? SafeArea(
            child: InAppWebView(
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
                ),
                initialData: InAppWebViewInitialData(
                    data: createReaderHtmlShell(
                        widget.publication,
                        widget.publication.documentsManager!.selectedDocumentIndex,
                        widget.publication.documentsManager!.documents.length - 1,
                        bookNumber: widget.bookNumber,
                        chapterNumber: widget.chapterNumber,
                        lastBookNumber: widget.lastBookNumber ?? widget.bookNumber,
                        lastChapterNumber: widget.lastChapterNumber ?? widget.chapterNumber,
                        startParagraphId: widget.startBlockIdentifierId,
                        endParagraphId: widget.endBlockIdentifierId,
                        startVerseId: widget.firstVerseNumber,
                        endVerseId: widget.lastVerseNumber,
                        textTag: widget.textTag,
                        wordsSelected: widget.wordsSelected
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
                        'isPreparingMode': webViewData.isBlockingHorizontallyMode,
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
                      if (index < 0 || index >= widget.publication.documentsManager!.documents.length) {
                        return {'title': '', 'html': '', 'className': '', 'audiosMarkers': '', 'isBibleChapter': false, 'link': '', 'svgs': '', 'preferredPresentation': 'text'};
                      }

                      final doc = widget.publication.documentsManager!.documents[index];

                      String html = '';
                      List<Map<String, dynamic>> audioMarkersJson = [];

                      if(doc.isBibleChapter()) {
                        List<Uint8List> contentBlob = doc.getChapterContent();

                        for(dynamic content in contentBlob) {
                          html += decodeBlobContent(
                            content,
                            widget.publication.hash!,
                          );
                        }

                        if (widget.publication.audiosNotifier.value.isNotEmpty) {
                          final audio = widget.publication.audiosNotifier.value.firstWhereOrNull((a) => a.bookNumber == doc.bookNumber && a.track == doc.chapterNumberBible);
                          if (audio != null && audio.markers.isNotEmpty) {
                            audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                          }
                        }
                      }
                      else {
                        html = decodeBlobContent(doc.content!, widget.publication.hash!);

                        if (widget.publication.audiosNotifier.value.isNotEmpty) {
                          final audio = widget.publication.audiosNotifier.value.firstWhereOrNull((a) => a.documentId == doc.mepsDocumentId);
                          if (audio != null && audio.markers.isNotEmpty) {
                            audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                          }
                        }
                      }
                      final className = getArticleClass(widget.publication, doc);

                      await doc.fetchSvgs();

                      String svg = '';
                      if (doc.svgs.isNotEmpty) {
                        svg = '${widget.publication.path}/${doc.svgs.first['FilePath']}';

                      }

                      if(loadingKey.currentState!.isLoadingPage) {
                        loadingKey.currentState!.loadingFinish();
                      }

                      return {
                        'title': doc.getDisplayTitle(),
                        'html': html,
                        'className': className,
                        'audiosMarkers': audioMarkersJson,
                        'isBibleChapter': doc.isBibleChapter(),
                        'link': '',
                        'svgs': svg,
                        'preferredPresentation': doc.preferredPresentation == null && svg.isNotEmpty ? 'image' : 'text'
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
                      List<int> tagsId = dynamicTags.where((e) => e is int).cast<int>().toList(); // Reste du code inchangé
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
                      Document document = widget.publication.documentsManager!.getCurrentDocument();
                      return {
                        'blockRanges': _blockRangesController.getBlockRangesByDocument(document: document).map((blockRange) => blockRange.toMap()).toList(),
                        'notes': _notesController.getNotesByDocument(document: document).map((note) => note.toMap()).toList(),
                        'tags': _tagsController.tags.map((tag) => tag.toMap()).toList(),
                        'inputFields': document.inputFields,
                        'bookmarks': document.bookmarks,
                      };
                    },
                  );

                  // On ajoute les blockRanges
                  controller.addJavaScriptHandler(
                    handlerName: 'addBlockRanges',
                    callback: (args) {
                      String guid = args[0];
                      int styleIndex = args[1];
                      int colorIndex = args[2];
                      List<dynamic> blockRangeParagraphs = args[3];

                      _blockRangesController.addBlockRanges(guid, styleIndex, colorIndex, blockRangeParagraphs, document: widget.publication.documentsManager!.getCurrentDocument());
                    },
                  );

                  // On enlève un blockRange
                  controller.addJavaScriptHandler(
                      handlerName: 'removeBlockRange',
                      callback: (args) async {
                        Document document = widget.publication.documentsManager!.getCurrentDocument();
                        String userMarkGuid = args[0]['UserMarkGuid'];
                        String? newUserMarkGuid = args[0]['NewUserMarkGuid'];
                        bool showAlertDialog = args[0]['ShowAlertDialog'];

                        _blockRangesController.removeBlockRange(userMarkGuid);

                        final note = _notesController.getNotesByDocument(document: document).firstWhereOrNull((n) => n.guid == userMarkGuid);

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
                              controller.evaluateJavascript(source: 'repositionNote("${note.guid}")');
                            }
                          }
                          else if (newUserMarkGuid != null) {
                            final blockRange = _blockRangesController.getBlockRangesByDocument(document: document).firstWhereOrNull((h) => h.userMarkGuid == userMarkGuid);
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

                      await _notesController.addNoteWithGuid(
                          guid,
                          title,
                          userMarkGuid,
                          blockType,
                          blockIdentifier,
                          0,
                          colorIndex,
                          document: widget.publication.documentsManager!.getCurrentDocument()
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

                  // Gestionnaire pour les clics sur les images
                  controller.addJavaScriptHandler(
                    handlerName: 'onImageClick',
                    callback: (args) {
                      _openFullScreenImageView(args[0]); // Gérer l'affichage de l'image
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'fetchVerses',
                    callback: (args) async {
                      Map<String, dynamic>? verses = await fetchVerses(args[0]);
                      return verses;
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'fetchGuideVerse',
                    callback: (args) async {
                      Map<String, dynamic>? extractPublication = await fetchGuideVerse(context, args[0]);
                      if (extractPublication != null) {
                        return extractPublication;
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'fetchExtractPublication',
                    callback: (args) async {
                      Map<String, dynamic>? extractPublication = await fetchExtractPublication(context, 'document', widget.publication.documentsManager!.database, widget.publication, args[0], _jumpToPage, _jumpToParagraph);
                      if (extractPublication != null) {
                        return extractPublication;
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'fetchCommentaries',
                    callback: (args) async {
                      Map<String, dynamic> versesCommentaries = await fetchCommentaries(context, widget.publication, args[0]);
                      return versesCommentaries;
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'fetchFootnote',
                    callback: (args) async {
                      Map<String, dynamic> footnote = await fetchFootnote(context, widget.publication, args[0]);
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
                    handlerName: 'fetchVerseInfo',
                    callback: (args) async {
                      Document document = widget.publication.documentsManager!.getCurrentDocument();
                      int book = document.bookNumber!;
                      int chapter = document.chapterNumber!;
                      int verse = args[0]['id'];
                      int? verseId = await JwLifeApp.bibleCluesInfo.getBibleVerseId(book, chapter, verse);

                      Future<List<Map<String, dynamic>>> verseCommentaries = fetchVerseCommentaries(context, widget.publication, verseId!, false);
                      Future<List<Map<String, dynamic>>> verseMedias = fetchVerseMedias(context, widget.publication, verseId);
                      Future<List<Map<String, dynamic>>> verseVersions = fetchOtherVerseVersion(context, widget.publication, book, chapter, verse, verseId);
                      Future<List<Map<String, dynamic>>> verseResearchGuide = fetchVerseResearchGuide(context, verseId, false);
                      Future<List<Map<String, dynamic>>> verseFootnotes = fetchVerseFootnotes(context, widget.publication, verseId);

                      final verseInfo = {
                        'title': JwLifeApp.bibleCluesInfo.getVerse(widget.publication.documentsManager!.getCurrentDocument().bookNumber!, widget.publication.documentsManager!.getCurrentDocument().chapterNumber!, verse),
                        'commentary': await verseCommentaries,
                        'medias': await verseMedias,
                        'versions': await verseVersions,
                        'guide': await verseResearchGuide,
                        'footnotes': await verseFootnotes,
                      };

                      return verseInfo;
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'openMepsDocument',
                    callback: (args) async {
                      Map<String, dynamic>? document = args[0];
                      if (document != null) {
                        if (document['mepsDocumentId'] != null) {
                          // Conversion de mepsDocumentId et mepsLanguageId
                          int? mepsDocumentId = document['mepsDocumentId'] is int ? document['mepsDocumentId'] : int.tryParse(document['mepsDocumentId'].toString());
                          int? mepsLanguageId = document['mepsLanguageId'] is int ? document['mepsLanguageId'] : int.tryParse(document['mepsLanguageId'].toString());

                          // Correction : Conversion de startParagraphId et endParagraphId
                          // J'utilise .toString() pour garantir que même si ce n'est pas un String initialement (mais non-int), on essaie de le parser.
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
                              startParagraphId: startParagraphId, // Passé comme int?
                              endParagraphId: endParagraphId       // Passé comme int?
                          );
                        }
                        else if ((document['firstBookNumber'] != null && document['firstChapterNumber'] != null) || (document['bookNumber'] != null && document['chapterNumber'] != null)) {
                          int bookNumber1 = document['firstBookNumber'] ?? document['bookNumber'];
                          int bookNumber2 = document['lastBookNumber'] ?? bookNumber1;
                          int chapterNumber1 = document['firstChapterNumber'] ?? document['chapterNumber'];
                          int chapterNumber2 = document['lastChapterNumber'] ?? chapterNumber1;

                          int? firstVerseNumber = document['firstVerseNumber'] ?? document['verseNumber'];
                          int? lastVerseNumber = document['lastVerseNumber'] ?? firstVerseNumber;

                          if(widget.publication.documentsManager!.documents.any((doc) => doc.bookNumber == bookNumber1 && doc.chapterNumber == chapterNumber1)) {
                            if (bookNumber1 != widget.publication.documentsManager!.getCurrentDocument().bookNumber || chapterNumber1 != widget.publication.documentsManager!.getCurrentDocument().chapterNumber) {
                              int index = widget.publication.documentsManager!.getIndexFromBookNumberAndChapterNumber(bookNumber1, chapterNumber1);
                              await _jumpToPage(index);
                            }

                            await Future.delayed(Duration(milliseconds: 100));

                            // Appeler _jumpToParagraph uniquement si un paragraphe est présent
                            if (firstVerseNumber != null) {
                              bool hasSameChapter = bookNumber1 == bookNumber2 && chapterNumber1 == chapterNumber2;
                              int? lastVerseNumber = hasSameChapter ? firstVerseNumber : null;
                              await _jumpToVerse(firstVerseNumber, lastVerseNumber);
                            }
                          }
                          else {
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
                      }
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onInputChange',
                    callback: (args) {
                      String tag = args[0]['tag'];
                      String value = args[0]['value'];
                      widget.publication.documentsManager!.getCurrentDocument().updateOrInsertInputFieldValue(tag, value);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'bookmark',
                    callback: (args) async {
                      final arg = args[0];

                      final bool isBible = arg['isBible'];
                      final int? id = arg['id'];
                      final String snippet = arg['snippet'];

                      final docManager = widget.publication.documentsManager!;
                      final currentDoc = docManager.getCurrentDocument();

                      if (isBible) {
                        // Cas d’un verset
                        int? blockIdentifier = id;
                        int blockType = blockIdentifier != null ? 2 : 0;

                        printTime('blockIdentifier: $blockIdentifier');
                        printTime('blockType: $blockType');
                        printTime('bookNumber: ${currentDoc.bookNumber}');
                        printTime('chapterNumber: ${currentDoc.chapterNumber}');

                        Bookmark? bookmark = await showBookmarkDialog(
                          context,
                          widget.publication,
                          webViewController: _controller,
                          bookNumber: currentDoc.bookNumber,
                          chapterNumber: currentDoc.chapterNumber,
                          title: '${currentDoc.displayTitle} ${currentDoc.chapterNumber}:$blockIdentifier',
                          snippet: snippet.trim(),
                          blockType: blockType,
                          blockIdentifier: blockIdentifier,
                        );

                        if(bookmark != null) {
                          if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                            final page = docManager.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumberBible == bookmark.location.chapterNumber);

                            if (page != widget.publication.documentsManager!.selectedDocumentIndex) {
                              await _jumpToPage(page);
                            }

                            if(bookmark.blockIdentifier != null) {
                              _jumpToVerse(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                            }
                          }
                        }
                      }
                      else {
                        // Cas d’un paragraphe classique
                        int? blockIdentifier = id;
                        int blockType = blockIdentifier != null ? 1 : 0;

                        printTime('blockIdentifier: $blockIdentifier');
                        printTime('blockType: $blockType');
                        printTime('mepsDocumentId: ${currentDoc.mepsDocumentId}');
                        printTime('title: ${currentDoc.displayTitle}');

                        Bookmark? bookmark = await showBookmarkDialog(
                          context,
                          widget.publication,
                          webViewController: _controller,
                          mepsDocumentId: currentDoc.mepsDocumentId,
                          title: currentDoc.displayTitle,
                          snippet: snippet.trim(),
                          blockType: blockType,
                          blockIdentifier: blockIdentifier,
                        );

                        if(bookmark != null) {
                          if (bookmark.location.mepsDocumentId != null) {
                            final page = docManager.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);
                            if (page != widget.publication.documentsManager!.selectedDocumentIndex) {
                              await _jumpToPage(page);
                            }
                          }

                          // Aller au paragraphe dans la même page
                          if (bookmark.blockIdentifier != null) {
                            _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                          }
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

                      widget.publication.documentsManager!.getCurrentDocument().share(id: id);
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'qrCode',
                    callback: (args) async {
                      final arg = args[0];
                      final int id = arg['id'];

                      String uri = widget.publication.documentsManager!.getCurrentDocument().share(id: id, hide: true);
                      showQrCodeDialog(context, widget.publication.documentsManager!.getCurrentDocument().getDisplayTitle(), uri);
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'copyText',
                    callback: (args) async {
                      Clipboard.setData(ClipboardData(text: args[0]['text']));
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'playAudio',
                    callback: (args) async {
                      final arg = args[0];

                      final bool isBible = arg['isBible'];
                      final int id = arg['id'];

                      try {
                        // Trouver l'audio correspondant au document dans une liste
                        Audio? audio;

                        if(isBible) {
                          audio = widget.publication.audiosNotifier.value.firstWhereOrNull((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                        }
                        else {
                          audio = widget.publication.audiosNotifier.value.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                        }

                        if(audio != null) {
                          // Trouver le marqueur correspondant au paragraphId dans la liste des marqueurs
                          Marker? marker;
                          if(isBible) {
                            marker = audio.markers.firstWhereOrNull((marker) => marker.verseNumber == id);
                          }
                          else {
                            marker = audio.markers.firstWhereOrNull((marker) => marker.mepsParagraphId == id);
                          }

                          if(marker != null) {
                            // Extraire le startTime du marqueur et vérifier s'il est valide
                            String startTime = marker.startTime;
                            if (startTime.isEmpty) {
                              printTime('Le startTime est invalide');
                              return;
                            }

                            // Analyser la durée
                            Duration duration = parseDuration(startTime);

                            printTime('duration: $duration');

                            // Trouver l'index du document
                            int? index;
                            if(isBible) {
                              index = widget.publication.audiosNotifier.value.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                            }
                            else {
                              index = widget.publication.audiosNotifier.value.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                            }

                            if (index != -1) {
                              // Afficher le lien du lecteur audio et se positionner au bon startTime
                              showAudioPlayerPublicationLink(context, widget.publication, index, start: duration);
                            }
                          }
                        }
                      }
                      catch (e) {
                        printTime('Erreur lors de la lecture de l\'audio : $e');
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'playVerseAudio',
                    callback: (args) async {
                      dynamic audio = args[0]['audio'];
                      dynamic verse = args[0]['verse'];

                      int verseNumber = verse['verseNumber'];
                      String url = audio['url'];
                      Duration startDuration = Duration.zero;
                      Duration? endDuration;

                      dynamic markers = audio['markers'];

                      if (markers != null) {
                        for (int i = 0; i < markers.length; i++) {
                          if (markers[i]['verseNumber'] == verseNumber) {
                            startDuration = parseDuration(markers[i]['startTime']);
                            Duration duration = parseDuration(markers[i]['duration']);
                            endDuration = startDuration + duration;
                            break;
                          }
                        }
                      }

                      Publication bible = PublicationRepository().getOrderBibles().first;

                      audio_service.MediaItem mediaItem = audio_service.MediaItem(
                          id: '0',
                          album: bible.title,
                          title: JwLifeApp.bibleCluesInfo.getVerse(verse['bookNumber'], verse['chapterNumber'], verseNumber),
                          artUri: Uri.file(bible.imageSqr!)
                      );

                      showAudioPlayerForLink(context, url, mediaItem, initialPosition: startDuration, endPosition: endDuration);
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
                    handlerName: 'searchVerse',
                    callback: (args) async {
                      String book = widget.publication.documentsManager!.getCurrentDocument().bookNumber.toString();
                      String chapter = widget.publication.documentsManager!.getCurrentDocument().chapterNumber.toString();
                      String verseNumber = args[0]['query'].toString();

                      String query = JwLifeApp.bibleCluesInfo.getVerse(int.parse(book), int.parse(chapter), int.parse(verseNumber));
                      showPage(SearchPage(query: query));
                    },
                  );

                  // Gestionnaire pour les modifications des champs de formulaire
                  controller.addJavaScriptHandler(
                    handlerName: 'onVideoClick',
                    callback: (args) async {
                      String link = args[0];

                      print(link);

                      // Extraire les paramètres
                      Uri uri = Uri.parse(link);
                      String? pub = uri.queryParameters['pub']?.toLowerCase();
                      int? issue = uri.queryParameters['issue'] != null ? int.parse(uri.queryParameters['issue']!) : null;
                      int? docId = uri.queryParameters['docid'] != null ? int.parse(uri.queryParameters['docid']!) : null;
                      int? track = uri.queryParameters['track'] != null ? int.parse(uri.queryParameters['track']!) : null;
                      String? langwritten = uri.queryParameters['langwritten'] ?? JwLifeSettings.instance.currentLanguage.value.symbol;
                      int? langId = uri.queryParameters['langId'] != null ? int.parse(uri.queryParameters['langId']!) : null;

                      if(langId != null) {
                        langwritten = await MepsLanguage.fromId(langId);
                      }

                      RealmMediaItem? mediaItem = getMediaItem(pub, track, docId, issue, langwritten);

                      if(mediaItem != null) {
                        Video video = Video.fromJson(mediaItem: mediaItem);
                        video.showPlayer(context);
                      }
                      else {
                        Video video = Video(
                          keySymbol: pub,
                          issueTagNumber: issue,
                          mepsLanguage: langwritten,
                          track: track,
                          documentId: docId,
                        );

                        video.showPlayer(context);

                        // dialog pour importer le média

                        //showImportPublication(context, keySymbol, issueTagNumber, mepsLanguageId)
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

                  controller.addJavaScriptHandler(
                    handlerName: 'imageLongPressHandler',
                    callback: (args) async {
                      if (args.length >= 3 && args[0] is String && args[1] is num && args[2] is num) {
                        final String imageUrl = args[0] as String;
                        // Les coordonnées sont des doubles (num)
                        final double clientX = (args[1] as num).toDouble();
                        final double clientY = (args[2] as num).toDouble();

                        final filePath = imageUrl.replaceFirst('jwpub-media://', '');
                        File? imageFile = await widget.publication.documentsManager!.getCurrentDocument().getImagePathFromDatabase(filePath, returnFile: true);

                        if(imageFile != null) {
                          showFloatingMenuAtPosition(context, imageFile.path, clientX, clientY);
                        }
                      }
                    },
                  );
                },
                shouldInterceptRequest: (controller, request) async {
                  String requestedUrl = '${request.url}';

                  if (requestedUrl.startsWith('jwpub-media://')) {
                    printTime('Requested URL: $requestedUrl');
                    final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                    return await widget.publication.documentsManager!.getCurrentDocument().getImagePathFromDatabase(filePath);
                  }
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
                    JwOrgUri jwOrgUri = JwOrgUri.parse(uri.toString());
                    printTime('Requested URL: $url');

                    if(jwOrgUri.isPublication) {
                      Publication? publication = await CatalogDb.instance.searchPub(jwOrgUri.pub!, jwOrgUri.issue!, jwOrgUri.wtlocale);
                      if (publication != null) {
                        publication.showMenu(context);
                      }
                    }
                    else if (jwOrgUri.isMediaItem) {
                      Duration startTime = Duration.zero;
                      Duration? endTime;

                      if (jwOrgUri.ts != null && jwOrgUri.ts!.isNotEmpty) {
                        final parts = jwOrgUri.ts!.split('-');
                        if (parts.isNotEmpty) {
                          startTime = JwOrgUri.parseDuration(parts[0]) ?? Duration.zero;
                        }
                        if (parts.length > 1) {
                          endTime = JwOrgUri.parseDuration(parts[1]);
                        }
                      }

                      RealmMediaItem? mediaItem = getMediaItemFromLank(jwOrgUri.lank!, jwOrgUri.wtlocale);

                      if (mediaItem == null) return NavigationActionPolicy.ALLOW;

                      if(mediaItem.type == 'AUDIO') {
                        Audio audio = Audio.fromJson(mediaItem: mediaItem);
                        audio.showPlayer(context, initialPosition: startTime);
                      }
                      else {
                        Video video = Video.fromJson(mediaItem: mediaItem);
                        video.showPlayer(context, initialPosition: startTime);
                      }
                    }
                    else {
                      _pageHistory.add(widget.publication.documentsManager!.selectedDocumentIndex); // Ajouter la page actuelle à l'historique
                      _currentPageHistory = -1;

                      controlsKey.currentState?.toggleControls(true);

                      return NavigationActionPolicy.ALLOW;
                    }

                    // Annule la navigation pour gérer le lien manuellement
                    return NavigationActionPolicy.CANCEL;
                  }

                  _pageHistory.add(widget.publication.documentsManager!.selectedDocumentIndex); // Ajouter la page actuelle à l'historique
                  _currentPageHistory = -1;

                  controlsKey.currentState?.toggleControls(true);
                  // Permet la navigation pour tous les autres liens
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) {
                  //_notesController.addListener(_updateNotesListener);
                  _tagsController.addListener(_updateTagsListener);
                }
            )
        ) : Container(),

           LoadingWidget(key: loadingKey),

          !_isLoadedData ? Container()
              : ControlsOverlay(key: controlsKey,
              publication: widget.publication,
              notesController: _notesController,
              handleBackPress: handleBackPress,
              jumpToPage: _jumpToPage,
              jumpToParagraph: _jumpToParagraph,
              jumpToVerse: _jumpToVerse
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
  bool isLoadingPage = true; // L'état qui change et déclenche setState

  void loadingFinish() {
    // Vérifiez que le widget est encore monté avant d'appeler setState
    if (mounted) {
      setState(() {
        isLoadingPage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le loader doit être enveloppé dans un Positioned.fill pour le Stack
    if (!isLoadingPage) {
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
  final NotesController notesController;
  final Function(int beginParagraphOrdinal, int endParagraphOrdinal) jumpToParagraph;
  final Function(int beginVerseOrdinal, int endVerseOrdinal) jumpToVerse;

  const ControlsOverlay({super.key, required this.publication, required this.notesController, required this.handleBackPress, required this.jumpToPage, required this.jumpToParagraph, required this.jumpToVerse});

  @override
  _ControlsOverlayState createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  late InAppWebViewController _controller;

  /* MODES */
  bool _isImageMode = false;
  bool _isPronunciationGuide = false;

  /* SEARCH */
  bool _isSearching = false;
  List<Map<String, dynamic>> suggestions = [];

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

  bool isSearching() {
    if(_isSearching) {
      setState(() {
        _isSearching = false;
      });
      return true;
    }
    return false;
  }

  void changePageAt(int index, bool imageMode) {
    setState(() {
      widget.publication.documentsManager!.selectedDocumentIndex = index;
      _controlsVisible = true;
      _isImageMode = imageMode;
    });
    GlobalKeyService.jwLifePageKey.currentState!.toggleBottomNavBarVisibility(_controlsVisible);
  }

  void refreshWidget() {
    setState(() {});
  }

  Future<void> switchImageMode() async {
   setState(() {
      if (_isImageMode) {
        _isImageMode = false;
      }
      else {
        _isImageMode = true;
      }
    });
    _controller.evaluateJavascript(source: "switchImageMode($_isImageMode)");
  }

  Future<void> switchPronunciationGuideMode() async {
    setState(() {
      if (_isPronunciationGuide) {
        _isPronunciationGuide = false;
      }
      else {
        _isPronunciationGuide = true;
      }
    });
    _controller.evaluateJavascript(source: "switchPronunciationGuideMode($_isPronunciationGuide)");
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: _controlsVisible,
              child: _isSearching ? AppBar(
                  titleSpacing: 0,
                  actionsPadding: const EdgeInsets.only(left: 10, right: 5),
                  title: SearchFieldWidget(
                  query: '',
                  onSearchTextChanged: (text) {
                    widget.publication.wordsSuggestionsModel!.fetchSuggestions(text);
                  },
                  onSuggestionTap: (item) async {
                    String query = item.item!.query;

                    // Encodage JS sûr
                    final safeQuery = jsonEncode([query]); // Exemple : ["mot"]

                    _controller.evaluateJavascript(source: "selectWords($safeQuery, true);");

                    setState(() {
                      _isSearching = false;
                    });
                  },
                  onSubmit: (text) async {
                    final safeText = jsonEncode([text]);

                    _controller.evaluateJavascript(source: "selectWords($safeText, true);");

                    setState(() {
                      _isSearching = false;
                    });
                  },
                  onTapOutside: (event) {
                    setState(() {
                      _isSearching = false;
                    });
                  },
                  suggestionsNotifier: widget.publication.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([])
                ),
                leading: IconButton(
                  icon: const Icon(JwIcons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                    });
                  }
                )
              ) : JwLifeAppBar(
                title: widget.publication.documentsManager!.getCurrentDocument().getDisplayTitle(),
                subTitle: widget.publication.issueTitle.isNotEmpty ? widget.publication.issueTitle : widget.publication.shortTitle,
                handleBackPress: widget.handleBackPress,
                actions: [
                  if (widget.publication.audiosNotifier.value.any((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) || widget.publication.audiosNotifier.value.any((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible))
                    IconTextButton(
                      text: "Écouter ou télécharger l'audio",
                      icon: Icon(JwIcons.headphones),
                      onPressed: (anchorContext) {
                        int? index;
                        if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
                          index = widget.publication.audiosNotifier.value.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                        }
                        else {
                          index = widget.publication.audiosNotifier.value.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                        }
                        if (index != -1) {
                          // Afficher un PopMenu avec Écouter l'audio ou Télécharger l'audio

                          showAudioPopupMenu(anchorContext, widget.publication, index);
                        }
                      },
                    ),
                  IconTextButton(
                    text: i18n().action_search,
                    icon: Icon(JwIcons.magnifying_glass),
                    onPressed: (anchorContext) {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                  IconTextButton(
                    text: i18n().action_bookmarks,
                    icon: Icon(JwIcons.bookmark),
                    onPressed: (anchorContext) async {
                      Bookmark? bookmark = await showBookmarkDialog(context, widget.publication, webViewController: _controller, mepsDocumentId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, bookNumber: widget.publication.documentsManager!.getCurrentDocument().bookNumber, chapterNumber: widget.publication.documentsManager!.getCurrentDocument().chapterNumber, title: widget.publication.documentsManager!.getCurrentDocument().getDisplayTitle(), snippet: '', blockType: 0, blockIdentifier: null);
                      if (bookmark != null) {
                        if(bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                          int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumber == bookmark.location.chapterNumber);

                          if (page != widget.publication.documentsManager!.selectedDocumentIndex) {
                            await widget.jumpToPage(page);
                          }

                          if (bookmark.blockIdentifier != null) {
                            widget.jumpToVerse(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                          }
                        }
                        else {
                          if(bookmark.location.mepsDocumentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                            int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);

                            if (page != widget.publication.documentsManager!.selectedDocumentIndex) {
                              await widget.jumpToPage(page);
                            }

                            if (bookmark.blockIdentifier != null) {
                              widget.jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                            }
                          }
                        }
                      }
                    },
                  ),
                  IconTextButton(
                    text: i18n().action_languages,
                    icon: Icon(JwIcons.language),
                    onPressed: (anchorContext) async {
                      showLanguagePubDialog(context, widget.publication).then((languagePub) async {
                        if(languagePub != null) {
                          showPageDocument(languagePub, widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                        }
                      });
                    },
                  ),
                  IconTextButton(
                    text: i18n().action_add_a_note,
                    icon: const Icon(JwIcons.note_plus),
                    onPressed: (anchorContext) async {
                      String title = widget.publication.documentsManager!.getCurrentDocument().getDisplayTitle();
                      Document document = widget.publication.documentsManager!.getCurrentDocument();
                      await widget.notesController.addNote(title: title, document: document);
                    },
                  ),
                  if(widget.publication.documentsManager!.getCurrentDocument().hasMediaLinks)
                    IconTextButton(
                      text: i18n().navigation_meetings_show_media,
                      icon: const Icon(JwIcons.video_music),
                      onPressed: (anchorContext) {
                        showPage(DocumentMediasView(document: widget.publication.documentsManager!.getCurrentDocument()));
                      },
                    ),
                  IconTextButton(
                    text: i18n().action_display_menu,
                    icon: const Icon(JwIcons.list_thumbnail),
                    onPressed: (anchorContext) {
                      widget.publication.showMenu(context);
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
                    icon: const Icon(JwIcons.share),
                    onPressed: (anchorContext) {
                      widget.publication.documentsManager!.getCurrentDocument().share();
                    },
                  ),
                  IconTextButton(
                    text: i18n().action_qr_code,
                    icon: const Icon(JwIcons.qr_code),
                    onPressed: (anchorContext) {
                      String uri = widget.publication.documentsManager!.getCurrentDocument().share(hide: true);
                      showQrCodeDialog(context, widget.publication.documentsManager!.getCurrentDocument().getDisplayTitle(), uri);
                    },
                  ),
                  if (widget.publication.documentsManager!.getCurrentDocument().svgs.isNotEmpty)
                    IconTextButton(
                      text: _isImageMode ? i18n().action_view_mode_text : i18n().action_view_mode_image,
                      icon: Icon(_isImageMode ? JwIcons.outline : JwIcons.image),
                      onPressed: (anchorContext) {
                        switchImageMode();
                      },
                    ),
                  if (widget.publication.documentsManager!.getCurrentDocument().hasPronunciationGuide)
                    IconTextButton(
                      text: widget.publication.mepsLanguage.primaryIetfCode == 'ja'
                          ? i18n().action_display_furigana
                          : widget.publication.mepsLanguage.primaryIetfCode.contains('cmn')
                          ? i18n().action_display_pinyin
                          : i18n().action_display_yale,
                      icon: Icon(JwIcons.vernacular_text),
                      isSwitch: widget.publication.mepsLanguage.primaryIetfCode == 'ja'
                          ? JwLifeSettings.instance.webViewData.isFuriganaActive
                          : widget.publication.mepsLanguage.primaryIetfCode.contains('cmn')
                          ? JwLifeSettings.instance.webViewData.isPinyinActive
                          : JwLifeSettings.instance.webViewData.isYaleActive,
                      onSwitchChange: (value) async {
                        final languageCode = widget.publication.mepsLanguage.primaryIetfCode;

                        if (languageCode == 'ja' &&
                            value != JwLifeSettings.instance.webViewData.isFuriganaActive) {
                          await AppSharedPreferences.instance.setFuriganaActive(value);
                          JwLifeSettings.instance.webViewData.updatePronunciationGuide(value, 'furigana');
                          setState(() {});
                        } else if (languageCode.contains('cmn') &&
                            value != JwLifeSettings.instance.webViewData.isPinyinActive) {
                          await AppSharedPreferences.instance.setPinyinActive(value);
                          JwLifeSettings.instance.webViewData.updatePronunciationGuide(value, 'pinyin');
                          setState(() {});
                        } else if (value != JwLifeSettings.instance.webViewData.isYaleActive) {
                          await AppSharedPreferences.instance.setYaleActive(value);
                          JwLifeSettings.instance.webViewData.updatePronunciationGuide(value, 'yale');
                          setState(() {});
                        }
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
                    icon: const Icon(JwIcons.square_stack),
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
                      icon: const Icon(JwIcons.scroll),
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
                      icon: const Icon(Icons.block),
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
                  if(kDebugMode)
                    IconTextButton(
                      text: "Voir le html",
                      icon: const Icon(JwIcons.square_stack),
                      onPressed: (anchorContext) async {
                        Document document = widget.publication.documentsManager!.getCurrentDocument();
                        if(document.isBibleChapter()) {
                          await showHtmlDialog(context, decodeBlobContent(document.chapterContent!, widget.publication.hash!));
                        }
                        else {
                          await showHtmlDialog(context, decodeBlobContent(document.content!, widget.publication.hash!));
                        }
                      },
                    ),
                ],
              )
          )
        ),
      ],
    );
  }
}