import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:sqflite/sqflite.dart';
import '../../app/services/settings_service.dart';
import '../../i18n/i18n.dart';

class LanguageDialog extends StatefulWidget {
  final Map<String, dynamic> languagesListJson;
  final String? selectedLanguageSymbol;

  const LanguageDialog({
    super.key,
    this.languagesListJson = const {},
    this.selectedLanguageSymbol,
  });

  @override
  _LanguageDialogState createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  String? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allLanguagesList = [];
  List<Map<String, dynamic>> _filteredLanguagesList = [];
  List<Map<String, dynamic>> _recommendedLanguages = []; // Renommé de _favoriteLanguages
  Database? database;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    initSettings();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> initSettings() async {
    selectedLanguage = widget.selectedLanguageSymbol ?? JwLifeSettings().currentLanguage.symbol;

    File mepsUnitFile = await getMepsUnitDatabaseFile();

    if (await mepsUnitFile.exists()) {
      try {
        database = await openDatabase(mepsUnitFile.path);
        await _fetchAllLanguages(selectedLanguage!);
      } finally {
        // La base de données est fermée après l'opération
        await database?.close();
      }
    }
  }

  Future<void> _fetchAllLanguages(String languageCode) async {
    // La requête SQL reste la même, elle récupère toutes les données nécessaires
    List<Map<String, dynamic>> response = await database!.rawQuery('''
      SELECT 
        l.LanguageId,
        l.Symbol,
        l.VernacularName,
        COALESCE(ln_src.Name, ln_fallback.Name) AS Name,
        l.PrimaryIetfCode,
        l.IsSignLanguage,
        s.InternalName,
        s.DisplayName,
        s.IsBidirectional,
        s.IsRTL,
        s.IsCharacterSpaced,
        s.IsCharacterBreakable,
        s.HasSystemDigits
      FROM Language l
      INNER JOIN Script s ON l.ScriptId = s.ScriptId
      LEFT JOIN LocalizedLanguageName lln_src 
        ON l.LanguageId = lln_src.TargetLanguageId 
        AND lln_src.SourceLanguageId = (SELECT LanguageId FROM Language WHERE PrimaryIetfCode = ?)
      LEFT JOIN LanguageName ln_src ON lln_src.LanguageNameId = ln_src.LanguageNameId
      LEFT JOIN LocalizedLanguageName lln_fallback 
        ON l.LanguageId = lln_fallback.TargetLanguageId 
        AND lln_fallback.SourceLanguageId = l.PrimaryFallbackLanguageId
      LEFT JOIN LanguageName ln_fallback ON lln_fallback.LanguageNameId = ln_fallback.LanguageNameId
      WHERE l.VernacularName IS NOT '' 
        AND (ln_src.Name IS NOT NULL OR (ln_src.Name IS NULL AND ln_fallback.Name IS NOT NULL))
      ORDER BY Name COLLATE NOCASE;
    ''', [JwLifeSettings().locale.languageCode]);

    // Si widget.languagesListJson est fourni, filtrer et mapper les résultats
    if (widget.languagesListJson.isNotEmpty) {
      response = response.where((language) => widget.languagesListJson.keys.contains(language['Symbol']))
          .map((language) {
        return {
          'LanguageId': language['LanguageId'],
          'VernacularName': language['VernacularName'],
          'Name': language['Name'],
          'Symbol': language['Symbol'],
          'Title': widget.languagesListJson[language['Symbol']]['title'],
          'IsSignLanguage': language['IsSignLanguage'],
          'ScriptInternalName': language['InternalName'],
          'ScriptDisplayName': language['DisplayName'],
          'IsBidirectional': language['IsBidirectional'],
          'IsRTL': language['IsRTL'],
          'IsCharacterSpaced': language['IsCharacterSpaced'],
          'IsCharacterBreakable': language['IsCharacterBreakable'],
          'SupportsCodeNames': language['SupportsCodeNames'],
          'HasSystemDigits': language['HasSystemDigits'],
        };
      }).toList();
    }

    // Obtenir la liste des langues les plus utilisées
    List<Map<String, dynamic>> mostUsedLanguages = await getUpdatedMostUsedLanguages(selectedLanguage!, response);

    // Identifier les langues recommandées (sélectionnée + plus utilisées)
    _recommendedLanguages = response.where((lang) {
      return isRecommended(lang, mostUsedLanguages); // isRecommended est l'ancien isFavorite
    }).toList();

    // Trier la liste complète (qui est déjà triée par la requête SQL)
    // Ici, nous nous assurons que le tri par Name de la requête SQL est suffisant pour le tri général
    List<Map<String, dynamic>> languagesModifiable = List.from(response);

    setState(() {
      _allLanguagesList = languagesModifiable;
      _filteredLanguagesList = languagesModifiable; // Initialisation complète
      _applySearchFilter(); // Appliquer le filtre de recherche initial (vide)
    });
  }

  Future<List<Map<String, dynamic>>> getUpdatedMostUsedLanguages(String selectedLanguageSymbol, List<Map<String, dynamic>> allLanguages) async {
    List<Map<String, dynamic>> mostUsedLanguages =
    await History.getMostUsedLanguages();
    List<Map<String, dynamic>> mostUsedLanguagesList =
    List.from(mostUsedLanguages);

    final selectedLang = allLanguages.firstWhere(
          (lang) => lang['Symbol'] == selectedLanguageSymbol,
      orElse: () => <String, dynamic>{},
    );

    if (selectedLang.isEmpty) {
      return mostUsedLanguagesList;
    }

    final alreadyInList = mostUsedLanguagesList.any(
          (lang) => lang['MepsLanguageId'] == selectedLang['LanguageId'],
    );

    if (!alreadyInList && mostUsedLanguagesList.isNotEmpty) {
      mostUsedLanguagesList
        ..sort((a, b) =>
            (a['Occurrences'] as int).compareTo(b['Occurrences'] as int))
        ..removeAt(0)
        ..add({
          'MepsLanguageId': selectedLang['LanguageId'],
          'Occurrences': 0,
        })
        ..sort((a, b) =>
            (b['Occurrences'] as int).compareTo(a['Occurrences'] as int));
    }

    return mostUsedLanguagesList;
  }

  bool isRecommended( // Renommé de isFavorite
      Map<String, dynamic> language,
      List<Map<String, dynamic>> mostUsedLanguages,
      ) {
    return language['Symbol'] == selectedLanguage ||
        mostUsedLanguages.any(
              (lang) => lang['MepsLanguageId'] == language['LanguageId'],
        );
  }

  void _applySearchFilter() {
    String searchTerm = _searchController.text.toLowerCase();

    // 1. Filtrer la liste complète (_allLanguagesList)
    final filtered = _allLanguagesList.where((lang) {
      final name = lang['Name']?.toString().toLowerCase() ?? '';
      final vernacularName = lang['VernacularName']?.toString().toLowerCase() ?? '';
      return name.contains(searchTerm) || vernacularName.contains(searchTerm);
    }).toList();

    // 2. Déterminer les langues recommandées parmi les résultats filtrés
    final recommendedSymbols = _recommendedLanguages.map((l) => l['Symbol']).toSet();

    // 3. Appliquer le tri : Recommandé, puis Alphabetique.
    filtered.sort((a, b) {
      final aIsRecommended = recommendedSymbols.contains(a['Symbol']);
      final bIsRecommended = recommendedSymbols.contains(b['Symbol']);

      // 3.1. Priorité à la langue actuellement sélectionnée
      if (a['Symbol'] == selectedLanguage) return -1;
      if (b['Symbol'] == selectedLanguage) return 1;

      // 3.2. Priorité aux langues Recommandées
      if (aIsRecommended && !bIsRecommended) return -1;
      if (!aIsRecommended && bIsRecommended) return 1;

      // 3.3. Tri alphabétique par 'Name' (traduit)
      final aName = a['Name']?.toString() ?? '';
      final bName = b['Name']?.toString() ?? '';
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    setState(() {
      _filteredLanguagesList = filtered;
    });
  }

  Future<void> _onSearchChanged() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _applySearchFilter();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color dividerColor = isDarkMode ? Colors.black : const Color(0xFFf0f0f0);
    final Color hintColor = isDarkMode ? const Color(0xFFc5c5c5) : const Color(0xFF666666);
    final Color subtitleColor = isDarkMode ? const Color(0xFFbdbdbd) : const Color(0xFF626262);

    final totalFilteredCount = _filteredLanguagesList.length;

    final recommendedSymbols = _recommendedLanguages.map((l) => l['Symbol']).toSet();

    // La liste _filteredLanguagesList est déjà triée avec les langues recommandées en tête
    final combinedLanguages = _filteredLanguagesList.map((language) {
      return {
        ...language,
        'isRecommended': recommendedSymbols.contains(language['Symbol']), // Utilisation de isRecommended
      };
    }).toList();

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                i18n().action_languages,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            Divider(color: dividerColor),

            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(JwIcons.magnifying_glass, color: hintColor),
                    const SizedBox(width: 16),
                    // **Wrap the TextField in Expanded**
                    Expanded(
                      child: TextField( // <-- This is now constrained
                        controller: _searchController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          hintText: i18n().search_prompt_languages(totalFilteredCount),
                          hintStyle: TextStyle(color: hintColor, fontSize: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                )
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: combinedLanguages.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor, height: 0),
                itemBuilder: (BuildContext context, int index) {
                  final languageData = combinedLanguages[index];
                  final lank = languageData['Symbol'];
                  final vernacularName = languageData['VernacularName'];
                  final translatedName = languageData['Name'] ?? '';
                  final title = languageData['Title'] ?? '';
                  final isRecommended = languageData['isRecommended'] as bool;

                  // Logique pour afficher les en-têtes de section
                  bool showRecommendedHeader = isRecommended && (index == 0 || !combinedLanguages[index - 1]['isRecommended']);

                  bool showOtherLanguagesHeader = !isRecommended && (index == 0 || combinedLanguages[index - 1]['isRecommended'] as bool);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showRecommendedHeader)
                        Padding(
                          padding: const EdgeInsets.only(left: 25, bottom: 8, top: 5),
                          child: Text(
                            i18n().label_languages_recommended, // Nouveau titre
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (showOtherLanguagesHeader)
                        Padding(
                          padding: const EdgeInsets.only(left: 25, bottom: 8, top: 10),
                          child: Text(
                            i18n().label_languages_more,
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedLanguage = languageData['Symbol'];
                            Navigator.of(context).pop(languageData);
                          });
                        },
                        child: Container(
                          color: selectedLanguage == languageData['Symbol'] ? Theme.of(context).brightness == Brightness.dark ? const Color(0xFF626262) : const Color(0xFFf0f0f0) : null,
                          padding: const EdgeInsets.only(left: 40, right: 5, top: 5, bottom: 5),
                          child: Row(
                            children: [
                              if(selectedLanguage == languageData['Symbol'])
                              // Montrer quelque chose qui indeic une sorte de bar
                                Container(
                                  width: 3,
                                  height: 20,
                                  color: Theme.of(context).primaryColor,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(translatedName, style: const TextStyle(fontSize: 16)),
                                    Text(
                                      title.isNotEmpty
                                          ? title
                                          : vernacularName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(color: dividerColor),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text(
                  i18n().action_done_uppercase,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}