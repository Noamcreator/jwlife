import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/utils/diacritic.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';

import 'package:image/image.dart' as img;

import '../../i18n/i18n.dart';

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

String removeDiacritics(String text) {
  return String.fromCharCodes(replaceCodeUnits(text.codeUnits));
}

String normalize(String s) {
  return removeDiacritics(s).toLowerCase();
}

String formatNumber(num number, {String? format, String? localeCode}) {
  final locale = getSafeLocale(localeInput: localeCode);
  return DateFormat.y(locale).format(DateTime(number.toInt()));
}

String formatYear(num number, {Locale? localeCode}) {
  final locale = getSafeLocale(localeInput: localeCode);
  return DateFormat.y(locale).format(DateTime(number.toInt()));
}

String getSafeLocale({dynamic localeInput}) {
  String locale;

  if (localeInput != null) {
    locale = localeInput.toString();
  }
  else {
    final context = GlobalKeyService.jwLifePageKey.currentContext;
    locale = context != null ? Localizations.localeOf(context).toString() : 'en';
  }

  if (!DateFormat.localeExists(locale)) {
    final languageCode = locale.split('_').first;

    if (DateFormat.localeExists(languageCode)) {
      return languageCode;
    }
    return (languageCode == 'ay') ? 'es' : 'en';
  }

  return locale;
}

String formatDuration(double duration) {
  final String locale = getSafeLocale();
  int totalSeconds = duration.toInt();
  DateTime time = DateTime.utc(0, 1, 1).add(Duration(seconds: totalSeconds));

  int hours = totalSeconds ~/ 3600;

  String formatPattern = (hours > 0) ? 'H:mm:ss' : 'm:ss';

  final formatter = DateFormat(formatPattern, locale);
  return formatter.format(time);
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

  Duration duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
  String formattedDuration = formatDuration(duration.inSeconds.toDouble());

  return formattedDuration;
}

String formatTs(double position, double duration) {
  DateTime referenceTime = DateTime(0, 0, 0);

  int positionSeconds = position.toInt();
  DateTime timePosition = referenceTime.add(Duration(seconds: positionSeconds));

  int totalSeconds = duration.toInt();
  DateTime timeDuration = referenceTime.add(Duration(seconds: totalSeconds));

  // Définir le format en fonction de la durée totale.
  String formatPattern = 'H:mm:ss';

  // Utiliser DateFormat pour localiser le format
  final locale = getSafeLocale();
  final formatter = DateFormat(formatPattern, locale);

  String formattedTime = '${formatter.format(timePosition)} - ${formatter.format(timeDuration)}';

  return formattedTime;
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

String formatFileSize(int bytes, {String? localeCode}) {
  const int KB = 1024;
  const int MB = 1024 * KB;
  const int GB = 1024 * MB;
  const int TB = 1024 * GB;

  // Format '0' assure qu'il n'y a pas de virgule affichée
  const String integerFormat = '0';

  if (bytes < KB) {
    return i18n().label_units_storage_bytes(formatNumber(bytes, format: integerFormat, localeCode: localeCode));
  } else if (bytes < MB) {
    // .round() transforme 8.9 en 9 et 8.4 en 8
    final int roundedKb = (bytes / KB).round();
    return i18n().label_units_storage_kb(formatNumber(roundedKb, format: integerFormat, localeCode: localeCode));
  } else if (bytes < GB) {
    final int roundedMb = (bytes / MB).round();
    return i18n().label_units_storage_mb(formatNumber(roundedMb, format: integerFormat, localeCode: localeCode));
  } else if (bytes < TB) {
    final int roundedGb = (bytes / GB).round();
    return i18n().label_units_storage_gb(formatNumber(roundedGb, format: integerFormat, localeCode: localeCode));
  } else {
    final int roundedTb = (bytes / TB).round();
    return i18n().label_units_storage_tb(formatNumber(roundedTb, format: integerFormat, localeCode: localeCode));
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

  // Nous utiliserons ce format pour les nombres entiers (ex: 5 minutes)
  const String integerFormat = '0';

  // Si futur
  if (diff.isNegative) return i18n().label_whats_new_multiple_seconds_ago;

  if (diff.inSeconds < 60) {
    return i18n().label_whats_new_multiple_seconds_ago;
  } else if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    if (minutes == 1) return i18n().label_whats_new_1_minute_ago;
    // Utilisation de formatNumber
    final String formattedMinutes = formatNumber(minutes, format: integerFormat);
    return i18n().label_whats_new_multiple_minutes_ago(formattedMinutes);
  } else if (diff.inHours < 24) {
    final hours = diff.inHours;
    if (hours == 1) return i18n().label_whats_new_1_hour_ago;
    // Utilisation de formatNumber
    final String formattedHours = formatNumber(hours, format: integerFormat);
    return i18n().label_whats_new_multiple_hours_ago(formattedHours);
  }
  // Si il y a moins de 60 jours, afficher le nombre de jours
  else if (diff.inDays < 60) {
    final days = diff.inDays;
    if (days == 0) return i18n().label_whats_new_today;
    if (days == 1) return i18n().label_whats_new_1_day_ago;
    // Utilisation de formatNumber
    final String formattedDays = formatNumber(days, format: integerFormat);
    return i18n().label_whats_new_multiple_days_ago(formattedDays);
  } else if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    if (months == 1) return i18n().label_whats_new_1_month_ago;
    // Utilisation de formatNumber
    final String formattedMonths = formatNumber(months, format: integerFormat);
    return i18n().label_whats_new_multiple_months_ago(formattedMonths);
  } else {
    final years = (diff.inDays / 365).floor();
    if (years == 1) return i18n().label_whats_new_1_year_ago;
    // Utilisation de formatNumber
    final String formattedYears = formatNumber(years, format: integerFormat);
    return i18n().label_whats_new_multiple_year_ago(formattedYears);
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

Future<bool> hasInternetConnection({BuildContext? context, String? type}) async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    printTime("Aucune connexion Internet !");
    if(context != null) {
      showNoConnectionDialog(context);
    }
    return false;
  }
  else {
     if(JwLifeSettings.instance.offlineMode && context != null) {
      bool? result = await showOfflineModeDialog(context);

      if(!(result ?? false)) {
        return false;
      }
    }
  }

  if (connectivityResult.contains(ConnectivityResult.mobile)) {
    printTime("Connexion Internet Mobile !");
    if(context != null && type == 'download' && !JwLifeSettings.instance.downloadUsingCellularData) {
      return (await showDownloadCellularConnectionDialog(context) ?? false);
    }
    else if(context != null && type == 'stream' && !JwLifeSettings.instance.streamUsingCellularData) {
      return (await showStreamCellularConnectionDialog(context) ?? false);
    }
    return true;
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