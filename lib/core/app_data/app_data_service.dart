import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/app_data/alert_info_service.dart';
import 'package:jwlife/core/app_data/articles_service.dart';
import 'package:jwlife/core/app_data/meetings_pubs_service.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../app/startup/auto_update.dart';
import '../../data/databases/mepsunit.dart';
import '../../data/models/publication.dart';
import '../../app/jwlife_app.dart';
import '../../data/models/publication_category.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../features/document/data/models/document.dart';
import '../../i18n/i18n.dart';
import '../utils/assets_downloader.dart';
import '../utils/common_ui.dart';
import '../utils/files_helper.dart';
import '../utils/utils.dart';
import 'daily_text_service.dart';

class AppDataService {
  AppDataService._();
  static final AppDataService instance = AppDataService._();

  // Home Page
  final isRefreshing = ValueNotifier<bool>(false);

  final alerts = ValueNotifier<List<dynamic>>([]);

  final dailyTextPublication = ValueNotifier<Publication?>(null);
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
  final videoCategories = ValueNotifier<RealmCategory?>(null);
  final audioCategories = ValueNotifier<RealmCategory?>(null);

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

  Future<void> checkUpdatesAndRefreshContent(BuildContext? context, {bool isFirst = false, String type = 'all'}) async {
    if (!await hasInternetConnection(context: context)) {
      if(context == null) {
        showBottomMessage(i18n().message_no_internet_connection_title);
      }
      return;
    }

    printTime("Refresh start");

    final settings = JwLifeSettings.instance;
    // Sélection de la langue basée sur le type
    MepsLanguage language;
    if (type == 'toolbox') {
      language = settings.teachingToolboxLanguage.value;
    }
    else if (type == 'latest') {
      language = settings.latestLanguage.value;
    }
    else {
      language = settings.libraryLanguage.value;
    }

    if (!isFirst) showBottomMessage(i18n().message_catalog_downloading);

    // 1. Définition propre des conditions
    final bool checkLibrary = ['all', 'library', 'toolbox', 'latest'].contains(type);
    final bool checkCatalog = ['all', 'workship', 'toolbox', 'latest'].contains(type);

    // 2. Récupération sécurisée des résultats
    bool libraryUpdate = false;
    bool catalogUpdate = false;

    try {
      final results = await Future.wait([
        if (checkLibrary) Api.isLibraryUpdateAvailable(language.symbol),
        if (checkCatalog) Api.isCatalogUpdateAvailable(),
      ]);

      // Extraction sécurisée selon ce qui a été ajouté à la liste
      int index = 0;
      if (checkLibrary) libraryUpdate = results[index++];
      if (checkCatalog) catalogUpdate = results[index++];

      if (!catalogUpdate && !libraryUpdate) {
        if (!isFirst) showBottomMessage(i18n().message_catalog_up_to_date);
        return;
      }

      if (!isFirst) showBottomMessage(i18n().label_update_available);

      isRefreshing.value = true;

      final List<Future> updateTasks = [];

      if (libraryUpdate) {
        updateTasks.add(Api.updateLibrary(language.symbol).then((_) {
          // Rechargement des données après mise à jour
          AppDataService.instance.teachingToolboxMedias.value = RealmLibrary.loadTeachingToolboxVideos(settings.teachingToolboxLanguage.value);
          AppDataService.instance.latestMedias.value = RealmLibrary.loadLatestMedias(settings.latestLanguage.value);
          RealmLibrary.updateLibraryCategories(settings.libraryLanguage.value);
        }));
      }

      if (catalogUpdate) {
        updateTasks.add(Api.updateCatalog().then((_) => loadAllContentData(isFirst: false, library: false)));
      }

      await Future.wait(updateTasks);
      showBottomMessage(i18n().message_catalog_success);

    }
    catch (e) {
      print("Error during update: $e");
    }
    finally {
      isRefreshing.value = false;
    }
  }

  Future<void> changeLanguageAndRefreshContent() async {
    printTime("Refresh change language start");
    loadAllContentData(isFirst: false);
  }

  Future<void> changeLibraryLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'library');
  }

  Future<void> changeDailyTextLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'dailyText');
  }

  Future<void> changeArticlesLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'articles');
  }

  Future<void> changeWorkshipLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'workship');
  }

  Future<void> changeTeachingToolboxLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'toolbox');
  }

  Future<void> changeLatestLanguageAndRefresh() async {
    loadAllContentData(isFirst: false, type: 'latest');
  }

  // Chargement rapide et progressif pour HomePage
  Future<void> loadAllContentData({bool isFirst = true, bool library = true, type = 'all'}) async {
    MepsLanguage libraryLanguage = JwLifeSettings.instance.libraryLanguage.value;
    MepsLanguage dailyTextLanguage = JwLifeSettings.instance.dailyTextLanguage.value;
    MepsLanguage articlesLanguage = JwLifeSettings.instance.articlesLanguage.value;
    MepsLanguage workshipLanguage = JwLifeSettings.instance.workshipLanguage.value;
    MepsLanguage teachingToolboxLanguage = JwLifeSettings.instance.teachingToolboxLanguage.value;
    MepsLanguage latestLanguage = JwLifeSettings.instance.latestLanguage.value;

    AppLocalizations appLocalizations = (await i18nLocale(JwLifeSettings.instance.locale));

    if(isFirst) {
      fetchAlertsList(appLocalizations.meps_language);
    }

    if(type == 'all' || type == 'articles') {
      fetchArticles(articlesLanguage);
    }

    final String publicationSelectQuery = CatalogDb.publicationSelectQuery;
    final String publicationQuery = CatalogDb.publicationQuery;

    final String publicationMepsSelectQuery = CatalogDb.publicationMepsSelectQuery;

    final mepsFile = await getMepsUnitDatabaseFile();

    final catalogFile = await getCatalogDatabaseFile();
    bool isCatalogFileExist = catalogFile.existsSync();

    final historyFile = await getHistoryDatabaseFile();
    bool isHistoryFileExist = historyFile.existsSync();

    await CatalogDb.instance.init(catalogFile);

    if(isFirst) {
      favorites.value = await JwLifeApp.userdata.fetchFavorites();
    }

    if (isCatalogFileExist) {
      late Database database = CatalogDb.instance.database;

      try {
        await database.transaction((txn) async {
          String formattedDate = DateTime.now().toIso8601String().split('T').first;

          // Exécution des requêtes EN SÉRIE, pas en parallèle
          List<Map<String, Object?>> result1 = [];
          List<Map<String, Object?>> result2 = [];
          List<Map<String, Object?>> result3 = [];
          List<Map<String, Object?>> result4 = [];
          List<Map<String, Object?>> result5 = [];

          printTime('Start: Dated Publications');

          if (type == 'all' || type == 'dailyText' || type == 'workship') {
            final dailyTextLangId = dailyTextLanguage.id;
            final workshipLangId = workshipLanguage.id;

            // 1. Construction dynamique des conditions SQL
            List<String> conditions = [];
            List<dynamic> params = [formattedDate];

            if (type == 'all' || type == 'dailyText') {
              conditions.add('(p.MepsLanguageId = ? AND p.KeySymbol LIKE "%es%")');
              params.add(dailyTextLangId);
            }

            if (type == 'all' || type == 'workship') {
              conditions.add('(p.MepsLanguageId = ? AND (p.KeySymbol LIKE "%mwb%" OR p.KeySymbol REGEXP "(?<!m)w"))');
              params.add(workshipLangId);
            }

            // On joint les conditions par un OR
            String filterQuery = conditions.join(' OR ');

            result1 = await txn.rawQuery('''
              SELECT DISTINCT $publicationSelectQuery
              FROM DatedText dt
              INNER JOIN Publication p ON dt.PublicationId = p.Id
              INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE ? BETWEEN dt.Start AND dt.End 
              AND ($filterQuery)
            ''', params);

            // 2. Réinitialisation ciblée
            if (type == 'all' || type == 'dailyText') {
              AppDataService.instance.dailyTextPublication.value = null;
            }
            if (type == 'all' || type == 'workship') {
              AppDataService.instance.midweekMeetingPub.value = null;
              AppDataService.instance.weekendMeetingPub.value = null;
            }

            // 3. Attribution des résultats
            for (Map<String, dynamic> pubMap in result1) {
              final String keySymbol = pubMap['KeySymbol'] ?? '';

              if (keySymbol.contains('es') && (type == 'all' || type == 'dailyText')) {
                Publication pub = Publication.fromJson(pubMap, language: dailyTextLanguage);
                AppDataService.instance.dailyTextPublication.value = pub;
                fetchVerseOfTheDay(pub);
              }
              else if (keySymbol.contains('mwb') && (type == 'all' || type == 'workship')) {
                AppDataService.instance.midweekMeetingPub.value = Publication.fromJson(pubMap, language: workshipLanguage);
              }
              else if (keySymbol.contains(RegExp(r'(?<!m)w')) && (type == 'all' || type == 'workship')) {
                AppDataService.instance.weekendMeetingPub.value = Publication.fromJson(pubMap, language: workshipLanguage);
              }
            }
          }

          if(isFirst) {
            // On affiche la page principal !
            GlobalKeyService.jwLifeAppKey.currentState!.finishInitialized();
          }

          printTime('End: Dated Publications');

          if(isFirst) {
            printTime('Start: Frequently Used Publications');
            await attachTransaction(txn, {'meps': mepsFile.path});

            if(isHistoryFileExist) {
              await attachTransaction(txn, {'history': historyFile.path});
            }

            if(isFirst && isHistoryFileExist) {
              result2 = await txn.rawQuery('''
                SELECT DISTINCT
                  SUM(hp.VisitCount) AS TotalVisits,
                  $publicationMepsSelectQuery
                FROM history.History hp
                INNER JOIN Publication p ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
                INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
                INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
                INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
                LEFT JOIN meps.Language AS fallback ON meps.Language.PrimaryFallbackLanguageId = fallback.LanguageId
                LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
                GROUP BY p.KeySymbol, p.IssueTagNumber, p.MepsLanguageId
                ORDER BY TotalVisits DESC
                LIMIT 10;
              ''');

              AppDataService.instance.frequentlyUsed.value = result2.map((item) => Publication.fromJson(item)).toList();
            }

            await detachTransaction(txn, ['meps']);

            if(isHistoryFileExist) {
              await detachTransaction(txn, ['history']);
            }

            printTime('End: Frequently Used Publications');
          }

          if(type == 'all' || type == 'toolbox') {
            printTime('Start: ToolBox Pubs');
            result4 = await txn.rawQuery('''
              SELECT DISTINCT
                ca.SortOrder,
                $publicationSelectQuery
              FROM CuratedAsset ca
              INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
              INNER JOIN Publication p ON pa.PublicationId = p.Id
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
              ORDER BY ca.SortOrder;
            ''', [teachingToolboxLanguage.id, 2]);

            List<Publication?> teachingToolboxPublications = [];
            List<Publication?> teachingToolboxTractsPublications = [];
            if (result4.isNotEmpty) {
                List<int> availableTeachingToolBoxInt = [-1, 5, 8, -1, 9, -1, 15, 16, 17];
                List<int> availableTeachingToolBoxTractsInt = [18, 19, 20, 21, 22, 23, 24, 25, 26];

                // 1. Remplissage de la liste principale
                for (int i = 0; i < availableTeachingToolBoxInt.length; i++) {
                  if (availableTeachingToolBoxInt[i] == -1) {
                    teachingToolboxPublications.add(null);
                  } else {
                    final pub = result4.firstWhereOrNull((e) => e['SortOrder'] == availableTeachingToolBoxInt[i]);
                    if (pub != null) {
                      teachingToolboxPublications.add(Publication.fromJson(pub, language: teachingToolboxLanguage));
                    }
                  }
                }

                // 2. Remplissage des tracts
                for (int i = 0; i < availableTeachingToolBoxTractsInt.length; i++) {
                  if (availableTeachingToolBoxTractsInt[i] == -1) {
                    teachingToolboxTractsPublications.add(null);
                  } else {
                    final pub = result4.firstWhereOrNull((e) => e['SortOrder'] == availableTeachingToolBoxTractsInt[i]);
                    if (pub != null) {
                      teachingToolboxTractsPublications.add(Publication.fromJson(pub, language: teachingToolboxLanguage));
                    }
                  }
                }

                // --- LA CORRECTION : Supprimer les null inutiles à la fin ---
                while (teachingToolboxPublications.isNotEmpty && teachingToolboxPublications.last == null) {
                  teachingToolboxPublications.removeLast();
                }
                while (teachingToolboxTractsPublications.isNotEmpty && teachingToolboxTractsPublications.last == null) {
                  teachingToolboxTractsPublications.removeLast();
                }
              }
              if(library) {
                AppDataService.instance.teachingToolboxMedias.value = RealmLibrary.loadTeachingToolboxVideos(teachingToolboxLanguage);
              }
                // Mise à jour de tes ValueNotifiers
              this.teachingToolboxPublications.value = teachingToolboxPublications;
              this.teachingToolboxTractsPublications.value = teachingToolboxTractsPublications;

            printTime('End: ToolBox Pubs');
          }

          if(type == 'all' || type == 'latest') {
            printTime('Start: Latest Publications');
            result3 = await txn.rawQuery('''
              SELECT
                $publicationQuery
              WHERE p.MepsLanguageId = ?
                AND p.Year >= strftime('%Y', 'now', '-2 year')
                AND (
                  pa.CatalogedOn >= date('now', '-50 days')
                  OR pa.GenerallyAvailableDate >= date('now', '-50 days')
                )
              ORDER BY
                COALESCE(pa.GenerallyAvailableDate, pa.CatalogedOn) DESC;
            ''', [latestLanguage.id]);

            AppDataService.instance.latestPublications.value = result3.map((item) => Publication.fromJson(item, language: latestLanguage)).toList();
            printTime('End: Latest Publications');

            if (library) {
              AppDataService.instance.latestMedias.value = RealmLibrary.loadLatestMedias(latestLanguage);
            }
          }

          if (type == 'all' || type == 'workship') {
            result5 = await txn.rawQuery('''
                SELECT DISTINCT
                  ca.SortOrder,
                  $publicationSelectQuery
                FROM CuratedAsset ca
                INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
                INNER JOIN Publication p ON pa.PublicationId = p.Id
                LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
                WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
                ORDER BY ca.SortOrder;
              ''', [workshipLanguage.id, 0]);

            AppDataService.instance.otherMeetingsPublications.value = result5.map((pub) => Publication.fromJson(pub, language: workshipLanguage)).toList();
          }
        });
      }
      catch (e) {
        printTime('Error loading PublicationsInHomePage: $e');
      }
    }
    else {
      GlobalKeyService.jwLifeAppKey.currentState!.finishInitialized();
    }

    if(isCatalogFileExist) {
      if(type == 'all' || type == 'library') {
        RealmLibrary.updateLibraryCategories(libraryLanguage);
      }

      await Future.wait([
        if (type == 'all' || type == 'library') CatalogDb.instance.updateCatalogCategories(libraryLanguage),

        if (type == 'all' || type == 'workship') refreshMeetingsPubs(pubs: [
          if (midweekMeetingPub.value != null) midweekMeetingPub.value!,
          if (weekendMeetingPub.value != null) weekendMeetingPub.value!,
        ]),

        if (type == 'all' || type == 'workship') CatalogDb.instance.fetchAssemblyPublications(workshipLanguage),
      ]);
      if (type == 'all' || type == 'workship') refreshPublicTalks();
    }

    if(library && type != 'articles' && type != 'dailyText') {
      checkUpdatesAndRefreshContent(null, isFirst: true, type: type);
    }

    if(type == 'library') {
      await libraryLanguage.loadWolInfo();
    }


    if(isFirst) {
      await Mepsunit.loadBibleCluesInfo(appLocalizations.meps_language);

      final isConnected = await hasInternetConnection();
      if (isConnected) {
        Future.wait([
          JwLifeAutoUpdater.checkAndUpdate(),
          AssetsDownload.download(),
        ]);
      }
    }
  }
}
