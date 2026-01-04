import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_database.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/utils/utils.dart';
import '../realm/catalog.dart';
import '../models/publication_category.dart';
import '../repositories/PublicationRepository.dart';

class CatalogDb {
  static final CatalogDb instance = CatalogDb._();
  CatalogDb._();

  late Database database;

  static final String publicationSelectQuery = '''
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
     WHERE paim.PublicationAssetId = pa.Id AND ((ia.Width = 270 AND ia.Height = 270) OR (ia.Width = 100 AND ia.Height = 100))
     LIMIT 1) AS ImageSqr
  ''';

  static final String publicationQuery = '''
    $publicationSelectQuery
    FROM Publication p
    INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
    LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
  ''';

  /// Requête SQL pour récupérer les publications et leurs métadonnées.
  static final String publicationMepsSelectQuery = '''
    meps.Language.Symbol AS LanguageSymbol, 
    meps.Language.VernacularName AS LanguageVernacularName, 
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
    meps.Language.IsSignLanguage AS IsSignLanguage,
    meps.Script.InternalName AS ScriptInternalName,
    meps.Script.DisplayName AS ScriptDisplayName,
    meps.Script.IsBidirectional AS IsBidirectional,
    meps.Script.IsRTL AS IsRTL,
    meps.Script.IsCharacterSpaced AS IsCharacterSpaced,
    meps.Script.IsCharacterBreakable AS IsCharacterBreakable,
    meps.Script.SupportsCodeNames AS SupportsCodeNames,
    meps.Script.HasSystemDigits AS HasSystemDigits,
    fallback.PrimaryIetfCode AS FallbackPrimaryIetfCode,
    $publicationSelectQuery
  ''';

  static final String publicationMepsQuery = '''
    $publicationMepsSelectQuery
    FROM Publication p
    INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
    LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
    INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
    INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
    LEFT JOIN meps.Language AS fallback ON meps.Language.PrimaryFallbackLanguageId = fallback.LanguageId
  ''';

  Future<void> init(File catalogFile) async {
    if(await catalogFile.exists()) {
      database = await openReadOnlyDatabase(catalogFile.path);
    }
  }

  Future<void> updateCatalogCategories(MepsLanguage language) async {
    printTime('On met à jour les catégories pour voir si le catalogue contient des nouvelles publications...');
    // Charger le fichier de catalogue et ouvrir la base de données
    try {
      // Récupérer les catégories distinctes de publication de la base de données pour la langue actuelle
      List<Map<String, dynamic>> result1 = await database.rawQuery('''
          SELECT DISTINCT 
            PublicationTypeId AS id
          FROM Publication
          WHERE MepsLanguageId = ?
        ''', [language.id]);

      List<Map<String, dynamic>> hasPubForConventionDay = await database.rawQuery('''
          SELECT EXISTS (
              SELECT 1
              FROM PublicationAsset
              WHERE ConventionReleaseDayNumber IS NOT NULL
                AND MepsLanguageId = ?
          ) AS HasConventionReleaseDayNumber;
        ''', [language.id]);

      final hasConvDay = RealmLibrary.realm.all<RealmCategory>().query("LanguageSymbol == '${language.symbol}'").query("Key == 'ConvDay1' OR Key == 'ConvDay2' OR Key == 'ConvDay3'");

      // Convertir les résultats SQL en un Set pour une recherche rapide
      Set<int> existingIds = result1.map((e) => e['id'] as int).toSet();

      // Récupérer les publications en fonction de la langue actuelle
      List<Publication> publications = PublicationRepository().getPublicationsFromLanguage(language);

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

      AppDataService.instance.publicationsCategories.value = matchedCategories;

      printTime('Catégories mis à jour dans LibraryView');
    }
    catch (e) {
      // Gérer les erreurs (par exemple si la base de données est inaccessible)
      printTime("Erreur lors de la récupération des catégories : $e");
    }
  }

  Future<List<Publication>> getPublicationsForTheDay(MepsLanguage mepsLanguage, {DateTime? date}) async {
    // Obtenez la date du jour au format AAAA-mm-jj
    String formattedDate = '';
    date ??= DateTime.now();
    formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    MepsLanguage language = mepsLanguage;

    try {
      final result = await database.rawQuery('''
          SELECT DISTINCT
            $publicationSelectQuery
          FROM DatedText dt
          INNER JOIN Publication p ON dt.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End AND p.MepsLanguageId = ?
        ''', [formattedDate, language.id]);

      return result.map((e) => Publication.fromJson(e, language: language)).toList();
    }
    catch (e) {
      printTime('Error getPublicationsForTheDay: $e');
      return [];
    }
  }

  /// Rechercher une publication par symbole et la date d'issue.
  Future<Publication?> searchPub(String keySymbol, int issueTagNumber, dynamic language) async {
    if (language is String) {
      Publication? pub = PublicationRepository().getPublicationWithSymbol(keySymbol, issueTagNumber, language);
      if (pub != null) return pub;
    }
    else {
      Publication? pub = PublicationRepository().getPublicationWithMepsLanguageId(keySymbol, issueTagNumber, language);
      if (pub != null) return pub;
    }

    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      String languageRequest = '';
      if (language is String) {
        languageRequest = 'WHERE meps.Language.Symbol = ?';
      }
      else {
        languageRequest = 'WHERE pa.MepsLanguageId = ?';
      }

      try {
        await attachDatabases(database, {'meps': mepsFile.path});

        printTime('pubSymbol: $keySymbol');
        printTime('issueTagNumber: $issueTagNumber');
        printTime('language: $language');

        final publications = await database.rawQuery('''
          SELECT
            $publicationMepsQuery
          $languageRequest 
          AND (LOWER(p.Symbol) = LOWER(?) OR LOWER(p.KeySymbol) = LOWER(?))
          AND p.IssueTagNumber = ?
          LIMIT 1
        ''', [language, keySymbol, keySymbol, issueTagNumber]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(database, ['meps']);
      }
    }
    return null;
  }

  Future<List<Publication>> searchPubs(List<String> keySymbols, List<int> issueTagNumbers, dynamic language) async {
    List<Publication> foundPubs = [];
    List<String> missingKeySymbols = [];
    List<int> missingIssueTagNumbers = [];

    // On s'assure que les listes de recherche sont de même taille pour itérer en parallèle
    int count = keySymbols.length < issueTagNumbers.length ? keySymbols.length : issueTagNumbers.length;

    // 1.1 Tente de récupérer chaque publication individuellement dans le Repository
    for (int i = 0; i < count; i++) {
      final keySymbol = keySymbols[i];
      final issueTagNumber = issueTagNumbers[i];

      Publication? pub;

      // Logique de langue similaire à votre fonction originale
      if (language is String) {
        pub = PublicationRepository().getPublicationWithSymbol(keySymbol, issueTagNumber, language);
      } else {
        pub = PublicationRepository().getPublicationWithMepsLanguageId(keySymbol, issueTagNumber, language);
      }

      if (pub != null) {
        foundPubs.add(pub);
      } else {
        // Si la publication n'est pas trouvée, on l'ajoute à la liste des manquantes
        missingKeySymbols.add(keySymbol);
        missingIssueTagNumbers.add(issueTagNumber);
      }
    }

    // Si toutes les publications ont été trouvées, on peut s'arrêter ici
    if (missingKeySymbols.isEmpty) {
      return foundPubs;
    }

    // --- Étape 2: Recherche en base de données pour les publications manquantes ---

    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile]) && missingKeySymbols.isNotEmpty) {
      // Crée les chaînes de placeholders '?, ?, ?' pour la clause IN de SQL
      final keySymbolPlaceholders = List.filled(missingKeySymbols.length, '?').join(', ');
      final issueTagNumberPlaceholders = List.filled(missingIssueTagNumbers.length, '?').join(', ');

      String languageRequest = '';
      if (language is String) {
        languageRequest = 'WHERE meps.Language.Symbol = ?';
      } else {
        languageRequest = 'WHERE pa.MepsLanguageId = ?';
      }

      // Prépare la liste complète des arguments pour la requête SQL
      // Ordre : [language, ...missingKeySymbols, ...missingIssueTagNumbers]
      final List<dynamic> sqlArguments = [
        language,
        ...missingKeySymbols.map((s) => s.toLowerCase()),
        ...missingIssueTagNumbers
      ];

      try {
        await attachDatabases(database, {'meps': mepsFile.path});

        printTime('Searching DB for missing pubs: ${missingKeySymbols.length}');

        // Exécute la requête sur la base de données
        final publications = await database.rawQuery('''
        SELECT
          $publicationMepsQuery
        $languageRequest 
        AND (LOWER(p.KeySymbol) IN ($keySymbolPlaceholders) OR LOWER(p.Symbol) IN ($keySymbolPlaceholders))
        AND p.IssueTagNumber IN ($issueTagNumberPlaceholders)
      ''', sqlArguments);

        // Ajoute les publications trouvées en base de données à la liste des résultats
        foundPubs.addAll(publications.map((json) => Publication.fromJson(json)).toList());

      }
      finally {
        await detachDatabases(database, ['meps']);
      }
    }

    // Retourne la liste complète (trouvées dans le Repository + trouvées en DB)
    return foundPubs;
  }

  Future<String?> getKeySymbolFromCatalogue(String symbol, int issueTagNumber, int mepsLanguageId) async {
    try {
      final result = await database.rawQuery('''
          SELECT
            KeySymbol
          FROM Publication
          WHERE MepsLanguageId = ? 
          AND Symbol = ?
          AND IssueTagNumber = ?
          LIMIT 1
        ''', [mepsLanguageId, symbol, issueTagNumber]);

      return result.isNotEmpty ? result.first['KeySymbol'] as String : null;
    }
    catch (e) {
      printTime('Error getKeySymbolFromCatalogue: $e');
    }
    return null;
  }

  Future<Publication?> searchPubNoMepsLanguage(String pubSymbol, int issueTagNumber, int mepsLanguageId) async {
    try {
      final publications = await database.rawQuery('''
          SELECT DISTINCT
           $publicationQuery
          WHERE p.MepsLanguageId = ? AND LOWER(p.KeySymbol) = LOWER(?)  AND p.IssueTagNumber = ?
          LIMIT 1
          ''', [mepsLanguageId, pubSymbol, issueTagNumber]);

      printTime('searchPub: ${publications.length}');

      return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
    }
    catch (e) {
      printTime('Error searchPubNoMepsLanguage: $e');
    }
    return null;
  }

  /// Rechercher une publication par bookNumber, le keySymbol et la langue.
  Future<Publication?> searchPubFromBookNumber(int book, String keySymbol, int mepsLanguageId) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      try {
        await attachDatabases(database, {'meps': mepsFile.path});

        final publications = await database.rawQuery('''
          SELECT DISTINCT
            $publicationMepsSelectQuery
          FROM AvailableBibleBook ab
          INNER JOIN Publication p ON ab.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
          LEFT JOIN meps.Language AS fallback ON meps.Language.PrimaryFallbackLanguageId = fallback.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE ab.Book = ? AND p.KeySymbol = ? AND p.MepsLanguageId = ?
          LIMIT 1
        ''', [book, keySymbol, mepsLanguageId]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(database, ['meps']);
      }
    }
    return null;
  }

  /// Rechercher une publication par mepsDocumentId et la langue.
  Future<Publication?> searchPubFromMepsDocumentId(int mepsDocumentId, int mepsLanguageId) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    if (allFilesExist([mepsFile])) {
      try {
        await attachDatabases(database, {'meps': mepsFile.path});

        final publications = await database.rawQuery('''
          SELECT DISTINCT
            $publicationMepsSelectQuery
          FROM PublicationDocument pd
          INNER JOIN Publication p ON pd.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
          LEFT JOIN meps.Language AS fallback ON meps.Language.PrimaryFallbackLanguageId = fallback.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE pd.DocumentId = ? AND p.MepsLanguageId = ?
          LIMIT 1
        ''', [mepsDocumentId, mepsLanguageId]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      }
      finally {
        await detachDatabases(database, ['meps']);
      }
    }
    return null;
  }

  /// Rechercher une publication où la date fournie est comprise entre Start et End
  Future<Publication?> searchPubFromDatedText(int dateAsInt, String keySymbol, int mepsLanguageId) async {
    final mepsFile = await getMepsUnitDatabaseFile();

    // Obtenez la date du jour au format AAAA-mm-jj
    String formattedDate = '';
    DateTime date = DateTime.parse(dateAsInt.toString());
    formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    if (allFilesExist([mepsFile])) {
      try {
        await attachDatabases(database, {'meps': mepsFile.path});

        // La logique : on cherche si dateAsInt est entre la colonne Start et la colonne End
        final publications = await database.rawQuery('''
          SELECT DISTINCT
            $publicationMepsSelectQuery
          FROM DatedText dt
          INNER JOIN Publication p ON dt.PublicationId = p.Id
          INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
          INNER JOIN meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
          INNER JOIN meps.Script ON meps.Language.ScriptId = meps.Script.ScriptId
          LEFT JOIN meps.Language AS fallback ON meps.Language.PrimaryFallbackLanguageId = fallback.LanguageId
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE ? BETWEEN dt.Start AND dt.End 
            AND p.KeySymbol = ? 
            AND p.MepsLanguageId = ?
          LIMIT 1
        ''', [formattedDate, keySymbol, mepsLanguageId]);

        return publications.isNotEmpty ? Publication.fromJson(publications.first) : null;
      } catch (e) {
        print('Erreur lors de la requête : $e');
        return null;
      } finally {
        await detachDatabases(database, ['meps']);
      }
    }
    return null;
  }

  /// Rechercher une publication par mepsDocumentId et la langue.
  Future<Publication?> searchPubNoMepsFromMepsDocumentId(int mepsDocumentId, MepsLanguage mepsLanguage) async {
    try {
      final publications = await database.rawQuery('''
          SELECT DISTINCT
           $publicationQuery
          WHERE pd.DocumentId = ? AND p.MepsLanguageId = ?
          LIMIT 1
        ''', [mepsDocumentId, mepsLanguage]);

      return publications.isNotEmpty ? Publication.fromJson(publications.first, language: mepsLanguage) : null;
    }
    catch (e) {
      return null;
    }
  }

  /// Charge les publications d'une catégorie
  Future<Map<List<PublicationAttribute>, List<Publication>>> getPublicationsFromCategory(int category, MepsLanguage mepsLanguage, {int? year}) async {
    try {
      // Paramètres dynamiques
      final queryParams = <dynamic>[
        mepsLanguage.id,
        category,
      ];

      // Condition sur l'année
      String yearCondition = '';
      if (year != null) {
        yearCondition = 'AND p.Year = ?';
        queryParams.add(year);
      }

      // Requête SQL
      final result = await database.rawQuery('''
        SELECT DISTINCT
          $publicationSelectQuery,
          GROUP_CONCAT(DISTINCT pam.PublicationAttributeId) AS PublicationAttributeIds
        FROM Publication p
        INNER JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
        WHERE p.MepsLanguageId = ? AND p.PublicationTypeId = ?
          $yearCondition
        GROUP BY
          p.Id
        ORDER BY p.Id;
      ''', queryParams);

      // Groupement par attribut
      final Map<List<PublicationAttribute>, List<Publication>> groupedByCategory = {};
      for (final publication in result) {
        final pub = Publication.fromJson(publication, language: mepsLanguage);
        groupedByCategory.putIfAbsent(pub.attributes, () => []).add(pub);
      }

      return groupedByCategory;
    }
    catch (e) {
      printTime('Error getPublicationsFromCategory: $e');
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getItemsYearInCategory(int category, {int? mepsLanguageId}) async {
    mepsLanguageId ??= JwLifeSettings.instance.libraryLanguage.value.id;

    try {
       final result = await database.rawQuery(''' 
          SELECT DISTINCT
            Year
          FROM 
            Publication
          WHERE MepsLanguageId = ? AND PublicationTypeId = ?
          ORDER BY Year DESC
      ''', [mepsLanguageId, category]);

       return result;
     }
     catch (e) {
       printTime('Error getItemsYearInCategory: $e');
     }
     return [];
  }

  Future<void> fetchAssemblyPublications(MepsLanguage mepsLanguage) async {
    List<Publication> assembliesPublications = [];

    try {
      // Récupération de toutes les publications d'assemblée de circonscription
      final allCircuitAssemblies = await database.rawQuery('''
          SELECT
            $publicationQuery
          WHERE p.MepsLanguageId = ? AND (p.KeySymbol LIKE 'CA-copgm%' OR p.KeySymbol LIKE 'CA-brpgm%')
      ''', [mepsLanguage.id]);

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
      final convention = await database.rawQuery('''
        SELECT
          $publicationQuery
        WHERE p.MepsLanguageId = ? AND p.KeySymbol LIKE 'CO-pgm%'
        ORDER BY p.Year DESC
        LIMIT 1;
      ''', [mepsLanguage.id]);

      // Fusion et transformation en objets Publication
      for (var publication in [...circuitAssemblies, ...convention]) {
        final pub = Publication.fromJson(publication, language: mepsLanguage);
        assembliesPublications.add(pub);
      }

      AppDataService.instance.conventionPub.value = assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CO-pgm'));
      AppDataService.instance.circuitCoPub.value = assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-copgm'));
      AppDataService.instance.circuitBrPub.value = assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-brpgm'));
    }
    catch (e) {
      printTime('Error fetchAssemblyPublications: $e');
    }
  }

  /// Rechercher les publications des assemblées régionales
  Future<List<Publication>> fetchPubsFromConventionsDays(MepsLanguage mepsLanguage) async {
    try {
      final publications = await database.rawQuery('''
          SELECT
          $publicationSelectQuery,
          pa.ConventionReleaseDayNumber
          FROM PublicationAsset pa
          INNER JOIN Publication p ON pa.PublicationId = p.Id
          LEFT JOIN PublicationAttributeMap pam ON p.Id = pam.PublicationId
          WHERE pa.MepsLanguageId = ? AND pa.ConventionReleaseDayNumber IS NOT NULL;
        ''', [mepsLanguage.id]);

      return publications.map((pub) => Publication.fromJson(pub)).toList();
    }
    catch (e) {
      printTime('Error fetchPubsFromConventionsDays: $e');
      return [];
    }
  }

  Future<List<Publication>> getAllUpdatePublications() async {
    // 1. Récupérer les publications locales
    List<Publication> localPubs = PublicationRepository().getAllDownloadedPublications();

    if (localPubs.isEmpty) return [];

    // 2. Préparer les placeholders pour la requête SQL (ex: ?, ?, ?)
    final placeholders = localPubs.map((_) => '?').join(', ');

    // Extraire les listes de valeurs pour le filtrage
    final keySymbols = localPubs.map((p) => p.keySymbol).toList();
    final issueTagNumbers = localPubs.map((p) => p.issueTagNumber).toList();
    final mepsLanguageIds = localPubs.map((p) => p.mepsLanguage.id).toList();

    try {
      final List<Map<String, dynamic>> results = await database.rawQuery('''
        SELECT
          p.KeySymbol,
          p.Symbol,
          p.IssueTagNumber,
          p.MepsLanguageId,
          pa.LastModified,
          pa.LastUpdated,
          pa.Size,
          pa.ExpandedSize
        FROM PublicationAsset pa
        INNER JOIN Publication p ON pa.PublicationId = p.Id
        WHERE p.KeySymbol IN ($placeholders) 
          AND p.IssueTagNumber IN ($placeholders) 
          AND p.MepsLanguageId IN ($placeholders)
          AND pa.LastModified IS NOT NULL 
          AND pa.LastUpdated IS NOT NULL
      ''', [...keySymbols, ...issueTagNumbers, ...mepsLanguageIds]);

      for (var pub in localPubs) {
        String? lastModified = results.firstWhereOrNull((element) => element['KeySymbol'] == pub.keySymbol && element['IssueTagNumber'] == pub.issueTagNumber && element['MepsLanguageId'] == pub.mepsLanguage.id)?['LastModified'] ?? pub.lastModified;
        String? lastUpdated = results.firstWhereOrNull((element) => element['KeySymbol'] == pub.keySymbol && element['IssueTagNumber'] == pub.issueTagNumber && element['MepsLanguageId'] == pub.mepsLanguage.id)?['LastUpdated'] ?? pub.lastUpdated;
        int? size = results.firstWhereOrNull((element) => element['KeySymbol'] == pub.keySymbol && element['IssueTagNumber'] == pub.issueTagNumber && element['MepsLanguageId'] == pub.mepsLanguage.id)?['Size'] ?? pub.size;
        int? expandedSize = results.firstWhereOrNull((element) => element['KeySymbol'] == pub.keySymbol && element['IssueTagNumber'] == pub.issueTagNumber && element['MepsLanguageId'] == pub.mepsLanguage.id)?['ExpandedSize'] ?? pub.expandedSize;

        if(lastModified != null && lastUpdated != null && size != null && expandedSize != null) {
          pub.lastModified = lastModified;
          pub.lastUpdated = lastUpdated;
          pub.size = size;
          pub.expandedSize = expandedSize;
          pub.hasUpdateNotifier.value = pub.hasUpdate();
        }
      }

      // 4. Conversion des résultats
      return localPubs;
    }
    catch (e) {
      print('Error getAllUpdatePublications: $e');
      return [];
    }
  }

  Future<List<Publication>> fetchPubs(String query, MepsLanguage mepsLanguage, {int? limit}) async {
    try {
      final searchQuery = '%$query%';

      final List<Map<String, dynamic>> results = await database.rawQuery('''
        SELECT DISTINCT
          $publicationQuery
        WHERE p.MepsLanguageId = ? 
        AND (p.Title LIKE ? OR p.KeySymbol LIKE ? OR p.Symbol LIKE ? OR p.Year LIKE ?)
        ORDER BY p.Year DESC
        ${limit != null ? 'LIMIT $limit' : ''}
      ''', [
        mepsLanguage.id,
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery
      ]);

      // Transformation de la liste de Maps en liste d'objets Publication
      return results.map((json) => Publication.fromJson(json, language: mepsLanguage)).toList();

    }
    catch (e) {
      print('Erreur lors de la recherche : $e');
      return [];
    }
  }

  Future<String> getCatalogDate() async {
    try {
      final result = await database.rawQuery('SELECT Created FROM Revision');
      if (result.isNotEmpty) {
        return result.first['Created'] as String;
      }
    }
    catch (e) {
      printTime('Error getCatalogDate: $e');
    }
    return '';
  }
}
