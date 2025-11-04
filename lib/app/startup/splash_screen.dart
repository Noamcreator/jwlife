import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/assets.dart'; // Assurez-vous que ce chemin est correct

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupère la couleur principale du thème (Primary Color)
    final Color primaryColor = Theme.of(context).primaryColor;

    // Utilise une couleur dérivée du thème pour l'arrière-plan de la progress bar,
    // garantissant une bonne visibilité quel que soit le thème (clair/sombre).
    final Color progressBackgroundColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.2);

    return Scaffold(
      // Le fond du Scaffold est souvent blanc ou la couleur de fond du thème
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // --- LOGO SVG ---
            Container(
              color: Colors.white,
              child: SvgPicture.asset(
                Assets.assetsIconsJwLife, // Assurez-vous que cette référence est correcte
                width: 150,
                height: 150,
                // Applique la couleur principale du thème au SVG
                colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
              ),
            ),

            const SizedBox(height: 4), // Augmentation de l'espace pour une meilleure esthétique

            // --- INDICATEUR DE PROGRESSION ---
            SizedBox(
              height: 3,
              width: 150, // Doit correspondre à la largeur du logo pour l'alignement
              child: LinearProgressIndicator(
                // Couleur de la barre de progression
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  // Couleur de fond de la barre
                  backgroundColor: progressBackgroundColor
              ),
            ),
          ],
        ),
      ),
    );
  }
}
