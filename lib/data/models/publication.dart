import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/features/bible/views/bible_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/services/settings_service.dart';
import '../../features/publication/pages/document/local/documents_manager.dart';
import '../../features/publication/pages/menu/local/publication_menu_view.dart';
import '../../features/publication/pages/menu/online/publication_menu.dart';
import '../repositories/PublicationRepository.dart';

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

    ValueNotifier<double>? progressNotifier,
    ValueNotifier<bool>? isDownloadingNotifier,
    ValueNotifier<bool>? isDownloadedNotifier,
    ValueNotifier<bool>? isFavoriteNotifier,

    this.hash,
    this.timeStamp,
    this.path,
    this.databasePath,
    this.hasTopics = false,
    this.hasCommentary = false,
  }) : progressNotifier = progressNotifier ?? ValueNotifier(0.0),
        isDownloadingNotifier = isDownloadingNotifier ?? ValueNotifier(false),
        isDownloadedNotifier = isDownloadedNotifier ?? ValueNotifier(false),
        isFavoriteNotifier = isFavoriteNotifier ?? ValueNotifier(false);

  factory Publication.fromJson(Map<String, dynamic> json, {bool? isFavorite}) {
    final symbol = json['Symbol'] ?? '';
    final issueTagNumber = json['IssueTagNumber'] ?? 0;
    final mepsLanguageId = json['MepsLanguageId'] ?? 0;

    // Recherche dans le repository une publication existante
    Publication? existing = PublicationRepository().getByCompositeKey(symbol, issueTagNumber, mepsLanguageId);

    if (existing != null) { // Si la publication est trouvée
      if(!existing.isDownloadedNotifier.value) { // Si elle n'est pas encore téléchargée, on la met à jour avec les nouvelles données de la base de données téléchargée
        existing.hash = json['Hash'] ?? existing.hash;
        existing.timeStamp = json['Timestamp'] ?? existing.timeStamp;
        existing.path = json['Path'] ?? existing.path;
        existing.databasePath = json['DatabasePath'];
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
      return existing;
    }

    // Sinon, en créer une nouvelle
    Publication publication = Publication(
      id: json['Id'] ?? json['PublicationId'] ?? 0,
      mepsLanguage: json['LanguageSymbol'] != null ? MepsLanguage(id: json['MepsLanguageId'], symbol: json['LanguageSymbol'], vernacular: json['LanguageVernacularName'], primaryIetfCode: json['LanguagePrimaryIetfCode']) : JwLifeSettings().currentLanguage,
      title: json['Title'] ?? '',
      issueTitle: json['IssueTitle'] ?? '',
      shortTitle: json['ShortTitle'] ?? '',
      coverTitle: json['CoverTitle'] ?? '',
      undatedTitle: json['UndatedTitle'] ?? '',
      undatedReferenceTitle: json['UndatedReferenceTitle'] ?? '',
      year: json['Year'] ?? 0,
      issueTagNumber: json['IssueTagNumber'] ?? 0,
      symbol: json['Symbol'] ?? '',
      keySymbol: json['UndatedSymbol'] ?? json['KeySymbol'] ?? '',
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

      progressNotifier: ValueNotifier(0.0),
      isDownloadingNotifier: ValueNotifier(false),
      isDownloadedNotifier: ValueNotifier(json['Hash'] != null && json['DatabasePath'] != null && json['Path'] != null),
      isFavoriteNotifier: ValueNotifier(isFavorite ?? JwLifeApp.userdata.favorites.any((p) => p.symbol == symbol && p.mepsLanguage.id == mepsLanguageId && p.issueTagNumber == issueTagNumber)),
    );

    PublicationRepository().addPublication(publication);

    return publication;
  }

  void setCategory(PublicationCategory category) {
    this.category = category;
  }

  void shareLink() {
    // Créer une map avec les paramètres de l'URL
    Map<String, String> queryParams = {
      'srcid': 'jwlshare',
      'wtlocale': mepsLanguage.symbol,
      'prefer': 'lang',
      'pub': symbol,
    };

    // Ajouter le paramètre issue si nécessaire
    if (issueTagNumber != 0) {
      queryParams['issue'] = issueTagNumber.toString();
    }

    // Créer l'URL avec les paramètres
    final uri = Uri.https('www.jw.org', '/finder', queryParams);

    // Partager le lien
    Share.share(
      uri.toString(),
      subject: title,
    );
  }

  Future<void> download(BuildContext context) async {
    if (!isDownloadingNotifier.value) {
      isDownloadingNotifier.value = true;
      progressNotifier.value = 0;

      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      final messenger = ScaffoldMessenger.of(context);   // ✅ capture en avance
      final theme = Theme.of(context); // ✅ capture en avance

      _downloadOperation = CancelableOperation.fromFuture(
        downloadJwpubFile(this, context, cancelToken),
        onCancel: () {
          isDownloadingNotifier.value = false;
          isDownloadedNotifier.value = false;
          progressNotifier.value = 0;
        },
      );

      Publication? pubDownloaded = await _downloadOperation!.valueOrCancellation();

      if (pubDownloaded != null) {
        isDownloadedNotifier.value = true;

        if (category.id == 1) {
          BiblePage.refreshBibleView();
        }

        progressNotifier.value = 1.0;

        showBottomMessageWithActionState(messenger, theme.brightness == Brightness.dark, '« ${getTitle()} » téléchargée', SnackBarAction(
            label: 'Ouvrir',
            textColor: theme.primaryColor,
            onPressed: () {
              messenger.clearSnackBars();
              pubDownloaded.showMenu(context);
            },
          ),
        );
      }

      isDownloadingNotifier.value = false;
    }
  }

  Future<void> cancelDownload(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _downloadOperation != null) {
      _cancelToken!.cancel();
      _downloadOperation!.cancel();
      _cancelToken = null;
      _downloadOperation = null;
      showBottomMessage(context, 'Téléchargement annulé');
    }
  }

  Future<void> update(BuildContext context) async {
    if (!isDownloadingNotifier.value) {
      progressNotifier.value = -1;
      isDownloadingNotifier.value = true;
      isDownloadedNotifier.value = false;

      await removeJwpubFile(this);

      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      final messenger = ScaffoldMessenger.of(context);   // ✅ capture en avance
      final theme = Theme.of(context); // ✅ capture en avance

      _updateOperation = CancelableOperation.fromFuture(
        downloadJwpubFile(this, context, cancelToken),
        onCancel: () {
          isDownloadingNotifier.value = false;
          isDownloadedNotifier.value = false;
          progressNotifier.value = 0;
        },
      );

      Publication? pubDownloaded = await _downloadOperation!.valueOrCancellation();

      if (pubDownloaded != null) {
        isDownloadedNotifier.value = true;

        if (category.id == 1) {
          BiblePage.refreshBibleView();
        }

        progressNotifier.value = 1.0;

        // ✅ Utilise messenger capturé
        showBottomMessageWithActionState(messenger, theme.brightness == Brightness.dark, '« ${getTitle()} » mis à jour', SnackBarAction(
          label: 'Ouvrir',
          textColor: theme.primaryColor,
          onPressed: () {
              messenger.clearSnackBars();
              pubDownloaded.showMenu(context);
            },
          ),
        );
      }

      isDownloadingNotifier.value = false;
    }
  }

  Future<void> cancelUpdate(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloadingNotifier.value && _cancelToken != null && _updateOperation != null) {
      _cancelToken!.cancel();
      _updateOperation!.cancel();
      _cancelToken = null;
      _updateOperation = null;
      showBottomMessage(context, 'Mis à jour annulée');
    }
  }

  Future<void> remove(BuildContext context) async {
    progressNotifier.value = -1;
    await removeJwpubFile(this);

    if (category.id == 1) {
      BiblePage.refreshBibleView();
    }

    showBottomMessage(context, 'Publication supprimée');

    documentsManager = null;
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
  }

  void showMenu(BuildContext context, {int? mepsLanguage}) async {
    if(isDownloadedNotifier.value && !isDownloadingNotifier.value) {
      showPage(context, PublicationMenuView(publication: this));
    }
    else {
      if(await hasInternetConnection()) {
        showPage(context, PublicationMenu(publication: this));
        //await download(context);
      }
      else {
        showNoConnectionDialog(context);
      }
    }
  }

  bool isBible() {
    return category.id == 1 || schemaVersion == 9;
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