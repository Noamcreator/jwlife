import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

String formatDuration(double duration) {
  // Convertir la durée en secondes
  int totalSeconds = duration.toInt(); // Supposons que 'duration' est en secondes

  // Calculer les heures, minutes et secondes
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  // Formater les secondes pour avoir deux chiffres
  String formattedSeconds = seconds.toString().padLeft(2, '0');
  String formattedMinutes = minutes.toString().padLeft(2, '0');

  // Retourner la durée formatée avec ou sans les heures
  if (hours > 0) {
    return '$hours:$formattedMinutes:$formattedSeconds';
  } else {
    return '$minutes:$formattedSeconds';
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B'; // Retourne la taille en octets
  } else if (bytes < 1024 * 1024) {
    double kb = bytes / 1024;
    int roundedKb = kb.ceil(); // Arrondir à l'entier supérieur
    return '$roundedKb Ko'; // Retourne la taille en kilo-octets
  } else if (bytes < 1024 * 1024 * 1024) {
    double mb = bytes / (1024 * 1024);
    int roundedMb = mb.ceil(); // Arrondir à l'entier supérieur
    return '$roundedMb Mo'; // Retourne la taille en mégaoctets
  } else {
    double gb = bytes / (1024 * 1024 * 1024);
    int roundedGb = gb.ceil(); // Arrondir à l'entier supérieur
    return '$roundedGb Go'; // Retourne la taille en gigaoctets
  }
}


String convertHtmlToText(String html) {
  return html == '' ? '' : html.replaceAll(RegExp(r"<[^>]*>"), '').trim();
}

bool isPortrait(BuildContext context) {
  return MediaQuery.of(context).orientation == Orientation.portrait;
}

bool isLandscape(BuildContext context) {
  return MediaQuery.of(context).orientation == Orientation.landscape;
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

bool isMobile(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide < 600;
}

bool isIOS(BuildContext context) {
  return Theme.of(context).platform == TargetPlatform.iOS;
}

bool isAndroid(BuildContext context) {
  return Theme.of(context).platform == TargetPlatform.android;
}

bool isWindows(BuildContext context) {
  return Theme.of(context).platform == TargetPlatform.windows;
}

Future<bool> hasInternetConnection() async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    print("Aucune connexion Internet !");
    return false;
  }
  else {
    return true;
  }
}