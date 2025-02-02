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
  Map<String, dynamic>? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredLanguagesList = [];
  Database? database;

  @override
  void initState() {
    super.initState();
    initSettings('');
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> initSettings(String searchTerm) async {
    File mepsUnitFile = await getMepsFile(); // mepsUnitFile est .db
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    if (await mepsUnitFile.exists()) {
      // Ouvrir la base de données
      database = await openDatabase(mepsUnitFile.path);

      // Fetch languages using language code
      await fetchLanguages(languageSymbol, searchTerm);

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
    if (!widget.languagesListJson.isEmpty) {
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

    setState(() {
      filteredLanguagesList = response;
    });
  }

  Future<void> _onSearchChanged() async {
    if (database != null) {
      await initSettings(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Accès au thème pour éviter les erreurs de constantes
    final Color dividerColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : const Color(0xFFf0f0f0);
    final Color hintColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFc5c5c5)
        : const Color(0xFF666666);
    final Color subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFbdbdbd)
        : const Color(0xFF626262);
    final Color buttonColor = Theme.of(context).primaryColor;

    return SimpleDialog(
      title: const Text('Langues'),
      contentPadding: const EdgeInsets.only(top: 10, bottom: 0),
      children: <Widget>[
        const SizedBox(height: 10),
        // Ligne de séparation
        Container(
          height: 1,
          color: dividerColor,
        ),
        const SizedBox(height: 10),
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
                    hintText: 'Rechercher une langue',
                    hintStyle: TextStyle(
                      fontSize: 18,
                      color: hintColor,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: MediaQuery.of(context).size.width,  // Largeur de l'écran
          height: MediaQuery.of(context).size.height * 0.6,  // 50% de la hauteur de l'écran
          child: ListView.builder(
            itemCount: filteredLanguagesList.length,
            itemBuilder: (BuildContext context, int index) {
              final languageData = filteredLanguagesList[index];
              final vernacularName = languageData['VernacularName'];
              final translatedName = languageData['Name'];
              final title = languageData['Title'] ?? ''; // Affichage du titre si disponible

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                title: Text(translatedName, style: const TextStyle(fontSize: 17)),
                subtitle: title != ''
                    ? Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                )
                    : Text(
                  vernacularName,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
                leading: Radio(
                  fillColor: MaterialStateColor.resolveWith(
                        (states) => const Color(0xFF9d9d9d),
                  ),
                  value: vernacularName,
                  groupValue: selectedLanguage?['VernacularName'],
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = filteredLanguagesList[index];
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    selectedLanguage = filteredLanguagesList[index];
                    Navigator.of(context).pop(selectedLanguage);
                  });
                },
              );
            },
          ),
        ),
        Container(
          height: 1,
          color: dividerColor,
        ),
        ButtonBar(
          children: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: Text(
                'TERMINER',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: buttonColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
