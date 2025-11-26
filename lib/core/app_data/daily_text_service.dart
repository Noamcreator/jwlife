import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';


import '../../data/models/publication.dart';
import '../utils/utils_jwpub.dart';
import 'app_data_service.dart';

Future<Map<String, dynamic>?> getDatedDocumentForToday(Publication publication) async {
  Database datedDocumentDb = await openReadOnlyDatabase(publication.databasePath!);

  String today = DateFormat('yyyyMMdd').format(DateTime.now());

  List<Map<String, dynamic>> response = await datedDocumentDb.rawQuery('''
      SELECT 
        D.Content,
        DP.ParagraphIndex,
        DP.BeginPosition,
        DP.EndPosition
    
    FROM DatedText DT
    JOIN DocumentParagraph DP
        ON DP.DocumentId = DT.DocumentId
        AND DP.ParagraphIndex = ((DT.BeginParagraphOrdinal + DT.EndParagraphOrdinal) / 2)
    JOIN Document D
	    ON D.DocumentId = DT.DocumentId    
    
    WHERE DT.FirstDateOffset <= ? AND DT.LastDateOffset >= ?;
    ''', [today, today]);

  datedDocumentDb.close();

  return response.first;
}

Future<void> fetchVerseOfTheDay() async {
  final pub = AppDataService.instance.dailyText.value;

  if (pub == null) return;

  // 2) Attendre la fin du téléchargement
  if (!pub.isDownloadedNotifier.value) {
    late VoidCallback listener;

    listener = () async {
      if (pub.isDownloadedNotifier.value) {
        pub.isDownloadedNotifier.removeListener(listener);
        await fetchVerseOfTheDay(); // relance propre
      }
    };

    pub.isDownloadedNotifier.addListener(listener);
    return;
  }

  final document = await getDatedDocumentForToday(pub);

  final beginPosition = document?['BeginPosition'];
  final endPosition = document?['EndPosition'];

  if (beginPosition != null && endPosition != null) {
    final documentBlob = decodeBlobParagraph(document!['Content'] as Uint8List, pub.hash!);
    final paragraphBlob = documentBlob.sublist(beginPosition, endPosition);
    final paragraphHtml = utf8.decode(paragraphBlob);
    final paragraphText = html_parser.parse(paragraphHtml).body?.text ?? '';

    // 3) Texte = mis dans le second ValueNotifier
    AppDataService.instance.dailyTextHtml.value = paragraphText;
  }
}
