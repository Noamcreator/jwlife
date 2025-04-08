import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/app/jw_settings.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';

import 'app/jwlife_app.dart';

Future<void> main() async {
  // Assure l'initialisation correcte des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Configure le mode d'affichage du système (utilisation de la zone complète de l'écran)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialise le service de lecture audio avec une notification persistante sur Android
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'JW Audio',
    androidNotificationOngoing: true,
  );

  // Initialise Firebase avec les options spécifiques à la plateforme
  //await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Active la persistance hors ligne pour Firestore
  //FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  JwSettings jwSettings = JwSettings();

  // Initialise les configurations de l'application
  JwLifeApp jwLifeApp = JwLifeApp();

  JwLifeApp.settings = jwSettings;

  // Lance l'application Flutter
  runApp(jwLifeApp);
}
