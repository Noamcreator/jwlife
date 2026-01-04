import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:async/async.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/features/document/local/dated_text_manager.dart';
import 'package:jwlife/features/document/local/document_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_data/app_data_service.dart';
import '../../app/services/global_key_service.dart';
import '../../app/services/notification_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/app_data/meetings_pubs_service.dart';
import '../../core/uri/jworg_uri.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../core/utils/utils_document.dart';
import '../../features/document/local/documents_manager.dart';
import '../../features/publication/models/menu/local/words_suggestions_model.dart';
import '../../features/publication/pages/local/publication_menu_view.dart';
import '../../i18n/i18n.dart';
import '../databases/catalog.dart';
import '../repositories/PublicationRepository.dart';
import 'audio.dart';

class Publication {
  int id;
  MepsLanguage mepsLanguage;
  PublicationCategory category;
  List<PublicationAttribute> attributes;
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
  bool hasHeading = false;
  bool isSingleDocument = false;
  DocumentsManager? documentsManager;
  DatedTextManager? datedTextManager;
  WordsSuggestionsModel? wordsSuggestionsModel;

  final ValueNotifier<List<Audio>> audiosNotifier;

  CancelableOperation? _downloadOperation;
  CancelableOperation? _updateOperation;
  CancelToken? _cancelToken;

  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isDownloadingNotifier;
  final ValueNotifier<bool> isDownloadedNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<bool> hasUpdateNotifier;

  bool canCancelDownload = false;

  Publication({
    required this.id,
    required this.mepsLanguage,
    required this.category,
    required this.attributes,
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
    this.hasHeading = false,
    this.isSingleDocument = false,
    ValueNotifier<List<Audio>>? audiosNotifier,
    ValueNotifier<double>? progressNotifier,
    ValueNotifier<bool>? isDownloadingNotifier,
    ValueNotifier<bool>? isDownloadedNotifier,
    ValueNotifier<bool>? isFavoriteNotifier,
    ValueNotifier<bool>? hasUpdateNotifier
  }) : audiosNotifier = audiosNotifier ?? ValueNotifier([]),
        progressNotifier = progressNotifier ?? ValueNotifier(0.0),
        isDownloadingNotifier = isDownloadingNotifier ?? ValueNotifier(false),
        isDownloadedNotifier = isDownloadedNotifier ?? ValueNotifier(false),
        isFavoriteNotifier = isFavoriteNotifier ?? ValueNotifier(false),
        hasUpdateNotifier = hasUpdateNotifier ?? ValueNotifier(false);

  factory Publication.fromJson(Map<String, dynamic> json, {bool? isFavorite, MepsLanguage? language, bool updateValue = false}) {
    final keySymbol = json['KeySymbol'] ?? json['UndatedSymbol'] ?? '';
    final issueTagNumber = json['IssueTagNumber'] ?? 0;
    final mepsLanguageId = json['MepsLanguageId'] as int? ?? language?.id ?? 0;

    // 1. Recherche de l'existant
    Publication? existing = PublicationRepository().getPublicationWithMepsLanguageId(
      keySymbol, issueTagNumber, mepsLanguageId
    );

    // 2. Logiques d'extraction réutilisables
    List<PublicationAttribute> extractAttributes() {
      final idsString = json['PublicationAttributeIds'] as String?;
      if (idsString?.isNotEmpty ?? false) {
        final ids = idsString!.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toSet();
        return PublicationAttribute.all.where((a) => ids.contains(a.id)).toList();
      }
      
      final attrId = json['PublicationAttributeId'];
      if (attrId != null) {
        return [PublicationAttribute.all.firstWhere((a) => a.id == attrId, orElse: () => PublicationAttribute.all.first)];
      }

      final typesString = json['AttributeTypes'] as String?;
      if (typesString != null) {
        final types = typesString.split(',').map((e) => e.trim()).toSet();
        return PublicationAttribute.all.where((a) => types.contains(a.type)).toList();
      }

      final type = json['Attribute'] as String?;
      if (type != null) {
        return [PublicationAttribute.all.firstWhere((a) => a.type == type, orElse: () => PublicationAttribute.all.first)];
      }

      return [PublicationAttribute.all.first];
    }

    String? formatImageUrl(String? key, {bool isNetwork = false}) {
      final val = json[key]?.toString();
      if (val == null) return null;
      final isLocal = val.startsWith("/data");
      if (isNetwork) return isLocal ? null : "https://app.jw-cdn.org/catalogs/publications/$val";
      return isLocal ? val : "https://app.jw-cdn.org/catalogs/publications/$val";
    }

    PublicationCategory extractCategory() {
      final typeId = json['PublicationTypeId'];
      if (typeId != null) return PublicationCategory.all.firstWhere((e) => e.id == typeId);
      
      final type = json['PublicationType'];
      if (type != null) {
        return PublicationCategory.all.firstWhere(
          (e) => e.type == type || e.type2 == type, 
          orElse: () => PublicationCategory.all.first
        );
      }
      return PublicationCategory.all.first;
    }

    // 3. Cas : Mise à jour ou Existant
    if (existing != null) {
      existing.id = json['PublicationId'] ?? existing.id;

      // Champs communs à mettre à jour peu importe l'état du téléchargement
      existing.reserved = json['Reserved'] ?? existing.reserved;
      existing.size = json['Size'] ?? existing.size;
      existing.expandedSize = json['ExpandedSize'] ?? existing.expandedSize;
      existing.schemaVersion = json['SchemaVersion'] ?? existing.schemaVersion;
      existing.catalogedOn = json['CatalogedOn'] ?? existing.catalogedOn;
      existing.lastUpdated = json['LastUpdated'] ?? existing.lastUpdated;
      existing.lastModified = json['LastModified'] ?? existing.lastModified;
      existing.conventionReleaseDayNumber = json['ConventionReleaseDayNumber'] ?? existing.conventionReleaseDayNumber;
      existing.networkImageSqr = formatImageUrl('ImageSqr', isNetwork: true) ?? existing.networkImageSqr;
      existing.networkImageLsr = formatImageUrl('ImageLsr', isNetwork: true) ?? existing.networkImageLsr;

      if (updateValue || !existing.isDownloadedNotifier.value) {
        existing.title = json['Title'] ?? existing.title;
        existing.issueTitle = json['IssueTitle'] ?? existing.issueTitle;
        existing.shortTitle = json['ShortTitle'] ?? existing.shortTitle;
        existing.coverTitle = json['CoverTitle'] ?? existing.coverTitle;
        existing.year = json['Year'] ?? existing.year;
        existing.symbol = json['Symbol'] ?? existing.symbol;
        existing.hash = json['Hash'] ?? existing.hash;
        existing.timeStamp = json['Timestamp'] ?? existing.timeStamp;
        existing.path = json['Path'] ?? existing.path;
        existing.databasePath = json['DatabasePath'] ?? existing.databasePath;
        existing.description = json['Description'] ?? existing.description;
        existing.imageSqr = formatImageUrl('ImageSqr') ?? existing.imageSqr;
        existing.imageLsr = formatImageUrl('ImageLsr') ?? existing.imageLsr;
        existing.hasTopics = json['TopicSearch'] == 1;
        existing.hasCommentary = json['VerseCommentary'] == 1;
        existing.hasHeading = json['HeadingSearch'] == 1;
        existing.isSingleDocument = json['IsSingleDocument'] == 1;
        
        if (updateValue) {
          existing.category = extractCategory();
          existing.attributes = extractAttributes();
          existing.isDownloadedNotifier.value = true;
        }
      }

      if (isFavorite != null) existing.isFavoriteNotifier.value = isFavorite;
      existing.hasUpdateNotifier.value = existing.hasUpdate();
      
      return existing;
    }

    // 4. Cas : Création d'une nouvelle publication
    final mepsLanguage = language ?? (json['LanguageSymbol'] != null ? MepsLanguage.fromJson(json) : JwLifeSettings.instance.libraryLanguage.value);
    final String? lastMod = json['LastModified'];
    final String? ts = json['Timestamp'];
    bool hasUpdateCalc = false;

    if (lastMod != null && ts != null) {
      hasUpdateCalc = DateTime.parse(lastMod).isAfter(DateTime.parse(ts));
    }

    final publication = Publication(
      id: json['Id'] ?? json['PublicationId'] ?? -1,
      mepsLanguage: mepsLanguage,
      title: json['Title'] ?? '',
      issueTitle: json['IssueTitle'] ?? '',
      shortTitle: json['ShortTitle'] ?? '',
      coverTitle: json['CoverTitle'] ?? '',
      undatedTitle: json['UndatedTitle'] ?? '',
      undatedReferenceTitle: json['UndatedReferenceTitle'] ?? '',
      description: json['Description'] ?? '',
      year: json['Year'] ?? 0,
      issueTagNumber: issueTagNumber,
      symbol: json['Symbol'] ?? keySymbol,
      keySymbol: keySymbol,
      reserved: json['Reserved'] ?? 0,
      category: extractCategory(),
      attributes: extractAttributes(),
      size: json['Size'] ?? 0,
      expandedSize: json['ExpandedSize'] ?? 0,
      schemaVersion: json['SchemaVersion'] ?? 0,
      catalogedOn: json['CatalogedOn'] ?? '',
      lastUpdated: json['LastUpdated'] ?? '',
      lastModified: lastMod,
      conventionReleaseDayNumber: json['ConventionReleaseDayNumber'],
      imageSqr: formatImageUrl('ImageSqr'),
      imageLsr: formatImageUrl('ImageLsr'),
      networkImageSqr: formatImageUrl('ImageSqr', isNetwork: true),
      networkImageLsr: formatImageUrl('ImageLsr', isNetwork: true),
      hash: json['Hash'],
      timeStamp: ts,
      path: json['Path'],
      databasePath: json['DatabasePath'],
      hasTopics: json['TopicSearch'] == 1,
      hasCommentary: json['VerseCommentary'] == 1,
      hasHeading: json['HeadingSearch'] == 1,
      isSingleDocument: json['IsSingleDocument'] == 1,
      isDownloadedNotifier: ValueNotifier(json['Hash'] != null && json['DatabasePath'] != null && json['Path'] != null),
      isFavoriteNotifier: ValueNotifier(isFavorite ?? AppDataService.instance.favorites.value.any((p) => p is Publication && (p.keySymbol == keySymbol && p.mepsLanguage.id == mepsLanguageId && p.issueTagNumber == issueTagNumber))),
      hasUpdateNotifier: ValueNotifier(hasUpdateCalc),
    );

    PublicationRepository().addPublication(publication);
    return publication;
  }

  void setCategory(PublicationCategory category) {
    this.category = category;
  }

  String shareLink({hide = false}) {
    String uri = JwOrgUri.publication(
       wtlocale: mepsLanguage.symbol,
       pub: keySymbol,
       issue: issueTagNumber
    ).toString();

    // Partager le lien
    if(!hide) {
      SharePlus.instance.share(ShareParams(title: getTitle(), uri: Uri.tryParse(uri)));
    }

    return uri;
  }

  Future<void> notifyDownload(String title) async {
    if(JwLifeSettings.instance.notificationDownload) {
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
          label: i18n().action_open,
          textColor:  Theme.of(context).primaryColor,
          onPressed: () {
            showMenu(context);
          }));
    }
  }

  Future<bool> download(BuildContext context) async {
    if (await hasInternetConnection(context: context)) {
      if (!isDownloadingNotifier.value) {
        isDownloadingNotifier.value = true;
        progressNotifier.value = 0;

        canCancelDownload = true;
        final cancelToken = CancelToken();
        _cancelToken = cancelToken;

        _downloadOperation = CancelableOperation.fromFuture(
          downloadJwpubFile(this, cancelToken, false),
          onCancel: () {
            isDownloadingNotifier.value = false;
            isDownloadedNotifier.value = false;
            progressNotifier.value = 0;
            canCancelDownload = false;
            // Annuler la notification
            NotificationService().cancelNotification(hashCode);
          },
        );

        Publication? pubDownloaded = await _downloadOperation!.valueOrCancellation();
        bool hasBible = PublicationRepository().getAllBibles().isNotEmpty;

        if (pubDownloaded != null) {
          // Notification de fin avec bouton "Ouvrir"
          isDownloadingNotifier.value = false;
          progressNotifier.value = 1.0;
          canCancelDownload = false;
          notifyDownload(i18n().message_download_complete);

          if (category.id == 1) {
            if(!hasBible) {
              String bibleKey = pubDownloaded.getKey();
              JwLifeSettings.instance.lookupBible.value = bibleKey;
              AppSharedPreferences.instance.setLookUpBible(bibleKey);
            }

            JwLifeSettings.instance.webViewSettings.addBibleToBibleSet(this);
          }
          return true; // <-- SUCCÈS
        }
        else {
          // Téléchargement annulé ou échoué (valueOrCancellation() retourne null)
          await NotificationService().cancelNotification(hashCode);
          isDownloadingNotifier.value = false;
          canCancelDownload = false;
          return false; // <-- ÉCHEC/ANNULATION
        }
      }
    }
    return false;
  }

  Future<void> cancelDownload() async {
  if (canCancelDownload && isDownloadingNotifier.value) {
    // Annuler le token Dio (ce qui stoppe le flux réseau immédiatement)
    _cancelToken?.cancel();
    
    // Annuler l'opération Async (ce qui déclenche le callback onCancel)
    _downloadOperation?.cancel();
    _updateOperation?.cancel();

    _cancelToken = null;
    _downloadOperation = null;
    _updateOperation = null;

    isDownloadingNotifier.value = false;
    progressNotifier.value = hasUpdateNotifier.value ? 1 : 0;
    
    // Message dynamique selon le contexte
    showBottomMessage(hasUpdateNotifier.value 
        ? i18n().message_update_cancel 
        : i18n().message_download_cancel);
  }
}

  Future<bool> update(BuildContext context, {bool refreshUi = true}) async {
    if(await hasInternetConnection(context: context)) {
      if (!isDownloadingNotifier.value) {
        isDownloadingNotifier.value = true;
        progressNotifier.value = 0;

        canCancelDownload = true;
        final cancelToken = CancelToken();
        _cancelToken = cancelToken;

        _updateOperation = CancelableOperation.fromFuture(
          downloadJwpubFile(this, cancelToken, true, refreshUi: refreshUi),
          onCancel: () {
            isDownloadingNotifier.value = false;
            progressNotifier.value = 0;
            canCancelDownload = false;
            // Annuler la notification
            NotificationService().cancelNotification(hashCode);
          },
        );

        Publication? pubDownloaded = await _updateOperation!.valueOrCancellation();

        if (pubDownloaded != null) {
          if (category.id == 1) {
            GlobalKeyService.bibleKey.currentState?.goToTheBooksTab();
          }

          // Notification de fin avec bouton "Ouvrir"
          isDownloadingNotifier.value = false;
          hasUpdateNotifier.value = false;
          progressNotifier.value = 1.0;
          canCancelDownload = false;
          notifyDownload(i18n().message_download_complete);

          if (category.id == 1) {
            if(AppSharedPreferences.instance.getLookUpBible() == pubDownloaded.getKey()) {
              String bibleKey = pubDownloaded.getKey();
              JwLifeSettings.instance.lookupBible.value = pubDownloaded.getKey();
              AppSharedPreferences.instance.setLookUpBible(bibleKey);
            }
          }
          return true; // <-- SUCCÈS
        }
        else {
          // Téléchargement annulé ou échoué
          await NotificationService().cancelNotification(hashCode);
          isDownloadingNotifier.value = false;
          canCancelDownload = false;
          return false; // <-- ÉCHEC/ANNULATION
        }
      }
    }
    return false;
  }

  Future<void> remove() async {
    progressNotifier.value = -1;
    await documentsManager?.database.close();
    await datedTextManager?.database.close();
    documentsManager = null;
    datedTextManager = null;

    await removePublication(this);

    hash = null;
    path = null;
    databasePath = null;
    path = null;
    timeStamp = null;
    imageSqr = networkImageSqr;
    imageLsr = networkImageLsr;
    isDownloadingNotifier.value = false;
    isDownloadedNotifier.value = false;
    hasUpdateNotifier.value = false;
    canCancelDownload = false;
    progressNotifier.value = 0;

    showBottomMessage(i18n().message_delete_item(title));

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
      JwLifeSettings.instance.lookupBible.value = bibleKeyToUse;
      AppSharedPreferences.instance.setLookUpBible(bibleKeyToUse);

      JwLifeSettings.instance.webViewSettings.removeBibleFromBibleSet(this);
    }

    if(keySymbol == 'S-34') {
      refreshPublicTalks();
    }
    
    // on cherche si la publication est dans le catalogue
    String? keySymbolString = await CatalogDb.instance.getKeySymbolFromCatalogue(symbol, issueTagNumber, mepsLanguage.id);
    if(keySymbolString == null) {
      // on enlève du repository
      PublicationRepository().removePublication(this);
    }
  }

  Future<void> showMenu(BuildContext context, {bool showDownloadDialog = true}) async {
    if(isDownloadedNotifier.value && !isDownloadingNotifier.value) {
      if(hasUpdateNotifier.value) {
        showBottomMessageWithAction(i18n().message_updated_publication, SnackBarAction(
          label: i18n().action_update,
          textColor: Theme.of(context).primaryColor,
          onPressed: () {
            update(context);
          },
        ));
      }
      if(JwLifeSettings.instance.autoOpenSingleDocument && isSingleDocument) {
        documentsManager = DocumentsManager(publication: this);
        await documentsManager!.initializeDatabaseAndData();
        try {
          List<Map<String, dynamic>> result = await documentsManager!.database.rawQuery('''
            SELECT Document.MepsDocumentId FROM Document
            INNER JOIN PublicationViewItemDocument ON Document.DocumentId = PublicationViewItemDocument.DocumentId
            LIMIT 1
          ''');

          showPageDocument(this, result.first['MepsDocumentId']);
        }
        catch (e) {
          print('Erreur lors de la lecture du premier document: $e');
          showPage(PublicationMenuPage(publication: this));
        }
      }
      else {
        await showPage(PublicationMenuPage(publication: this));
      }
    }
    else {
      if(await hasInternetConnection(context: context)) {
        if(showDownloadDialog) {
          await showDownloadPublicationDialog(context, this);
        }
        else {
          await download(context);
        }
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

    return lastModDate.isAfter(pubDate);
  }

  Future<void> fetchAudios() async {
    if(audiosNotifier.value.isEmpty) {
      List<Audio>? audios = await Api.getPubAudio(keySymbol: keySymbol, issueTagNumber: issueTagNumber, languageSymbol: mepsLanguage.symbol);
      if(audios != null) {
        audiosNotifier.value = audios;
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

  String getCoverTitle() {
    if(coverTitle.isNotEmpty) {
      return coverTitle;
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

      return "${mepsLanguage.vernacular} · ${timeAgo(firstPublished)}";
    } catch (e) {
      return "";
    }
  }

  String getFullPath(String? path) {
    if(this.path != null && path != null) {
      return '${this.path!}/$path';
    }
    return '';
  }
}