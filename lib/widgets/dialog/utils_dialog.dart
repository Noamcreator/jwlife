import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';

import 'language_dialog.dart';

class JwDialogButton {
  final String label;
  final bool closeDialog;
  final Function(BuildContext)? onPressed;
  final dynamic result;

  JwDialogButton({
    required this.label,
    this.closeDialog = true,
    this.onPressed,
    this.result,
  });
}


Future<T?> showJwDialog<T>({
  required BuildContext context,
  Widget? title,
  String? titleText,
  Widget? content,
  String? contentText,
  List<JwDialogButton> buttons = const [],
  MainAxisAlignment buttonAxisAlignment = MainAxisAlignment.spaceBetween,
}) {
  return showDialog<T>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF353535)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(3),
          ),
          margin: const EdgeInsets.all(0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (title != null || titleText != null)
                const SizedBox(height: 20),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: title
                ),
              if (titleText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    titleText,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFFFFFFF) : Color(0xFF212121),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (content != null || contentText != null)
                SizedBox(height: (title == null && titleText == null) ? 18 : 15),
              if (content != null)
                content,
              if (contentText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    contentText,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFB1B1B1) : Color(0xFF676767),
                      fontSize: 16,
                    ),
                  ),
                ),
              if (contentText != null)
                const SizedBox(height: 10),
              if (buttons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: buttonAxisAlignment,
                    children: buttons.map((btn) {
                      return TextButton(
                        onPressed: () {
                          if (btn.closeDialog) {
                            Navigator.of(context).pop(btn.result);
                          }
                          btn.onPressed?.call(context);
                        },
                        child: Text(
                          btn.label,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      );
    },
  );
}

Future<T?> showJwChoiceDialog<T>({
  required BuildContext context,
  required String titleText,
  required String contentText,
  required List<T> choices,
  required T initialSelection,
  String Function(T)? display,
}) {
  return showDialog<T>(
    context: context,
    builder: (BuildContext context) {
      T? selected = initialSelection;

      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF353535)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(3),
              ),
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      contentText,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final item = choices[index];
                        final isSelected = item == selected;
                        return RadioListTile<T>(
                          title: Text(display?.call(item) ?? item.toString()),
                          value: item,
                          groupValue: selected,
                          onChanged: (val) => setState(() => selected = val),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('ANNULER'),
                        onPressed: () => Navigator.pop(context, null),
                      ),
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context, selected),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


Future<void> showNoConnectionDialog(BuildContext context) async{
  showJwDialog(
    context: context,
    contentText: 'Connectez-vous à Internet.',
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: 'OK',
        onPressed: (buildContext) {
          Navigator.of(buildContext).pop();
        },
      ),
      JwDialogButton(
        label: 'PARAMÈTRES',
        onPressed: (buildContext) {
          AppSettings.openAppSettings(type: AppSettingsType.wifi);
        },
      ),
    ],
  );
}

Future<DateTime> showWeekSelectionDialog(BuildContext context, DateTime initialDate) async {
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

  List<Map<String, dynamic>> result = await db.rawQuery(query, [JwLifeApp.settings.currentLanguage.id]);

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
    String weekRange = '${DateFormat('d', JwLifeApp.settings.locale.languageCode).format(currentWeekStart)}-${DateFormat('d MMMM', JwLifeApp.settings.locale.languageCode).format(currentWeekEnd)}';
    weeksList.add(weekRange);
    weeksStartDates.add(currentWeekStart);

    // Passer à la semaine suivante
    currentWeekStart = currentWeekStart.add(Duration(days: 7));
  }

  // Trouver l'index de la semaine où initialDate se trouve
  int selectedWeekIndex = weeksStartDates.indexWhere((weekStart) {
    // Vérifier si initialDate est dans cette semaine (du lundi au dimanche)
    DateTime currentWeekEnd = weekStart.add(Duration(days: 6));
    return initialDate.isAfter(weekStart.subtract(Duration(days: 1))) && initialDate.isBefore(currentWeekEnd.add(Duration(days: 1)));
  });

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
                                groupValue: weeksList[selectedWeekIndex],
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
    return weeksStartDates[selectedIndex];
  }

  return DateTime.now();  // Retourne une chaîne vide si aucune semaine n'est sélectionnée
}

Future showLibraryLanguageDialog(BuildContext context) {
  LanguageDialog languageDialog = LanguageDialog();
  return showDialog(
    context: context,
    builder: (context) => languageDialog,
  );
}