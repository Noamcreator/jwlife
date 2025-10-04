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

  // NOUVEAU: Liste complète de toutes les langues chargées depuis la BD
  List<Map<String, dynamic>> _allLanguagesList = [];

  // Liste filtrée pour l'affichage (non favorites)
  List<Map<String, dynamic>> filteredLanguagesList = [];

  // Liste filtrée pour l'affichage (favorites)
  List<Map<String, dynamic>> favoriteLanguages = [];

  Database? database;

  @override
  void initState() {
    super.initState();
    initSettings();
    _searchController.addListener(_filterLanguages); // CHANGEMENT: Appelle _filterLanguages
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterLanguages); // CHANGEMENT
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
      // CHANGEMENT: On charge toutes les langues une seule fois
      await _loadAllLanguages();
      // Puis on applique le filtre initial (qui sera vide)
      _filterLanguages();
    }
  }

  // CHANGEMENT: Renommé et modifié pour charger TOUTES les langues (sans terme de recherche)
  Future<void> _loadAllLanguages() async {
    if (database == null) return;

    File mepsUnitFile = await getMepsUnitDatabaseFile();

    Database db = database!;
    await db.execute('ATTACH DATABASE ? AS meps', [mepsUnitFile.path]);
    printTime('Database meps attached');

    List<Map<String, dynamic>> languagesAvailable = [];
    List<dynamic> arguments = [];

    // La condition de recherche SQL est supprimée ici pour charger toutes les données
    String baseQuery;

    if (widget.publication != null) {
      if (widget.publication!.issueTagNumber == 0) {
        baseQuery = '''
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
            Publication.KeySymbol = ? AND meps.LocalizedLanguageName.SourceLanguageId = ?
          ORDER BY 
            meps.LanguageName.Name
        ''';
        arguments = [widget.publication!.keySymbol, widget.publication!.mepsLanguage.id];
      }
      else {
        baseQuery = '''
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
          ORDER BY 
            meps.LanguageName.Name
        ''';
        arguments = [widget.publication!.keySymbol, widget.publication!.issueTagNumber, widget.publication!.mepsLanguage.id];
      }
    }
    else {
      baseQuery = '''
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
        ORDER BY 
          meps.LanguageName.Name
      ''';
      arguments = [JwLifeSettings().currentLanguage.id];
    }

    languagesAvailable = await db.rawQuery(baseQuery, arguments);

    await db.execute('DETACH DATABASE meps');
    printTime('Database meps detached');
    printTime('languagesAvailable loaded: ${languagesAvailable.length} items');

    // NOUVEAU: Stocker le résultat dans _allLanguagesList
    _allLanguagesList = languagesAvailable;
  }

  bool isFavorite(Map<String, dynamic> language) {
    // La logique de favori doit être plus robuste si elle est basée sur plus qu'un simple exemple.
    // Pour l'instant, on garde l'exemple, mais on pourrait vouloir stocker une liste d'IDs/Symboles favoris.
    return language['LanguageSymbol'] == selectedLanguage;
  }

  // CHANGEMENT: Nouvelle méthode pour filtrer les résultats en mémoire
  void _filterLanguages() {
    final searchTerm = _searchController.text.toLowerCase();

    // 1. Filtrer la liste complète en mémoire
    final List<Map<String, dynamic>> results = _allLanguagesList.where((lang) {
      if (searchTerm.isEmpty) return true;

      final languageName = lang['LanguageName']?.toLowerCase() ?? '';
      final title = lang['Title']?.toLowerCase() ?? '';
      final shortTitle = lang['ShortTitle']?.toLowerCase() ?? '';

      return languageName.contains(searchTerm) ||
          title.contains(searchTerm) ||
          shortTitle.contains(searchTerm);
    }).toList();

    // 2. Mettre à jour les listes d'affichage
    setState(() {
      favoriteLanguages = results.where((lang) {
        return isFavorite(lang);
      }).toList();

      // La liste filtrée exclut les favoris
      filteredLanguagesList = results.where((lang) => !isFavorite(lang)).toList();
    });
  }

  // ... (Reste de la classe _LanguagesPubDialogState) ...
  // La méthode `build` reste inchangée, sauf le `hintText`

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Accès au thème pour éviter les erreurs de constantes
    final Color dividerColor = isDarkMode ? Colors.black : const Color(0xFFf0f0f0);

    // NOUVEAU: Compte total des éléments affichés (filtrés)
    final totalFilteredCount = favoriteLanguages.length + filteredLanguagesList.length;

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
                  // CHANGEMENT: Afficher le nombre total filtré/affiché
                  hintText: 'Rechercher une langue ($totalFilteredCount)',
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
                      // La logique d'affichage des titres "Favoris" et "Autres langues" est conservée
                      if (isFavorite && index == 0)
                        Padding(
                          padding: EdgeInsets.only(left: 20, bottom: 8, top: 8), // Ajustement du padding
                          child: Text(
                            'Favoris',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Afficher "Autres langues" juste avant le premier élément non favori
                      if (!isFavorite && index == favoriteLanguages.length && favoriteLanguages.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(left: 20, top: 8, bottom: 8), // Ajustement du padding
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

  // ... (Le reste des méthodes _buildLanguageItem et _buildProgressBar est inchangé)

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
                          // Pour des raisons d'asynchronisme avec le menu, on exécute la logique de téléchargement
                          // *après* la fermeture du menu si on utilise `onTap` sur le `PopupMenuItem`.
                          // Le `Future.delayed` est une astuce courante pour s'assurer que le menu se ferme avant
                          // de lancer une action potentiellement longue ou qui navigue.
                          Future.delayed(Duration.zero, () async {
                            Publication? publication = await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);

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
                                if (mounted) {
                                  setState(() {
                                    _publication = null;
                                  });
                                }
                              }
                            }
                          });
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