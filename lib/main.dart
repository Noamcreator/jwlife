import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/app/services/settings_service.dart';

import 'app/jwlife_app.dart';

Future<void> main() async {
  // Assure l'initialisation correcte des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // On met la barre de navigation en mode edgeToEdge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialise le service de lecture audio avec une notification persistante sur Android
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'JW Audio',
    androidNotificationOngoing: true,
  );

  // Initialise les configurations de l'application
  await JwLifeSettings().init();

  // Lance l'application Flutter
  runApp(JwLifeApp());
}
