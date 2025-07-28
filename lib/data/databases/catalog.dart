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
  static List<Publication> recentPublications = [];
  static List<Publication> latestPublications = [];
  static List<Publication> assembliesPublications = [];

  /// Requête SQL pour récupérer les publications et leurs métadonnées.
  static final String _publicationQuery = '''
    p.*,
    meps.Language.Symbol AS LanguageSymbol, 
    meps.Language.VernacularName AS LanguageVernacularName, 
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
    pa.LastModified, 
    pa.CatalogedOn,
    pa.Size,
    pa.ExpandedSize,
    pa.SchemaVersion,
    pam.PublicationAttributeId,
    (
      SELECT ia2.NameFragment
      FROM ImageAsset ia2
      INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
      WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_sqr-%'
      ORDER BY ia2.Width DESC, ia2.Height DESC
      LIMIT 1
    ) AS ImageSqr,
    (
      SELECT ia2.NameFragment 
      FROM ImageAsset ia2
      INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
      WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_lsr-%'
      ORDER BY ia2.Width DESC, ia2.Height DESC
      LIMIT 1
    ) AS ImageLsr
    FROM Publication p
    LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
    LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
    LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
    LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
    LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
  ''';

  static Future<List<Publication>> getPublicationsForTheDay({DateTime? date}) async {
    // Obtenez la date du jour au format AAAA-mm-jj
    String formattedDate = '';
    date ??= DateTime.now();
    formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      await attachDatabases(catalog, {'meps': mepsFile.path});

      try {
        final result = await catalog.rawQuery('''
          SELECT DISTINCT
            dt.Class,
          $_publicationQuery
          LEFT JOIN DatedText dt ON p.Id = dt.PublicationId
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

  static Future<Map<String, dynamic>?> getDatedDocumentForToday(Publication publication) async {
    Database datedDocumentDb = await openReadOnlyDatabase(publication.databasePath!);

    String today = DateFormat('yyyyMMdd').format(DateTime.now());

    List<Map<String, dynamic>> response = await datedDocumentDb.rawQuery('''
      SELECT Content
      FROM DatedText
      WHERE FirstDateOffset <= ? AND LastDateOffset >= ?
    ''', [today, today]
    );

    datedDocumentDb.close();

    return response.first;
  }

  static Future<List<PublicationCategory>> updateCatalogCategories() async {
    printTime('On met à jour les catégories pour voir si le catalogue contient des nouvelles publications...');
    // Charger le fichier de catalogue et ouvrir la base de données
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      Database catalogDB = await openReadOnlyDatabase(catalogFile.path);

      try {
        // Récupérer les catégories distinctes de publication de la base de données pour la langue actuelle
        List<Map<String, dynamic>> result1 = await catalogDB.rawQuery('''
          SELECT PublicationTypeId AS id
          FROM Publication
          WHERE MepsLanguageId = ?
          GROUP BY PublicationTypeId
        ''', [JwLifeSettings().currentLanguage.id]);

        List<Map<String, dynamic>> hasPubForConventionDay = await catalogDB.rawQuery('''
          SELECT COUNT(*) > 0 AS HasConventionReleaseDayNumber
          FROM PublicationAsset
          WHERE ConventionReleaseDayNumber IS NOT NULL AND MepsLanguageId = ?;
        ''', [JwLifeSettings().currentLanguage.id]);

        final hasConvDay = RealmLibrary.realm.all<Category>().query("language == '${JwLifeSettings().currentLanguage.symbol}'").query("key == 'ConvDay1' OR key == 'ConvDay2' OR key == 'ConvDay3'");

        for(Category convDay in hasConvDay) {
          printTime('${convDay.key!} : ${convDay.media}');
        }

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
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();
    final historyFile = await getHistoryFile();

    if (allFilesExist([mepsFile, historyFile, catalogFile])) {
      final catalogDB = await openReadOnlyDatabase(catalogFile.path);

      try {
        List<List<Map<String, Object?>>> results = [];

        // ATTACH et requêtes dans la transaction
        await catalogDB.transaction((txn) async {
          await txn.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
          await txn.execute("ATTACH DATABASE '${historyFile.path}' AS history");

          String formattedDate = DateTime.now().toIso8601String().split('T').first;
          final languageId = JwLifeSettings().currentLanguage.id;


          // Exécution des requêtes EN SÉRIE, pas en parallèle
          final result1 = await txn.rawQuery('''
          SELECT DISTINCT
            $_publicationQuery
          LEFT JOIN DatedText dt ON p.Id = dt.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
        ''', [formattedDate, languageId]);

          printTime('result1 check');

          final result2 = await txn.rawQuery('''
          SELECT
            SUM(hp.VisitCount) AS TotalVisits,
            $_publicationQuery
            LEFT JOIN history.History hp ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
            WHERE hp.Type = 'webview' 
            GROUP BY p.Id
            ORDER BY TotalVisits DESC
            LIMIT 10;
        ''');

          printTime('result2 check');

          final result3 = await txn.rawQuery('''
          SELECT DISTINCT
            $_publicationQuery
            WHERE p.MepsLanguageId = ?
            GROUP BY p.Id
            ORDER BY pa.CatalogedOn DESC
            LIMIT ?
        ''', [languageId, 12]);

          printTime('result3 check');

          final result4 = await txn.rawQuery('''
          SELECT DISTINCT
            ca.SortOrder,
            $_publicationQuery
            LEFT JOIN CuratedAsset ca ON ca.PublicationAssetId = pa.Id
            WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
            GROUP BY p.Id
            ORDER BY ca.SortOrder;
        ''', [languageId, 2]);

          printTime('result4 check');

          results = [result1, result2, result3, result4];

          await txn.execute("DETACH DATABASE meps");
          await txn.execute("DETACH DATABASE history");
        });

        // Traitement des résultats après le détachement
        final resultDatedPublications = results[0];
        datedPublications = resultDatedPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('datedPublications: ${datedPublications.length}');

        final resultRecentPublications = results[1];
        recentPublications = resultRecentPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('recentPublications: ${recentPublications.length}');

        final resultLastPublications = results[2];
        latestPublications = resultLastPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('lastPublications: ${latestPublications.length}');

        final resultToolBox = results[3];
        printTime('resultToolBox: ${resultToolBox.length}');
        if (resultToolBox.isNotEmpty) {
          teachingToolboxPublications = [];
          List<int> availableTeachingToolBoxInt = [-1, 5, 8, 9, 10, -1, 11, -1, 17, 18, 19];
          for (int i = 0; i < availableTeachingToolBoxInt.length; i++) {
            if (availableTeachingToolBoxInt[i] == -1) {
              teachingToolboxPublications.add(null);
            } else if (resultToolBox.any((e) => e['SortOrder'] == availableTeachingToolBoxInt[i])) {
              final pub = resultToolBox.firstWhere(
                    (e) => e['SortOrder'] == availableTeachingToolBoxInt[i],
                orElse: () => {},
              );
              if (pub.isNotEmpty) {
                teachingToolboxPublications.add(Publication.fromJson(pub));
              }
            }
          }
        }
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

  static Future<List<Map<String, dynamic>>> getAllDatedTextFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT
        Class,
        Start,
        End
      FROM DatedText
      LEFT JOIN Publication ON DatedText.PublicationId = Publication.Id
      WHERE Publication.MepsLanguageId = ? AND Publication.Symbol = ? AND Publication.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllAvailableBibleBookFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT
        Book
      FROM AvailableBibleBook
      LEFT JOIN Publication ON AvailableBibleBook.PublicationId = Publication.Id
      WHERE Publication.MepsLanguageId = ? AND Publication.Symbol = ? AND Publication.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  /// Rechercher une publication par symbole et la date d'issue.
  static Future<Publication?> searchPub(String pubSymbol, int issueTagNumber, dynamic language) async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      String languageRequest = '';
      if (language is String) {
        languageRequest = 'WHERE meps.Language.Symbol = ? ';
      }
      else {
        languageRequest = 'WHERE pa.MepsLanguageId = ? ';
      }

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        printTime('pubSymbol: $pubSymbol');
        printTime('issueTagNumber: $issueTagNumber');
        printTime('language: $language');

        final publications = await catalog.rawQuery('''
          SELECT
            $_publicationQuery
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
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        final publications = await catalog.rawQuery('''
          SELECT
            p.*,
            pa.LastModified, 
            pa.CatalogedOn,
            pa.Size,
            pa.ExpandedSize,
            pa.SchemaVersion,
            pam.PublicationAttributeId,
            (
              SELECT ia2.NameFragment
              FROM ImageAsset ia2
              INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
              WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_sqr-%'
              ORDER BY ia2.Width DESC, ia2.Height DESC
              LIMIT 1
            ) AS ImageSqr,
            (
              SELECT ia2.NameFragment 
              FROM ImageAsset ia2
              INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
              WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_lsr-%'
              ORDER BY ia2.Width DESC, ia2.Height DESC
              LIMIT 1
            ) AS ImageLsr
            FROM Publication p
            LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
            LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
            LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
            LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
            WHERE p.MepsLanguageId = ?
            AND LOWER(p.KeySymbol) = LOWER(?) 
            AND p.IssueTagNumber = ?
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

  /// Rechercher une publication par symbole et la date d'issue.
  static Future<dynamic> searchSqrImageForPub(String pubSymbol, int issueTagNumber, int mepsLanguageId) async {
    final catalogFile = await getCatalogFile();
    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        final result = await catalog.rawQuery('''
        SELECT
          p.IssueTitle,
          (SELECT ia2.NameFragment
           FROM ImageAsset ia2
           LEFT JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
           WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_sqr-%'
           ORDER BY ia2.Width DESC, ia2.Height DESC
           LIMIT 1) AS ImageSqr
        FROM Publication p
        LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
        LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
        WHERE pa.MepsLanguageId = ? 
          AND LOWER(p.KeySymbol) = LOWER(?) 
          AND p.IssueTagNumber = ?
        LIMIT 1
      ''', [mepsLanguageId, pubSymbol, issueTagNumber]);

        return result.isNotEmpty ? result.first : null;
      } finally {
        await catalog.close();
      }
    }
    return null;
  }


  /// Rechercher une publication par mepsDocumentId et la langue.
  static Future<Publication?> searchPubFromMepsDocumentId(int mepsDocumentId, int mepsLanguageId) async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        final publications = await catalog.rawQuery('''
          SELECT DISTINCT
            $_publicationQuery
          LEFT JOIN PublicationDocument pd ON p.Id = pd.PublicationId
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
  static Future<Map<PublicationAttribute, List<Publication>>> getPublicationsFromCategory(int category, {int? year}) async {
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        // Construction des paramètres de la requête
        List<dynamic> queryParams = [JwLifeSettings().currentLanguage.id, category];
        String yearCondition = '';

        if (year != null) {
          yearCondition = 'AND p.Year = ?';
          queryParams.add(year);
        }

        final result = await catalog.rawQuery('''
        SELECT
            p.*,
            pa.LastModified,
            pa.Size,
            pa.ExpandedSize,
            pa.SchemaVersion,
            pam.PublicationAttributeId,
            (SELECT ia.NameFragment 
             FROM PublicationAssetImageMap paim 
             JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
             WHERE paim.PublicationAssetId = pa.Id 
               AND (ia.Width = 270 AND ia.Height = 270)
             LIMIT 1) AS ImageSqr
        FROM Publication p
        LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
        WHERE p.MepsLanguageId = ? AND p.PublicationTypeId = ? $yearCondition
        ORDER BY p.Id;
''', queryParams);

        Map<PublicationAttribute, List<Publication>> groupedByCategory = {};
        for (var publication in result) {
          Publication pub = Publication.fromJson(publication);
          groupedByCategory.putIfAbsent(pub.attribute, () => []).add(pub);
        }
        return groupedByCategory;
      }
      finally {
        await catalog.close();
      }
    }
    return {};
  }

  static Future<void> fetchAssemblyPublications() async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        final langId = JwLifeSettings().currentLanguage.id;

        // Récupération de toutes les publications d'assemblée de circonscription
        final allCircuitAssemblies = await catalog.rawQuery('''
        SELECT
          p.*,
          meps.Language.Symbol AS LanguageSymbol,
          meps.Language.VernacularName AS LanguageVernacularName,
          meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
          pa.LastModified,
          pa.CatalogedOn,
          pa.Size,
          pa.ExpandedSize,
          pa.SchemaVersion,
          pam.PublicationAttributeId,
          (
            SELECT ia2.NameFragment
            FROM ImageAsset ia2
            INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
            WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_sqr-%'
            ORDER BY ia2.Width DESC, ia2.Height DESC
            LIMIT 1
          ) AS ImageSqr,
          (
            SELECT ia2.NameFragment
            FROM ImageAsset ia2
            INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
            WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_lsr-%'
            ORDER BY ia2.Width DESC, ia2.Height DESC
            LIMIT 1
          ) AS ImageLsr
        FROM Publication p
        LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
        LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
        LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
        LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
        WHERE p.MepsLanguageId = ?
          AND (p.KeySymbol LIKE 'CA-copgm%' OR p.KeySymbol LIKE 'CA-brpgm%')
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
          p.*,
          meps.Language.Symbol AS LanguageSymbol,
          meps.Language.VernacularName AS LanguageVernacularName,
          meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
          pa.LastModified,
          pa.CatalogedOn,
          pa.Size,
          pa.ExpandedSize,
          pa.SchemaVersion,
          pam.PublicationAttributeId,
          (
            SELECT ia2.NameFragment
            FROM ImageAsset ia2
            INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
            WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_sqr-%'
            ORDER BY ia2.Width DESC, ia2.Height DESC
            LIMIT 1
          ) AS ImageSqr,
          (
            SELECT ia2.NameFragment
            FROM ImageAsset ia2
            INNER JOIN PublicationAssetImageMap paim2 ON ia2.Id = paim2.ImageAssetId
            WHERE paim2.PublicationAssetId = pa.Id AND ia2.NameFragment LIKE '%_lsr-%'
            ORDER BY ia2.Width DESC, ia2.Height DESC
            LIMIT 1
          ) AS ImageLsr
        FROM Publication p
        LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
        LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
        LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
        LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
        WHERE p.MepsLanguageId = ?
          AND p.KeySymbol LIKE 'CO-pgm%'
        ORDER BY p.Year DESC
        LIMIT 1;
      ''', [langId]);

        // Fusion et transformation en objets Publication
        for (var publication in [...circuitAssemblies, ...convention]) {
          final pub = Publication.fromJson(publication);
          assembliesPublications.add(pub);
        }
      } finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
  }

  /// Rechercher les publications des assemblées régionales
  static Future<List<Publication>> fetchPubsFromConventionsDays() async {
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        final publications = await catalog.rawQuery('''
        SELECT
            p.*,
            pa.LastModified,
            pa.Size,
            pa.ExpandedSize, 
            pa.SchemaVersion,
            pa.ConventionReleaseDayNumber,
            pam.PublicationAttributeId,
            (SELECT ia.NameFragment 
             FROM PublicationAssetImageMap paim 
             JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
             WHERE paim.PublicationAssetId = pa.Id 
               AND (ia.Width = 270 AND ia.Height = 270)
             LIMIT 1) AS ImageSqr,
            -- Sous-requête pour l'image rectangulaire ou fallback
            COALESCE(
                (SELECT ia.NameFragment 
                 FROM PublicationAssetImageMap paim 
                 JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
                 WHERE paim.PublicationAssetId = pa.Id 
                   AND (ia.NameFragment LIKE '%_lsr-%' OR (ia.Width = 1200 AND ia.Height = 600))
                 LIMIT 1),
                -- Fallback : image la plus grande si pas de LSR
                (SELECT ia.NameFragment 
                 FROM PublicationAssetImageMap paim 
                 JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id 
                 WHERE paim.PublicationAssetId = pa.Id 
                   AND NOT EXISTS (
                       SELECT 1 FROM PublicationAssetImageMap paim2 
                       JOIN ImageAsset ia2 ON paim2.ImageAssetId = ia2.Id 
                       WHERE paim2.PublicationAssetId = pa.Id 
                         AND (ia2.NameFragment LIKE '%_lsr-%' OR (ia2.Width = 1200 AND ia2.Height = 600))
                   )
                 ORDER BY (ia.Width * ia.Height) DESC
                 LIMIT 1)
            ) AS ImageLsr
        FROM PublicationAsset pa
        JOIN Publication p ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
        WHERE pa.MepsLanguageId = ? AND pa.ConventionReleaseDayNumber IS NOT NULL;
      ''', [JwLifeSettings().currentLanguage.id]);

        return publications
            .map((pub) => Publication.fromJson(pub))
            .toList();
      } finally {
        await catalog.close();
      }
    }

    return [];
  }
}
