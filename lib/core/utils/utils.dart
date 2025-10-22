import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import 'package:image/image.dart' as img;

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

String normalize(String s) {
  return removeDiacritics(s).toLowerCase();
}

int convertDateTimeToIntDate(DateTime dateTime) {
  String formatted = DateFormat('yyyyMMdd').format(dateTime);
  return int.parse(formatted);
}

int durationSecondsToTicks(double seconds) {
  return (seconds * 10000000).round();
}

String formatTick(int ticks) {
  // 1 tick = 100 ns → 10 000 000 ticks = 1 seconde
  double totalSeconds = ticks / 10000000;

  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60 ~/ 1;
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

DateTime formatDateTime(String isoString) {
  // Convertir la chaîne ISO 8601 en objet DateTime
  DateTime dateTime = DateTime.parse(isoString).toLocal();
  return dateTime;
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

String timeAgo(DateTime dateTime) {
  final Duration diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'il y a quelques secondes';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} minutes';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} heures';
  return 'il y a ${diff.inDays} jours';
}

Future<int> getDirectorySize(Directory dir) async {
  int size = 0;
  if (await dir.exists()) {
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
  }
  return size;
}

String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  int i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

Future<Color> getDominantColorFromFile(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 40,
      targetHeight: 40,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return const Color(0xFFE0E0E0);

    final pixels = byteData.buffer.asUint8List();

    Map<String, int> colorFrequency = {};

    // Échantillonner tous les 4 pixels pour optimiser
    for (int i = 0; i < pixels.length; i += 16) {
      if (i + 3 < pixels.length) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];

        // Grouper les couleurs similaires (réduire la précision)
        final groupedR = (r ~/ 32) * 32;
        final groupedG = (g ~/ 32) * 32;
        final groupedB = (b ~/ 32) * 32;

        final colorKey = '$groupedR,$groupedG,$groupedB';
        colorFrequency[colorKey] = (colorFrequency[colorKey] ?? 0) + 1;
      }
    }

    final dominantColorKey = colorFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final parts = dominantColorKey.split(',');
    return Color.fromARGB(
      255,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  } catch (e) {
    return const Color(0xFFE0E0E0);
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
    printTime("Aucune connexion Internet !");
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

img.Image resizeAndCropCenter(img.Image originalImage, int targetSize) {
  // 1) Redimensionner l'image pour que la hauteur soit targetSize, garder ratio
  int newHeight = targetSize;
  int newWidth = (originalImage.width * newHeight / originalImage.height).round();

  img.Image resized = img.copyResize(originalImage, width: newWidth, height: newHeight);

  // 2) Si la largeur est plus grande que targetSize, crop au centre horizontalement
  if (newWidth > targetSize) {
    int left = (newWidth - targetSize) ~/ 2;
    return img.copyCrop(resized, x: left, y: 0, width: targetSize, height: targetSize);
  }

  // Si la largeur est déjà <= targetSize, retourner l'image redimensionnée telle quelle
  return resized;
}

String toHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}