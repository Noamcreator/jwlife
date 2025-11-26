import 'dart:developer'; // Ajout ou maintien de l'import pour la fonction log()

import 'package:flutter/foundation.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../../../../core/utils/utils.dart';
import '../../../../../data/models/publication.dart';
import '../../../../home/pages/search/suggestion.dart';

class WordsSuggestionsModel {
  Publication publication;

  // Cache pour stocker tous les mots de la base de données
  List<String> _cachedWords = [];

  // ValueNotifier pour notifier les changements à l'UI. Il contient des SuggestionItem.
  final ValueNotifier<List<SuggestionItem>> suggestionsNotifier = ValueNotifier([]);

  int _latestRequestId = 0;

  WordsSuggestionsModel(this.publication) {
    _loadAllWords();
  }

  // -------------------------------------------------------------------
  // MÉTHODE : Charger tous les mots dans le cache une seule fois
  // -------------------------------------------------------------------
  Future<void> _loadAllWords() async {
    if (publication.documentsManager == null || publication.documentsManager?.database == null) {
      debugPrint('Erreur: Publication Documents Manager ou Database est null. Impossible de charger les mots.');
      return;
    }

    try {
      final List<Map<String, dynamic>> allWordsResult = await publication.documentsManager!.database.rawQuery(
        '''
        SELECT Word
        FROM Word
        ''',
      );

      _cachedWords = allWordsResult.map<String>((row) => row['Word'] as String).toList();
      // Utilise log() qui nécessite 'dart:developer'
      log('Nombre de mots chargés dans le cache : ${_cachedWords.length}');

    } catch (e) {
      debugPrint('Erreur lors du chargement des mots du cache: $e');
    }
  }

  // -------------------------------------------------------------------
  // MÉTHODE OPTIMISÉE : Utilise le cache et crée des SuggestionItem
  // -------------------------------------------------------------------
  Future<void> fetchSuggestions(String text) async {
    final int requestId = ++_latestRequestId;

    if (text.isEmpty) {
      if (requestId == _latestRequestId) {
        suggestionsNotifier.value = [];
      }
      return;
    }

    // 1. Chargement initial du cache si nécessaire
    if (_cachedWords.isEmpty) {
      await _loadAllWords();

      // Si une nouvelle requête a été lancée pendant l'attente du chargement, on abandonne.
      if (requestId != _latestRequestId) return;

      // Si le chargement a échoué (cache toujours vide), on arrête.
      if (_cachedWords.isEmpty) return;
    }

    String normalizedText = normalize(text);

    // 2. Filtrer et trier les mots du cache
    final List<String> filteredAndSortedWords = _cachedWords.where((word) {
      // Filtrer seulement les mots qui contiennent la sous-chaîne normalisée
      return normalize(word).contains(normalizedText);
    }).toList();

    // Vérification anti-concurrence avant le tri, car le tri peut être coûteux
    if (requestId != _latestRequestId) return;

    filteredAndSortedWords.sort((a, b) {
      // Tri descendant basé sur la similarité
      double simA = StringSimilarity.compareTwoStrings(normalize(a), normalizedText);
      double simB = StringSimilarity.compareTwoStrings(normalize(b), normalizedText);
      return simB.compareTo(simA);
    });

    // 3. Conversion en instances de SuggestionItem
    List<SuggestionItem> newSuggestions = [];

    // N'afficher qu'un nombre limité de suggestions (ex: 15)
    for (String word in filteredAndSortedWords.take(15)) {
      newSuggestions.add(SuggestionItem(
        type: 'word',
        query: word,
        title: word,
        image: 'magnifying_glass',
      ));
    }

    // Dernière vérification avant de mettre à jour l'UI
    if (requestId != _latestRequestId) return;

    // 4. Met à jour le ValueNotifier
    suggestionsNotifier.value = newSuggestions;
  }
}