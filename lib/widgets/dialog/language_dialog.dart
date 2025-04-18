import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';

class LanguageDialog extends StatefulWidget {
  final Map<String, dynamic> languagesListJson;

  const LanguageDialog({super.key, this.languagesListJson = const {}});

  @override
  _LanguageDialogState createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  String? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredLanguagesList = [];
  List<Map<String, dynamic>> favoriteLanguages = []; // Liste pour les langues favorites
  Database? database;

  @override
  void initState() {
    super.initState();
    initSettings('');
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> initSettings(String searchTerm) async {
    selectedLanguage = JwLifeApp.settings.currentLanguage.symbol;

    File mepsUnitFile = await getMepsFile(); // mepsUnitFile est .db

    if (await mepsUnitFile.exists()) {
      // Ouvrir la base de données
      database = await openDatabase(mepsUnitFile.path);

      // Fetch languages using language code
      await fetchLanguages(selectedLanguage!, searchTerm);

      database!.close();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchLanguages(String languageCode, String searchTerm) async {
    List<Map<String, dynamic>> response = await database!.rawQuery('''
    SELECT l.LanguageId, l.VernacularName, ln.Name, l.Symbol, l.PrimaryIetfCode
    FROM Language l
    JOIN LocalizedLanguageName lln ON l.LanguageId = lln.TargetLanguageId
    JOIN LanguageName ln ON lln.LanguageNameId = ln.LanguageNameId
    WHERE lln.SourceLanguageId = (SELECT LanguageId FROM Language WHERE Symbol = ?)
      AND l.VernacularName IS NOT '' 
      AND (l.VernacularName LIKE '%$searchTerm%' OR ln.Name LIKE '%$searchTerm%')
    ORDER BY ln.Name
  ''', [languageCode]);

    // Si le widget.languagesList est vide, on effectue une requête à la base de données.
    if (widget.languagesListJson.isNotEmpty) {
      // Filtrer les résultats pour ne garder que ceux présents dans la liste de langues
      response = response.where((language) => widget.languagesListJson.keys.contains(language['Symbol'])).toList();

      // Mapper les résultats en un nouveau format
      response = response.map((language) {
        return {
          'LanguageId': language['LanguageId'],
          'VernacularName': language['VernacularName'],
          'Name': language['Name'],
          'Symbol': language['Symbol'],
          'Title': widget.languagesListJson[language['Symbol']]['title'],
        };
      }).toList(); // Assurez-vous de convertir le résultat en liste
    }

    // Mise à jour de filteredLanguagesList
    List<Map<String, dynamic>> languagesModifiable = List.from(response);

    setState(() {
      filteredLanguagesList = languagesModifiable;
      favoriteLanguages = filteredLanguagesList.where((lang) {
        return isFavorite(lang);
      }).toList();
      filteredLanguagesList.removeWhere((lang) => isFavorite(lang));
    });
  }

  bool isFavorite(Map<String, dynamic> language) {
    return language['Symbol'] == selectedLanguage;
  }

  Future<void> _onSearchChanged() async {
    if (database != null) {
      await initSettings(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Accès au thème pour éviter les erreurs de constantes
    final Color dividerColor = isDarkMode ? Colors.black : const Color(0xFFf0f0f0);
    final Color hintColor = isDarkMode ? const Color(0xFFc5c5c5) : const Color(0xFF666666);
    final Color subtitleColor = isDarkMode ? const Color(0xFFbdbdbd) : const Color(0xFF626262);

    // Combine favoriteLanguages en haut et filteredLanguagesList en bas
    final combinedLanguages = [
      ...favoriteLanguages.map((language) => {...language, 'isFavorite': true}),
      ...filteredLanguagesList.map((language) => {
        ...language,
        'isFavorite': false
      }),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width,  // Largeur de l'écran
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                'Langues',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            Divider(color: dividerColor),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Icon(
                    JwIcons.magnifying_glass,
                    color: const Color(0xFF9d9d9d),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autocorrect: false, // Désactive la correction automatique
                      enableSuggestions: false, // Désactive les suggestions
                      keyboardType: TextInputType.text, // Permet la saisie de texte
                      decoration: InputDecoration(
                        hintText: 'Rechercher une langue (${filteredLanguagesList.length})',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                itemCount: combinedLanguages.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor),
                itemBuilder: (BuildContext context, int index) {
                  final languageData = combinedLanguages[index];
                  final vernacularName = languageData['VernacularName'];
                  final translatedName = languageData['Name'];
                  final title = languageData['Title'] ?? ''; // Affichage du titre si disponible
                  final isFavorite = languageData['isFavorite'] as bool;

                  return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFavorite && index == 0)
                        Padding(
                          padding: EdgeInsets.only(left: 20, bottom: 8),
                          child: Text(
                            'Favoris',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (!isFavorite && index == favoriteLanguages.length)
                        Padding(
                          padding: EdgeInsets.only(left: 20, bottom: 8, top: 10),
                          child: Text(
                            'Autres langues',
                            style: TextStyle(
                              fontSize: 16,
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
                            padding: const EdgeInsets.only(left: 10, right: 5),
                            child: Row(
                              children: [
                                Radio(
                                  value: languageData['Symbol'],
                                  activeColor: Theme.of(context).primaryColor,
                                  groupValue: selectedLanguage,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedLanguage = languageData['Symbol'];
                                    });
                                  },
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(translatedName, style: const TextStyle(fontSize: 17)),
                                      title != ''
                                          ? Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor,
                                        ),
                                      ) : Text(
                                        vernacularName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          )
                      ),
                    ]
                  );
                },
              )
            ),

            Divider(color: dividerColor),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text(
                  'TERMINER',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor),
                ),
                onPressed: () {
                  Navigator.pop(context, null); // Retourne null si l'utilisateur ferme la boîte de dialogue
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
