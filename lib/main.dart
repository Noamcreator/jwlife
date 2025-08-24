import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/jwlife_app.dart';
import 'app/services/file_handler_service.dart';
import 'app/services/global_key_service.dart';
import 'app/services/notification_service.dart';
import 'core/jworg_uri.dart';

Future<void> main() async {
  // Assure l'initialisation correcte des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);

  // On met la barre de navigation en mode edgeToEdge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SharedPreferences.setPrefix('jwlife.'); // une seule fois ici

  // On initialise les notifications locales
  await NotificationService().initNotification();

  // Vérifier si l'app a été lancée via une notification
  final launchDetails = await NotificationService().notificationPlugin.getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp == true) {
    final response = launchDetails!.notificationResponse;
    if (response != null) {
      // Traiter la notification qui a lancé l'app
      print('App lancée via notification: ${response.payload}');
      // Vous pouvez stocker cette info pour la traiter plus tard
      JwOrgUri.startUri = JwOrgUri.parse(response.payload!);
    }
  }

  // Initialiser le service de fichiers
  await FileHandlerService().initialize();

  // Définir le callback pour les fichiers reçus
  FileHandlerService().onFileReceived = (filePath, fileType) {
    print('Fichier reçu: $filePath de type $fileType');

    switch (fileType) {
      case 'jwlibrary':
        FileHandlerService().processJwLibraryFile(filePath);
        break;
      case 'jwplaylist':
        FileHandlerService().processJwPlaylistFile(filePath);
        break;
      case 'jwpub':
        FileHandlerService().processJwPubFile(filePath);
        break;
    }
  };

  // NOUVEAU: Callback pour les URLs JW.org
  FileHandlerService().onUrlReceived = (url) {
    print('URL JW.org reçue: $url');
    FileHandlerService().processJwOrgUrl(url);
  };

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
