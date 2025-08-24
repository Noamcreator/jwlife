import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../app/jwlife_app.dart';
import '../app/services/global_key_service.dart';
import '../app/services/settings_service.dart';
import '../core/constants.dart';
import '../core/shared_preferences/shared_preferences_utils.dart';
import '../core/utils/files_helper.dart';
import '../core/utils/utils.dart';
import '../core/utils/widgets_utils.dart';
import '../data/realm/catalog.dart';
import '../data/realm/realm_library.dart';
import '../data/databases/userdata.dart';
import '../widgets/settings_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  // Cache des données pour éviter les recalculs
  ThemeMode _theme = JwLifeSettings().themeMode;
  Locale _selectedLocale = const Locale('en');
  String _selectedLocaleVernacular = 'English';
  Color? _selectedColor = Colors.blue;
  final MepsLanguage _selectedLanguage = JwLifeSettings().currentLanguage;

  String catalogDate = '';
  String libraryDate = '';
  String cacheSize = '';
  double _fontSize = 16;
  int _colorIndex = 1;

  // Cache des styles pour éviter les recréations
  late final TextStyle _subtitleStyle;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true; // Garde la page en vie pour éviter les reconstructions

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialise les styles une seule fois
    if (!_isInitialized) {
      _subtitleStyle = TextStyle(
        fontSize: 14,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFc3c3c3)
            : const Color(0xFF626262),
      );
      _isInitialized = true;
    }
  }

  Future<void> _loadSettings() async {
    // Charge toutes les données en parallèle pour réduire le temps d'attente
    final futures = await Future.wait([
      getTheme(),
      getLocale(),
      getPrimaryColor(_theme),
      getFontSize(),
      getLastHighlightColorIndex(),
    ]);

    final theme = futures[0] as String;
    final selectedLanguage = futures[1] as String;
    final primaryColor = futures[2] as Color;
    final fontSize = futures[3] as double;
    final colorIndex = futures[4] as int;

    final themeMode = theme == 'dark'
        ? ThemeMode.dark
        : theme == 'light'
        ? ThemeMode.light
        : ThemeMode.system;

    // Charge les autres données en parallèle
    final otherFutures = Future.wait([
      _getVernacularName(selectedLanguage),
      _getCatalogDate(),
      _getLibraryDate(),
      _loadCacheSize(),
    ]);

    if (mounted) {
      setState(() {
        _theme = themeMode;
        _selectedLocale = Locale(selectedLanguage);
        _selectedColor = primaryColor;
        _fontSize = fontSize;
        _colorIndex = colorIndex;
      });
    }

    // Attend les autres données et met à jour
    await otherFutures;
  }

  Future<void> _loadCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final sizeInBytes = await getDirectorySize(cacheDir);
      if (mounted) {
        setState(() {
          cacheSize = formatBytes(sizeInBytes);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cacheSize = '0 B';
        });
      }
    }
  }

  Future<void> _getVernacularName(String languageCode) async {
    try {
      final mepsFile = await getMepsUnitDatabaseFile();
      final database = await openDatabase(mepsFile.path);

      final result = await database.rawQuery('''
        SELECT VernacularName FROM Language
        WHERE PrimaryIetfCode = ?
      ''', [languageCode]);

      await database.close();

      if (mounted && result.isNotEmpty) {
        setState(() {
          _selectedLocaleVernacular = result.first['VernacularName'] as String;
        });
      }
    } catch (e) {
      // Gestion d'erreur silencieuse
    }
  }

  Future<void> _getCatalogDate() async {
    try {
      final catalogFile = await getCatalogDatabaseFile();
      final database = await openDatabase(catalogFile.path);
      final result = await database.rawQuery('SELECT Created FROM Revision');
      await database.close();

      if (result.isNotEmpty) {
        final dateStr = result.first['Created'] as String;
        if (dateStr.isNotEmpty) {
          final parsedDate = DateTime.parse(dateStr);
          if (mounted) {
            setState(() {
              catalogDate = _formatDate(parsedDate);
            });
          }
        }
      }
    } catch (e) {
      // Gestion d'erreur silencieuse
    }
  }

  Future<void> _getLibraryDate() async {
    try {
      final results = RealmLibrary.realm
          .all<Language>()
          .query("symbol == '${JwLifeSettings().currentLanguage.symbol}'");

      final date = results.isNotEmpty ? results.first.lastModified : null;

      if (date != null && date.isNotEmpty) {
        final parsedDate = HttpDate.parse(date);
        if (mounted) {
          setState(() {
            libraryDate = _formatDate(parsedDate);
          });
        }
      }
    } catch (e) {
      // Gestion d'erreur silencieuse
    }
  }

  String _formatDate(DateTime dateTime) {
    final localDate = dateTime.toLocal();
    return DateFormat(
      'EEEE d MMMM yyyy HH:mm:ss',
      JwLifeSettings().currentLanguage.primaryIetfCode,
    ).format(localDate);
  }

  Future<void> _updateTheme(ThemeMode theme) async {
    if (_theme != theme) {
      setState(() {
        _theme = theme;
      });
      GlobalKeyService.jwLifeAppKey.currentState?.toggleTheme(theme);
    }
  }

  Future<void> _updatePrimaryColor(Color color) async {
    if (_selectedColor != color) {
      setState(() {
        _selectedColor = color;
      });
      GlobalKeyService.jwLifeAppKey.currentState?.togglePrimaryColor(color);
    }
  }

  Future<void> _updateLocale(Locale locale, String vernacular) async {
    if (_selectedLocale != locale) {
      setState(() {
        _selectedLocale = locale;
        _selectedLocaleVernacular = vernacular;
      });
      GlobalKeyService.jwLifeAppKey.currentState?.changeLocale(locale);
    }
  }

  void showThemeSelectionDialog() {
    showJwDialog(
      context: context,
      title: Text(
        localization(context).settings_appearance,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                Navigator.of(context, rootNavigator: true).pop();
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
      title: const Text(
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
          closeDialog: true,
          onPressed: (BuildContext context) {
            _updatePrimaryColor(tempColor);
          },
        ),
      ],
    );
  }

  Future<void> showLanguageSelectionDialog() async {
    try {
      final mepsFile = await getMepsUnitDatabaseFile();
      final database = await openDatabase(mepsFile.path);

      final languageCodes = AppLocalizations.supportedLocales.map((locale) => locale.languageCode).toList();

      final languages = await database.rawQuery('''
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

      if (mounted) {
        showJwDialog(
          context: context,
          title: Text(
            localization(context).settings_languages,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          buttonAxisAlignment: MainAxisAlignment.end,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((language) {
              final vernacularName = language['VernacularName'] as String? ?? '';
              final name = language['Name'] as String? ?? '';
              final languageCode = language['PrimaryIetfCode'] as String? ?? '';
              final locale = Locale(languageCode);

              return RadioListTile<Locale>(
                title: Text(name),
                subtitle: Text(vernacularName),
                value: locale,
                groupValue: _selectedLocale,
                onChanged: (Locale? value) {
                  if (value != null) {
                    Navigator.of(context, rootNavigator: true).pop();
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
    } catch (e) {
      // Gestion d'erreur silencieuse ou affichage d'un message d'erreur
    }
  }

  // Méthodes d'import/export optimisées avec gestion d'erreur améliorée
  Future<void> _handleImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) return;

      final file = result.files.first;
      final filePath = file.path ?? '';

      // Validation du fichier
      final allowedExtensions = ['jwlife', 'jwlibrary'];
      final fileExtension = filePath.split('.').last.toLowerCase();

      if (!allowedExtensions.contains(fileExtension)) {
        await _showErrorDialog('Fichier invalide', 'Le fichier doit avoir une extension .jwlife ou .jwlibrary.');
        return;
      }

      // Validation ZIP
      if (!await _isValidZipFile(filePath)) {
        return;
      }

      // Récupération des infos et confirmation
      final info = await getBackupInfo(File(filePath));
      if (info == null) {
        await _showErrorDialog('Erreur', 'Le fichier de sauvegarde est invalide ou corrompu. Veuillez choisir un autre fichier.');
        return;
      }

      final shouldRestore = await _showRestoreConfirmation(info);
      if (shouldRestore != true) return;

      await _performRestore(File(filePath));
    } catch (e) {
      await _showErrorDialog('Erreur', 'Une erreur est survenue lors de l\'importation.');
    }
  }

  Future<bool> _isValidZipFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      ZipDecoder().decodeBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showErrorDialog(String title, String content) async {
    await showJwDialog(
      context: context,
      titleText: title,
      contentText: content,
      buttons: [
        JwDialogButton(
          label: 'OK',
          closeDialog: true,
        ),
      ],
      buttonAxisAlignment: MainAxisAlignment.end,
    );
  }

  Future<bool?> _showRestoreConfirmation(dynamic info) async {
    return await showJwDialog<bool>(
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
  }

  Future<void> _performRestore(File file) async {
    BuildContext? dialogContext;

    showJwDialog(
      context: context,
      titleText: 'Importation en cours…',
      content: Builder(
        builder: (ctx) {
          dialogContext = ctx;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: SizedBox(
              height: 50,
              child: getLoadingWidget(Theme.of(context).primaryColor),
            ),
          );
        },
      ),
    );

    try {
      await JwLifeApp.userdata.importBackup(file);

      if (dialogContext != null) Navigator.of(dialogContext!).pop();

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

      GlobalKeyService.homeKey.currentState?.refreshFavorites();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (dialogContext != null) Navigator.of(dialogContext!).pop();
      await _showErrorDialog('Erreur', 'Erreur lors de l\'importation de la sauvegarde.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important pour AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localization(context).navigation_settings,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView.builder(
        // Utilise ListView.builder pour une meilleure performance
        itemCount: _buildItems().length,
        cacheExtent: 500, // Cache plus d'éléments pour un scroll fluide
        itemBuilder: (context, index) {
          return _buildItems()[index];
        },
      ),
    );
  }

  List<Widget> _buildItems() {
    return [
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
              await setLibraryLanguage(value);
              GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
            }
          });
        },
      ),
      const Divider(),

      SettingsSectionHeader(localization(context).settings_userdata),
      SettingsTile(
        title: localization(context).settings_userdata_import,
        trailing: const Icon(JwIcons.cloud_arrow_down),
        onTap: _handleImport,
      ),
      SettingsTile(
        title: localization(context).settings_userdata_export,
        trailing: const Icon(JwIcons.cloud_arrow_up),
        onTap: () async {
          BuildContext? dialogContext;

          showJwDialog(
            context: context,
            titleText: 'Exportation…',
            content: Builder(
              builder: (ctx) {
                dialogContext = ctx;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    height: 50,
                    child: getLoadingWidget(Theme.of(context).primaryColor),
                  ),
                );
              },
            ),
          );

          try {
            final backupFile = await JwLifeApp.userdata.exportBackup();
            if (dialogContext != null) Navigator.of(dialogContext!).pop();

            if (backupFile != null) {
              SharePlus.instance.share(ShareParams(files: [XFile(backupFile.path)]));
            }

            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _showErrorDialog('Erreur', 'Erreur lors de l\'exportation.');
          }
        },
      ),
      SettingsTile(
        title: 'Réinitialiser cette sauvegarde',
        trailing: const Icon(JwIcons.trash),
        onTap: () async {
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

          if (confirm != true) return;

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

          try {
            await JwLifeApp.userdata.deleteBackup();
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            GlobalKeyService.homeKey.currentState?.refreshFavorites();
            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _showErrorDialog('Erreur', 'Erreur lors de la suppression.');
          }
        },
      ),
      const Divider(),

      SettingsSectionHeader('Cache'),
      SettingsTile(
        title: 'Vider le cache',
        trailing: Text(cacheSize),
        onTap: () async {
          BuildContext? dialogContext;

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

          try {
            final cacheDir = await getTemporaryDirectory();
            if (await cacheDir.exists()) {
              await cacheDir.delete(recursive: true);
            }

            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _loadCacheSize();
          } catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _showErrorDialog('Erreur', 'Erreur lors de la suppression du cache.');
          }
        },
      ),
      const Divider(),

      SettingsSectionHeader('Document'),
      SettingsTile(
        title: 'Taille de la police',
        subtitle: '$_fontSize px',
        trailing: const Icon(JwIcons.device_text),
        onTap: () async {
          final fontSize = await showJwChoiceDialog<double>(
            context: context,
            titleText: 'Taille de la police',
            contentText: 'Choisissez la taille de la police',
            choices: List.generate(50, (i) => (i + 10).toDouble()),
            initialSelection: _fontSize,
          );
          if (fontSize != null && fontSize != _fontSize) {
            await setFontSize(fontSize);
            JwLifeSettings().webViewData.updateFontSize(fontSize);
            setState(() => _fontSize = fontSize);
          }
        },
      ),
      SettingsTile(
        title: 'Couleur du surlignage',
        subtitle: '$_colorIndex',
        trailing: const Icon(JwIcons.device_text),
        onTap: () async {
          final selectedColor = await showJwChoiceDialog<int>(
            context: context,
            titleText: 'Couleur de surlignage',
            contentText: 'Choisissez une couleur',
            choices: List.generate(8, (i) => i),
            initialSelection: _colorIndex,
            display: (i) => "Couleur $i",
          );
          if (selectedColor != null && selectedColor != _colorIndex) {
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
        subtitle: Constants.appVersion,
      ),
      SettingsTile(
        title: localization(context).settings_catalog_date,
        subtitle: catalogDate,
      ),
      SettingsTile(
        title: 'Date de la bibliothèque',
        subtitle: libraryDate,
      ),
    ];
  }
}