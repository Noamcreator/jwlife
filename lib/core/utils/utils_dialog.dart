import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/services/settings_service.dart';
import '../../i18n/i18n.dart';
import '../icons.dart';

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
                        child: Text(i18n().action_cancel_uppercase),
                        onPressed: () => Navigator.pop(context, null),
                      ),
                      TextButton(
                        child: Text(i18n().action_ok),
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


Future<void> showNoConnectionDialog(BuildContext context) async {
  showJwDialog(
    context: context,
    contentText: i18n().message_no_internet_connection,
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: i18n().action_ok,
        closeDialog: true,
      ),
      JwDialogButton(
        label: i18n().action_settings_uppercase,
        onPressed: (buildContext) {
          AppSettings.openAppSettings(type: AppSettingsType.wifi);
        },
      ),
    ],
  );
}

Future<DateTime?> showMonthCalendarDialog(BuildContext context, DateTime initialDate) async {
  final locale = JwLifeSettings.instance.locale.languageCode;

  // Pour afficher le mois et l'année
  String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', locale).format(date);
  }

  List<DateTime> getCalendarDays(DateTime date) {
    DateTime firstOfMonth = DateTime(date.year, date.month, 1);
    DateTime lastOfMonth = DateTime(date.year, date.month + 1, 0);

    // Début = lundi précédent ou égal au 1er du mois
    DateTime startCalendar = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    // Fin = dimanche suivant ou égal à la fin du mois
    DateTime endCalendar = lastOfMonth.add(Duration(days: 7 - lastOfMonth.weekday));

    List<DateTime> days = [];
    DateTime day = startCalendar;
    while (!day.isAfter(endCalendar)) {
      days.add(day);
      day = day.add(Duration(days: 1));
    }
    return days;
  }

  DateTime selectedDay = initialDate;
  DateTime displayedMonth = DateTime(initialDate.year, initialDate.month);

  DateTime? result = await showDialog<DateTime>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          List<DateTime> days = getCalendarDays(displayedMonth);

          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête avec mois/année et navigation mois précédent/suivant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(JwIcons.chevron_left),
                        onPressed: () {
                          setState(() {
                            displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        formatMonthYear(displayedMonth),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(JwIcons.chevron_right),
                        onPressed: () {
                          setState(() {
                            displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),

                  const Divider(),

                  // Noms des jours en entête (Lun, Mar, Mer, ...)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      // DateTime weekday: 1 = lundi ... 7 = dimanche
                      final dayName = DateFormat.E(locale).format(DateTime(2021, 8, index + 2)); // 2 août 2021 est lundi
                      return Expanded(
                        child: Center(
                          child: Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  // Grille des jours du mois avec 7 colonnes
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        DateTime day = days[index];
                        bool isInMonth = day.month == displayedMonth.month;
                        bool isSelected = day.year == selectedDay.year &&
                            day.month == selectedDay.month &&
                            day.day == selectedDay.day;

                        return GestureDetector(
                          onTap: isInMonth
                              ? () {
                            setState(() {
                              selectedDay = day;
                            });
                          }
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : isInMonth
                                  ? Colors.grey.shade200
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(0),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isInMonth
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedDay = DateTime.now();
                        displayedMonth = DateTime.now();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(i18n().action_reset_today_uppercase)
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            i18n().action_cancel_uppercase,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                        ),
                        SizedBox(width: 16),
                        TextButton(
                          child: Text(
                            i18n().action_ok,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, selectedDay);
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}