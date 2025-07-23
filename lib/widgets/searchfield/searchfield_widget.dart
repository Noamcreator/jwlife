import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:searchfield/searchfield.dart';

import '../../i18n/localization.dart';

class SearchFieldWidget extends StatefulWidget {
  final String query;
  final List<SearchFieldListItem<Map<String, dynamic>>>? Function(String) onSearchTextChanged;
  final Function(SearchFieldListItem<Map<String, dynamic>>) onSuggestionTap;
  final Function(String) onSubmit;
  final Function(PointerEvent) onTapOutside;
  final List<Map<String, dynamic>> suggestions;

  const SearchFieldWidget({
    super.key,
    required this.query,
    required this.onSearchTextChanged,
    required this.onSuggestionTap,
    required this.onSubmit,
    required this.onTapOutside,
    required this.suggestions,
  });

  @override
  _SearchFieldWidgetState createState() => _SearchFieldWidgetState();
}

class _SearchFieldWidgetState extends State<SearchFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query); // Initialiser le contrôleur avec la valeur de `query`
  }

  @override
  Widget build(BuildContext context) {
    return SearchField<Map<String, dynamic>>(
      controller: _controller, // Le contrôleur mis à jour
      animationDuration: Duration.zero,
      itemHeight: 50,
      autofocus: true,
      offset: const Offset(0, 50),
      maxSuggestionsInViewPort: 9,
      searchInputDecoration: buildSearchInputDecoration(context),
      suggestionsDecoration: buildSuggestionsDecoration(context),
      onSearchTextChanged: (text) {
        final fetchedSuggestions = widget.onSearchTextChanged(text);
        return fetchedSuggestions ?? [];
      },
      onSuggestionTap: (item) {
        // Appel du callback sur la suggestion sélectionnée
        widget.onSuggestionTap(item);
      },
      onSubmit: widget.onSubmit,
      suggestions: widget.suggestions
          .map(
            (item) => SearchFieldListItem<Map<String, dynamic>>(
          item['query'],
          item: item,
          child: _buildSuggestionItem(context, item),
        ),
      )
          .toList(),
    );
  }

  static SearchInputDecoration buildSearchInputDecoration(BuildContext context) {
    return SearchInputDecoration(
      hintText: localization(context).search_hint,
      searchStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1f1f1f) : const Color(0xFFf1f1f1),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
    );
  }

  static SuggestionDecoration buildSuggestionsDecoration(BuildContext context) {
    return SuggestionDecoration(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : const Color(0xFFffffff),
    );
  }


  Widget _buildSuggestionItem(BuildContext context, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(JwIcons.magnifying_glass, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4c4c4c)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['word'],
              style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFb8b8b8) : const Color(0xFF757575)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
