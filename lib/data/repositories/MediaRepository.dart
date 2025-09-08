import 'package:collection/collection.dart';
import 'package:jwlife/data/models/media.dart';

import '../../app/services/settings_service.dart';
import '../models/audio.dart';
import '../realm/catalog.dart';

class MediaRepository {
  static final MediaRepository _instance = MediaRepository._internal();

  factory MediaRepository() => _instance;

  MediaRepository._internal();

  final Map<String, Media> _medias = {};

  /// Crée une clé unique à partir des attributs significatifs
  String _generateKey(Media media) {
    String type = media is Audio ? "AUDIO" : "VIDEO";
    return '${media.keySymbol ?? ''}_${media.documentId ?? 0}_${media.issueTagNumber ?? 0}_${media.track ?? 0}_${media.mepsLanguage}_$type';
  }

  void addMedia(Media media) {
    _medias[_generateKey(media)] = media;
  }

  /// Retourne toutes les publications centralisées
  List<Media> getAllMedias() {
    return _medias.values.toList();
  }

  List<Media> getAllDownloadedMedias() {
    return _medias.values.where((p) => p.isDownloadedNotifier.value).toList();
  }

  Media? getByCompositeKey(MediaItem? mediaItem) {
    String keySymbol = mediaItem?.pubSymbol ?? '';
    int documentId = mediaItem?.documentId ?? 0;
    String mepsLanguage = mediaItem?.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;
    int issueTagNumber = mediaItem?.issueDate ?? 0;
    int? track = mediaItem?.track ?? 0;

    return _medias.values.firstWhereOrNull((m) => m.keySymbol == keySymbol && m.documentId == documentId && m.mepsLanguage == mepsLanguage && m.issueTagNumber == issueTagNumber && m.track == track);
  }

  Media? getByCompositeKeyForDownload(MediaItem mediaItem) {
    String keySymbol = mediaItem.pubSymbol ?? '';
    int documentId = mediaItem.documentId ?? 0;
    String mepsLanguage = mediaItem.languageSymbol ?? JwLifeSettings().currentLanguage.symbol;
    int issueTagNumber = mediaItem.issueDate ?? 0;
    int? track = mediaItem.track ?? 0;

    return getAllDownloadedMedias().firstWhereOrNull((m) => m.keySymbol == keySymbol && m.documentId == documentId && m.mepsLanguage == mepsLanguage && m.issueTagNumber == issueTagNumber && m.track == track);
  }

  /// Retourne une instance unique d'une publication si elle existe, sinon l'original
  Media getMedia(Media media) {
    final key = _generateKey(media);
    return _medias[key] ?? media;
  }

  /// (Optionnel) Vérifie si une publication est déjà enregistrée
  bool contains(Media media) {
    return _medias.containsKey(_generateKey(media));
  }

  List<Media> getMediasFromLanguage(String currentLanguage) {
    return _medias.values.where((p) => p.mepsLanguage == currentLanguage && p.isDownloadedNotifier.value).toList();
  }

  Media? getMediaWithMepsLanguageId(String keySymbol, int documentId, int issueTagNumber, int track, String mepsLanguage, bool isAudio) {
    final type = isAudio ? "AUDIO" : "VIDEO";
    final key = "${keySymbol}_${documentId}_${issueTagNumber}_${track}_${mepsLanguage}_$type";
    return _medias[key];
  }
}
