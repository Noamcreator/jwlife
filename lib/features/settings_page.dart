import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_backup_app.dart';
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
import '../app/services/notification_service.dart';
import '../app/services/settings_service.dart';
import '../core/api/api_keys.dart';
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

  bool _dailyTextNotification = false;
  DateTime _dailyTextNotificationTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);

  bool _bibleReadingNotification = false;
  DateTime _bibleReadingNotificationTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);

  bool _downloadNotification = false;

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
      getDailyTextNotification(),
      getDailyTextNotificationTime(),
      getBibleReadingNotification(),
      getBibleReadingNotificationTime(),
      getDownloadNotification()
    ]);

    final theme = futures[0] as String;
    final selectedLanguage = futures[1] as String;
    final primaryColor = futures[2] as Color;
    final fontSize = futures[3] as double;
    final colorIndex = futures[4] as int;

    final dailyTextNotification = futures[5] as bool;
    final dailyTextNotificationTime = futures[6] as DateTime;
    final bibleReadingNotification = futures[7] as bool;
    final bibleReadingNotificationTime = futures[8] as DateTime;

    final downloadNotification = futures[9] as bool;

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

        _dailyTextNotification = dailyTextNotification;
        _dailyTextNotificationTime = dailyTextNotificationTime;
        _bibleReadingNotification = bibleReadingNotification;
        _bibleReadingNotificationTime = bibleReadingNotificationTime;

        _downloadNotification = downloadNotification;
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
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: tempColor,
                labelTypes: const [],
                onColorChanged: (Color color) {
                  // Met à jour la variable locale, mais ne reconstruit pas le widget
                  tempColor = color;
                },
              ),
              ElevatedButton(
                child: const Text('COULEUR PAR DÉFAUT'),
                onPressed: () {
                  // Met à jour la couleur et reconstruit la boîte de dialogue pour mettre à jour le sélecteur
                  setState(() {
                    tempColor = Theme.of(context).brightness == Brightness.dark
                        ? Constants.defaultDarkPrimaryColor
                        : Constants.defaultLightPrimaryColor;
                  });
                  _updatePrimaryColor(tempColor);
                },
              ),
            ],
          );
        },
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
      final allowedExtensions = ['jwlibrary'];
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

      final shouldRestore = await _showRestoreConfirmation('Les données de votre étude individuelle sur cet appareil seront écrasées.', info);
      if (shouldRestore != true) return;

      await _performRestore(File(filePath));
    } catch (e) {
      await _showErrorDialog('Erreur', 'Une erreur est survenue lors de l\'importation.');
    }
  }

  Future<void> _handleAppImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) return;

      final file = result.files.first;
      final filePath = file.path ?? '';

      // Validation du fichier
      final allowedExtensions = ['jwlife'];
      final fileExtension = filePath.split('.').last.toLowerCase();

      if (!allowedExtensions.contains(fileExtension)) {
        await _showErrorDialog('Fichier invalide', 'Le fichier doit avoir une extension .jwlife ou .jwlibrary.');
        return;
      }

      // Validation ZIP
      if (!await _isValidZipFile(filePath)) {
        return;
      }

      final shouldRestore = await _showRestoreConfirmation('Les données de votre applications seront écrasées par les nouvelles données.', null);
      if (shouldRestore != true) return;

      await _performAppRestore(File(filePath));
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

  Future<bool?> _showRestoreConfirmation(String content, dynamic info) async {
    return await showJwDialog<bool>(
      context: context,
      titleText: 'Importer une sauvegarde',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF676767),
              ),
            ),
            const SizedBox(height: 15),
            info == null  ? SizedBox.shrink() : Text(
              'Appareil : ${info.deviceName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            info == null  ? SizedBox.shrink() : const SizedBox(height: 5),
            info == null  ? SizedBox.shrink() : Text('Dernière modification : ${timeAgo(info.lastModified)}'),
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
      GlobalKeyService.personalKey.currentState?.refreshUserdata();
    } catch (e) {
      if (dialogContext != null) Navigator.of(dialogContext!).pop();
      await _showErrorDialog('Erreur', 'Erreur lors de l\'importation de la sauvegarde.');
    }
  }

  Future<void> _performAppRestore(File file) async {
    BuildContext? dialogContext;

    showJwDialog(
      context: context,
      titleText: "Importation des données de l'app en cours…",
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
      await importAppBackup(file);

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

      // redémarer l'application

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (dialogContext != null) Navigator.of(dialogContext!).pop();
      await _showErrorDialog('Erreur', 'Erreur lors de l\'importation de la sauvegarde.');
    }
  }

  Future<void> _showTimeSelector(BuildContext context, DateTime initialTime, Function(DateTime) onTimeSelected) async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );

    if (newTime != null) {
      final DateTime updatedDateTime = DateTime(
        initialTime.year,
        initialTime.month,
        initialTime.day,
        newTime.hour,
        newTime.minute,
      );
      onTimeSelected(updatedDateTime);
    }
  }

  Future<String> uploadImageToImgbb(File imageFile) async {
    const String imgbbApiKey = ApiKey.imgbbApiKey;
    const String albumId = ApiKey.albumId;
    final url = Uri.parse('https://api.imgbb.com/1/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['key'] = imgbbApiKey
      ..fields['album'] = albumId // Ajout du paramètre pour l'album
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data']['url'];
      } else {
        throw Exception('Échec de l\'upload de l\'image sur Imgbb: ${data['error']['message']}');
      }
    } else {
      print("Erreur upload Imgbb: ${response.statusCode} - ${response.body}");
      throw Exception('Échec de l\'upload de l\'image sur Imgbb : ${response.body}');
    }
  }


// Fonction pour envoyer l'issue à GitHub
  Future<void> sendIssues(
      BuildContext context,
      String title,
      String textBody,
      String type,
      String username,
      String? imageUrl,
      ) async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceModel = 'Unknown';
    String deviceManufacturer = 'Unknown';
    String androidVersion = 'Unknown';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceManufacturer = androidInfo.manufacturer;
        androidVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        deviceManufacturer = 'Apple';
        androidVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      print("Erreur lors de la récupération des infos de l'appareil: $e");
    }

    final buffer = StringBuffer()
      ..writeln(textBody)
      ..writeln()
      ..writeln("---")
      ..writeln("## Informations utilisateur et système")
      ..writeln("- **Nom:** $username")
      ..writeln("- **Appareil:** $deviceManufacturer ($deviceModel)")
      ..writeln("- **Version OS:** $androidVersion ${Platform.isAndroid ? '(Android)' : Platform.isIOS ? '(iOS)' : ''}")
      ..writeln("- **Version ${Constants.appName}:** ${Constants.appVersion}")
      ..writeln("- **Timestamp:** ${DateTime.now().toIso8601String()}");

    if (imageUrl != null) {
      buffer.writeln("\n## Capture d'écran jointe\n");
      buffer.writeln("![Capture d'écran]($imageUrl)");
    }

    final issueUrl = Uri.parse("https://api.github.com/repos/${ApiKey.githubOwner}/${Constants.appRepo}/issues");
    final issueResponse = await http.post(
      issueUrl,
      headers: {
        "Authorization": "Bearer ${ApiKey.githubToken}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "body": buffer.toString(),
        "labels": type == "suggestion" ? ["suggestion"] : ["bug"],
      }),
    );

    if (issueResponse.statusCode == 201) {
      showBottomMessage("${type == 'suggestion' ? 'Suggestion' : 'Bug'} envoyé avec succès ✅");
    } else {
      showBottomMessage("Échec de l'envoi de ${type == 'suggestion' ? 'la suggestion' : 'du bug'} ❌");
      print("Erreur d'envoi de l'issue (statut: ${issueResponse.statusCode}) : ${issueResponse.body}");
    }
  }

// Fonction pour afficher le dialogue de soumission
  Future<void> sendIssuesDialog(BuildContext context, String type) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController textController = TextEditingController();
    File? imageFile;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(type == 'suggestion' ? 'Envoyer une suggestion' : 'Signaler un bug'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Votre nom',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: type == 'suggestion' ? 'Titre de la suggestion' : 'Titre du bug',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: type == 'suggestion' ? 'Écrivez ici votre suggestion...' : 'Décrivez le bug ici...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() {
                            imageFile = File(pickedFile.path);
                          });
                        }
                      },
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Ajouter une capture d\'écran'),
                    ),
                    if (imageFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Image sélectionnée : ${imageFile!.path.split('/').last}', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final title = titleController.text.trim();
                    final text = textController.text.trim();
                    String? imageUrl;

                    if (name.isEmpty || title.isEmpty || text.isEmpty) {
                      showBottomMessage("Veuillez remplir tous les champs.");
                      return;
                    }

                    // Si une image est sélectionnée, on l'upload via Imgbb
                    if (imageFile != null) {
                      try {
                        showBottomMessage("Téléchargement de l'image en cours...");
                        imageUrl = await uploadImageToImgbb(imageFile!);
                        showBottomMessage("Image téléchargée ✅");
                      } catch (e) {
                        print("Erreur générale lors de l'upload de l'image : $e");
                        showBottomMessage("Échec de l'envoi de l'image ❌");
                        // Continue sans l'image en cas d'échec
                      }
                    }

                    if (Navigator.of(context).mounted) {
                      await sendIssues(context, title, text, type, name, imageUrl);
                    }

                    if (Navigator.of(context).mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Envoyer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important pour AutomaticKeepAliveClientMixin

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            GlobalKeyService.personalKey.currentState?.refreshUserdata();
          }
          catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            print(e);
            await _showErrorDialog('Erreur', 'Erreur lors de la suppression.');
          }
        },
      ),
      /*
      SettingsTile(
        title: "Importer les données d'application",
        trailing: const Icon(JwIcons.cloud_arrow_down),
        onTap: _handleAppImport,
      ),
      SettingsTile(
        title: "Exporter les données d'application",
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
            final backupFile = await exportAppBackup();
            if (dialogContext != null) Navigator.of(dialogContext!).pop();

            SharePlus.instance.share(ShareParams(files: [XFile(backupFile.path)]));

            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _showErrorDialog('Erreur', 'Erreur lors de l\'exportation.');
          }
        },
      ),

       */
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

      SettingsSectionHeader('Notifications & Rappels'),
      SettingsTile(
        title: 'Rappels pour le texte du jour',
        subtitle: 'Heure du rappel: ${_dailyTextNotificationTime.hour}:${_dailyTextNotificationTime.minute.toString().padLeft(2, '0')}',
        trailing: Switch(
          value: _dailyTextNotification, // Remplacez 'true' par la variable d'état qui contrôle le switch (e.g., _rappelTexteJourActive)
          onChanged: (bool value) async {
            setState(() {
              _dailyTextNotification = value;
            });
            await setDailyTextNotification(value);
            if(_dailyTextNotification) {
              await NotificationService().scheduleDailyTextReminder(hour: _dailyTextNotificationTime.hour, minute: _dailyTextNotificationTime.minute);
            }
            else {
              await NotificationService().cancelDailyTextReminder();
            }
          },
        ),
        onTap: () {
          _showTimeSelector(
              context,
              _dailyTextNotificationTime,
              (time) async {
                setState(() {
                  _dailyTextNotificationTime = time;
                });
                await setDailyTextNotificationTime(time);
                if(_dailyTextNotification) {
                  await NotificationService().scheduleDailyTextReminder(hour: _dailyTextNotificationTime.hour, minute: _dailyTextNotificationTime.minute);
                }
              }
          );
        }
      ),
      SettingsTile(
        title: 'Rappels pour la lecture de la bible',
        subtitle: 'Heure du rappel: ${_bibleReadingNotificationTime.hour}:${_bibleReadingNotificationTime.minute.toString().padLeft(2, '0')}',
        trailing: Switch(
          value: _bibleReadingNotification, // Remplacez 'false' par la variable d'état qui contrôle le switch (e.g., _rappelLectureBibleActive)
          onChanged: (bool value) async {
            setState(() {
              _bibleReadingNotification = value;
            });
            await setBibleReadingNotification(value);
            if(_bibleReadingNotification) {
              await NotificationService().scheduleBibleReadingReminder(hour: _bibleReadingNotificationTime.hour, minute: _bibleReadingNotificationTime.minute);
            }
            else {
              await NotificationService().cancelBibleReadingReminder();
            }
          },
        ),
        onTap: () {
          _showTimeSelector(
            context,
            _bibleReadingNotificationTime,
            (time) async {
              setState(() {
                _bibleReadingNotificationTime = time;
              });
              await setBibleReadingNotificationTime(time);
              if(_bibleReadingNotification) {
                await NotificationService().scheduleBibleReadingReminder(hour: _bibleReadingNotificationTime.hour, minute: _bibleReadingNotificationTime.minute);
              }
            }
          );
        }
      ),
      SettingsTile(
          title: 'Notifications de fichiers téléchargés',
          subtitle: 'Une notification est envoyée chaque fois qu’un fichier est téléchargé.',
          trailing: Switch(
            value: _downloadNotification, // Remplacez 'false' par la variable d'état qui contrôle le switch (e.g., _rappelLectureBibleActive)
            onChanged: (bool value) async {
              setState(() {
                _downloadNotification = value;
              });
              await setDownloadNotification(value);
              JwLifeSettings().notificationDownload = value;
            },
          ),
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

      SettingsSectionHeader('Suggestions & Bugs'),
      SettingsTile(
          title: 'Envoyer une suggestion',
          subtitle: 'Écrivez votre suggestion dans un champ qui sera automatiquement envoyé au développeur.',
          onTap: () {
            sendIssuesDialog(context, 'suggestion');
          }
      ),
      SettingsTile(
          title: 'Décrire un bug rencontré',
          subtitle: 'Décrivez votre bug dans un champ qui sera automatiquement envoyé au développeur.',
          onTap: () {
            sendIssuesDialog(context, 'bug');
          }
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