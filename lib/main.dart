import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';

import 'app/jwlife_app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'JW Audio',
    androidNotificationOngoing: true
  );

  await Firebase.initializeApp(
    name: 'JW Life',
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final theme = await getTheme();
  final themeMode = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
  final lightData = await getPrimaryColor(ThemeMode.light);
  final darkData = await getPrimaryColor(ThemeMode.dark);
  final locale = await getLocale();

  runApp(JwLifeApp());

  JwLifeApp.theme = themeMode;
  JwLifeApp.locale = Locale(locale);
  JwLifeApp.lightData = AppTheme.getLightTheme(lightData);
  JwLifeApp.darkData = AppTheme.getDarkTheme(darkData);
}