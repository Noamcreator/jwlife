import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/data/meps/language.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:sqflite/sqflite.dart';
import '../app/jwlife_app.dart';
import '../core/utils/files_helper.dart';

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
  String _selectedLocaleVernacular = 'English';
  Color? _selectedColor = Colors.blue;
  MepsLanguage _selectedLanguage = JwLifeApp.settings.currentLanguage;

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

    _getVernacularName();

    setState(() {
      _theme = themeMode;
      _selectedLocale = Locale(selectedLanguage);
      _selectedColor = primaryColor;
      _getCatalogDate();
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
    String date = await getCatalogDate();
    setState(() {
      catalogDate = _formatDate(date);
    });
  }

  String _formatDate(String dateString) {
    DateTime dateTime = DateTime.parse(dateString).toLocal(); // Convertir en heure locale
    return DateFormat(
      'EEEE d MMMM yyyy HH:mm:ss',
      JwLifeApp.settings.currentLanguage.primaryIetfCode,
    ).format(dateTime);
  }

  _updateTheme(ThemeMode theme) async {
    setState(() {
      _theme = theme;
    });
    widget.toggleTheme(theme);
  }

  _updateLocale(Locale locale, String vernacular) async {
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
              Navigator.pop(context); // Fermer la boîte de dialogue
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(localization(context).settings_appearance_dark),
            value: ThemeMode.dark,
            groupValue: _theme,
            onChanged: (ThemeMode? value) {
              Navigator.of(context).pop();
              if (value != null) _updateTheme(value);
              Navigator.pop(context); // Fermer la boîte de dialogue
            },
          ),
        ],
      ),
      buttons: [
        JwDialogButton(
          label: localization(context).action_cancel.toUpperCase(),
        ),
      ],
    );
  }

  void showColorSelectionDialog() {
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
            pickerColor: _selectedColor!, // La couleur actuellement sélectionnée
            onColorChanged: (Color color) {
              setState(() {
                _selectedColor = color; // Met à jour la couleur sélectionnée
              });
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
          onPressed: (buildContext) {
            JwLifeApp.togglePrimaryColor(_selectedColor!); // Applique la nouvelle couleur
          },
        ),
      ],
    );
  }

  Future<void> showLanguageSelectionDialog() async {
    // Récupérer le fichier MEPS
    File mepsFile = await getMepsFile();

    // Ouvrir la base de données
    Database database = await openDatabase(mepsFile.path);

    // Créer une liste des codes IETF (codes de langue) supportés par l'application
    List<String> languageCodes = AppLocalizations.supportedLocales.map((locale) => locale.languageCode).toList();

    // Récupérer les langues avec la requête SQL
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
    '''
    );

    // Fermer la base de données
    database.close();

    // Affichage de la boîte de dialogue avec showJwDialog
    showJwDialog(
      context: context,
      title: Text(
        localization(context).settings_languages,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      buttonAxisAlignment: MainAxisAlignment.end,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
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
                _updateLocale(value, vernacularName); // Mise à jour du locale sélectionné
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
              showThemeSelectionDialog();
            }
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
              showColorSelectionDialog();
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
                      _selectedLocaleVernacular,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
            ),
            onTap: () {
              showLanguageSelectionDialog();
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
                if (value['Symbol'] != JwLifeApp.settings.currentLanguage.symbol) {
                  setState(() {
                    _selectedLanguage = MepsLanguage(id: value['LanguageId'], symbol: value['Symbol'], vernacular: value['VernacularName'], primaryIetfCode: value['PrimaryIetfCode']);
                  });
                  await setLibraryLanguage(value);
                  HomeView.setStateHomePage();
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
            trailing: Icon(JwIcons.cloud_arrow_down),
              onTap: () async {
                JwLifeApp.userdata.importBackup();
                setState(() {
                  Navigator.pop(context);
                });
              }
          ),
          ListTile(
            title: Text(localization(context).settings_userdata_export),
            trailing: Icon(JwIcons.cloud_arrow_up),
              onTap: () async {
                JwLifeApp.userdata.exportBackup();
                setState(() {
                  Navigator.pop(context);
                });
              }
          ),
          ListTile(
            title: Text('Rénitialiser cette sauvegarde'),
            trailing: Icon(JwIcons.trash),
            onTap: () async {
              JwLifeApp.userdata.deleteBackup();
              setState(() {
                Navigator.pop(context);
              });
            }
          ),

          /*
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

           */

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
