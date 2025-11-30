import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HtmlTemplateService {
  static final HtmlTemplateService _instance = HtmlTemplateService._internal();
  factory HtmlTemplateService() => _instance;
  HtmlTemplateService._internal();

  String? _readerHtmlTemplate;
  String? _readerJsTemplate;
  bool _isInitialized = false;

  /// Initialise tous les templates HTML ET JS au démarrage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _readerHtmlTemplate = await rootBundle.loadString('assets/html/DocumentView.html');
      _readerJsTemplate = await rootBundle.loadString('assets/html/DocumentView.js');
      _isInitialized = true;
      print('✅ HTML templates loaded successfully');
    } catch (e) {
      print('❌ Error loading HTML templates: $e');
      rethrow;
    }
  }

  /// Récupère le template reader (déjà chargé en mémoire)
  String getReaderTemplate() {
    if (!_isInitialized || _readerHtmlTemplate == null || _readerJsTemplate == null) {
      throw StateError('HtmlTemplateService not initialized. Call initialize() first.');
    }
    return _readerHtmlTemplate!.replaceAll('{{SCRIPT_CODE}}', _readerJsTemplate!);
  }

  /// Pour le hot reload en dev
  Future<void> reload() async {
    if (kDebugMode) {
      _isInitialized = false;
      await initialize();
    }
  }
}