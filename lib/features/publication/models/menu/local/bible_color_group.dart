import 'package:flutter/material.dart';

class BibleColorGroup {
  static Color getGroupColorAt(BuildContext context, int groupId) {
    final primaryColor = Theme.of(context).primaryColor;

    // Vous pouvez ajuster les couleurs selon le groupId
    switch (groupId) {
      case 0:
        return primaryColor.withOpacity(0.5);
      case 1:
        return primaryColor.withOpacity(1.0); // Variante plus claire
      case 2:
        return primaryColor.withOpacity(0.7); // Variante intermédiaire
      case 3:
        return primaryColor.withOpacity(0.4);
      case 4:
        return primaryColor.withOpacity(0.5);
      case 5:
        return primaryColor.withOpacity(1.0); // Variante plus claire
      case 6:
        return primaryColor.withOpacity(0.7); // Variante intermédiaire
      case 7:
        return primaryColor.withOpacity(0.5);
      default:
        return primaryColor; // Valeur par défaut si le groupId ne correspond à aucun cas
    }
  }
}
