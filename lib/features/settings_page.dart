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
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/app/startup/auto_update.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_backup_app.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/releases_page.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:realm/realm.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../app/app_page.dart';
import '../app/jwlife_app.dart';
import '../app/services/global_key_service.dart';
import '../app/services/notification_service.dart';
import '../app/services/settings_service.dart';
import '../core/app_data/app_data_service.dart';
import '../core/keys.dart';
import '../core/constants.dart';
import '../core/shared_preferences/shared_preferences_utils.dart';
import '../core/utils/directory_helper.dart';
import '../core/utils/files_helper.dart';
import '../core/utils/utils.dart';
import '../core/utils/utils_import_export.dart';
import '../data/realm/catalog.dart';
import '../data/realm/realm_library.dart';
import '../widgets/settings_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  // Cache des données pour éviter les recalculs
  ThemeMode _theme = JwLifeSettings.instance.themeMode;
  String _pageTransition = 'default';
  Locale _selectedLocale = const Locale('en');
  String _selectedLocaleVernacular = 'English';
  Color? _selectedColor = Colors.blue;
  Color? _bibleSelectedColor = Colors.blue;

  String catalogDate = '';
  String libraryDate = '';
  int cacheSize = 0;

  bool _dailyTextNotification = false;
  DateTime _dailyTextNotificationTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);

  bool _bibleReadingNotification = false;
  DateTime _bibleReadingNotificationTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);

  bool _downloadNotification = false;

  String _currentVersion = '1.0.0';

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
    final sharedPreferences = AppSharedPreferences.instance;

    final theme = sharedPreferences.getTheme();
    final pageTransition = sharedPreferences.getPageTransition();
    final selectedLanguage = sharedPreferences.getLocale();
    final primaryColor = sharedPreferences.getPrimaryColor(_theme);
    final bibleColor = sharedPreferences.getBibleColor();

    final dailyTextNotification = sharedPreferences.getDailyTextNotification();
    final dailyTextNotificationTime = sharedPreferences.getDailyTextNotificationTime();
    final bibleReadingNotification = sharedPreferences.getBibleReadingNotification();
    final bibleReadingNotificationTime = sharedPreferences.getBibleReadingNotificationTime();

    final downloadNotification = sharedPreferences.getDownloadNotification();

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

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
        _pageTransition = pageTransition;
        _selectedLocale = Locale(selectedLanguage);
        _selectedColor = primaryColor;
        _bibleSelectedColor = bibleColor;

        _dailyTextNotification = dailyTextNotification;
        _dailyTextNotificationTime = dailyTextNotificationTime;
        _bibleReadingNotification = bibleReadingNotification;
        _bibleReadingNotificationTime = bibleReadingNotificationTime;

        _downloadNotification = downloadNotification;

        _currentVersion = currentVersion;
      });
    }

    // Attend les autres données et met à jour
    await otherFutures;
  }

  Future<void> _loadCacheSize() async {
    try {
      final appCacheDir = await getAppCacheDirectory();
      final appCacheSizeInBytes = await getDirectorySize(appCacheDir);
      if (mounted) {
        setState(() {
          cacheSize = appCacheSizeInBytes;
        });
      }
    }
    catch (e) {
      if (mounted) {
        setState(() {
          cacheSize = 0;
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
    String catalogDateStr = await CatalogDb.instance.getCatalogDate();
    if (catalogDateStr.isNotEmpty) {
      final parsedDate = DateTime.parse(catalogDateStr);
      if (mounted) {
        setState(() {
          catalogDate = _formatDate(parsedDate);
        });
      }
    }
  }

  Future<void> _getLibraryDate() async {
    try {
      final results = RealmLibrary.realm.all<RealmLanguage>().query("Symbol == '${JwLifeSettings.instance.currentLanguage.value.symbol}'");

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
      JwLifeSettings.instance.currentLanguage.value.primaryIetfCode,
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

  Future<void> _updatePageTransition(String pageTransition) async {
    if (_pageTransition != pageTransition) {
      setState(() {
        _pageTransition = pageTransition;
      });

      JwLifeSettings.instance.pageTransition = pageTransition;
      AppSharedPreferences.instance.setPageTransition(pageTransition);
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

  Future<void> _updateBibleColor(Color color) async {
    if (_bibleSelectedColor != color) {
      setState(() {
        _bibleSelectedColor = color;
      });
      GlobalKeyService.jwLifeAppKey.currentState?.toggleBibleColor(color);
    }
  }

  Future<void> _updateLocale(Locale? locale, String vernacular) async {
    if (_selectedLocale != locale && locale != null) {
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
        i18n().settings_appearance,
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
          label: i18n().action_cancel.toUpperCase(),
        ),
      ],
    );
  }

  String getPageTransitionLabel(String mode) {
    switch (mode) {
      case 'default':
        return i18n().settings_appearance_system;
      case 'right':
        return i18n().settings_page_transition_right;
      case 'bottom':
        return i18n().settings_page_transition_bottom;
      default:
        return i18n().settings_appearance_system;
    }
  }

  void showPageTransitionSelectionDialog() {
    showJwDialog(
      context: context,
      title: Text(
        i18n().settings_page_transition,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      buttonAxisAlignment: MainAxisAlignment.end,
      content: Column(
        spacing: 0,
        mainAxisAlignment: MainAxisAlignment.start,
        children: ['default', 'right', 'bottom'].map((mode) {
          return RadioListTile<String>(
            title: Text(getPageTransitionLabel(mode)),
            value: mode,
            groupValue: _pageTransition,
            onChanged: (String? value) {
              if (value != null) {
                _updatePageTransition(value);
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          );
        }).toList(),
      ),
      buttons: [
        JwDialogButton(
          label: i18n().action_cancel.toUpperCase(),
        ),
      ],
    );
  }

  String getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return i18n().settings_appearance_system;
      case ThemeMode.light:
        return i18n().settings_appearance_light;
      case ThemeMode.dark:
        return i18n().settings_appearance_dark;
    }
  }

  void showColorSelectionDialog(bool isPrimaryColor) {
    Color tempColor = isPrimaryColor ? _selectedColor! : _bibleSelectedColor!;

    showJwDialog(
      context: context,
      title: Text(
        isPrimaryColor ? i18n().settings_main_color : i18n().settings_main_books_color,
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
                    tempColor = isPrimaryColor ? Theme.of(context).brightness == Brightness.dark ? Constants.defaultDarkPrimaryColor : Constants.defaultLightPrimaryColor : Constants.defaultBibleColor;
                  });
                  isPrimaryColor ? _updatePrimaryColor(tempColor) : _updateBibleColor(tempColor);
                },
              ),
            ],
          );
        },
      ),
      buttons: [
        JwDialogButton(
          label: i18n().action_cancel.toUpperCase(),
        ),
        JwDialogButton(
          label: i18n().action_ok.toUpperCase(),
          closeDialog: true,
          onPressed: (BuildContext context) {
            isPrimaryColor ? _updatePrimaryColor(tempColor) : _updateBibleColor(tempColor);
          },
        ),
      ],
    );
  }

  Future<void> showLanguageSelectionDialog() async {
    Map<String, dynamic>? languageData = await showLanguagesAppDialog(context);
    if(languageData != null) {
      _updateLocale(languageData['Locale'], languageData['VernacularName']);
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
    const String imgbbApiKey = Keys.imgbbApiKey;
    const String albumId = Keys.albumId;
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
      ..writeln("- **Version ${Constants.appName}:** $_currentVersion")
      ..writeln("- **Timestamp:** ${DateTime.now().toIso8601String()}");

    if (imageUrl != null) {
      buffer.writeln("\n## Capture d'écran jointe\n");
      buffer.writeln("![Capture d'écran]($imageUrl)");
    }

    final issueUrl = Uri.parse("https://api.github.com/repos/${Keys.githubOwner}/${Constants.appRepo}/issues");
    final issueResponse = await http.post(
      issueUrl,
      headers: {
        "Authorization": "Bearer ${Keys.githubToken}",
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
    }
    else {
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

    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().navigation_settings
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
      SettingsSectionHeader(i18n().settings_appearance_display_upper),
      SettingsTile(
        title: i18n().settings_appearance,
        subtitle: _theme == ThemeMode.system
            ? i18n().settings_appearance_system
            : _theme == ThemeMode.light
            ? i18n().settings_appearance_light
            : i18n().settings_appearance_dark,
        onTap: showThemeSelectionDialog,
      ),
      SettingsTile(
        title: i18n().settings_page_transition,
        subtitle: _pageTransition == 'default' ? i18n().settings_appearance_system : _pageTransition == 'right' ? i18n().settings_page_transition_right : i18n().settings_page_transition_bottom,
        onTap: showPageTransitionSelectionDialog,
      ),
      SettingsColorTile(
        title: i18n().settings_main_color,
        color: _selectedColor!,
        onTap: () => showColorSelectionDialog(true),
      ),
      SettingsColorTile(
        title: i18n().settings_main_books_color,
        color: _bibleSelectedColor!,
        onTap: () => showColorSelectionDialog(false),
      ),
      const Divider(),

      SettingsSectionHeader(i18n().settings_languages),
      SettingsTile(
        title: i18n().settings_language_app,
        subtitle: _selectedLocaleVernacular,
        onTap: showLanguageSelectionDialog,
      ),
      ValueListenableBuilder(
          valueListenable: JwLifeSettings.instance.currentLanguage,
          builder: (context, value, child) {
            return SettingsTile(
              title: i18n().settings_language_library,
              subtitle: value.vernacular,
              onTap: () {
                showLanguageDialog(context).then((value) async {
                  if (value['Symbol'] != JwLifeSettings.instance.currentLanguage.value.symbol) {
                    await AppSharedPreferences.instance.setLibraryLanguage(value);
                    AppDataService.instance.changeLanguageAndRefreshContent();
                  }
                });
              },
            );
          }
      ),
      const Divider(),

      SettingsSectionHeader(i18n().settings_userdata_upper),
      SettingsTile(
        title: i18n().settings_userdata_import,
        trailing: const Icon(JwIcons.cloud_arrow_down),
        onTap: () => handleImport(context),
      ),
      SettingsTile(
        title: i18n().settings_userdata_export,
        trailing: const Icon(JwIcons.cloud_arrow_up),
        onTap: () => handleExport(context)
      ),
      SettingsTile(
        title: i18n().settings_userdata_reset,
        trailing: const Icon(JwIcons.trash),
        onTap: () => handleResetUserdata(context)
      ),

      const Divider(),

      SettingsSectionHeader(i18n().settings_notifications_upper),
      SettingsTile(
        title: i18n().settings_notifications_daily_text,
        subtitle: i18n().settings_notifications_hour('${_dailyTextNotificationTime.hour}:${_dailyTextNotificationTime.minute.toString().padLeft(2, '0')}'),
        trailing: Switch(
          value: _dailyTextNotification, // Remplacez 'true' par la variable d'état qui contrôle le switch (e.g., _rappelTexteJourActive)
          onChanged: (bool value) async {
            setState(() {
              _dailyTextNotification = value;
            });
            await AppSharedPreferences.instance.setDailyTextNotification(value);
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
                await AppSharedPreferences.instance.setDailyTextNotificationTime(time);
                if(_dailyTextNotification) {
                  await NotificationService().scheduleDailyTextReminder(hour: _dailyTextNotificationTime.hour, minute: _dailyTextNotificationTime.minute);
                }
              }
          );
        }
      ),
      SettingsTile(
        title: i18n().settings_notifications_bible_reading,
        subtitle: i18n().settings_notifications_hour('${_bibleReadingNotificationTime.hour}:${_bibleReadingNotificationTime.minute.toString().padLeft(2, '0')}'),
        trailing: Switch(
          value: _bibleReadingNotification, // Remplacez 'false' par la variable d'état qui contrôle le switch (e.g., _rappelLectureBibleActive)
          onChanged: (bool value) async {
            setState(() {
              _bibleReadingNotification = value;
            });
            await AppSharedPreferences.instance.setBibleReadingNotification(value);
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
              await AppSharedPreferences.instance.setBibleReadingNotificationTime(time);
              if(_bibleReadingNotification) {
                await NotificationService().scheduleBibleReadingReminder(hour: _bibleReadingNotificationTime.hour, minute: _bibleReadingNotificationTime.minute);
              }
            }
          );
        }
      ),
      SettingsTile(
          title: i18n().settings_notifications_download_file,
          subtitle: i18n().settings_notifications_download_file_subtitle,
          trailing: Switch(
            value: _downloadNotification, // Remplacez 'false' par la variable d'état qui contrôle le switch (e.g., _rappelLectureBibleActive)
            onChanged: (bool value) async {
              setState(() {
                _downloadNotification = value;
              });
              await AppSharedPreferences.instance.setDownloadNotification(value);
              JwLifeSettings.instance.notificationDownload = value;
            },
          ),
      ),

      const Divider(),

      SettingsSectionHeader(i18n().settings_cache_upper),
      SettingsTile(
        title: i18n().action_clear_cache,
        trailing: Text(formatFileSize(cacheSize)),
        onTap: () async {
          BuildContext? dialogContext;

          try {
            final appCacheDir = await getAppCacheDirectory();
            final appCacheSizeInBytes = await getDirectorySize(appCacheDir);
            if (await appCacheDir.exists() && appCacheSizeInBytes != 0) {
              showJwDialog(
                context: context,
                titleText: i18n().message_clear_cache,
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

              await appCacheDir.delete(recursive: true);
            }

            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await _loadCacheSize();
          }
          catch (e) {
            if (dialogContext != null) Navigator.of(dialogContext!).pop();
            await showErrorDialog(context, 'Erreur', 'Erreur lors de la suppression du cache.');
          }
        },
      ),

      const Divider(),

      SettingsSectionHeader(i18n().settings_suggestions_upper),
      SettingsTile(
          title: i18n().settings_suggestions_send,
          subtitle: i18n().settings_suggestions_subtitle,
          onTap: () {
            sendIssuesDialog(context, 'suggestion');
          }
      ),
      SettingsTile(
          title: i18n().settings_bugs_send,
          subtitle: i18n().settings_bugs_subtitle,
          onTap: () {
            sendIssuesDialog(context, 'bug');
          }
      ),

      const Divider(),

      SettingsSectionHeader(i18n().settings_about),
      SettingsTile(
        title: i18n().settings_application_version,
        subtitle: _currentVersion,
        trailing: IconButton(
            icon: const Icon(JwIcons.arrows_circular),
            onPressed: () {
              JwLifeAutoUpdater.checkAndUpdate(showBannerNoUpdate: true);
            }
        ),
        onTap: () {
          showPage(ReleasesPage());
        }
      ),
      SettingsTile(
        title: i18n().settings_catalog_date,
        subtitle: catalogDate,
      ),
      SettingsTile(
        title: i18n().settings_library_date,
        subtitle: libraryDate,
      ),
    ];
  }
}