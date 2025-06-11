import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/meps/language.dart';
import 'package:jwlife/modules/bible/views/bible_view.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

class Publication {
  final int id;
  MepsLanguage mepsLanguage;
  PublicationCategory category;
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
  String attribute;
  int attributeId;
  int schemaVersion;
  String catalogedOn;
  String lastUpdated;
  String? lastModified;
  String? imageSqr;
  String? imageLsr;
  bool isDownloaded;
  CancelableOperation? _downloadOperation;
  CancelableOperation? _updateOperation;
  CancelToken? _cancelToken;
  double downloadProgress;
  bool isDownloading;
  String hash;
  String timeStamp;
  String path;
  String databasePath;
  bool hasTopics = false;
  bool hasCommentary = false;
  DocumentsManager? documentsManager;

  Publication({
    required this.id,
    required this.mepsLanguage,
    required this.category,
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
    this.attribute = '',
    this.attributeId = -1,
    this.size = 0,
    this.expandedSize = 0,
    this.schemaVersion = 0,
    this.catalogedOn = '',
    this.lastUpdated = '',
    this.lastModified,
    this.imageSqr,
    this.imageLsr,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.hash = '',
    this.timeStamp = '',
    this.path = '',
    this.databasePath = '',
    this.hasTopics = false,
    this.hasCommentary = false,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    return Publication(
      id: json['Id'] ?? json['PublicationId'] ?? 0,
      mepsLanguage: json['LanguageSymbol'] != null ? MepsLanguage(id: json['MepsLanguageId'], symbol: json['LanguageSymbol'], vernacular: json['LanguageVernacularName'], primaryIetfCode: json['LanguagePrimaryIetfCode']) : JwLifeApp.settings.currentLanguage,
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
      category: json['PublicationTypeId'] != null ? PublicationCategory.getCategories().firstWhere((element) => element.id == json['PublicationTypeId']) : json['PublicationType'] != null ? PublicationCategory.getCategories().firstWhere((element) => element.type == json['PublicationType'] || element.type2 == json['PublicationType']) : PublicationCategory.getCategories().first,
      attribute: json['Attribute'] ?? '',
      attributeId: json['PublicationAttributeId'] ?? -1,
      size: json['Size'] ?? 0,
      expandedSize: json['ExpandedSize'] ?? 0,
      schemaVersion: json['SchemaVersion'] ?? 0,
      catalogedOn: json['CatalogedOn'] ?? '',
      lastUpdated: json['LastUpdated'] ?? '',
      lastModified: json['LastModified'] ?? '',
      imageSqr: json['ImageSqr'] != null ? json['ImageSqr'].toString().startsWith("/data") ? json['ImageSqr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageSqr']}" : null,
      imageLsr: json['ImageLsr'] != null ? json['ImageLsr'].toString().startsWith("/data") ? json['ImageLsr'] : "https://app.jw-cdn.org/catalogs/publications/${json['ImageLsr']}" : null,
      isDownloaded: json['Hash'] != null && json['Hash'] != '' && json['DatabasePath'] != null && json['DatabasePath'] != '' ? true : false,
      hash: json['Hash'] ?? '',
      timeStamp: json['Timestamp'] ?? '',
      path: json['Path'] ?? '',
      databasePath: json['DatabasePath'] ?? '',
      hasTopics: json['TopicSearch'] == 1 ? true : false,
      hasCommentary: json['VerseCommentary'] == 1 ? true : false,
    );
  }

  void setDownload(dynamic json) {
    isDownloaded = true;
    hash = json['Hash'];
    timeStamp = json['Timestamp'];
    path = json['Path'];
    databasePath = json['DatabasePath'];
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

  Future<void> download(BuildContext context, {void Function(double progress)? update}) async {
    if (!isDownloading) {
      isDownloading = true;

      _cancelToken = CancelToken();
      _downloadOperation = CancelableOperation.fromFuture(
        downloadJwpubFile(this, context, _cancelToken, update: update),
        onCancel: () {
          isDownloading = false;
          isDownloaded = false;
          downloadProgress = 0;
          showBottomMessage(context, 'Téléchargement annulé');
        },
      );

      Publication? pubDownloaded = await _downloadOperation!.valueOrCancellation();

      if (pubDownloaded != null) {
        if (PubCatalog.datedPublications.any((element) => element.keySymbol == keySymbol)) {
          HomeView.setStateHomePage();
        }

        if (category.id == 1) {
          BibleView.refreshBibleView();
        }

        if (update != null) {
          update(downloadProgress);
        }

        showBottomMessageWithAction(
          context,
          '${getTitle()} téléchargée',
          SnackBarAction(
            label: 'Ouvrir',
            textColor: Theme.of(context).primaryColor,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              pubDownloaded.showMenu(context, update: update);
            },
          ),
        );
      }

      isDownloading = false;
    }
  }

  Future<void> cancelDownload(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloading && _cancelToken != null && _downloadOperation != null) {
      _cancelToken!.cancel('Téléchargement annulé par l\'utilisateur');
      _downloadOperation!.cancel();
      _cancelToken = null;
      _downloadOperation = null;
      showBottomMessage(context, 'Téléchargement annulé');
    }
  }

  Future<void> update(BuildContext context, {void Function(double progress)? update}) async {
    if (!isDownloading) {
      isDownloading = true;
      downloadProgress = -1;

      if (update != null) {
        update(downloadProgress);
      }

      await removeJwpubFile(this);

      // Création du token d'annulation pour l'opération de téléchargement
      _cancelToken = CancelToken();

      // Encapsuler l'opération de téléchargement dans une CancelableOperation
      _updateOperation = CancelableOperation.fromFuture(
        downloadJwpubFile(this, context, _cancelToken, update: update),
        onCancel: () {
          isDownloading = false;
          isDownloaded = false;
          downloadProgress = 0;
          showBottomMessage(context, 'Téléchargement annulé');
        },
      );

      // Attente de l'opération de téléchargement avec possibilité d'annulation
      Publication? pubDownloaded = await _updateOperation!.valueOrCancellation();

      if (pubDownloaded != null) {
        if (PubCatalog.datedPublications.any((element) => element.keySymbol == keySymbol)) {
          HomeView.setStateHomePage();
        }

        if (category.id == 1) {
          BibleView.refreshBibleView();
        }

        if (update != null) {
          update(downloadProgress);
        }

        showBottomMessageWithAction(
          context,
          '${getTitle()} mis à jour',
          SnackBarAction(
            label: 'Ouvrir',
            textColor: Theme.of(context).primaryColor,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              pubDownloaded.showMenu(context, update: update);
            },
          ),
        );
      }

      isDownloading = false;
    }
  }

  Future<void> cancelUpdate(BuildContext context, {void Function(double progress)? update}) async {
    if (isDownloading && _cancelToken != null && _updateOperation != null) {
      _cancelToken!.cancel('Téléchargement annulé par l\'utilisateur');
      _updateOperation!.cancel();
      _cancelToken = null;
      _updateOperation = null;
      showBottomMessage(context, 'Téléchargement annulé');
    }
  }


  Future<void> remove(BuildContext context, {void Function(double progress)? update}) async {
    await removeJwpubFile(this);

    if(PubCatalog.datedPublications.any((element) => element.keySymbol == keySymbol)) {
      HomeView.setStateHomePage();
    }

    if (category.id == 1) {
      BibleView.refreshBibleView();
    }

    if (update != null) {
      update(downloadProgress);
    }

    showBottomMessage(context, 'Publication supprimée');
  }

  void showMenu(BuildContext context, {int? mepsLanguage, void Function(double progress)? update}) async {
    if(update != null) {
      if(isDownloaded) {
        showPage(context, PublicationMenuView(publication: this));
      }
      else {
        if(await hasInternetConnection()) {
          await download(context, update: update);
        }
        else {
          showNoConnectionDialog(context);
        }
      }
    }
    else {
      Publication pub = JwLifeApp.pubCollections.getPublication(this);
      if (pub.isDownloaded) {
        showPage(context, PublicationMenuView(publication: pub));
      }
      else {
        if(await hasInternetConnection()) {
          await showDownloadPublicationDialog(context, this);
          Publication pub = JwLifeApp.pubCollections.getPublication(this);
          if (pub.isDownloaded) {
            showPage(context, PublicationMenuView(publication: pub));
          }
        }
        else {
          showNoConnectionDialog(context);
        }
      }
    }
  }

  bool isBible() {
    return category.id == 1 || schemaVersion == 9;
  }

  bool hasUpdate(Publication pub) {
    if (lastModified == null || lastModified!.isEmpty || pub.timeStamp.isEmpty) {
      return false;
    }

    DateTime lastModDate = DateTime.parse(lastModified!);
    DateTime pubDate = DateTime.parse(pub.timeStamp);

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

      Publication publication = JwLifeApp.pubCollections.getPublication(this);
      return "${publication.mepsLanguage.vernacular} · $textToShow";
    } catch (e) {
      return "";
    }
  }
}