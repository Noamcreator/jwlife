import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:async/async.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/features/publication/pages/document/local/dated_text_manager.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/notification_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/jworg_uri.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../core/utils/utils_document.dart';
import '../../features/publication/models/menu/local/words_suggestions_model.dart';
import '../../features/publication/pages/document/local/documents_manager.dart';
import '../../features/publication/pages/menu/local/publication_menu_view.dart';
import '../databases/catalog.dart';
import '../repositories/PublicationRepository.dart';
import 'audio.dart';

class Publication {
  final int id;
  MepsLanguage mepsLanguage;
  PublicationCategory category;
  PublicationAttribute attribute;
  String title;
  String issueTitle;
  String shortTitle;
  String coverTitle;
  String undatedTitle;
  String undatedReferenceTitle;
  String description;
  int year;
  int issueTagNumber;
  String symbol;
  String keySymbol;
  int reserved;
  int size;
  int expandedSize;
  int schemaVersion;
  String catalogedOn;
  String lastUpdated;
  String? lastModified;
  int? conventionReleaseDayNumber;
  String? imageSqr;
  String? imageLsr;
  String? networkImageSqr;
  String? networkImageLsr;
  String? hash;
  String? timeStamp;
  String? path;
  String? databasePath;
  bool hasTopics = false;
  bool hasCommentary = false;
  DocumentsManager? documentsManager;
  DatedTextManager? datedTextManager;
  WordsSuggestionsModel? wordsSuggestionsModel;

  List<Audio> audios = [];

  CancelableOperation? _downloadOperation;
  CancelableOperation? _updateOperation;
  CancelToken? _cancelToken;

  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isDownloadingNotifier;
  final ValueNotifier<bool> isDownloadedNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;

  Publication({
    required this.id,
    required this.mepsLanguage,
    required this.category,
    required this.attribute,
    this.title = '',
    this.issueTitle = '',
    this.shortTitle = '',
    this.coverTitle = '',
    this.undatedTitle = '',
    this.undatedReferenceTitle = '',
    this.description = '',
    this.year = 0,
    this.issueTagNumber = 0,
    this.symbol = '',
    this.keySymbol = '',
    this.reserved = 0,
    this.size = 0,
    this.expandedSize = 0,
    this.schemaVersion = 0,
    this.catalogedOn = '',
    this.lastUpdated = '',
    this.lastModified,
    this.conventionReleaseDayNumber,
    this.imageSqr,
    this.imageLsr,
    this.networkImageSqr,
    this.networkImageLsr,
    this.hash,
    this.timeStamp,
    this.path,
    this.databasePath,
    this.hasTopics = false,
    this.hasCommentary = false,
    ValueNotifier<double>? progressNotifier,
    ValueNotifier<bool>? isDownloadingNotifier,
    ValueNotifier<bool>? isDownloadedNotifier,
    ValueNotifier<bool>? isFavoriteNotifier
  }) : progressNotifier = progressNotifier ?? ValueNotifier(0.0),
        isDownloadingNotifier = isDownloadingNotifier ?? ValueNotifier(false),
        isDownloadedNotifier = isDownloadedNotifier ?? ValueNotifier(false),
        isFavoriteNotifier = isFavoriteNotifier ?? ValueNotifier(false);

  factory Publication.fromJson(Map<String, dynamic> json, {bool? isFavorite}) {
    final keySymbol = json['KeySymbol'] ?? json['UndatedSymbol'] ?? '';
    final issueTagNumber = json['IssueTagNumber'] ?? 0;
    final mepsLanguageId = json['MepsLanguageId'] ?? 0;

    // Recherche dans le repository une publications existante
    Publication? existing = PublicationRepository().getPublicationWithMepsLanguageId(keySymbol, issueTagNumber, mepsLanguageId);

    if (existing != null) { // Si la publications est trouvée
      if(!existing.isDownloadedNotifier.value) {
        existing.hash = json['Hash'] ?? existing.hash;
        existing.timeStamp = json['Timestamp'] ?? existing.timeStamp;
        existing.path = json['Path'] ?? existing.path;
        existing.databasePath = json['DatabasePath'];
        existing.description = json['Description'] ?? existing.description;
        existing.imageSqr = json['ImageSqr'] != null ? json['ImageSqr'].toString().startsWith("/data") ? json['ImageSqr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageSqr']}" : existing.imageSqr;
        existing.imageLsr = json['ImageLsr'] != null ? json['ImageLsr'].toString().startsWith("/data") ? json['ImageLsr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageLsr']}" : existing.imageLsr;
      }
      existing.reserved = json['Reserved'] ?? existing.reserved;
      existing.size = json['Size'] ?? existing.size;
      existing.expandedSize = json['ExpandedSize'] ?? existing.expandedSize;
      existing.schemaVersion = json['SchemaVersion'] ?? existing.schemaVersion;
      existing.catalogedOn = json['CatalogedOn'] ?? existing.catalogedOn;
      existing.lastUpdated = json['LastUpdated'] ?? existing.lastUpdated;
      existing.lastModified = json['LastModified'] ?? existing.lastModified;
      existing.conventionReleaseDayNumber = json['ConventionReleaseDayNumber'] ?? existing.conventionReleaseDayNumber;
      existing.isFavoriteNotifier.value = isFavorite ?? existing.isFavoriteNotifier.value;
      existing.networkImageSqr = json['ImageSqr'] != null ? json['ImageSqr'].toString().startsWith("/data") ? existing.networkImageSqr : "https://app.jw-cdn.org/catalogs/publications/${json['ImageSqr']}" : existing.networkImageSqr;
      existing.networkImageLsr = json['ImageLsr'] != null ? json['ImageLsr'].toString().startsWith("/data") ? existing.networkImageLsr : "https://app.jw-cdn.org/catalogs/publications/${json['ImageLsr']}" : existing.networkImageLsr;
      return existing;
    }

    // Sinon, en créer une nouvelle
    Publication publication = Publication(
      id: json['Id'] ?? json['PublicationId'] ?? -1,
      mepsLanguage: json['LanguageSymbol'] != null ?
        MepsLanguage(
            id: json['MepsLanguageId'],
            symbol: json['LanguageSymbol'],
            vernacular: json['LanguageVernacularName'],
            primaryIetfCode: json['LanguagePrimaryIetfCode'],
            isSignLanguage: json['IsSignLanguage'] == 1) : JwLifeSettings().currentLanguage,
      title: json['Title'] ?? '',
      issueTitle: json['IssueTitle'] ?? '',
      shortTitle: json['ShortTitle'] ?? '',
      coverTitle: json['CoverTitle'] ?? '',
      undatedTitle: json['UndatedTitle'] ?? '',
      undatedReferenceTitle: json['UndatedReferenceTitle'] ?? '',
      description: json['Description'] ?? '',
      year: json['Year'] ?? 0,
      issueTagNumber: json['IssueTagNumber'] ?? 0,
      symbol: json['Symbol'] ?? keySymbol,
      keySymbol: keySymbol,
      reserved: json['Reserved'] ?? 0,
      category: json['PublicationTypeId'] != null ? PublicationCategory.all.firstWhere((element) => element.id == json['PublicationTypeId']) : json['PublicationType'] != null ? PublicationCategory.all.firstWhere((element) => element.type == json['PublicationType'] || element.type2 == json['PublicationType']) : PublicationCategory.all.first,
      attribute: json['PublicationAttributeId'] != null ? PublicationAttribute.all.firstWhere((element) => element.id == json['PublicationAttributeId']) : json['Attribute'] != null ? PublicationAttribute.all.firstWhere((element) => element.type == json['Attribute']) : PublicationAttribute.all.first,
      size: json['Size'] ?? 0,
      expandedSize: json['ExpandedSize'] ?? 0,
      schemaVersion: json['SchemaVersion'] ?? 0,
      catalogedOn: json['CatalogedOn'] ?? '',
      lastUpdated: json['LastUpdated'] ?? '',
      lastModified: json['LastModified'],
      conventionReleaseDayNumber: json['ConventionReleaseDayNumber'],
      imageSqr: json['ImageSqr'] != null ? json['ImageSqr'].toString().startsWith("/data") ? json['ImageSqr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageSqr']}" : null,
      imageLsr: json['ImageLsr'] != null ? json['ImageLsr'].toString().startsWith("/data") ? json['ImageLsr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageLsr']}" : null,
      networkImageSqr: json['ImageSqr'] != null ? json['ImageSqr'].toString().startsWith("/data") ? null : "https://app.jw-cdn.org/catalogs/publications/${json['ImageSqr']}" : null,
      networkImageLsr: json['ImageLsr'] != null ? json['ImageLsr'].toString().startsWith("/data") ? null : "https://app.jw-cdn.org/catalogs/publications/${json['ImageLsr']}" : null,
      hash: json['Hash'],
      timeStamp: json['Timestamp'],
      path: json['Path'],
      databasePath: json['DatabasePath'],
      hasTopics: json['TopicSearch'] == 1,
      hasCommentary: json['VerseCommentary'] == 1,

      isDownloadedNotifier: ValueNotifier(json['Hash'] != null && json['DatabasePath'] != null && json['Path'] != null),
      isFavoriteNotifier: ValueNotifier(isFavorite ?? JwLifeApp.userdata.favorites.any((p) => p is Publication && (p.keySymbol == keySymbol && p.mepsLanguage.id == mepsLanguageId && p.issueTagNumber == issueTagNumber))),
    );

    PublicationRepository().addPublication(publication);

    return publication;
  }

  void setCategory(PublicationCategory category) {
    this.category = category;
  }

  void shareLink() {
    String uri = JwOrgUri.publication(
       wtlocale: mepsLanguage.symbol,
       pub: keySymbol,
       issue: issueTagNumber
    ).toString();

    // Partager le lien
    SharePlus.instance.share(
        ShareParams(title: getTitle(), uri: Uri.tryParse(uri))
    );
  }

  Future<void> notifyDownload(String title) async {
    if(JwLifeSettings().notificationDownload) {
      // Notification de fin avec bouton "Ouvrir"
      await NotificationService().showCompletionNotification(
          id: hashCode,
          title: title,
          body: getTitle(),
          payload: JwOrgUri.publication(
              wtlocale: mepsLanguage.symbol,
              pub: keySymbol,
              issue: issueTagNumber
          ).toString()
      );
    }
    else {
      BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;
      showBottomMessageWithAction(getTitle(), SnackBarAction(
          label: 'Ouvrir',
          textColor:  Theme.of(context).primaryColor,
          onPressed: () {
            showMenu(context);
          }));
    }
  }

  Future<bool> download(BuildContext context) async {
    if (await hasInternetConnection()) {
      if (!isDownloadingNotifier.value) {
        isDownloadingNotifier.value = true;
        progressNotifier.value = 0;

        final cancelToken = CancelToken();
        _cancelToken = cancelToken;

        _downloadOperation = CancelableOperation.fromFuture(
          downloadJwpubFile(this, context, cancelToken, false),
          onCancel: () {
            // Ceci s'exécute si l'opération est annulée par `_downloadOperation.cancel()`
            isDownloadingNotifier.value = false;
            isDownloadedNotifier.value = false;
            progressNotifier.value = 0;
            // Annuler la notification
            NotificationService().cancelNotification(hashCode);
          },
        );

        Publication? pubDownloaded = await _downloadOperation!.valueOrCancellation();
        bool hasBible = PublicationRepository().getAllBibles().isNotEmpty;

        if (pubDownloaded != null) {
          // Téléchargement RÉUSSI
          isDownloadedNotifier.value = true;

          if (category.id == 1) {
            if(!hasBible) {
              String bibleKey = pubDownloaded.getKey();
              JwLifeSettings().lookupBible = bibleKey;
              setLookUpBible(bibleKey);
            }

            JwLifeSettings().webViewData.addBibleToBibleSet(this);
            GlobalKeyService.bibleKey.currentState?.refreshBiblePage();
          }

          progressNotifier.value = 1.0;

          // Notification de fin avec bouton "Ouvrir"
          notifyDownload('Téléchargement terminé');
          isDownloadingNotifier.value = false;
          return true; // <-- SUCCÈS
        }
        else {
          // Téléchargement annulé ou échoué (valueOrCancellation() retourne null)
          await NotificationService().cancelNotification(hashCode);
          isDownloadingNotifier.value = false;
          return false; // <-- ÉCHEC/ANNULATION
        }
      }
      // Si la publication était déjà en cours de téléchargement
      return false;
    } else {
      showNoConnectionDialog(context);
      return false; // Pas de connexion
    }
  }

  Future<void> cancelDownload(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _downloadOperation != null) {
      _cancelToken!.cancel();
      _downloadOperation!.cancel();
      _cancelToken = null;
      _downloadOperation = null;
      showBottomMessage('Téléchargement annulé');
    }
    if (isDownloadingNotifier.value) {
      isDownloadingNotifier.value = false;
      isDownloadedNotifier.value = false;
      progressNotifier.value = 0;
    }
  }

  Future<void> update(BuildContext context) async {
    if(await hasInternetConnection()) {
      if (!isDownloadingNotifier.value) {
        progressNotifier.value = -1;
        isDownloadingNotifier.value = true;
        isDownloadedNotifier.value = false;

        final cancelToken = CancelToken();
        _cancelToken = cancelToken;

        _updateOperation = CancelableOperation.fromFuture(
          downloadJwpubFile(this, context, cancelToken, true),
          onCancel: () {
            isDownloadingNotifier.value = false;
            isDownloadedNotifier.value = false;
            progressNotifier.value = 0;
            // Annuler la notification
            NotificationService().cancelNotification(hashCode);
          },
        );

        Publication? pubDownloaded = await _updateOperation!.valueOrCancellation();

        if (pubDownloaded != null) {
          isDownloadedNotifier.value = true;

          if (category.id == 1) {
            GlobalKeyService.bibleKey.currentState?.refreshBiblePage();
          }

          progressNotifier.value = 1.0;

          // ✅ Notification de fin avec bouton "Ouvrir" (comme dans downloads)
          notifyDownload('Mise à jour terminée');
        } else {
          // Téléchargement annulé ou échoué
          await NotificationService().cancelNotification(hashCode);
        }

        isDownloadingNotifier.value = false;
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }


  Future<void> cancelUpdate(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _updateOperation != null) {
      _cancelToken!.cancel();
      _updateOperation!.cancel();
      _cancelToken = null;
      _updateOperation = null;
      showBottomMessage('Mis à jour annulée');
    }
    if (isDownloadingNotifier.value) {
      isDownloadingNotifier.value = false;
      isDownloadedNotifier.value = false;
      progressNotifier.value = 0;
    }
  }

  Future<void> remove(BuildContext context) async {
    progressNotifier.value = -1;
    await removePublication(this);

    documentsManager = null;
    datedTextManager = null;
    hash = null;
    path = null;
    databasePath = null;
    path = null;
    timeStamp = null;
    imageSqr = networkImageSqr;
    imageLsr = networkImageLsr;
    isDownloadingNotifier.value = false;
    isDownloadedNotifier.value = false;
    progressNotifier.value = 0;

    showBottomMessage('Publication supprimée');

    if (category.id == 1) {
      // Récupérer la liste des Bibles
      final List<Publication> bibles = PublicationRepository().getAllBibles();

      // Variable pour stocker la clé finale de la Bible
      String? bibleKeyToUse;

      if (bibles.isEmpty) {
        // Cas 1 : Aucune Bible trouvée
        bibleKeyToUse = '';

      }
      else {
        // Cas 3 : Plusieurs Bibles trouvées - Rechercher celle qui correspond à la langue actuelle
        // Correction de l'erreur : Utilisation de '==' pour la comparaison au lieu de '=' pour l'affectation.
        final Publication? matchingBible = bibles.firstWhereOrNull((element) => element.mepsLanguage.symbol == mepsLanguage.symbol);

        if (matchingBible != null) {
          // Sous-cas 3a : Bible correspondante trouvée
          bibleKeyToUse = matchingBible.getKey();
        }
        else {
          // Sous-cas 3b : Aucune Bible correspondante trouvée, utiliser la première par défaut
          final Publication defaultBible = bibles.first;
          bibleKeyToUse = defaultBible.getKey();
        }
      }

      // Application unique des mises à jour pour éviter la duplication de code
      JwLifeSettings().lookupBible = bibleKeyToUse;
      setLookUpBible(bibleKeyToUse);

      JwLifeSettings().webViewData.removeBibleFromBibleSet(this);

      GlobalKeyService.bibleKey.currentState?.refreshBiblePage();
    }

    if(keySymbol == 'S-34') {
      GlobalKeyService.workShipKey.currentState?.refreshMeetingsPubs();
    }
    
    // on cherche si la publication est dans le catalogue
    String? keySymbolString = await PubCatalog.getKeySymbolFromCatalogue(symbol, issueTagNumber, mepsLanguage.id);
    if(keySymbolString == null) {
      // on enlève du repository
      PublicationRepository().removePublication(this);
      GlobalKeyService.homeKey.currentState!.refreshFavorites();
    }
  }

  Future<void> showMenu(BuildContext context, {bool showDownloadDialog = true}) async {
    if(isDownloadedNotifier.value && !isDownloadingNotifier.value) {
      if(hasUpdate()) {
        showBottomMessageWithAction('Une mise à jour de la publication est disponible', SnackBarAction(
          label: 'Mettre à jour',
          textColor: Theme.of(context).primaryColor,
          onPressed: () {
            update(context);
          },
        ));
      }
      await showPage(PublicationMenuView(publication: this));
    }
    else {
      if(await hasInternetConnection()) {
        //await showPage(PublicationMenu(publication: this));
        if(showDownloadDialog) {
          await showDownloadPublicationDialog(context, this);
        }
        else {
          await download(context);
        }
      }
      else {
        await showNoConnectionDialog(context);
      }
    }
  }

  bool isBible() {
    return category.id == 1;
  }

  bool hasUpdate() {
    if (lastModified == null || timeStamp == null) {
      return false;
    }

    DateTime lastModDate = DateTime.parse(lastModified!);
    DateTime pubDate = DateTime.parse(timeStamp!);

    if (lastModDate.isAtSameMomentAs(pubDate)) {
      return false;
    }

    return lastModDate.isAfter(pubDate);
  }

  Future<void> fetchAudios() async {
    if(audios.isEmpty) {
      List<Audio>? audios = await Api.getPubAudio(keySymbol: keySymbol, issueTagNumber: issueTagNumber, languageSymbol: mepsLanguage.symbol);
      if(audios != null) {
        this.audios = audios;
      }
    }
  }

  String getTitle() {
    if(issueTitle.isNotEmpty) {
      return issueTitle;
    }
    else {
      return title;
    }
  }

  String getShortTitle() {
    if(issueTitle.isNotEmpty) {
      return issueTitle;
    }
    else {
      return shortTitle;
    }
  }

  String getSymbolAndIssue() {
    return issueTagNumber != 0 ? '$keySymbol • $issueTagNumber' : keySymbol;
  }

  String getKey() {
    return '${keySymbol}_${mepsLanguage.symbol}';
  }

  String getRelativeDateText() {
    try {
      DateTime firstPublished = DateTime.parse(catalogedOn);

      // On normalise les deux dates à minuit pour ignorer l'heure
      DateTime publishedDate = DateTime(firstPublished.year, firstPublished.month, firstPublished.day);
      DateTime today = DateTime.now();
      DateTime currentDate = DateTime(today.year, today.month, today.day);

      int days = currentDate.difference(publishedDate).inDays;

      String textToShow = (days == 0)
          ? "Aujourd'hui"
          : (days == 1)
          ? "Hier"
          : "Il y a $days jours";

      return "${mepsLanguage.vernacular} · $textToShow";
    } catch (e) {
      return "";
    }
  }
}