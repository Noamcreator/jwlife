import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/features/video/subtitles.dart';

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
  int _currentMatchIndex = -1;
  int _totalMatches = 0;
  String _lastQuery = "";

  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.video.isDownloadedNotifier.value) {
      fetchLocalSubtitles(widget.video);
    }
    else {
      fetchOnlineSubtitles();
    }

    if (widget.query != null && widget.query!.isNotEmpty) {
      _searchController.text = widget.query!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isSearching = true;
        });
        _search(widget.query!);
      });
    }
  }

  void fetchLocalSubtitles(Video localVideo) async {
    try {
      await _subtitles.loadSubtitlesFromFile(File(localVideo.subtitlesFilePath));
      _loadWebView();
    } catch (e) {
      debugPrint('Erreur lors du chargement des sous-titres locaux : $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void fetchOnlineSubtitles() async {
    try {
      final link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${widget.video.mepsLanguage}/${widget.video.naturalKey}';
      final response = await Api.httpGetWithHeaders(link);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        await _subtitles.loadSubtitles(jsonData['media'][0]);
      }
      _loadWebView();
    }
    catch (e) {
      debugPrint('Erreur lors du chargement des sous-titres en ligne : $e');
      setState(() {
        _isLoading = false;
      });
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
    var currentIndex = 0;
    
    function wrapWordsWithSpan(article) {
        const paragraphs = article.querySelectorAll('[data-pid]');
        paragraphs.forEach((p) => {
            processTextNodes(p);
        });
    }

    function processTextNodes(element) {
        const skipClasses = new Set(["fn", "m", "cl", "vl", "dc-button--primary", "gen-field"]);
       
        function walkNodes(node) {
            if (node.nodeType === Node.TEXT_NODE) {
                const text = node.textContent;
                const newHTML = processText(text);
                const temp = document.createElement('div');
                temp.innerHTML = newHTML.html;
                            
                const parent = node.parentNode;
                while (temp.firstChild) {
                    parent.insertBefore(temp.firstChild, node);
                }
                parent.removeChild(node);
            } 
            else if (node.nodeType === Node.ELEMENT_NODE) {
              // VÉRIFIER D'ABORD avant de descendre dans les enfants !
              if (node.classList && [...skipClasses].some(c => node.classList.contains(c))) {
                  return; // Stop ici, ne traite PAS les enfants
              }
              
              if ((node.closest && node.closest("sup")) || 
                  (node.classList && (node.classList.contains('word') || 
                                     node.classList.contains('escape') || 
                                     node.classList.contains('punctuation')))) {
                  return;
              }
              
              const children = Array.from(node.childNodes);
              children.forEach(child => walkNodes(child));
          }
        }
        walkNodes(element);
    }
    
    function processText(text) {
        let html = '';
        let i = 0;
        while (i < text.length) {
            let currentChar = text[i];
            
            if (isSpace(currentChar)) {
                let spaceSequence = '';
                while (i < text.length && isSpace(text[i])) {
                    spaceSequence += text[i];
                    i++;
                }
                html += `<span class="escape">${spaceSequence}</span>`;
            } else if (isLetterOrDigit(currentChar) || isPunctuationPart(text, i)) {
                let word = '';
                while (i < text.length && (isLetterOrDigit(text[i]) || isPunctuationPart(text, i))) {
                    word += text[i];
                    i++;
                }
                html += `<span class="word">${word}</span>`;
            } else {
                html += `<span class="punctuation">${currentChar}</span>`;
                i++;
            }
        }
        return { html: html };
    }
    
    function isLetterOrDigit(char) {
        const code = char.charCodeAt(0);
        return (code >= 65 && code <= 90) || 
               (code >= 97 && code <= 122) || 
               (code >= 192 && code <= 255) || 
               (code >= 48 && code <= 57) ||
               char === 'œ' || char === 'Œ' ||
               char === 'æ' || char === 'Æ';
    }
    
    function isSpace(char) {
        return char === ' ' || char === '\u00A0';
    }
    
    function isPunctuationPart(text, index) {
        const char = text[index];
        if (isLetterOrDigit(char) || isSpace(char)) return false;
        
        const prevChar = index > 0 ? text[index - 1] : '';
        const nextChar = index < text.length - 1 ? text[index + 1] : '';
        
        return (isLetterOrDigit(prevChar) || isLetterOrDigit(nextChar));
    }

    function highlightSearch(query) {
        const article = document.querySelector('article');
        article.querySelectorAll('.searched-word').forEach(span => {
            span.classList.remove('searched-word');
        });
        
        if (!query) {
            return { totalMatches: 0, firstMatchId: null, searchResults: [] };
        }
        
        searchResults = [];
        currentIndex = 0;
        const regex = new RegExp(query, 'gi');
        
        article.querySelectorAll(".word").forEach((span, idx) => {
            if (regex.test(span.textContent)) {
                span.classList.add("searched-word");
                const parentP = span.closest('p');
                if (parentP) {
                    searchResults.push(parentP.dataset.pid);
                }
            }
        });
        
        const uniquePids = [...new Set(searchResults)];
        searchResults = uniquePids.sort((a, b) => parseInt(a) - parseInt(b));
        
        let firstMatchId = null;
        if (searchResults.length > 0) {
            firstMatchId = "p" + searchResults[0];
        }
        
        return { 
            totalMatches: searchResults.length, 
            firstMatchId: firstMatchId, 
            searchResults: searchResults
        };
    }

    function scrollToResult(index) {
        if (searchResults.length === 0) return;
        
        let targetId = "p" + searchResults[index];
        const element = document.getElementById(targetId);
        if (element) {
            element.scrollIntoView({ behavior: "smooth", block: "center" });
        }
    }

    function copySubtitles() {
        let allText = '';
        const paragraphs = document.querySelectorAll('p');
        paragraphs.forEach(p => {
            allText += p.textContent + '\n';
        });
        
        const textarea = document.createElement('textarea');
        textarea.value = allText;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        return true;
    }
    
    document.addEventListener('DOMContentLoaded', () => {
        const paragraphs = document.querySelectorAll('p');
        paragraphs.forEach(p => {
            p.addEventListener('click', (event) => {
                const pid = event.currentTarget.dataset.pid;
                window.flutter_inappwebview.callHandler('startVideo', parseInt(pid) - 1);
            });
        });
    });
    
    wrapWordsWithSpan(document.querySelector('article'));
    """;

    return '''
  <!DOCTYPE html>
  <html style="overflow-x: hidden; height: 100%;">
    <head>
      <meta content="text/html" charset="UTF-8">
      <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
      <link rel="stylesheet" href="jw-styles.css" />
    </head>
    <meta charset="utf-8">
    <style>
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          font-size: ${JwLifeSettings().webViewData.fontSize}px;
          overflow-y: scroll;
        }
        body.cc-theme--dark {
          background-color: #121212;
          color: #e0e0e0;
        }
        body.cc-theme--light {
          background-color: #ffffff;
          color: #1a1a1a;
        }
        .searched-word {
          background-color: rgba(255, 185, 46, 0.8);
          border-radius: 2px;
        }
        p {
          margin: 1em 0;
          line-height: 1.5;
        }
    </style>
    <body class="${JwLifeSettings().webViewData.theme}">
      <article id="article" class="jwac docClass-31 ms-ROMAN ml-F dir-ltr layout-reading layout-sidebar">
        ${buffer.toString()}
      </article>
      <script>
        $jsCode
      </script>
    </body>
  </html>
  ''';
  }

  void _loadWebView() {
    final html = _buildHtmlContent();
    _controller?.loadData(
        data: html,
        baseUrl: WebUri('file://${JwLifeSettings().webViewData.webappPath}/')
    ).then((_) {
      if (widget.query != null && widget.query!.isNotEmpty) {
        _search(widget.query!);
      }
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _search(String query) async {
    if (query.isEmpty) {
      await _controller?.evaluateJavascript(source: "highlightSearch('');");
      setState(() {
        _totalMatches = 0;
        _currentMatchIndex = -1;
      });
      return;
    }

    if (query != _lastQuery) {
      _lastQuery = query;
      final result = await _controller?.evaluateJavascript(source: "highlightSearch('$query');");
      _totalMatches = result['totalMatches'] as int? ?? 0;
      _currentMatchIndex = _totalMatches > 0 ? 0 : -1;
    } else {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    }

    if (_totalMatches > 0) {
      await _controller?.evaluateJavascript(source: "scrollToResult($_currentMatchIndex);");
    }
    setState(() {});
  }

  void _copySubtitles() async {
    await _controller?.evaluateJavascript(source: "copySubtitles();");
    if (mounted) {
      showBottomMessage('Sous-titres copiés');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDarkMode ? const Color(0xFF111111) : Colors.white,
      appBar: AppBar(
        title: _isSearching
            ? SearchBar(
          autoFocus: true,
          hintText: 'Rechercher...',
          controller: _searchController,
          onChanged: _search,
          onSubmitted: _search,
          constraints: const BoxConstraints(minHeight: 48),
          trailing: [
            if (_totalMatches > 0)
              Text(
                '${_currentMatchIndex + 1}/$_totalMatches',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_totalMatches > 0)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: () {
                  _currentMatchIndex = (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
                  _controller?.evaluateJavascript(source: "scrollToResult($_currentMatchIndex);");
                  setState(() {});
                },
              ),
            if (_totalMatches > 0)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () {
                  _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
                  _controller?.evaluateJavascript(source: "scrollToResult($_currentMatchIndex);");
                  setState(() {});
                },
              ),
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.video.title, style: const TextStyle(fontSize: 18.0)),
            const Text('Sous-titres', style: TextStyle(fontSize: 12.0)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _totalMatches = 0;
                _currentMatchIndex = -1;
                _lastQuery = "";
              });
              _controller?.evaluateJavascript(source: "highlightSearch('');");
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(JwIcons.magnifying_glass),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(JwIcons.document_stack),
              onPressed: _copySubtitles,
            ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(
                data: _buildHtmlContent(),
                baseUrl: WebUri('file://${JwLifeSettings().webViewData.webappPath}/')),
            onWebViewCreated: (controller) {
              _controller = controller;

              controller.addJavaScriptHandler(
                handlerName: 'startVideo',
                callback: (args) {
                  if (args.isNotEmpty && args[0] is int) {
                    int pid = args[0];
                    Subtitle subtitle = _subtitles.getSubtitles()[pid];
                    widget.video.showPlayer(context, initialPosition: subtitle.startTime);
                  }
                },
              );
            },
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? const Color(0xFF111111) : Colors.white,
                child: Center(
                  child: getLoadingWidget(Theme.of(context).primaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}