import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Element;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/userdata/block_range.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../../data/controller/block_ranges_controller.dart';
import '../../data/controller/notes_controller.dart';
import '../../data/databases/catalog.dart';
import '../../data/databases/tiles_cache.dart';
import '../../data/models/publication.dart';
import '../../data/models/publication_category.dart';
import '../../data/models/userdata/note.dart';
import '../../data/repositories/PublicationRepository.dart';
import '../utils/files_helper.dart';

/*
  String verseAudioLink = 'https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?pub=NWT&langwritten=F&fileformat=mp3&booknum=$book1&track=$chapter1';

  dynamic audio = {};
    try {
      final response = await http.get(Uri.parse(verseAudioLink));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        audio = {
          'url': data['files']['F']['MP3'][0]['file']['url'],
          'markers': data['files']['F']['MP3'][0]['markers']['markers'],
        };
      }
      else {
        printTime('Loading error: ${response.statusCode}');
      }
    }
    catch (e) {
      printTime('An exception occurred: $e');
    }

     */

Future<Map<String, dynamic>> fetchVerses(Publication publication, String link) async {
  List<String> linkSplit = link.split('/');
  String verses = linkSplit.last;

  String bibleInfoName = linkSplit[linkSplit.length - 2];

  int book1 = int.parse(verses.split('-').first.split(':')[0]);
  int chapter1 = int.parse(verses.split('-').first.split(':')[1]);
  int verse1 = int.parse(verses.split('-').first.split(':')[2]);

  int book2 = int.parse(verses.split('-').last.split(':')[0]);
  int chapter2 = int.parse(verses.split('-').last.split(':')[1]);
  int verse2 = int.parse(verses.split('-').last.split(':')[2]);

  String versesDisplay = JwLifeApp.bibleCluesInfo.getVerses(book1, chapter1, verse1, book2, chapter2, verse2);

  List<Map<String, dynamic>> items = [];
  File mepsFile = await getMepsUnitDatabaseFile();

  try {
    Database db = await openDatabase(mepsFile.path);
    List<Map<String, dynamic>> versesIds = await db.rawQuery("""
      SELECT
        (
          SELECT
            FirstBibleVerseId +
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM BibleSuperscriptionLocation
                    WHERE BookNumber = ? AND ChapterNumber = ?
                ) THEN
                    CASE
                        WHEN ? = 0 OR ? = 1 THEN 0
                        ELSE (? - FirstOrdinal) + 1
                    END
                ELSE (? - FirstOrdinal)
            END
          FROM BibleRange
          INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
          WHERE BibleInfo.Name = 'NWTR' AND BookNumber = ? AND ChapterNumber = ?
        ) AS NewFirstVerseId,
    
        (
          SELECT 
            FirstBibleVerseId + (? - FirstOrdinal) + 
            CASE 
              WHEN EXISTS (
                SELECT 1 FROM BibleSuperscriptionLocation
                WHERE BookNumber = ? AND ChapterNumber = ?
              ) AND ? > 0 THEN 1 ELSE 0
            END
          FROM BibleRange
          INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
          WHERE BibleInfo.Name = 'NWTR' AND BookNumber = ? AND ChapterNumber = ?
        ) AS NewLastVerseId,
    
        (
          SELECT
            FirstBibleVerseId +
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM BibleSuperscriptionLocation
                    WHERE BookNumber = ? AND ChapterNumber = ?
                ) THEN
                    CASE
                        WHEN ? = 0 OR ? = 1 THEN 0
                        ELSE (? - FirstOrdinal) + 1
                    END
                ELSE (? - FirstOrdinal)
            END
          FROM BibleRange
          INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
          WHERE BibleInfo.Name = 'NWT' AND BookNumber = ? AND ChapterNumber = ?
        ) AS OldFirstVerseId,
    
        (
          SELECT 
            FirstBibleVerseId + (? - FirstOrdinal) + 
            CASE 
              WHEN EXISTS (
                SELECT 1 FROM BibleSuperscriptionLocation
                WHERE BookNumber = ? AND ChapterNumber = ?
              ) AND ? > 0 THEN 1 ELSE 0
            END
          FROM BibleRange
          INNER JOIN BibleInfo ON BibleRange.BibleInfoId = BibleInfo.BibleInfoId
          WHERE BibleInfo.Name = 'NWT' AND BookNumber = ? AND ChapterNumber = ?
        ) AS OldLastVerseId;
    """, [
      book1, chapter1, verse1, verse1, verse1, verse1, book1, chapter1,
      verse2, book2, chapter2, verse2, book2, chapter2,
      book1, chapter1, verse1, verse1, verse1, verse1, book1, chapter1,
      verse2, book2, chapter2, verse2, book2, chapter2,
    ]);

    db.close();

    for (var bible in PublicationRepository().getOrderBibles()) {
      Database? bibleDb;
      if(bible.documentsManager == null) {
        bibleDb = await openDatabase(bible.databasePath!);
      }
      else {
        bibleDb = bible.documentsManager!.database;
      }

      bool isNewWorldTranslation = bible.keySymbol.contains('nwt');
      int firstVerseId = isNewWorldTranslation ? versesIds.first['NewFirstVerseId'] : versesIds.first['OldFirstVerseId'];
      int lastVerseId = isNewWorldTranslation ? versesIds.first['NewLastVerseId'] : versesIds.first['OldLastVerseId'];

      List<Map<String, dynamic>> results = await bibleDb.rawQuery("""
        SELECT *
        FROM BibleVerse
        WHERE BibleVerseId BETWEEN ? AND ?
      """, [firstVerseId, lastVerseId]);

      String htmlContent = '';
      for (Map<String, dynamic> row in results) {
        String label = row['Label'].replaceAllMapped(
          RegExp(r'<span class="cl">(.*?)<\/span>'),
              (match) => '<span class="cl"><strong>${match.group(1)}</strong> </span>',
        );

        htmlContent += label;

        String decodedHtml = decodeBlobContent(
          row['Content'] as Uint8List,
          bible.hash!,
        );

        if (label.isEmpty) {
          // row['BeginParagraphOrdinal'] te donne ton pid
          final pid = row['BeginParagraphOrdinal'];

          // on encapsule dans un <p>
          decodedHtml =
          '<p id="p$pid" data-pid="$pid" class="sw">$decodedHtml</p>';
        }

        htmlContent += decodedHtml;
      }

      BuildContext context = GlobalKeyService.jwLifePageKey.currentContext!;
      List<BlockRange> blockRanges = await JwLifeApp.userdata.getBlockRangesFromChapterNumber(book1, chapter1, bible.keySymbol, bible.mepsLanguage.id, startVerse: verse1, endVerse: verse2);
      context.read<BlockRangesController>().loadBlockRanges(blockRanges);

      items.add({
        'type': 'verse',
        'content': htmlContent,
        'className': "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-${bible.mepsLanguage.internalScriptName} dir-${bible.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'subtitle': bible.mepsLanguage.vernacular,
        'imageUrl': bible.imageSqr,
        'publicationTitle': bible.shortTitle,
        'firstBookNumber': book1,
        'lastBookNumber': book2,
        'firstChapterNumber': chapter1,
        'lastChapterNumber': chapter2,
        'firstVerseNumber': verse1,
        'lastVerseNumber': verse2,
        'audio': {},
        'keySymbol': bible.keySymbol,
        'mepsLanguageId': bible.mepsLanguage.id,
        'highlights': blockRanges.map((blockRange) => blockRange.toMap()).toList(),
        'notes': context.read<NotesController>().getNotesByDocument(keySymbol: bible.keySymbol, mepsLanguageId: bible.mepsLanguage.id, firstBookNumber: book1, lastBookNumber: book2, firstChapterNumber: chapter1, lastChapterNumber: chapter2, firstBlockIdentifier: verse1, lastBlockIdentifier: verse2).map((n) => n.toMap()).toList(),
      });
    }

    return {
      'items': items,
      'title': versesDisplay,
    };
  }
  catch (e) {
    printTime('Error fetching verses: $e');
    return {
      'items': [],
      'title': versesDisplay,
    };
  }
}

Future<Map<String, dynamic>?> fetchExtractPublication(BuildContext context, String type, Database database, Publication publication, String link, Function(int) jumpToPage, Function(int, int) jumpToParagraph) async {
  String newLink = link.replaceAll('jwpub://', '');
  List<String> links = newLink.split("\$");

  List<Map<String, dynamic>> response = await database.rawQuery('''
    SELECT 
      Extract.*,
      RefPublication.*
    FROM Extract
    LEFT JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
    WHERE Extract.Link IN (${links.map((link) => "'$link'").join(',')})
  ''');

  if (response.isNotEmpty) {
    List<Map<String, dynamic>> extractItems = [];

    for (var extract in response) {
      Publication? refPub = await CatalogDb.instance.searchPub(extract['UndatedSymbol'], int.parse(extract['IssueTagNumber']), extract['MepsLanguageIndex']);

      var doc = parse(extract['Caption']);
      String caption = doc.querySelector('.etitle')?.text ?? '';

      String image = refPub?.imageSqr ?? refPub?.networkImageSqr ?? '';
      if (image.isNotEmpty) {
        if(image.startsWith('https')) {
          image = (await TilesCache().getOrDownloadImage(image))!.file.path;
        }
      }
      if (refPub == null || refPub.imageSqr == null) {
        String type = PublicationCategory.all.firstWhere((element) => element.type == extract['PublicationType']).image;
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        String path = isDark ? 'assets/images/${type}_gray.png' : 'assets/images/$type.png';
        image = '/android_asset/flutter_assets/$path';
      }

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(extract['Content'] as Uint8List, publication.hash!);

      int? extractMepsDocumentId = extract['RefMepsDocumentId'];
      int? firstParagraphId = extract['RefBeginParagraphOrdinal'];
      int? lastParagraphId = extract['RefEndParagraphOrdinal'];

      // Si une des valeurs est nulle, on essaie de les extraire depuis la référence
      if (extractMepsDocumentId == null || firstParagraphId == null || lastParagraphId == null) {
        final regex = RegExp(r'[A-Z]+:(\d+)(?:/(\d+)-(\d+))?');
        final match = regex.firstMatch(newLink);

        if (match != null) {
          extractMepsDocumentId ??= int.tryParse(match.group(1)!);
          firstParagraphId ??= int.tryParse(match.group(2) ?? '');
          lastParagraphId ??= int.tryParse(match.group(3) ?? '');
        }
      }

      List<BlockRange> blockRanges = [];
      if (extractMepsDocumentId != null) {
        blockRanges = await JwLifeApp.userdata.getBlockRangesFromDocumentId(extractMepsDocumentId, extract['MepsLanguageIndex'], startParagraph: firstParagraphId, endParagraph: lastParagraphId);
      }

      dynamic article = {
        'type': 'publication',
        'content': decodedHtml,
        'className': "publicationCitation html5 pub-${extract['UndatedSymbol']} docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${refPub?.mepsLanguage.symbol ?? publication.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName ?? publication.mepsLanguage.internalScriptName} dir-${refPub?.mepsLanguage.isRtl ?? publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'subtitle': caption,
        'imageUrl': image,
        'mepsDocumentId': extractMepsDocumentId ?? -1,
        'mepsLanguageId': extract['MepsLanguageIndex'],
        'startParagraphId': firstParagraphId,
        'endParagraphId': lastParagraphId,
        'publicationTitle': refPub == null ? extract['ShortTitle'] : refPub.getShortTitle(),
        'highlights': blockRanges.map((blockRange) => blockRange.toMap()).toList(),
        'notes': context.read<NotesController>().getNotesByDocument(mepsDocumentId: extractMepsDocumentId, mepsLanguageId: extract['MepsLanguageIndex'], firstBlockIdentifier: firstParagraphId, lastBlockIdentifier: lastParagraphId).map((n) => n.toMap()).toList()
      };

      // Ajouter l'élément document à la liste versesItems
      extractItems.add(article);
    }

    return {
      'items': extractItems,
      'title': 'Extrait de publication',
    };
  }
  else {
    List<String> parts = newLink.split('/');

    int mepsDocumentId = int.parse(parts[1].split(':')[1]);

    String lastPart = parts.last.split(':')[0]; // Ignore tout après ":"
    int? startParagraph;
    int? endParagraph;

    if (lastPart.contains('-')) {
      List<String> paragraphParts = lastPart.split('-');
      startParagraph = int.tryParse(paragraphParts[0]);
      endParagraph = int.tryParse(paragraphParts[1]);
    }
    else if (RegExp(r'^\d+$').hasMatch(lastPart)) {
      startParagraph = int.tryParse(lastPart);
    }

    if(type == 'document') {
      if(publication.documentsManager!.documents.any((doc) => doc.mepsDocumentId == mepsDocumentId)) {
        if (mepsDocumentId != publication.documentsManager!.getCurrentDocument().mepsDocumentId) {
          int index = publication.documentsManager!.getIndexFromMepsDocumentId(mepsDocumentId);
          jumpToPage(index);
        }

        // Appeler _jumpToParagraph uniquement si un paragraphe est présent
        if (startParagraph != null) {
          jumpToParagraph(startParagraph, endParagraph ?? startParagraph);
        }
      }
      else {
        await showDocumentView(context, mepsDocumentId, publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
      }
    }
    else {
      await showDocumentView(context, mepsDocumentId, publication.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
    }

    return null;
  }
}

Future<Map<String, dynamic>?> fetchGuideVerse(BuildContext context, Publication publication, String guideVerseId) async {
  Publication? guideVersePub = await CatalogDb.instance.searchPub('rsg19', 0, JwLifeSettings.instance.currentLanguage.value.id);
  if(guideVersePub == null) return null;

  Database? guideVersePubDb;
  if(guideVersePub.documentsManager == null) {
    guideVersePubDb = await openDatabase(guideVersePub.databasePath!);
  }
  else {
    guideVersePubDb = guideVersePub.documentsManager!.database;
  }

  List<Map<String, dynamic>> response = await guideVersePubDb.rawQuery('''
    SELECT 
      Extract.*,
      RefPublication.*
    FROM Extract
    LEFT JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
    WHERE ExtractId = $guideVerseId
  ''');

  if (response.isNotEmpty) {
    List<Map<String, dynamic>> extractItems = [];

    for (var extract in response) {
      Publication? refPub = await CatalogDb.instance.searchPub(extract['UndatedSymbol'], int.parse(extract['IssueTagNumber']), extract['MepsLanguageIndex']);

      var doc = parse(extract['Caption']);
      String caption = doc.querySelector('.etitle')?.text ?? '';

      String image = refPub?.imageSqr ?? refPub?.networkImageSqr ?? '';
      if (image.isNotEmpty) {
        if(image.startsWith('https')) {
          image = (await TilesCache().getOrDownloadImage(image))!.file.path;
        }
      }
      if (refPub == null || refPub.imageSqr == null) {
        String type = PublicationCategory.all.firstWhere((element) => element.type == extract['PublicationType']).image;
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        String path = isDark ? 'assets/images/${type}_gray.png' : 'assets/images/$type.png';
        image = '/android_asset/flutter_assets/$path';
      }

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(extract['Content'] as Uint8List, guideVersePub.hash!);

      int? extractMepsDocumentId = extract['RefMepsDocumentId'];
      int? firstParagraphId = extract['RefBeginParagraphOrdinal'];
      int? lastParagraphId = extract['RefEndParagraphOrdinal'];

      List<BlockRange> blockRanges = [];
      List<Map<String, dynamic>> notes = [];
      if (extractMepsDocumentId != null) {
        blockRanges = await JwLifeApp.userdata.getBlockRangesFromDocumentId(extractMepsDocumentId, extract['MepsLanguageIndex'], startParagraph: firstParagraphId, endParagraph: lastParagraphId);
        notes = await JwLifeApp.userdata.getNotesFromDocumentId(extractMepsDocumentId, extract['MepsLanguageIndex'], startParagraph: firstParagraphId, endParagraph: lastParagraphId);

        if(publication.documentsManager == null) {
          //publication.datedTextManager!.getCurrentDatedText().extractedNotes.clear();
          //publication.datedTextManager!.getCurrentDatedText().extractedNotes.addAll(notes.map((item) => Map<String, dynamic>.from(item)).toList());
        }
        else {
          //publication.documentsManager!.getCurrentDocument().extractedNotes.clear();
          //publication.documentsManager!.getCurrentDocument().extractedNotes.addAll(notes.map((item) => Map<String, dynamic>.from(item)).toList());
        }
      }

      dynamic article = {
        'type': 'publication',
        'content': decodedHtml,
        'className': "publicationCitation html5 pub-${extract['UndatedSymbol']} docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${refPub?.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName} dir-${refPub?.mepsLanguage.isRtl ?? false ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'subtitle': caption,
        'imageUrl': image,
        'mepsDocumentId': extractMepsDocumentId ?? -1,
        'mepsLanguageId': extract['MepsLanguageIndex'],
        'startParagraphId': firstParagraphId,
        'endParagraphId': lastParagraphId,
        'publicationTitle': refPub == null ? extract['ShortTitle'] : refPub.getShortTitle(),
        'highlights': blockRanges,
        'notes': notes
      };

      // Ajouter l'élément document à la liste versesItems
      extractItems.add(article);
    }

    return {
      'items': extractItems,
      'title': 'Extrait de publication',
    };
  }
  return null;
}

Future<Map<String, dynamic>> fetchFootnote(BuildContext context, Publication publication, String footNoteId, {String? bibleVerseId}) async {
  List<Map<String, dynamic>> response = [];

  if(bibleVerseId != null) {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT * FROM Footnote WHERE BibleVerseId = ? AND FootnoteIndex = ?
        ''',
        [bibleVerseId, footNoteId]);

  }
  else if(publication.documentsManager!.getCurrentDocument().chapterNumberBible != null) {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT Footnote.* FROM Footnote
          LEFT JOIN Document ON Footnote.DocumentId = Document.DocumentId
          WHERE Document.MepsDocumentId = ? AND FootnoteIndex = ?
        ''',
        [publication.documentsManager!.getCurrentDocument().mepsDocumentId, footNoteId]);
  }
  else {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT * FROM Footnote WHERE DocumentId = ? AND FootnoteIndex = ?
        ''',
        [publication.documentsManager!.selectedDocumentIndex, footNoteId]);

  }

  if (response.isNotEmpty) {
    final footNote = response.first;

    /// Décoder le contenu
    final decodedHtml = decodeBlobContent(
        footNote['Content'] as Uint8List,
        publication.hash!
    );

    return {
      'type': 'note',
      'content': decodedHtml,
      'className': "document html5 pub-${publication.keySymbol} docId-${publication.documentsManager!.getCurrentDocument().mepsDocumentId} docClass-13 jwac showRuby ml-${publication.mepsLanguage.symbol} ms-${publication.mepsLanguage.internalScriptName} dir-${publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
      'title': 'Note',
    };
  }
  return {
    'type': 'note',
    'content': '',
    'className': '',
    'title': 'Note',
  };
}

Future<Map<String, dynamic>> fetchVersesReference(BuildContext context, Publication publication, String versesReferenceId) async {
  List<Map<String, dynamic>> response = await publication.documentsManager!.database.rawQuery(
      '''
      SELECT 
        BibleChapter.BookNumber, 
        BibleChapter.ChapterNumber,
        (BibleVerse.BibleVerseId - BibleChapter.FirstVerseId + 1) AS VerseNumber,
        BibleVerse.BibleVerseId,
        BibleVerse.Label,
        BibleVerse.Content
      FROM BibleCitation
      LEFT JOIN Document ON BibleCitation.DocumentId = Document.DocumentId
      LEFT JOIN BibleVerse ON BibleCitation.FirstBibleVerseId = BibleVerse.BibleVerseId
      LEFT JOIN BibleChapter ON BibleVerse.BibleVerseId BETWEEN BibleChapter.FirstVerseId AND BibleChapter.LastVerseId
      WHERE Document.MepsDocumentId = ? AND BlockNumber = ?;
      ''',
      [publication.documentsManager!.getCurrentDocument().mepsDocumentId, versesReferenceId]);

  if (response.isNotEmpty) {
    List<Map<String, dynamic>> versesItems = [];

    // Process each verse in the response
    for (var verse in response) {
      String htmlContent = '';

      String label = verse['Label'].replaceAllMapped(
        RegExp(r'<span class="cl">(.*?)<\/span>'),
            (match) => '<span class="cl"><strong>${match.group(1)}</strong> </span>',
      );


      htmlContent += label;

      String decodedHtml = decodeBlobContent(
        verse['Content'] as Uint8List,
        publication.hash!,
      );

      if (label.isEmpty) {
        // row['BeginParagraphOrdinal'] te donne ton pid
        final pid = verse['BeginParagraphOrdinal'];

        // on encapsule dans un <p>
        decodedHtml =
        '<p id="p$pid" data-pid="$pid" class="sw">$decodedHtml</p>';
      }

      htmlContent += decodedHtml;

      String verseDisplay = JwLifeApp.bibleCluesInfo.getVerses(
          verse['BookNumber'], verse['ChapterNumber'], verse['VerseNumber'],
          verse['BookNumber'], verse['ChapterNumber'], verse['VerseNumber']
      );

      versesItems.add({
        'type': 'verse',
        'content': htmlContent,
        'className': "bibleCitation html5 pub-${publication.keySymbol} jwac showRuby ml-${publication.mepsLanguage.symbol} ms-${publication.mepsLanguage.internalScriptName} dir-${publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'subtitle': publication.mepsLanguage.vernacular,
        'imageUrl': publication.imageSqr,
        'publicationTitle': verseDisplay,
        'bookNumber': verse['BookNumber'],
        'chapterNumber': verse['ChapterNumber'],
        'keySymbol': publication.keySymbol,
        'firstVerseNumber': verse['VerseNumber'],
        'lastVerseNumber': verse['VerseNumber'],
        'mepsLanguageId': publication.mepsLanguage.id,
        'verse': verse['ElementNumber'],
      });
    }

    return {
      'items': versesItems,
      'title': 'Renvois',
    };
  }
  return {
    'items': [],
    'title': 'Renvois',
  };
}

Future<Map<String, dynamic>> fetchCommentaries(BuildContext context, Publication publication, String link) async {
  final result = <String, dynamic>{};

  // On sépare la partie avant et après $p
  final parts = link.split(r'$p');
  if (parts.length != 2) return {};

  // Partie principale
  final mainPart = parts[0].replaceAll('jwpub://c/', ''); // F:1001070144/3:1
  final mainSegments = mainPart.split('/');
  if (mainSegments.length == 2) {
    final langAndBook = mainSegments[0].split(':'); // F:1001070144
    final chapterAndVerse = mainSegments[1].split(':'); // 3:1

    result['languageSymbolVerse'] = langAndBook[0];
    result['mepsDocumentIdBook'] = int.parse(langAndBook[1]);
    result['chapterId'] = int.parse(chapterAndVerse[0]);
    result['verseId'] = int.parse(chapterAndVerse[1]);
  }

  // Partie commentaire
  final commentaryPart = parts[1]; // F:1001070603/6-6:273
  final commentarySegments = commentaryPart.split('/');
  if (commentarySegments.length >= 2) {
    final langAndDoc = commentarySegments[1].split(':'); // F:1001070603
    final beginParagraphPart = commentarySegments[2].split('-')[0]; // 6
    final endParagraphPart = commentarySegments[2].split('-')[1].split(':')[0]; // 6

    result['languageSymbolCommentary'] = langAndDoc[0];
    result['mepsDocumentIdCommentary'] = int.parse(langAndDoc[1]);
    result['beginParagraphId'] = int.parse(beginParagraphPart);
    result['endParagraphId'] = int.parse(endParagraphPart);
  }

  try {
    List<Map<String, dynamic>> response =
    await publication.documentsManager!.database.rawQuery('''
      SELECT
        Label, 
        Content, 
        CommentaryMepsDocumentId
      FROM VerseCommentary
      WHERE CommentaryMepsDocumentId = ? AND EndParagraphOrdinal >= ? AND BeginParagraphOrdinal <= ?
    ''', [result['mepsDocumentIdCommentary'], result['beginParagraphId'], result['endParagraphId']]);

    Publication? bible = PublicationRepository().getLookUpBible();
    if(bible == null) {
      return {
        'items': [],
        'title': 'Note d\'étude',
      };
    }

    if (response.isNotEmpty) {
      final items = response.map((commentary) {
        final decodedHtml = decodeBlobContent(
          commentary['Content'] as Uint8List,
          publication.hash!,
        );

        return {
          'type': 'commentary',
          'content': decodedHtml,
          'className': "scriptureIndexLink html5 layout-reading layout-sidebar",
          'imageUrl': bible.imageSqr,
          'publicationTitle': bible.shortTitle,
          'subtitle': bible.mepsLanguage.vernacular,
        };
      }).toList();

      return {
        'items': items,
        'title': 'Note d\'étude',
      };
    }

    // Cas où response est vide
    return {
      'items': [],
      'title': 'Note d\'étude',
    };
  }
  catch (e) {
    print(e);
  }

  // Retourne une liste vide si aucun commentaire
  return {};
}

Future<List<Map<String, dynamic>>> fetchVerseCommentaries(
    BuildContext context,
    Publication publication,
    int verseId,
    bool showLabel) async {
  try {
    List<Map<String, dynamic>> response =
    await publication.documentsManager!.database.rawQuery('''
      SELECT
        Label, 
        Content, 
        CommentaryMepsDocumentId
      FROM VerseCommentary
      INNER JOIN VerseCommentaryMap 
        ON VerseCommentary.VerseCommentaryId = VerseCommentaryMap.VerseCommentaryId
      WHERE VerseCommentaryMap.BibleVerseId = ?
    ''', [verseId]);

    if (response.isNotEmpty) {
      return response.map((commentary) {
        String htmlContent = '';
        if (showLabel) {
          htmlContent += commentary['Label'] ?? '';
        }
        final decodedHtml = decodeBlobContent(
          commentary['Content'] as Uint8List,
          publication.hash!,
        );
        htmlContent += decodedHtml;

        return {
          'type': 'commentary',
          'content': htmlContent,
          'className': "scriptureIndexLink html5 layout-reading layout-sidebar",
          'subtitle': publication.mepsLanguage.vernacular,
          'imageUrl': publication.imageSqr,
          'publicationTitle': publication.getTitle(),
        };
      }).toList();
    }
  } catch (e) {
    print(e);
  }

  // Retourne une liste vide si aucun commentaire
  return [];
}

Future<List<Map<String, dynamic>>> fetchVerseMedias(
    BuildContext context,
    Publication publication,
    int verseId,
    ) async {
  try {
    final response = await publication.documentsManager!.database.rawQuery('''
      SELECT 
          M.MultimediaId,
          M.FilePath,
          M.Label,
          M.Caption,
          M.LinkMultimediaId,
          M1.CategoryType,
          M1.KeySymbol,
          M1.Track,
          M1.MepsDocumentId,
          M1.MepsLanguageIndex,
          M1.IssueTagNumber
      FROM 
          Multimedia M
      JOIN 
          VerseMultimediaMap VMM ON M.MultimediaId = VMM.MultimediaId
      LEFT JOIN 
          Multimedia M1 ON M.LinkMultimediaId = M1.MultimediaId AND M1.CategoryType = -1
      WHERE 
          VMM.BibleVerseId = ? AND M.CategoryType = 10;
    ''', [verseId]);

    if (response.isNotEmpty) {
      return response.map((multimedia) {
        final bool isVideo =
            multimedia['CategoryType'] != null && multimedia['CategoryType'] == -1;

        String href;

        if (isVideo) {
          final params = <String, String>{
            if (multimedia['MepsDocumentId'] != null)
              'docid': multimedia['MepsDocumentId'].toString(),
            if (multimedia['KeySymbol'] != null && multimedia['KeySymbol'].toString().isNotEmpty)
              'pub': multimedia['KeySymbol'].toString(),
            if (multimedia['IssueTagNumber'] != null && multimedia['IssueTagNumber'] != 0)
              'issue': multimedia['IssueTagNumber'].toString(),
            if (multimedia['Track'] != null)
              'track': multimedia['Track'].toString(),
            if (multimedia['MepsLanguageIndex'] != null)
              'langId': multimedia['MepsLanguageIndex'].toString(),
          };

          // Encode proprement chaque clé/valeur et joindre avec ;
          final query = params.entries
              .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
              .join('&');

          href = 'webpubdl://?$query';
        }
        else {
          href = 'jwpub-media://${multimedia['FilePath']}';
        }

        return {
          'type': 'medias',
          'imagePath': publication.getFullPath(multimedia['FilePath'] as String?),
          'label': multimedia['Label'],
          'caption': multimedia['Caption'],
          'isVideo': isVideo,
          'href': href,
          'keySymbol': multimedia['KeySymbol'],
          'track': multimedia['Track'],
          'mepsDocumentId': multimedia['MepsDocumentId'],
          'mepsLanguageIndex': multimedia['MepsLanguageIndex'],
          'issueTagNumber': multimedia['IssueTagNumber'],
        };
      }).toList();
    }
  } catch (e, stack) {
    debugPrint('Error in fetchVerseMedias: $e\n$stack');
  }

  // Retourne une liste vide si aucun média trouvé ou en cas d'erreur
  return [];
}

Future<List<Map<String, dynamic>>> fetchOtherVerseVersion(BuildContext context, Publication publication, int book, int chapter, int verse, int verseId) async {
  try {
    List<Map<String, dynamic>> versesTranslations = [];
    for (var bible in PublicationRepository().getOrderBibles()) {
      Database? bibleDb;
      if(bible.documentsManager == null) {
        bibleDb = await openDatabase(bible.databasePath!);
      }
      else {
        bibleDb = bible.documentsManager!.database;
      }

      print('Verse Id: $verseId');

      List<Map<String, dynamic>> results = await bibleDb.rawQuery("""
        SELECT *
        FROM BibleVerse
        WHERE BibleVerseId = ?
      """, [verseId]);

      if(bible.documentsManager == null) {
        bibleDb.close();
      }

      String htmlContent = '';
      String label = results.first['Label'].replaceAllMapped(
        RegExp(r'<span class="cl">(.*?)<\/span>'),
            (match) => '<span class="cl"><strong>${match.group(1)}</strong> </span>',
      );

      htmlContent += label;
      final decodedHtml = decodeBlobContent(
        results.first['Content'] as Uint8List,
        bible.hash!,
      );
      htmlContent += decodedHtml;

      versesTranslations.add({
        'type': 'verse',
        'content': htmlContent,
        'className': "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-${bible.mepsLanguage.internalScriptName} dir-${bible.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'subtitle': bible.mepsLanguage.vernacular,
        'imageUrl': bible.imageSqr,
        'publicationTitle': bible.shortTitle,
        'keySymbol': bible.keySymbol,
        'bookNumber': book,
        'chapterNumber': chapter,
        'firstVerseNumber': verse,
        'lastVerseNumber': verse,
        'audio': {},
        'mepsLanguageId': bible.mepsLanguage.id,
        //'highlights': publication.documentsManager!.getCurrentDocument().blockRanges,
        //'notes': publication.documentsManager!.getCurrentDocument()
      });
    }
    return versesTranslations;
  }
  catch (e) {
    print(e);
  }

  return [];
}

Future<List<Map<String, dynamic>>> fetchVerseResearchGuide(
    BuildContext context, int verseId, bool showLabel) async {

  // Récupération des publications avec commentaire
  List<Publication> publications = (PublicationRepository()
      .getAllDownloadedPublications())
      .where((pub) => pub.hasCommentary)
      .toList();

  Database? db;
  List<Map<String, dynamic>> verseCommentariesByPub = [];

  for (var publication in publications) {
    if (!publication.isBible()) {
      try {
        // Ouvrir la base de données si nécessaire
        if (publication.documentsManager == null) {
          db = await openDatabase(publication.databasePath!);
        } else {
          db = publication.documentsManager!.database;
        }

        List<Map<String, dynamic>> response = await db.rawQuery('''
          SELECT
            Label, 
            Content
          FROM VerseCommentary
          INNER JOIN VerseCommentaryMap ON VerseCommentary.VerseCommentaryId = VerseCommentaryMap.VerseCommentaryId
          WHERE VerseCommentaryMap.BibleVerseId = ?
        ''', [verseId]);

        if (response.isEmpty) continue;

        Map<String, dynamic> commentary = response.first;
        // ... Décodage du contenu HTML ...
        String htmlContent = '';
        if (showLabel) htmlContent += (commentary['Label'] as String?) ?? '';
        final decodedHtml = decodeBlobContent(
          commentary['Content'] as Uint8List,
          publication.hash!,
        );
        htmlContent += decodedHtml;
        final Document document = parse(decodedHtml);

        // Extraction des liens avec data-xtid
        final List<Element> elements = document.querySelectorAll('a');
        final List<Map<String, String>> xtidHrefList = elements
            .map((element) => {
          'xtid': element.attributes['data-xtid'] ?? '',
          'href': element.attributes['href'] ?? '',
        })
            .where((m) => m['xtid']!.isNotEmpty)
            .toList();

        // Suppression des doublons sur la clé 'xtid'
        final List<Map<String, String>> uniqueXtidHrefList = [];
        final Set<String> seenXtid = {};
        for (var item in xtidHrefList) {
          final xtid = item['xtid']!;
          if (!seenXtid.contains(xtid)) {
            seenXtid.add(xtid);
            uniqueXtidHrefList.add(item);
          }
        }

        if (uniqueXtidHrefList.isEmpty) continue;

        // 1. Requête unique pour tous les extraits (xtid)
        final List<String> uniqueXtids = uniqueXtidHrefList.map((ref) => ref['xtid']!).toList();
        final String placeholders = List.filled(uniqueXtids.length, '?').join(', ');

        List<Map<String, dynamic>> allResponseExtracts = await db!.rawQuery('''
          SELECT
            Extract.*, 
            RefPublication.*
          FROM Extract
          INNER JOIN RefPublication ON Extract.RefPublicationId = RefPublication.RefPublicationId
          WHERE ExtractId IN ($placeholders)
        ''', uniqueXtids);

        if (allResponseExtracts.isEmpty) continue;

        // Mapper les extraits par ExtractId pour un accès facile
        final Map<String, List<Map<String, dynamic>>> extractsByXtid = {};
        for (var extract in allResponseExtracts) {
          final xtid = extract['ExtractId'].toString();
          if (!extractsByXtid.containsKey(xtid)) {
            extractsByXtid[xtid] = [];
          }
          extractsByXtid[xtid]!.add(extract);
        }

        // --- DÉBUT DE L'OPTIMISATION AVEC searchPubs ---

        // 2. Collecter tous les arguments nécessaires pour chercher les Publications de référence (refPubs)
        final Set<String> pubKeySymbols = {};
        final List<int> pubIssueTagNumbers = [];
        final List<dynamic> pubLanguages = [];

        // On utilise l'ensemble des extraits trouvés (pas seulement ceux liés à un xtid unique)
        for (var extract in allResponseExtracts) {
          final String keySymbol = extract['UndatedSymbol']?.toString() ?? '';
          final int issueTagNumber = int.tryParse(extract['IssueTagNumber']?.toString() ?? '') ?? 0;
          final dynamic language = extract['MepsLanguageIndex'];

          // Pour ne pas surcharger la requête, on ajoute uniquement les couples uniques
          final String uniqueKey = '$keySymbol-$issueTagNumber-$language';

          if (!pubKeySymbols.contains(uniqueKey)) {
            pubKeySymbols.add(uniqueKey);
            pubIssueTagNumbers.add(issueTagNumber);
            pubLanguages.add(language);
          }
        }

        // 3. Appeler searchPubs une seule fois pour toutes les publications de référence
        final List<Publication> refPubs = await CatalogDb.instance.searchPubs(
            pubKeySymbols.map((e) => e.split('-')[0]).toList(), // Extraire KeySymbol
            pubIssueTagNumbers,
            pubLanguages.firstWhere((e) => true, orElse: () => null) // Supposition: la langue est la même pour l'ensemble des refPubs
        );

        // 4. Mapper les publications de référence (refPubs) par leur identifiant unique
        final Map<String, Publication> refPubsMap = {};
        for (var refPub in refPubs) {
          final key = '${refPub.keySymbol}-${refPub.issueTagNumber}-${refPub.mepsLanguage.id}';
          refPubsMap[key] = refPub;
        }

        // --- FIN DE L'OPTIMISATION ---

        // Parcourir tous les éléments uniques pour l'extraction et la construction
        List<Map<String, dynamic>> extractItems = [];

        for (var ref in uniqueXtidHrefList) {
          String? xtid = ref['xtid'];
          String? href = ref['href'];

          if(xtid != null && href != null && extractsByXtid.containsKey(xtid)) {

            List<Map<String, dynamic>> responseExtracts = extractsByXtid[xtid]!;

            for (var extract in responseExtracts) {

              // 5. Remplacer l'appel individuel à searchPub par la recherche dans la Map
              final String undatedSymbol = extract['UndatedSymbol']?.toString() ?? '';
              final int issueTagNumber = int.tryParse(extract['IssueTagNumber']?.toString() ?? '') ?? 0;
              final dynamic mepsLanguageIndex = extract['MepsLanguageIndex'];

              final String refKey = '$undatedSymbol-$issueTagNumber-$mepsLanguageIndex';
              Publication? refPub = refPubsMap[refKey]; // Accès rapide à la publication

              // ... (Reste du traitement, non modifié) ...

              // Extraction du titre
              var doc = parse(extract['Caption']?.toString() ?? '');
              String caption = doc.querySelector('.etitle')?.text ?? '';

              // Gestion de l'image
              String image = refPub?.imageSqr ?? refPub?.networkImageSqr ?? '';
              if (image.isNotEmpty) {
                if(image.startsWith('https')) {
                  image = (await TilesCache().getOrDownloadImage(image))!.file.path;
                }
              }
              if (refPub == null || refPub.imageSqr == null) {
                String type = PublicationCategory.all.firstWhere((element) => element.type == extract['PublicationType']).image;
                bool isDark = Theme.of(context).brightness == Brightness.dark;
                String path = isDark ? 'assets/images/${type}_gray.png' : 'assets/images/$type.png';
                image = '/android_asset/flutter_assets/$path';
              }

              /// Décoder le contenu
              final decodedHtml = decodeBlobContent(extract['Content'] as Uint8List, publication.hash!);

              int? extractMepsDocumentId = extract['RefMepsDocumentId'];
              int? firstParagraphId = extract['RefBeginParagraphOrdinal'];
              int? lastParagraphId = extract['RefEndParagraphOrdinal'];

              // Si une des valeurs est nulle, on essaie de les extraire depuis la référence
              if (extractMepsDocumentId == null || firstParagraphId == null || lastParagraphId == null) {
                final regex = RegExp(r'[A-Z]+:(\d+)(?:/(\d+)-(\d+))?');
                final match = regex.firstMatch(href);

                if (match != null) {
                  extractMepsDocumentId ??= int.tryParse(match.group(1)!);
                  firstParagraphId ??= int.tryParse(match.group(2) ?? '');
                  lastParagraphId ??= int.tryParse(match.group(3) ?? '');
                }
              }

              List<BlockRange> blockRanges = [];
              List<Note> notes = [];

              if (extractMepsDocumentId != null) {
                blockRanges = await JwLifeApp.userdata.getBlockRangesFromDocumentId(extractMepsDocumentId, extract['MepsLanguageIndex'], startParagraph: firstParagraphId, endParagraph: lastParagraphId);
                context.read<BlockRangesController>().loadBlockRanges(blockRanges);
                notes = context.read<NotesController>().getNotesByDocument(mepsDocumentId: extractMepsDocumentId, mepsLanguageId: extract['MepsLanguageIndex'], firstBlockIdentifier: firstParagraphId, lastBlockIdentifier: lastParagraphId);
              }

              // Construction de l’article
              extractItems.add({
                'type': 'publication',
                'content': decodedHtml,
                'className': "publicationCitation html5 pub-$undatedSymbol docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${refPub?.mepsLanguage.symbol ?? publication.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName ?? publication.mepsLanguage.internalScriptName} dir-${(refPub?.mepsLanguage.isRtl ?? publication.mepsLanguage.isRtl) ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
                'subtitle': caption,
                'imageUrl': image,
                'mepsDocumentId': extractMepsDocumentId ?? -1,
                'mepsLanguageId': extract['MepsLanguageIndex'] as int,
                'startParagraphId': firstParagraphId,
                'endParagraphId': lastParagraphId,
                'publicationTitle': refPub == null ? extract['ShortTitle']?.toString() ?? '' : refPub.getShortTitle(),
                'highlights': blockRanges.map((b) => b.toMap()).toList(),
                'notes': notes.map((n) => n.toMap()).toList(),
              });
            }
          }
        }

        if (extractItems.isNotEmpty) {
          verseCommentariesByPub.add({
            'type': 'guide',
            'items': extractItems,
            'className': "document html5 layout-reading layout-sidebar",
          });
        }

        if (publication.documentsManager == null) {
          await db.close();
        }
      } catch (e) {
        print('Erreur dans ${publication.title}: $e');
        if (publication.documentsManager == null) {
          await db?.close();
        }
      }
    }
  }

  return verseCommentariesByPub;
}

Future<List<Map<String, dynamic>>> fetchVerseFootnotes(BuildContext context, Publication publication, int verseId) async {
  try {
    List<Map<String, dynamic>> response1 = await publication.documentsManager!.database.rawQuery('''
          SELECT
            FootnoteIndex, Content
          FROM Footnote
          WHERE BibleVerseId = ?
          ''', [verseId]
    );

    List<Map<String, dynamic>> response2 = await publication.documentsManager!.database.rawQuery(
        '''
      SELECT 
        BibleChapter.BookNumber, 
        BibleChapter.ChapterNumber,
        (BibleVerse.BibleVerseId - BibleChapter.FirstVerseId + 1) AS VerseNumber,
        BibleCitation.BlockNumber,
        BibleMarginalSymbol.Symbol AS MarginalSymbol,
        BibleVerse.Label,
        BibleVerse.Content
      FROM BibleCitation
      LEFT JOIN BibleVerse ON BibleCitation.FirstBibleVerseId = BibleVerse.BibleVerseId
      LEFT JOIN BibleChapter ON BibleVerse.BibleVerseId BETWEEN BibleChapter.FirstVerseId AND BibleChapter.LastVerseId
      INNER JOIN BibleMarginalSymbol ON BibleCitation.BlockNumber = BibleMarginalSymbol.BibleMarginalSymbolId
      WHERE BibleCitation.BibleVerseId = ?;
      ''',
        [verseId]);

    List<Map<String, dynamic>> footnotesAndVerseReferences = [];

    if (response1.isNotEmpty) {
      for (var footnote in response1) {
        final decodedHtml = decodeBlobContent(
            footnote['Content'] as Uint8List,
            publication.hash!
        );
        String htmlContent = decodedHtml;

        Document doc = parse(htmlContent);

        final String? textContent = doc.body?.text ?? doc.text;

        footnotesAndVerseReferences.add({
          'type': 'footnote',
          'footnoteIndex': footnote['FootnoteIndex'] as int,
          'content': textContent!.trim(),
          'className': "document jwac"
        });
      }
    }

    // 1. Structure pour regrouper les versets par BlockNumber
    Map<int, List<Map<String, dynamic>>> groupedCitations = {};

    if (response2.isNotEmpty) {
      // ÉTAPE 1: Regroupement (inchangé)
      for (var verse in response2) {
        // Le BlockNumber est la clé de regroupement
        final blockNumber = verse['BlockNumber'] as int;

        if (!groupedCitations.containsKey(blockNumber)) {
          groupedCitations[blockNumber] = [];
        }

        groupedCitations[blockNumber]!.add(verse);
      }

      // ÉTAPE 2: Traitement et construction des éléments pour chaque groupe
      groupedCitations.forEach((blockNumber, versesInGroup) {
        // NOUVEAU : Liste pour stocker les détails de chaque verset
        List<Map<String, dynamic>> verseDetailsList = [];

        // Déterminer les informations communes pour le groupe (on prend le premier verset)
        final firstVerse = versesInGroup.first;

        // Pour les références de versets, on veut l'étendue (ex: Jn 3:16-17)
        final firstV = firstVerse['VerseNumber'] as int;
        final lastV = versesInGroup.last['VerseNumber'] as int;
        final bookN = firstVerse['BookNumber'] as int;
        final chapterN = firstVerse['ChapterNumber'] as int;

        String verseDisplay = JwLifeApp.bibleCluesInfo.getVerses(
            bookN, chapterN, firstV,
            bookN, chapterN, lastV
        );


        // Parcourir tous les versets du groupe pour combiner leur contenu HTML
        for (var verse in versesInGroup) {
          String htmlContent = '';

          // --- Traitement et préparation du HTML ---
          String label = verse['Label'].replaceAllMapped(
            RegExp(r'<span class="cl">(.*?)<\/span>'),
                (match) => '<span class="cl"><strong>${match.group(1)}</strong> </span>',
          );
          htmlContent += label;

          String decodedHtml = decodeBlobContent(
            verse['Content'] as Uint8List,
            publication.hash!,
          );

          final pid = verse['BeginParagraphOrdinal']; // À ajuster si la clé n'est pas dans la requête

          if (label.isEmpty) {
            decodedHtml =
            '<p id="p$pid" data-pid="$pid" class="sw">$decodedHtml</p>';
          }

          htmlContent += decodedHtml;
          // ----------------------------------------

          // NOUVEAU : Construire l'objet détaillé pour ce verset
          verseDetailsList.add({
            'bookNumber': bookN,
            'chapterNumber': chapterN,
            'firstVerseNumber': firstV,
            'lastVerseNumber': lastV,
            'bookDisplay': JwLifeApp.bibleCluesInfo.getVerse(bookN, chapterN, verse['VerseNumber'], isAbbreviation: true),
            'bibleVerseDisplay': JwLifeApp.bibleCluesInfo.getVerse(bookN, chapterN, verse['VerseNumber']),
            'content': htmlContent, // Contenu HTML du verset individuel
            'label': label,
            // Vous pouvez ajouter d'autres champs si nécessaire, comme 'BeginParagraphOrdinal'
          });
        }

        // Ajouter l'élément unique pour ce groupe (BlockNumber)
        footnotesAndVerseReferences.add({
          'type': 'versesReference',
          'className': "bibleCitation html5 pub-${publication.keySymbol} jwac ml-${publication.mepsLanguage.symbol} ms-${publication.mepsLanguage.internalScriptName} dir-${publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'}",
          'subtitle': publication.mepsLanguage.vernacular,
          'imageUrl': publication.imageSqr,
          'publicationTitle': verseDisplay,
          'chapterNumbers': chapterN,
          'keySymbol': publication.keySymbol,
          'mepsLanguageId': publication.mepsLanguage.id,
          'marginalSymbol': firstVerse['MarginalSymbol'],
          'blockNumber': blockNumber,
          'verses': verseDetailsList,
        });
      });
    }

    return footnotesAndVerseReferences;
  }
  catch (e) {
    print(e);
  }

  return [];
}
