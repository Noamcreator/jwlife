import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwlife/jwlife.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.noam.jwlife.channel.audio',
    androidNotificationChannelName: 'Jw Audio',
    androidNotificationOngoing: true
  );
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
  runApp(JwLifeApp(isDarkTheme: isDarkTheme));
}