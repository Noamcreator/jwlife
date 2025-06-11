import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/utils.dart';
import 'PublicationCategory.dart';

class PubCatalog {
  /// Liste des dernières publications chargées.
  static List<Publication> datedPublications = [];
  static List<Publication?> teachingToolBoxPublications = [];
  static List<Publication> recentPublications = [];
  static List<Publication> lastPublications = [];
  static List<Publication> assembliesPublications = [];

  /// Requête SQL pour récupérer les publications et leurs métadonnées.
  static final String _publicationQuery = '''
    p.*,
    meps.Language.Symbol AS LanguageSymbol, 
    meps.Language.VernacularName AS LanguageVernacularName, 
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode, 
    pa.LastModified, 
    pa.CatalogedOn,
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
    p.*,
    dt.Class,
    meps.Language.Symbol AS LanguageSymbol,
    meps.Language.VernacularName AS LanguageVernacularName,
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode
  FROM Publication p
  LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
  LEFT JOIN DatedText dt ON p.Id = dt.PublicationId
  WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
''', [formattedDate, JwLifeApp.settings.currentLanguage.id]);

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
    Database datedDocumentDb = await openReadOnlyDatabase(publication.databasePath);

    String today = DateFormat('yyyyMMdd').format(DateTime.now());

    List<Map<String, dynamic>> response = await datedDocumentDb.rawQuery('''
      SELECT 
        DatedText.Content
      FROM DatedText
      WHERE DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
    ''', [today, today]
    );

    await datedDocumentDb.close();

    return response.first;
  }

  static Future<void> getPublicationsCategories() async {
    // Charger le fichier de catalogue et ouvrir la base de données
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      Database catalogDB = await openDatabase(catalogFile.path);

      try {
        // Récupérer les catégories distinctes de publication de la base de données pour la langue actuelle
        List<Map<String, dynamic>> result1 = await catalogDB.rawQuery('''
        SELECT PublicationTypeId AS id
        FROM Publication
        WHERE MepsLanguageId = ?
        GROUP BY PublicationTypeId
    ''', [JwLifeApp.settings.currentLanguage.id]);

        // Convertir les résultats SQL en un Set pour une recherche rapide
        Set<int> existingIds = result1.map((e) => e['id'] as int).toSet();

        // Fermer la base de données après avoir récupéré les résultats
        await catalogDB.close();

        // Récupérer les publications en fonction de la langue actuelle
        List<Publication> publications = JwLifeApp.pubCollections.getPublicationsFromLanguage(JwLifeApp.settings.currentLanguage);

        // Extraire les IDs des catégories existantes dans les publications
        Set<int> existingTypes = publications.map((e) => e.category.id).toSet();

        // Conserver uniquement les catégories existantes tout en respectant l'ordre
        List<PublicationCategory> matchedCategories = PublicationCategory.getCategories().where((cat) {
          // Vérifier si l'ID de la catégorie correspond à l'un des ID existants
          return existingIds.contains(cat.id) || existingTypes.contains(cat.id);
        }).toList();

        // Mettre à jour l'état avec les catégories correspondantes
        JwLifeApp.categories = matchedCategories;
      } catch (e) {
        // Gérer les erreurs (par exemple si la base de données est inaccessible)
        print("Erreur lors de la récupération des catégories : $e");
      }
    }
  }

  static Future<void> loadHomePage() async {
    printTime('loadHomePage');

    await PubCatalog.getPublicationsCategories();

    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();
    final historyFile = await getHistoryFile();

    if (allFilesExist([catalogFile, mepsFile, historyFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {
          'meps': mepsFile.path,
          'history': historyFile.path,
        });

        String formattedDate = DateTime.now().toIso8601String().split('T').first;
        final languageId = JwLifeApp.settings.currentLanguage.id;

        // Lancement des requêtes en parallèle
        final results = await Future.wait([
          catalog.rawQuery('''
          SELECT DISTINCT
            p.*,
            dt.Class,
            meps.Language.Symbol AS LanguageSymbol,
            meps.Language.VernacularName AS LanguageVernacularName,
            meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode
          FROM Publication p
          LEFT JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          LEFT JOIN DatedText dt ON p.Id = dt.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
        ''', [formattedDate, languageId]),

          catalog.rawQuery('''
          SELECT
            SUM(hp.VisitCount) AS TotalVisits,
            $_publicationQuery
            LEFT JOIN history.History hp ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
            WHERE hp.Type = 'document'
            GROUP BY p.Id, pa.Id, pam.PublicationAttributeId
            ORDER BY TotalVisits DESC
            LIMIT 10;
        '''),

          catalog.rawQuery('''
          SELECT DISTINCT
            $_publicationQuery
            WHERE p.MepsLanguageId = ?
            GROUP BY p.Id
            ORDER BY pa.CatalogedOn DESC
            LIMIT ?
        ''', [languageId, 12]),

          catalog.rawQuery('''
          SELECT DISTINCT
            ca.SortOrder,
            $_publicationQuery
            LEFT JOIN CuratedAsset ca ON ca.PublicationAssetId = pa.Id
            WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
            GROUP BY p.Id
            ORDER BY ca.SortOrder;
        ''', [languageId, 2]),
        ]);

        final resultDatedPublications = results[0];
        datedPublications = resultDatedPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('datedPublications: ${datedPublications.length}');

        final resultRecentPublications = results[1];
        recentPublications = resultRecentPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('recentPublications: ${recentPublications.length}');

        final resultLastPublications = results[2];
        lastPublications = resultLastPublications.map((item) => Publication.fromJson(item)).toList();
        printTime('lastPublications: ${lastPublications.length}');

        final resultToolBox = results[3];
        printTime('resultToolBox: ${resultToolBox.length}');
        if (resultToolBox.isNotEmpty) {
          teachingToolBoxPublications = [];
          List<int> availableTeachingToolBoxInt = [-1, 5, 8, 9, 10, -1, 11, -1, 17, 18, 19];
          for (int i = 0; i < availableTeachingToolBoxInt.length; i++) {
            if (availableTeachingToolBoxInt[i] == -1) {
              teachingToolBoxPublications.add(null);
            } else if (resultToolBox.any((e) => e['SortOrder'] == availableTeachingToolBoxInt[i])) {
              final pub = resultToolBox.firstWhere(
                    (e) => e['SortOrder'] == availableTeachingToolBoxInt[i],
                orElse: () => {},
              );
              if (pub.isNotEmpty) {
                teachingToolBoxPublications.add(Publication.fromJson(pub));
              }
            }
          }
        }
      } finally {
        await detachDatabases(catalog, ['meps', 'history']);
        await catalog.close();
      }
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

        final publications = await catalog.rawQuery('''
          SELECT DISTINCT
            $_publicationQuery
          $languageRequest
          AND LOWER(p.KeySymbol) = LOWER(?) 
          AND p.IssueTagNumber = ?
          LIMIT 1
        ''', [language, pubSymbol, issueTagNumber]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(catalog, ['meps']);
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
  static Future<Map<int, List<Publication>>> getPublicationsFromCategory(int category, {int? year}) async {
    final catalogFile = await getCatalogFile();

    if (allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        // Construction des paramètres de la requête
        List<dynamic> queryParams = [JwLifeApp.settings.currentLanguage.id, category];
        String yearCondition = '';

        if (year != null) {
          yearCondition = 'AND p.Year = ?';
          queryParams.add(year);
        }

        final result = await catalog.rawQuery('''
SELECT
    p.*,
    pa.LastModified, 
    pa.ExpandedSize, 
    pa.SchemaVersion,
    pam.PublicationAttributeId,
    -- Sous-requête optimisée pour l'image carrée (270x270 en priorité)
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
FROM 
    Publication p
JOIN 
    PublicationAsset pa ON p.Id = pa.PublicationId
LEFT JOIN 
    PublicationAttributeMap pam ON p.Id = pam.PublicationId
WHERE 
    p.MepsLanguageId = ?
    AND p.PublicationTypeId = ?
    $yearCondition
ORDER BY p.Id;
''', queryParams);

        Map<int, List<Publication>> groupedByCategory = {};
        for (var publication in result) {
          Publication pub = Publication.fromJson(publication);
          groupedByCategory.putIfAbsent(pub.attributeId, () => []).add(pub);
        }
        return groupedByCategory;
      }
      finally {
        await catalog.close();
      }
    }
    return {};
  }

  /// Charge les publications des assemblies
  static Future<void> fetchAssemblyPublications() async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (allFilesExist([catalogFile, mepsFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {'meps': mepsFile.path});

        final circuitAssemblies = await catalog.rawQuery('''
          SELECT
            $_publicationQuery
          WHERE p.MepsLanguageId = ? AND (p.KeySymbol LIKE 'CA-copgm%' OR p.KeySymbol LIKE 'CA-brpgm%')
          GROUP BY p.Id          
          ORDER BY p.Year DESC
          LIMIT 2;
        ''', [JwLifeApp.settings.currentLanguage.id]);

        final convention = await catalog.rawQuery('''
          SELECT
            $_publicationQuery
          WHERE p.MepsLanguageId = ? AND p.KeySymbol LIKE 'CO-pgm%'
          ORDER BY p.Year DESC
          LIMIT 1;
        ''', [JwLifeApp.settings.currentLanguage.id]);

        for (var publication in [...circuitAssemblies, ...convention]) {
          Publication pub = Publication.fromJson(publication);
          assembliesPublications.add(pub);
        }
      }
      finally {
        await detachDatabases(catalog, ['meps']);
        await catalog.close();
      }
    }
  }
}
