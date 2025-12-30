import 'package:collection/collection.dart';
import 'package:jwlife/data/models/meps_language.dart';

import '../../app/services/settings_service.dart';
import '../models/publication.dart';

class PublicationRepository {
  static final PublicationRepository _instance = PublicationRepository._internal();

  factory PublicationRepository() => _instance;

  PublicationRepository._internal();

  final Map<String, Publication> _publications = {};

  /// Crée une clé unique à partir des attributs significatifs
  String _generateKey(Publication pub) {
    return '${pub.keySymbol}_${pub.issueTagNumber}_${pub.mepsLanguage.id}';
  }

  void addPublication(Publication publication) {
    _publications[_generateKey(publication)] = publication;
  }

  void removePublication(Publication publication) {
      _publications.remove(_generateKey(publication));
    }

  /// Retourne toutes les publications centralisées
  List<Publication> getAllPublications() {
    return _publications.values.toList();
  }

  List<Publication> getAllDownloadedPublications() {
    return _publications.values.where((p) => p.isDownloadedNotifier.value).toList();
  }

  Publication? getByCompositeKeyForDownloadWithMepsLanguageId(String keySymbol, int issueTagNumber, int mepsLanguageId) {
    return getAllDownloadedPublications().firstWhereOrNull((p) => p.keySymbol == keySymbol && p.issueTagNumber == issueTagNumber && p.mepsLanguage.id == mepsLanguageId);
  }

  /// Retourne toutes les bibles
  List<Publication> getAllBibles() {
    return _publications.values.where((p) => p.category.id == 1 && p.isDownloadedNotifier.value).toList();
  }

  List<Publication> getOrderBibles() {
    List<String> biblesSet = JwLifeSettings.instance.webViewData.biblesSet;

    // On filtre d'abord pour ne garder que celles présentes dans biblesSet
    final filteredBibles = getAllBibles().where((bible) {
      final key = '${bible.keySymbol}_${bible.mepsLanguage.symbol}';
      return biblesSet.contains(key);
    }).toList();

    // Puis on trie selon l’ordre défini dans biblesSet
    filteredBibles.sort((a, b) {
      final keyA = '${a.keySymbol}_${a.mepsLanguage.symbol}';
      final keyB = '${b.keySymbol}_${b.mepsLanguage.symbol}';

      final indexA = biblesSet.indexOf(keyA);
      final indexB = biblesSet.indexOf(keyB);

      return indexA.compareTo(indexB);
    });

    return filteredBibles;
  }

  Publication? getLookUpBible({String? bibleKey}) {
    bibleKey ??= JwLifeSettings.instance.lookupBible.value;

    List<String> parts = bibleKey.split('_');
    if(parts.length < 2) return null;
    String keySymbol = parts[0];
    String mepsLanguageSymbol = parts[1];

    return getAllPublications().firstWhereOrNull((p) => p.keySymbol == keySymbol && p.mepsLanguage.symbol == mepsLanguageSymbol) ?? getAllBibles().first;
  }

  /// Retourne une instance unique d'une publication si elle existe, sinon l'original
  Publication getPublication(Publication pub) {
    final key = _generateKey(pub);
    return _publications[key] ?? pub;
  }

  Publication? getPublicationWithMepsLanguageId(String keySymbol, int issueTagNumber, int mepsLanguageId) {
    return _publications.values.firstWhereOrNull((p) => (p.symbol == keySymbol || p.keySymbol == keySymbol) && p.issueTagNumber == issueTagNumber && p.mepsLanguage.id == mepsLanguageId);
  }

  Publication? getPublicationWithSymbol(String keySymbol, int issueTagNumber, String mepsLanguageSymbol) {
    return _publications.values.firstWhereOrNull((p) => (p.symbol == keySymbol || p.keySymbol == keySymbol) && p.issueTagNumber == issueTagNumber && p.mepsLanguage.symbol == mepsLanguageSymbol);
  }

  /// (Optionnel) Vérifie si une publication est déjà enregistrée
  bool contains(Publication pub) {
    return _publications.containsKey(_generateKey(pub));
  }

  List<Publication> getPublicationsFromLanguage(MepsLanguage currentLanguage) {
    return _publications.values.where((p) => p.mepsLanguage.id == currentLanguage.id && p.isDownloadedNotifier.value).toList();
  }
}
