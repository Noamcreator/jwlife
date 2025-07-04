
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

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

Duration parseDuration(String startTime) {
  // Vérifiez que la chaîne est au bon format
  final RegExp regExp = RegExp(r'(\d{2}):(\d{2}):(\d{2})\.(\d{3})');
  final match = regExp.firstMatch(startTime);

  if (match != null) {
    // Extraire les heures, minutes, secondes et millisecondes
    final int hours = int.parse(match.group(1)!);
    final int minutes = int.parse(match.group(2)!);
    final int seconds = int.parse(match.group(3)!);
    final int milliseconds = int.parse(match.group(4)!);

    // Retourner la durée en secondes et millisecondes
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }

  // Si la chaîne ne correspond pas au format, retourner une durée nulle
  return Duration.zero;
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

Future<String> sha256hashOfFile(String filePath) async {
  var file = File(filePath);
  List<int> fileBytes = await file.readAsBytes(); // Utilisation de la version asynchrone
  var hash = sha256.convert(fileBytes);
  return hash.toString();
}

void printTime(String printText) async {
  DateTime now = DateTime.now();
  String formattedTime = DateFormat('HH:mm:ss:SS').format(now);
  debugPrint("$formattedTime: $printText");
}

Future<bool> tableExists(Database db, String tableName) async {
  final result = await db.rawQuery('''
    SELECT name FROM sqlite_master 
    WHERE type='table' AND name=?
  ''', [tableName]);
  return result.isNotEmpty;
}