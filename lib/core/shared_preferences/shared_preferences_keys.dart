/// Centralise les clés et valeurs par défaut de SharedPreferences
class SharedPreferencesKeys {
  const SharedPreferencesKeys._(); // empêche l'instanciation

  // Thème
  static const theme = _PrefKey('theme', 'system');
  static const primaryColor = _PrefKey('primary_color', null);
  static const bibleColor = _PrefKey('bible_color', null);

  // Langue
  static const locale = _PrefKey('locale', 'en');
  static const libraryLanguage = _PrefKey('library_language', ['0', 'E', 'English', 'en', '0', 'ROMAN', 'Roman', '0', '0', '0', '0', '1', 'r1', 'lp-e']);

  // Version
  static const lastCatalogRevision = _PrefKey('last_catalog_revision', 0);
  static const lastMepsTimestamp = _PrefKey('last_meps_timestamp', '');

  // Web app
  static const webAppDownloadVersion = _PrefKey('webapp_version', '');

  // Document
  static const fontSize = _PrefKey('font_size', 20.0);
  static const fullscreenMode = _PrefKey('fullscreen', true);
  static const readingMode = _PrefKey('reading', false);
  static const blockingHorizontallyMode = _PrefKey('blocking_horizontally', false);

  // Style dans le webview
  static const styleIndex = _PrefKey('style_index', 0);
  static const colorIndex = _PrefKey('color_index', 1);

  static const lookupBible = _PrefKey('lookup_bible', '');
  static final biblesSet = _PrefKey('bibles_set', []);

  // Notifications
  static const dailyTextNotification = _PrefKey('daily_text_notification', false);
  static final dailyTextNotificationTime = _PrefKey('daily_text_notification_time', '08:00'); // Format: HH:mm

  static const bibleReadingNotification = _PrefKey('bible_reading_notification', false);
  static final bibleReadingNotificationTime = _PrefKey('bible_reading_notification_time', '08:00'); // Format: HH:mm

  static final downloadNotification = _PrefKey('download_notification', false);
}

/// Modèle interne pour associer une clé à une valeur par défaut
class _PrefKey {
  final String key;
  final dynamic defaultValue;
  const _PrefKey(this.key, this.defaultValue);
}
