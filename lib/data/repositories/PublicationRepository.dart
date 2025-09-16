import 'package:collection/collection.dart';
import 'package:jwlife/data/models/meps_language.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/settings_service.dart';
import '../models/publication.dart';

class PublicationRepository {
  static final PublicationRepository _instance = PublicationRepository._internal();

  factory PublicationRepository() => _instance;

  PublicationRepository._internal();

  final Map<String, Publication> _publications = {};

  /// Crée une clé unique à partir des attributs significatifs
  String _generateKey(Publication pub) {
    return '${pub.symbol}_${pub.issueTagNumber}_${pub.mepsLanguage.id}';
  }

  void addPublication(Publication publication) {
    _publications[_generateKey(publication)] = publication;
  }

  /// Retourne toutes les publications centralisées
  List<Publication> getAllPublications() {
    return _publications.values.toList();
  }

  List<Publication> getAllDownloadedPublications() {
    return _publications.values.where((p) => p.isDownloadedNotifier.value).toList();
  }

  Publication? getByCompositeKeyForDownload(String symbol, int issueTagNumber, String mepsLanguage) {
    return getAllDownloadedPublications().firstWhereOrNull((p) => p.symbol == symbol && p.issueTagNumber == issueTagNumber && p.mepsLanguage.symbol == mepsLanguage,
    );
  }

  Publication? getByCompositeKeyForDownloadWithMepsLanguageId(String symbol, int issueTagNumber, int mepsLanguageId) {
    return getAllDownloadedPublications().firstWhereOrNull((p) => p.symbol == symbol && p.issueTagNumber == issueTagNumber && p.mepsLanguage.id == mepsLanguageId);
  }

  /// Retourne toutes les bibles
  List<Publication> getAllBibles() {
    int id = JwLifeSettings().currentLanguage.id;

    return _publications.values
        .where((p) => p.category.id == 1 && p.isDownloadedNotifier.value)
        .toList()
      ..sort((a, b) {
        // Priorité à la langue courante
        if (a.mepsLanguage.id == id && b.mepsLanguage.id != id) return -1;
        if (a.mepsLanguage.id != id && b.mepsLanguage.id == id) return 1;

        // Remplacer ici par un champ existant pour trier, exemple :
        return a.title.compareTo(b.title); // ou p.id, p.symbol, etc.
      });
  }

  /// Retourne une instance unique d'une publication si elle existe, sinon l'original
  Publication getPublication(Publication pub) {
    final key = _generateKey(pub);
    return _publications[key] ?? pub;
  }

  Publication? getPublicationWithMepsLanguageId(String symbol, int issueTagNumber, int mepsLanguageId) {
    final key = '${symbol}_${issueTagNumber}_$mepsLanguageId';
    return _publications[key];
  }

  Publication? getPublicationWithSymbol(String symbol, int issueTagNumber, String mepsLanguageSymbol) {
    return _publications.values.firstWhereOrNull((p) => p.symbol == symbol && p.issueTagNumber == issueTagNumber && p.mepsLanguage.symbol == mepsLanguageSymbol);
  }

  /// (Optionnel) Vérifie si une publication est déjà enregistrée
  bool contains(Publication pub) {
    return _publications.containsKey(_generateKey(pub));
  }

  List<Publication> getPublicationsFromLanguage(MepsLanguage currentLanguage) {
    return _publications.values.where((p) => p.mepsLanguage.id == currentLanguage.id && p.isDownloadedNotifier.value).toList();
  }
}
