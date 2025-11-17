import 'package:flutter/material.dart';

class ConditionalSizedWidget extends StatelessWidget {
  final String title;
  final String subtitle;

  const ConditionalSizedWidget({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Définition des styles standards pour le titre et le sous-titre
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black,
      height: 1.1,
    );

    // Style de sous-titre par défaut (12)
    final TextStyle defaultSubtitleStyle = TextStyle(
      fontSize: 12,
      color: subtitleColor,
    );

    // Style de sous-titre conditionnel (16)
    final TextStyle largeSubtitleStyle = TextStyle(
      fontSize: 15,
      color: subtitleColor,
    );

    // Suppression de l'Expanded ici.
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. Initialiser le TextPainter pour le titre
        final TextPainter textPainter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: TextDirection.ltr,
          maxLines: 2, // Limiter la vérification à 2 lignes (ou plus)
        );

        // 2. Calculer la taille du texte avec les contraintes de largeur du parent
        textPainter.layout(minWidth: 0, maxWidth: constraints.maxWidth);

        // Détermine si le titre dépasse la hauteur définie pour 2 lignes
        final bool titleTakesTwoLines = textPainter.didExceedMaxLines;

        final TextStyle currentSubtitleStyle =
        titleTakesTwoLines ? defaultSubtitleStyle : largeSubtitleStyle;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: currentSubtitleStyle, // Style ajusté
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: titleStyle,
            ),
          ],
        );
      },
    );
  }
}