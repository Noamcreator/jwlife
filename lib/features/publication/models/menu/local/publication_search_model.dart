import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../../../../core/utils/utils.dart';
import 'position_adjustement.dart';

class PublicationSearchModel {
  final Publication publication;
  final List<Map<String, dynamic>> _documents = [];
  final List<Map<String, dynamic>> _verses = [];
  int nbWordResultsInDocuments = 0;
  int nbWordResultsInVerses = 0;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> verses = [];
  List<int> versesRanking = [];

  List<String> wordsSelectedDocument = [];
  List<String> wordsSelectedVerse = [];

  PublicationSearchModel(this.publication);

  /* DOCUMENTS */
  Future<List<Map<String, dynamic>>> getDocuments(List<int> textUnitIds) async {
    final searchResults = await publication.documentsManager!.database.rawQuery('''
    SELECT DocumentId, Title, MepsDocumentId, Content, TextPositions, TextLengths, ScopeParagraphData
    FROM Document
    LEFT JOIN TextUnit ON Document.DocumentId = TextUnit.Id
    LEFT JOIN SearchTextRangeDocument ON TextUnit.Id = SearchTextRangeDocument.TextUnitId
    WHERE TextUnit.Type = 'Document' AND TextUnit.Id IN (${textUnitIds.join(',')})
  ''');

    return searchResults.isNotEmpty ? searchResults : [];
  }

  Future<List<Map<String, dynamic>>> getParagraphs(List<int> documentIds) async {
    final searchResults = await publication.documentsManager!.database.rawQuery('''
      SELECT 
        Document.DocumentId,
        DocumentParagraph.ParagraphIndex,
        DocumentParagraph.BeginPosition, 
        DocumentParagraph.EndPosition
      FROM 
        Document
      LEFT JOIN 
        DocumentParagraph ON Document.DocumentId = DocumentParagraph.DocumentId
      WHERE 
        Document.DocumentId IN (${documentIds.join(',')});
    ''');

    return searchResults.isNotEmpty ? searchResults : [];
  }

  Future<void> searchDocuments(String query, int mode, {bool newSearch = false}) async {
    if(newSearch) {
      _documents.clear();
    }
    wordsSelectedDocument = query.trim().split(RegExp(r'\s+'));

    nbWordResultsInDocuments = 0;
    documents.clear();

    if(_documents.isEmpty) {
      List<Set<int>> documentIdSets = [];
      Map<int, Map<String, dynamic>> tempDocuments = {};

      await Future.wait(wordsSelectedDocument.map((queryWord) async {
        final results = await searchWordInDocuments(queryWord);

        if (results.isNotEmpty) {
          final docIds = results.map((doc) => doc['documentId'] as int).toSet();
          documentIdSets.add(docIds);

          for (var rawDoc in results) {
            final doc = Map<String, dynamic>.from(rawDoc);
            final int id = doc['documentId'] as int;

            final List<Map<String, dynamic>> newParagraphs = (doc['paragraphs'] as List)
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();

            if (tempDocuments.containsKey(id)) {
              tempDocuments[id]!['occurrences'] += doc['occurrences'] as int;

              final existingParagraphs = tempDocuments[id]!['paragraphs'] as List<dynamic>;

              for (var newPara in newParagraphs) {
                final paraId = newPara['paragraphId'];
                final List<Map<String, dynamic>> newWords = (newPara['words'] as List)
                    .map((w) => Map<String, dynamic>.from(w as Map))
                    .toList();

                final existingIndex = existingParagraphs.indexWhere(
                        (p) => (p as Map)['paragraphId'] == paraId);

                if (existingIndex != -1) {
                  final existingPara = Map<String, dynamic>.from(existingParagraphs[existingIndex]);
                  final List<Map<String, dynamic>> existingWords = (existingPara['words'] as List)
                      .map((w) => Map<String, dynamic>.from(w as Map))
                      .toList();

                  final existingIndexes = existingWords.map((w) => w['index']).toSet();
                  final mergedWords = [
                    ...existingWords,
                    ...newWords.where((w) => !existingIndexes.contains(w['index']))
                  ];

                  existingPara['words'] = mergedWords..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
                  existingParagraphs[existingIndex] = existingPara;
                } else {
                  existingParagraphs.add(newPara);
                }
              }
            } else {
              tempDocuments[id] = {
                ...doc,
                'paragraphs': newParagraphs,
              };
            }
          }
        }
      }));

      if (documentIdSets.isNotEmpty) {
        final commonDocumentIds = documentIdSets.reduce((a, b) => a.intersection(b));
        _documents.addAll(tempDocuments.entries
            .where((entry) => commonDocumentIds.contains(entry.key))
            .map((e) => e.value));
      }
    }

    if (mode == 1 || wordsSelectedDocument.length == 1) {
      documents = List<Map<String, dynamic>>.from(_documents);
    }
    else if (mode == 2) {
      final int expectedWordCount = wordsSelectedDocument.length;

      documents = _documents.map((doc) {
        final paragraphs = doc['paragraphs'] as List<dynamic>;

        final matchingParagraphs = <dynamic>[];

        for (final para in paragraphs) {
          final words = para['words'] as List<dynamic>;
          if (words.length < expectedWordCount) continue;

          for (int i = 0; i <= words.length - expectedWordCount; i++) {
            bool sequenceMatch = true;

            for (int j = 1; j < expectedWordCount; j++) {
              final currentIndex = words[i + j]['index'] as int;
              final prevIndex = words[i + j - 1]['index'] as int;

              if (currentIndex != prevIndex + 1) {
                sequenceMatch = false;
                break;
              }
            }

            if (sequenceMatch) {
              matchingParagraphs.add(para);
              break;
            }
          }
        }

        if (matchingParagraphs.isEmpty) return null;

        return {
          ...doc,
          'paragraphs': matchingParagraphs,
          'occurrences': matchingParagraphs.length,
        };
      }).whereType<Map<String, dynamic>>().toList();
    }

    for (var doc in documents) {
      nbWordResultsInDocuments += doc['occurrences'] as int;
    }

    documents.sort((a, b) => b['occurrences'].compareTo(a['occurrences']));
  }

  Future<List<Map<String, dynamic>>> searchWordInDocuments(String query) async {
    final Map<int, Map<String, dynamic>> tempDocuments = {};

    final searchResults = await publication.documentsManager!.database.rawQuery('''
    SELECT TextUnitCount, WordOccurrenceCount, TextUnitIndices, PositionalList, PositionalListIndex
    FROM SearchIndexDocument
    LEFT JOIN Word ON SearchIndexDocument.WordId = Word.WordId
    WHERE Word.Word LIKE ?
    ''', [query]);

    if (searchResults.isNotEmpty) {
      final documentIds = getTextUnitIds(searchResults.first['TextUnitIndices'] as Uint8List);
      final wordOccurrencesInDocuments = getOccurrenceByDocument(searchResults.first['PositionalListIndex'] as Uint8List);
      final wordPositionalsListInDocuments = getPositionsInDocument(searchResults.first['PositionalList'] as Uint8List, wordOccurrencesInDocuments);

      final docs = await getDocuments(documentIds);
      final paragraphs = await getParagraphs(documentIds);

      for (int i = 0; i < documentIds.length; i++) {
        final document = docs[i];
        final positions = getWordsPositionsAndParagraphId(document['TextPositions']);
        final lengths = getWordsLengths(document['TextLengths']);

        tempDocuments.putIfAbsent(documentIds[i], () => {
          'documentId': documentIds[i],
          'mepsDocumentId': document['MepsDocumentId'],
          'title': document['Title'],
          'occurrences': 0,
          'paragraphs': <int, Map<String, dynamic>>{}
        });

        final docEntry = tempDocuments[documentIds[i]]!;

        docEntry['occurrences'] += wordOccurrencesInDocuments[i];

        for(int wordPositionalsListInDocument in wordPositionalsListInDocuments[i]) {
          final wordPosition = positions.elementAtOrNull(wordPositionalsListInDocument);
          final wordLength = lengths.elementAtOrNull(wordPositionalsListInDocument);

          if (wordPosition != null && wordLength != null) {
            final paragraphPosition = paragraphs.where((element) => element['DocumentId'] == documentIds[i] && element['ParagraphIndex'] == wordPosition['paragraphId']).firstOrNull;

            if (paragraphPosition != null) {
              String paragraphText = '';
              int? paragraphId = wordPosition['paragraphId'];

              if (!docEntry['paragraphs'].containsKey(paragraphId)) {
                final beginPosition = paragraphPosition['BeginPosition'];
                final endPosition = paragraphPosition['EndPosition'];

                if (beginPosition != null && endPosition != null) {
                  final documentBlob = decodeBlobParagraph(
                      document['Content'], publication.hash!);
                  final paragraphBlob = documentBlob.sublist(
                      beginPosition, endPosition);
                  final paragraphHtml = utf8.decode(paragraphBlob);
                  paragraphText = parse(paragraphHtml).body?.text ?? '';
                }

                docEntry['paragraphs'][paragraphId] = {
                  'paragraphId': paragraphId,
                  'paragraphText': paragraphText,
                  'words': <Map<String, int?>>[],
                };
              }

              docEntry['paragraphs'][paragraphId]['words'].add({
                'index': wordPositionalsListInDocument,
                'startHighlight': wordPosition['position'],
                'endHighlight': (wordPosition['position'] ?? 0) + wordLength,
              });
            }
          }
        }
      }
    }

    for (var doc in tempDocuments.values) {
      doc['paragraphs'] = (doc['paragraphs'] as Map<int, Map<String, dynamic>>).values.toList();
    }

    return tempDocuments.values.toList();
  }

  Future<List<Map<String, dynamic>>> getVerses(List<int> bibleVerseIds) async {
    final searchResults = await publication.documentsManager!.database.rawQuery('''
      SELECT BibleVerseId, Content, AdjustmentInfo, TextPositions, TextLengths
      FROM BibleVerse
      LEFT JOIN SearchTextRangeBibleVerse ON BibleVerse.BibleVerseId = SearchTextRangeBibleVerse.TextUnitId
      WHERE BibleVerseId IN (${bibleVerseIds.join(',')});
    ''');

    return searchResults.isNotEmpty ? searchResults : [];
  }

  Future<void> searchBibleVerses(String query, int mode, {bool newSearch = false}) async {
    if(newSearch) {
      _verses.clear();
    }
    wordsSelectedVerse = query.trim().split(RegExp(r'\s+'));

    nbWordResultsInVerses = 0;
    verses.clear();

    // Optimisation : Charge le classement une seule fois si besoin
    if (versesRanking.isEmpty) {
      await findRankingBlob();
    }

    if ( _verses.isEmpty && wordsSelectedVerse.isNotEmpty) {
      List<Set<int>> verseIdSets = [];
      Map<int, Map<String, dynamic>> tempVerses = {};

      await Future.wait(wordsSelectedVerse.map((queryWord) async {
        final results = await searchWordInBibleVerses(queryWord);

        Set<int> currentWordVerseIds = {};

        for (var result in results) {
          int verseId = result['verseId'];
          int bookNumber = result['bookNumber'];
          int chapterNumber = result['chapterNumber'];
          int verseNumber = result['verseNumber'];
          String verseText = result['verse'];
          int occurrences = result['occurrences'];
          List<Map<String, int?>> words = List<Map<String, int?>>.from(result['words']);

          currentWordVerseIds.add(verseId);

          tempVerses.putIfAbsent(verseId, () => {
            'verseId': verseId,
            'bookNumber': bookNumber,
            'chapterNumber': chapterNumber,
            'verseNumber': verseNumber,
            'verse': verseText,
            'occurrences': occurrences,
            'words': <Map<String, int?>>[]
          });

          final existingWords = tempVerses[verseId]!['words'] as List<Map<String, int?>>;

          final existingIndexes = existingWords.map((w) => w['index']).toSet();
          final mergedWords = [
            ...existingWords,
            ...words.where((w) => !existingIndexes.contains(w['index']))
          ];

          tempVerses[verseId]!['words'] = mergedWords..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
        }

        if (currentWordVerseIds.isNotEmpty) {
          verseIdSets.add(currentWordVerseIds);
        }
      }));

      if (verseIdSets.isNotEmpty) {
        final commonVerseIds = verseIdSets.reduce((a, b) => a.intersection(b));
        _verses.addAll(tempVerses.entries.where((entry) => commonVerseIds.contains(entry.key)).map((e) => e.value));
      }
    }

    if (mode == 1 || wordsSelectedVerse.length == 1) {
      verses = List<Map<String, dynamic>>.from(_verses);
    }
    else if (mode == 2) {
      final int expectedWordCount = wordsSelectedVerse.length;

      final List<Map<String, dynamic>> matchingVerses = [];

      for (final verse in _verses) {
        final words = verse['words'] as List<dynamic>;

        if (words.length < expectedWordCount) {
          continue;
        }

        bool hasConsecutiveSequence = false;
        for (int i = 0; i <= words.length - expectedWordCount; i++) {
          bool sequenceMatch = true;

          for (int j = 1; j < expectedWordCount; j++) {
            final int currentIndex = words[i + j]['index'] as int;
            final int prevIndex = words[i + j - 1]['index'] as int;

            if (currentIndex != prevIndex + 1) {
              sequenceMatch = false;
              break;
            }
          }

          if (sequenceMatch) {
            hasConsecutiveSequence = true;
            break;
          }
        }

        if (hasConsecutiveSequence) {
          matchingVerses.add({
            ...verse,
          });
        }
      }

      verses = matchingVerses;
    }

    for (var verse in verses) {
      nbWordResultsInVerses += verse['occurrences'] as int;
    }
  }

  Future<List<Map<String, dynamic>>> searchWordInBibleVerses(String query) async {
    final Map<int, Map<String, dynamic>> tempVerses = {};

    final searchResults = await publication.documentsManager!.database.rawQuery('''
      SELECT TextUnitCount, WordOccurrenceCount, TextUnitIndices, PositionalList, PositionalListIndex
      FROM SearchIndexBibleVerse
      LEFT JOIN Word ON SearchIndexBibleVerse.WordId = Word.WordId
      WHERE Word.Word LIKE ?
    ''', [query]);

    if (searchResults.isNotEmpty) {
      final bibleVerseIds = getTextUnitIds(searchResults.first['TextUnitIndices'] as Uint8List);
      final wordOccurrencesInVerses = getOccurrenceByDocument(searchResults.first['PositionalListIndex'] as Uint8List);
      final wordPositionalsListInVerses = getPositionsInDocument(searchResults.first['PositionalList'] as Uint8List, wordOccurrencesInVerses);

      final bibleVerses = await getVerses(bibleVerseIds);
      final versesById = { for (var v in bibleVerses) v['BibleVerseId'] as int : v };

      for (int i = 0; i < bibleVerseIds.length; i++) {
        final verseId = bibleVerseIds[i];
        final verse = versesById[verseId];

        if (verse == null) continue;

        final positions = getWordsPositionsAndParagraphId(verse['TextPositions']);
        final lengths = getWordsLengths(verse['TextLengths']);

        String verseHtml = decodeBlobContent(verse['Content'], publication.hash!);

        List<PositionAdjustment> adjustments = verse['AdjustmentInfo'] == null ? [] : getAdjustmentsInfo(verse['AdjustmentInfo']);

        RegExp regExp = RegExp(r'id="v(\d+)-(\d+)-(\d+)"');
        Match? match = regExp.firstMatch(verseHtml);

        int bookNumber = 0;
        int chapterNumber = 0;
        int verseNumber = 0;

        if (match != null) {
          bookNumber = int.parse(match.group(1)!);
          chapterNumber = int.parse(match.group(2)!);
          verseNumber = int.parse(match.group(3)!);
        }
        else {
          printTime('Aucune correspondance trouvée');
        }

        String verseText = parse(verseHtml).body?.text ?? '';
        final wordOccurrences = wordOccurrencesInVerses[i];
        final wordPositionals = wordPositionalsListInVerses[i];

        tempVerses.putIfAbsent(verseId, () => {
          'verseId': verseId,
          'bookNumber': bookNumber,
          'chapterNumber': chapterNumber,
          'verseNumber': verseNumber,
          'verse': verseText,
          'occurrences': 0,
          'words': <Map<String, int?>>[]
        });

        final verseEntry = tempVerses[verseId]!;

        verseEntry['occurrences'] += wordOccurrences;

        for(int j = 0; j < wordOccurrences; j++) {
          final wordPositionalListIndex = wordPositionals[j];
          final wordPosition = positions.elementAtOrNull(wordPositionalListIndex);
          final wordLength = lengths.elementAtOrNull(wordPositionalListIndex);

          if (wordPosition != null && wordLength != null) {
            int start = adjustPosition(wordPosition['position']!, adjustments);
            int end = start + wordLength;

            verseEntry['words'].add({
              'index': wordPositionalListIndex,
              'startHighlight': start,
              'endHighlight': end,
            });
          }
        }
      }
    }

    return tempVerses.values.toList();
  }

  void sortVerses(int type) {
    if(type == 0) {
      verses.sort((a, b) => a['verseId'].compareTo(b['verseId']));
    }
    else if(type == 1) {
      if (versesRanking.isNotEmpty && versesRanking.length > 0) {
        verses.sort((verse1, verse2) {
          final int verseId1 = verse1['verseId'];
          final int verseId2 = verse2['verseId'];

          int rank1 = (verseId1 < versesRanking.length && versesRanking.elementAt(verseId1) != -1) ? versesRanking.elementAt(verseId1) : 999999;
          int rank2 = (verseId2 < versesRanking.length && versesRanking.elementAt(verseId2) != -1) ? versesRanking.elementAt(verseId2) : 999999;

          return rank1.compareTo(rank2);
        });
      } else {
        verses.sort((a, b) => a['verseId'].compareTo(b['verseId']));
      }
    }
    else if(type == 2) {
      verses.sort((a, b) => b['occurrences'].compareTo(a['occurrences']));
    }
  }

  Future<void> findRankingBlob() async {
    List<Map<String, dynamic>> rankingResult = await publication.documentsManager!.database.rawQuery('''
      SELECT RankingData FROM BibleVerseRanking WHERE Keyword = '<default>';
    ''');

    List<Map<String, dynamic>> countResult = await publication.documentsManager!.database.rawQuery('''
      SELECT COUNT(*) FROM BibleVerse;
    ''');

    Uint8List versesRankingBlob = rankingResult.isNotEmpty ? rankingResult.first['RankingData'] as Uint8List : Uint8List(0);
    int nbMaxVerses = countResult.isNotEmpty ? countResult.first['COUNT(*)'] as int : 0;

    getVersesRanking(versesRankingBlob, nbMaxVerses);
  }

  void getVersesRanking(Uint8List versesRankingBlob, int nbMaxVerses) {
    if (versesRankingBlob.length % 2 != 0 || versesRankingBlob.length != nbMaxVerses * 2) {
      printTime("Erreur: Taille BLOB/nb versets incohérente.");
      versesRanking = List.filled(nbMaxVerses + 1, 999999);
      return;
    }

    versesRanking = List.filled(nbMaxVerses + 1, 999999);
    int index = 0;
    int nbRanking = 0;

    while (index < versesRankingBlob.length) {
      int byte0 = versesRankingBlob[index++] & 0xFF;
      int byte1 = versesRankingBlob[index++] & 0xFF;
      int verseId = byte0 + (byte1 << 8);

      if (verseId >= versesRanking.length) {
        printTime("VerseId trop grand: $verseId");
        break;
      }

      versesRanking[verseId] = nbRanking++;
    }
  }

  List<PositionAdjustment> getAdjustmentsInfo(Uint8List data) {
    List<PositionAdjustment> adjustments = [];
    int currentIndex = 0;

    while (currentIndex < data.length) {
      final List<int> operationCodeHolder = [0];
      final int bytesForOp = decodeVariableLengthInt(data, currentIndex, operationCodeHolder);
      currentIndex += bytesForOp;

      final List<int> positionHolder = [0];
      final int bytesForPos = decodeVariableLengthInt(data, currentIndex, positionHolder);
      currentIndex += bytesForPos;

      final List<int> lengthHolder = [0];
      final int bytesForLen = decodeVariableLengthInt(data, currentIndex, lengthHolder);
      currentIndex += bytesForLen;

      final AdjustmentType type = (operationCodeHolder[0] == 0) ? AdjustmentType.delete : AdjustmentType.insert;

      adjustments.add(PositionAdjustment(
        type: type,
        position: positionHolder[0],
        length: lengthHolder[0],
      ));
    }

    return adjustments;
  }

  List<int> getTextUnitIds(Uint8List bytes) {
    final textUnitIds = <int>[];
    int sum = 0;
    for (int byte in bytesVLQToIntList(bytes)) {
      sum += byte;
      textUnitIds.add(sum);
    }
    return textUnitIds;
  }

  List<int> getOccurrenceByDocument(Uint8List bytes) => bytesVLQToIntList(bytes);

  List<List<int>> getPositionsInDocument(Uint8List bytes, List<int> occurrencesByDocument) {
    final allPositions = bytesVLQToIntList(bytes);
    final groupedPositions = <List<int>>[];

    int index = 0;
    for (int occurrences in occurrencesByDocument) {
      if (index + occurrences > allPositions.length) {
        throw ArgumentError("Les occurrences dépassent la taille de la liste des positions.");
      }

      groupedPositions.add(allPositions.sublist(index, index + occurrences));
      index += occurrences;
    }

    return groupedPositions;
  }

  List<Map<String, int>> getWordsPositionsAndParagraphId(Uint8List positionBytes) {
    final positionList = <Map<String, int>>[];
    int currentPosition = 0;
    int index = 0;

    while (index < positionBytes.length) {
      final tempValue = [0];
      index += decodeVLQ(positionBytes, index, tempValue);
      currentPosition += tempValue[0];
      positionList.add({
        "position": currentPosition & 0xFFFF,
        "paragraphId": ((currentPosition >> 16) & 0xFFFF)+1
      });
    }

    return positionList;
  }

  List<int> getWordsLengths(Uint8List lengthBytes) {
    final lengthList = <int>[];
    int index = 0;

    while (index < lengthBytes.length) {
      final tempValue = [0];
      index += decodeVLQ(lengthBytes, index, tempValue);
      lengthList.add(tempValue[0]);
    }

    return lengthList;
  }

  int countUsedBits(int b) {
    int count = 0;
    while (b != 0) {
      count++;
      b >>= 1;
    }
    return count;
  }

  List<int> bytesVLQToIntList(Uint8List bytes) {
    final intList = <int>[];
    int curInt = 0;
    int bitCount = 0;

    for (int b in bytes) {
      final isLastByte = (b & 0x80) != 0;
      final sevenBits = b & 0x7F;

      curInt |= sevenBits << bitCount;
      bitCount += isLastByte ? countUsedBits(sevenBits) : 7;

      if (bitCount > 32) {
        throw ArgumentError("Dépassement VLQ de 32 bits.");
      }

      if (isLastByte) {
        intList.add(curInt);
        curInt = 0;
        bitCount = 0;
      }
    }

    if (bitCount != 0) {
      throw ArgumentError("Suite de bytes invalide : pas de terminaison.");
    }

    return intList;
  }

  int decodeVLQ(Uint8List byteArray, int startIndex, List<int> decodedValue) {
    decodedValue[0] = 0;
    int readIndex = 0;
    int shiftFactor = 0;

    while (true) {
      final currentByte = byteArray[startIndex + readIndex];

      if ((currentByte & 0x80) != 0) {
        decodedValue[0] += (currentByte & 0x7F) << (shiftFactor * 7);
        return readIndex + 1;
      }

      decodedValue[0] += currentByte << (shiftFactor * 7);
      readIndex++;
      shiftFactor++;
    }
  }

  int decodeVariableLengthInt(List<int> buffer, int startIndex, List<int> resultHolder) {
    resultHolder[0] = 0;
    int currentOffset = 0;
    int shiftCount = 0;

    while (true) {
      int currentByte = buffer[startIndex + currentOffset];
      if ((currentByte & 128) == 0) {
        currentOffset++;
        resultHolder[0] = resultHolder[0] + (currentByte << (shiftCount * 7));
        shiftCount++;
      } else {
        int bytesRead = currentOffset + 1;
        resultHolder[0] = resultHolder[0] + ((currentByte & 127) << (shiftCount * 7));
        return bytesRead;
      }
    }
  }

  int adjustPosition(int originalPosition, List<PositionAdjustment> adjustments) {
    int adjustedPosition = originalPosition;

    for (final adj in adjustments) {
      if (adj.position < adjustedPosition) {
        if (adj.type == AdjustmentType.delete) {
          adjustedPosition -= adj.length;
        }
        else if (adj.type == AdjustmentType.insert) {
          adjustedPosition += adj.length;
        }
      }
    }

    return adjustedPosition;
  }
}