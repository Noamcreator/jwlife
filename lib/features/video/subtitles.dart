import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';

import '../../core/api/api.dart';

class Subtitles {
  late List<Subtitle> subtitles = [];

  // Méthode pour charger les sous-titres depuis l'URL
  Future<void> loadSubtitles(dynamic jsonData) async {
    String subtitlesUrl = jsonData['files'][0]['subtitles']['url'];
    printTime('subtitlesUrl: $subtitlesUrl');
    try {
      final response = await Api.httpGetWithHeaders(subtitlesUrl);
      if (response.statusCode == 200) {
        String decodedBody = utf8.decode(response.bodyBytes);
        final vttContent = _removeWebvttHeader(decodedBody);
        subtitles = _extractSegments(vttContent);
      } else {
        throw Exception('Failed to load subtitles');
      }
    } 
    catch (e) {
      printTime('Error loading subtitles: $e');
    }
  }

  // Méthode pour charger les sous-titres depuis l'URL
  Future<void> loadSubtitlesFromFile(File file) async {
    String fileContent = await file.readAsString();
    final vttContent = _removeWebvttHeader(fileContent);
    subtitles = _extractSegments(vttContent);
  }

  // Fonction pour enlever la ligne "WEBVTT"
  static String _removeWebvttHeader(String vttContent) {
    final webvttIndex = vttContent.indexOf('WEBVTT');
    if (webvttIndex != -1) {
      return vttContent.substring(webvttIndex + 6).trim();
    }
    return vttContent;
  }

  // Fonction pour extraire les segments de sous-titres
  List<Subtitle> _extractSegments(String vttContent) {
    final lines = vttContent.split('\n');
    List<Subtitle> segments = [];
    String? currentText;
    Duration? startTime;
    Duration? endTime;
    Alignment? alignment;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        if (currentText != null && startTime != null && endTime != null && alignment != null) {
          segments.add(Subtitle(text: currentText, startTime: startTime, endTime: endTime, alignment: alignment));
          currentText = null;
          startTime = null;
          endTime = null;
        }
      }
      else if (RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}').hasMatch(line) || RegExp(r'^\d{2}:\d{2}\.\d{3}').hasMatch(line)) {
        final timeParts = line.split(' --> ');
        startTime = _parseDuration(timeParts[0]);
        final endPart = timeParts[1].split(' ');
        endTime = _parseDuration(endPart[0]);

        alignment = Alignment.center;
        List<String> styles = timeParts[1].split(' ').sublist(1);
        for (String style in styles) {
          String param = style.split(':')[0].trim();
          String value = style.split(':')[1].trim();
          if (param == 'align') {
            if (value == 'left') {
              alignment = Alignment.centerLeft;
            }
            else if (value == 'right') {
              alignment = Alignment.centerRight;
            }
            else {
              alignment = Alignment.center;
            }
          }
        }
      }
      else {
        line = line.replaceAll('♪', '').trim();
        if (line.isNotEmpty) {
          if (currentText == null) {
            currentText = line;
          } else {
            currentText += '\n' + line;
          }
        }
      }
    }

    if (currentText != null && startTime != null && endTime != null && alignment != null) {
      segments.add(Subtitle(text: currentText, startTime: startTime, endTime: endTime, alignment: alignment));
    }

    return segments;
  }

  // Fonction pour parser la durée au format HH:MM:SS.MS ou MM:SS.MS
  static Duration _parseDuration(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsAndMillis = parts[2].split('.');
      final seconds = int.parse(secondsAndMillis[0]);
      final milliseconds = int.parse(secondsAndMillis[1]);
      return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    }
    else if (parts.length == 2) {
      final minutes = int.parse(parts[0]);
      final secondsAndMillis = parts[1].split('.');
      final seconds = int.parse(secondsAndMillis[0]);
      final milliseconds = int.parse(secondsAndMillis[1]);
      return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    }
    else {
      throw FormatException('Invalid time format: $timeString');
    }
  }

  @override
  String toString() {
    String result = '';
    String phrase = '';

    final htmlTagPattern = RegExp(r'<[^>]*>');

    for (Subtitle subtitle in subtitles) {
      printTime('subtitle.text: ${subtitle.text}');

      // Nettoyage
      String cleanText = subtitle.text.trim().replaceAll('\n', ' ').replaceAll(htmlTagPattern, '');
      printTime('cleanText: $cleanText');

      phrase = phrase.isEmpty ? cleanText : '$phrase $cleanText';

      String trimmed = cleanText.trim();
      if (trimmed.endsWith('.') || trimmed.endsWith('?') || trimmed.endsWith('!')) {
        result += '$phrase\n';
        phrase = '';
      }
    }

    return result.trim();
  }


  List<Subtitle> getSubtitles() {
    return subtitles;
  }
}

class Subtitle {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final Alignment alignment;
  final GlobalKey key;

  Subtitle({required this.text, required this.startTime, required this.endTime, required this.alignment}) : key = GlobalKey();

  String getText() {
    // retourner le texte sans les balises
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}