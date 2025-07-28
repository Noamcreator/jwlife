class SuggestionItem {
  final int type;
  final dynamic query; // peut être String, int, ou autre selon usage
  final String caption;
  final String? icon;
  final String? subtitle;
  final String? label;

  SuggestionItem({
    required this.type,
    required this.query,
    required this.caption,
    this.icon,
    this.subtitle,
    this.label,
  });
}