import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/views/search/search_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import '../../../../../../../core/utils/directory_helper.dart';
import '../../../../../../../core/utils/widgets_utils.dart';
import '../../../../../../../data/models/userdata/bookmark.dart';
import '../../../../../app/services/settings_service.dart';
import '../../../../../core/webview/webview_utils.dart';
import '../../../../personal/pages/tag_page.dart';
import 'document_medias_page.dart';
import '../data/models/document.dart';
import 'package:audio_service/audio_service.dart' as audio_service;

import 'documents_manager.dart';
import 'full_screen_image_page.dart';

class DocumentPage extends StatefulWidget {
  final Publication publication;
  final int mepsDocumentId;
  final int? startParagraphId;
  final int? endParagraphId;
  final int? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;
  final List<Audio> audios;
  final List<String> wordsSelected;

  const DocumentPage({
    super.key,
    required this.publication,
    required this.mepsDocumentId,
    this.startParagraphId,
    this.endParagraphId,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
    this.audios = const [],
    this.wordsSelected = const [],
  });

  // Constructeur nommé pour une Bible
  const DocumentPage.bible({
    Key? key,
    required Publication bible,
    required int book,
    required int chapter,
    int? firstVerse,
    int? lastVerse,
    List<Audio> audios = const [],
  }) : this(
    key: key,
    publication: bible,
    mepsDocumentId: 0,
    book: book,
    chapter: chapter,
    firstVerse: firstVerse,
    lastVerse: lastVerse,
    audios: audios,
  );

  @override
  _DocumentPageState createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> with SingleTickerProviderStateMixin {
  /* CONTROLLER */
  late InAppWebViewController _controller;

  String webappPath = '';

  /* MODES */
  bool _isImageMode = false;
  bool _isSearching = false;
  bool _isFullscreen = true;

  /* LOADING */
  bool _isLoadingData = false;
  bool _isLoadingWebView = false;
  bool _isLoadingFonts = false;

  /* OTHER VIEW */
  bool _isProgrammaticScroll = false; // Variable pour éviter l'interférence
  String _lastDirectionScroll = ''; // Variable pour éviter l'interférence
  bool _controlsVisible = true; // Variable pour contrôler la visibilité des contrôles
  bool _controlsVisibleSave = true; // Variable pour contrôler la visibilité des contrôles
  bool _showDialog = false; // Variable pour contrôler la visibilité des contrôles

  final List<int> _pageHistory = []; // Historique des pages visitées
  int _currentPageHistory = 0;

  int? lastDocumentId;
  int lastParagraphId = 0;

  late StreamSubscription<SequenceState?> _streamSequenceStateSubscription;
  late StreamSubscription<Duration?> _streamSequencePositionSubscription;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    super.dispose();
    _streamSequenceStateSubscription.cancel();
    _streamSequencePositionSubscription.cancel();
    _controller.dispose();
  }

  Future<void> init() async {
    Directory webApp = await getAppWebViewDirectory();
    webappPath = '${webApp.path}/webapp';

    if(widget.publication.documentsManager != null) {
      if(widget.book != null && widget.chapter != null) {
        widget.publication.documentsManager!.bookNumber = widget.book!;
        widget.publication.documentsManager!.chapterNumber = widget.chapter!;
        widget.publication.documentsManager!.documentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.bookNumber == widget.book && element.chapterNumberBible == widget.chapter);
      }
      else {
        widget.publication.documentsManager!.documentIndex = widget.publication.documentsManager!.documents.indexWhere((element) => element.mepsDocumentId == widget.mepsDocumentId);
      }
    }
    else {
      widget.publication.documentsManager = DocumentsManager(publication: widget.publication, mepsDocumentId: widget.mepsDocumentId, bookNumber: widget.book, chapterNumber: widget.chapter);
      await widget.publication.documentsManager!.initializeDatabaseAndData();
    }

    setState(() {
      _isLoadingData = true;
    });

    await widget.publication.documentsManager!.getCurrentDocument().changePageAt();

    _isFullscreen = await getFullscreen();

    JwLifePage.toggleNavBarPositioned.call(true);
    JwLifePage.toggleNavBarVisibility.call(true);

    _streamSequenceStateSubscription = JwLifeApp.audioPlayer.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      if (JwLifeApp.audioPlayer.isSettingPlaylist && state.currentIndex == 0) return;
      if(!_isLoadingFonts) return;

      final currentSource = state.currentSource;
      if (currentSource is! ProgressiveAudioSource) {
        if (lastParagraphId != -1) {
          _jumpToParagraph(-1, -1);
          lastParagraphId = -1;
        }
        return;
      }

      ProgressiveAudioSource source = currentSource;
      var tag = source.tag as audio_service.MediaItem?;

      lastDocumentId = tag?.extras?['documentId'];

      if(widget.publication.documentsManager!.documents.any((document) => document.mepsDocumentId == lastDocumentId)) {
        int? currentIndex = state.currentIndex;

        if(currentIndex == null || currentIndex == -1) {
          _jumpToParagraph(-1, -1);
        }
        else {
          Audio audio = widget.audios[currentIndex];
          if(audio.documentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
            _jumpToPage(widget.publication.documentsManager!.documents.indexWhere((document) => document.mepsDocumentId == audio.documentId));
          }
        }
      }
      else if (lastParagraphId != -1) {
        _jumpToParagraph(-1, -1);
        lastParagraphId = -1;
      }
    });

    _streamSequencePositionSubscription = JwLifeApp.audioPlayer.player.positionStream.listen((position) {
      if (!mounted) return;
      if(!_isLoadingFonts) return;

      if(lastDocumentId != null && lastDocumentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
        Audio? audio = widget.audios.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
        if(audio != null) {
          Marker? marker = audio.markers.firstWhereOrNull((m) {
            final start = parseDuration(m.startTime).inSeconds;
            final end = start + parseDuration(m.duration).inSeconds;
            return position.inSeconds >= start && position.inSeconds <= end;
          });

          if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
            if (marker != null && marker.verseNumber != null) {
              if (marker.verseNumber != lastParagraphId) {
                _jumpToVerse(marker.verseNumber!, marker.verseNumber!);
                lastParagraphId = marker.verseNumber!;
              }
            }
          }
          else {
            if (marker != null && marker.mepsParagraphId != null) {
              if (marker.mepsParagraphId != lastParagraphId) {
                _jumpToParagraph(marker.mepsParagraphId!, marker.mepsParagraphId!);
                lastParagraphId = marker.mepsParagraphId!;
              }
            }
          }
        }
      }
    });
  }

  Future<void> changePageAt(int index) async {
    if (index <= widget.publication.documentsManager!.documents.length - 1 && index >= 0) {
      setState(() {
        widget.publication.documentsManager!.documentIndex = index;
      });

      await widget.publication.documentsManager!.getCurrentDocument().changePageAt();
    }
  }

  Future<void> _jumpToParagraph(int beginParagraphOrdinal, int endParagraphOrdinal) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('[data-pid]', 'data-pid', $beginParagraphOrdinal, $endParagraphOrdinal);");
  }

  Future<void> _jumpToVerse(int startVerseNumber, int lastVerseNumber) async {
    await _controller.evaluateJavascript(source: "jumpToIdSelector('.v', 'id', $startVerseNumber, $lastVerseNumber);");
  }

  Future<void> _jumpToPage(int page) async {
    if (page == widget.publication.documentsManager!.documentIndex) {
      return;
    }

    _pageHistory.add(widget.publication.documentsManager!.documentIndex); // Ajouter la page actuelle à l'historique
    _currentPageHistory = page;

    setState(() async {
      if (page != widget.publication.documentsManager!.documentIndex) {
        widget.publication.documentsManager!.documentIndex = page;
      }

      await _controller.evaluateJavascript(source: 'jumpToPage($page);');

      setControlsVisible(true);
    });
  }

  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    JwLifePage.toggleNavBarVisibility(visible);
  }

  bool _handleBackPress() {
    if (_pageHistory.isNotEmpty) {
      _currentPageHistory = _pageHistory.removeLast(); // Revenir à la dernière page dans l'historique
      _controller.evaluateJavascript(source: 'jumpToPage($_currentPageHistory);');
      return false; // Ne pas quitter l'application
    }
    return true; // Quitter l'application si aucun historique
  }

  void _openFullScreenImageView(String path) {
    String newPath = path.split('//').last.toLowerCase().trim();

    int indexImage = widget.publication.documentsManager!.getCurrentDocument().multimedias.indexWhere((img) => img.filePath.toLowerCase().contains(newPath));

    if (!widget.publication.documentsManager!.getCurrentDocument().multimedias.elementAt(indexImage).hasSuppressZoom) {
      JwLifePage.toggleNavBarBlack.call(true);

      showPage(context, FullScreenImagePage(
          publication: widget.publication,
          multimedias: widget.publication.documentsManager!.getCurrentDocument().multimedias,
          index: indexImage
      ));
    }
  }

  Future<void> switchImageMode() async {
    if (_isImageMode) {
      _controller.loadData(data: widget.publication.documentsManager!.getCurrentDocument().htmlContent, baseUrl: WebUri('file://$webappPath/'));

      setState(() {
        _isImageMode = false;
      });
    }
    else {
      String path = '${widget.publication.path}/${widget.publication.documentsManager!.getCurrentDocument().svgs[0]['FilePath']}';
      File file = File(path);
      String colorBackground = Theme.of(context).brightness == Brightness.dark ? '#202020' : '#ecebe7';
      String svgBase64 = base64Encode(file.readAsBytesSync());
      String base64Html = '''
<html>
  <body style="margin:0;padding:0;background-color:$colorBackground;display:flex;align-items:center;justify-content:center;">
    <div style="background-color:#ffffff;height:65%;box-shadow:0 4px 10px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;">
      <img src="data:image/svg+xml;base64,$svgBase64" style="width:100%;height:100%;object-fit:contain;" />
    </div>
  </body>
</html>
''';
      _controller.loadData(data: base64Html, mimeType: 'text/html', encoding: 'utf8');
      setState(() {
        _isImageMode = true;
      });
    }
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
                disableContextMenu: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                disableDefaultErrorPage: true,
                useOnLoadResource: false,         // À désactiver sauf si tu surveilles les requêtes
                allowUniversalAccessFromFileURLs: true,
                allowFileAccess: true,
                allowContentAccess: true,
                loadWithOverviewMode: true,
                useHybridComposition: true,
                offscreenPreRaster: true,
                hardwareAcceleration: true,
                databaseEnabled: false,
                domStorageEnabled: true,
              ),
              initialData: InAppWebViewInitialData(
                  data: widget.publication.documentsManager!.createReaderHtmlShell(widget),
                  baseUrl: WebUri('file://$webappPath/')
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
                    setState(() {
                      if(isShowDialog) {
                        _showDialog = true;
                      }
                      else {
                        setControlsVisible(_controlsVisibleSave);
                        _showDialog = false;
                      }
                    });
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'showFullscreenPopup',
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
                    if (index < 0 || index >= widget.publication.documentsManager!.documents.length) {
                      return {'html': '', 'className': '', 'audiosMarkers': '', 'isBibleChapter': false};
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

                      if (widget.audios.isNotEmpty) {
                        final audio = widget.audios.firstWhereOrNull((a) => a.bookNumber == doc.bookNumber && a.track == doc.chapterNumberBible);
                        if (audio != null && audio.markers.isNotEmpty) {
                          audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                        }
                      }
                    }
                    else {
                      html = decodeBlobContent(doc.content!, widget.publication.hash!);

                      if (widget.audios.isNotEmpty) {
                        final audio = widget.audios.firstWhereOrNull((a) => a.documentId == doc.mepsDocumentId);;
                        if (audio != null && audio.markers.isNotEmpty) {
                          audioMarkersJson = audio.markers.map((m) => m.toJson()).toList();
                        }
                      }
                    }
                    final className = getArticleClass(doc);

                    return {
                      'html': html,
                      'className': className,
                      'audiosMarkers': audioMarkersJson,
                      'isBibleChapter': doc.isBibleChapter(),
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
                    for(var note in widget.publication.documentsManager!.getCurrentDocument().notes) {
                      printTime('note: $note');
                    }
                    return {
                      'highlights': widget.publication.documentsManager!.getCurrentDocument().highlights,
                      'notes': widget.publication.documentsManager!.getCurrentDocument().notes,
                      'inputFields': widget.publication.documentsManager!.getCurrentDocument().inputFields,
                      'bookmarks': widget.publication.documentsManager!.getCurrentDocument().bookmarks,
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
                    if(!_showDialog) {
                      if (!_isProgrammaticScroll) {
                        if (args[1] == "down" && _lastDirectionScroll != "down") {
                          setState(() {
                            _controlsVisible = false;
                            _controlsVisibleSave = false;
                          });
                          // enelever la barre de noti en haut de l'ecran
                          //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
                          JwLifePage.toggleNavBarVisibility.call(false);
                        }
                        else if (args[1] == "up" && _lastDirectionScroll != "up") {
                          setState(() {
                            _controlsVisible = true;
                            _controlsVisibleSave = true;
                          });
                          // remettre la barre de noti en haut de l'ecran
                          //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
                          JwLifePage.toggleNavBarVisibility.call(true);
                        }
                        _lastDirectionScroll = args[1];
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
                    widget.publication.documentsManager!.getCurrentDocument().addHighlights(
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
                      widget.publication.documentsManager!.getCurrentDocument().removeHighlight(args[0]['guid']);
                    }
                );

                // Quand on change le color index d'un highlight
                controller.addJavaScriptHandler(
                    handlerName: 'changeHighlightColor',
                    callback: (args) {
                      widget.publication.documentsManager!.getCurrentDocument().changeHighlightColor(args[0]['guid'], args[0]['newColorIndex']);
                    }
                );


                controller.addJavaScriptHandler(
                  handlerName: 'addNote',
                  callback: (args) {
                    var uuid = Uuid();
                    String uuidV4 = uuid.v4();

                    widget.publication.documentsManager!.getCurrentDocument().addNoteWithUserMarkGuid(
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
                    widget.publication.documentsManager!.getCurrentDocument().removeNote(guid);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'updateNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    String title = args[0]['title'];
                    String content = args[0]['content'];
                    widget.publication.documentsManager!.getCurrentDocument().updateNote(uuid, title, content);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'addTagToNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    int tagId = args[0]['tagId'];
                    widget.publication.documentsManager!.getCurrentDocument().addTagToNote(uuid, tagId);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'removeTagToNote',
                  callback: (args) {
                    String uuid = args[0]['noteGuid'];
                    int tagId = args[0]['tagId'];
                    widget.publication.documentsManager!.getCurrentDocument().removeTagToNote(uuid, tagId);
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
                  handlerName: 'onImageClick',
                  callback: (args) {
                    _openFullScreenImageView(args[0]); // Gérer l'affichage de l'image
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchFootnote',
                  callback: (args) {
                    fetchFootnote(context, widget.publication, controller, args[0]);
                  },
                );

                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'fetchVersesReference',
                  callback: (args) {
                    fetchVersesReference(context, widget.publication, controller, args[0]);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'openMepsDocument',
                  callback: (args) async {
                    Map<String, dynamic>? document = args[0];
                    if (document != null) {
                      if (document['mepsDocumentId'] != null) {
                        await showDocumentView(context, document['mepsDocumentId'], document['mepsLanguageId'], startParagraphId: document['startParagraphId'], endParagraphId: document['endParagraphId']);
                        JwLifePage.toggleNavBarVisibility(_controlsVisible);
                        JwLifePage.toggleNavBarPositioned(true);
                      }
                      else if (document['bookNumber'] != null && document['chapterNumber'] != null) {
                        await showChapterView(
                          context,
                          'nwtsty',
                          document["mepsLanguageId"],
                          document["bookNumber"],
                          document["chapterNumber"],
                          firstVerseNumber: document["firstVerseNumber"],
                          lastVerseNumber: document["lastVerseNumber"],
                        );
                        JwLifePage.toggleNavBarVisibility(_controlsVisible);
                        JwLifePage.toggleNavBarPositioned(true);
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
                    final String id = arg['id'];
                    final String snippet = arg['snippet'];

                    final docManager = widget.publication.documentsManager!;
                    final currentDoc = docManager.getCurrentDocument();

                    if (isBible) {
                      // Cas d’un verset
                      int? blockIdentifier = int.tryParse(id);
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
                        title: '${currentDoc.displayTitle} ${currentDoc.chapterNumber}',
                        snippet: snippet.trim(),
                        blockType: blockType,
                        blockIdentifier: blockIdentifier,
                      );

                      if(bookmark != null) {
                        if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                          final page = docManager.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumberBible == bookmark.location.chapterNumber);

                          if (page != widget.publication.documentsManager!.documentIndex) {
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
                      int? blockIdentifier = int.tryParse(id);
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
                          if (page != widget.publication.documentsManager!.documentIndex) {
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
                  handlerName: 'showFullscreenDialog',
                  callback: (args) async {
                    bool isFullscreen = args[0]['isFullscreen'];
                    bool closeDialog = args[0]['closeDialog'];
                    setState(() {
                      if(closeDialog) {
                        setControlsVisible(_controlsVisibleSave);
                      }
                      else {
                        setControlsVisible(true);
                      }
                      _showDialog = isFullscreen;
                    });
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'share',
                  callback: (args) async {
                    final arg = args[0];

                    final bool isBible = arg['isBible'];
                    final String id = arg['id'];

                    widget.publication.documentsManager!.getCurrentDocument().share(isBible, id: id);
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

                controller.addJavaScriptHandler(
                  handlerName: 'playAudio',
                  callback: (args) async {
                    final arg = args[0];

                    final bool isBible = arg['isBible'];
                    final String id = arg['id'];

                    try {
                      // Trouver l'audio correspondant au document dans une liste
                      Audio? audio;

                      if(isBible) {
                        audio = widget.audios.firstWhereOrNull((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                      }
                      else {
                        audio = widget.audios.firstWhereOrNull((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                      }

                      if(audio != null) {
                        // Trouver le marqueur correspondant au paragraphId dans la liste des marqueurs
                        Marker? marker;
                        if(isBible) {
                          marker = audio.markers.firstWhereOrNull((marker) => marker.verseNumber == int.tryParse(id));
                        }
                        else {
                          marker = audio.markers.firstWhereOrNull((marker) => marker.mepsParagraphId == int.tryParse(id));
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
                            index = widget.audios.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                          }
                          else {
                            index = widget.audios.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                          }

                          if (index != -1) {
                            // Afficher le lien du lecteur audio et se positionner au bon startTime
                            showAudioPlayerPublicationLink(context, widget.publication, widget.audios, index, start: duration);
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

                    Publication bible = PublicationRepository().getAllBibles().first;

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
                    showPage(context, SearchPage(query: query));
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
                    int? docId = uri.queryParameters['docid'] != null ? int.parse(uri.queryParameters['docid']!) : null;
                    String track = uri.queryParameters['track'] ?? '';

                    MediaItem? mediaItem = getVideoItem(pub, int.parse(track), docId, null, null);

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

                if (requestedUrl.startsWith('jwpub-media://')) {
                  final filePath = requestedUrl.replaceFirst('jwpub-media://', '');
                  return await widget.publication.documentsManager!.getCurrentDocument().getImagePathFromDatabase(filePath);
                }

                return null;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                WebUri uri = navigationAction.request.url!;
                String url = uri.uriValue.toString();

                if(url.startsWith('jwpub://')) {
                  fetchHyperlink(context, controller, widget.publication, _jumpToPage, _jumpToParagraph, url, _controlsVisible);
                  return NavigationActionPolicy.CANCEL;
                }
                else if (url.startsWith('webpubdl://'))  {
                  final docId = uri.queryParameters['docid'];
                  final track = uri.queryParameters['track'];
                  final langwritten = uri.queryParameters.containsKey('langwritten') ? uri.queryParameters['langwritten'] : widget.publication.mepsLanguage.symbol;
                  final fileformat = uri.queryParameters['fileformat'];

                  showDocumentDialog(context, docId!, track!, langwritten!, fileformat!);

                  return NavigationActionPolicy.CANCEL;
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
                        if (result ==
                            'play') { // Vérifiez si le résultat est 'play'
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
                        publication.showMenu(context);
                      }
                    }
                  }

                  // Annule la navigation pour gérer le lien manuellement
                  return NavigationActionPolicy.CANCEL;
                }

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


        if (!_isFullscreen || (_isFullscreen && _controlsVisible))
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                title: _isSearching
                    ? Container(
                  decoration: BoxDecoration(
                    color: Colors.black, // Fond noir pour la barre de recherche
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          style: TextStyle(color: Colors.white), // Texte en blanc
                          decoration: InputDecoration(
                            hintText: 'Recherche...',
                            hintStyle: TextStyle(color: Colors.white54), // Texte de l'astuce en gris
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          onChanged: (value) {
                            printTime(value);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isSearching = false; // Fermer la barre de recherche
                          });
                        },
                      ),
                    ],
                  ),
                )
                    : !_isLoadingData ? Container() : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.publication.documentsManager!.getCurrentDocument().chapterNumber != null && widget.book != null
                          ? '${widget.publication.documentsManager!.getCurrentDocument().displayTitle} ${widget.publication.documentsManager!.getCurrentDocument().chapterNumber} '
                          : widget.publication.documentsManager!.getCurrentDocument().displayTitle.isNotEmpty ? widget.publication.documentsManager!.getCurrentDocument().displayTitle.trim() : widget.publication.documentsManager!.getCurrentDocument().title),
                      style: textStyleTitle,
                    ),
                    Text(
                      widget.publication.issueTitle.isNotEmpty ? widget.publication.issueTitle : widget.publication.shortTitle,
                      style: textStyleSubtitle,
                    ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if(_showDialog) {
                      _showDialog = false;
                      _controller.evaluateJavascript(source: """
                        const existingDialog = webview.getElementById('customDialog');
                        if (existingDialog) {
                          existingDialog.remove(); // Supprimez le dialogue existant
                        }
                      """);
                    }
                    else {
                      if (_handleBackPress()) {
                        setState(() {
                          _isLoadingWebView = false;
                        });
                        JwLifePage.toggleNavBarPositioned.call(false);
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
                actions: [
                  if (!_isSearching)
                    !_isLoadingData ? Container() : ResponsiveAppBarActions(
                      allActions: [
                        if (widget.audios.any((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) || widget.audios.any((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible))
                          IconTextButton(
                            text: "Écouter l'audio",
                            icon: Icon(JwIcons.headphones),
                            onPressed: () {
                              int? index;
                              if(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter()) {
                                index = widget.audios.indexWhere((audio) => audio.bookNumber == widget.publication.documentsManager!.getCurrentDocument().bookNumber && audio.track == widget.publication.documentsManager!.getCurrentDocument().chapterNumberBible);
                              }
                              else {
                                index = widget.audios.indexWhere((audio) => audio.documentId == widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId);
                              }
                              if (index != -1) {
                                showAudioPlayerPublicationLink(context, widget.publication, widget.audios, index);
                              }
                            },
                          ),
                        IconTextButton(
                          text: "Rechercher",
                          icon: Icon(JwIcons.magnifying_glass),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Marque-pages",
                          icon: Icon(JwIcons.bookmark),
                          onPressed: () async {
                            Bookmark? bookmark = await showBookmarkDialog(context, widget.publication, webViewController: _controller, mepsDocumentId: widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId, title: widget.publication.documentsManager!.getCurrentDocument().displayTitle, snippet: '', blockType: 0, blockIdentifier: null);
                            if (bookmark != null) {
                              if(bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                                int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.bookNumber == bookmark.location.bookNumber && doc.chapterNumber == bookmark.location.chapterNumber);

                                if (page != widget.publication.documentsManager!.documentIndex) {
                                  await _jumpToPage(page);
                                }

                                if (bookmark.blockIdentifier != null) {
                                  _jumpToVerse(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                                };
                              }
                              else {
                                if(bookmark.location.mepsDocumentId != widget.publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
                                  int page = widget.publication.documentsManager!.documents.indexWhere((doc) => doc.mepsDocumentId == bookmark.location.mepsDocumentId);

                                  if (page != widget.publication.documentsManager!.documentIndex) {
                                    await _jumpToPage(page);
                                  }

                                  if (bookmark.blockIdentifier != null) {
                                    _jumpToParagraph(bookmark.blockIdentifier!, bookmark.blockIdentifier!);
                                  }
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
                          text: "Ajouter une note",
                          icon: const Icon(JwIcons.note_plus),
                          onPressed: () async {
                            String title = widget.publication.documentsManager!.getCurrentDocument().title;
                            Document document = widget.publication.documentsManager!.getCurrentDocument();
                            var note = await JwLifeApp.userdata.addNote(
                                title, '', 0, [], document.mepsDocumentId,
                                document.bookNumber,
                                document.chapterNumberBible,
                                widget.publication.issueTagNumber,
                                widget.publication.keySymbol,
                                widget.publication.mepsLanguage.id, blockType: 0, blockIdentifier: null
                            );
                          },
                        ),
                        if(widget.publication.documentsManager!.getCurrentDocument().hasMediaLinks)
                          IconTextButton(
                            text: "Voir les médias",
                            icon: const Icon(JwIcons.video_music),
                            onPressed: () {
                              showPage(context, DocumentMediasView(document: widget.publication.documentsManager!.getCurrentDocument()));
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
                            widget.publication.documentsManager!.getCurrentDocument().share(widget.publication.documentsManager!.getCurrentDocument().isBibleChapter());
                          },
                        ),
                        if (widget.publication.documentsManager!.getCurrentDocument().svgs.isNotEmpty)
                          IconTextButton(
                            text: _isImageMode ? "Mode Texte" : "Mode Image",
                            icon: Icon(_isImageMode ? JwIcons.outline : JwIcons.image),
                            onPressed: () {
                              switchImageMode();
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
                            setState(() {
                              _isFullscreen = isFullscreen;
                            });
                          },
                        ),
                        IconTextButton(
                          text: "Voir le html",
                          icon: Icon(JwIcons.square_stack),
                          onPressed: () async {
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
                    ),
                ],
              )
          ),
      ]),
    );
  }

  String getArticleClass(Document document) {
    String publication = document.isBibleChapter() ? 'bible' : 'webview';
    return '''$publication html5 pub-${widget.publication.keySymbol} jwac docClass-${document.classType} docId-${document.documentId} ms-ROMAN ml-${widget.publication.mepsLanguage.symbol} dir-ltr layout-reading layout-sidebar ${JwLifeSettings().webViewData.theme}''';
  }
}