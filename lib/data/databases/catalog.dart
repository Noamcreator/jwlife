import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../realm/catalog.dart';
import '../models/publication_category.dart';
import '../repositories/PublicationRepository.dart';

class PubCatalog {
  /// Liste des dernières publications chargées.
  static List<Publication> datedPublications = [];
  static List<Publication?> teachingToolboxPublications = [];
  static List<Publication?> teachingToolboxTractsPublications = [];
  static List<Publication> recentPublications = [];
  static List<Publication> latestPublications = [];
  static List<Publication> otherMeetingsPublications = [];
  static List<Publication> assembliesPublications = [];

  /*
  (
      SELECT ia2.NameFragment
      FROM ImageAsset ia2
      INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
      WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_lsr-%'
      ORDER BY ia2.Width DESC, ia2.Height DESC
      LIMIT 1
    ) AS ImageLsr
  */

  /// Requête SQL pour récupérer les publications et leurs métadonnées.
  static final String publicationSelectQuery = '''
    p.*,
    meps.Language.Symbol AS LanguageSymbol, 
    meps.Language.VernacularName AS LanguageVernacularName, 
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
    meps.Language.IsSignLanguage AS IsSignLanguage,
    pa.LastModified, 
    pa.CatalogedOn,
    pa.Size,
    pa.ExpandedSize,
    pa.SchemaVersion,
    pam.PublicationAttributeId,
    (SELECT ia.NameFragment 
     FROM PublicationAssetImageMap paim 
     JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
     WHERE paim.PublicationAssetId = pa.Id AND ((ia.Width = 270 AND ia.Height = 270) OR (ia.Width = 100 AND ia.Height = 100))
     LIMIT 1) AS ImageSqr
  ''';

  static final String publicationQuery = '''
    $publicationSelectQuery
    FROM Publication p
    INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
    INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
    LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
  ''';

  static Future<Map<String, dynamic>?> getDatedDocumentForToday(Publication publication) async {
    Database datedDocumentDb = await openReadOnlyDatabase(publication.databasePath!);

    String today = DateFormat('yyyyMMdd').format(DateTime.now());

    List<Map<String, dynamic>> response = await datedDocumentDb.rawQuery('''
      SELECT Content
      FROM DatedText
      WHERE FirstDateOffset <= ? AND LastDateOffset >= ?
    ''', [today, today]);

    datedDocumentDb.close();

    return response.first;
  }

  static Future<List<PublicationCategory>> updateCatalogCategories() async {
    printTime('On met à jour les catégories pour voir si le catalogue contient des nouvelles publications...');
    // Charger le fichier de catalogue et ouvrir la base de données
    final catalogFile = await getCatalogDatabaseFile();

    if (allFilesExist([catalogFile])) {
      Database catalogDB = await openReadOnlyDatabase(catalogFile.path);

      try {
        // Récupérer les catégories distinctes de publication de la base de données pour la langue actuelle
        List<Map<String, dynamic>> result1 = await catalogDB.rawQuery('''
          SELECT DISTINCT 
            PublicationTypeId AS id
          FROM Publication
          WHERE MepsLanguageId = ?
        ''', [JwLifeSettings().currentLanguage.id]);

        List<Map<String, dynamic>> hasPubForConventionDay = await catalogDB.rawQuery('''
          SELECT EXISTS (
              SELECT 1
              FROM PublicationAsset
              WHERE ConventionReleaseDayNumber IS NOT NULL
                AND MepsLanguageId = ?
          ) AS HasConventionReleaseDayNumber;
        ''', [JwLifeSettings().currentLanguage.id]);

        final hasConvDay = RealmLibrary.realm.all<Category>().query("language == '${JwLifeSettings().currentLanguage.symbol}'").query("key == 'ConvDay1' OR key == 'ConvDay2' OR key == 'ConvDay3'");

        // Convertir les résultats SQL en un Set pour une recherche rapide
        Set<int> existingIds = result1.map((e) => e['id'] as int).toSet();

        // Récupérer les publications en fonction de la langue actuelle
        List<Publication> publications = PublicationRepository().getPublicationsFromLanguage(JwLifeSettings().currentLanguage);

        // Extraire les IDs des catégories existantes dans les publications
        Set<int> existingTypes = publications.map((e) => e.category.id).toSet();

        // Conserver uniquement les catégories existantes tout en respectant l'ordre
        List<PublicationCategory> matchedCategories = PublicationCategory.all.where((cat) {
          // Vérifier si l'ID de la catégorie correspond à l'un des ID existants
          return existingIds.contains(cat.id) || existingTypes.contains(cat.id);
        }).toList();

        if(hasPubForConventionDay.first['HasConventionReleaseDayNumber'] != 0 || hasConvDay.isNotEmpty) {
          matchedCategories.add(PublicationCategory.all.firstWhere((cat) => cat.type == 'Convention'));
        }

        GlobalKeyService.libraryKey.currentState?.refreshCatalogCategories(matchedCategories);

        printTime('Catégories mis à jour dans LibraryView');

        // Mettre à jour l'état avec les catégories correspondantes
        return matchedCategories;
      }
      catch (e) {
        // Gérer les erreurs (par exemple si la base de données est inaccessible)
        printTime("Erreur lors de la récupération des catégories : $e");
      }
    }
    return [];
  }

  static Future<void> loadPublicationsInHomePage() async {
    printTime('load PublicationsInHomePage');
    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();
    final historyFile = await getHistoryDatabaseFile();

    if (allFilesExist([mepsFile, historyFile, catalogFile])) {
      final catalogDB = await openReadOnlyDatabase(catalogFile.path);

      try {
        // ATTACH et requêtes dans la transaction
        await catalogDB.transaction((txn) async {
          await txn.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
          await txn.execute("ATTACH DATABASE '${historyFile.path}' AS history");

          String formattedDate = DateTime.now().toIso8601String().split('T').first;
          final languageId = JwLifeSettings().currentLanguage.id;

          // Exécution des requêtes EN SÉRIE, pas en parallèle
          List<Map<String, Object?>> result1 = [];
          List<Map<String, Object?>> result2 = [];
          List<Map<String, Object?>> result3 = [];
          List<Map<String, Object?>> result4 = [];

          result1 = await txn.rawQuery('''
              SELECT DISTINCT
                $publicationSelectQuery
              FROM DatedText dt
              INNER JOIN Publication p ON dt.PublicationId = p.Id
              INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
            ''', [formattedDate, languageId]);

          datedPublications = result1.map((item) => Publication.fromJson(item)).toList();

          result2 = await txn.rawQuery('''
              SELECT DISTINCT
                SUM(hp.VisitCount) AS TotalVisits,
                $publicationSelectQuery
              FROM history.History hp
              INNER JOIN Publication p ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
              INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              GROUP BY p.KeySymbol, p.IssueTagNumber, p.MepsLanguageId
              ORDER BY TotalVisits DESC
              LIMIT 10;
            ''');

          recentPublications = result2.map((item) => Publication.fromJson(item)).toList();

          result3 = await txn.rawQuery('''
              SELECT DISTINCT
                $publicationQuery
              WHERE p.MepsLanguageId = ?
              ORDER BY pa.CatalogedOn DESC
              LIMIT ?
            ''', [languageId, 12]);

          latestPublications = result3.map((item) => Publication.fromJson(item)).toList();

          result4 = await txn.rawQuery('''
              SELECT DISTINCT
                ca.SortOrder,
                $publicationSelectQuery
              FROM CuratedAsset ca
              INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
              INNER JOIN Publication p ON pa.PublicationId = p.Id
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
              ORDER BY ca.SortOrder;
            ''', [languageId, 2]);

          if (result4.isNotEmpty) {
            teachingToolboxPublications = [];
            teachingToolboxTractsPublications = [];
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
          }

          await txn.execute("DETACH DATABASE meps");
          await txn.execute("DETACH DATABASE history");
        });
      }
      catch (e) {
        printTime('Error loading PublicationsInHomePage: $e');
      }
      finally {
        await catalogDB.close();
      }
    }
    else {
      printTime('Catalog file does not exist');
    }

    printTime('loadHomePage end');
  }

  static Future<List<Publication>> getPublicationsForTheDay({DateTime? date}) async {
    // Obtenez la date du jour au format AAAA-mm-jj
    String formattedDate = '';
    date ??= DateTime.now();
    formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      await attachDatabases(catalog, {'meps': mepsFile.path});

      try {
        final result = await catalog.rawQuery('''
          SELECT DISTINCT
            $publicationSelectQuery
          FROM DatedText dt
          INNER JOIN Publication p ON dt.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
        ''', [formattedDate, JwLifeSettings().currentLanguage.id]);

        await detachDatabases(catalog, ['meps']);

        return result.map((e) => Publication.fromJson(e)).toList();
      }
      finally {
        await catalog.close();
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllAvailableBibleBookFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogDatabaseFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT Book
      FROM AvailableBibleBook
      INNER JOIN Publication ON AvailableBibleBook.PublicationId = Publication.Id
      WHERE Publication.MepsLanguageId = ? AND Publication.Symbol = ? AND Publication.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  /// Rechercher une publication par symbole et la date d'issue.
  static Future<Publication?> searchPub(String pubSymbol, int issueTagNumber, dynamic language) async {
    if (language is String) {
      Publication? pub = PublicationRepository().getPublicationWithSymbol(pubSymbol, issueTagNumber, language);
      if (pub != null) return pub;
    }
    else {
      Publication? pub = PublicationRepository().getPublicationWithMepsLanguageId(pubSymbol, issueTagNumber, language);
      if (pub != null) return pub;
    }

    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      String languageRequest = '';
      if (language is String) {
        languageRequest = 'WHERE meps.Language.Symbol = ?';
      }
      else {
        languageRequest = 'WHERE pa.MepsLanguageId = ?';
      }

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        printTime('pubSymbol: $pubSymbol');
        printTime('issueTagNumber: $issueTagNumber');
        printTime('language: $language');

        final publications = await catalog.rawQuery('''
          SELECT
            $publicationQuery
          $languageRequest 
          AND LOWER(p.KeySymbol) = LOWER(?) 
          AND p.IssueTagNumber = ?
          LIMIT 1
        ''', [language, pubSymbol, issueTagNumber]);

        printTime('searchPub: ${publications.length}');

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
    return null;
  }

  static Future<Publication?> searchPubNoMepsLanguage(String pubSymbol, int issueTagNumber, int mepsLanguageId) async {
    final catalogFile = await getCatalogDatabaseFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        final publications = await catalog.rawQuery('''
          SELECT DISTINCT
           p.*,
           pa.LastModified, 
           pa.CatalogedOn,
           pa.Size,
           pa.ExpandedSize,
           pa.SchemaVersion,
           pam.PublicationAttributeId,
           (SELECT ia.NameFragment 
            FROM PublicationAssetImageMap paim 
            JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
            WHERE paim.PublicationAssetId = pa.Id  AND (ia.Width = 270 AND ia.Height = 270)
            LIMIT 1) AS ImageSqr
          FROM Publication p
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE p.MepsLanguageId = ? AND LOWER(p.KeySymbol) = LOWER(?)  AND p.IssueTagNumber = ?
          LIMIT 1
          ''', [mepsLanguageId, pubSymbol, issueTagNumber]);

        printTime('searchPub: ${publications.length}');

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await catalog.close();
      }
    }
    return null;
  }

  /// Rechercher une publication par mepsDocumentId et la langue.
  static Future<Publication?> searchPubFromMepsDocumentId(int mepsDocumentId, int mepsLanguageId) async {
    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        final publications = await catalog.rawQuery('''
          SELECT DISTINCT
            $publicationSelectQuery
          FROM PublicationDocument pd
          INNER JOIN Publication p ON pd.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE pd.DocumentId = ? AND p.MepsLanguageId = ?
          LIMIT 1
        ''', [mepsDocumentId, mepsLanguageId]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
    return null;
  }

  /// Charge les publications d'une catégorie
  static Future<Map<PublicationAttribute, List<Publication>>> getPublicationsFromCategory(int category, {int? year, int? mepsLanguageId}) async {
    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    if (!allFilesExist([catalogFile, mepsFile])) {
      return {};
    }

    final catalog = await openReadOnlyDatabase(catalogFile.path);

    try {
      await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

      // Paramètres dynamiques
      final queryParams = <dynamic>[
        mepsLanguageId ?? JwLifeSettings().currentLanguage.id,
        category,
      ];

      // Condition sur l'année
      String yearCondition = '';
      if (year != null) {
        yearCondition = 'AND p.Year = ?';
        queryParams.add(year);
      }

      // Requête SQL
      final result = await catalog.rawQuery('''
      SELECT DISTINCT
        p.*,
        pa.LastModified, 
        pa.CatalogedOn,
        pa.Size,
        pa.ExpandedSize,
        pa.SchemaVersion,
        pam.PublicationAttributeId,
        meps.Language.Symbol AS LanguageSymbol, 
        meps.Language.VernacularName AS LanguageVernacularName, 
        meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
        meps.Language.IsSignLanguage AS IsSignLanguage,
        (
          SELECT ia.NameFragment 
          FROM PublicationAssetImageMap paim 
          JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
          WHERE paim.PublicationAssetId = pa.Id
            AND ((ia.Width = 270 AND ia.Height = 270) OR (ia.Width = 100 AND ia.Height = 100))
          LIMIT 1
        ) AS ImageSqr
      FROM Publication p
      INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
      LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
      LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
      WHERE p.MepsLanguageId = ? 
        AND p.PublicationTypeId = ?
        $yearCondition
      ORDER BY p.Id;
    ''', queryParams);

      // Groupement par attribut
      final Map<PublicationAttribute, List<Publication>> groupedByCategory = {};
      for (final publication in result) {
        final pub = Publication.fromJson(publication);
        groupedByCategory.putIfAbsent(pub.attribute, () => []).add(pub);
      }

      return groupedByCategory;
    }
    finally {
      await catalog.execute("DETACH DATABASE meps");
      await catalog.close();
    }
  }

  static Future<void> fetchOtherMeetingsPubs() async {
    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      await attachDatabases(catalog, {'meps': mepsFile.path});

      final languageId = JwLifeSettings().currentLanguage.id;

      otherMeetingsPublications.clear();

      try {
        final results = await catalog.rawQuery('''
              SELECT DISTINCT
                ca.SortOrder,
                $publicationSelectQuery
              FROM CuratedAsset ca
              INNER JOIN PublicationAsset pa ON ca.PublicationAssetId = pa.Id
              INNER JOIN Publication p ON pa.PublicationId = p.Id
              INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
              LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
              WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
              ORDER BY ca.SortOrder;
            ''', [languageId, 0]);

        otherMeetingsPublications = results.map((pub) => Publication.fromJson(pub)).toList();
      }
      finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
  }

  static Future<void> fetchAssemblyPublications() async {
    final catalogFile = await getCatalogDatabaseFile();
    final mepsFile = await getMepsUnitDatabaseFile();

    assembliesPublications.clear();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        final langId = JwLifeSettings().currentLanguage.id;

        // Récupération de toutes les publications d'assemblée de circonscription
        final allCircuitAssemblies = await catalog.rawQuery('''
          SELECT
            $publicationSelectQuery
          FROM Publication p
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE p.MepsLanguageId = ? AND (p.KeySymbol LIKE 'CA-copgm%' OR p.KeySymbol LIKE 'CA-brpgm%')
      ''', [langId]);

        // Groupement et tri en Dart pour émuler ROW_NUMBER()
        final Map<String, List<Map<String, Object?>>> grouped = {};
        for (var pub in allCircuitAssemblies) {
          final keySymbol = pub['KeySymbol']?.toString() ?? '';
          final groupKey = keySymbol.startsWith('CA-copgm')
              ? 'CA-copgm'
              : keySymbol.startsWith('CA-brpgm')
              ? 'CA-brpgm'
              : 'other';
          grouped.putIfAbsent(groupKey, () => []).add(pub);
        }

        final circuitAssemblies = grouped.entries
            .map((entry) => entry.value
          ..sort((a, b) => (b['Year'] as int).compareTo(a['Year'] as int)))
            .map((sortedList) => sortedList.first)
            .toList();

        // Dernière publication d’assemblée régionale
        final convention = await catalog.rawQuery('''
        SELECT
          $publicationQuery
        WHERE p.MepsLanguageId = ? AND p.KeySymbol LIKE 'CO-pgm%'
        ORDER BY p.Year DESC
        LIMIT 1;
      ''', [langId]);

        // Fusion et transformation en objets Publication
        for (var publication in [...circuitAssemblies, ...convention]) {
          final pub = Publication.fromJson(publication);
          assembliesPublications.add(pub);
        }
      }
      finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
  }

  /// Rechercher les publications des assemblées régionales
  static Future<List<Publication>> fetchPubsFromConventionsDays() async {
    final catalogFile = await getCatalogDatabaseFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        final publications = await catalog.rawQuery('''
          SELECT
             $publicationSelectQuery
          FROM PublicationAsset p
          INNER JOIN Publication p ON pa.PublicationId = p.Id
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE pa.MepsLanguageId = ? AND pa.ConventionReleaseDayNumber IS NOT NULL;
        ''', [JwLifeSettings().currentLanguage.id]);

        return publications.map((pub) => Publication.fromJson(pub)).toList();
      }
      finally {
        await catalog.close();
      }
    }
    return [];
  }
}
