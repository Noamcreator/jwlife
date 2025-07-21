import 'package:flutter/material.dart';

class Note {
  static Color getColor(var context, int index) {
    switch (index % 7) {
      case 0:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.grey[300]!;
      case 1:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF49400e) : Colors.yellow[200]!;
      case 2:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF233315) : Colors.green[200]!;
      case 3:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF203646) : Colors.blue[200]!;
      case 4:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF401f2c) : Colors.pink[200]!;
      case 5:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF49290e) : Colors.orange[200]!;
      case 6:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF2d2438) : Colors.purple[200]!;
      default:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.grey[300]!; // Si jamais index est supérieur à 5, retourne par défaut la couleur grise
    }
  }

  static String dateTodayToCreated(String lastModif) {
    DateTime lastModified = DateTime.parse(lastModif);

    // Obtenir la date d'aujourd'hui
    DateTime today = DateTime.now();

    // Calculer la différence en jours entre la date de dernière modification et aujourd'hui
    int differenceInDays = today.difference(lastModified).inDays;

    if (differenceInDays <= 30) {
      // Si la différence est inférieure ou égale à 30 jours, retourner le nombre de jours écoulés
      return 'Il y a $differenceInDays jours';
    } else {
      // Si la différence dépasse 30 jours, formater la date de dernière modification
      // au format "jour mois" (par exemple, "26 mars")
      String formattedDate = '${lastModified.day} ${_getMonthName(lastModified.month)}';
      return formattedDate;
    }
  }

  static String _getMonthName(int month) {
    // Tableau des noms des mois
    List<String> monthNames = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];

    // Retourner le nom du mois correspondant à l'indice
    return monthNames[month - 1]; // -1 car les indices commencent à 0
  }
}