import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'language_dialog.dart';

void showNoConnectionDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: const Text('Connectez-vous à Internet.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('PARAMÈTRES'),
            onPressed: () {
              AppSettings.openAppSettings(type: AppSettingsType.wifi);
            },
          ),
        ],
      );
    },
  );
}

Future<String> showWeekSelectionDialog(BuildContext context) async {
  // Requête SQL pour récupérer la dernière date
  String query = '''
  SELECT End
  FROM DatedText
  JOIN Publication ON DatedText.PublicationId = Publication.Id
  WHERE (Publication.KeySymbol = 'mwb' OR Publication.KeySymbol = 'w') AND Publication.MepsLanguageId = ?
  ORDER BY DatedText.End DESC
  LIMIT 1;
  ''';

  // Exécuter la requête SQL
  File catalogFile = await getCatalogFile();
  Database db = await openReadOnlyDatabase(catalogFile.path);

  List<Map<String, dynamic>> result = await db.rawQuery(query, [JwLifeApp.currentLanguage.id]);

  db.close();

  // Convertir la dernière date reçue en DateTime
  DateTime lastDate = DateFormat('yyyy-MM-dd').parse(result.first['End']);

  // Obtenir la date actuelle
  DateTime currentDate = DateTime.now();

  // Calculer la date de début de la première semaine (5 semaines avant la date actuelle)
  DateTime startDate = currentDate.subtract(Duration(days: 5 * 7));

  // Initialiser une liste pour stocker les semaines
  List<String> weeksList = [];
  List<DateTime> weeksStartDates = []; // Liste des dates de début pour chaque semaine

  // Générer la liste des semaines en fonction de la date de début
  DateTime currentWeekStart = startDate.subtract(Duration(days: startDate.weekday - 1)); // Commence le lundi de la semaine
  while (currentWeekStart.isBefore(lastDate) || currentWeekStart.isAtSameMomentAs(lastDate)) {
    // Calculer la date de fin de la semaine (dimanche)
    DateTime currentWeekEnd = currentWeekStart.add(Duration(days: 6));

    // Formater les dates pour afficher la semaine au format "6-12 janvier", "13-19 janvier", etc.
    String weekRange = '${DateFormat('d', JwLifeApp.locale.languageCode).format(currentWeekStart)}-${DateFormat('d MMMM', JwLifeApp.locale.languageCode).format(currentWeekEnd)}';
    weeksList.add(weekRange);
    weeksStartDates.add(currentWeekStart);

    // Passer à la semaine suivante
    currentWeekStart = currentWeekStart.add(Duration(days: 7));
  }

  // Trouver l'index de la semaine actuelle
  int currentWeekIndex = weeksStartDates.indexWhere((weekStart) => weekStart.isAtSameMomentAs(currentDate.subtract(Duration(days: currentDate.weekday - 1))));

  // Afficher un dialogue pour la sélection de la semaine
  String? selectedWeek = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: double.infinity,  // Utiliser toute la largeur du dialogue
          padding: EdgeInsets.symmetric(vertical: 5),  // Padding vertical pour le dialogue
          child: Column(
            mainAxisSize: MainAxisSize.min,  // Ajuster la taille pour ne pas prendre trop de place
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Sélectionner une semaine',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Divider(color: Colors.black),  // Ligne de séparation en haut
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: weeksList.asMap().map((index, week) {
                      return MapEntry(
                        index,
                        Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),  // Réduire l'espace autour
                              title: Text(week),
                              leading: Radio<String>(
                                value: week,
                                groupValue: weeksList[currentWeekIndex],
                                onChanged: (String? value) {
                                  Navigator.pop(context, value);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context, week);  // Retourner la semaine sélectionnée
                              },
                            ),
                            Divider(color: Colors.black, thickness: 1), // Séparation noire
                          ],
                        ),
                      );
                    }).values.toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  // Si une semaine a été sélectionnée, retourner la date du lundi de cette semaine
  if (selectedWeek != null && selectedWeek.isNotEmpty) {
    int selectedIndex = weeksList.indexOf(selectedWeek);
    DateTime selectedWeekStart = weeksStartDates[selectedIndex];
    return DateFormat('yyyyMMdd').format(selectedWeekStart);  // Retourne le premier jour de la semaine au format 'yyyy-MM-dd'
  }

  return '';  // Retourne une chaîne vide si aucune semaine n'est sélectionnée
}

Future showLibraryLanguageDialog(BuildContext context) {
  LanguageDialog languageDialog = LanguageDialog();
  return showDialog(
    context: context,
    builder: (context) => languageDialog,
  );
}