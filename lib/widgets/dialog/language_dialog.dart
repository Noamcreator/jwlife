import 'dart:io';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';
import 'package:sqflite/sqflite.dart';
import '../../app/services/settings_service.dart';
import '../../data/models/audio.dart';
import '../../data/models/video.dart';
import '../../i18n/i18n.dart';

class LanguageDialog extends StatefulWidget {
  final Map<String, dynamic> languagesListJson;
  final String? selectedLanguageSymbol;
  final Media? media;
  final String type;

  const LanguageDialog({
    super.key,
    this.languagesListJson = const {},
    this.selectedLanguageSymbol,
    this.media,
    this.type = 'library',
  });

  @override
  _LanguageDialogState createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  String? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allLanguagesList = [];
  List<Map<String, dynamic>> _filteredLanguagesList = [];
  List<Map<String, dynamic>> _recommendedLanguages = [
  ]; // Renommé de _favoriteLanguages
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
    selectedLanguage = widget.selectedLanguageSymbol ?? JwLifeSettings.instance.libraryLanguage.value.symbol;

    File mepsUnitFile = await getMepsUnitDatabaseFile();

    if (await mepsUnitFile.exists()) {
      try {
        database = await openReadOnlyDatabase(mepsUnitFile.path);
        await _fetchAllLanguages(selectedLanguage!);
      } finally {
        // La base de données est fermée après l'opération
        await database?.close();
      }
    }
  }

  Future<void> _fetchAllLanguages(String languageCode) async {
    // 1. Récupération des données depuis la base de données locale
    List<Map<String, dynamic>> responseSql = await database!.rawQuery('''
      SELECT 
          l.LanguageId,
          l.Symbol,
          COALESCE(NULLIF(l.VernacularName, ''), l.EnglishName) AS VernacularName,
          COALESCE(ln_src.Name, ln_fallback.Name, l.EnglishName) AS LocalizedName,
          -- Priorité : IETF -> ISO Alpha 2 -> ISO Alpha 3
          COALESCE(
              NULLIF(l.PrimaryIetfCode, ''), 
              NULLIF(l.IsoAlpha2Code, ''), 
              NULLIF(l.IsoAlpha3Code, '')
          ) AS PrimaryIetfCode,
          l.IsSignLanguage,
          s.InternalName AS ScriptInternalName,
          s.DisplayName AS ScriptDisplayName,
          s.IsBidirectional,
          s.IsRTL,
          s.IsCharacterSpaced,
          s.IsCharacterBreakable,
          s.HasSystemDigits
      FROM Language l
      INNER JOIN Script s ON l.ScriptId = s.ScriptId
      LEFT JOIN LocalizedLanguageName lln_src ON l.LanguageId = lln_src.TargetLanguageId 
          AND lln_src.SourceLanguageId = (SELECT LanguageId FROM Language WHERE PrimaryIetfCode = ?)
      LEFT JOIN LanguageName ln_src ON lln_src.LanguageNameId = ln_src.LanguageNameId
      LEFT JOIN LocalizedLanguageName lln_fallback ON l.LanguageId = lln_fallback.TargetLanguageId 
          AND lln_fallback.SourceLanguageId = l.PrimaryFallbackLanguageId
      LEFT JOIN LanguageName ln_fallback ON lln_fallback.LanguageNameId = ln_fallback.LanguageNameId
      WHERE 
          -- Doit avoir un nom (Vernaculaire ou Anglais)
          (NULLIF(l.VernacularName, '') IS NOT NULL OR NULLIF(l.EnglishName, '') IS NOT NULL)
          -- ET doit avoir au moins un des trois codes d'identification
          AND (
              NULLIF(l.PrimaryIetfCode, '') IS NOT NULL OR 
              NULLIF(l.IsoAlpha2Code, '') IS NOT NULL OR 
              NULLIF(l.IsoAlpha3Code, '') IS NOT NULL
          )
  ''', [JwLifeSettings.instance.locale.languageCode]);

    // On crée une liste modifiable
    List<Map<String, dynamic>> combinedLanguages = [];

    final Set<String> existingSymbols = responseSql.map((l) => l['Symbol'].toString()).toSet();

    if(widget.type != 'media' && widget.type != 'medias' && widget.type != 'article' && widget.type != 'workship') {
      List<Map<String, dynamic>> responseSqlCatalog = await CatalogDb.instance.database.rawQuery('''
        SELECT DISTINCT MepsLanguageId 
        FROM Publication;
      ''', []);

      final Set<int> existingIds = responseSqlCatalog.map((l) => l['MepsLanguageId'] as int).toSet();

      for (var language in responseSql.map((l) => l).toSet().toList()) {
        if(existingIds.contains(language['LanguageId'])) {
          combinedLanguages.add(language);
          existingSymbols.remove(language['Symbol']);
        }
      }
    }

    if(widget.type != 'publication' && widget.type != 'media' && widget.type != 'workship' && await hasInternetConnection()) {
      try {
        List<String> onlineSymbols = await Api.getAllLanguageSymbols();

        if (onlineSymbols.isNotEmpty) {
          for (var symbol in onlineSymbols) {
            if(existingSymbols.contains(symbol)) {
              var sqlLang = responseSql.firstWhereOrNull((l) => l['Symbol'] == symbol);

              if (sqlLang != null) {
                combinedLanguages.add(sqlLang);
              }
            }
          }
        }
      } 
      catch (e) {
        debugPrint('Erreur lors de la récupération des langues: $e');
      }
    }

    if(widget.type == 'workship') {
      List<Map<String, dynamic>> responseSqlCatalog = await CatalogDb.instance.database.rawQuery('''
        SELECT DISTINCT MepsLanguageId 
        FROM Publication
        WHERE KeySymbol = 'w'
          OR KeySymbol = 'mwb'
          OR KeySymbol LIKE '%CO-pgm%'
          OR KeySymbol LIKE '%CA-brpgm%'
          OR KeySymbol LIKE '%CA-copgm%';
      ''', []);

      final Set<int> existingIds = responseSqlCatalog.map((l) => l['MepsLanguageId'] as int).toSet();

      for (var language in responseSql.map((l) => l).toSet().toList()) {
        if(existingIds.contains(language['LanguageId'])) {
          combinedLanguages.add(language);
        }
      }
    }

    if(widget.type == 'media') {
      combinedLanguages.addAll(responseSql);
    }

    // 3. Filtrage final si widget.languagesListJson est défini
    if (widget.languagesListJson.isNotEmpty) {
      combinedLanguages = combinedLanguages
          .where((lang) => widget.languagesListJson.containsKey(lang['Symbol']))
          .map((lang) {
            var updatedLang = Map<String, dynamic>.from(lang);
            updatedLang['Title'] = widget.languagesListJson[lang['Symbol']]?['title'] ?? lang['LocalizedName'];
            return updatedLang;
          }).toList();
    }

    // 4. Tri alphabétique final (indispensable après la fusion)
    combinedLanguages.sort((a, b) {
      String nameA = (a['LocalizedName'] ?? '').toString().toLowerCase();
      String nameB = (b['LocalizedName'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    // 5. Mise à jour de l'interface
    List<Map<String, dynamic>> mostUsedLanguages = await getUpdatedMostUsedLanguages(selectedLanguage!, combinedLanguages);

    setState(() {
      _allLanguagesList = combinedLanguages;
      _recommendedLanguages = combinedLanguages.where((lang) {
        return isRecommended(lang, mostUsedLanguages);
      }).toList();
      
      _filteredLanguagesList = combinedLanguages;
      _applySearchFilter();
    });
  }

  Future<List<Map<String, dynamic>>> getUpdatedMostUsedLanguages(
      String selectedLanguageSymbol,
      List<Map<String, dynamic>> allLanguages) async {
    List<Map<String, dynamic>> mostUsedLanguages =
    await JwLifeApp.history.getMostUsedLanguages();
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
      List<Map<String, dynamic>> mostUsedLanguages,) {
    return language['Symbol'] == selectedLanguage ||
        mostUsedLanguages.any(
              (lang) => lang['MepsLanguageId'] == language['LanguageId'],
        );
  }

  void _applySearchFilter() {
    String searchTerm = normalize(_searchController.text);

    // 1. Filtrer la liste complète (_allLanguagesList)
    final filtered = _allLanguagesList.where((lang) {
      final name = normalize(lang['LocalizedName']?.toString() ?? '');
      final vernacularName = normalize(
          lang['VernacularName']?.toString() ?? '');
      return name.contains(searchTerm) || vernacularName.contains(searchTerm);
    }).toList();

    // 2. Déterminer les langues recommandées parmi les résultats filtrés
    final recommendedSymbols = _recommendedLanguages
        .map((l) => l['Symbol'])
        .toSet();

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
      final aName = a['LocalizedName']?.toString() ?? '';
      final bName = b['LocalizedName']?.toString() ?? '';
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
        'isRecommended': recommendedSymbols.contains(language['Symbol']),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
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
                  final translatedName = languageData['LocalizedName'] ?? '';
                  final title = languageData['Title'] ?? '';
                  final isRecommended = languageData['isRecommended'] as bool;

                  // Logique pour afficher les en-têtes de section
                  bool showRecommendedHeader = isRecommended && (index == 0 || !combinedLanguages[index - 1]['isRecommended']);

                  bool showOtherLanguagesHeader = !isRecommended && (index == 0 || combinedLanguages[index - 1]['isRecommended'] as bool);

                  Media? media;
                  if(widget.media != null) {
                    media = MediaRepository().getAllMedias().firstWhereOrNull((media) => media.naturalKey == widget.media!.naturalKey && media.mepsLanguage == lank);
                    media ??= widget.media is Video ? Video(
                      naturalKey: widget.media!.naturalKey,
                      mepsLanguage: lank,
                    ) : Audio(
                      naturalKey: widget.media!.naturalKey,
                      mepsLanguage: lank,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showRecommendedHeader)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 25, bottom: 8, top: 5),
                          child: Text(
                            i18n().label_languages_recommended, // Nouveau titre
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme
                                  .of(context)
                                  .secondaryHeaderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (showOtherLanguagesHeader)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 25, bottom: 8, top: 10),
                          child: Text(
                            i18n().label_languages_more,
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme
                                  .of(context)
                                  .secondaryHeaderColor,
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
                          padding: const EdgeInsetsDirectional.only(start: 40, end: 5, top: 5, bottom: 5),
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  if(selectedLanguage == languageData['Symbol'])
                                  // Montrer quelque chose qui indeic une sorte de bar
                                    Container(
                                      width: 3,
                                      height: 20,
                                      color: Theme
                                          .of(context)
                                          .primaryColor,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(translatedName,
                                            style: const TextStyle(
                                                fontSize: 16)),
                                        Text(
                                          title.isNotEmpty
                                              ? title
                                              : vernacularName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 40), // pour laisser la place au bouton
                                ],
                              ),

                              if(media != null)
                                ValueListenableBuilder(
                                    valueListenable: media.isDownloadingNotifier,
                                    builder: (context, isDownloading, _) {
                                      // --- 1. Mode Téléchargement en cours (Annuler) ---
                                      if (isDownloading) {
                                        return PositionedDirectional(
                                          bottom: -4,
                                          end: -8,
                                          height: 40,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            onPressed: () => media!.cancelDownload(context),
                                            icon: const Icon(
                                              JwIcons.x,
                                              color: Color(0xFF9d9d9d),
                                            ),
                                          ),
                                        );
                                      }

                                      return ValueListenableBuilder(
                                          valueListenable: media!.isDownloadedNotifier,
                                          builder: (context, isDownloaded, child) {
                                            if (!isDownloaded || media!.hasUpdate()) {
                                              return PositionedDirectional(
                                                end: 0,
                                                top: 0,
                                                bottom: 0,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () {
                                                    if (media!.hasUpdate()) {
                                                      //media.update(context);
                                                    }
                                                    else {
                                                      final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                                      final Offset tapPosition = renderBox.localToGlobal(Offset.zero) + renderBox.size.center(Offset.zero);

                                                      media.download(context, tapPosition: tapPosition);
                                                    }
                                                  },
                                                  icon: Icon(
                                                    media!.hasUpdate() ? JwIcons.arrows_circular : JwIcons.cloud_arrow_down,
                                                    size: media.hasUpdate() ? 20 : 24,
                                                    color: const Color(0xFF9d9d9d),
                                                  ),
                                                ),
                                              );
                                            }

                                            return ValueListenableBuilder<bool>(
                                              valueListenable: media.isFavoriteNotifier,
                                              builder: (context, isFavorite, _) {
                                                if (isFavorite) {
                                                  return PositionedDirectional(
                                                    end: 7,
                                                    top: 0,
                                                    bottom: 0,
                                                    child: Icon(
                                                      JwIcons.star, // Assurez-vous que JwIcons.star existe ou utilisez Icons.star
                                                      color: Color(0xFF9d9d9d),
                                                    ),
                                                  );
                                                } else {
                                                  return const SizedBox.shrink();
                                                }
                                              },
                                            );
                                          }
                                      );
                                    }
                                ),

                              if (media != null)
                                _buildProgressBar(media),
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
                    color: Theme
                        .of(context)
                        .primaryColor,
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

  // Extrait la logique de la barre de progression
  Widget _buildProgressBar(Media media) {
    return ValueListenableBuilder<bool>(
      valueListenable: media.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading
            ? PositionedDirectional(
          bottom: 0,
          end: 0,
          start: 10,
          height: 2,
          child: ValueListenableBuilder<double>(
            valueListenable: media.progressNotifier,
            builder: (context, progress, _) {
              return LinearProgressIndicator(
                value: progress == -1 ? null : progress,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                backgroundColor: const Color(0xFFbdbdbd),
                minHeight: 2,
              );
            },
          ),
        ) : const SizedBox.shrink();
      },
    );
  }
}