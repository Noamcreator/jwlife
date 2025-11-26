import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/app_data/alert_info_service.dart';
import 'package:jwlife/core/app_data/articles_service.dart';
import 'package:jwlife/core/app_data/meetings_pubs_service.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/meps_language.dart';

import '../../data/databases/mepsunit.dart';
import '../../data/models/publication.dart';
import '../../app/jwlife_app.dart';
import '../../data/models/publication_category.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../features/publication/pages/document/data/models/document.dart';
import '../../i18n/i18n.dart';
import '../utils/common_ui.dart';
import '../utils/files_helper.dart';
import '../utils/utils.dart';
import '../utils/utils_database.dart';
import 'daily_text_service.dart' show fetchVerseOfTheDay;

class AppDataService {
  AppDataService._();
  static final AppDataService instance = AppDataService._();

  // Home Page
  final isRefreshing = ValueNotifier<bool>(false);

  final alerts = ValueNotifier<List<dynamic>>([]);

  final dailyText = ValueNotifier<Publication?>(null);
  final dailyTextHtml = ValueNotifier<String>('');

  final articles = ValueNotifier<List<Map<String, dynamic>>>([]);
  final favorites = ValueNotifier<List<dynamic>>([]);
  final frequentlyUsed = ValueNotifier<List<Publication>>([]);
  final teachingToolboxMedias = ValueNotifier<List<Media>>([]);
  final teachingToolboxPublications = ValueNotifier<List<Publication?>>([]);
  final teachingToolboxTractsPublications = ValueNotifier<List<Publication?>>([]);
  final latestPublications = ValueNotifier<List<Publication>>([]);
  final latestMedias = ValueNotifier<List<Media>>([]);

  // Library Page
  final publicationsCategories = ValueNotifier<List<PublicationCategory>>([]);
  final videoCategories = ValueNotifier<Category?>(null);
  final audioCategories = ValueNotifier<Category?>(null);

  // Workship Page
  final midweekMeetingPub = ValueNotifier<Publication?>(null);
  final midweekMeeting = ValueNotifier<Map<String, dynamic>?>(null);
  final weekendMeetingPub = ValueNotifier<Publication?>(null);
  final weekendMeeting = ValueNotifier<Map<String, dynamic>?>(null);
  final publicTalkPub = ValueNotifier<Publication?>(null);
  final selectedPublicTalk = ValueNotifier<Document?>(null);

  final otherMeetingsPublications = ValueNotifier<List<Publication>>([]);

  final conventionPub = ValueNotifier<Publication?>(null);
  final circuitBrPub = ValueNotifier<Publication?>(null);
  final circuitCoPub = ValueNotifier<Publication?>(null);

  Future<void> refreshContent({bool first = false}) async {
    printTime("Refresh start");
    if (!await hasInternetConnection()) {
      showBottomMessage(i18n().message_no_internet_connection_title);
      return;
    }

    if (!first) {
      showBottomMessage(i18n().message_catalog_downloading);
    }

    // Lancer les vérifications en parallèle
    final results = await Future.wait([
      Api.isLibraryUpdateAvailable(),
      Api.isCatalogUpdateAvailable()
    ]);

    bool libraryUpdate = results[0];
    bool catalogUpdate = results[1];

    if (!catalogUpdate && !libraryUpdate) {
      if (!first) {
        showBottomMessage(i18n().message_catalog_up_to_date);
      }
      return;
    }

    showBottomMessage(i18n().label_update_available);

    isRefreshing.value = true;

    // Préparer les tâches de mise à jour
    final List<Future> updateTasks = [];

    if (libraryUpdate) {
      updateTasks.add(
        Api.updateLibrary(JwLifeSettings.instance.currentLanguage.value.symbol).then((_) {
          AppDataService.instance.teachingToolboxMedias.value = RealmLibrary.loadTeachingToolboxVideos();
          AppDataService.instance.latestMedias.value = RealmLibrary.loadLatestMedias();
          RealmLibrary.updateLibraryCategories();
        }),
      );
    }

    if (catalogUpdate) {
      updateTasks.add(
        Api.updateCatalog().then((_) async {
          await loadAllContentData(first: false, library: false);
        }),
      );
    }

    // Exécuter toutes les tâches en parallèle
    await Future.wait(updateTasks);

    isRefreshing.value = false;

    showBottomMessage(i18n().message_catalog_success);
  }

  Future<void> changeLanguageAndRefreshContent() async {
    printTime("Refresh change language start");
    loadAllContentData(language: JwLifeSettings.instance.currentLanguage.value, first: false);
  }

  // Chargement rapide et progressif pour HomePage
  Future<void> loadAllContentData({MepsLanguage? language, bool first = true, bool library = true}) async {
    MepsLanguage currentLanguage = language ?? JwLifeSettings.instance.currentLanguage.value;

    final database = CatalogDb.instance.database;
    final String publicationSelectQuery = CatalogDb.publicationSelectQuery;
    final String publicationQuery = CatalogDb.publicationQuery;

    fetchAlertsList(currentLanguage);
    fetchArticles(currentLanguage);

    if(first) {
      favorites.value = await JwLifeApp.userdata.fetchFavorites();
    }

    // On affiche la page principal !
    GlobalKeyService.jwLifeAppKey.currentState!.finishInitialized();

    refreshContent(first: language != null || first);

    final mepsFile = await getMepsUnitDatabaseFile();
    final historyFile = await getHistoryDatabaseFile();

    if (allFilesExist([mepsFile, historyFile])) {
      try {
        // ATTACH et requêtes dans la transaction
        await database.transaction((txn) async {
          await txn.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
          await txn.execute("ATTACH DATABASE '${historyFile.path}' AS history");

          String formattedDate = DateTime.now().toIso8601String().split('T').first;
          final languageId = currentLanguage.id;

          // Exécution des requêtes EN SÉRIE, pas en parallèle
          List<Map<String, Object?>> result1 = [];
          List<Map<String, Object?>> result2 = [];
          List<Map<String, Object?>> result3 = [];
          List<Map<String, Object?>> result4 = [];
          List<Map<String, Object?>> result5 = [];

          printTime('Start: Dated Publications');

          result1 = await txn.rawQuery('''
              SELECT DISTINCT
                $publicationSelectQuery
              FROM DatedText dt
              INNER JOIN Publication p ON dt.PublicationId = p.Id
              INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
            ''', [formattedDate, languageId]);

          for(Publication pub in result1.map((item) => Publication.fromJson(item)).toList()) {
            if (pub.keySymbol.contains('es')) {
              AppDataService.instance.dailyText.value = pub;
              fetchVerseOfTheDay();
            }
            else if (pub.keySymbol.contains('mwb')) {
              AppDataService.instance.midweekMeetingPub.value = pub;
            }
            else if (pub.keySymbol.contains(RegExp(r'(?<!m)w'))) {
              AppDataService.instance.weekendMeetingPub.value = pub;
            }
          }

          printTime('End: Dated Publications');

          if(first) {
            printTime('Start: Recent Publications');
            result2 = await txn.rawQuery('''
              SELECT DISTINCT
                SUM(hp.VisitCount) AS TotalVisits,
                $publicationSelectQuery
              FROM history.History hp
              INNER JOIN Publication p ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
              INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              GROUP BY p.KeySymbol, p.IssueTagNumber, p.MepsLanguageId
              ORDER BY TotalVisits DESC
              LIMIT 10;
            ''');

            AppDataService.instance.frequentlyUsed.value = result2.map((item) => Publication.fromJson(item)).toList();
            printTime('End: Recent Publications');
          }

          printTime('Start: ToolBox Pubs');
          result4 = await txn.rawQuery('''
              SELECT DISTINCT
                ca.SortOrder,
                $publicationSelectQuery
              FROM CuratedAsset ca
              INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
              INNER JOIN Publication p ON pa.PublicationId = p.Id
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
              ORDER BY ca.SortOrder;
            ''', [languageId, 2]);

          if (result4.isNotEmpty) {
            List<Publication?> teachingToolboxPublications = [];
            List<Publication?> teachingToolboxTractsPublications = [];

            List<int> availableTeachingToolBoxInt = [-1, 5, 8, -1, 9, -1, 15, 16, 17];
            List<int> availableTeachingToolBoxTractsInt = [18, 19, 20, 21, 22, 23, 24, 25, 26];
            for (int i = 0; i < availableTeachingToolBoxInt.length; i++) {
              if (availableTeachingToolBoxInt[i] == -1) {
                teachingToolboxPublications.add(null);
              }
              else if (result4.any((e) => e['SortOrder'] == availableTeachingToolBoxInt[i])) {
                final pub = result4.firstWhereOrNull((e) => e['SortOrder'] == availableTeachingToolBoxInt[i]);
                if (pub != null) {
                  teachingToolboxPublications.add(Publication.fromJson(pub));
                }
              }
            }
            for (int i = 0; i < availableTeachingToolBoxTractsInt.length; i++) {
              if (availableTeachingToolBoxTractsInt[i] == -1) {
                teachingToolboxTractsPublications.add(null);
              }
              else if (result4.any((e) => e['SortOrder'] == availableTeachingToolBoxTractsInt[i])) {
                final pub = result4.firstWhereOrNull((e) => e['SortOrder'] == availableTeachingToolBoxTractsInt[i]);
                if (pub != null) {
                  teachingToolboxTractsPublications.add(Publication.fromJson(pub));
                }
              }
            }

            if(library) {
              AppDataService.instance.teachingToolboxMedias.value = RealmLibrary.loadTeachingToolboxVideos();
            }
            AppDataService.instance.teachingToolboxPublications.value = teachingToolboxPublications;
            AppDataService.instance.teachingToolboxTractsPublications.value = teachingToolboxTractsPublications;
          }

          printTime('End: ToolBox Pubs');

          printTime('Start: Latest Publications');
          result3 = await txn.rawQuery('''
              SELECT DISTINCT
                $publicationQuery
              WHERE p.MepsLanguageId = ?
              ORDER BY pa.CatalogedOn DESC
              LIMIT ?
            ''', [languageId, 12]);

          AppDataService.instance.latestPublications.value = result3.map((item) => Publication.fromJson(item)).toList();
          printTime('End: Latest Publications');

          if(library) {
            AppDataService.instance.latestMedias.value = RealmLibrary.loadLatestMedias();
          }

          result5 = await txn.rawQuery('''
              SELECT DISTINCT
                ca.SortOrder,
                $publicationSelectQuery
              FROM CuratedAsset ca
              INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
              INNER JOIN Publication p ON pa.PublicationId = p.Id
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
              ORDER BY ca.SortOrder;
            ''', [languageId, 0]);

          AppDataService.instance.otherMeetingsPublications.value = result5.map((pub) => Publication.fromJson(pub)).toList();

          await txn.execute("DETACH DATABASE meps");
          await txn.execute("DETACH DATABASE history");
        });
      }
      catch (e) {
        printTime('Error loading PublicationsInHomePage: $e');
      }

      GlobalKeyService.jwLifePageKey.currentState!.loadAllNavigator();

      CatalogDb.instance.updateCatalogCategories();
      RealmLibrary.updateLibraryCategories();

      await refreshMeetingsPubs();
      refreshPublicTalks();

      await Mepsunit.loadBibleCluesInfo();

      CatalogDb.instance.fetchAssemblyPublications();

      currentLanguage.loadWolInfo();
    }
    else {
      printTime('Catalog file does not exist');
    }
  }
}
