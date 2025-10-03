import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/assets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Remplacer l'image par un SVG avec la couleur principale du thème
            Container(
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                // La bordure arrondie sur le fond blanc
                borderRadius: BorderRadius.circular(0.0),
              ),
              child: ClipRRect(
                // 💡 Définir le MÊME rayon d'arrondi sur ClipRRect
                borderRadius: BorderRadius.circular(0.0),
                child: SvgPicture.asset(
                  Assets.assetsIconsJwLife,
                  width: 160,
                  height: 160,
                  colorFilter: ColorFilter.mode(Color(0xFF143368), BlendMode.srcIn),
                ),
              ),
            ),

            const SizedBox(height: 4),
            // Indicateur de progression avec une hauteur plus petite
            SizedBox(
              height: 4, // Hauteur personnalisée de l'indicateur
              width: 160,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                backgroundColor: Color(0xFF686868)
              ),
            ),
          ],
        ),
      ),
    );
  }
}