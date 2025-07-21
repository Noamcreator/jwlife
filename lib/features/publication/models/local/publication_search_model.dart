import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/publication.dart';

import '../../../../core/utils/utils.dart';
import '../../views/document/local/documents_manager.dart';

class PublicationSearchModel {
  final Publication publication;
  final DocumentsManager documentsManager;
  final List<Map<String, dynamic>> _documents = [];
  final List<Map<String, dynamic>> _verses = [];
  int nbWordResultsInDocuments = 0;
  int nbWordResultsInVerses = 0;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> verses = [];
  List<int> versesRanking = [];

  List<String> wordsSelectedDocument = [];
  List<String> wordsSelectedVerse = [];

  PublicationSearchModel(this.publication, this.documentsManager);

  /* DOCUMENTS */
  Future<List<Map<String, dynamic>>> getDocuments(List<int> textUnitIds) async {
    final searchResults = await documentsManager.database.rawQuery('''
    SELECT DocumentId, Title, MepsDocumentId, Content, TextPositions, TextLengths, ScopeParagraphData
    FROM Document
    LEFT JOIN TextUnit ON Document.DocumentId = TextUnit.Id
    LEFT JOIN SearchTextRangeDocument ON TextUnit.Id = SearchTextRangeDocument.TextUnitId
    WHERE TextUnit.Type = 'Document' AND TextUnit.Id IN (${textUnitIds.join(',')})
  ''');

    return searchResults.isNotEmpty ? searchResults : [];
  }

  Future<List<Map<String, dynamic>>> getParagraphs(List<int> documentIds) async {
    final searchResults = await documentsManager.database.rawQuery('''
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

  Future<void> searchDocuments(String query, int mode) async {
    wordsSelectedDocument = query.trim().split(RegExp(r'\s+'));

    nbWordResultsInDocuments = 0;
    documents.clear();

    if(_documents.isEmpty) {
      // Liste des ensembles de DocumentIds pour chaque mot
      List<Set<int>> documentIdSets = [];

      // Stockage temporaire de tous les documents trouvés par mot
      Map<int, Map<String, dynamic>> tempDocuments = {};

      await Future.wait(wordsSelectedDocument.map((queryWord) async {
        final results = await searchWordInDocuments(queryWord);

        if (results.isNotEmpty) {
          final docIds = results.map((doc) => doc['documentId'] as int).toSet();
          documentIdSets.add(docIds);

          for (var rawDoc in results) {
            final doc = Map<String, dynamic>.from(rawDoc);
            final int id = doc['documentId'] as int;

            // Convertir les paragraphes proprement
            final List<Map<String, dynamic>> newParagraphs = (doc['paragraphs'] as List)
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();

            if (tempDocuments.containsKey(id)) {
              // Cumuler les occurrences
              tempDocuments[id]!['occurrences'] += doc['occurrences'] as int;

              // Paragraphes déjà présents
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

                  // Mise à jour triée
                  existingPara['words'] = mergedWords..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
                  existingParagraphs[existingIndex] = existingPara;
                } else {
                  existingParagraphs.add(newPara);
                }
              }
            } else {
              // Ajout du nouveau document
              tempDocuments[id] = {
                ...doc,
                'paragraphs': newParagraphs,
              };
            }
          }
        }
      }));

      // Intersection des documents qui contiennent tous les mots
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

        // Liste des paragraphes qui contiennent au moins une séquence valide
        final matchingParagraphs = <dynamic>[];

        for (final para in paragraphs) {
          final words = para['words'] as List<dynamic>;
          if (words.length < expectedWordCount) continue;

          // Vérifie s'il existe au moins une séquence de mots consécutifs
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
              break; // une seule occurrence suffit pour garder ce paragraphe
            }
          }
        }

        if (matchingParagraphs.isEmpty) return null;

        // Ajoute le champ "occurrences" = nombre de paragraphes avec match
        return {
          ...doc,
          'paragraphs': matchingParagraphs,
          'occurrences': matchingParagraphs.length,
        };
      }).whereType<Map<String, dynamic>>().toList();
    }

    // Calculer le nombre total de mots trouvés en fonction du mode
    for (var doc in documents) {
      nbWordResultsInDocuments += doc['occurrences'] as int;
    }

    // Trier par occurrences décroissantes
    documents.sort((a, b) => b['occurrences'].compareTo(a['occurrences']));
  }

  Future<List<Map<String, dynamic>>> searchWordInDocuments(String query) async {
    final Map<int, Map<String, dynamic>> tempDocuments = {};

    final searchResults = await documentsManager.database.rawQuery('''
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

        // Initialisation du document dans tempDocuments si pas déjà présent
        tempDocuments.putIfAbsent(documentIds[i], () => {
          'documentId': documentIds[i],
          'mepsDocumentId': document['MepsDocumentId'],
          'title': document['Title'],
          'occurrences': 0,
          'paragraphs': <int, Map<String, dynamic>>{}
        });

        final docEntry = tempDocuments[documentIds[i]]!;

        // Ajouter le nombre d'occurrences
        docEntry['occurrences'] += wordOccurrencesInDocuments[i];

        for(int wordPositionalsListInDocument in wordPositionalsListInDocuments[i]) {
          final wordPosition = positions.elementAtOrNull(wordPositionalsListInDocument);
          final wordLength = lengths.elementAtOrNull(wordPositionalsListInDocument);

          if (wordPosition != null && wordLength != null) {
            final paragraphPosition = paragraphs.where((element) => element['DocumentId'] == documentIds[i] && element['ParagraphIndex'] == wordPosition['paragraphId']).firstOrNull;

            if (paragraphPosition != null) {
              String paragraphText = '';
              int? paragraphId = wordPosition['paragraphId'];

              // Si le paragraphe n'existe pas, on l'ajoute
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

              // Ajouter la position et la longueur comme un seul objet
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

    // Transformer la map de paragraphes en liste pour chaque document
    for (var doc in tempDocuments.values) {
      doc['paragraphs'] = (doc['paragraphs'] as Map<int, Map<String, dynamic>>).values.toList();
    }

    return tempDocuments.values.toList();
  }

  Future<List<Map<String, dynamic>>> getVerses(List<int> bibleVerseIds) async {
    final searchResults = await documentsManager.database.rawQuery('''
      SELECT BibleVerseId, Content, AdjustmentInfo, TextPositions, TextLengths
      FROM BibleVerse
      LEFT JOIN SearchTextRangeBibleVerse ON BibleVerse.BibleVerseId = SearchTextRangeBibleVerse.TextUnitId
      WHERE BibleVerseId IN (${bibleVerseIds.join(',')});
    ''');

    return searchResults.isNotEmpty ? searchResults : [];
  }

  Future<void> searchBibleVerses(String query) async {
    wordsSelectedVerse = query.trim().split(RegExp(r'\s+'));

    nbWordResultsInVerses = 0;
    verses.clear();

    if (_verses.isEmpty) {
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

          // Initialisation si le verset n'existe pas encore
          tempVerses.putIfAbsent(verseId, () => {
            'verseId': verseId,
            'bookNumber': bookNumber,
            'chapterNumber': chapterNumber,
            'verseNumber': verseNumber,
            'verse': verseText,
            'occurrences': occurrences,
            'words': <Map<String, int?>>[]
          });

          // Ajout des mots au champ 'words'
          final existingWords = tempVerses[verseId]!['words'] as List<Map<String, int?>>;
          existingWords.addAll(words);
        }

        if (currentWordVerseIds.isNotEmpty) {
          verseIdSets.add(currentWordVerseIds);
        }
      }));

      if (verseIdSets.isNotEmpty) {
        final commonVerseIds = verseIdSets.reduce((a, b) => a.intersection(b));
        _verses.addAll(tempVerses.entries
            .where((entry) => commonVerseIds.contains(entry.key))
            .map((e) => e.value));
      }
    }

    verses = List<Map<String, dynamic>>.from(_verses);

    // Calculer le nombre total de mots trouvés en fonction du mode
    for (var verse in verses) {
      nbWordResultsInVerses += verse['occurrences'] as int;
    }
  }

  Future<List<Map<String, dynamic>>> searchWordInBibleVerses(String query) async {
    final Map<int, Map<String, dynamic>> tempVerses = {};

    final searchResults = await documentsManager.database.rawQuery('''
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
      findRankingBlob();

      for (int i = 0; i < bibleVerseIds.length; i++) {
        final verse = bibleVerses[i];
        final positions = getWordsPositionsAndParagraphId(verse['TextPositions']);
        final lengths = getWordsLengths(verse['TextLengths']);

        String verseHtml = decodeBlobContent(verse['Content'], publication.hash!);

        // Utilisation d'une expression régulière pour extraire les numéros
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

        // Initialisation du document dans tempDocuments si pas déjà présent
        tempVerses.putIfAbsent(bibleVerses[i]['BibleVerseId'], () => {
          'verseId': bibleVerses[i]['BibleVerseId'],
          'bookNumber': bookNumber,
          'chapterNumber': chapterNumber,
          'verseNumber': verseNumber,
          'verse': verseText,
          'occurrences': 0,
          'words': <Map<String, int?>>[]
        });

        final verseEntry = tempVerses[bibleVerses[i]['BibleVerseId']]!;

        // Ajouter le nombre d'occurrences
        verseEntry['occurrences'] += wordOccurrencesInVerses[i];

        for(int wordPositionalsListInDocument in wordPositionalsListInVerses[i]) {
          final wordPosition = positions.elementAtOrNull(wordPositionalsListInDocument);
          final wordLength = lengths.elementAtOrNull(wordPositionalsListInDocument);


          if (wordPosition != null && wordLength != null) {
            // Ajouter la position et la longueur comme un seul objet
            verseEntry['words'].add({
              'index': wordPositionalsListInDocument,
              'startHighlight': wordPosition['position'],
              'endHighlight': (wordPosition['position'] ?? 0) + wordLength,
            });
          }
        }
      }
    }

    return tempVerses.values.toList();
  }

  // fonction pour trier les versets
  void sortVerses(int type) {
    if(type == 0) { // tri par ordre de verse id
      verses.sort((a, b) => a['verseId'].compareTo(b['verseId']));
    }
    if(type == 1) { // tri par ordre de score du classement
      verses.sort((verse1, verse2) {
        int rank1 = versesRanking[verse1['verseId']];
        int rank2 = versesRanking[verse2['verseId']];
        return rank1.compareTo(rank2);
      });
    }
    else if(type == 2) { // tri par ordre de nombre d'occurrences du mot par verset
      verses.sort((a, b) => b['occurrences'].compareTo(a['occurrences']));
    }
  }

  /// Fonction pour obtenir le classement des versets depuis la base de données
  Future<void> findRankingBlob() async {
    // Exécution de la première requête pour obtenir RankingData
    List<Map<String, dynamic>> rankingResult = await documentsManager.database.rawQuery('''
      SELECT RankingData FROM BibleVerseRanking WHERE Keyword = '<default>';
    ''');

    // Exécution de la seconde requête pour obtenir la taille de la table BibleVerse
    List<Map<String, dynamic>> countResult = await documentsManager.database.rawQuery('''
      SELECT COUNT(*) FROM BibleVerse;
    ''');

    // Récupérer les données de RankingData (si présentes)
    Uint8List versesRanking = rankingResult.isNotEmpty ? rankingResult.first['RankingData'] as Uint8List : Uint8List(0);

    // Récupérer la taille de la table BibleVerse
    int nbMaxVerses = countResult.isNotEmpty ? countResult.first['COUNT(*)'] as int : 0;

    // Appel de la fonction avec les résultats récupérés
    getVersesRanking(versesRanking, nbMaxVerses);
  }

  /// Fonction pour obtenir le classement des versets depuis le BLOB
  void getVersesRanking(Uint8List versesRankingBlob, int nbMaxVerses) {
    // Vérifier si la taille du BLOB est paire
    if (versesRankingBlob.length % 2 != 0) {
      printTime("Erreur : BLOB a une taille impaire");
      return;
    }

    // Vérifier si la taille du BLOB est cohérente avec le nombre de versets
    if (versesRankingBlob.length != nbMaxVerses * 2) {
      printTime("Erreur : La taille du BLOB ne correspond pas au nombre de versets attendu");
      return;
    }

    versesRanking = List.filled(nbMaxVerses, -1);
    int index = 0;
    int nbRanking = 0;

    while (index < versesRankingBlob.length && nbRanking < nbMaxVerses) {
      int byte0 = versesRankingBlob[index++] & 0xFF;
      int byte1 = versesRankingBlob[index++] & 0xFF;
      int verseId = byte0 + (byte1 << 8);

      if (verseId >= nbMaxVerses) {
        printTime("VerseId trop grand");
        break;
      }

      versesRanking[verseId] = nbRanking++;
    }

    if (nbRanking > nbMaxVerses) {
      printTime("Trop de versets dans le BLOB");
    }
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
}
