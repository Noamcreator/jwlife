import 'dart:ui';

import 'package:collection/collection.dart';
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

Future<void> refreshMeetingsPubs({List<Publication>? pubs, DateTime? date}) async {
  Publication? midweekMeetingPub = pubs?.firstWhereOrNull((pub) => pub.keySymbol.contains('mwb'));
  Publication? weekendMeetingPub = pubs?.firstWhereOrNull((pub) => pub.keySymbol.contains(RegExp(r'(?<!m)w')));

  if(midweekMeetingPub != AppDataService.instance.midweekMeetingPub.value) {
    AppDataService.instance.midweekMeetingPub.value = midweekMeetingPub;
  }

  if(weekendMeetingPub != AppDataService.instance.weekendMeetingPub.value) {
    AppDataService.instance.weekendMeetingPub.value = weekendMeetingPub;
  }

  if (midweekMeetingPub != null) {
    late VoidCallback midweekListener;

    midweekListener = () async {
      if (midweekMeetingPub.isDownloadedNotifier.value) {
        midweekMeetingPub.isDownloadedNotifier.removeListener(midweekListener);
        await refreshMeetingsPubs(pubs: pubs); // relance propre
      }
    };

    midweekMeetingPub.isDownloadedNotifier.addListener(midweekListener);

    if (midweekMeetingPub.isDownloadedNotifier.value) {
      AppDataService.instance.midweekMeeting.value = await fetchMidWeekMeeting(midweekMeetingPub, date ?? DateTime.now());

      midweekMeetingPub.fetchAudios();
    }
    else {
      AppDataService.instance.midweekMeeting.value = null;
    }
  }

  if (weekendMeetingPub != null) {
    late VoidCallback weekendListener;

    weekendListener = () async {
      if (weekendMeetingPub.isDownloadedNotifier.value) {
        weekendMeetingPub.isDownloadedNotifier.removeListener(weekendListener);
        await refreshMeetingsPubs(pubs: pubs); // relance propre
      }
    };

    weekendMeetingPub.isDownloadedNotifier.addListener(weekendListener);

    if (weekendMeetingPub.isDownloadedNotifier.value) {
      AppDataService.instance.weekendMeeting.value = await fetchWeekendMeeting(weekendMeetingPub, date ?? DateTime.now());

      weekendMeetingPub.fetchAudios();
    }
    else {
      AppDataService.instance.weekendMeeting.value = null;
    }
  }
}

Future<Map<String, dynamic>?> fetchMidWeekMeeting(Publication? publication, DateTime dateOfMeetings) async {
  if (publication != null && publication.isDownloadedNotifier.value) {
    Database db = await openReadOnlyDatabase(publication.databasePath!);

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

    if (result.isNotEmpty) {
      return result.first;
    }
  }
  return null;
}

Future<Map<String, dynamic>?> fetchWeekendMeeting(Publication? publication, DateTime dateOfMeetings) async {
  if (publication != null) {
    Database db = await openReadOnlyDatabase(publication.databasePath!);

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

    if (result.isNotEmpty) {
      return result.first;
    }
  }
  return null;
}