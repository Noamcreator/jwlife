/// Centralise les clés et valeurs par défaut de SharedPreferences
class SharedPreferencesKeys {
  const SharedPreferencesKeys._(); // empêche l'instanciation

  // Apparence
  static const theme = PrefKey('theme', 'system');
  static const pageTransition = PrefKey('page_transition', 'default');
  static const primaryColor = PrefKey('primary_color', null);
  static const bibleColor = PrefKey('bible_color', null);

  // Langue
  static const locale = PrefKey('locale', 'en');
  static const List<String> languageDefault = ['0', 'E', 'English', 'en', '0', 'ROMAN', 'Roman', '0', '0', '0', '0', '1', 'en', 'r1', 'lp-e'];
  static const libraryLanguage = PrefKey('library_language', languageDefault);
  static const dailyTextLanguage = PrefKey('daily_text_language', languageDefault);
  static const articlesLanguage = PrefKey('articles_language', languageDefault);
  static const workshipLanguage = PrefKey('workship_language', languageDefault);
  static const teachingToolboxLanguage = PrefKey('teaching_toolbox_language', languageDefault);
  static const latestLanguage = PrefKey('latest_language', languageDefault);

  // Version
  static const lastCatalogRevision = PrefKey('last_catalog_revision', 0);
  static const lastMepsTimestamp = PrefKey('last_meps_timestamp', '');

  // Web app
  static const webAppDownloadVersion = PrefKey('webapp_version', '');

  // Menu
  static const showPublicationDescription = PrefKey('show_publication_description', true);
  static const showDocumentDescription = PrefKey('show_document_description', true);
  static const autoOpenSingleDocument = PrefKey('auto_open_single_document', false);

  // Document
  static const fontSize = PrefKey('font_size', 20.0);
  static const fullscreenMode = PrefKey('fullscreen', true);
  static const readingMode = PrefKey('reading', false);
  static const blockingHorizontallyMode = PrefKey('blocking_horizontally', false);
  static const versesInParallel = PrefKey('verses_in_parallel', false);

  // Prononciation guide
  static const furiganaActive = PrefKey('furigana_active', false);
  static const pinyinActive = PrefKey('pinyin_active', false);
  static const yaleActive = PrefKey('yale_active', false);

  // Style dans le webview
  static const styleIndex = PrefKey('style_index', 0);
  static const colorIndex = PrefKey('color_index', 1);

  static const lookupBible = PrefKey('lookup_bible', '');
  static final biblesSet = PrefKey('bibles_set', []);

  // Notifications
  static const dailyTextNotification = PrefKey('daily_text_notification', false);
  static final dailyTextNotificationTime = PrefKey('daily_text_notification_time', '08:00'); // Format: HH:mm

  static const bibleReadingNotification = PrefKey('bible_reading_notification', false);
  static final bibleReadingNotificationTime = PrefKey('bible_reading_notification_time', '08:00'); // Format: HH:mm

  static final downloadNotification = PrefKey('download_notification', false);

  // Play and download
  static const streamUsingCellularData = PrefKey('stream_using_cellular_data', false);
  static const downloadUsingCellularData = PrefKey('download_using_cellular_data', false);
  static const offlineMode = PrefKey('offline_mode', false);

  // PLaylists
  static const playlistStartupAction = PrefKey('playlist_startup_action', 0);
  static const playlistEndAction = PrefKey('playlist_end_action', 0);
}

/// Modèle interne pour associer une clé à une valeur par défaut
class PrefKey {
  final String key;
  final dynamic defaultValue;
  const PrefKey(this.key, this.defaultValue);
}
