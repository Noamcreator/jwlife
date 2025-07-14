import 'package:collection/collection.dart';
import 'package:jwlife/data/meps/language.dart';

import '../../app/jwlife_app.dart';
import 'Publication.dart';

class PublicationRepository {
  static final PublicationRepository _instance = PublicationRepository._internal();

  factory PublicationRepository() => _instance;

  PublicationRepository._internal();

  final Map<String, Publication> _publications = {};

  /// Crée une clé unique à partir des attributs significatifs
  String _generateKey(Publication pub) {
    return '${pub.symbol}_${pub.issueTagNumber}_${pub.mepsLanguage.id}';
  }

  void addPublication(Publication publications) {
    _publications[_generateKey(publications)] = publications;
  }

  Publication? getByCompositeKey(String symbol, int issueTagNumber, int mepsLanguageId) {
    return _publications.values.firstWhereOrNull(
          (p) =>
      p.symbol == symbol &&
          p.issueTagNumber == issueTagNumber &&
          p.mepsLanguage.id == mepsLanguageId,
    );
  }


  /// Retourne toutes les publications centralisées
  List<Publication> getAllPublications() {
    return _publications.values.toList();
  }

  List<Publication> getAllDownloadedPublications() {
    return _publications.values.where((p) => p.isDownloadedNotifier.value).toList();
  }

  /// Retourne toutes les bibles
  List<Publication> getAllBibles() {
    return _publications.values.where((p) => p.category.id == 1 && p.mepsLanguage.id == JwLifeApp.settings.currentLanguage.id && p.isDownloadedNotifier.value).toList();
  }

  /// Retourne une instance unique d'une publication si elle existe, sinon l'original
  Publication getPublication(Publication pub) {
    final key = _generateKey(pub);
    return _publications[key] ?? pub;
  }

  Publication? getPublicationWithSymbol(String symbol, int issueTagNumber, int mepsLanguageId) {
    final key = '${symbol}_${issueTagNumber}_${mepsLanguageId}';
    return _publications[key];
  }

  /// (Optionnel) Vérifie si une publication est déjà enregistrée
  bool contains(Publication pub) {
    return _publications.containsKey(_generateKey(pub));
  }

  List<Publication> getPublicationsFromLanguage(MepsLanguage currentLanguage) {
    return _publications.values.where((p) => p.mepsLanguage.id == currentLanguage.id && p.isDownloadedNotifier.value).toList();
  }
}
