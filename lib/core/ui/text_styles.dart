import 'package:flutter/material.dart';

// 1. Définir votre classe qui étend ThemeExtension
class JwLifeThemeStyles extends ThemeExtension<JwLifeThemeStyles> {
  final TextStyle appBarTitle;
  final TextStyle appBarSubTitle;
  final TextStyle squareTitle;
  final TextStyle rectanglePublicationTitle;
  final TextStyle rectanglePublicationContext;
  final TextStyle rectanglePublicationSubtitle;
  final TextStyle rectangleMediaItemTitle;
  final TextStyle rectangleMediaItemSubTitle;
  final TextStyle rectangleMediaItemLargeTitle;
  final TextStyle categoryTitle;
  final TextStyle labelTitle;

  final Color containerColor;
  final Color otherColor;


  // Constructeur constant : Toutes les propriétés DOIVENT être requises
  const JwLifeThemeStyles({
    required this.appBarTitle,
    required this.appBarSubTitle,
    required this.squareTitle,
    required this.rectanglePublicationTitle,
    required this.rectanglePublicationContext,
    required this.rectanglePublicationSubtitle,
    required this.rectangleMediaItemTitle,
    required this.rectangleMediaItemSubTitle,
    required this.rectangleMediaItemLargeTitle,
    required this.categoryTitle,
    required this.labelTitle,

    required this.containerColor,
    required this.otherColor,
  });

// --- Implémentations Obligatoires ---

  // 2. Implémenter copyWith : Gérer la copie et le remplacement des styles
  @override
  JwLifeThemeStyles copyWith({
    TextStyle? appBarTitle,
    TextStyle? appBarSubTitle,
    TextStyle? squareTitle,
    TextStyle? rectanglePublicationTitle,
    TextStyle? rectanglePublicationContext,
    TextStyle? rectanglePublicationSubtitle,
    TextStyle? rectangleMediaItemTitle,
    TextStyle? rectangleMediaItemSubTitle,
    TextStyle? rectangleMediaItemLargeTitle,
    TextStyle? categoryTitle,
    TextStyle? labelTitle,

    Color? containerColor,
    Color? otherColor,
  }) {
    return JwLifeThemeStyles(
      // Si la nouvelle valeur est nulle, on garde l'ancienne (this.propriété)
      appBarTitle: appBarTitle ?? this.appBarTitle,
      appBarSubTitle: appBarSubTitle ?? this.appBarSubTitle,
      squareTitle: squareTitle ?? this.squareTitle,
      rectanglePublicationTitle: rectanglePublicationTitle ?? this.rectanglePublicationTitle,
      rectanglePublicationContext: rectanglePublicationContext ?? this.rectanglePublicationContext,
      rectanglePublicationSubtitle: rectanglePublicationSubtitle ?? this.rectanglePublicationSubtitle,
      rectangleMediaItemTitle: rectangleMediaItemTitle ?? this.rectangleMediaItemTitle,
      rectangleMediaItemSubTitle: rectangleMediaItemSubTitle ?? this.rectangleMediaItemSubTitle,
      rectangleMediaItemLargeTitle: rectangleMediaItemLargeTitle ?? this.rectangleMediaItemLargeTitle,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      labelTitle: labelTitle ?? this.labelTitle,

      containerColor: containerColor ?? this.containerColor,
      otherColor: otherColor ?? this.otherColor,
    );
  }

  // 3. Implémenter lerp : Gérer la transition (interpolation) entre deux thèmes
  @override
  JwLifeThemeStyles lerp(covariant ThemeExtension<JwLifeThemeStyles>? other, double t) {
    if (other is! JwLifeThemeStyles) {
      return this;
    }

    // Utiliser TextStyle.lerp pour chaque propriété
    return JwLifeThemeStyles(
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      appBarSubTitle: TextStyle.lerp(appBarSubTitle, other.appBarSubTitle, t)!,
      squareTitle: TextStyle.lerp(squareTitle, other.squareTitle, t)!,
      rectanglePublicationTitle: TextStyle.lerp(rectanglePublicationTitle, other.rectanglePublicationTitle, t)!,
      rectanglePublicationContext: TextStyle.lerp(rectanglePublicationContext, other.rectanglePublicationContext, t)!,
      rectanglePublicationSubtitle: TextStyle.lerp(rectanglePublicationSubtitle, other.rectanglePublicationSubtitle, t)!,
      rectangleMediaItemTitle: TextStyle.lerp(rectangleMediaItemTitle, other.rectangleMediaItemTitle, t)!,
      rectangleMediaItemSubTitle: TextStyle.lerp(rectangleMediaItemSubTitle, other.rectangleMediaItemSubTitle, t)!,
      rectangleMediaItemLargeTitle: TextStyle.lerp(rectangleMediaItemLargeTitle, other.rectangleMediaItemLargeTitle, t)!,
      categoryTitle: TextStyle.lerp(categoryTitle, other.categoryTitle, t)!,
      labelTitle: TextStyle.lerp(labelTitle, other.labelTitle, t)!,

      containerColor: Color.lerp(containerColor, other.containerColor, t)!,
      otherColor: Color.lerp(otherColor, other.otherColor, t)!,
    );
  }
}