/// Centralise les clés et valeurs par défaut de SharedPreferences
class SharedPreferencesKeys {
  const SharedPreferencesKeys._(); // empêche l'instanciation

  // Thème
  static const theme = _PrefKey('theme', 'system');
  static const primaryColor = _PrefKey('primary_color', null);

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
  static const fullscreen = _PrefKey('fullscreen', true);

  // Surbrillance
  static const lastHighlightColorIndex = _PrefKey('last_highlight_color_index', 1);
}

/// Modèle interne pour associer une clé à une valeur par défaut
class _PrefKey {
  final String key;
  final dynamic defaultValue;
  const _PrefKey(this.key, this.defaultValue);
}
