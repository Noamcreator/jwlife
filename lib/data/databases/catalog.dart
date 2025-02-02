import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PublicationsCatalog {
  /// Liste des dernières publications chargées.
  static List<Map<String, dynamic>> lastPublications = [];

  /// Requête SQL pour récupérer les publications et leurs métadonnées.
  static final String _publicationQuery = '''
    SELECT DISTINCT
      p.Id AS PublicationId,
      p.MepsLanguageId,
      meps.Language.Symbol AS LanguageSymbol,
      meps.Language.VernacularName AS LanguageVernacularName,
      meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
      p.PublicationTypeId,
      p.IssueTagNumber,
      p.Title,
      p.IssueTitle,
      p.ShortTitle,
      p.CoverTitle,
      p.KeySymbol,
      p.Symbol,
      p.Year,
      pa.CatalogedOn,
      pa.ExpandedSize,
      (SELECT ia.NameFragment
       FROM ImageAsset ia
       JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
       WHERE paim.PublicationAssetId = pa.Id 
         AND (ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600))
       ORDER BY ia.Width DESC
       LIMIT 1) AS ImageSqr,
      (SELECT ia.NameFragment
       FROM ImageAsset ia
       JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
       WHERE paim.PublicationAssetId = pa.Id 
         AND ia.NameFragment LIKE '%_lsr-%'
       ORDER BY ia.Width DESC
       LIMIT 1) AS ImageLsr,
      (SELECT CASE WHEN COUNT(pc.Symbol) > 0 THEN 1 ELSE 0 END
       FROM pub_collections.Publication pc
       WHERE p.Symbol = pc.Symbol 
         AND p.IssueTagNumber = pc.IssueTagNumber 
         AND p.MepsLanguageId = pc.MepsLanguageId) AS isDownload,
      (SELECT pc.Path
       FROM pub_collections.Publication pc
       WHERE p.Symbol = pc.Symbol 
         AND p.IssueTagNumber = pc.IssueTagNumber 
         AND p.MepsLanguageId = pc.MepsLanguageId
       LIMIT 1) AS Path,
      (SELECT pc.DatabasePath
       FROM pub_collections.Publication pc
       WHERE p.Symbol = pc.Symbol 
         AND p.IssueTagNumber = pc.IssueTagNumber 
         AND p.MepsLanguageId = pc.MepsLanguageId
       LIMIT 1) AS DatabasePath,
      (SELECT pc.Hash
       FROM pub_collections.Publication pc
       WHERE p.Symbol = pc.Symbol 
         AND p.IssueTagNumber = pc.IssueTagNumber 
         AND p.MepsLanguageId = pc.MepsLanguageId
       LIMIT 1) AS Hash,
      (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
       FROM userdata.TagMap tg
       JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
       WHERE userdata.Location.IssueTagNumber = p.IssueTagNumber 
         AND userdata.Location.KeySymbol = p.KeySymbol 
         AND userdata.Location.MepsLanguage = p.MepsLanguageId 
         AND tg.TagId = 1) AS isFavorite
    FROM
      Publication p
    LEFT JOIN
      PublicationAsset pa ON p.Id = pa.PublicationId
    LEFT JOIN
      PublicationRootKey prk ON p.PublicationRootKeyId = prk.Id
    LEFT JOIN
      PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
    LEFT JOIN
      ImageAsset ia ON paim.ImageAssetId = ia.Id
    LEFT JOIN
      meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
  ''';

  /// Charge les dernières publications avec une limite spécifiée.
  static Future<void> loadLastPublications(int limit) async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();
    final pubCollectionsFile = await getPubCollectionsFile();
    final userdataFile = await getUserdataFile();

    if (await _allFilesExist([
      catalogFile,
      mepsFile,
      pubCollectionsFile,
      userdataFile,
    ])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await _attachDatabases(catalog, {
          'meps': mepsFile.path,
          'pub_collections': pubCollectionsFile.path,
          'userdata': userdataFile.path,
        });

        final result = await catalog.rawQuery('''
          $_publicationQuery
          WHERE p.MepsLanguageId = ?
          ORDER BY pa.CatalogedOn DESC
          LIMIT ?
        ''', [JwLifeApp.currentLanguage.id, limit]);

        lastPublications = result.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      finally {
        await _detachDatabases(catalog, ['meps', 'pub_collections', 'userdata']);
        await catalog.close();
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getPublicationsForTheDay() async {
    // Obtenez la date du jour au format AAAA-mm-jj
    final dateOfTheDay = DateTime.now();
    final formattedDate = "${dateOfTheDay.year}-${dateOfTheDay.month.toString().padLeft(2, '0')}-${dateOfTheDay.day.toString().padLeft(2, '0')}";

    final pubCollectionsFile = await getPubCollectionsFile();

    if (await _allFilesExist([pubCollectionsFile])) {
      final pubCollections = await openReadOnlyDatabase(pubCollectionsFile.path);

      try {
        final result = await pubCollections.rawQuery('''
          SELECT DISTINCT 
            p.*,
            dt.Class
          FROM Publication p
          JOIN DatedText dt ON p.PublicationId = dt.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End 
          AND p.MepsLanguageId = ?
        ''', [formattedDate, JwLifeApp.currentLanguage.id]);

        return result.isNotEmpty ? result : [];
      }
      finally {
        await pubCollections.close();
      }
    }
    return [];
  }

  static Future<String?> getDatedDocumentForToday(dynamic publication) async {
    Database datedDocumentDb = await openReadOnlyDatabase(publication['DatabasePath']);

    String query = '''
      SELECT DatedText.Content
      FROM DatedText
      WHERE DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
    ''';

    String today = DateFormat('yyyyMMdd').format(DateTime.now());

    List<Map<String, dynamic>> response = await datedDocumentDb.rawQuery(query, [
      today,
      today
    ]);

    final decodedHtml = await decodeBlobContentWithHash(
      contentBlob: response.first['Content'] as Uint8List,
      hashPublication: publication['Hash'],
    );

    await datedDocumentDb.close();

    return decodedHtml;
  }

  static Future<List<Map<String, dynamic>>> getAllDocumentFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (await _allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT
        p.MepsLanguageId,
        PublicationDocument.DocumentId as MepsDocumentId
      FROM Publication p
      JOIN PublicationDocument ON p.Id = PublicationDocument.PublicationId
      WHERE p.MepsLanguageId = ? AND p.Symbol = ? AND p.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllDatedTextFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (await _allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT
        Class,
        Start,
        End
      FROM DatedText
      JOIN Publication ON DatedText.PublicationId = Publication.Id
      WHERE Publication.MepsLanguageId = ? AND Publication.Symbol = ? AND Publication.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllAvailableBibleBookFromPub(int languageId, String pubSymbol, int issueTagNumber) async {
    final catalogFile = await getCatalogFile();

    if (await _allFilesExist([catalogFile])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      final publications = await catalog.rawQuery('''
      SELECT
        Book
      FROM AvailableBibleBook
      JOIN Publication ON AvailableBibleBook.PublicationId = Publication.Id
      WHERE Publication.MepsLanguageId = ? AND Publication.Symbol = ? AND Publication.IssueTagNumber = ?
    ''', [languageId, pubSymbol, issueTagNumber]);

      await catalog.close();

      return publications.isNotEmpty ? publications : [];
    }
    return [];
  }

  /// Rechercher une publication par symbole et la date d'issue.
  static Future<Map<String, dynamic>?> searchPub(String pubSymbol, String issueTagNumber) async {
    final catalogFile = await getCatalogFile();
    final mepsFile = await getMepsFile();
    final pubCollectionsFile = await getPubCollectionsFile();
    final userdataFile = await getUserdataFile();

    if (await _allFilesExist([
      catalogFile,
      mepsFile,
      pubCollectionsFile,
      userdataFile,
    ])) {
      final catalog = await openReadOnlyDatabase(catalogFile.path);

      try {
        await _attachDatabases(catalog, {
          'meps': mepsFile.path,
          'pub_collections': pubCollectionsFile.path,
          'userdata': userdataFile.path,
        });

        final publications = await catalog.rawQuery('''
      $_publicationQuery
      WHERE pa.MepsLanguageId = ? 
        AND LOWER(p.KeySymbol) = LOWER(?) 
        AND p.IssueTagNumber = ?
      LIMIT 1
    ''', [JwLifeApp.currentLanguage.id, pubSymbol, issueTagNumber]);

        return publications.isNotEmpty ? publications.first : null;
      }
      finally {
        await _detachDatabases(catalog, ['meps', 'pub_collections', 'userdata']);
        await catalog.close();
      }
    }
    return null;
  }

  /// Vérifie si tous les fichiers spécifiés existent.
  static Future<bool> _allFilesExist(List<File> files) async {
    for (final file in files) {
      if (!await file.exists()) return false;
    }
    return true;
  }

  /// Attache les bases de données supplémentaires au catalogue principal.
  static Future<void> _attachDatabases(Database catalog, Map<String, String> databases) async {
    for (final entry in databases.entries) {
      await catalog.execute("ATTACH DATABASE '${entry.value}' AS ${entry.key}");
    }
  }

  /// Détache les bases de données supplémentaires.
  static Future<void> _detachDatabases(Database catalog, List<String> aliases) async {
    for (final alias in aliases) {
      await catalog.execute("DETACH DATABASE $alias");
    }
  }
}
