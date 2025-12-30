const double kAudioHeight = 80;

// Largeur maximale des tuiles pour les grilles responsives
const double kMaxItemWidth = 300.0;

// Espacement entre les tuiles de la grille
const double kSpacing = 2.0;

// Hauteur harmonisée des éléments de liste (RectanglePublicationItem)
const double kCategoriesHeight = 80.0;
const double kItemHeight = 80.0;
const double kAudioItemHeight = 55.0;

const double kFontBase = 15.0;

const double kMaxMenuItemWidth = 700.0;

double getContentPadding(double screenWidth) {
  // Définir un facteur de mise à l'échelle basé sur la largeur,
  // par exemple, une échelle de 0.01 (1% de la largeur)
  const double scaleFactor = 0.015;

  // Calculer un padding initial basé sur le facteur et la largeur
  double calculatedPadding = screenWidth * scaleFactor;

  // Assurer que le padding est au minimum 8.0 et au maximum 16.0
  return calculatedPadding.clamp(8.0, 16.0);
}