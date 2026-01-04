import 'dart:io';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:sqflite/sqflite.dart';
import '../../app/services/settings_service.dart';
import '../../i18n/i18n.dart';

class LanguagesAppDialog extends StatefulWidget {
  const LanguagesAppDialog({super.key,});

  @override
  _LanguagesAppDialogState createState() => _LanguagesAppDialogState();
}

class _LanguagesAppDialogState extends State<LanguagesAppDialog> {
  Locale? selectedLocale;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allLanguagesList = [];
  List<Map<String, dynamic>> _filteredLanguagesList = [];
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
    selectedLocale = JwLifeSettings.instance.locale;

    File mepsUnitFile = await getMepsUnitDatabaseFile();

    if (await mepsUnitFile.exists()) {
      try {
        database = await openReadOnlyDatabase(mepsUnitFile.path);
        await _fetchAllLanguages(selectedLocale!);
      } finally {
        // La base de données est fermée après l'opération
        await database?.close();
      }
    }
  }

  Future<void> _fetchAllLanguages(Locale locale) async {
    final mepsLanguagesInClause = JwLifeSettings.instance.appLocalesMeps.map((meps) => "'${meps.value}'").join(',');
    final selectedMepsLanguage = i18n().meps_language;

    final response = await database!.rawQuery('''
      SELECT
        L.VernacularName,
        L.PrimaryIetfCode,
        COALESCE(LN.Name, L.PrimaryIetfCode) AS Name,
        L.Symbol
      FROM Language L
      LEFT JOIN LocalizedLanguageName LLN
        ON LLN.TargetLanguageId = L.LanguageId
        AND LLN.SourceLanguageId = (
          SELECT LanguageId FROM Language WHERE Symbol = '$selectedMepsLanguage'
        )
      LEFT JOIN LanguageName LN ON LN.LanguageNameId = LLN.LanguageNameId
      WHERE L.Symbol IN ($mepsLanguagesInClause)
    ''');

    List<Map<String, dynamic>> languagesModifiable = [];

    for (var loc in JwLifeSettings.instance.appLocalesMeps) {
      final dbMatch = response.firstWhereOrNull((row) => row['Symbol'] == loc.value);

      if (dbMatch != null) {
        languagesModifiable.add({
          ...Map<String, dynamic>.from(dbMatch),
          'Locale': loc.key,
        });
      }
      else {
        languagesModifiable.add({
          'VernacularName': '',
          'PrimaryIetfCode': loc.key.languageCode,
          'Name': loc.key.toString(),
          'Symbol': loc.value,
          'Locale': loc.key,
        });
      }
    }

    setState(() {
      _allLanguagesList = languagesModifiable;
      _filteredLanguagesList = languagesModifiable; // Initialisation complète
      _applySearchFilter(); // Appliquer le filtre de recherche initial (vide)
    });
  }

  void _applySearchFilter() {
    String searchTerm = normalize(_searchController.text);

    // 1. Filtrer la liste complète (_allLanguagesList)
    final filtered = _allLanguagesList.where((lang) {
      final name = normalize(lang['Name']?.toString() ?? '');
      final vernacularName = normalize(
          lang['VernacularName']?.toString() ?? '');
      return name.contains(searchTerm) || vernacularName.contains(searchTerm);
    }).toList();

    // 3. Appliquer le tri : Recommandé, puis Alphabetique.
    filtered.sort((a, b) {
      // 3.1. Priorité à la langue actuellement sélectionnée
      if (a['Symbol'] == selectedLocale) return -1;
      if (b['Symbol'] == selectedLocale) return 1;

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

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                itemCount: _filteredLanguagesList.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor, height: 0),
                itemBuilder: (BuildContext context, int index) {
                  final languageData = _filteredLanguagesList[index];
                  final vernacularName = languageData['VernacularName'];
                  final translatedName = languageData['Name'] ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            Navigator.of(context).pop(languageData);
                          });
                        },
                        child: Container(
                          color: selectedLocale == languageData['Locale'] ? Theme.of(context).brightness == Brightness.dark ? const Color(0xFF626262) : const Color(0xFFf0f0f0) : null,
                          padding: const EdgeInsetsDirectional.only(start: 40, end: 5, top: 5, bottom: 5),
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  if(selectedLocale == languageData['Locale'])
                                  // Montrer quelque chose qui indeic une sorte de bar
                                    Container(
                                      width: 3,
                                      height: 20,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(translatedName, style: const TextStyle(fontSize: 16)),
                                        Text(vernacularName, style: TextStyle(fontSize: 14, color: subtitleColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 40), // pour laisser la place au bouton
                                ],
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
              alignment: AlignmentDirectional.centerEnd,
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