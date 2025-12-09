import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../../data/databases/history.dart';
import '../../i18n/i18n.dart';

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
        await _fetchAllPubLanguages();
      }
      catch (e) {
        printTime('Error initSettings: $e');
      }
    }
  }

  Future<void> _fetchAllPubLanguages() async {
    Database? database = CatalogDb.instance.database;

    File mepsUnitFile = await getMepsUnitDatabaseFile();

    await database.execute('ATTACH DATABASE ? AS meps', [mepsUnitFile.path]);

    // PrimaryIetfCode de la langue source
    String sourceLanguageLocale = JwLifeSettings.instance.locale.languageCode;

    List<dynamic> arguments = [];
    String baseQuery;

    // ==========================================================
    // CAS 1 : Publication avec issueTagNumber == 0
    // ==========================================================
    if (widget.publication != null && widget.publication!.issueTagNumber == 0) {
      baseQuery = '''
      SELECT 
        Publication.*,
        PublicationAsset.ExpandedSize,
        mepsLang.Symbol AS LanguageSymbol,
        COALESCE(translatedName.Name, mepsLang.EnglishName) AS LanguageName,
        mepsLang.VernacularName
      FROM Publication
      INNER JOIN PublicationAsset 
        ON Publication.Id = PublicationAsset.PublicationId  
      JOIN meps.Language AS mepsLang
        ON Publication.MepsLanguageId = mepsLang.LanguageId
      
      -- Langue source basée sur PrimaryIetfCode
      LEFT JOIN meps.Language AS sourceLang
        ON sourceLang.PrimaryIetfCode = ?
      
      -- Traduction du nom de la langue de Publication
      LEFT JOIN meps.LocalizedLanguageName AS lln
        ON lln.TargetLanguageId = mepsLang.LanguageId
        AND lln.SourceLanguageId = sourceLang.LanguageId
      
      LEFT JOIN meps.LanguageName AS translatedName
        ON translatedName.LanguageNameId = lln.LanguageNameId
      
      WHERE 
        Publication.KeySymbol = ?
      
      ORDER BY LanguageName COLLATE NOCASE
      ''';

      arguments = [
        sourceLanguageLocale,
        widget.publication!.keySymbol,
      ];
    }

    // ==========================================================
    // CAS 2 : Publication avec issueTagNumber != 0
    // ==========================================================
    else if (widget.publication != null && widget.publication!.issueTagNumber != 0) {
      baseQuery = '''
      SELECT 
        Publication.*,
        PublicationAsset.ExpandedSize,
        mepsLang.Symbol AS LanguageSymbol,
        COALESCE(translatedName.Name, mepsLang.EnglishName) AS LanguageName,
        mepsLang.VernacularName
      FROM Publication
      INNER JOIN PublicationAsset ON Publication.Id = PublicationAsset.PublicationId  
      JOIN meps.Language AS mepsLang ON Publication.MepsLanguageId = mepsLang.LanguageId
      
      LEFT JOIN meps.Language AS sourceLang
        ON sourceLang.PrimaryIetfCode = ?
      
      LEFT JOIN meps.LocalizedLanguageName AS lln
        ON lln.TargetLanguageId = mepsLang.LanguageId
        AND lln.SourceLanguageId = sourceLang.LanguageId
      
      LEFT JOIN meps.LanguageName AS translatedName
        ON translatedName.LanguageNameId = lln.LanguageNameId
      
      WHERE 
        Publication.KeySymbol = ?
        AND Publication.IssueTagNumber = ?
      
      ORDER BY LanguageName COLLATE NOCASE
      ''';

      arguments = [
        sourceLanguageLocale,
        widget.publication!.keySymbol,
        widget.publication!.issueTagNumber,
      ];
    }

    // ==========================================================
    // CAS 3 : Pas de publication → PublicationTypeId = 1
    // ==========================================================
    else {
      baseQuery = '''
      SELECT 
        Publication.*,
        PublicationAsset.ExpandedSize,
        mepsLang.Symbol AS LanguageSymbol,
        COALESCE(translatedName.Name, mepsLang.EnglishName) AS LanguageName,
        mepsLang.VernacularName
      FROM Publication
      INNER JOIN PublicationAsset 
        ON Publication.Id = PublicationAsset.PublicationId  
      JOIN meps.Language AS mepsLang
        ON Publication.MepsLanguageId = mepsLang.LanguageId
      
      LEFT JOIN meps.Language AS sourceLang
        ON sourceLang.PrimaryIetfCode = ?
      
      LEFT JOIN meps.LocalizedLanguageName AS lln
        ON lln.TargetLanguageId = mepsLang.LanguageId
        AND lln.SourceLanguageId = sourceLang.LanguageId
      
      LEFT JOIN meps.LanguageName AS translatedName
        ON translatedName.LanguageNameId = lln.LanguageNameId
      
      WHERE 
        Publication.PublicationTypeId = 1
      
      ORDER BY LanguageName COLLATE NOCASE
      ''';

      arguments = [
        sourceLanguageLocale,
      ];
    }

    // ==========================================================
    // EXECUTION
    // ==========================================================

    List<Map<String, dynamic>> response =
    await database.rawQuery(baseQuery, arguments);

    await database.execute('DETACH DATABASE meps');

    List<Map<String, dynamic>> languagesModifiable = List.from(response);

    if(widget.publication != null) {
      Database mepsDb = await openReadOnlyDatabase(mepsUnitFile.path);
      for(Publication pub in PublicationRepository().getAllDownloadedPublications()) {
        if(widget.publication!.keySymbol == pub.keySymbol && widget.publication!.issueTagNumber == pub.issueTagNumber) {
          if(!languagesModifiable.any((l) => l['MepsLanguageId'] == pub.mepsLanguage.id)) {
            languagesModifiable.add({
              'LanguageSymbol': pub.mepsLanguage.symbol,
              'LanguageName': pub.mepsLanguage.vernacular,
              'VernacularName': pub.mepsLanguage.vernacular,
              'KeySymbol': pub.keySymbol,
              'IssueTagNumber': pub.issueTagNumber,
              'MepsLanguageId': pub.mepsLanguage.id,
              'IssueTitle': pub.issueTitle.isEmpty ? null : pub.issueTitle,
              'ShortTitle': pub.shortTitle,
              'Title': pub.title
            });
          }
        }
      }

      await mepsDb.close();
    }

    List<Map<String, dynamic>> mostUsedLanguages =
    await getUpdatedMostUsedLanguages(selectedLanguage, languagesModifiable);

    _recommendedLanguages = languagesModifiable.where((lang) {
      return isRecommended(lang, mostUsedLanguages);
    }).toList();

    _recommendedLanguageMepsIds =
        _recommendedLanguages.map((l) => l['MepsLanguageId'] as int).toSet();

    setState(() {
      _allLanguagesList = languagesModifiable;
      _applySearchAndSort();
    });
  }

  Future<List<Map<String, dynamic>>> getUpdatedMostUsedLanguages(String? selectedLanguageSymbol, List<Map<String, dynamic>> allLanguagesList) async {
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
    String searchTerm = normalize(_searchController.text);

    final filtered = _allLanguagesList.where((lang) {
      final name = normalize(lang['LanguageName']?.toString() ?? '');
      final vernacularName = normalize(lang['VernacularName']?.toString().toLowerCase() ?? '');
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Titre principal
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                i18n().action_languages,
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
                          padding: const EdgeInsets.only(left: 25, bottom: 5, top: 5),
                          child: Text(
                            i18n().label_languages_recommended,
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
                  i18n().action_done_uppercase,
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

          publication ??= await CatalogDb.instance.searchPub(keySymbol, issueTagNumber, languageSymbol);
          await _handlePublicationSelection(context, publication);
        },
        child: Container(
          color: languageSymbol == selectedLanguage && keySymbol == selectedSymbol && issueTagNumber == selectedIssueTagNumber ? Theme.of(context).brightness == Brightness.dark ? const Color(0xFF626262) : const Color(0xFFf0f0f0) : null,
          padding: const EdgeInsets.only(left: 40, right: 5, top: 5, bottom: 5),
          child: Stack(
            children: [
              // Contenu principal (Row avec Radio + Textes)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if(languageSymbol == selectedLanguage && keySymbol == selectedSymbol && issueTagNumber == selectedIssueTagNumber)
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
                        Text(
                          languageData['LanguageName'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          languageData['IssueTitle'] ?? languageData['ShortTitle'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc3c3c3)
                                : const Color(0xFF626262),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  const SizedBox(width: 40), // pour laisser la place au bouton
                ],
              ),

              // PopupMenuButton (positionné à droite)
              if(publication?.isDownloadedNotifier.value == true)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: PopupMenuButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Color(0xFF9d9d9d),
                    ),
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          onTap: () async {
                            Publication? publication = await CatalogDb.instance.searchPub(keySymbol, issueTagNumber, languageSymbol);

                            if(publication == null) return;
                            publication.shareLink();
                          },
                          child: Row(
                            children: [
                              Icon(JwIcons.share),
                              SizedBox(width: 8),
                              Text(i18n().action_open_in_share),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () async {
                            publication ??= await CatalogDb.instance.searchPub(keySymbol, issueTagNumber, languageSymbol);

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
                              publication != null && publication?.isDownloadedNotifier.value == true ? Text(i18n().action_delete) : Text(i18n().action_download),
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
                  right: 0,
                  top: widget.publication == null ? 0 : -5,
                  bottom: isDownloading ? 0 : null,
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

                        publication ??= await CatalogDb.instance.searchPub(keySymbol, issueTagNumber, languageSymbol);
                        await _handlePublicationSelection(context, publication);
                      }
                    }
                  ),
                ),

              // PopupMenuButton (positionné à droite)
              if((publication == null || publication?.isDownloadedNotifier.value == false) && languageData['ExpandedSize'] != null && !isDownloading)
                Positioned(
                  right: 5,
                  bottom: 0,
                  child: Text(
                      formatFileSize(languageData['ExpandedSize'] ?? 0),
                    style: TextStyle(
                      color: Color(0xFF9d9d9d),
                      fontSize: widget.publication == null ? 14 : 12
                    ),
                  ),
                ),

              // ProgressBar (positionné en bas à gauche, sous les textes)
              if (isDownloading)
                Positioned(
                  left: 10,
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