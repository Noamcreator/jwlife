import 'package:flutter/cupertino.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../data/controller/tags_controller.dart';
import '../../data/models/userdata/tag.dart';

const double _similarityThreshold = 0.6;

List<Tag> getFilteredTags(String query, List<int> tagsId) {
  BuildContext context = GlobalKeyService.jwLifePageKey.currentContext!;

  final tags = context.read<TagsController>().tags;

  // 1. Préparation de la requête : minuscule, sans accents
  final normalizedQuery = normalize(query);

  // Si la requête est vide, ne pas filtrer sur la similarité, juste exclure les tags existants
  if (query.isEmpty) {
    return tags.where((tag) => !tagsId.contains(tag.id)).toList();
  }

  return tags.where((tag) {
    // 2. Exclure les tags déjà associés à la note
    if (tagsId.contains(tag.id)) {
      return false;
    }

    // 3. Préparation du nom du tag : minuscule, sans accents
    final normalizedTagName = normalize(tag.name);

    if (normalizedTagName.contains(normalizedQuery)) {
      return true;
    }

    final similarity = normalizedQuery.similarityTo(normalizedTagName);

    // Retourne true si la similarité est supérieure au seuil défini
    return similarity >= _similarityThreshold;

  }).toList();
}