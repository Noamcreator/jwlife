import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:html/parser.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';

import '../../../../../app/jwlife_app.dart';

class PublicationSearchModel {
  final Publication publication;
  final DocumentsManager documentsManager;
  int nbWordResultsInDocuments = 0;
  int nbWordResultsInVerses = 0;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> verses = [];
  List<int> versesRanking = [];

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

  Future<void> searchDocuments(String query) async {
    final searchResults = await documentsManager.database.rawQuery('''
      SELECT TextUnitCount, WordOccurrenceCount, TextUnitIndices, PositionalList, PositionalListIndex
      FROM SearchIndexDocument
      LEFT JOIN Word ON SearchIndexDocument.WordId = Word.WordId
      WHERE Word.Word LIKE ?
    ''', [query]);

    if (searchResults.isNotEmpty) {
      nbWordResultsInDocuments = searchResults.first['WordOccurrenceCount'] as int;

      final documentIds = getTextUnitIds(searchResults.first['TextUnitIndices'] as Uint8List);
      final occurrencesByDocument = getOccurrenceByDocument(searchResults.first['PositionalListIndex'] as Uint8List);
      final positionalList = getPositionsInDocument(searchResults.first['PositionalList'] as Uint8List, occurrencesByDocument);

      final docs = await getDocuments(documentIds);
      final paragraphs = await getParagraphs(documentIds);

      documents.clear();

      for (int i = 0; i < documentIds.length; i++) {
        final document = docs[i];
        final positions = getWordsPositionsAndParagraphId(document['TextPositions']);
        final lengths = getWordsLengths(document['TextLengths']);

        final wordPosition = positions.elementAtOrNull(positionalList[i].first);
        final wordLength = lengths.elementAtOrNull(positionalList[i].first);

        String paragraphText = '';
        if (wordPosition != null && wordLength != null) {
          final paragraphPosition = paragraphs.firstWhereOrNull((element) => element['DocumentId'] == documentIds[i] && element['ParagraphIndex'] == wordPosition['paragraphId']);
          if (paragraphPosition != null) {
            final beginPosition = paragraphPosition['BeginPosition'];
            final endPosition = paragraphPosition['EndPosition'];

            if (beginPosition != null && endPosition != null) {
              // Décoder le contenu HTML
              final documentBlob = decodeBlobParagraph(document['Content'], publication.hash);
              final paragraphBlob = documentBlob.sublist(beginPosition, endPosition);

              // Extraire le fragment du HTML normalisé
              final paragraphHtml = utf8.decode(paragraphBlob);

              // Si vous avez besoin d'un texte brut après, utilisez parse
              paragraphText = parse(paragraphHtml).body?.text ?? '';
            }
          }

          documents.add({
            'documentId': documentIds[i],
            'mepsDocumentId': document['MepsDocumentId'],
            'title': document['Title'],
            'occurences': occurrencesByDocument[i],
            'wordPosition': wordPosition['position'],
            'wordLength': wordLength,
            'paragraphId': wordPosition['paragraphId'],
            'paragraph': paragraphText
          });
        }
      }

      documents.sort((a, b) => b['occurences'].compareTo(a['occurences']));
    }
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
    final searchResults = await documentsManager.database.rawQuery('''
      SELECT TextUnitCount, WordOccurrenceCount, TextUnitIndices, PositionalList, PositionalListIndex
      FROM SearchIndexBibleVerse
      LEFT JOIN Word ON SearchIndexBibleVerse.WordId = Word.WordId
      WHERE Word.Word LIKE ?
    ''', [query]);

    if (searchResults.isNotEmpty) {
      nbWordResultsInVerses = searchResults.first['WordOccurrenceCount'] as int;

      final bibleVerseIds = getTextUnitIds(searchResults.first['TextUnitIndices'] as Uint8List);
      final occurrencesByDocument = getOccurrenceByDocument(searchResults.first['PositionalListIndex'] as Uint8List);
      final positionalList = getPositionsInDocument(searchResults.first['PositionalList'] as Uint8List, occurrencesByDocument);

      final bibleVerses = await getVerses(bibleVerseIds);
      findRankingBlob();

      verses.clear();

      for (int i = 0; i < bibleVerseIds.length; i++) {
        final verse = bibleVerses[i];
        final positions = getWordsPositionsAndParagraphId(verse['TextPositions']);
        final lengths = getWordsLengths(verse['TextLengths']);

        final wordPosition = positions.elementAtOrNull(positionalList[i].first);
        final wordLength = lengths.elementAtOrNull(positionalList[i].first);

        String verseHtml = decodeBlobContent(verse['Content'], publication.hash);

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
          print('Aucune correspondance trouvée');
        }

        String verseText = parse(verseHtml).body?.text ?? '';

        verses.add({
          'verseId': bibleVerses[i]['BibleVerseId'],
          'bookNumber': bookNumber,
          'chapterNumber': chapterNumber,
          'verseNumber': verseNumber,
          'occurences': occurrencesByDocument[i],
          'wordPosition': wordPosition != null ? wordPosition['position'] : 0,
          'wordLength': wordLength ?? 0,
          'verse': verseText
        });
      }
    }
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
    else if(type == 2) { // tri par ordre de nombre d'occurences du mot par verset
      verses.sort((a, b) => b['occurences'].compareTo(a['occurences']));
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
      print("Erreur : BLOB a une taille impaire");
      return;
    }

    // Vérifier si la taille du BLOB est cohérente avec le nombre de versets
    if (versesRankingBlob.length != nbMaxVerses * 2) {
      print("Erreur : La taille du BLOB ne correspond pas au nombre de versets attendu");
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
        print("VerseId trop grand");
        break;
      }

      versesRanking[verseId] = nbRanking++;
    }

    if (nbRanking > nbMaxVerses) {
      print("Trop de versets dans le BLOB");
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
