import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:sqflite/sqflite.dart';

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

    if (await allFilesExist([catalogFile, mepsFile])) {
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

  /// Charge la panoplie d'enseignant
  static Future<void> loadHomePage() async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();
    final historyFile = await getHistoryFile();

    if (await allFilesExist([catalogFile, mepsFile, historyFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await attachDatabases(catalog, {
          'meps': mepsFile.path,
          'history': historyFile.path
        });

        String formattedDate = '';
        DateTime date = DateTime.now();
        formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        final resultDatedPublications = await catalog.rawQuery('''
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

        datedPublications = resultDatedPublications.map((item) => Publication.fromJson(item)).toList();

        final resultRecentPublications = await catalog.rawQuery('''
        SELECT
          SUM(hp.VisitCount) AS TotalVisits,
          $_publicationQuery
          LEFT JOIN history.History hp ON p.KeySymbol = hp.KeySymbol AND p.IssueTagNumber = hp.IssueTagNumber AND p.MepsLanguageId = hp.MepsLanguageId
          WHERE hp.Type = 'document'
          GROUP BY p.Id, pa.Id, pam.PublicationAttributeId
          ORDER BY TotalVisits DESC
          LIMIT 10;
        ''');

        recentPublications = resultRecentPublications.map((item) => Publication.fromJson(item)).toList();

        final resultLastPublication = await catalog.rawQuery('''
        SELECT DISTINCT
          $_publicationQuery
          WHERE p.MepsLanguageId = ?
          GROUP BY p.Id
          ORDER BY pa.CatalogedOn DESC
          LIMIT ?
        ''', [JwLifeApp.settings.currentLanguage.id, 12]);

        lastPublications = resultLastPublication.map((item) => Publication.fromJson(item)).toList();

        final resultToolBox = await catalog.rawQuery('''
          SELECT DISTINCT
          ca.SortOrder,
          $_publicationQuery
          LEFT JOIN CuratedAsset ca ON ca.PublicationAssetId = pa.Id
          WHERE pa.MepsLanguageId = ? AND ca.ListType = ?
          GROUP BY p.Id
          ORDER BY ca.SortOrder;

        ''', [JwLifeApp.settings.currentLanguage.id, 2]);

        if (resultToolBox.isNotEmpty) {
          teachingToolBoxPublications = [];
          List<int> availableTeachingToolBoxInt = [-1, 5, 8, 9, 10, -1, 11, -1, 17, 18, 19];

          for (int i = 0; i < availableTeachingToolBoxInt.length; i++) {
            if(availableTeachingToolBoxInt[i] == -1) {
              teachingToolBoxPublications.add(null);
            }
            else if(resultToolBox.any((element) => element['SortOrder'] == availableTeachingToolBoxInt[i])) {
              Map<String, dynamic> pub = resultToolBox.firstWhere((element) => element['SortOrder'] == availableTeachingToolBoxInt[i], orElse: () => {});
              if(pub.isNotEmpty) {
                teachingToolBoxPublications.add(Publication.fromJson(pub));
              }
            }
          }
        }
      }
      finally {
        await detachDatabases(catalog, ['meps', 'history']);
        await catalog.close();
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDatedTextFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (await allFilesExist([catalogFile])) {
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

    if (await allFilesExist([catalogFile])) {
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

    if (await allFilesExist([catalogFile, mepsFile])) {
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

  /// Rechercher une publication par mepsDocumentId et la langue.
  static Future<Publication?> searchPubFromMepsDocumentId(int mepsDocumentId, int mepsLanguageId) async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();

    if (await allFilesExist([catalogFile, mepsFile])) {
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

    if (await allFilesExist([catalogFile])) {
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
  MAX(ia_sqr.NameFragment) AS ImageSqr,
  MAX(ia_lsr.NameFragment) AS ImageLsr
FROM 
  Publication p
JOIN 
  PublicationAsset pa ON p.Id = pa.PublicationId
LEFT JOIN 
  PublicationAttributeMap pam ON p.Id = pam.PublicationId
LEFT JOIN 
  PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
LEFT JOIN 
  ImageAsset ia_sqr ON paim.ImageAssetId = ia_sqr.Id 
  AND (ia_sqr.NameFragment LIKE '%_sqr-%' OR (ia_sqr.Width = 600 AND ia_sqr.Height = 600))
LEFT JOIN 
  ImageAsset ia_lsr ON paim.ImageAssetId = ia_lsr.Id 
  AND (ia_lsr.NameFragment LIKE '%_lsr-%' OR (ia_lsr.Width = 1200 AND ia_lsr.Height = 600))
WHERE 
  p.MepsLanguageId = ?
  AND p.PublicationTypeId = ?
  $yearCondition
GROUP BY 
  p.Id, pa.CatalogedOn, pa.ExpandedSize, pa.SchemaVersion, pam.PublicationAttributeId
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

    if (await allFilesExist([catalogFile, mepsFile])) {
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

        for (var publication in circuitAssemblies) {
          print(publication);
        }

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
