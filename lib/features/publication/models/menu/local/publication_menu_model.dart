import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/models/menu/local/tab_items.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/utils/files_helper.dart';
import '../../../pages/document/data/models/document.dart';
import '../../../pages/document/local/documents_manager.dart';
import 'menu_list_item.dart';

class PublicationMenuModel {
  final Publication publication;
  late final List<TabWithItems> tabsWithItems = [];
  int initialTabIndex = 0;

  // Initialisation à vide car non utilisée dans le flux critique de chargement
  List<Map<String, dynamic>> suggestions = [];

  bool multimediaExists = false;
  bool documentMultimediaExists = false;
  bool hasMultimediaColumns = false;

  // Map pour stocker les documents par ID et éviter les lookups répétitifs
  late final Map<int, Document> _documentMap;

  PublicationMenuModel(this.publication);

  // --- Initialisation et récupération des données ---

  Future<void> init() async {
    // CORRECTION: Initialisation et vérification sécurisée
    publication.documentsManager ??= DocumentsManager(publication: publication, mepsDocumentId: -1);

    // Le '!' est sécurisé car il vient d'être initialisé ou supposé valide
    await publication.documentsManager!.initializeDatabaseAndData();

    publication.wordsSuggestionsModel ??= WordsSuggestionsModel(publication);

    // Création de la map pour un accès O(1) aux objets Document
    _documentMap = {
      for (var doc in publication.documentsManager!.documents) doc.documentId: doc
    };

    await _fetchItems();
  }

  Future<void> initAudio() async {
    // Assurez-vous que publications.fetchAudios() est une méthode valide
    await publication.fetchAudios();
  }

  Future<void> _fetchItems() async {
    try {
      // 1. Déclenchement parallèle des requêtes préliminaires
      final Future<List<Map<String, dynamic>>> tabsFuture = publication.documentsManager!.database.rawQuery('''
        SELECT 
          pvi.PublicationViewItemId,
          pvi.Title,
          COALESCE(
              CASE 
                  WHEN pvi.ChildTemplateSchemaType != pvi.SchemaType 
                  THEN cvs.DataType
              END,
              vs.DataType
          ) AS DataType
        FROM PublicationView pv
        INNER JOIN PublicationViewItem pvi ON pvi.PublicationViewId = pv.PublicationViewId AND pvi.ParentPublicationViewItemId = -1
        LEFT JOIN (
            SELECT SchemaType, MIN(DataType) AS DataType
            FROM PublicationViewSchema
            GROUP BY SchemaType
        ) vs ON pvi.SchemaType = vs.SchemaType
        LEFT JOIN (
            SELECT SchemaType, MIN(DataType) AS DataType
            FROM PublicationViewSchema
            GROUP BY SchemaType
        ) cvs ON pvi.ChildTemplateSchemaType = cvs.SchemaType
              AND pvi.ChildTemplateSchemaType != pvi.SchemaType
        WHERE pv.Symbol = 'jwpub';
      ''');

      final Future<List<bool>> tableChecksFuture = Future.wait([
        _checkIfTableExists('Multimedia'),
        _checkIfTableExists('DocumentMultimedia'),
      ]);

      // Attente des résultats
      final List<Map<String, dynamic>> tabs = await tabsFuture;
      final List<bool> tableChecks = await tableChecksFuture;

      multimediaExists = tableChecks[0];
      documentMultimediaExists = tableChecks[1];

      // Vérification des colonnes, lancée après la vérification de l'existence de la table
      hasMultimediaColumns = multimediaExists && (await _getColumnsForTable('Multimedia')).contains('CategoryType');

      // 2. Récupérer tous les items pour chaque onglet en parallèle
      final allItemsPerTab = await Future.wait(
        tabs.map((tab) => _getItemsForParent(tab['PublicationViewItemId'] as int)).toList(),
      );

      // 3. Traitement des résultats
      for (int i = 0; i < tabs.length; i++) {
        final tab = tabs[i];
        final items = allItemsPerTab[i];
        final List<ListItem> itemList = [];

        // Création d'un set d'IDs pour la vérification rapide de la présence d'un item
        final itemIds = items.map((item) => item['PublicationViewItemId'] as int).toSet();

        for (final item in items) {
          final currentItemId = item['PublicationViewItemId'] as int;
          final currentParentId = item['ParentPublicationViewItemId'] as int;

          if (!itemIds.contains(currentParentId)) {

            if (item['DefaultDocumentId'] == -1) {
              // Cas Titre/Header
              final subItems = items.where((subItem) => subItem['ParentPublicationViewItemId'] == currentItemId).toList();

              // Optimisation: Utilisation d'un drapeau pour la présence de livre biblique
              final bool isBibleBooks = subItems.any((subItem) => subItem['Type'] == 2);

              if (isBibleBooks && initialTabIndex == 0) {
                initialTabIndex = i;
              }

              itemList.add(
                ListItem(
                  title: item['DisplayTitle'] as String,
                  isTitle: true,
                  isBibleBooks: isBibleBooks,
                  showImage: false,
                  subItems: subItems.map(_mapToListItem).toList(),
                ),
              );
            }
            else {
              // Cas Item de document
              itemList.add(_mapToListItem(item));
            }
          }
        }

        tabsWithItems.add(TabWithItems(tab: tab, items: itemList));
      }
    }
    catch (e) {
      throw Exception('Erreur lors de la récupération des données : $e');
    }
  }

  // --- Fonctions d'aide SQL ---

  // Optimisation: utilise une méthode rapide 'LIMIT 1'
  Future<bool> _checkIfTableExists(String tableName) async {
    final result = await publication.documentsManager!.database.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
        [tableName]);
    return result.isNotEmpty;
  }

  // Fonction inchangée, elle est déjà rapide (PRAGMA est une commande interne)
  Future<List<String>> _getColumnsForTable(String tableName) async {
    final result = await publication.documentsManager!.database.rawQuery("PRAGMA table_info($tableName)");
    return result.map((row) => row['name'] as String).toList();
  }

  // --- Requêtes de récupération des items ---

  Future<List<Map<String, dynamic>>> _getItemsForParent(int parentId) async {
    // La logique de séparation Bible/Non-Bible est déléguée à getBibleItems/getPublicationItems
    if (publication.isBible()) {
      return await getBibleItems(parentId);
    }

    // Cas Non-Bible : Construction de la requête + exécution
    final String query = getPublicationItems();
    return await publication.documentsManager!.database.rawQuery(query, [parentId, parentId]);
  }

  String getPublicationItems() {
    // Utilisation des booléens vérifiés pour éviter des JOINS inutiles
    final useMultimedia = documentMultimediaExists && multimediaExists && hasMultimediaColumns;

    // Construction de la requête avec un constructeur de chaîne plus efficace
    final buffer = StringBuffer('''
      SELECT
        pvi.PublicationViewItemId,
        pvi.ParentPublicationViewItemId,
        pvi.Title AS DisplayTitle,
        pvi.DefaultDocumentId,
        pvs.DataType,
    ''');

    // Ajout conditionnel de FilePath
    if (useMultimedia) {
      buffer.writeln('  MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath');
    } else {
      buffer.writeln('  NULL AS FilePath');
    }

    // FROM & JOINS
    buffer.writeln('FROM PublicationViewItem pvi');
    buffer.writeln('LEFT JOIN PublicationViewSchema pvs ON pvi.SchemaType = pvs.SchemaType');

    if (documentMultimediaExists) {
      buffer.writeln('LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = pvi.DefaultDocumentId');
      if (useMultimedia) {
        // La condition est déjà vérifiée par useMultimedia
        buffer.writeln('LEFT JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId');
      }
    }

    // JOIN pour récupérer les enfants d'éléments avec DefaultDocumentId = -1
    buffer.writeln('LEFT JOIN PublicationViewItem pvx');
    buffer.writeln('  ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId');
    buffer.writeln('  AND pvx.ParentPublicationViewItemId = ?');
    buffer.writeln('  AND pvx.DefaultDocumentId = -1');

    // WHERE & GROUP BY
    buffer.writeln('WHERE pvi.ParentPublicationViewItemId = ?');
    buffer.writeln('   OR pvx.PublicationViewItemId IS NOT NULL');
    buffer.writeln('GROUP BY pvi.PublicationViewItemId'); // Ajout des colonnes pour un GROUP BY valide

    return buffer.toString();
  }

  // Fonction getBibleItems inchangée (déjà optimisée pour le batch processing)
  Future<List<Map<String, dynamic>>> getBibleItems(int parentId) async {
    // ... (Code de getBibleItems inchangé) ...
    // Retiré FilePath car il est géré dans le SELECT
    const query = '''
      SELECT
        pvi.PublicationViewItemId,
        pvi.ParentPublicationViewItemId,
        pvi.Title AS DisplayTitle,
        pvi.DefaultDocumentId,
        pvs.DataType,
        d.Type,
        bb.BibleBookId,
        bb.HasCommentary,
        MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath
      FROM PublicationViewItem pvi
      LEFT JOIN PublicationViewSchema pvs 
        ON pvi.SchemaType = pvs.SchemaType
      LEFT JOIN DocumentMultimedia dm 
        ON dm.DocumentId = pvi.DefaultDocumentId
      LEFT JOIN Multimedia m 
        ON dm.MultimediaId = m.MultimediaId
      LEFT JOIN Document d 
        ON d.DocumentId = pvi.DefaultDocumentId
      LEFT JOIN BibleBook bb 
        ON d.ChapterNumber = bb.BibleBookId
      LEFT JOIN PublicationViewItem pvx
        ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId
        AND pvx.ParentPublicationViewItemId = ?
        AND pvx.DefaultDocumentId = -1  
      WHERE pvi.ParentPublicationViewItemId = ? OR pvx.PublicationViewItemId IS NOT NULL
      GROUP BY 
        pvi.PublicationViewItemId,
        pvi.ParentPublicationViewItemId,
        pvi.Title,
        pvi.DefaultDocumentId,
        pvs.DataType,
        d.Type;
    ''';

    final result = await publication.documentsManager!.database.rawQuery(query, [parentId, parentId]);

    // Séparer les éléments Bible et non-Bible
    final bibleItems = <Map<String, dynamic>>[];
    final nonBibleItems = <Map<String, dynamic>>[];

    for (final item in result) {
      // Le type 2 correspond aux livres bibliques
      if (item['Type'] == 2) {
        bibleItems.add(item);
      } else {
        nonBibleItems.add(item);
      }
    }

    // Traiter les éléments Bible en parallèle si nécessaire (et SEULEMENT s'il y en a)
    if (bibleItems.isNotEmpty) {
      final processedBibleItems = await _processBibleItems(bibleItems);
      nonBibleItems.addAll(processedBibleItems);
    }

    return nonBibleItems;
  }

  // Méthode helper pour traiter les éléments bibliques en batch
  Future<List<Map<String, dynamic>>> _processBibleItems(List<Map<String, dynamic>> bibleItems) async {
    // Assurez-vous que getMepsUnitDatabaseFile est importé et fonctionne
    final mepsFile = await getMepsUnitDatabaseFile();
    final mepsDatabase = await openDatabase(mepsFile.path);

    try {
      // Collecte des IDs de livres uniques pour la requête batch
      final bookIds = bibleItems
          .map((item) => item['BibleBookId'])
          .whereType<int>()
          .toSet()
          .toList();

      if (bookIds.isEmpty) return bibleItems;

      // Requête unique pour tous les noms de livres
      final placeholders = List.filled(bookIds.length, '?').join(',');
      final bookNamesQuery = '''
      SELECT 
        bbn.BookNumber,
        bbn.StandardBookName,
        bbn.StandardBookAbbreviation,
        bbn.OfficialBookAbbreviation,
        bbg.GroupId
      FROM BibleBookName bbn
      INNER JOIN BibleCluesInfo bci ON bbn.BibleCluesInfoId = bci.BibleCluesInfoId
      INNER JOIN BibleBookGroup bbg ON bbg.BookNumber = bbn.BookNumber
      WHERE bbn.BookNumber IN ($placeholders) AND bci.LanguageId = ?''';

      // Assurez-vous que publications.mepsLanguage.id est un int pour la requête
      final bookNames = await mepsDatabase.rawQuery(
        bookNamesQuery,
        [...bookIds, publication.mepsLanguage.id],
      );

      // Map pour un accès rapide aux données du livre par ID
      final bookNamesMap = <int, Map<String, dynamic>>{
        for (final book in bookNames) book['BookNumber'] as int: book
      };

      // Application des données des noms de livres aux items d'origine
      return bibleItems.map((item) {
        final bookId = item['BibleBookId'] as int?;
        if (bookId != null && bookNamesMap.containsKey(bookId)) {
          // Fusion des maps pour ajouter les noms/abréviations
          return {...item, ...bookNamesMap[bookId]!};
        }
        return item;
      }).toList();
    }
    finally {
      // Très important de fermer la base de données après usage
      await mepsDatabase.close();
    }
  }


  // --- Mapping en ListItem (Optimisation du lookup) ---
  ListItem _mapToListItem(Map<String, dynamic> item) {
    // OPTIMISATION: Utilise la map pour un accès O(1) au lieu de .firstWhere (O(n))
    final documentId = item['DefaultDocumentId'] as int;
    final document = _documentMap[documentId];

    // Gère le cas où le document ne serait pas trouvé (bien que peu probable si la DB est cohérente)
    if (document == null) {
      // Retourne un ListItem par défaut ou lève une exception selon la politique d'erreur
      return ListItem(title: 'Erreur Document ID $documentId', isTitle: false);
    }

    // Utilisation des valeurs fusionnées dans les items bibliques (OfficialBookAbbreviation, StandardBookName)
    final title = publication.schemaVersion >= 8 ? document.type == 2
        ? item['OfficialBookAbbreviation'] as String? ?? ''
        : document.title as String? ?? ''
        : item['DisplayTitle']?.trim() as String? ?? '';

    return ListItem(
      title: title,
      mediumTitle: document.type == 2 ? item['StandardBookAbbreviation'] as String? ?? '' : '',
      largeTitle: document.type == 2 ? item['StandardBookName'] as String? ?? '' : '',
      displayTitle: item['DisplayTitle'] as String? ?? '',
      subTitle: document.contextTitle ?? document.featureTitle ?? '',
      imageFilePath: item['FilePath'] as String? ?? '',
      dataType: item['DataType'] as String? ?? '',
      groupId: document.type == 2 ? item['GroupId'] as int? ?? -1 : -1,
      hasCommentary: document.type == 2
          ? (item['HasCommentary'] ?? 0) == 1
          : false,
      bibleBookId: item['BibleBookId'] as int? ?? -1,
      mepsDocumentId: document.mepsDocumentId, // Assumé non-null
      isTitle: false,
    );
  }
}