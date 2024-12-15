import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Ajoute cette ligne
import 'package:shared_preferences/shared_preferences.dart';
import '../jwlife.dart';
import '../utils/directory_helper.dart';
import '../utils/shared_preferences_helper.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final Function() reloadPage;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.reloadPage,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkTheme = false;
  final String appVersion = '1.0.0';
  String catalogDate = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = (prefs.getBool('isDarkTheme') ?? false);
      _getCatalogDate();
    });
  }

  Future<void> _getCatalogDate() async {
    String date = await getCatalogDate();
    setState(() {
      catalogDate = _formatDate(date); // Formate la date ici
    });
  }

  String _formatDate(String dateString) {
    DateTime dateTime = DateTime.parse(dateString); // Assure-toi que la date est au format ISO 8601
    return DateFormat('EEEE d MMMM yyyy HH:mm:ss', JwLifeApp.currentLanguage.primaryIetfCode).format(dateTime);
  }

  _updateTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = value;
      prefs.setBool('isDarkTheme', value);
    });
    widget.toggleTheme(value);
  }

  _exportBackup() {
    // Logique pour exporter une sauvegarde
  }

  Future<void> _importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any
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
            widget.reloadPage();
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
        title: Text('Paramètres'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Thème sombre'),
            trailing: Switch(
              value: _isDarkTheme,
              onChanged: (value) {
                _updateTheme(value);
              },
            ),
          ),
          ListTile(
            title: Text('Exporter une sauvegarde'),
            trailing: Icon(Icons.upload),
            onTap: _exportBackup,
          ),
          ListTile(
            title: Text('Importer une sauvegarde'),
            trailing: Icon(Icons.download),
            onTap: _importBackup,
          ),
          ListTile(
            title: Text('À propos'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version de l\'application: $appVersion'),
                Text('Date du catalogue: $catalogDate'), // Affiche la date formatée
              ],
            ),
          ),
        ],
      ),
    );
  }
}
