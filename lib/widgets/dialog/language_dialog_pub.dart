import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';

class LanguagesPubDialog extends StatefulWidget {
  final Publication? publication;

  const LanguagesPubDialog({super.key, required this.publication});

  @override
  _LanguagesPubDialogState createState() => _LanguagesPubDialogState();
}

class _LanguagesPubDialogState extends State<LanguagesPubDialog> {
  String? selectedLanguage;
  String? selectedSymbol;
  int? selectedIssueTagNumber;
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
    File catalogFile = await getCatalogDatabaseFile();

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

    File catalogFile = await getCatalogDatabaseFile();
    File mepsUnitFile = await getMepsUnitDatabaseFile();

    if (await catalogFile.exists()) {
      Database db = database!;  // Utiliser la base de données déjà initialisée
      await db.execute('ATTACH DATABASE ? AS meps', [mepsUnitFile.path]);
      printTime('Database meps attached');

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
      FROM Publication
      INNER JOIN meps.LocalizedLanguageName ON Publication.MepsLanguageId = meps.LocalizedLanguageName.TargetLanguageId
      INNER JOIN  meps.LanguageName ON meps.LocalizedLanguageName.LanguageNameId = meps.LanguageName.LanguageNameId
      INNER JOIN meps.Language AS mepsLang ON mepsLang.LanguageId = meps.LocalizedLanguageName.TargetLanguageId
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
        arguments = [JwLifeSettings().currentLanguage.id];
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
      printTime('Database meps detached');

      // Affichage des résultats récupérés
      printTime('languagesAvailable: $languagesAvailable');

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
      printTime('Catalog file does not exist.');
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
                padding: EdgeInsets.zero,
                itemCount: combinedLanguages.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor, height: 1),
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
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            'Autres langues',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      _buildLanguageItem(context, languageData, dividerColor),
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

  // Variable pour suivre quelle langue est en cours de téléchargement
  Publication? _publication;

  Widget _buildLanguageItem(BuildContext context, Map<String, dynamic> languageData, Color dividerColor) {
    final String languageSymbol = languageData['LanguageSymbol'];
    final String keySymbol = languageData['KeySymbol'];
    final int issueTagNumber = languageData['IssueTagNumber'] ?? 0;

    return InkWell(
      onTap: () async {
        setState(() {
          selectedLanguage = languageSymbol;
          selectedSymbol = keySymbol;
          selectedIssueTagNumber = issueTagNumber;
        });

        Publication? publication = PublicationRepository().getAllPublications().firstWhereOrNull((p) =>
        p.mepsLanguage.symbol == languageSymbol &&
            p.keySymbol == keySymbol &&
            p.issueTagNumber == issueTagNumber);

        publication ??= await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);

        if (publication != null) {
          setState(() {
            _publication = publication;
          });

          if (publication.isDownloadedNotifier.value == false) {
            // Démarrer le téléchargement et rafraîchir l'UI

            try {
              await publication.download(context);
              Navigator.of(context).pop(publication);
            }
            catch (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur lors du téléchargement: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            finally {
              if (mounted) {
                setState(() {
                  _publication = null;
                });
              }
            }
          }
          else {
            Navigator.of(context).pop(publication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 5, top: 5, bottom: 5),
        child: Stack(
          children: [
            // Contenu principal (Row avec Radio + Textes)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio(
                  value: languageSymbol,
                  activeColor: Theme.of(context).primaryColor,
                  groupValue: widget.publication == null ? '${selectedLanguage}_${selectedSymbol}_$selectedIssueTagNumber' : selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = languageSymbol;
                      selectedSymbol = languageData['KeySymbol'];
                      selectedIssueTagNumber = languageData['IssueTagNumber'];
                    });
                  },
                ),
                SizedBox(width: 20),
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
                      if(widget.publication == null)
                        SizedBox(height: 2),
                      if(widget.publication == null)
                        Text(
                          '${languageData['Year']} - ${languageData['KeySymbol']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFa0a0a0)
                                : const Color(0xFFa0a0a0),
                          ),
                        ),

                    ],
                  ),
                ),
                SizedBox(width: 35), // pour laisser la place au bouton
              ],
            ),

            // PopupMenuButton (positionné à droite)
            Positioned(
              right: 0,
              top: 0,
              child: PopupMenuButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Color(0xFF9d9d9d),
                ),
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      onTap: () async {
                        Publication? publication = await PubCatalog.searchPub(widget.publication!.keySymbol, widget.publication!.issueTagNumber, languageSymbol);

                        if (publication != null && publication.isDownloadedNotifier.value == false) {
                          setState(() {
                            selectedLanguage = languageSymbol;
                            _publication = publication;
                          });

                          try {
                            await publication.download(context);
                          }
                          catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors du téléchargement: $error'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          finally {
                            setState(() {
                              _publication = null;
                            });
                          }
                        }
                      },
                      child: Text('Télécharger'),
                    ),
                  ];
                },
              ),
            ),


            // ProgressBar (positionné en bas à gauche, sous les textes)
            if (_publication != null && _publication?.mepsLanguage.symbol == languageSymbol && _publication?.keySymbol == keySymbol && _publication?.issueTagNumber == issueTagNumber)
              Positioned(
                left: 65, // pour laisser de l’espace au Radio
                right: 35, // pour éviter d’écraser le menu
                bottom: 0,
                child: _buildProgressBar(context),
              ),
          ],
        ),
      )

    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ValueListenableBuilder<double>(
        valueListenable: _publication!.progressNotifier,
        builder: (context, progress, child) {
          return LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
            minHeight: 3,
          );
        },
      ),
    );
  }
}