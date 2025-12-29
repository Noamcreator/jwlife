import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';

class BibleColorGroup {
  static Color getGroupColorAt(int groupId) {
    final Color bibleColor = JwLifeSettings.instance.bibleColor;
    final bool isDark = Theme.of(GlobalKeyService.jwLifePageKey.currentContext!).brightness == Brightness.dark;

    // Fonction utilitaire pour ajuster la luminosité
    // Valeur négative pour assombrir
    Color adjustLightness(Color color, double amount) {
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor().withOpacity(isDark ? 0.7 : 0.9);
    }

    switch (groupId) {
      case 0:
      case 3:
      case 4:
      case 7:
      // On assombrit la couleur de 15% (ajuste la valeur selon tes besoins)
        return adjustLightness(bibleColor, isDark ? -0.15 : -0.1);

      case 1:
      case 5:
      // Variante plus claire (20% de luminosité en plus)
        return adjustLightness(bibleColor, isDark ? 0.1 : 0);

      case 2:
      case 6:
      // Variante légèrement plus claire (10% de luminosité en plus)
        return adjustLightness(bibleColor, isDark ? 0 : 0.05);

      default:
        return bibleColor;
    }
  }
}