import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/jworg_uri.dart';
import '../../core/utils/utils.dart';
import '../../data/databases/history.dart';

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
  List<Map<String, dynamic>> _allLanguagesList = [];
  List<Map<String, dynamic>> _filteredLanguagesList = [];
  List<Map<String, dynamic>> _recommendedLanguages = [];
  Database? database;
  Timer? _debounce;

  // Stocke la liste des IDs MEPS des langues recommandées pour un accès rapide
  Set<int> _recommendedLanguageMepsIds = {};

  @override
  void initState() {
    super.initState();
    // Initialisation de l'état sélectionné
    selectedLanguage = widget.publication?.mepsLanguage.symbol;
    selectedSymbol = widget.publication?.keySymbol;
    selectedIssueTagNumber = widget.publication?.issueTagNumber;

    if(selectedLanguage == null && selectedSymbol == null && selectedIssueTagNumber == null) {
      Publication? bible = PublicationRepository().getLookUpBible();
      if(bible != null) {
        selectedLanguage = bible.mepsLanguage.symbol;
        selectedSymbol = bible.keySymbol;
        selectedIssueTagNumber = bible.issueTagNumber;
      }
    }

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
    File catalogFile = await getCatalogDatabaseFile();

    if (await catalogFile.exists()) {
      try {
        database = await openDatabase(catalogFile.path);
        await _fetchAllPubLanguages();
      } finally {
        await database?.close();
      }
    }
  }

  Future<void> _fetchAllPubLanguages() async {
    File mepsUnitFile = await getMepsUnitDatabaseFile();

    await database!.execute('ATTACH DATABASE ? AS meps', [mepsUnitFile.path]);
    printTime('Database meps attached');

    List<dynamic> arguments = [];
    String baseQuery;
    int sourceLanguageId = widget.publication?.mepsLanguage.id ?? JwLifeSettings().currentLanguage.id;

    if (widget.publication != null) {
      if (widget.publication!.issueTagNumber == 0) {
        baseQuery = '''
          SELECT 
            Publication.*,
            mepsLang.Symbol as LanguageSymbol,
            COALESCE(meps.LanguageName.Name, mepsLangFallback.Name) AS LanguageName,
            mepsLang.VernacularName
          FROM 
            Publication
          JOIN 
            meps.Language AS mepsLang ON Publication.MepsLanguageId = mepsLang.LanguageId
          LEFT JOIN 
            meps.LocalizedLanguageName AS lln_src ON mepsLang.LanguageId = lln_src.TargetLanguageId AND lln_src.SourceLanguageId = ?
          LEFT JOIN 
            meps.LanguageName ON lln_src.LanguageNameId = meps.LanguageName.LanguageNameId
          LEFT JOIN 
            meps.LocalizedLanguageName AS lln_fallback ON mepsLang.LanguageId = lln_fallback.TargetLanguageId AND lln_fallback.SourceLanguageId = mepsLang.PrimaryFallbackLanguageId
          LEFT JOIN 
            meps.LanguageName AS mepsLangFallback ON lln_fallback.LanguageNameId = mepsLangFallback.LanguageNameId
          WHERE 
            Publication.KeySymbol = ?
          ORDER BY 
            LanguageName COLLATE NOCASE
        ''';
        arguments = [sourceLanguageId, widget.publication!.keySymbol];
      }
      else {
        baseQuery = '''
          SELECT 
            Publication.*,
            mepsLang.Symbol as LanguageSymbol,
            COALESCE(meps.LanguageName.Name, mepsLangFallback.Name) AS LanguageName,
            mepsLang.VernacularName
          FROM 
            Publication
          JOIN 
            meps.Language AS mepsLang ON Publication.MepsLanguageId = mepsLang.LanguageId
          LEFT JOIN 
            meps.LocalizedLanguageName AS lln_src ON mepsLang.LanguageId = lln_src.TargetLanguageId AND lln_src.SourceLanguageId = ?
          LEFT JOIN 
            meps.LanguageName ON lln_src.LanguageNameId = meps.LanguageName.LanguageNameId
          LEFT JOIN 
            meps.LocalizedLanguageName AS lln_fallback ON mepsLang.LanguageId = lln_fallback.TargetLanguageId AND lln_fallback.SourceLanguageId = mepsLang.PrimaryFallbackLanguageId
          LEFT JOIN 
            meps.LanguageName AS mepsLangFallback ON lln_fallback.LanguageNameId = mepsLangFallback.LanguageNameId
          WHERE 
            Publication.KeySymbol = ? 
            AND Publication.IssueTagNumber = ?
          ORDER BY 
            LanguageName COLLATE NOCASE
        ''';
        arguments = [sourceLanguageId, widget.publication!.keySymbol, widget.publication!.issueTagNumber];
      }
    }
    else {
      baseQuery = '''
        SELECT 
          Publication.*,
          mepsLang.Symbol as LanguageSymbol,
          COALESCE(meps.LanguageName.Name, mepsLangFallback.Name) AS LanguageName,
          mepsLang.VernacularName
        FROM 
          Publication
        JOIN 
          meps.Language AS mepsLang ON Publication.MepsLanguageId = mepsLang.LanguageId
        LEFT JOIN 
          meps.LocalizedLanguageName AS lln_src ON mepsLang.LanguageId = lln_src.TargetLanguageId AND lln_src.SourceLanguageId = ?
        LEFT JOIN 
          meps.LanguageName ON lln_src.LanguageNameId = meps.LanguageName.LanguageNameId
        LEFT JOIN 
          meps.LocalizedLanguageName AS lln_fallback ON mepsLang.LanguageId = lln_fallback.TargetLanguageId AND lln_fallback.SourceLanguageId = mepsLang.PrimaryFallbackLanguageId
        LEFT JOIN 
          meps.LanguageName AS mepsLangFallback ON lln_fallback.LanguageNameId = mepsLangFallback.LanguageNameId
        WHERE 
          Publication.PublicationTypeId = 1
        ORDER BY 
          LanguageName COLLATE NOCASE
      ''';
      arguments = [sourceLanguageId];
    }

    List<Map<String, dynamic>> response = await database!.rawQuery(baseQuery, arguments);
    await database!.execute('DETACH DATABASE meps');

    List<Map<String, dynamic>> languagesModifiable = List.from(response);

    List<Map<String, dynamic>> mostUsedLanguages = await getUpdatedMostUsedLanguages(selectedLanguage!, languagesModifiable);

    _recommendedLanguages = languagesModifiable.where((lang) {
      return isRecommended(lang, mostUsedLanguages);
    }).toList();

    _recommendedLanguageMepsIds = _recommendedLanguages.map((l) => l['MepsLanguageId'] as int).toSet();

    setState(() {
      _allLanguagesList = languagesModifiable;
      _applySearchAndSort();
    });
  }

  Future<List<Map<String, dynamic>>> getUpdatedMostUsedLanguages(String selectedLanguageSymbol, List<Map<String, dynamic>> allLanguagesList) async {
    List<Map<String, dynamic>> mostUsedLanguages = await History.getMostUsedLanguages();
    List<Map<String, dynamic>> mostUsedLanguagesList = List.from(mostUsedLanguages);

    final selectedLang = allLanguagesList.firstWhere(
          (lang) => lang['LanguageSymbol'] == selectedLanguageSymbol,
      orElse: () => {},
    );

    if (selectedLang.isEmpty) {
      return mostUsedLanguagesList;
    }

    final alreadyInList = mostUsedLanguagesList.any(
          (lang) => lang['MepsLanguageId'] == selectedLang['MepsLanguageId'],
    );

    if (!alreadyInList && mostUsedLanguagesList.length >= 5) {
      mostUsedLanguagesList.sort((a, b) {
        return (a['Occurrences'] as int).compareTo(b['Occurrences'] as int);
      });

      mostUsedLanguagesList.removeAt(0);
    }

    if (!alreadyInList) {
      mostUsedLanguagesList.add({
        'MepsLanguageId': selectedLang['MepsLanguageId'],
        'Occurrences': 0,
      });
    }

    mostUsedLanguagesList.sort((a, b) {
      return (b['Occurrences'] as int).compareTo(a['Occurrences'] as int);
    });

    return mostUsedLanguagesList;
  }

  bool isRecommended(Map<String, dynamic> language, List<Map<String, dynamic>> mostUsedLanguages) {
    return language['LanguageSymbol'] == selectedLanguage ||
        mostUsedLanguages.any(
              (lang) => lang['MepsLanguageId'] == language['MepsLanguageId'],
        );
  }

  void _applySearchAndSort() {
    String searchTerm = _searchController.text.toLowerCase();

    final filtered = _allLanguagesList.where((lang) {
      final name = lang['LanguageName']?.toString().toLowerCase() ?? '';
      final vernacularName = lang['VernacularName']?.toString().toLowerCase() ?? '';
      return name.contains(searchTerm) || vernacularName.contains(searchTerm);
    }).toList();

    filtered.sort((a, b) {
      final aIsRecommended = _recommendedLanguageMepsIds.contains(a['MepsLanguageId']);
      final bIsRecommended = _recommendedLanguageMepsIds.contains(b['MepsLanguageId']);

      // 1. Priorité aux langues Recommandées
      if (aIsRecommended && !bIsRecommended) return -1;
      if (!aIsRecommended && bIsRecommended) return 1;

      // 2. Tri alphabétique par 'LanguageName' (traduit)
      final aName = a['LanguageName']?.toString() ?? '';
      final bName = b['LanguageName']?.toString() ?? '';
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
        _applySearchAndSort();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color dividerColor = isDarkMode ? Colors.black : const Color(0xFFf0f0f0);
    final Color hintColor = isDarkMode ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final totalFilteredCount = _filteredLanguagesList.length;

    final combinedLanguages = _filteredLanguagesList.map((language) {
      return {
        ...language,
        'isRecommended': _recommendedLanguageMepsIds.contains(language['MepsLanguageId']),
      };
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Titre principal
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                'Langues',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).secondaryHeaderColor,
                  fontSize: 20,
                ),
              ),
            ),

            Divider(color: dividerColor),

            // Barre de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextField(
                controller: _searchController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Rechercher une langue ($totalFilteredCount)',
                  hintStyle: TextStyle(color: hintColor),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Corps de la boîte de dialogue : une seule liste triée
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: combinedLanguages.length,
                separatorBuilder: (context, index) => Divider(color: dividerColor, height: 0),
                itemBuilder: (BuildContext context, int index) {
                  final languageData = combinedLanguages[index];
                  final isRecommended = languageData['isRecommended'] as bool;

                  // Logique pour afficher les en-têtes de section
                  // Le premier élément recommandé ou le premier tout court obtient le header "Recommandé"
                  bool showRecommendedHeader = isRecommended && (index == 0 || !combinedLanguages[index - 1]['isRecommended']);

                  // Le premier élément non-recommandé obtient le header "Autres langues"
                  bool showOtherLanguagesHeader = !isRecommended && (index == 0 || combinedLanguages[index - 1]['isRecommended'] as bool);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showRecommendedHeader)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 5, top: 5),
                          child: Text(
                            'Recommandé',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (showOtherLanguagesHeader)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 8, top: 10),
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

            // Bouton de fermeture
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text(
                  'TERMINER',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onPressed: () => Navigator.pop(context, null),
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

    // Clé unique pour l'état sélectionné (pour le Radio)
    final String uniquePubKey = '$languageSymbol\_$keySymbol\_$issueTagNumber';
    final String selectedKey = '$selectedLanguage\_$selectedSymbol\_$selectedIssueTagNumber';

    Publication? publication = PublicationRepository().getAllPublications().firstWhereOrNull((p) => p.mepsLanguage.symbol == languageSymbol && p.keySymbol == keySymbol && p.issueTagNumber == issueTagNumber);

    // Détermine si le téléchargement est en cours pour CET élément
    final bool isDownloading = _publication != null &&
        _publication?.mepsLanguage.symbol == languageSymbol &&
        _publication?.keySymbol == keySymbol &&
        _publication?.issueTagNumber == issueTagNumber;

    return InkWell(
        onTap: () async {
          setState(() {
            selectedLanguage = languageSymbol;
            selectedSymbol = keySymbol;
            selectedIssueTagNumber = issueTagNumber;
          });

          publication ??= await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);
          await _handlePublicationSelection(context, publication);
        },
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 5, top: 5, bottom: 5),
          child: Stack(
            children: [
              // Contenu principal (Row avec Radio + Textes)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Radio<String>( // Spécifie le type pour le Radio
                    value: uniquePubKey,
                    activeColor: Theme.of(context).primaryColor,
                    groupValue: selectedKey,
                    onChanged: (value) async {
                      if (value != null) {
                        final parts = value.split('_');
                        final langSym = parts[0];
                        final kSym = parts[1];
                        final issueTag = int.tryParse(parts[2]) ?? 0;

                        setState(() {
                          selectedLanguage = langSym;
                          selectedSymbol = kSym;
                          selectedIssueTagNumber = issueTag;
                        });

                        Publication? publication = PublicationRepository().getAllPublications().firstWhereOrNull((p) => p.mepsLanguage.symbol == langSym && p.keySymbol == kSym && p.issueTagNumber == issueTag);
                        publication ??= await PubCatalog.searchPub(kSym, issueTag, langSym);
                        _handlePublicationSelection(context, publication);
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageData['LanguageName'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          languageData['ShortTitle'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc3c3c3)
                                : const Color(0xFF626262),
                          ),
                        ),
                        if(widget.publication == null)
                          const SizedBox(height: 2),
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
                  const SizedBox(width: 35), // pour laisser la place au bouton
                ],
              ),

              // PopupMenuButton (positionné à droite)
              Positioned(
                right: 0,
                top: 0,
                child: PopupMenuButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Color(0xFF9d9d9d),
                  ),
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        onTap: () async {
                          Publication? publication = await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);

                          if(publication == null) return;
                          publication.shareLink();
                        },
                        child: Row(
                          children: [
                            Icon(JwIcons.share),
                            SizedBox(width: 8),
                            Text('Envoyer le lien'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () async {
                          publication ??= await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);

                          if(publication != null) {
                            if(publication!.isDownloadedNotifier.value) {
                              await publication!.remove(context);
                            }
                            else {
                              setState(() {
                                _publication = publication;
                              });

                              await publication!.download(context);
                            }

                            if (mounted) {
                              setState(() {
                                _publication = null;
                              });
                            }
                          }
                        },
                        child: Row(
                          children: [
                            publication != null && publication?.isDownloadedNotifier.value == true ? Icon(JwIcons.trash) : Icon(JwIcons.cloud_arrow_down),
                            SizedBox(width: 8),
                            publication != null && publication?.isDownloadedNotifier.value == true ? Text('Supprimer') : Text('Télécharger'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ),

              // PopupMenuButton (positionné à droite)
              if(publication == null || publication?.isDownloadedNotifier.value == false)
                Positioned(
                  right: 30,
                  top: 0,
                  child: IconButton(
                    icon: Icon(
                      isDownloading ? JwIcons.x : JwIcons.cloud_arrow_down,
                      color: const Color(0xFF9d9d9d),
                    ),
                    onPressed: () async {
                      if(isDownloading) {
                        if(_publication != null) {
                          _publication!.cancelDownload(context);
                          setState(() {
                            _publication = null;
                          });
                        }
                      }
                      else {
                        setState(() {
                          selectedLanguage = languageSymbol;
                          selectedSymbol = keySymbol;
                          selectedIssueTagNumber = issueTagNumber;
                        });

                        publication ??= await PubCatalog.searchPub(keySymbol, issueTagNumber, languageSymbol);
                        await _handlePublicationSelection(context, publication);
                      }
                    }
                  ),
                ),

              // ProgressBar (positionné en bas à gauche, sous les textes)
              if (isDownloading)
                Positioned(
                  left: 65,
                  right: 35,
                  bottom: 0,
                  child: _buildProgressBar(context),
                ),
            ],
          ),
        )

    );
  }

  Future<void> _handlePublicationSelection(BuildContext context, Publication? publication) async {
    if (publication != null) {
      if (publication.isDownloadedNotifier.value == false) {
        setState(() {
          _publication = publication;
        });

        try {
          // Capture le résultat: true si succès, false si annulé/échec
          bool success = await publication.download(context);

          // Ferme la fenêtre SEULEMENT si le téléchargement a réussi
          if (success) {
            Navigator.of(context).pop(publication);
          }
          // Si 'success' est false (annulation ou autre), on ne fait rien
        }
        catch (error) {
          // Attrape les vraies erreurs (exceptions levées par le code)
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
        // Publication déjà téléchargée
        Navigator.of(context).pop(publication);
      }
    }
  }

  Widget _buildProgressBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ValueListenableBuilder<double>(
        valueListenable: _publication!.progressNotifier,
        builder: (context, progress, child) {
          final isIndeterminate = progress == -1;

          return LinearProgressIndicator(
            value: isIndeterminate ? null : progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
            minHeight: 2,
          );
        },
      ),
    );
  }
}