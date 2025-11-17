import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/decoration.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/input_decoration.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/searchfield.dart';
import 'package:jwlife/widgets/searchfield/searchfield_with_suggestions/searchfield_list_item.dart';

import '../../features/home/pages/search/suggestion.dart';
import '../../i18n/i18n.dart';

class SearchFieldWidget extends StatefulWidget {
  final String query;
  final void Function(String) onSearchTextChanged;
  final Function(SearchFieldListItem<SuggestionItem>) onSuggestionTap;
  final Function(String) onSubmit;
  final Function(PointerDownEvent) onTapOutside;
  final ValueNotifier<List<SuggestionItem>> suggestionsNotifier;

  const SearchFieldWidget({
    super.key,
    required this.query,
    required this.onSearchTextChanged,
    required this.onSuggestionTap,
    required this.onSubmit,
    required this.onTapOutside,
    required this.suggestionsNotifier,
  });

  @override
  _SearchFieldWidgetState createState() => _SearchFieldWidgetState();
}

class _SearchFieldWidgetState extends State<SearchFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    if(widget.query.isNotEmpty) {
      widget.onSearchTextChanged(widget.query);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Fonctions de décoration (inchangées)
  // -------------------------------------------------------------------
  static SearchInputDecoration buildSearchInputDecoration(BuildContext context) {
    return SearchInputDecoration(
      hintText: i18n().search_hint,
      searchStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1f1f1f) : const Color(0xFFf1f1f1),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
      border: const OutlineInputBorder(
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

  // -------------------------------------------------------------------
  // Construction d'un élément de suggestion (CORRIGÉ : gestion de l'icône)
  // -------------------------------------------------------------------
  Widget _buildSuggestionItem(BuildContext context, SuggestionItem suggestionItem) {
    // Utilisation directe des propriétés de SuggestionItem (caption et subtitle)
    final bool hasSubtitle = suggestionItem.subtitle?.isNotEmpty == true;

    final IconData icon = suggestionItem.icon ?? JwIcons.magnifying_glass; // Icône de recherche par défaut

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Utilise l'icône par défaut (ou mappée)
          Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4c4c4c)
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Titre (caption)
                Text(
                  suggestionItem.title,
                  style: TextStyle(
                      fontSize: hasSubtitle ? 15 : 16,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Sous-titre (subtitle)
                if (hasSubtitle)
                  Text(
                    suggestionItem.subtitle!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFc0c0c0) : const Color(0xFF757575)
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser ValueListenableBuilder pour réagir aux changements de suggestionsNotifier
    return ValueListenableBuilder<List<SuggestionItem>>(
      valueListenable: widget.suggestionsNotifier,
      builder: (context, suggestions, child) {
        // 1. Transformer la liste de SuggestionItem en List<SearchFieldListItem<SuggestionItem>>
        final List<SearchFieldListItem<SuggestionItem>> searchFieldListItems = suggestions.map((suggestionItem) {
          // Utilise la propriété 'caption' comme valeur d'affichage
          final String displayValue = suggestionItem.title;
          return SearchFieldListItem<SuggestionItem>(
            displayValue,
            item: suggestionItem, // L'objet complet SuggestionItem
            child: _buildSuggestionItem(context, suggestionItem),
          );
        }).toList();

        // 2. Retourner le SearchField reconstruit avec la nouvelle liste
        return SearchField<SuggestionItem>(
          controller: _controller,
          animationDuration: Duration.zero,
          itemHeight: 50,
          autofocus: true,
          offset: const Offset(0, 50),
          maxSuggestionsInViewPort: 9,
          searchInputDecoration: buildSearchInputDecoration(context),
          suggestionsDecoration: buildSuggestionsDecoration(context),

          onSearchTextChanged: (text) {
            widget.onSearchTextChanged(text);
            return []; // L'update UI se fait via le ValueListenableBuilder
          },

          onSuggestionTap: (item) {
            // Passer le SearchFieldListItem<SuggestionItem> au callback
            widget.onSuggestionTap(item);
          },
          onSubmit: widget.onSubmit,

          // Utilise la liste mise à jour
          suggestions: searchFieldListItems,
        );
      },
    );
  }
}