import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Logo de votre application
            Image.asset(
              'assets/icons/jw_life.png',
              width: 160,
              height: 160,
            ),
            const SizedBox(height: 5),
            // Indicateur de progression avec une hauteur plus petite
            SizedBox(
              height: 4, // Hauteur personnalisée de l'indicateur
              width: 150,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), // Couleur de remplissage de l'indicateur
              ),
            ),
          ],
        ),
      ),
    );
  }
}
