import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:sqflite/sqflite.dart';

class LanguagesPubDialog extends StatefulWidget {
  final Publication? publication;

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
    if (widget.publication != null) {
      selectedLanguage = widget.publication!.mepsLanguage.symbol;
    }
    File catalogFile = await getCatalogFile();

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

      if(widget.publication != null) {
        if (widget.publication!.issueTagNumber == 0) {
          arguments = [widget.publication!.keySymbol, widget.publication!.mepsLanguage.id];
          if (searchTerm.isNotEmpty) {
            arguments.add('%$searchTerm%');
            arguments.add('%$searchTerm%');
            arguments.add('%$searchTerm%');
          }
          languagesAvailable = await db.rawQuery('''
      SELECT 
        Publication.*,
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
          arguments = [widget.publication!.keySymbol, widget.publication!.issueTagNumber, widget.publication!.mepsLanguage.id];
          if (searchTerm.isNotEmpty) {
            arguments.add('%$searchTerm%');
            arguments.add('%$searchTerm%');
            arguments.add('%$searchTerm%');
          }
          languagesAvailable = await db.rawQuery('''
      SELECT 
        Publication.*,
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
      }
      else {
        arguments = [JwLifeApp.settings.currentLanguage.id];
        if (searchTerm.isNotEmpty) {
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
          arguments.add('%$searchTerm%');
        }
        languagesAvailable = await db.rawQuery('''
      SELECT 
        Publication.*,
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
        Publication.PublicationTypeId = 1
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
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Titre du dialogue
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                'Langues',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).secondaryHeaderColor, fontSize: 20),
              ),
            ),

            Divider(color: dividerColor),
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
              child: ListView.separated(
                itemCount: combinedLanguages.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor),
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
                            selectedLanguage = languageData['LanguageSymbol'];
                            Navigator.of(context).pop(languageData);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.only(left: 10, right: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Radio(
                                value: languageData['LanguageSymbol'],
                                activeColor: Theme.of(context).primaryColor,
                                groupValue: selectedLanguage,
                                onChanged: (value) {
                                  setState(() {
                                    selectedLanguage = languageData['LanguageSymbol'];
                                  });
                                },
                              ),
                              SizedBox(width: 20), // Espacement entre l'icône et le texte
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      languageData['LanguageName'],
                                      style: TextStyle(
                                        color: Theme.of(context).secondaryHeaderColor,
                                        fontFamily: 'Roboto',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      languageData['ShortTitle'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFc3c3c3)
                                            : const Color(0xFF626262),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Color(0xFF9d9d9d),
                                ),
                                itemBuilder: (context) {
                                  return [
                                    PopupMenuItem(
                                      onTap: () async {

                                      },
                                      child: Text('Télécharger'),
                                    ),
                                  ];
                                },
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