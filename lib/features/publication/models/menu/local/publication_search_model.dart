import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils_database.dart';
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

  Future<void> searchDocuments(String query, int searchScope, {bool newSearch = false}) async {
    if (newSearch) {
      _documents.clear();
    }
    
    // On normalise les mots de la recherche pour la comparaison
    wordsSelectedDocument = query.toLowerCase().trim().split(RegExp(r"[\s']+"));
    nbWordResultsInDocuments = 0;
    documents.clear();

    if (_documents.isEmpty && wordsSelectedDocument.isNotEmpty) {
      final results = await searchWordInDocuments(wordsSelectedDocument);
      _documents.addAll(results);
    }

    if (searchScope == 0 || wordsSelectedDocument.length == 1) {
      documents = List<Map<String, dynamic>>.from(_documents);
    } 
    else {
      List<Map<String, dynamic>> filteredDocs = [];
      final int queryLen = wordsSelectedDocument.length;

      for (var doc in _documents) {
        final List<dynamic> allParas = doc['paragraphs'];
        List<Map<String, dynamic>> validParagraphs = [];
        int totalExpressionsInDoc = 0;

        for (var para in allParas) {
          final List<dynamic> wordsInPara = para['words'];

          // --- DANS LA BOUCLE DES PARAGRAPHES (searchScope == 1) ---

          if (searchScope == 1) {
            // 1. On prépare les mots présents dans CE paragraphe (en minuscule/normalisé)
            final Set<String> wordsInThisPara = para['words']
                .map((w) => (w['word'] as String).toLowerCase().trim()).cast<String>()
                .toSet();

            // 2. On vérifie si TOUS les mots de la recherche sont inclus dans ce set
            bool allWordsFoundInThisPara = wordsSelectedDocument.every((queryWord) {
              return wordsInThisPara.contains(queryWord.toLowerCase().trim());
            });

            if (allWordsFoundInThisPara) {
              // 3. Optionnel : On ne garde que les mots qui font partie de la recherche pour le surlignage
              final List<dynamic> highlightedWords = (para['words'] as List).where((w) {
                return wordsSelectedDocument.contains((w['word'] as String).toLowerCase().trim());
              }).toList();

              validParagraphs.add({
                ...para,
                'words': highlightedWords, // On remplace par les mots filtrés
              });

              // On compte le nombre de mots trouvés comme occurrences
              totalExpressionsInDoc += highlightedWords.length;
            }
          }
          else if (searchScope == 2) {
            // --- MODE PHRASE : SÉQUENCE EXACTE ---
            final List<Map<String, dynamic>> sortedWords = List.from(wordsInPara);
            sortedWords.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

            List<Map<String, dynamic>> exactMatchHighlights = [];
            int expressionCount = 0;

            for (int i = 0; i <= sortedWords.length - queryLen; i++) {
              bool match = true;
              List<Map<String, dynamic>> potentialHighlights = [];

              for (int j = 0; j < queryLen; j++) {
                final currentHit = sortedWords[i + j];
                bool sameWord = currentHit['word'] == wordsSelectedDocument[j];
                bool consecutive = j == 0 || (currentHit['index'] == sortedWords[i + j - 1]['index'] + 1);
                
                if (sameWord && consecutive) {
                  potentialHighlights.add(currentHit);
                } else {
                  match = false;
                  break;
                }
              }

              if (match) {
                expressionCount++;
                exactMatchHighlights.addAll(potentialHighlights);
                i += queryLen - 1; // On saute l'expression trouvée
              }
            }

            if (expressionCount > 0) {
              // On remplace le paragraphe par une version qui ne contient QUE les bons highlights
              validParagraphs.add({
                ...para,
                'words': exactMatchHighlights,
              });
              totalExpressionsInDoc += expressionCount;
            }
          }
        }

        if (validParagraphs.isNotEmpty) {
          filteredDocs.add({
            ...doc,
            'paragraphs': validParagraphs,
            'occurrences': totalExpressionsInDoc,
          });
        }
      }
      documents = filteredDocs;
    }

    for (var doc in documents) {
      nbWordResultsInDocuments += doc['occurrences'] as int;
    }
    documents.sort((a, b) => b['occurrences'].compareTo(a['occurrences']));
  }

  /* DOCUMENTS */
  Future<List<Map<String, dynamic>>> getDocuments(List<int> textUnitIds) async {
    if (textUnitIds.isEmpty) return [];
    final ids = textUnitIds.join(',');
    return await publication.documentsManager!.database.rawQuery('''
      SELECT DocumentId, Title, MepsDocumentId, TextPositions, TextLengths
      FROM Document
      JOIN TextUnit ON Document.DocumentId = TextUnit.Id
      JOIN SearchTextRangeDocument ON TextUnit.Id = SearchTextRangeDocument.TextUnitId
      WHERE TextUnit.Type = 'Document' AND TextUnit.Id IN ($ids)
    ''');
  }

  Future<List<Map<String, dynamic>>> getParagraphsMap(List<int> documentIds) async {
    if (documentIds.isEmpty) return [];
    return await publication.documentsManager!.database.rawQuery('''
      SELECT DocumentId, ParagraphIndex, BeginPosition, EndPosition
      FROM DocumentParagraph
      WHERE DocumentId IN (${documentIds.join(',')})
    ''');
  }

  Future<List<Map<String, dynamic>>> searchWordInDocuments(List<String> queryWords) async {
    if (queryWords.isEmpty) return [];

    final placeholders = List.filled(queryWords.length, '?').join(', ');
    //final sqlColumn = buildAccentInsensitiveQuery('');

    final sqlQuery = '''
      SELECT TextUnitIndices, PositionalList, PositionalListIndex, Word.Word as WordValue
      FROM SearchIndexDocument
      JOIN Word ON SearchIndexDocument.WordId = Word.WordId
      WHERE Word.Word IN ($placeholders)
    ''';

    final searchResults = await publication.documentsManager!.database.rawQuery(sqlQuery, queryWords);

    if (searchResults.isEmpty) return [];

    Set<int>? commonDocIds;
    for (var row in searchResults) {
      final ids = getTextUnitIds(row['TextUnitIndices'] as Uint8List).toSet();
      if (commonDocIds == null) {
        commonDocIds = ids;
      } else {
        commonDocIds = commonDocIds.intersection(ids);
        if (commonDocIds.isEmpty) return [];
      }
    }

    // Map : DocID -> List of { index, word }
    final Map<int, List<Map<String, dynamic>>> aggregatedData = {};
    final Map<int, int> aggregatedOccurrences = {};

    for (var row in searchResults) {
      final currentDocIds = getTextUnitIds(row['TextUnitIndices'] as Uint8List);
      final occs = getOccurrenceByDocument(row['PositionalListIndex'] as Uint8List);
      final pos = bytesVLQToIntList(row['PositionalList'] as Uint8List);
      final String wordValue = row['WordValue'] as String;

      int posOffset = 0;
      for (int i = 0; i < currentDocIds.length; i++) {
        final docId = currentDocIds[i];
        final count = occs[i];
        
        if (commonDocIds!.contains(docId)) {
          aggregatedOccurrences[docId] = (aggregatedOccurrences[docId] ?? 0) + count;
          final list = aggregatedData.putIfAbsent(docId, () => []);
          for (int j = 0; j < count; j++) {
            list.add({
              'index': pos[posOffset + j],
              'word': wordValue,
            });
          }
        }
        posOffset += count;
      }
    }

    final finalDocIds = commonDocIds!.toList();
    final docsList = await getDocuments(finalDocIds);
    final Map<int, Map<String, dynamic>> docsMap = {
      for (var d in docsList) d['DocumentId'] as int: d
    };

    final paragraphsList = await getParagraphsMap(finalDocIds);
    final Map<int, List<Map<String, dynamic>>> paragraphsByDoc = {};
    for (var p in paragraphsList) {
      (paragraphsByDoc[p['DocumentId'] as int] ??= []).add(p);
    }

    final List<Map<String, dynamic>> finalDocs = [];

    for (final docId in finalDocIds) {
      final doc = docsMap[docId];
      if (doc == null) continue;

      final allPositions = getWordsPositionsAndParagraphId(doc['TextPositions']);
      final allLengths = getWordsLengths(doc['TextLengths']);
      final Map<int, Map<String, dynamic>> docParagraphs = {};

      // On utilise aggregatedData[docId] qui contient maintenant le mot
      for (var hit in aggregatedData[docId]!) {
        int wordIdx = hit['index'];
        String wordValue = hit['word'];

        if (wordIdx >= allPositions.length) continue;

        final posInfo = allPositions[wordIdx];
        final paraId = posInfo['paragraphId'];
        if (paraId == null) continue;
        
        final docParas = paragraphsByDoc[docId];
        final paraInfo = docParas?.firstWhereOrNull((p) => p['ParagraphIndex'] == paraId);

        if (paraInfo != null) {
          docParagraphs.putIfAbsent(paraId, () => {
            'paragraphId': paraId,
            'begin': paraInfo['BeginPosition'],
            'end': paraInfo['EndPosition'],
            'words': [],
          });

          (docParagraphs[paraId]!['words'] as List).add({
            'index': wordIdx,
            'word': wordValue, // On le transmet au paragraphe
            'startHighlight': posInfo['position'],
            'endHighlight': (posInfo['position'] as int) + allLengths[wordIdx],
          });
        }
      }

      finalDocs.add({
        'documentId': docId,
        'mepsDocumentId': doc['MepsDocumentId'],
        'title': doc['Title'],
        'occurrences': aggregatedOccurrences[docId],
        'paragraphs': docParagraphs.values.toList(),
      });
    }

    return finalDocs;
  }

  /* VERSETS DE LA BIBLE */
  Future<void> searchBibleVerses(String query, bool isExactMatch, {bool newSearch = false}) async {
    if (newSearch) {
      _verses.clear();
    }

    wordsSelectedVerse = query.toLowerCase().trim().split(RegExp(r"[\s']+"));
    nbWordResultsInVerses = 0;
    verses.clear();

    if (versesRanking.isEmpty) {
      await findRankingBlob();
    }

    if (_verses.isEmpty && wordsSelectedVerse.isNotEmpty) {
      final results = await searchWordInBibleVerses(wordsSelectedVerse);
      _verses.addAll(results);
    }

    if (!isExactMatch || wordsSelectedVerse.length == 1) {
      verses = List<Map<String, dynamic>>.from(_verses);
    } 
    else {
      final List<Map<String, dynamic>> matchingVerses = [];
      final int queryLen = wordsSelectedVerse.length;

      for (final verse in _verses) {
        final List<Map<String, dynamic>> allWords = List<Map<String, dynamic>>.from(verse['words']);
        // Important : trier par index pour détecter la suite
        allWords.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

        List<Map<String, dynamic>> exactMatchHighlights = [];
        int expressionCount = 0;

        // On parcourt les mots pour trouver des séquences qui matchent la requête
        for (int i = 0; i <= allWords.length - queryLen; i++) {
          bool sequenceMatch = true;
          List<Map<String, dynamic>> potentialHighlights = [];

          for (int j = 0; j < queryLen; j++) {
            final currentHit = allWords[i + j];
            
            bool sameWord = currentHit['word'] == wordsSelectedVerse[j];
            bool consecutive = (j == 0) || (currentHit['index'] == allWords[i + j - 1]['index'] + 1);

            if (sameWord && consecutive) {
              potentialHighlights.add(currentHit);
            } else {
              sequenceMatch = false;
              break;
            }
          }

          if (sequenceMatch) {
            expressionCount++;
            exactMatchHighlights.addAll(potentialHighlights);
            // On avance l'index pour ne pas compter deux fois les mots de cette expression
            i += queryLen - 1; 
          }
        }

        if (expressionCount > 0) {
          matchingVerses.add({
            ...verse,
            'occurrences': expressionCount, // On remplace par le nombre d'expressions
            'words': exactMatchHighlights,  // On ne garde QUE les highlights de l'expression
          });
        }
      }
      verses = matchingVerses;
    }

    // Calcul du total global basé sur le nombre d'expressions trouvées
    for (var verse in verses) {
      nbWordResultsInVerses += verse['occurrences'] as int;
    }
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

  Future<List<Map<String, dynamic>>> searchWordInBibleVerses(List<String> queryWords) async {
  if (queryWords.isEmpty) return [];

  final placeholders = List.filled(queryWords.length, '?').join(', ');
  //final sqlColumn = buildAccentInsensitiveQuery('');

  // 1. On récupère les positions ET le texte du mot (WordValue)
  final searchResults = await publication.documentsManager!.database.rawQuery('''
    SELECT TextUnitIndices, PositionalList, PositionalListIndex, Word.Word as WordValue
    FROM SearchIndexBibleVerse
    JOIN Word ON SearchIndexBibleVerse.WordId = Word.WordId
    WHERE Word.Word IN ($placeholders)
  ''', queryWords);

  // Si on n'a pas trouvé tous les mots de la requête, on arrête
  if (searchResults.isEmpty) return [];

  // 2. Intersection pour ne garder que les versets qui contiennent TOUS les mots
  Set<int>? commonBibleVerseIds;
  for (var row in searchResults) {
    final ids = getTextUnitIds(row['TextUnitIndices'] as Uint8List).toSet();
    if (commonBibleVerseIds == null) {
      commonBibleVerseIds = ids;
    } else {
      commonBibleVerseIds = commonBibleVerseIds.intersection(ids);
      if (commonBibleVerseIds.isEmpty) return [];
    }
  }

  // 3. Agrégation des données par ID de verset
  // Map : BibleVerseId -> List of { index, word }
  final Map<int, List<Map<String, dynamic>>> aggregatedData = {};
  final Map<int, int> aggregatedOccurrences = {};

  for (var row in searchResults) {
    final currentDocIds = getTextUnitIds(row['TextUnitIndices'] as Uint8List);
    final occs = getOccurrenceByDocument(row['PositionalListIndex'] as Uint8List);
    final pos = bytesVLQToIntList(row['PositionalList'] as Uint8List);
    final String wordValue = row['WordValue'] as String;

    int posOffset = 0;
    for (int i = 0; i < currentDocIds.length; i++) {
      final docId = currentDocIds[i];
      final count = occs[i];
      
      if (commonBibleVerseIds!.contains(docId)) {
        aggregatedOccurrences[docId] = (aggregatedOccurrences[docId] ?? 0) + count;
        
        final list = aggregatedData.putIfAbsent(docId, () => []);
        for (int j = 0; j < count; j++) {
          list.add({
            'index': pos[posOffset + j],
            'word': wordValue,
          });
        }
      }
      posOffset += count;
    }
  }

  final finalBibleVerseIds = commonBibleVerseIds!.toList();
  
  // 4. Récupération des contenus des versets
  final bibleVerseList = await getVerses(finalBibleVerseIds);
  final Map<int, Map<String, dynamic>> bibleVerseMap = {
    for (var d in bibleVerseList) d['BibleVerseId'] as int: d
  };

  final List<Map<String, dynamic>> finalBibleVerses = [];

  for (final bibleVerseId in finalBibleVerseIds) {
    final bibleVerse = bibleVerseMap[bibleVerseId];
    if (bibleVerse == null) continue;

    final allPositions = getWordsPositionsAndParagraphId(bibleVerse['TextPositions']);
    final allLengths = getWordsLengths(bibleVerse['TextLengths']);

    // Décodage du contenu HTML et parsing des références (Livre, Chapitre, Verset)
    String verseHtml = decodeBlobContent(bibleVerse['Content'], publication.hash!);
    List<PositionAdjustment> adjustments = bibleVerse['AdjustmentInfo'] == null 
        ? [] 
        : getAdjustmentsInfo(bibleVerse['AdjustmentInfo']);

    RegExp regExp = RegExp(r'id="v(\d+)-(\d+)-(\d+)"');
    Match? match = regExp.firstMatch(verseHtml);

    int bookNumber = 0, chapterNumber = 0, verseNumber = 0;

    if (match != null) {
      bookNumber = int.parse(match.group(1)!);
      chapterNumber = int.parse(match.group(2)!);
      verseNumber = int.parse(match.group(3)!);
    } 
    else {
      continue;
    }

    String verseText = parse(verseHtml).body?.text ?? '';
    
    final verseEntry = {
      'verseId': bibleVerseId,
      'bookNumber': bookNumber,
      'chapterNumber': chapterNumber,
      'verseNumber': verseNumber,
      'verse': verseText,
      'occurrences': aggregatedOccurrences[bibleVerseId],
      'words': []
    };

    // 5. Mapping des positions de surbrillance
    final List<Map<String, dynamic>> hits = aggregatedData[bibleVerseId]!;
    for (var hit in hits) {
      int wordIdx = hit['index'];

      if (wordIdx >= allPositions.length) continue;

      final posInfo = allPositions[wordIdx];
      
      // Ajustement de la position (gestion des caractères spéciaux/HTML)
      int start = adjustPosition(posInfo['position']!, adjustments);
      int end = start + allLengths[wordIdx];

      (verseEntry['words'] as List).add({
        'index': wordIdx,
        'word': hit['word'], // Transmis pour le filtrage searchBibleVerses
        'startHighlight': start,
        'endHighlight': end,
      });
    }

    finalBibleVerses.add(verseEntry);
  }

  return finalBibleVerses;
}

  void sortVerses(int type) {
    if(type == 0) {
      verses.sort((a, b) => a['verseId'].compareTo(b['verseId']));
    }
    else if(type == 1) {
      if (versesRanking.isNotEmpty && versesRanking.isNotEmpty) {
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