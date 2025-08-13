import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/jwlife_app.dart';
import 'app/services/global_key_service.dart';
import 'app/services/notification_service.dart';

Future<void> main() async {
  // Assure l'initialisation correcte des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);

  // On met la barre de navigation en mode edgeToEdge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SharedPreferences.setPrefix('jwlife.'); // une seule fois ici

  // On initialise les notifications locales
  NotificationService().initNotification();

  // Initialise le service de lecture audio avec une notification persistante sur Android
  JustAudioBackground.init(
    androidNotificationChannelId: 'org.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'JW Audio',
    androidNotificationOngoing: true,
    preloadArtwork: true
  );

  // Initialise les configurations de l'application
  await JwLifeSettings().init();

  // Lance l'application Flutter
  runApp(JwLifeApp(key: GlobalKeyService.jwLifeAppKey));
}
