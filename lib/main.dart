import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/jwlife_app.dart';
import 'app/services/settings_service.dart';
import 'app/services/audio_service/just_audio_background.dart';
import 'app/services/file_handler_service.dart';
import 'app/services/global_key_service.dart';
import 'app/services/notification_service.dart';
import 'core/uri/jworg_uri.dart';
import 'core/webview/html_template_service.dart';
import 'data/realm/realm_library.dart';

// Constante pour le préfixe SharedPreferences
const String _kSharedPrefsPrefix = 'jwlife.';

/// Exécute toutes les initialisations asynchrones nécessaires
Future<void> _initializeServices() async {
  // 1. Initialisations de bas niveau
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Activation du debug pour InAppWebView uniquement en mode debug
    InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);

  // 2. Configuration et Initialisation des Services
  SharedPreferences.setPrefix(_kSharedPrefsPrefix); // Fait une seule fois

  // Exécutions en parallèle (si possible) pour améliorer le temps de démarrage
  await Future.wait([
    // Initialisation des notifications locales
    NotificationService().initNotification(),
    // Initialisation du service de fichiers
    FileHandlerService().initialize(),
    // Initialisation des templates HTML
    HtmlTemplateService().initialize(),
    // Initialisation des configurations de l'application
    JwLifeSettings.instance.init(),
    // Initialisation de la base de données Realm
    RealmLibrary.init()
  ]);

  // 3. Configuration de Just Audio Background (nécessite d'être après ensureInitialized)
  JustAudioBackground.init(
    androidNotificationChannelId: 'org.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'Lecteur audio',
    androidNotificationChannelDescription: 'Lecteur audio de JW Life',
    androidNotificationOngoing: true,
    preloadArtwork: true,
    showStopControl: false,
    leftMediaControl: LeftMediaControl.skipToPrevious,
    rightMediaControl: RightMediaControl.skipToNext,
  );
}

/// Gère le lancement de l'application via une notification
Future<void> _handleNotificationLaunch() async {
  final launchDetails = await NotificationService().notificationPlugin.getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp == true) {
    final response = launchDetails!.notificationResponse;
    if (response != null && response.payload != null) {
      // Utilisez debugPrint en mode debug pour des messages qui n'apparaissent pas en production
      debugPrint('App lancée via notification: ${response.payload}');
      JwOrgUri.startUri = JwOrgUri.parse(response.payload!);
    }
  }
}

Future<void> main() async {
  printTime('Start app at:');
  // Exécute toutes les initialisations
  await _initializeServices();

  // Traiter l'éventuel lancement par notification (après l'init du service de notification)
  await _handleNotificationLaunch();

  // Lance l'application Flutter
  runApp(JwLifeApp(key: GlobalKeyService.jwLifeAppKey));
}