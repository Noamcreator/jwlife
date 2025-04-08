import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/startup/login_view.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/data/meps/language.dart';
import 'package:jwlife/l10n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import '../app/jwlife_app.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsView extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLanguage;

  const SettingsView({
    super.key,
    required this.toggleTheme,
    required this.changeLanguage,
  });

  @override
  _SettingsViewState createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  ThemeMode _theme = ThemeMode.system;
  Locale _selectedLocale = Locale('en');
  Color? _selectedColor = Colors.blue;
  MepsLanguage _selectedLanguage = JwLifeApp.currentLanguage;

  final String appVersion = '1.0.0';
  String catalogDate = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    String theme = await getTheme();
    ThemeMode themeMode = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
    String selectedLanguage = await getLocale();
    Color primaryColor = await getPrimaryColor(themeMode);
    setState(() {
      _theme = themeMode;
      _selectedLocale = Locale(selectedLanguage);
      _selectedColor = primaryColor;
      _getCatalogDate();
    });
  }

  Future<void> _getCatalogDate() async {
    String date = await getCatalogDate();
    setState(() {
      catalogDate = _formatDate(date);
    });
  }

  String _formatDate(String dateString) {
    DateTime dateTime = DateTime.parse(dateString);
    return DateFormat(
      'EEEE d MMMM yyyy HH:mm:ss',
      JwLifeApp.currentLanguage.primaryIetfCode,
    ).format(dateTime);
  }

  _updateTheme(ThemeMode theme) async {
    setState(() {
      _theme = theme;
    });
    widget.toggleTheme(theme);
  }

  _updateLocale(Locale locale) async {
    setState(() {
      _selectedLocale = locale;
    });
    widget.changeLanguage(locale);
  }

  _exportBackup() {
    // Logique pour exporter une sauvegarde
  }

  Future<void> _importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        PlatformFile file = result.files.first;

        try {
          Directory userDataDir = await getAppUserDataDirectory();
          if (await userDataDir.exists()) {
            await userDataDir.delete(recursive: true);
          }
          await userDataDir.create(recursive: true);

          List<int> bytes = File(file.path!).readAsBytesSync();
          Archive archive = ZipDecoder().decodeBytes(bytes);
          for (ArchiveFile archiveFile in archive) {
            File newFile = File('${userDataDir.path}/${archiveFile.name}');
            await newFile.writeAsBytes(archiveFile.content);
          }

          File userDataFile = File('${userDataDir.path}/userData.db');
          if (await userDataFile.exists()) {
            print('Importation du fichier UserData');
            await JwLifeApp.userdata.reload_db();
            HomeView.setStateFavorites;
            Navigator.pop(context);
          }
        } catch (e) {
          print('Erreur lors du traitement du fichier UserData : $e');
        }
      }
    } catch (e) {
      print('Erreur lors de l\'importation du fichier UserData : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localization(context).navigation_settings),
      ),
      body: ListView(
        children: [
          // Section Affichage
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              localization(context).settings_appearance_display.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          ),
          InkWell(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localization(context).settings_appearance, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _theme == ThemeMode.system
                          ? localization(context).settings_appearance_system
                          : _theme == ThemeMode.light
                          ? localization(context).settings_appearance_light
                          : localization(context).settings_appearance_dark,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(localization(context).settings_appearance),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(localization(context).settings_appearance_system),
                          value: ThemeMode.system,
                          groupValue: _theme,
                          onChanged: (ThemeMode? value) {
                            if (value != null) _updateTheme(value);
                            Navigator.pop(context); // Fermer la boîte de dialogue
                          },
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(localization(context).settings_appearance_light),
                          value: ThemeMode.light,
                          groupValue: _theme,
                          onChanged: (ThemeMode? value) {
                            if (value != null) _updateTheme(value);
                            Navigator.pop(context);
                          },
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(localization(context).settings_appearance_dark),
                          value: ThemeMode.dark,
                          groupValue: _theme,
                          onChanged: (ThemeMode? value) {
                            if (value != null) _updateTheme(value);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(localization(context).action_cancel),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          InkWell(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Couleur Principale', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  ColoredBox(color: Theme.of(context).primaryColor, child: Container(height: 50)),
                ],
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Couleur Principale'),
                    content: ColorPicker(
                      pickerColor: _selectedColor!,
                      onColorChanged: (Color color) {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(localization(context).action_cancel),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: Text(localization(context).action_save),
                        onPressed: () {
                          JwLifeApp.togglePrimaryColor(_selectedColor!);
                          Navigator.pop(context);
                        }
                      )
                    ],
                  );
                },
              );
            },
          ),
          Divider(),

          // Section Langues
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              localization(context).settings_languages.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          ),
          InkWell(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localization(context).settings_language_app, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _selectedLocale.languageCode,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(localization(context).settings_languages),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: AppLocalizations.supportedLocales.map((locale) {
                        return RadioListTile<Locale>(
                          title: Text(locale.languageCode),
                          value: locale,
                          groupValue: _selectedLocale,
                          onChanged: (Locale? value) {
                            if (value != null) _updateLocale(value);
                            Navigator.pop(context); // Fermer la boîte de dialogue
                          },
                        );
                      }).toList(),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(localization(context).action_cancel),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localization(context).settings_language_library, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _selectedLanguage.vernacular,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            onTap: () {
              showLibraryLanguageDialog(context).then((value) async {
                if (value['Symbol'] != JwLifeApp.currentLanguage.symbol) {
                  setState(() {
                    _selectedLanguage = MepsLanguage(id: value['LanguageId'], symbol: value['Symbol'], vernacular: value['VernacularName'], primaryIetfCode: value['PrimaryIetfCode']);
                  });
                  await setLibraryLanguage(value);
                  await HomeView.setStateHomePage();
                  await LibraryView.setStateLibraryPage();
                }
              }).catchError((error) {
                // Gérer les erreurs ici si nécessaire
                print('Erreur : $error');
              });
            }
          ),
          Divider(),

          // Section À propos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              localization(context).settings_userdata.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          ),
          ListTile(
            title: Text(localization(context).settings_userdata_import),
            trailing: Icon(Icons.download),
            onTap: _importBackup,
          ),
          ListTile(
            title: Text(localization(context).settings_userdata_export),
            trailing: Icon(Icons.upload),
            onTap: _exportBackup,
          ),
          Divider(),

          // Section À propos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization(context).settings_account.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16.0),
                if (FirebaseAuth.instance.currentUser != null) ...[
                  Text('${localization(context).settings_user_name}: ${FirebaseAuth.instance.currentUser!.displayName}'),
                  const SizedBox(height: 8.0),
                  Text("${localization(context).settings_user_email}: ${FirebaseAuth.instance.currentUser!.email}"),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                      style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))))),
                      child: Text(localization(context).action_sign_out),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        setState(() {});
                      }
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))))),
                    child: Text(localization(context).action_delete),
                    onPressed: () => FirebaseAuth.instance.currentUser!.delete(),
                  ),
                ],
                if (FirebaseAuth.instance.currentUser == null) ...[
                  ElevatedButton(
                    style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))))),
                    child: Text(localization(context).action_sign_in),
                    onPressed: () {
                      showPage(context, LoginView(update: setState, fromSettings: true));
                    }
                  ),
                ],
              ],
            ),
          ),

          Divider(),

          // Section À propos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization(context).settings_about.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16.0),
                Text('${localization(context).settings_application_version}: $appVersion'),
                const SizedBox(height: 8.0),
                Text("${localization(context).settings_catalog_date}: $catalogDate"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
