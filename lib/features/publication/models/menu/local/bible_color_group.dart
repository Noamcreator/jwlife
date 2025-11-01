import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';

class BibleColorGroup {
  static Color getGroupColorAt(int groupId) {
    final bibleColor = JwLifeSettings().bibleColor;

    // Vous pouvez ajuster les couleurs selon le groupId
    switch (groupId) {
      case 0:
        return bibleColor.withOpacity(0.5);
      case 1:
        return bibleColor.withOpacity(1.0); // Variante plus claire
      case 2:
        return bibleColor.withOpacity(0.7); // Variante intermédiaire
      case 3:
        return bibleColor.withOpacity(0.4);
      case 4:
        return bibleColor.withOpacity(0.5);
      case 5:
        return bibleColor.withOpacity(1.0); // Variante plus claire
      case 6:
        return bibleColor.withOpacity(0.7); // Variante intermédiaire
      case 7:
        return bibleColor.withOpacity(0.5);
      default:
        return bibleColor; // Valeur par défaut si le groupId ne correspond à aucun cas
    }
  }
}
