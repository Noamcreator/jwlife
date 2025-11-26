import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:sqflite/sqflite.dart';

import 'package:image/image.dart' as img;

import '../../i18n/i18n.dart';

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
  BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.context;
  String locale = Localizations.localeOf(context).languageCode;

  // Convertir la durée en secondes
  int totalSeconds = duration.toInt();
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  // Formatter normal
  final numberFormatter = NumberFormat('00', locale);

  String formattedSeconds = numberFormatter.format(seconds);
  String formattedMinutes = numberFormatter.format(minutes);
  String formattedHours = numberFormatter.format(hours);

  String result = (hours > 0)
      ? '$formattedHours:$formattedMinutes:$formattedSeconds'
      : '$formattedMinutes:$formattedSeconds';

  // Si locale arabe → convertir les chiffres en "Arabic-Indic"
  if (locale == 'ar') {
    result = _convertToArabicDigits(result);
  }

  return result;
}

/// Convertit 0-9 vers ٠-٩ (Arabic-Indic)
String _convertToArabicDigits(String input) {
  const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  return input.replaceAllMapped(RegExp(r'[0-9]'), (match) {
    final digit = int.parse(match.group(0)!);
    return arabicDigits[digit];
  });
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
  const int KB = 1024;
  const int MB = 1024 * KB;
  const int GB = 1024 * MB;
  const int TB = 1024 * GB;

  if (bytes < KB) {
    // Retourne la taille en octets
    return i18n().label_units_storage_bytes(bytes);
  } else if (bytes < MB) {
    double kb = bytes / KB;
    // Utiliser floor() pour obtenir 4 KO pour 4.2 KO
    int roundedKb = kb.floor();
    return i18n().label_units_storage_kb(roundedKb);
  } else if (bytes < GB) {
    double mb = bytes / MB;
    // Utiliser floor() pour obtenir 4 MO pour 4.2 MO
    int roundedMb = mb.floor();
    return i18n().label_units_storage_mb(roundedMb);
  } else if (bytes < TB) {
    double gb = bytes / GB;
    // Utiliser floor() pour obtenir 4 GO pour 4.2 GO
    int roundedGb = gb.floor();
    return i18n().label_units_storage_gb(roundedGb);
  } else {
    double tb = bytes / TB;
    // Utiliser floor() pour obtenir 4 TO pour 4.2 TO
    int roundedTb = tb.floor();
    return i18n().label_units_storage_tb(roundedTb);
  }
}

String formatFilesLength(int count) {
  if (count == 1) {
    return i18n().label_download_all_one_file;
  }
  else {
    return i18n().label_download_all_files(count);
  }
}

String timeAgo(DateTime dateTime, {DateTime? dateTimeCompare}) {
  final DateTime nowDateTime = dateTimeCompare ?? DateTime.now();
  final Duration diff = nowDateTime.difference(dateTime);

  // Si futur
  if (diff.isNegative) return i18n().label_whats_new_multiple_seconds_ago;

  if (diff.inSeconds < 60) {
    return i18n().label_whats_new_multiple_seconds_ago;
  } else if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    if (minutes == 1) return i18n().label_whats_new_1_minute_ago;
    return i18n().label_whats_new_multiple_minutes_ago(minutes);
  } else if (diff.inHours < 24) {
    final hours = diff.inHours;
    if (hours == 1) return i18n().label_whats_new_1_hour_ago;
    return i18n().label_whats_new_multiple_hours_ago(hours);
  } else if (diff.inDays < 30) {
    final days = diff.inDays;
    if (days == 0) return i18n().label_whats_new_today;
    if (days == 1) return i18n().label_whats_new_1_day_ago;
    return i18n().label_whats_new_multiple_days_ago(days);
  } else if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    if (months == 1) return i18n().label_whats_new_1_month_ago;
    return i18n().label_whats_new_multiple_months_ago(months);
  } else {
    final years = (diff.inDays / 365).floor();
    if (years == 1) return i18n().label_whats_new_1_year_ago;
    return i18n().label_whats_new_multiple_year_ago(years);
  }
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

Future<bool> hasInternetConnection({BuildContext? context}) async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    printTime("Aucune connexion Internet !");
    if(context != null) {
      showNoConnectionDialog(context);
    }
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