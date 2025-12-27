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

  Future<void> fetchSuggestions(String text) async {
    final int requestId = ++_latestRequestId;

    // Si texte vide → pas de suggestion
    if (text.trim().isEmpty) {
      if (requestId == _latestRequestId) {
        suggestionsNotifier.value = [];
      }
      return;
    }

    // Charger le cache si nécessaire
    if (_cachedWords.isEmpty) {
      await _loadAllWords();
      if (requestId != _latestRequestId) return;
      if (_cachedWords.isEmpty) return;
    }

    // ------------------------------------------------------------
    // 🧠 1. EXTRAIRE LES MOTS PRÉCÉDENTS + LE DERNIER MOT À CHERCHER
    // ------------------------------------------------------------
    List<String> parts = text.split(" ");
    String lastWord = parts.last;
    String prefix = parts.length > 1
        ? "${parts.sublist(0, parts.length - 1).join(" ")} "
        : "";

    // Si dernier mot vide (l’utilisateur vient d'appuyer espace)
    if (lastWord.trim().isEmpty) {
      suggestionsNotifier.value = [];
      return;
    }

    String normalizedSearch = normalize(lastWord);

    // ------------------------------------------------------------
    // 🔍 2. CHERCHER UNIQUEMENT SUR LE DERNIER MOT
    // ------------------------------------------------------------
    final List<String> matches = _cachedWords.where((word) {
      return normalize(word).contains(normalizedSearch);
    }).toList();

    if (requestId != _latestRequestId) return;

    // Tri par similarité
    matches.sort((a, b) {
      double simA = StringSimilarity.compareTwoStrings(normalize(a), normalizedSearch);
      double simB = StringSimilarity.compareTwoStrings(normalize(b), normalizedSearch);
      return simB.compareTo(simA);
    });

    // ------------------------------------------------------------
    // 🔗 3. RECONSTRUIRE LES SUGGESTIONS AVEC LE PRÉFIXE
    // ------------------------------------------------------------
    List<SuggestionItem> newSuggestions = [];

    for (String word in matches.take(15)) {
      newSuggestions.add(
        SuggestionItem(
          type: 'word',
          query: prefix + word, // 👉 le mot complet
          title: prefix + word,
          image: 'magnifying_glass',
        ),
      );
    }

    if (requestId != _latestRequestId) return;

    suggestionsNotifier.value = newSuggestions;
  }
}