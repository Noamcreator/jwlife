import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';

import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/features/video/subtitles.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';

import '../../app/app_page.dart';
import '../../app/services/settings_service.dart';
import '../../core/icons.dart';
import '../../core/utils/widgets_utils.dart';

class SubtitlesPage extends StatefulWidget {
  final Video video;
  final String? query;

  const SubtitlesPage({super.key, required this.video, this.query});

  @override
  State<SubtitlesPage> createState() => _SubtitlesPageState();
}

class _SubtitlesPageState extends State<SubtitlesPage> {
  final Subtitles _subtitles = Subtitles();
  InAppWebViewController? _controller;

  final TextEditingController _searchController = TextEditingController();
  
  final ValueNotifier<int> _currentMatchIndex = ValueNotifier(-1);
  final ValueNotifier<int> _totalMatches = ValueNotifier(0);
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  
  bool _webViewReady = false;
  String? _pendingQuery;

  @override
  void initState() {
    super.initState();
    
    if (widget.query != null && widget.query!.isNotEmpty) {
      _isSearching.value = true;
      _searchController.text = widget.query!;
      _pendingQuery = widget.query!;
    }

    if (widget.video.isDownloadedNotifier.value) {
      _fetchLocalSubtitles(widget.video);
    } else {
      _fetchOnlineSubtitles();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _currentMatchIndex.dispose();
    _totalMatches.dispose();
    _isSearching.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  void _fetchLocalSubtitles(Video localVideo) async {
    try {
      await _subtitles.loadSubtitlesFromFile(File(localVideo.subtitlesFilePath));
      _loadWebView();
    } catch (e) {
      debugPrint('Erreur sous-titres locaux : $e');
      _isLoading.value = false;
    }
  }

  void _fetchOnlineSubtitles() async {
    try {
      final link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.video.mepsLanguage}/${widget.video.naturalKey}';
      final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
      if (response.statusCode == 200) {
        await _subtitles.loadSubtitles(response.data['media'][0]);
      }
      _loadWebView();
    } catch (e) {
      debugPrint('Erreur sous-titres en ligne : $e');
      _isLoading.value = false;
    }
  }

  String _buildHtmlContent() {
    final buffer = StringBuffer();
    for (int i = 0; i < _subtitles.getSubtitles().length; i++) {
      final s = _subtitles.getSubtitles()[i];
      int pid = i + 1;
      buffer.writeln('<p id="p$pid" data-pid="$pid">${s.text}</p>');
    }

    const jsCode = r"""
    var searchResults = [];
    var isReady = false;
    
    const skipClasses = new Set(["fn", "m", "cl", "vl", "dc-button--primary", "gen-field", "parNum", "word", "escape", "punctuation"]);

    function wrapWordsWithSpan(article) {
        const paragraphs = article.querySelectorAll('[data-pid]');
        for (let i = 0; i < paragraphs.length; i++) {
            processTextNodes(paragraphs[i]);
        }
    }

    function processTextNodes(element) {
        const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false);
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
                if (/[\p{L}\p{N}]/u.test(token)) span.className = 'word';
                else if (/\s+/.test(token)) span.className = 'escape';
                else span.className = 'punctuation';
                span.textContent = token;
                fragment.appendChild(span);
            }
            node.parentNode.replaceChild(fragment, node);
        }
    }

    function highlightSearch(query) {
        const article = document.querySelector('article');
        article.querySelectorAll('.searched-word').forEach(span => span.classList.remove('searched-word'));
        
        if (!query) {
            searchResults = [];
            return { totalMatches: 0 };
        }
        
        searchResults = [];
        const regex = new RegExp(query, 'gi');
        article.querySelectorAll(".word").forEach((span) => {
            if (regex.test(span.textContent)) {
                span.classList.add("searched-word");
                const parentP = span.closest('p');
                if (parentP) searchResults.push(parentP.dataset.pid);
            }
        });
        
        searchResults = [...new Set(searchResults)].sort((a, b) => parseInt(a) - parseInt(b));
        return { totalMatches: searchResults.length };
    }

    function scrollToResult(index) {
        if (searchResults.length === 0) return;
        const targetId = "p" + searchResults[index];
        const element = document.getElementById(targetId);
        if (element) element.scrollIntoView({ behavior: "smooth", block: "center" });
    }

    function copySubtitles() {
        let allText = '';
        document.querySelectorAll('p').forEach(p => allText += p.textContent + '\n');
        const textarea = document.createElement('textarea');
        textarea.value = allText;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
    }
    
    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('p').forEach(p => {
            p.addEventListener('click', (event) => {
                const pid = event.currentTarget.dataset.pid;
                window.flutter_inappwebview.callHandler('startVideo', parseInt(pid) - 1);
            });
        });
        wrapWordsWithSpan(document.querySelector('article'));
        isReady = true;
        window.flutter_inappwebview.callHandler('onWebViewReady');
    });
    """;

    return '''
  <!DOCTYPE html>
  <html style="overflow-x: hidden; height: 100%;">
    <head>
      <meta content="text/html" charset="UTF-8">
      <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
      <link rel="stylesheet" href="jw-styles.css" />
      <style>
          body { font-size: ${JwLifeSettings.instance.webViewSettings.fontSize}px;}
          body.cc-theme--dark { background-color: #121212; color: #e0e0e0; }
          body.cc-theme--light { background-color: #ffffff; color: #1a1a1a; }
          .searched-word { background-color: rgba(255, 185, 46, 0.8);}
      </style>
    </head>
    <body class="${JwLifeSettings.instance.webViewSettings.theme}">
      <article id="article" class="jwac docClass-31 ms-ROMAN ml-F dir-ltr layout-reading layout-sidebar">
        ${buffer.toString()}
      </article>
      <script>$jsCode</script>
    </body>
  </html>
  ''';
  }

  Future<void> _loadWebView() async {
    final html = _buildHtmlContent();
    await _controller?.loadData(
        data: html,
        baseUrl: WebUri('file://${JwLifeSettings.instance.webViewSettings.webappPath}/')
    );
    _isLoading.value = false;
  }

  Future<void> _performSearch(String query) async {
    if (_controller == null) return;
    
    if (query.isEmpty) {
      await _controller!.evaluateJavascript(source: "highlightSearch('');");
      _totalMatches.value = 0;
      _currentMatchIndex.value = -1;
      return;
    }

    try {
      final result = await _controller!.evaluateJavascript(source: "highlightSearch('$query');");
      
      if (result != null && result is Map) {
        final total = result['totalMatches'] as int? ?? 0;
        _totalMatches.value = total;
        _currentMatchIndex.value = total > 0 ? 0 : -1;
        
        if (total > 0) {
          await _controller!.evaluateJavascript(source: "scrollToResult(0);");
        }
      }
    } catch (e) {
      debugPrint('Erreur recherche: $e');
    }
  }

  void _search(String query) async {
    if (!_webViewReady) {
      _pendingQuery = query;
      return;
    }
    
    await _performSearch(query);
  }

  void _nextResult() async {
    if (_totalMatches.value > 0) {
      _currentMatchIndex.value = (_currentMatchIndex.value + 1) % _totalMatches.value;
      await _controller?.evaluateJavascript(source: "scrollToResult(${_currentMatchIndex.value});");
    }
  }

  void _previousResult() async {
    if (_totalMatches.value > 0) {
      _currentMatchIndex.value = (_currentMatchIndex.value - 1 + _totalMatches.value) % _totalMatches.value;
      await _controller?.evaluateJavascript(source: "scrollToResult(${_currentMatchIndex.value});");
    }
  }

  void _copySubtitles() async {
    await _controller?.evaluateJavascript(source: "copySubtitles();");
    if (mounted) showBottomMessage('Sous-titres copiés');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppPage(
      backgroundColor: isDarkMode ? const Color(0xFF111111) : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isSearching,
          builder: (context, isSearching, _) {
            if (isSearching) {
              return JwLifeAppBar(
                titleWidget: SearchBar(
                  hintText: 'Rechercher...',
                  controller: _searchController,
                  onChanged: (query) {
                    _pendingQuery = null;
                    _performSearch(query);
                  },
                  onSubmitted: _performSearch,
                  constraints: const BoxConstraints(minHeight: 48),
                  trailing: [
                    ValueListenableBuilder<int>(
                      valueListenable: _totalMatches,
                      builder: (context, total, _) {
                        if (total == 0) return const SizedBox.shrink();
                        return ValueListenableBuilder<int>(
                          valueListenable: _currentMatchIndex,
                          builder: (context, index, _) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('${index + 1}/$total', style: Theme.of(context).textTheme.bodySmall),
                            );
                          },
                        );
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _totalMatches,
                      builder: (context, total, _) => IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: total > 0 ? _previousResult : null,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _totalMatches,
                      builder: (context, total, _) => IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: total > 0 ? _nextResult : null,
                      ),
                    ),
                  ],
                ),
                handleBackPress: () {
                  _searchController.clear();
                  _pendingQuery = null;
                  _controller?.evaluateJavascript(source: "highlightSearch('');");
                  _totalMatches.value = 0;
                  _currentMatchIndex.value = -1;
                  _isSearching.value = false;
                },
              );
            } else {
              return JwLifeAppBar(
                title: widget.video.title,
                subTitle: 'Sous-titres',
                actions: [
                  IconTextButton(
                    icon: const Icon(JwIcons.magnifying_glass),
                    onPressed: (BuildContext context) => _isSearching.value = true,
                  ),
                  IconTextButton(
                    icon: const Icon(JwIcons.document_stack),
                    onPressed: (BuildContext context) => _copySubtitles(),
                  ),
                ],
              );
            }
          },
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(
                data: _buildHtmlContent(),
                baseUrl: WebUri('file://${JwLifeSettings.instance.webViewSettings.webappPath}/')),
            onWebViewCreated: (controller) {
              _controller = controller;
              
              controller.addJavaScriptHandler(
                handlerName: 'onWebViewReady',
                callback: (args) async {
                  _webViewReady = true;
                  if (_pendingQuery != null && _pendingQuery!.isNotEmpty) {
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _performSearch(_pendingQuery!);
                    _pendingQuery = null;
                  }
                },
              );
              
              controller.addJavaScriptHandler(
                handlerName: 'startVideo',
                callback: (args) {
                  if (args.isNotEmpty && args[0] is int) {
                    int idx = args[0];
                    if (idx >= 0 && idx < _subtitles.getSubtitles().length) {
                       Subtitle subtitle = _subtitles.getSubtitles()[idx];
                       widget.video.showPlayer(context, initialPosition: subtitle.startTime);
                    }
                  }
                },
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) {
              if (!loading) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: isDarkMode ? const Color(0xFF111111) : Colors.white,
                  child: Center(child: getLoadingWidget(Theme.of(context).primaryColor)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}