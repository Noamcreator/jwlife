import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../jwlife.dart';
import '../../utils/files_helper.dart';

class LanguagesPubDialog extends StatefulWidget {
  final Map<String, dynamic> publication;

  const LanguagesPubDialog({super.key, required this.publication});

  @override
  _LanguagesPubDialogState createState() => _LanguagesPubDialogState();
}

class _LanguagesPubDialogState extends State<LanguagesPubDialog> {
  String? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredLanguagesList = [];
  List<Map<String, dynamic>> favoriteLanguages = []; // Liste pour les langues favorites
  Database? database;

  @override
  void initState() {
    super.initState();
    initSettings();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> initSettings() async {
    selectedLanguage = widget.publication['LanguageSymbol'];
    File catalogFile = await getCatalogFile();
    File mepsUnitFile = await getMepsFile();

    if (await catalogFile.exists()) {
      Database db = await openDatabase(catalogFile.path);
      setState(() {
        database = db;
      });
      await fetchLanguages('');
    }
  }

  Future<void> fetchLanguages(String searchTerm) async {
    if (database == null) return; // Assurez-vous que la base de données est initialisée

    print('fetchLanguages called with searchTerm: $searchTerm');
    File catalogFile = await getCatalogFile();
    File mepsUnitFile = await getMepsFile();

    if (await catalogFile.exists()) {
      Database db = database!;  // Utiliser la base de données déjà initialisée
      await db.execute('ATTACH DATABASE ? AS meps', [mepsUnitFile.path]);
      print('Database meps attached');

      List<Map<String, dynamic>> languagesAvailable = [];
      List<dynamic> arguments = [];

      String searchCondition = '';
      if (searchTerm.isNotEmpty) {
        searchCondition = 'AND (meps.LanguageName.Name LIKE ? OR Publication.Title LIKE ? OR Publication.ShortTitle LIKE ?)';
      }

      if (widget.publication['IssueTagNumber'] == 0) {
        arguments = [widget.publication['KeySymbol'], widget.publication['MepsLanguageId']];
        if (searchTerm.isNotEmpty) {
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
        }
        languagesAvailable = await db.rawQuery('''
      SELECT 
        Publication.Title,
        Publication.ShortTitle,
        mepsLang.Symbol as LanguageSymbol,
        meps.LanguageName.Name AS LanguageName
      FROM 
        Publication
      JOIN 
        meps.LocalizedLanguageName ON Publication.MepsLanguageId = meps.LocalizedLanguageName.TargetLanguageId
      JOIN 
        meps.LanguageName ON meps.LocalizedLanguageName.LanguageNameId = meps.LanguageName.LanguageNameId
      JOIN
        meps.Language AS mepsLang ON mepsLang.LanguageId = meps.LocalizedLanguageName.TargetLanguageId
      WHERE 
        Publication.KeySymbol = ? 
        AND meps.LocalizedLanguageName.SourceLanguageId = ?
        $searchCondition
      ORDER BY 
        meps.LanguageName.Name
      ''', arguments);
      }
      else {
        arguments = [widget.publication['KeySymbol'], widget.publication['IssueTagNumber'], widget.publication['MepsLanguageId']];
        if (searchTerm.isNotEmpty) {
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
        }
        languagesAvailable = await db.rawQuery('''
      SELECT 
        Publication.Title,
        Publication.ShortTitle,
        mepsLang.Symbol as LanguageSymbol,
        meps.LanguageName.Name AS LanguageName
      FROM 
        Publication
      JOIN 
        meps.LocalizedLanguageName ON Publication.MepsLanguageId = meps.LocalizedLanguageName.TargetLanguageId
      JOIN 
        meps.LanguageName ON meps.LocalizedLanguageName.LanguageNameId = meps.LanguageName.LanguageNameId
      JOIN
        meps.Language AS mepsLang ON mepsLang.LanguageId = meps.LocalizedLanguageName.TargetLanguageId
      WHERE 
        Publication.KeySymbol = ? 
        AND Publication.IssueTagNumber = ? 
        AND meps.LocalizedLanguageName.SourceLanguageId = ?
        $searchCondition
      ORDER BY 
        meps.LanguageName.Name
      ''', arguments);
      }

      await db.execute('DETACH DATABASE meps');
      print('Database meps detached');

      // Affichage des résultats récupérés
      print('languagesAvailable: $languagesAvailable');

      // Mise à jour de filteredLanguagesList
      List<Map<String, dynamic>> languagesModifiable = List.from(languagesAvailable);

      setState(() {
        filteredLanguagesList = languagesModifiable;
        favoriteLanguages = filteredLanguagesList.where((lang) {
          return isFavorite(lang);
        }).toList();
        filteredLanguagesList.removeWhere((lang) => isFavorite(lang));
      });
    } else {
      print('Catalog file does not exist.');
    }
  }

  bool isFavorite(Map<String, dynamic> language) {
    return language['LanguageSymbol'] == selectedLanguage; // Juste un exemple
  }

  Future<void> _onSearchChanged() async {
    if (database != null) {
      await fetchLanguages(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine favoriteLanguages en haut et filteredLanguagesList en bas
    final combinedLanguages = [
      ...favoriteLanguages.map((language) => {...language, 'isFavorite': true}),
      ...filteredLanguagesList.map((language) => {
        ...language,
        'isFavorite': false
      }),
    ];

    return Dialog(
      child: SizedBox(
        // Utilisation de la hauteur maximale de l'écran moins un peu de padding
        height: MediaQuery.of(context).size.height * 0.9, // 90% de la hauteur de l'écran
        width: MediaQuery.of(context).size.width * 0.9,  // 90% de la largeur de l'écran
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Titre du dialogue
            Padding(padding: const EdgeInsets.only(top: 20, left: 24),
              child: Text(
                'Langues',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).secondaryHeaderColor, fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            // Zone de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextField(
                controller: _searchController,
                autocorrect: false, // Désactive la correction automatique
                enableSuggestions: false, // Désactive les suggestions
                decoration: InputDecoration(
                  hintText: 'Rechercher une langue (${filteredLanguagesList.length})',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFc3c3c3)
                        : const Color(0xFF626262),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Liste combinée des langues
            Expanded(
              child: ListView.builder(
                itemCount: combinedLanguages.length,
                itemBuilder: (BuildContext context, int index) {
                  final languageData = combinedLanguages[index];
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
                        const Divider(),
                      if (!isFavorite && index == favoriteLanguages.length)
                        Padding(
                          padding: EdgeInsets.only(left: 20, bottom: 8),
                          child: Text(
                            'Autres langues',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ListTile(
                        title: Text(
                          languageData['LanguageName'],
                          style: TextStyle(
                            color: Theme.of(context).secondaryHeaderColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          languageData['ShortTitle'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc3c3c3)
                                : const Color(0xFF626262),
                          ),
                        ),
                        leading: Radio(
                          value: languageData['LanguageSymbol'],
                          groupValue: selectedLanguage,
                          onChanged: (value) {
                            setState(() {
                              selectedLanguage = languageData['LanguageSymbol'];
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            selectedLanguage = languageData['LanguageSymbol'];
                            Navigator.of(context).pop(languageData);
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            ButtonBar(
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('TERMINER', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}