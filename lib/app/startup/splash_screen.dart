import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            SvgPicture.asset(
              'assets/icons/jw_life.svg',
              width: 160,
              height: 160,
              color: Theme.of(context).primaryColor,  // Appliquer la couleur principale du thème
            ),
            const SizedBox(height: 5),
            // Indicateur de progression avec une hauteur plus petite
            SizedBox(
              height: 4, // Hauteur personnalisée de l'indicateur
              width: 160,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                backgroundColor: Colors.grey[300]
              ),
            ),
          ],
        ),
      ),
    );
  }
}