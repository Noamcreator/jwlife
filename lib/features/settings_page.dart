import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../app/jwlife_app.dart';
import '../app/services/settings_service.dart';
import '../core/utils/files_helper.dart';
import '../core/utils/utils.dart';
import '../core/utils/widgets_utils.dart';
import '../data/realm/catalog.dart';
import '../data/realm/realm_library.dart';
import '../data/databases/userdata.dart';
import '../widgets/settings_widget.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLanguage;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.changeLanguage,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _theme = JwLifeSettings().themeMode;
  Locale _selectedLocale = Locale('en');
  String _selectedLocaleVernacular = 'English';
  Color? _selectedColor = Colors.blue;
  MepsLanguage _selectedLanguage = JwLifeSettings().currentLanguage;

  final String appVersion = '1.0.0';
  String catalogDate = '';
  String libraryDate = '';
  String cacheSize = '';

  // vue web
  double _fontSize = 16;
  int _colorIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    String theme = await getTheme();
    ThemeMode themeMode = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
    String selectedLanguage = await getLocale();
    Color primaryColor = await getPrimaryColor(themeMode);

    double fontSize = await getFontSize();
    int colorIndex = await getLastHighlightColorIndex();

    _getVernacularName();

    setState(() {
      _theme = themeMode;
      _selectedLocale = Locale(selectedLanguage);
      _selectedColor = primaryColor;
      _fontSize = fontSize;
      _colorIndex = colorIndex;
      _getCatalogDate();
      _getLibraryDate();
      _loadCacheSize();
    });
  }

  Future<void> _loadCacheSize() async {
    Directory cacheDir = await getTemporaryDirectory();
    int sizeInBytes = await getDirectorySize(cacheDir);
    setState(() {
      cacheSize = formatBytes(sizeInBytes);
    });
  }

  Future<void> _getVernacularName() async {
    File mepsFile = await getMepsFile();
    Database database = await openDatabase(mepsFile.path);

    List<Map<String, dynamic>> result = await database.rawQuery('''
      SELECT VernacularName FROM Language
      WHERE PrimaryIetfCode = ?
    ''', [_selectedLocale.languageCode]);

    setState(() {
      _selectedLocaleVernacular = result.first['VernacularName'];
    });
  }

  Future<void> _getCatalogDate() async {
    String dateStr = await getCatalogDate();

    // Si vide ou nul, on arrête
    if (dateStr.isEmpty) return;

    // Parser la date HTTP
    DateTime parsedDate = DateTime.parse(dateStr);

    // Mettre à jour l'interface
    setState(() {
      catalogDate = _formatDate(parsedDate);
    });
  }

  Future<void> _getLibraryDate() async {
    final results = RealmLibrary.realm
        .all<Language>()
        .query("symbol == '${JwLifeSettings().currentLanguage.symbol}'");
    String? date = results.isNotEmpty ? results.first.lastModified : null;

    if (date == null || date.isEmpty) return;

    // Parse la date HTTP
    DateTime parsedDate = HttpDate.parse(date);

    setState(() {
      libraryDate = _formatDate(parsedDate);
    });
  }

// Corrigé pour prendre un DateTime au lieu d'une String
  String _formatDate(DateTime dateTime) {
    // Convertir en heure locale si nécessaire
    final localDate = dateTime.toLocal();
    return DateFormat(
      'EEEE d MMMM yyyy HH:mm:ss',
      JwLifeSettings().currentLanguage.primaryIetfCode,
    ).format(localDate);
  }

  Future<void> _updateTheme(ThemeMode theme) async {
    setState(() {
      _theme = theme;
    });
    widget.toggleTheme(theme);
  }

  Future<void> _updateLocale(Locale locale, String vernacular) async {
    setState(() {
      _selectedLocale = locale;
      _selectedLocaleVernacular = vernacular;
    });
    widget.changeLanguage(locale);
  }

  void showThemeSelectionDialog() {
    showJwDialog(
      context: context,
      title: Text(
        localization(context).settings_appearance,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      buttonAxisAlignment: MainAxisAlignment.end,
      content: Column(
        spacing: 0,
        mainAxisAlignment: MainAxisAlignment.start,
        children: ThemeMode.values.map((mode) {
          return RadioListTile<ThemeMode>(
            title: Text(getThemeLabel(mode)),
            value: mode,
            groupValue: _theme,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                _updateTheme(value);
                Navigator.of(context, rootNavigator: true).pop(); // Ferme uniquement la dialog
              }
            },
          );
        }).toList(),
      ),
      buttons: [
        JwDialogButton(
          label: localization(context).action_cancel.toUpperCase(),
        ),
      ],
    );
  }

  String getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return localization(context).settings_appearance_system;
      case ThemeMode.light:
        return localization(context).settings_appearance_light;
      case ThemeMode.dark:
        return localization(context).settings_appearance_dark;
    }
  }


  void showColorSelectionDialog() {
    Color tempColor = _selectedColor!;

    showJwDialog(
      context: context,
      title: Text(
        'Couleur Principale',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      buttonAxisAlignment: MainAxisAlignment.end,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (Color color) {
              tempColor = color;
            },
          ),
        ],
      ),
      buttons: [
        JwDialogButton(
          label: localization(context).action_cancel.toUpperCase(),
        ),
        JwDialogButton(
          label: localization(context).action_save.toUpperCase(),
          onPressed: (dialogContext) {
            Navigator.of(dialogContext).pop(); // Fermer seulement la boîte de dialogue
            setState(() {
              _selectedColor = tempColor;
            });
            JwLifeApp.togglePrimaryColor(_selectedColor!);
          },
        ),
      ],
    );
  }

  Future<void> showLanguageSelectionDialog() async {
    File mepsFile = await getMepsFile();
    Database database = await openDatabase(mepsFile.path);

    List<String> languageCodes = AppLocalizations.supportedLocales.map((locale) => locale.languageCode).toList();

    List<Map<String, dynamic>> languages = await database.rawQuery('''
    SELECT 
      Language.VernacularName,
      Language.PrimaryIetfCode,
      LanguageName.Name
    FROM Language
    JOIN LocalizedLanguageName ON LocalizedLanguageName.TargetLanguageId = Language.LanguageId
    JOIN LanguageName ON LocalizedLanguageName.LanguageNameId = LanguageName.LanguageNameId
    JOIN Language SourceL ON LocalizedLanguageName.SourceLanguageId = SourceL.LanguageId
    WHERE Language.PrimaryIetfCode IN (${languageCodes.map((code) => "'$code'").join(',')}) AND SourceL.PrimaryIetfCode = '${_selectedLocale.languageCode}';
  ''');

    await database.close();

    showJwDialog(
      context: context,
      title: Text(
        localization(context).settings_languages,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      buttonAxisAlignment: MainAxisAlignment.end,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((language) {
          String vernacularName = language['VernacularName'] ?? '';
          String name = language['Name'] ?? '';
          String languageCode = language['PrimaryIetfCode'] ?? '';
          Locale locale = Locale(languageCode);

          return RadioListTile<Locale>(
            title: Text(name),
            subtitle: Text(vernacularName),
            value: locale,
            groupValue: _selectedLocale,
            onChanged: (Locale? value) {
              if (value != null) {
                Navigator.of(context, rootNavigator: true).pop(); // Fermer uniquement la boîte de dialogue
                _updateLocale(value, vernacularName);
              }
            },
          );
        }).toList(),
      ),
      buttons: [
        JwDialogButton(
          label: localization(context).action_cancel.toUpperCase(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),

    );

    return Scaffold(
      appBar: AppBar(
        title: Text(localization(context).navigation_settings, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        children: [
          SettingsSectionHeader(localization(context).settings_appearance_display),
          SettingsTile(
            title: localization(context).settings_appearance,
            subtitle: _theme == ThemeMode.system
                ? localization(context).settings_appearance_system
                : _theme == ThemeMode.light
                ? localization(context).settings_appearance_light
                : localization(context).settings_appearance_dark,
            onTap: showThemeSelectionDialog,
          ),
          SettingsColorTile(
            title: 'Couleur Principale',
            color: Theme.of(context).primaryColor,
            onTap: showColorSelectionDialog,
          ),
          const Divider(),

          SettingsSectionHeader(localization(context).settings_languages),
          SettingsTile(
            title: localization(context).settings_language_app,
            subtitle: _selectedLocaleVernacular,
            onTap: showLanguageSelectionDialog,
          ),
          SettingsTile(
            title: localization(context).settings_language_library,
            subtitle: _selectedLanguage.vernacular,
            onTap: () {
              showLibraryLanguageDialog(context).then((value) async {
                if (value['Symbol'] != JwLifeSettings().currentLanguage.symbol) {
                  setState(() {
                    _selectedLanguage = MepsLanguage(
                      id: value['LanguageId'],
                      symbol: value['Symbol'],
                      vernacular: value['VernacularName'],
                      primaryIetfCode: value['PrimaryIetfCode'],
                    );
                  });
                  await setLibraryLanguage(value);
                  JwLifePage.getHomeGlobalKey().currentState?.changeLanguageAndRefresh();
                }
              });
            },
          ),
          const Divider(),

          SettingsSectionHeader(localization(context).settings_userdata),
          SettingsTile(
            title: localization(context).settings_userdata_import,
            trailing: const Icon(JwIcons.cloud_arrow_down),
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.any,
              );

              if (result != null) {
                PlatformFile file = result.files.first;
                final String filePath = file.path ?? '';

                // Vérifie l'extension
                final allowedExtensions = ['jwlife', 'jwlibrary'];
                final fileExtension = filePath.split('.').last.toLowerCase();

                if (!allowedExtensions.contains(fileExtension)) {
                  await showJwDialog(
                    context: context,
                    titleText: 'Fichier invalide',
                    contentText: 'Le fichier doit avoir une extension .jwlife ou .jwlibrary.',
                    buttons: [
                      JwDialogButton(
                        label: 'OK',
                        closeDialog: true,
                      ),
                    ],
                    buttonAxisAlignment: MainAxisAlignment.end,
                  );
                  return;
                }

                // Teste que c'est bien une archive ZIP valide
                bool isValidZip = false;
                try {
                  final bytes = File(filePath).readAsBytesSync();
                  ZipDecoder().decodeBytes(bytes);
                  isValidZip = true;
                } catch (_) {
                  isValidZip = false;
                }

                if (!isValidZip) {
                  await showJwDialog(
                    context: context,
                    titleText: 'Fichier invalide',
                    contentText: 'Le fichier sélectionné n’est pas une archive valide.',
                    buttons: [
                      JwDialogButton(
                        label: 'OK',
                        closeDialog: true,
                      ),
                    ],
                    buttonAxisAlignment: MainAxisAlignment.end,
                  );
                  return;
                }

                // Récupération des infos de sauvegarde
                final info = await getBackupInfo(File(filePath));
                if (info == null) {
                  await showJwDialog(
                    context: context,
                    titleText: 'Erreur',
                    contentText: 'Le fichier de sauvegarde est invalide ou corrompu. Veuillez choisir un autre fichier.',
                    buttons: [
                      JwDialogButton(
                        label: 'OK',
                        closeDialog: true,
                      ),
                    ],
                    buttonAxisAlignment: MainAxisAlignment.end,
                  );
                  return;
                }

                // Confirmation avant restauration
                final shouldRestore = await showJwDialog<bool>(
                  context: context,
                  titleText: 'Importer une sauvegarde',
                  content: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'Les données de votre étude individuelle sur cet appareil seront écrasées.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF676767),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Appareil : ${info.deviceName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text('Dernière modification : ${timeAgo(info.lastModified)}'),
                      ],
                    ),
                  ),
                  buttons: [
                    JwDialogButton(
                      label: 'ANNULER',
                      closeDialog: true,
                      result: false,
                    ),
                    JwDialogButton(
                      label: 'RESTAURER',
                      closeDialog: true,
                      result: true,
                    ),
                  ],
                  buttonAxisAlignment: MainAxisAlignment.end,
                );

                if (shouldRestore == true) {
                  BuildContext? dialogContext;

                  showJwDialog(
                    context: context,
                    titleText: 'Importation en cours…',
                    content: Builder(
                      builder: (ctx) {
                        dialogContext = ctx;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25),
                          child: SizedBox(
                            height: 50,
                            child: getLoadingWidget(Theme.of(context).primaryColor),
                          ),
                        );
                      },
                    ),
                  );

                  await JwLifeApp.userdata.importBackup(File(filePath));

                  await showJwDialog(
                    context: context,
                    titleText: 'Sauvegarde importée',
                    contentText: 'La sauvegarde a bien été importée.',
                    buttons: [
                      JwDialogButton(
                        label: 'OK',
                        closeDialog: true,
                      ),
                    ],
                    buttonAxisAlignment: MainAxisAlignment.end,
                  );

                  if (dialogContext != null) Navigator.of(dialogContext!).pop();
                  JwLifePage.getHomeGlobalKey().currentState?.refreshFavorites();
                  Navigator.pop(context);
                }
              }
            },
          ),
          SettingsTile(
            title: localization(context).settings_userdata_export,
            trailing: const Icon(JwIcons.cloud_arrow_up),
            onTap: () async {
              // On crée une variable pour contrôler le contexte du dialog
              BuildContext? dialogContext;

              // Affiche le dialog de chargement et garde son contexte pour le fermer plus tard
              showJwDialog(
                context: context,
                titleText: 'Exportation…',
                content: Builder(
                  builder: (ctx) {
                    dialogContext = ctx;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: SizedBox(
                        height: 50,
                        child: getLoadingWidget(Theme.of(context).primaryColor),
                      ),
                    );
                  },
                ),
              );

              // Exporte la sauvegarde
              File? backupFile = await JwLifeApp.userdata.exportBackup();

              // Ferme le dialog de chargement
              if (dialogContext != null) Navigator.of(dialogContext!).pop();

              // Si le fichier est bien exporté, on le partage
              if (backupFile != null) {
                await Share.shareXFiles(
                  [XFile(backupFile.path)]
                );
              }

              // Retour à l'écran précédent
              Navigator.pop(context);
            },
          ),
          SettingsTile(
            title: 'Réinitialiser cette sauvegarde',
            trailing: const Icon(JwIcons.trash),
            onTap: () async {
              // 1. Dialog de confirmation
              final confirm = await showJwDialog<bool>(
                context: context,
                titleText: 'Confirmer la réinitialisation',
                contentText: 'Voulez-vous vraiment réinitialiser cette sauvegarde ? Vous perdrez toutes vos données de votre étude individuelle. Cette action est irréversible.',
                buttons: [
                  JwDialogButton(
                    label: 'ANNULER',
                    closeDialog: true,
                    result: false,
                  ),
                  JwDialogButton(
                    label: 'RÉINITIALISER',
                    closeDialog: true,
                    result: true,
                  ),
                ],
                buttonAxisAlignment: MainAxisAlignment.end,
              );

              if (confirm != true) return; // L’utilisateur annule

              // 2. Dialog de chargement pendant la suppression
              BuildContext? dialogContext;
              showJwDialog(
                context: context,
                titleText: 'Suppression de la sauvegarde…',
                content: Builder(
                  builder: (ctx) {
                    dialogContext = ctx;
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
              );

              // 3. Supprimer la sauvegarde
              await JwLifeApp.userdata.deleteBackup();

              // 4. Fermer le dialog de chargement et revenir à l’écran précédent
              if (dialogContext != null) Navigator.of(dialogContext!).pop();
              JwLifePage.getHomeGlobalKey().currentState?.refreshFavorites();
              Navigator.pop(context);
            },
          ),
          const Divider(),

          SettingsSectionHeader('Cache'),
          SettingsTile(
            title: 'Vider le cache',
            trailing: Text(cacheSize),
            onTap: () async {
              BuildContext? dialogContext;

              // Afficher dialog de chargement
              showJwDialog(
                context: context,
                titleText: 'Suppression du cache…',
                content: Builder(
                  builder: (ctx) {
                    dialogContext = ctx;
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
              );

              // Suppression du cache
              Directory cacheDir = await getTemporaryDirectory();
              if (await cacheDir.exists()) {
                await cacheDir.delete(recursive: true);
              }

              // Fermer le dialog
              if (dialogContext != null) Navigator.of(dialogContext!).pop();

              // Recalculer et mettre à jour la taille du cache
              await _loadCacheSize();
            },
          ),

          const Divider(),

          SettingsSectionHeader('Document'),

          SettingsTile(
            title: 'Taille de la police',
            subtitle: '$_fontSize px',
            trailing: Icon(JwIcons.device_text),
            onTap: () async {
              final fontSize = await showJwChoiceDialog<double>(
                context: context,
                titleText: 'Taille de la police',
                contentText: 'Choisissez la taille de la police',
                choices: List.generate(50, (i) => i + 10),
                initialSelection: _fontSize,
              );
              if (fontSize != null) {
                await setFontSize(fontSize);
                JwLifeSettings().webViewData.updateFontSize(fontSize);
                setState(() => _fontSize = fontSize);
              }
            },
          ),

          SettingsTile(
            title: 'Couleur du surlignage',
            subtitle: '$_colorIndex',
            trailing: Icon(JwIcons.device_text),
            onTap: () async {
              final selectedColor = await showJwChoiceDialog<int>(
                context: context,
                titleText: 'Couleur de surlignage',
                contentText: 'Choisissez une couleur',
                choices: List.generate(8, (i) => i),
                initialSelection: _colorIndex,
                display: (i) => "Couleur $i", // ou un widget couleur si tu préfères
              );
              if (selectedColor != null) {
                await setLastHighlightColor(selectedColor);
                JwLifeSettings().webViewData.updateColorIndex(selectedColor);
                setState(() => _colorIndex = selectedColor);
              }
            },
          ),

          const Divider(),

          SettingsSectionHeader(localization(context).settings_about),
          SettingsTile(
            title: localization(context).settings_application_version,
            subtitle: appVersion,
          ),
          SettingsTile(
            title: localization(context).settings_catalog_date,
            subtitle: catalogDate,
          ),
          SettingsTile(
            title: 'Date de la bibliothèque',
            subtitle: libraryDate,
          ),
        ],
      ),
    );
  }
}
