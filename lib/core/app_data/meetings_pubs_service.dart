import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/PublicationRepository.dart';
import 'app_data_service.dart';

void refreshPublicTalks() {
  String keySymbol = 'S-34';
  String mepsLanguageSymbol = JwLifeSettings.instance.workshipLanguage.value.symbol;

  AppDataService.instance.publicTalkPub.value = PublicationRepository().getPublicationWithSymbol(keySymbol, 0, mepsLanguageSymbol);
}

// Variable globale ou dans ton service pour suivre la dernière date demandée
DateTime? _lastRequestedDate;

Future<void> refreshMeetingsPubs({List<Publication>? pubs, DateTime? date}) async {
  final targetDate = date ?? DateTime.now();
  _lastRequestedDate = targetDate; // On enregistre la date de cette requête

  Publication? midweekMeetingPub = pubs?.firstWhereOrNull((pub) => pub.keySymbol.contains('mwb'));
  Publication? weekendMeetingPub = pubs?.firstWhereOrNull((pub) => pub.keySymbol.contains(RegExp(r'(?<!m)w')));

  // On met à jour les pubs immédiatement
  AppDataService.instance.midweekMeetingPub.value = midweekMeetingPub;
  AppDataService.instance.weekendMeetingPub.value = weekendMeetingPub;

  // --- TRAITEMENT MIDWEEK ---
  if (midweekMeetingPub != null) {
    if (midweekMeetingPub.isDownloadedNotifier.value) {
      final data = await fetchMidWeekMeeting(midweekMeetingPub, targetDate);
      
      // VERIFICATION : Est-ce qu'on est toujours sur la même semaine ?
      if (_lastRequestedDate == targetDate) {
        AppDataService.instance.midweekMeeting.value = data;
        midweekMeetingPub.fetchAudios();
      }
    } else {
      AppDataService.instance.midweekMeeting.value = null;
      // Ajout d'un listener unique pour quand le téléchargement finit
      late VoidCallback l;
      l = () {
        midweekMeetingPub.isDownloadedNotifier.removeListener(l);
        refreshMeetingsPubs(pubs: pubs, date: targetDate);
      };
      midweekMeetingPub.isDownloadedNotifier.addListener(l);
    }
  }

  // --- TRAITEMENT WEEKEND ---
  if (weekendMeetingPub != null) {
    if (weekendMeetingPub.isDownloadedNotifier.value) {
      final data = await fetchWeekendMeeting(weekendMeetingPub, targetDate);
      
      // VERIFICATION : Est-ce qu'on est toujours sur la même semaine ?
      if (_lastRequestedDate == targetDate) {
        AppDataService.instance.weekendMeeting.value = data;
        weekendMeetingPub.fetchAudios();
      }
    } else {
      AppDataService.instance.weekendMeeting.value = null;
      late VoidCallback l;
      l = () {
        weekendMeetingPub.isDownloadedNotifier.removeListener(l);
        refreshMeetingsPubs(pubs: pubs, date: targetDate);
      };
      weekendMeetingPub.isDownloadedNotifier.addListener(l);
    }
  }
}

Future<Map<String, dynamic>?> fetchMidWeekMeeting(Publication? publication, DateTime dateOfMeetings) async {
  if (publication == null || !publication.isDownloadedNotifier.value) return null;

  Database? db;
  try {
    // singleInstance: false permet d'ouvrir plusieurs connexions indépendantes sans conflit
    db = await openDatabase(publication.databasePath!, readOnly: true, singleInstance: false);
    String weekRange = DateFormat('yyyyMMdd').format(dateOfMeetings);

    final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT Document.MepsDocumentId, Document.Title, Document.Subtitle, Multimedia.FilePath
        FROM Document
        LEFT JOIN DatedText ON DatedText.DocumentId = Document.DocumentId
        LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = Document.DocumentId
        LEFT JOIN Multimedia ON Multimedia.MultimediaId = DocumentMultimedia.MultimediaId
        WHERE Multimedia.CategoryType = ? AND DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
        ORDER BY Multimedia.MultimediaId
        LIMIT 1
      ''', [9, weekRange, weekRange]);

    return result.isNotEmpty ? result.first : null;
  } catch (e) {
    debugPrint("Erreur SQL Midweek: $e");
    return null;
  } finally {
    await db?.close();
  }
}

Future<Map<String, dynamic>?> fetchWeekendMeeting(Publication? publication, DateTime dateOfMeetings) async {
  if (publication == null || !publication.isDownloadedNotifier.value) return null;

  Database? db;
  try {
    db = await openDatabase(publication.databasePath!, readOnly: true, singleInstance: false);
    String weekRange = DateFormat('yyyyMMdd').format(dateOfMeetings);

    final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT doc.MepsDocumentId, doc.Title, doc.ContextTitle, m.FilePath
        FROM DatedText d
        JOIN DocumentInternalLink dil
            ON d.DocumentId = dil.DocumentId
           AND (
                d.BeginParagraphOrdinal = dil.BeginParagraphOrdinal
                OR d.BeginParagraphOrdinal = dil.EndParagraphOrdinal
                OR d.EndParagraphOrdinal = dil.BeginParagraphOrdinal
                OR d.EndParagraphOrdinal = dil.EndParagraphOrdinal
           )
        JOIN InternalLink il ON dil.InternalLinkId = il.InternalLinkId
        JOIN Document doc ON il.MepsDocumentId = doc.MepsDocumentId
        LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = doc.DocumentId
        LEFT JOIN Multimedia m ON m.MultimediaId = dm.MultimediaId
        WHERE m.CategoryType = ? AND d.FirstDateOffset <= ? AND d.LastDateOffset >= ?
        LIMIT 1
      ''', [9, weekRange, weekRange]);

    return result.isNotEmpty ? result.first : null;
  } catch (e) {
    debugPrint("Erreur SQL Weekend: $e");
    return null;
  } finally {
    await db?.close();
  }
}