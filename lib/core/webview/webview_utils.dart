import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
import '../../features/document/local/documents_manager.dart';
import '../../i18n/i18n.dart';
import '../utils/utils_database.dart';

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

final RegExp _clRegex = RegExp(r'<span class="cl">(.*?)<\/span>');
final RegExp _vlRegex = RegExp(r'<span class="vl">(.*?)<\/span>');

Future<Map<String, dynamic>> fetchVerses(Map<String, dynamic> payload, Publication publication) async {
  final String clickedHref = payload['clicked'];
  final List<String> otherHrefs = List<String>.from(payload['others'] ?? []);
  final List<String> allLinks = [clickedHref, ...otherHrefs];

  // Helper interne pour parser les URLs de type bible
  Map<String, int> parse(String href) {
    final parts = href.split('/').last.split('-');
    final sP = parts.first.split(':');
    final eP = parts.last.split(':');
    return {
      'b1': int.parse(sP[0]), 'c1': int.parse(sP[1]), 'v1': int.parse(sP[2]),
      'b2': int.parse(eP[0]), 'c2': int.parse(eP[1]), 'v2': int.parse(eP[2]),
    };
  }

  // 1. ANALYSE DU LIEN PRINCIPAL (pour les métadonnées de la modale)
  final m = parse(clickedHref);
  final String titleLarge = JwLifeApp.bibleCluesInfo.getVerses(m['b1']!, m['c1']!, m['v1']!, m['b2']!, m['c2']!, m['v2']!, type: 'standardBookName');
  final String titleMedium = JwLifeApp.bibleCluesInfo.getVerses(m['b1']!, m['c1']!, m['v1']!, m['b2']!, m['c2']!, m['v2']!, type: 'standardBookAbbreviation');
  final String titleSmall = JwLifeApp.bibleCluesInfo.getVerses(m['b1']!, m['c1']!, m['v1']!, m['b2']!, m['c2']!, m['v2']!, type: 'officialBookAbbreviation');

  // 2. PRÉ-CALCUL DES SEGMENTS (On le fait une seule fois pour toutes les bibles)
  final List<Map<String, dynamic>> preparedLinks = [];
  for (String link in allLinks) {
    final v = parse(link);
    final segments = await JwLifeApp.bibleCluesInfo.getBibleVerseId(v['b1']!, v['c1']!, v['v1']!, book2: v['b2'], chapter2: v['c2'], verse2: v['v2']);
    final display = JwLifeApp.bibleCluesInfo.getVerses(v['b1']!, v['c1']!, v['v1']!, v['b2']!, v['c2']!, v['v2']!, type: 'standardBookName');
    preparedLinks.add({'coords': v, 'segments': segments, 'display': display});
  }

  final context = GlobalKeyService.jwLifePageKey.currentContext!;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  List<Note> notes = [];

  try {
    final bibles = PublicationRepository().getOrderBibles();
    
    final versesDataResults = await Future.wait(bibles.map((bible) async {
      Database? bibleDb = bible.documentsManager?.database ?? await openReadOnlyDatabase(bible.databasePath!);
      final String typeKey = bible.keySymbol.contains('nwt') ? 'NWTR' : 'NWT';
      final String langCode = bible.mepsLanguage.primaryIetfCode;
      final StringBuffer htmlBuffer = StringBuffer();

      bool isVerseExisting = false;
      List<BlockRange> blockRanges = [];

      for (int i = 0; i < preparedLinks.length; i++) {
        final linkData = preparedLinks[i];
        final coords = linkData['coords'] as Map<String, int>;
        final segment = linkData['segments'][typeKey] ?? {'start': -1, 'end': -1};

        // Extraction des notes (uniquement sur la première bible de la liste pour éviter les doublons)
        if (bibles.indexOf(bible) == 0) {
          notes.addAll(context.read<NotesController>().getNotesByDocument(
            firstBookNumber: coords['b1']!, lastBookNumber: coords['b1']!,
            firstChapterNumber: coords['c1']!, lastChapterNumber: coords['c2']!,
            firstBlockIdentifier: coords['v1']!, lastBlockIdentifier: coords['v2']!,
          ));
        }

        if (segment['start'] != -1 || segment['end'] != -1) {
          bool hasPara = await checkIfColumnsExists(bibleDb, 'BibleVerse', ['BeginParagraphOrdinal']);
          String col = hasPara ? ', BeginParagraphOrdinal' : '';

          final List<Map<String, dynamic>> dbResults = await bibleDb.rawQuery(
            "SELECT Label, Content $col FROM BibleVerse WHERE BibleVerseId BETWEEN ? AND ? ORDER BY BibleVerseId",
            [segment['start'], segment['end']]
          );

          if (dbResults.isNotEmpty) {
            isVerseExisting = true;
            if (i == 0) {
              // Style du verset principal
              htmlBuffer.write('<div class="main-verse-focus" style="${allLinks.length == 1 ? "" : "background: rgba(74, 109, 167, 0.08);"} padding: 15px 23px;">');
            } else {
              // Style des versets liés (voisins)
              htmlBuffer.write('<div style="font-size: 0.95em; font-weight: bold; color: ${isDark ? '#ffffff' : '#000000'}; margin-top: 15px; padding-left: 15px; padding-right: 15px;">${linkData['display']}</div>');
              htmlBuffer.write('<div class="neighbor-verse" style="opacity: 0.9; padding: 5px 23px 15px 23px;">');
            }

            for (final row in dbResults) {
              String label = row['Label'] ?? '';
              if (label.isNotEmpty) {
                label = label.replaceAllMapped(_clRegex, (m) => '<span class="cl"><strong>${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</strong> </span>')
                             .replaceAllMapped(_vlRegex, (m) => '<span class="vl">${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</span>');
              }
              htmlBuffer.write(label);
              if (row['Content'] != null) {
                htmlBuffer.write(decodeBlobContent(row['Content'] as Uint8List, bible.hash!));
              }
            }
          }
          htmlBuffer.write('</div>');
        }
        
        // Récupération des blockRanges pour le surlignage
        blockRanges.addAll(await JwLifeApp.userdata.getBlockRangesFromChapterNumber(
          coords['b1']!, coords['c1']!, coords['c2']!, bible.keySymbol, bible.mepsLanguage.id, 
          startVerse: coords['v1']!, endVerse: coords['v2']!
        ));
      }

      return {
        'type': 'verse',
        'isVerseExisting': isVerseExisting,
        'content': isVerseExisting ? htmlBuffer.toString() : '',
        'className': isVerseExisting ? "bibleCitation html5 pub-${bible.keySymbol} jwac ml-${bible.mepsLanguage.symbol} ms-${bible.mepsLanguage.internalScriptName} dir-${bible.mepsLanguage.isRtl ? 'rtl' : 'ltr'}" : "document html5 jwac",
        'imageUrl': bible.imageSqr ?? '/android_asset/flutter_assets/assets/images/pub_type_bible${isDark ? '_gray' : ''}.png',
        'bibleTitle': bible.shortTitle,
        'languageText': bible.mepsLanguage.vernacular,
        'audio': {},
        'keySymbol': bible.keySymbol,
        'mepsLanguageId': bible.mepsLanguage.id,
        'display': JwLifeSettings.instance.webViewSettings.versesInParallel ? bibles.indexOf(bible) == 0 ? 'left' : bibles.indexOf(bible) == 1 ? 'right' : 'full' : 'full',
        'blockRanges': blockRanges.map((br) => br.toMap()).toList()
      };
    }));

    return {
      'verses': versesDataResults,
      'title': titleLarge,
      'allTiles': { 'large': titleLarge, 'medium': titleMedium, 'small': titleSmall },
      'personalizedText': i18n().action_customize,
      'noVerseExistingText': i18n().message_verse_not_present,
      'firstBookNumber': m['b1'], 'lastBookNumber': m['b2'],
      'firstChapterNumber': m['c1'], 'lastChapterNumber': m['c2'],
      'firstVerseNumber': m['v1'], 'lastVerseNumber': m['v2'],
      'notes': notes.map((n) => n.toMap()).toList(),
    };
  } catch (e) {
    return {'verses': [], 'title': titleLarge};
  }
}

Future<Map<String, dynamic>?> fetchExtractPublication(BuildContext context, String type, Publication currentPublication, Publication? extractPublication, int? initMepsDocumentId, String link, Function(int) jumpToPage, Function(int, int, {String articleId}) jumpToParagraph) async {
  Publication current = extractPublication ?? currentPublication;
  if(current.documentsManager == null) {
    current.documentsManager = DocumentsManager(publication: current, initMepsDocumentId: initMepsDocumentId);
    await current.documentsManager!.initializeDatabaseAndData();
  }

  Database database = current.documentsManager!.database;

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
    List<Map<String, dynamic>> extracts = [];

    for (var extract in response) {
      int issueTagNumber = int.parse(extract['IssueTagNumber']);
      String keySymbol = issueTagNumber != 0 ? extract['Symbol'] : extract['UniqueEnglishSymbol'];
      int mepsLanguageIndex = extract['MepsLanguageIndex'];

      Publication? refPub = await CatalogDb.instance.searchPub(keySymbol, issueTagNumber, mepsLanguageIndex);

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
        String path = isDark ? '${type}' : '$type';
        image = '/android_asset/flutter_assets/assets/images/$path.png';
      }

      /// Décoder le contenu
      final decodedHtml = decodeBlobContent(extract['Content'] as Uint8List, current.hash!);

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
        'className': "publicationCitation html5 pub-${extract['UndatedSymbol']} docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac ml-${refPub?.mepsLanguage.symbol ?? current.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName ?? current.mepsLanguage.internalScriptName} dir-${refPub?.mepsLanguage.isRtl ?? current.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'imageUrl': image,
        'publicationTitle': refPub == null ? extract['ShortTitle'] : refPub.getShortTitle(),
        'subtitleText': caption,
        'mepsLanguageId': extract['MepsLanguageIndex'],
        'keySymbol': extract['UndatedSymbol'] ?? refPub?.keySymbol ?? '',
        'issueTagNumber': extract['IssueTagNumber'] ?? refPub?.issueTagNumber ?? '',
        'mepsDocumentId': extractMepsDocumentId ?? -1,
        'startParagraphId': firstParagraphId,
        'endParagraphId': lastParagraphId,
        'blockRanges': blockRanges.map((blockRange) => blockRange.toMap()).toList(),
        'notes': context.read<NotesController>().getNotesByDocument(mepsDocumentId: extractMepsDocumentId, mepsLanguageId: extract['MepsLanguageIndex'], firstBlockIdentifier: firstParagraphId, lastBlockIdentifier: lastParagraphId).map((n) => n.toMap()).toList()
      };

      // Ajouter l'élément document à la liste versesItems
      extracts.add(article);
    }

    return {
      'extractsPublications': extracts,
      'title': i18n().label_icon_extracted_content,
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
      if(current.documentsManager!.documents.any((doc) => doc.mepsDocumentId == mepsDocumentId)) {
        if (mepsDocumentId != current.documentsManager!.documents.firstWhereOrNull((doc) => doc.mepsDocumentId == initMepsDocumentId)?.mepsDocumentId) {
          int index = current.documentsManager!.getIndexFromMepsDocumentId(mepsDocumentId);
          await jumpToPage(index);
        }

        // Appeler _jumpToParagraph uniquement si un paragraphe est présent
        if (startParagraph != null) {
          String articleId = extractPublication != null ? 'containerDialog' : 'page-center';
          jumpToParagraph(startParagraph, endParagraph ?? startParagraph, articleId: articleId);
        }
      }
      else {
        await showDocumentView(context, mepsDocumentId, current.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
      }
    }
    else {
      await showDocumentView(context, mepsDocumentId, current.mepsLanguage.id, startParagraphId: startParagraph, endParagraphId: endParagraph);
    }

    return null;
  }
}

Future<Map<String, dynamic>?> fetchGuideVerse(BuildContext context, String guideVerseId) async {
  Publication? guideVersePub = PublicationRepository().getPublicationWithMepsLanguageId(
    'rsg19',
    0,
    JwLifeSettings.instance.libraryLanguage.value.id,
  );
  if (guideVersePub == null) return null;

  Database? guideVersePubDb;
  if (guideVersePub.documentsManager == null) {
    guideVersePubDb = await openReadOnlyDatabase(guideVersePub.databasePath!);
  } else {
    guideVersePubDb = guideVersePub.documentsManager!.database;
  }

  // -- Récupération brute des extraits --
  List<Map<String, dynamic>> response = await guideVersePubDb.rawQuery('''
    SELECT 
      Extract.*,
      RefPublication.*
    FROM Extract
    LEFT JOIN RefPublication 
      ON Extract.RefPublicationId = RefPublication.RefPublicationId
    WHERE ExtractId = $guideVerseId
  ''');

  if (response.isEmpty) return null;

  // --------------------------------------------------------------------
  // 1) Construire les listes pour lancer UNE SEULE recherche
  // --------------------------------------------------------------------
  List<String> keySymbols = [];
  List<int> issueTagNumbers = [];
  List<int> languageIndexes = [];

  for (var extract in response) {
    int issueTagNumber = int.tryParse(extract['IssueTagNumber'].toString()) ?? 0;
    String keySymbol = extract['UniqueEnglishSymbol'];
    int mepsLanguageIndex = extract['MepsLanguageIndex'];

    keySymbols.add(keySymbol);
    issueTagNumbers.add(issueTagNumber);
    languageIndexes.add(mepsLanguageIndex);
  }

  // --------------------------------------------------------------------
  // 2) Effectuer une seule recherche multi-publications
  // --------------------------------------------------------------------
  List<Publication> pubs = await CatalogDb.instance.searchPubs(
    keySymbols,
    issueTagNumbers,
    languageIndexes,
  );

  // Indexation pour lookup rapide
  Map<String, Publication> pubsByKey = {};
  for (var p in pubs) {
    final key = "${p.keySymbol}_${p.issueTagNumber}_${p.mepsLanguage.id}";
    pubsByKey[key] = p;
  }

  // --------------------------------------------------------------------
  // 3) Construire les items à retourner
  // --------------------------------------------------------------------
  List<Map<String, dynamic>> extractItems = [];

  for (var extract in response) {
    int issueTagNumber = int.tryParse(extract['IssueTagNumber'].toString()) ?? 0;
    String keySymbol = extract['UniqueEnglishSymbol'];
    int mepsLanguageIndex = extract['MepsLanguageIndex'];

    final lookupKey = "${keySymbol}_${issueTagNumber}_$mepsLanguageIndex";
    Publication? refPub = pubsByKey[lookupKey];

    // Caption
    var doc = parse(extract['Caption']);
    String caption = doc.querySelector('.etitle')?.text ?? '';

    // Image
    String image = refPub?.imageSqr ?? refPub?.networkImageSqr ?? '';
    if (image.isNotEmpty && image.startsWith('https')) {
      image = (await TilesCache().getOrDownloadImage(image))!.file.path;
    }

    if (refPub == null || refPub.imageSqr == null) {
      String type = PublicationCategory.all
          .firstWhere((e) => e.type == extract['PublicationType'])
          .image;
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      String path = isDark ? 'assets/images/${type}_gray.png' : 'assets/images/$type.png';
      image = '/android_asset/flutter_assets/$path';
    }

    // Décodage contenu
    final decodedHtml = decodeBlobContent(
      extract['Content'] as Uint8List,
      guideVersePub.hash!,
    );

    // BlockRanges + Notes
    int? extractMepsDocumentId = extract['RefMepsDocumentId'];
    int? firstParagraphId = extract['RefBeginParagraphOrdinal'];
    int? lastParagraphId = extract['RefEndParagraphOrdinal'];

    List<BlockRange> blockRanges = [];
    List<Map<String, dynamic>> notes = [];

    if (extractMepsDocumentId != null) {
      blockRanges = await JwLifeApp.userdata.getBlockRangesFromDocumentId(
        extractMepsDocumentId,
        mepsLanguageIndex,
        startParagraph: firstParagraphId,
        endParagraph: lastParagraphId,
      );

      notes = await JwLifeApp.userdata.getNotesFromDocumentId(
        extractMepsDocumentId,
        mepsLanguageIndex,
        startParagraph: firstParagraphId,
        endParagraph: lastParagraphId,
      );
    }

    extractItems.add({
      'type': 'publication',
      'content': decodedHtml,
      'className':
      "publicationCitation html5 pub-${extract['UndatedSymbol']} docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${refPub?.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName} dir-${refPub?.mepsLanguage.isRtl ?? false ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
      'subtitle': caption,
      'imageUrl': image,
      'mepsDocumentId': extractMepsDocumentId ?? -1,
      'mepsLanguageId': mepsLanguageIndex,
      'startParagraphId': firstParagraphId,
      'endParagraphId': lastParagraphId,
      'publicationTitle': refPub?.getShortTitle() ?? extract['ShortTitle'],
      'blockRanges': blockRanges,
      'notes': notes,
    });
  }

  return {
    'items': extractItems,
    'title': i18n().label_icon_extracted_content,
  };
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
          INNER JOIN Document ON Footnote.DocumentId = Document.DocumentId
          WHERE Document.MepsDocumentId = ? AND Footnote.FootnoteIndex = ?
        ''',
        [publication.documentsManager!.getCurrentDocument().mepsDocumentId, footNoteId]);
  }
  else {
    response = await publication.documentsManager!.database.rawQuery(
        '''
          SELECT Footnote.* FROM Footnote 
          INNER JOIN Document ON Footnote.DocumentId = Document.DocumentId
          WHERE Document.MepsDocumentId = ? AND Footnote.FootnoteIndex = ?
        ''',
        [publication.documentsManager!.getCurrentDocument().mepsDocumentId, footNoteId]);

  }

  if (response.isNotEmpty) {
    final footNote = response.first;

    /// Décoder le contenu
    final decodedHtml = decodeBlobContent(footNote['Content'] as Uint8List, publication.hash!);

    return {
      'type': 'note',
      'content': decodedHtml,
      'className': "document html5 pub-${publication.keySymbol} docId-${publication.documentsManager!.getCurrentDocument().mepsDocumentId} docClass-13 jwac showRuby ml-${publication.mepsLanguage.symbol} ms-${publication.mepsLanguage.internalScriptName} dir-${publication.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
      'title': i18n().label_icon_footnotes,
    };
  }
  return {
    'type': 'note',
    'content': '',
    'className': '',
    'title': i18n().label_icon_footnotes,
  };
}

Future<Map<String, dynamic>> fetchVersesReference(BuildContext context, Publication bible, String versesReferenceId) async {
  List<Map<String, dynamic>> response = await bible.documentsManager!.database.rawQuery(
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
      [bible.documentsManager!.getCurrentDocument().mepsDocumentId, versesReferenceId]);

  if (response.isNotEmpty) {
    List<Map<String, dynamic>> verseReferences = [];

    // Process each verse in the response
    for (var verse in response) {
      int book = verse['BookNumber'];
      int chapter = verse['ChapterNumber'];
      int verseNumber = verse['VerseNumber'];

      final String langCode = bible.mepsLanguage.primaryIetfCode;

      String verseDisplay = JwLifeApp.bibleCluesInfo.getVerses(book, chapter, verseNumber, book, chapter, verseNumber);

      final StringBuffer htmlBuffer = StringBuffer();
      String label = verse['Label'] ?? '';
      if(label.isNotEmpty) {
        label = label.replaceAllMapped(_clRegex, (m) =>
        '<span class="cl"><strong>${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</strong> </span>'
        ).replaceAllMapped(_vlRegex, (m) =>
        '<span class="vl">${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</span>'
        );
      }
      htmlBuffer.write(label);
      if (verse['Content'] != null) {
        String decoded = decodeBlobContent(verse['Content'] as Uint8List, bible.hash!);
        if (label.isEmpty) {
          final pid = verse['BeginParagraphOrdinal'];
          htmlBuffer.write('<p id="p$pid" data-pid="$pid" class="sw">$decoded</p>');
        }
        else {
          htmlBuffer.write(decoded);
        }
      }

      final blockRanges = await JwLifeApp.userdata.getBlockRangesFromChapterNumber(
          book, chapter, chapter, bible.keySymbol, bible.mepsLanguage.id,
          startVerse: verseNumber, endVerse: verseNumber
      );

      verseReferences.add({
        'type': 'verse-references',
        'content': htmlBuffer.toString(),
        'className': "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-${bible.mepsLanguage.internalScriptName} dir-${bible.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'imageUrl': bible.imageSqr,
        'verseTitleDiaplay': verseDisplay,
        'languageText': bible.mepsLanguage.vernacular,
        'keySymbol': bible.keySymbol,
        'bookNumber': verse['BookNumber'],
        'chapterNumber': verse['ChapterNumber'],
        'firstVerseNumber': verse['VerseNumber'],
        'lastVerseNumber': verse['VerseNumber'],
        'mepsLanguageId': bible.mepsLanguage.id,
        'verse': verse['ElementNumber'],
        'blockRanges': blockRanges.map((br) => br.toMap()).toList(),
        'notes': context.read<NotesController>().getNotesByDocument(
            firstBookNumber: verse['BookNumber'], lastBookNumber: verse['BookNumber'],
            firstChapterNumber: verse['ChapterNumber'], lastChapterNumber: verse['ChapterNumber'],
            firstBlockIdentifier: verse['VerseNumber'], lastBlockIdentifier: verse['VerseNumber']
        ).map((n) => n.toMap()).toList(),
      });
    }

    return {
      'verseReferences': verseReferences,
      'title': i18n().label_icon_marginal_references,
    };
  }
  return {
    'verseReferences': [],
    'title': i18n().label_icon_marginal_references,
  };
}

Future<Map<String, dynamic>> fetchCommentaries(BuildContext context, Publication publication, String link) async {
  final Map<String, dynamic> resultData = {'items': [], 'title': i18n().label_icon_commentary};

  try {
    // 1. Parsing du lien
    final parts = link.split(r'$p');
    if (parts.length != 2) return resultData;

    final mainPart = parts[0].replaceAll('jwpub://c/', '');
    final mainSegments = mainPart.split('/');
    if (mainSegments.length < 2) return resultData;

    final langAndBook = mainSegments[0].split(':');
    final chapterAndVerse = mainSegments[1].split(':');

    final commentarySegments = parts[1].split('/');
    if (commentarySegments.length < 3) return resultData;

    final langAndDocComm = commentarySegments[1].split(':');
    final paragraphs = commentarySegments[2].split(':').first.split('-');

    final int bookDocId = int.parse(langAndBook[1]);
    int bookNumber = 0;
    final int chapterNum = int.parse(chapterAndVerse[0]);
    final int verseNum = int.parse(chapterAndVerse[1]);
    final int commDocId = int.parse(langAndDocComm[1]);
    final int startP = int.parse(paragraphs[0]);
    final int endP = int.parse(paragraphs.length > 1 ? paragraphs[1] : paragraphs[0]);

    // 2. Accès Base de données
    final bible = publication.isBible() ? publication : PublicationRepository().getLookUpBible();
    if (bible == null) return resultData;

    Database? db;
    bool mustCloseDb = false;

    if (bible.documentsManager?.database != null) {
      db = bible.documentsManager!.database;
    } else if (bible.databasePath != null) {
      db = await openReadOnlyDatabase(bible.databasePath!);
      mustCloseDb = true;
    }

    if (db == null) return resultData;

    try {
      // 3. Récupération du verset
      final verseResponse = await db.rawQuery('''
        SELECT 
            v.Label, 
            v.Content,
            c.BookNumber
        FROM BibleVerse v
        INNER JOIN BibleChapter c ON c.ChapterNumber = ?
        INNER JOIN Document d ON c.BookNumber = d.ChapterNumber
        WHERE d.MepsDocumentId = ?
          AND v.BibleVerseId = (c.FirstVerseId + ? - (c.FirstVerseId - (SELECT LastVerseId FROM BibleChapter WHERE BibleChapterId = c.BibleChapterId - 1)));
      ''', [chapterNum, bookDocId, verseNum]);

      if (verseResponse.isEmpty) return resultData;

      bookNumber = verseResponse.first['BookNumber'] as int? ?? 0;

      final StringBuffer htmlBuffer = StringBuffer();
      final String langCode = bible.mepsLanguage.primaryIetfCode;

      String label = verseResponse.first['Label'] as String? ?? '';

      if (label.isNotEmpty) {
        label = label.replaceAllMapped(_clRegex, (m) {
          // On vérifie que le groupe 1 existe pour éviter un crash au parse
          final group1 = m.group(1);
          if (group1 == null) return m.group(0)!;
          return '<span class="cl"><strong>${formatNumber(int.parse(group1), localeCode: langCode)}</strong> </span>';
        }).replaceAllMapped(_vlRegex, (m) {
          final group1 = m.group(1);
          if (group1 == null) return m.group(0)!;
          return '<span class="vl">${formatNumber(int.parse(group1), localeCode: langCode)}</span>';
        });
      }

      htmlBuffer.write(label);

      if (verseResponse.first['Content'] != null) {
        String decoded = decodeBlobContent(verseResponse.first['Content'] as Uint8List, bible.hash!);
        htmlBuffer.write(decoded);
      }

      // 4. Récupération et filtrage des commentaires
      final commentaryResponse = await db.rawQuery('''
        SELECT Content FROM VerseCommentary
        WHERE CommentaryMepsDocumentId = ? AND EndParagraphOrdinal >= ? AND BeginParagraphOrdinal <= ?
      ''', [commDocId, startP, endP]);

      final List<Map<String, dynamic>> commentaries = [];
      for (var row in commentaryResponse) {
        final fullHtml = decodeBlobContent(row['Content'] as Uint8List, bible.hash ?? '');

        // Filtrage HTML intégré
        final document = parse(fullHtml);
        final buffer = StringBuffer();
        for (var p in document.querySelectorAll('p')) {
          final pid = int.tryParse(p.attributes['data-pid'] ?? '');
          if (pid != null && pid >= startP && pid <= endP) {
            buffer.write(p.outerHtml);
          }
        }

        commentaries.add({
          'type': 'commentary',
          'content': buffer.isEmpty ? fullHtml : buffer.toString(),
          'className': "scriptureIndexLink html5 layout-reading layout-sidebar",
        });
      }

      final blockRanges = await JwLifeApp.userdata.getBlockRangesFromChapterNumber(
          bookNumber, chapterNum, chapterNum, bible.keySymbol, bible.mepsLanguage.id,
          startVerse: verseNum, endVerse: verseNum
      );

      return {
        'type': 'commentary',
        'commentaries': commentaries,
        'title': i18n().label_icon_commentary,
        'imageUrl': bible.imageSqr,
        'verseTitleDiaplay': JwLifeApp.bibleCluesInfo.getVerse(bookNumber, chapterNum, verseNum),
        'bibleTitle': bible.mepsLanguage.vernacular,
        'keySymbol': bible.keySymbol,
        'bookNumber': bookNumber,
        'chapterNumber': chapterNum,
        'verseNumber': verseNum,
        'mepsLanguageId': bible.mepsLanguage.id,
        'verseContent': htmlBuffer.toString(),
        'verseClassName': "bibleCitation html5 pub-${bible.keySymbol} jwac showRuby ml-${bible.mepsLanguage.symbol} ms-${bible.mepsLanguage.internalScriptName} dir-${bible.mepsLanguage.isRtl ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
        'blockRanges': blockRanges.map((br) => br.toMap()).toList(),
        'notes':  context.read<NotesController>().getNotesByDocument(
          firstBookNumber: bookNumber, lastBookNumber: bookNumber,
          firstChapterNumber: chapterNum, lastChapterNumber: chapterNum,
          firstBlockIdentifier: verseNum, lastBlockIdentifier: verseNum
          ).map((n) => n.toMap()).toList(),
        };

    } 
    finally {
      if (mustCloseDb) await db.close();
    }
  } 
  catch (e) {
    print('Error: $e');
    return resultData;
  }
}

Future<List<Map<String, dynamic>>> fetchVerseCommentaries(BuildContext context, Publication publication, int verseId, bool showLabel) async {
  Database db = publication.documentsManager!.database;
  try {
    bool hasCommentaryTable = await checkIfTableExists(db, 'VerseCommentary');
    bool hasCommentaryMepsDocumentIdColumn = hasCommentaryTable ? await checkIfColumnsExists(db, 'VerseCommentary', ['CommentaryMepsDocumentId']) : false;

    if(hasCommentaryTable && hasCommentaryMepsDocumentIdColumn) {
      List<Map<String, dynamic>> response = await db.rawQuery('''
      SELECT
        Label, 
        Content, 
        CommentaryMepsDocumentId
      FROM VerseCommentary
      INNER JOIN VerseCommentaryMap ON VerseCommentary.VerseCommentaryId = VerseCommentaryMap.VerseCommentaryId
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
        bibleDb = await openReadOnlyDatabase(bible.databasePath!);
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

      final String langCode = bible.mepsLanguage.primaryIetfCode;

      final StringBuffer htmlBuffer = StringBuffer();
      String label = results.first['Label'] ?? '';
      if(label.isNotEmpty) {
        label = label.replaceAllMapped(_clRegex, (m) =>
        '<span class="cl"><strong>${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</strong> </span>'
        ).replaceAllMapped(_vlRegex, (m) =>
        '<span class="vl">${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</span>'
        );
      }
      htmlBuffer.write(label);
      if (results.first['Content'] != null) {
        String decoded = decodeBlobContent(results.first['Content'] as Uint8List, bible.hash!);
        if (label.isEmpty) {
          final pid = results.first['BeginParagraphOrdinal'];
          htmlBuffer.write('<p id="p$pid" data-pid="$pid" class="sw">$decoded</p>');
        }
        else {
          htmlBuffer.write(decoded);
        }
      }

      final blockRanges = await JwLifeApp.userdata.getBlockRangesFromChapterNumber(
          book, chapter, chapter, bible.keySymbol, bible.mepsLanguage.id,
          startVerse: verse, endVerse: verse
      );

      versesTranslations.add({
        'type': 'verse',
        'content': htmlBuffer.toString(),
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
        'blockRanges': blockRanges.map((br) => br.toMap()).toList(),
        'notes': context.read<NotesController>().getNotesByDocument(
            firstBookNumber: book, lastBookNumber: book,
            firstChapterNumber: chapter, lastChapterNumber: chapter,
            firstBlockIdentifier: verse, lastBlockIdentifier: verse
        ).map((n) => n.toMap()).toList(),
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
          db = await openReadOnlyDatabase(publication.databasePath!);
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

        List<Map<String, dynamic>> allResponseExtracts = await db.rawQuery('''
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

              int issueTagNumber = int.tryParse(extract['IssueTagNumber']?.toString() ?? '') ?? 0;
              String keySymbol = issueTagNumber != 0 ? extract['UniqueEnglishSymbol'] : extract['UniqueEnglishSymbol'];
              int mepsLanguageIndex = extract['MepsLanguageIndex'];

              final String refKey = '$keySymbol-$issueTagNumber-$mepsLanguageIndex';
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
                'className': "publicationCitation html5 pub-$keySymbol docId-$extractMepsDocumentId docClass-${extract['RefMepsDocumentClass']} jwac showRuby ml-${refPub?.mepsLanguage.symbol ?? publication.mepsLanguage.symbol} ms-${refPub?.mepsLanguage.internalScriptName ?? publication.mepsLanguage.internalScriptName} dir-${(refPub?.mepsLanguage.isRtl ?? publication.mepsLanguage.isRtl) ? 'rtl' : 'ltr'} layout-reading layout-sidebar",
                'subtitle': caption,
                'imageUrl': image,
                'mepsDocumentId': extractMepsDocumentId ?? -1,
                'mepsLanguageId': extract['MepsLanguageIndex'] as int,
                'startParagraphId': firstParagraphId,
                'endParagraphId': lastParagraphId,
                'publicationTitle': refPub == null ? extract['ShortTitle']?.toString() ?? '' : refPub.getShortTitle(),
                'blockRanges': blockRanges.map((b) => b.toMap()).toList(),
                'notes': notes.map((n) => n.toMap()).toList(),
              });
            }
          }
        }

        if (extractItems.isNotEmpty) {
          verseCommentariesByPub.add({
            'type': 'guide',
            'items': extractItems
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
      groupedCitations.forEach((blockNumber, verses) async {
        // NOUVEAU : Liste pour stocker les détails de chaque verset
        List<Map<String, dynamic>> verseDetailsList = [];

        // Déterminer les informations communes pour le groupe (on prend le premier verset)
        final firstVerse = verses.first;

        // Pour les références de versets, on veut l'étendue (ex: Jn 3:16-17)
        final firstV = firstVerse['VerseNumber'] as int;
        final lastV = verses.last['VerseNumber'] as int;
        final bookN = firstVerse['BookNumber'] as int;
        final chapterN = firstVerse['ChapterNumber'] as int;

        String verseDisplay = JwLifeApp.bibleCluesInfo.getVerses(
            bookN, chapterN, firstV,
            bookN, chapterN, lastV
        );

        final StringBuffer htmlBuffer = StringBuffer();
        final String langCode = publication.mepsLanguage.primaryIetfCode;

        // Parcourir tous les versets du groupe pour combiner leur contenu HTML
        for (var verse in verses) {
          String label = verse['Label'] ?? '';
          if (label.isNotEmpty) {
            label = label.replaceAllMapped(_clRegex, (m) =>
            '<span class="cl"><strong>${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</strong> </span>'
            ).replaceAllMapped(_vlRegex, (m) =>
            '<span class="vl">${formatNumber(int.parse(m.group(1)!), localeCode: langCode)}</span>'
            );
          }
          htmlBuffer.write(label);
          if (verse['Content'] != null) {
            String decoded = decodeBlobContent(verse['Content'] as Uint8List, publication.hash!);
            if (label.isEmpty) {
              final pid = verse['BeginParagraphOrdinal'];
              htmlBuffer.write('<p id="p$pid" data-pid="$pid" class="sw">$decoded</p>');
            }
            else {
              htmlBuffer.write(decoded);
            }
          }

          final blockRanges = await JwLifeApp.userdata.getBlockRangesFromChapterNumber(
              bookN, chapterN, chapterN, publication.keySymbol, publication.mepsLanguage.id,
              startVerse: firstV, endVerse: lastV
          );

          verseDetailsList.add({
            'bookNumber': bookN,
            'chapterNumber': chapterN,
            'firstVerseNumber': firstV,
            'lastVerseNumber': lastV,
            'bookDisplay': JwLifeApp.bibleCluesInfo.getVerse(bookN, chapterN, verse['VerseNumber'], type: 'officialBookAbbreviation'),
            'bibleVerseDisplay': JwLifeApp.bibleCluesInfo.getVerse(bookN, chapterN, verse['VerseNumber']),
            'content': htmlBuffer.toString(), // Contenu HTML du verset individuel
            'label': label,
            'blockRanges': blockRanges.map((br) => br.toMap()).toList(),
            'notes': context.read<NotesController>().getNotesByDocument(
                firstBookNumber: bookN, lastBookNumber: bookN,
                firstChapterNumber: chapterN, lastChapterNumber: chapterN,
                firstBlockIdentifier: firstV, lastBlockIdentifier: lastV
            ).map((n) => n.toMap()).toList(),
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

InAppWebViewSettings getWebViewSettings() {
  return InAppWebViewSettings(
    scrollBarStyle: null,
    verticalScrollBarEnabled: false,
    horizontalScrollBarEnabled: false,
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    useOnLoadResource: false,
    allowUniversalAccessFromFileURLs: true,
    allowFileAccess: true,
    allowContentAccess: true,
    useHybridComposition: true,
    hardwareAcceleration: true,
    allowsLinkPreview: false,
    disableDefaultErrorPage: true,
    transparentBackground: true,
  );
}
